const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    var target = b.standardTargetOptions(.{});
    target.abi = .musl;
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("ScalpiEditor", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);    
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
