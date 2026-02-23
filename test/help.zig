const std = @import("std");
const argparse = @import("argparse");

const str = []const u8;
const c_str = [*:0]u8;

test "help" {
    var allocator = std.testing.allocator;

    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "-h"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const App = struct {
        verbose: argparse.Flag(.{ .short = &.{"v"}, .long = &.{"verbose"}, .long_inverse = &.{"no-verbose"}, .help = "Enable verbose output" }),
        version: argparse.Flag(.{ .short = &.{"V"}, .long = &.{"version"}, .help = "Print version and exit" }),
        name: argparse.Positional(str),
        num: argparse.Option(i32, .{ .short = &.{"n"}, .long = &.{"num"}, .help = "A number" }) = .{ .value = 42 },
        run: ?argparse.Subcommand(struct {}, .{ .subcommand = "run", .help = "Run the app" }),
    };
    std.debug.print("help test:\n", .{});
    try std.testing.expectError(argparse.ParseError.Help, argparse.parseInto(App, .{ .allocator = allocator }));
}
