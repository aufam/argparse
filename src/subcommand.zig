const std = @import("std");

const Flag = @import("flag.zig");
const Option = @import("option.zig");
const ParseError = @import("error.zig").ParseError;
const str = []const u8;

const Self = @This();

subcommand: str,
help: ?str = null,

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
    allocator: std.mem.Allocator,
) ParseError!bool {
    if (std.mem.eql(u8, self.subcommand, arg)) {
        switch (@typeInfo(field_type)) {
            .optional => |opt| {
                if (@hasDecl(opt.child, "__argparse_subcommand__")) {
                    @field(result, field_name) = .{ .value = try apply(opt.child.__argparse_type__, args, allocator) };
                } else {
                    @field(result, field_name) = try apply(opt.child, args, allocator);
                }
                return true;
            },
            else => return error.UnsupportedType,
        }
    }
    return false;
}

pub fn apply(comptime T: type, args: *std.process.ArgIterator, allocator: std.mem.Allocator) ParseError!T {
    switch (@typeInfo(T)) {
        .@"struct" => {},
        else => return error.UnsupportedType,
    }

    const ti = @typeInfo(T).@"struct";

    var result: T = undefined;
    var required_fields: [ti.fields.len]?str = undefined;
    inline for (ti.fields, 0..) |field, i| {
        if (field.type == bool) {
            _ = field.defaultValue() orelse {
                @field(result, field.name) = false; // set to false if bool field has no default value
            };
            required_fields[i] = null; // bool fields are not required
        } else if (@typeInfo(field.type) == .optional) {
            _ = field.defaultValue() orelse {
                @field(result, field.name) = null; // set to null if option field has no default value
            };
            required_fields[i] = null; // option fields are not required
        } else {
            required_fields[i] = field.name; // non-optional fields are required
        }
    }

    var kinds: [ti.fields.len]?Kind = undefined;
    inline for (ti.fields, 0..) |field, i| {
        kinds[i] = Kind.of(field) orelse {
            std.debug.print("Type of .{s} is unsupported\n", .{field.name});
            return error.UnsupportedType;
        };
    }

    try applyImpl(T, ti, &result, args, &required_fields, &kinds, allocator);

    for (required_fields) |field| {
        if (field) |name| {
            std.debug.print("required field `{s}` is missing\n", .{name});
            return error.MissingRequiredField;
        }
    }

    return result;
}

fn applyImpl(
    comptime T: type,
    comptime ti: std.builtin.Type.Struct,
    result: *T,
    args: *std.process.ArgIterator,
    required_fields: *[ti.fields.len]?str,
    kinds: *[ti.fields.len]?Kind,
    allocator: std.mem.Allocator,
) ParseError!void {
    const arg = args.next() orelse return;

    inline for (ti.fields, 0..) |field, i| {
        if (kinds[i]) |kind| {
            const matched = switch (kind) {
                .flag => |flag| try flag.match(T, field.type, field.name, result, arg),
                .option => |option| try option.match(T, field.type, field.name, result, arg, args, allocator),
                .subcommand => |subcommand| try subcommand.match(T, field.type, field.name, result, arg, args, allocator),
            };
            if (matched) {
                kinds[i] = null; // mark as matched
                required_fields[i] = null;
                return try applyImpl(T, ti, result, args, required_fields, kinds, allocator);
            }
        }
    }

    std.debug.print("Cannot process arg={s}\n", .{arg});
    return error.UnknownFlag;
}
