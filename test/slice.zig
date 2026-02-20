const std = @import("std");
const argparse = @import("argparse");

const str = []const u8;
const c_str = [*:0]u8;

test "subcommand" {
    var allocator = std.testing.allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "--names"),
        try allocator.dupeZ(u8, "Alice"),
        try allocator.dupeZ(u8, "Bob"),
        try allocator.dupeZ(u8, "--ages"),
        try allocator.dupeZ(u8, "30"),
        try allocator.dupeZ(u8, "42"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        names: []const str,
        ages: []u8,
    };
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    defer allocator.free(app.names);
    defer allocator.free(app.ages);

    std.debug.print("slice: names={any} ages={any}\n", app);
}
