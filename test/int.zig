const std = @import("std");
const argparse = @import("argparse");

test "int" {
    var allocator = std.testing.allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "--num"),
        try allocator.dupeZ(u8, "123"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        num: i32,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("int: num={}\n", app);

    try std.testing.expect(app.num == 123);
}
