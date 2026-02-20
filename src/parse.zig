const std = @import("std");
const Subcommand = @import("subcommand.zig");
const ParseError = @import("error.zig").ParseError;

pub const Config = struct {
    allocator: std.mem.Allocator,
};

pub fn parseInto(comptime T: type, config: Config) ParseError!T {
    var args = std.process.args();
    _ = args.next().?;

    return Subcommand.apply(T, &args, config.allocator);
}
