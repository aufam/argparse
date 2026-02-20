const std = @import("std");
const argparse = @import("argparse");

const str = []const u8;
const c_str = [*:0]u8;

test "subcommand" {
    var allocator = std.heap.page_allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "--names"),
        try allocator.dupeZ(u8, "Alice"),
        try allocator.dupeZ(u8, "Bob"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        names: []const str,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    std.debug.print("slice: names={any}\n", app);
}
