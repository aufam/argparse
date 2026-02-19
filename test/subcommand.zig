const std = @import("std");
const argparse = @import("argparse");

test "subcommand" {
    var allocator = std.heap.page_allocator;

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
        run: ?struct {},
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("subcommand: verbose={any} run={any}\n", app);

    try std.testing.expect(app.v);
    try std.testing.expect(app.run != null);
}
