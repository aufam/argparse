const std = @import("std");
const argparse = @import("argparse");

test "optional" {
    var allocator = std.heap.page_allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "info"),
        try allocator.dupeZ(u8, "debug"),
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
        level2: argparse.Option(LogLevel, .{ .positional = true }),
    };
    std.debug.print("optional: ", .{});
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("verbose={any} level={any} level={any}\n", app);

    try std.testing.expect(app.level.value == .info);
    try std.testing.expect(app.verbose == false);
}
