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
                @field(result, field.name) = false;
            };
            required_fields[i] = null;
        } else if (@typeInfo(field.type) == .optional) {
            _ = field.defaultValue() orelse {
                @field(result, field.name) = null;
            };
            required_fields[i] = null;
        } else {
            required_fields[i] = if (field.defaultValue()) |_| null else field.name;
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
    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
        printHelp(ti, required_fields, kinds);
        return error.Help;
    }

    inline for (ti.fields, 0..) |field, i| {
        if (kinds[i]) |kind| {
            const matched = switch (kind) {
                .flag => |flag| try flag.match(T, field.type, field.name, result, arg),
                .option => |option| try option.match(T, field.type, field.name, result, arg, args, allocator),
                .subcommand => |subcommand| try subcommand.match(T, field.type, field.name, result, arg, args, allocator),
            };
            if (matched) {
                kinds[i] = null; // TODO: what about late help flag?
                required_fields[i] = null;
                return try applyImpl(T, ti, result, args, required_fields, kinds, allocator);
            }
        }
    }

    std.debug.print("Cannot process arg={s}\n", .{arg});
    return error.UnknownFlag;
}

fn printHelp(
    comptime ti: std.builtin.Type.Struct,
    required_fields: *[ti.fields.len]?str,
    kinds: *[ti.fields.len]?Kind,
) void {
    std.debug.print("Usage: {s} [options]", .{std.os.argv[0]}); // TODO: subcommand usage?
    inline for (ti.fields, 0..) |field, i| {
        if (kinds[i]) |kind| {
            switch (kind) {
                .option => |option| if (option.positional) {
                    std.debug.print(" <{s}>", .{field.name});
                },
                else => {},
            }
        }
    }

    std.debug.print("\n\nOptions:\n", .{});
    inline for (ti.fields, 0..) |field, i| {
        if (kinds[i]) |kind| {
            switch (kind) {
                .flag => |flag| {
                    std.debug.print("  ", .{});
                    for (flag.short) |short| {
                        std.debug.print("-{s}, ", .{short});
                    }
                    for (flag.long) |long| {
                        std.debug.print("--{s}, ", .{long});
                    }
                    for (flag.long_inverse) |long| {
                        std.debug.print("--{s}, ", .{long});
                    }
                    if (flag.help) |help| {
                        std.debug.print(": {s} ", .{help});
                    }
                    std.debug.print("\n", .{});
                },
                .option => |option| if (!option.positional) {
                    std.debug.print("  ", .{});
                    for (option.short) |short| {
                        std.debug.print("-{s}, ", .{short});
                    }
                    for (option.long) |long| {
                        std.debug.print("--{s}, ", .{long});
                    }
                    if (required_fields[i]) |_| {
                        std.debug.print("<required> ", .{});
                    }
                    if (option.help) |help| {
                        std.debug.print(": {s} ", .{help});
                    }
                    if (field.type != bool) {
                        if (field.defaultValue()) |default| {
                            if (@typeInfo(@TypeOf(default)) == .@"struct" and @hasDecl(@TypeOf(default), "__argparse_option__")) {
                                const V = @TypeOf(default.value);
                                if (V == str) {
                                    std.debug.print("(default: {s})", .{default.value});
                                } else {
                                    std.debug.print("(default: {any})", .{default.value});
                                }
                            } else if (@TypeOf(default) == str) {
                                std.debug.print("(default: {s})", .{default});
                            } else {
                                std.debug.print("(default: {any})", .{default});
                            }
                        }
                    }
                    std.debug.print("\n", .{});
                },
                else => {},
            }
        }
    }

    std.debug.print("\nSubcommands:\n", .{});
    inline for (ti.fields, 0..) |_, i| {
        if (kinds[i]) |kind| {
            switch (kind) {
                .subcommand => |subcommand| {
                    std.debug.print("  {s}", .{subcommand.subcommand});
                    if (subcommand.help) |help| {
                        std.debug.print(": {s}, ", .{help});
                    }
                    std.debug.print("\n", .{});
                },
                else => {},
            }
        }
    }
}
