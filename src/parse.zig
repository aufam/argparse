const std = @import("std");
const Subcommand = @import("subcommand.zig");
const ParseError = @import("error.zig").ParseError;

pub const Config = struct {
    description: ?[]const u8 = null,
    allocator: std.mem.Allocator,
};

pub fn parseInto(comptime T: type, config: Config) ParseError!T {
    var args = std.process.args();

    // TODO
    _ = args.next().?;
    _ = config.description;

    return Subcommand.apply(T, &args, config.allocator);
}
