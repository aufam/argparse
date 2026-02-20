const std = @import("std");
const argparse = @import("argparse");

test "optional" {
    var allocator = std.testing.allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "--log-level"),
        try allocator.dupeZ(u8, "info"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const LogLevel = enum {
        trace,
        info,
        debug,
    };
    const App = struct {
        @"log-level": ?LogLevel,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("optional: log-level={?}\n", app);

    try std.testing.expect(app.@"log-level" == .info);
}
