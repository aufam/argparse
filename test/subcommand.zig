const std = @import("std");
const argparse = @import("argparse");

const str = []const u8;
const c_str = [*:0]u8;

test "subcommand" {
    var allocator = std.testing.allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "-v"),
        try allocator.dupeZ(u8, "run"),
        try allocator.dupeZ(u8, "--target=this"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        v: bool,
        run: ?argparse.Subcommand(struct {
            target: str,
        }, .{ .subcommand = "run" }),
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("subcommand: verbose={any} run={any}\n", app);

    try std.testing.expect(app.v);
    try std.testing.expect(app.run != null);
    try std.testing.expect(std.mem.eql(u8, app.run.?.value.target, "this"));
}
