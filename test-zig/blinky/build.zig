const std = @import("std");
const builtin = @import("builtin");

comptime {
    const current_zig = builtin.zig_version;
    const required_zig = std.SemanticVersion.parse("0.14.0-xtensa") catch unreachable;
    if (current_zig.order(required_zig) != .eq) {
           const error_message =
               \\Sorry, it looks like your version of Zig ({f}) isn't right. :-(
               \\
               \\ESP32 compilation requires zig version {f}
               \\
               \\https://github.com/kassane/zig-espressif-bootstrap/releases/tag/0.14.0-xtensa
               \\
           ;
           @compileError(std.fmt.comptimePrint(error_message, .{current_zig, required_zig}));
       }
}

// Reference: https://github.com/kassane/zig-esp-idf-sample/blob/main/build.zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "blinky",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn isEspXtensa() bool {
    for (std.Target.Cpu.Arch.xtensa.allCpuModels()) |model| {
        const result = std.mem.startsWith(u8, model.name, "esp");
        if (result) return true;
    } else return false;
}
