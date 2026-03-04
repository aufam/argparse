const std = @import("std");
const argparse = @import("argparse");

const App = struct {
    /// boolean
    verbose: bool,

    /// enum, fallback value is optional, but if provided, it must be a valid enum variant
    @"log-level": enum { trace, info, debug } = .info,

    //
    // subcommands must be ?struct {...}
    //
    version: ?struct {},

    run: ?struct {
        //
        // non-bool and non-optional fields are required unless they have a default value
        //

        /// string slice
        name: []const u8,

        /// integer
        age: u32,

        /// float
        height: f32,

        /// array slice type, must be freed, and must not be confused with positional arguments
        hobbies: []const []const u8,

        /// with default value, implies optional
        country: []const u8 = "Unknown",

        /// optional value
        nickname: ?[]const u8,

        //
        // custom options
        //

        /// positional arguments
        input: argparse.Positional([]const u8),

        /// can be flagged or positional
        output: argparse.Option([]const u8, .{ .short = &.{"o"}, .long = &.{"output"}, .help = "Output file path", .positional = true }),

        /// custom flag
        print_hash: argparse.Flag(.{ .short = &.{"H"}, .long = &.{"hash"}, .help = "Print the hash of the input file" }),
    },
};

test "main" {
    var allocator = std.testing.allocator;

    const c_str = [*:0]u8;
    var argv = [_]c_str{
        try allocator.dupeZ(u8, "argparse"),
        try allocator.dupeZ(u8, "run"),
        try allocator.dupeZ(u8, "--name"),
        try allocator.dupeZ(u8, "Alice"),
        try allocator.dupeZ(u8, "--age"),
        try allocator.dupeZ(u8, "30"),
        try allocator.dupeZ(u8, "--height"),
        try allocator.dupeZ(u8, "5.5"),
        try allocator.dupeZ(u8, "--hobbies"),
        try allocator.dupeZ(u8, "Reading"),
        try allocator.dupeZ(u8, "Traveling"),
        try allocator.dupeZ(u8, "--output=output.txt"),
        try allocator.dupeZ(u8, "input.txt"),
    };
    defer for (argv) |arg| {
        allocator.free(std.mem.span(arg));
    };

    std.os.argv = &argv;

    const app = try argparse.parseInto(App, .{ .allocator = allocator });
    if (app.run) |run| {
        defer allocator.free(run.hobbies);
        std.debug.print("main: name={s} age={d} height={d} country={s} hobbies={s},{s} input={s} output={s}\n", .{ run.name, run.age, run.height, run.country, run.hobbies[0], run.hobbies[1], run.input.value, run.output.value });
    }
}
