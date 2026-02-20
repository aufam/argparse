const std = @import("std");
const argparse = @import("argparse");

test "unsupported" {
    var allocator = std.testing.allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "-v"),
        try allocator.dupeZ(u8, "run"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        v: bool,
        run: struct {},
    };
    std.debug.print("unsupported: ", .{});
    try std.testing.expectError(argparse.ParseError.UnsupportedType, argparse.parseInto(App, .{ .allocator = allocator }));
}
