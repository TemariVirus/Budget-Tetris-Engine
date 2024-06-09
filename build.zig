const std = @import("std");
const Build = std.Build;
const builtin = std.builtin;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: remove
    const nterm_module = b.dependency("nterm", .{
        .target = target,
        .optimize = optimize,
    }).module("nterm");

    // Expose the library root
    _ = b.addModule("engine", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/root.zig",
            },
        },
        .imports = &.{
            .{ .name = "nterm", .module = nterm_module },
        },
    });

    buildTests(b);
}

fn buildTests(b: *Build) void {
    const lib_tests = b.addTest(.{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/root.zig",
            },
        },
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
