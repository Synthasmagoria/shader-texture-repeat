const std = @import("std");

pub fn build(b: *std.Build) void {
    //const windows = b.option(bool, "Windows", "Target Microsoft Windows") orelse false;
    //const target = b.resolveTargetQuery(.{.os_tag = if (windows) .windows else null});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Neothunthoen",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
    });

    const raylib_dep = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.artifact("raylib");
    exe.linkLibrary(raylib);

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {run_exe.addArgs(args);}
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
