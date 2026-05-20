const std = @import("std");
const Build = std.Build;
const builtin = std.builtin;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nterm = b.dependency("nterm", .{
        .target = target,
        .optimize = optimize,
    }).module("nterm");
    const bounded_array = b.dependency("bounded_array", .{
        .target = target,
        .optimize = optimize,
    }).module("bounded_array");

    // Expose the library root
    _ = b.addModule("engine", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "nterm", .module = nterm },
            .{ .name = "bounded_array", .module = bounded_array },
        },
    });

    buildTests(b);
}

fn buildTests(b: *Build) void {
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.resolveTargetQuery(.{}),
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
