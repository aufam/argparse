const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const argparse = b.addModule("argparse", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });

    const argparse_tests = b.addModule("ws-chat", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("test/root.zig"),
        .imports = &.{
            .{ .name = "argparse", .module = argparse },
        },
    });

    const argparse_run_tests = b.addTest(.{
        .root_module = argparse_tests,
    });
    const run_argparse_tests = b.addRunArtifact(argparse_run_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_argparse_tests.step);
}
