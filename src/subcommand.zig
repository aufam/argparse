const std = @import("std");

const Flag = @import("flag.zig");
const Option = @import("option.zig");
const ParseError = @import("error.zig").ParseError;
const str = []const u8;

const Self = @This();

subcommand: str,

const Kind = union(enum) {
    flag: Flag,
    option: Option,
    subcommand: Self,

    pub fn of(comptime field: std.builtin.Type.StructField) ?Kind {
        if (Flag.of(field)) |flag| {
            return .{ .flag = flag };
        }
        if (Option.of(field)) |option| {
            return .{ .option = option };
        }
        if (Self.of(field)) |subcommand| {
            return .{ .subcommand = subcommand };
        }
        return null;
    }
};

pub fn of(comptime field: std.builtin.Type.StructField) ?Self {
    return switch (@typeInfo(field.type)) {
        .optional => |opt| switch (@typeInfo(opt.child)) {
            .@"struct" => if (@hasDecl(opt.child, "__argparse_subcommand__"))
                opt.child.__argparse_subcommand__
            else
                .{ .subcommand = field.name },
            else => null,
        },
        else => null,
    };
}

pub fn match(
    self: Self,
    comptime T: type,
    comptime field_type: type,
    comptime field_name: []const u8,
    result: *T,
    arg: str,
    args: *std.process.ArgIterator,
) ParseError!bool {
    if (std.mem.eql(u8, self.subcommand, arg)) {
        switch (@typeInfo(field_type)) {
            .optional => |opt| {
                @field(result, field_name) = try apply(opt.child, args);
                return true;
            },
            else => return error.UnsupportedType,
        }
    }
    return false;
}

pub fn apply(comptime T: type, args: *std.process.ArgIterator) ParseError!T {
    switch (@typeInfo(T)) {
        .@"struct" => |ti| {
            var result: T = undefined;
            var required_fields: [ti.fields.len]?str = undefined;
            inline for (ti.fields, 0..) |field, i| {
                if (field.type == bool) {
                    _ = field.defaultValue() orelse {
                        @field(result, field.name) = false; // set to false if bool field has no default value
                    };
                }

                if (@typeInfo(field.type) == .optional) {
                    _ = field.defaultValue() orelse {
                        @field(result, field.name) = null; // set to null if option field has no default value
                    };
                }

                required_fields[i] = if (@typeInfo(field.type) != .optional and field.type == bool) null else field.name;
            }

            try applyImpl(T, ti, &result, args, &required_fields);

            for (required_fields) |field| {
                if (field) |name| {
                    std.debug.print("required field `{s}` is missing\n", .{name});
                    return error.MissingRequiredField;
                }
            }

            return result;
        },
        else => return error.UnsupportedType,
    }
}

fn applyImpl(
    comptime T: type,
    comptime ti: std.builtin.Type.Struct,
    result: *T,
    args: *std.process.ArgIterator,
    required_fields: *[ti.fields.len]?str,
) ParseError!void {
    const arg = args.next() orelse return;

    inline for (ti.fields, 0..) |field, i| {
        if (Kind.of(field)) |kind| {
            const matched = switch (kind) {
                .flag => |flag| try flag.match(T, field.type, field.name, result, arg),
                .option => |option| try option.match(T, field.type, field.name, result, arg, args),
                .subcommand => |subcommand| try subcommand.match(T, field.type, field.name, result, arg, args),
            };
            if (matched) {
                required_fields[i] = null;
                return try applyImpl(T, ti, result, args, required_fields);
            }
        } else {
            std.debug.print("Type of .{s} is unsupported\n", .{field.name});
            return error.UnsupportedType;
        }
    }

    std.debug.print("Cannot process arg={s}\n", .{arg});
    return error.UnknownFlag;
}
