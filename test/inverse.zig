const std = @import("std");
const argparse = @import("argparse");

test "subcommand" {
    var allocator = std.testing.allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "--no-verbose"),
        try allocator.dupeZ(u8, "run"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        verbose: argparse.Flag(.{ .long = &.{"verbose"}, .short = &.{"v"}, .long_inverse = &.{"no-verbose"} }),
        run: ?struct {} = null,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("inverse: verbose={any} run={any}\n", app);

    try std.testing.expect(!app.verbose.value);
    try std.testing.expect(app.run != null);
}
