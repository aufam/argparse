const std = @import("std");
const argparse = @import("argparse");

test "optional" {
    var allocator = std.heap.page_allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
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
        verbose: bool,
        level: argparse.Option(LogLevel, .{ .positional = true }),
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("optional: verbose={any} log-level={any}\n", app);

    try std.testing.expect(app.level.value == .info);
    try std.testing.expect(app.verbose == false);
}
