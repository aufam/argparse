const std = @import("std");
const argparse = @import("argparse");

const str = []const u8;
const c_str = [*:0]u8;

test "simple" {
    var allocator = std.heap.page_allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "-v"),
        try allocator.dupeZ(u8, "--test"),
        try allocator.dupeZ(u8, "foo"),
        try allocator.dupeZ(u8, "--num=123"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        v: bool,
        @"test": str,
        num: i32,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("simple: verbose={any} test={s} num={d}\n", app);

    try std.testing.expect(app.v);
    try std.testing.expect(std.mem.eql(u8, app.@"test", "foo"));
    try std.testing.expect(app.num == 123);
}
