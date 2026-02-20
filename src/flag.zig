const std = @import("std");

const Self = @This();
const str = []const u8;
const ParseError = @import("error.zig").ParseError;

short: []const str = &.{},
long: []const str = &.{},
long_inverse: []const str = &.{},
help: ?str = null,

pub fn of(comptime field: std.builtin.Type.StructField) ?Self {
    const ret: ?Self = switch (@typeInfo(field.type)) {
        .@"struct" => if (@hasDecl(field.type, "__argparse_flag__"))
            field.type.__argparse_flag__
        else
            null,
        .bool => if (field.name.len == 1)
            .{ .short = &.{field.name} }
        else
            .{ .long = &.{field.name} },
        else => null,
    };
    return ret;
}

pub fn match(
    self: Self,
    comptime T: type,
    comptime field_type: type,
    comptime field_name: []const u8,
    result: *T,
    arg: str,
) ParseError!bool {
    switch (@typeInfo(field_type)) {
        .bool => {
            if (std.mem.startsWith(u8, arg, "--")) {
                const name = arg[2..];

                if (contains(self.long, name)) {
                    @field(result, field_name) = true;
                    return true;
                }

                if (contains(self.long_inverse, name)) {
                    @field(result, field_name) = false;
                    return true;
                }
            } else if (std.mem.startsWith(u8, arg, "-")) {
                const name = arg[1..];

                if (contains(self.short, name)) {
                    @field(result, field_name) = true;
                    return true;
                }
            }
        },
        .@"struct" => if (@hasDecl(field_type, "__argparse_flag__")) {
            const flag: Self = field_type.__argparse_flag__;
            const ptr = &@field(result, field_name);
            return try flag.match(field_type, bool, "value", ptr, arg);
        },
        else => return error.UnsupportedType,
    }

    return false;
}

fn contains(list: []const str, value: str) bool {
    for (list) |item| {
        if (std.mem.eql(u8, item, value))
            return true;
    }
    return false;
}
