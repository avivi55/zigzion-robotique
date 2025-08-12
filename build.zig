const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    raylib_artifact.root_module.addCMacro("SUPPORT_FILEFORMAT_PNM", "");

    const nfd = b.dependency("nfd", .{
        .target = target,
        .optimize = optimize,
    });

    const nfd_mod = nfd.module("nfd");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = exe_mod,
        .use_lld = false,
    });
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    exe.root_module.addImport("raygui", raygui);
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("nfd", nfd_mod);


    b.installArtifact(exe);

    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TEST

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
        .use_lld = false,
    });
    const run_lib_unit_tests = b.addRunArtifact(exe_unit_tests);

    exe_unit_tests.root_module.addImport("raylib", raylib);
    exe_unit_tests.root_module.addImport("raygui", raygui);
    exe_unit_tests.root_module.addImport("raygui", raygui);
    exe_unit_tests.linkLibrary(raylib_artifact);
    // run_lib_unit_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
