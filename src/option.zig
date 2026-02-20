const std = @import("std");

const Self = @This();
const str = []const u8;
const ParseError = @import("error.zig").ParseError;

short: []const str = &.{},
long: []const str = &.{},
positional: bool = false,
help: ?str = null,

fn check(comptime T: type) bool {
    if (T == str) {
        return true;
    }

    return switch (@typeInfo(T)) {
        .int, .float, .@"enum" => true,
        .@"struct" => @hasDecl(T, "__argparse_option__"),
        .optional => |opt| check(opt.child),
        .pointer => |ptr| ptr.size == .slice and isPrimitive(ptr.child),
        else => return false,
    };
}

pub fn of(comptime field: std.builtin.Type.StructField) ?Self {
    const T = field.type;
    if (!check(T))
        return null;

    switch (@typeInfo(T)) {
        .@"struct" => {
            if (@hasDecl(T, "__argparse_option__"))
                return T.__argparse_option__;
        },
        else => {},
    }

    return if (field.name.len == 1)
        .{ .short = &.{field.name} }
    else
        .{ .long = &.{field.name} };
}

pub fn match(
    self: Self,
    comptime T: type,
    comptime field_type: type,
    comptime field_name: str,
    result: *T,
    arg: str,
    args: *std.process.ArgIterator,
    allocator: std.mem.Allocator,
) ParseError!bool {
    if (std.mem.startsWith(u8, arg, "--")) {
        const body = arg[2..];

        const eq_index = std.mem.indexOfScalar(u8, body, '=');
        const name = if (eq_index) |i| body[0..i] else body;
        const value = if (eq_index) |i| body[i + 1 ..] else null;

        for (self.long) |flag| if (std.mem.eql(u8, flag, name)) {
            return try apply(T, field_type, field_name, result, value, args, allocator);
        };
    } else if (std.mem.startsWith(u8, arg, "-")) {
        for (self.short) |flag| if (std.mem.eql(u8, flag, arg[1..])) {
            return try apply(T, field_type, field_name, result, null, args, allocator);
        };
    } else if (self.positional) {
        return try apply(T, field_type, field_name, result, arg, args, allocator);
    }
    return false;
}

fn apply(
    comptime T: type,
    comptime field_type: type,
    comptime field_name: str,
    result: *T,
    arg: ?str,
    args: *std.process.ArgIterator,
    allocator: std.mem.Allocator,
) ParseError!bool {
    if (field_type == str) {
        const value = arg orelse args.next() orelse return error.MissingValue;
        @field(result, field_name) = value;
        return true;
    }

    switch (@typeInfo(field_type)) {
        .int => {
            const value = arg orelse args.next() orelse return error.MissingValue;
            const num = std.fmt.parseInt(field_type, value, 0) catch |err| switch (err) {
                error.InvalidCharacter, error.Overflow => return error.ConversionFailure,
                else => |e| return e,
            };
            @field(result, field_name) = num;
        },
        .float => {
            const value = arg orelse args.next() orelse return error.MissingValue;
            const num = std.fmt.parseFloat(field_type, value) catch |err| switch (err) {
                error.InvalidCharacter => return error.ConversionFailure,
                else => |e| return e,
            };
            @field(result, field_name) = num;
        },
        .@"enum" => {
            const value = arg orelse args.next() orelse return error.MissingValue;
            const enum_value = std.meta.stringToEnum(field_type, value) orelse return error.InvalidEnumValue;
            @field(result, field_name) = enum_value;
        },
        .@"struct" => {
            if (@hasDecl(field_type, "__argparse_option__")) {
                const ptr = &@field(result, field_name);
                return try apply(field_type, field_type.__argparse_type__, "value", ptr, arg, args, allocator);
            } else {
                return error.UnsupportedType;
            }
        },
        .pointer => |ptr| if (ptr.size == .slice and ptr.child == str) {
            if (arg) |_| args.inner.index -= 1; // put back the argument for dupeZ;

            const start = args.inner.index;
            var len: usize = 0;
            while (args.next()) |a| {
                if (std.mem.startsWith(u8, a, "-")) {
                    args.inner.index -= 1; // put back the argument for the next option;
                    break;
                }
                len += 1;
            }

            var out = allocator.alloc([]const u8, len) catch return error.OutOfMemory;
            for (std.os.argv[start .. start + len], 0..) |a, i| {
                out[i] = std.mem.span(a);
            }

            @field(result, field_name) = out;
        } else {
            return error.UnsupportedType;
        },
        .optional => |opt| return try apply(T, opt.child, field_name, result, arg, args, allocator),
        else => return error.UnsupportedType,
    }
    return true;
}

fn isPrimitive(T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .@"enum" => true,
        .pointer => |ptr| ptr.size == .slice and ptr.child == u8,
        else => false,
    };
}
