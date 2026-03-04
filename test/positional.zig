const std = @import("std");
const argparse = @import("argparse");

const c_str = [*:0]u8;
const str = []const u8;

test "optional" {
    var allocator = std.testing.allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "info"),
        try allocator.dupeZ(u8, "debug"),
        try allocator.dupeZ(u8, "--"),
        try allocator.dupeZ(u8, "subcommand"),
        try allocator.dupeZ(u8, "--key=value"),
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
        rest: argparse.Positional([]const str),
    };
    std.debug.print("optional: ", .{});
    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    defer allocator.free(app.rest.value);
    std.debug.print("verbose={any} level={any} level={any} rest={s},{s}\n", .{ app.verbose, app.level.value, app.level2.value, app.rest.value[0], app.rest.value[1] });

    try std.testing.expect(app.verbose == false);
    try std.testing.expect(app.level.value == .info);
    try std.testing.expect(app.level2.value == .debug);
    try std.testing.expect(std.mem.eql(u8, app.rest.value[0], "subcommand"));
    try std.testing.expect(std.mem.eql(u8, app.rest.value[1], "--key=value"));
}
