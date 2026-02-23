## A Blazingly Fast (I guess) Argument Parser in Zig

A simple, fast argument parser for Zig.

- Short and long options
- Positional arguments
- Subcommands
- Struct-based API
- Minimal runtime overhead

### Getting started
run:
```bash
zig fetch --save "git+https://github.com/aufam/argparse#v0.1.0"
```

in `build.zig`:
```zig
    const argparse = b.dependency("argparse", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("argparse", argparse.module("argparse"));
```


### Quick example:

```zig
const std = @import("std");
const argparse = @import("argparse");

const App = struct {
    // subcommands must be ?struct {...}
    version: ?struct {},

    run: ?struct {
        /// non-bool and non-optional fields are required unless they have a default value

        // string slice
        name: []const u8,

        // integer
        age: u32,

        // float
        height: f32,

        // array slice type, must be freed, and must not be confused with positional arguments
        hobbies: []const []const u8,

        // with default value, implies optional
        country: []const u8 = "Unknown",

        // optional value
        nickname: ?[]const u8,

        /// custom options

        // positional argument
        input: argparse.Positional([]const u8),

        // can be flagged or positional
        output: argparse.Option([]const u8, .{ .short = &.{"o"}, .long = &.{"output"}, .help = "Output file path", .positional = true }),
    },

    // boolen flags with --no- variants
    verbose: argparse.Flag(.{ .short = &.{"v"}, .long = &.{"verbose"}, .long_inverse = &.{"no-verbose"}, .help = "Verbose output" }),

    // enums
    @"log-level": ?enum { trace, info, debug } = .info,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const app = argparse.parseInto(App, .{ .allocator = allocator }) catch |err| if (err == argparse.ParseError.Help) {
        return; // help information is automatically printed by the library, so we can just exit
    } else {
        return err;
    };

    // accessing custom flags
    const verbose = app.verbose.value;

    // subcommands are ensured to be mutually exclusive, so we can use if-else statements to handle them
    if (app.version) |_| {
        // print version information
    } else if (app.run) |run| {
        // don't forget to free slice types
        defer allocator.free(run.hobbies);

        // run the application with the provided arguments
    }
}
```


### Design
`argparse` maps CLI arguments directly into a user-defined struct.

Rules:
- `Flags` are boolean.
- `Options` are for values that can be set by the user. Fields with default values are optional, and fields without default values are required.
- `Subcommands` must be `?struct {...}`.
- Primitive types for options: integers, floats, string slices, and enums.
- Parse long options with `=` or space
  ```zig
  const App = struct {
      name: []const u8,
      age: u8,
  };
  // ./app --name=John --age 30
  ```
- Slices are allocated by allocator and must be freed by the user.
- Positional arguments can be defined with `argparse.Positional` and can be used in conjunction with flagged options. For example:
  ```zig
  const App = struct {
      verbose: bool,
      m: []const []const u8,
      input: argparse.Positional([]const u8),
      output: argparse.Option([]const u8, .{ .short = &.{"o"}, .long = &.{"output"}, .help = "Output file path", .positional = true }),
  };
  ```
  ```bash
  ./app input.txt output.txt -m foo bar    # ok
  ./app input.txt -o output.txt -m foo bar # ok
  ./app -m foo bar -o output.txt input.txt # ok
  ./app -m foo bar input.txt -o output.txt # err: missing input field, because the parser will assume input.txt is the value for the -m option
  ```


### TODO
- [ ] Better help message.
- [ ] Better compile error message.
- [ ] Windows and wasm.
