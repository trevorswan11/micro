const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    // const optimize = b.standardOptimizeOption(.{});
    const xzig = std.mem.trimRight(u8, std.fs.path.basename(b.graph.zig_exe), ".exe");
    if (!std.mem.eql(u8, xzig, "xzig")) {
        std.debug.print(
            \\CMake requires the xtensa zig compiler to be available in your path with the name 'xzig'.
            \\  The executable being used to run this build is {s}
        , .{b.graph.zig_exe});
        return error.InvalidZigBinary;
    }

    const fmt = b.addFmt(.{ .paths = &.{ "build.zig", "main", "include" } });
    const fmt_step = b.step("fmt", "Format all zig files");
    fmt_step.dependOn(&fmt.step);

    const build_dir = "zig-out";
    const idf_cmd = b.addSystemCommand(&.{ "idf.py", "-B", build_dir, "build" });
    b.getInstallStep().dependOn(&idf_cmd.step);

    const flash_cmd = b.addSystemCommand(&.{ "idf.py", "-B", build_dir, "flash" });
    flash_cmd.step.dependOn(&idf_cmd.step);
    const flash_step = b.step("flash", "Flash the binary to the device");
    flash_step.dependOn(&flash_cmd.step);

    const monitor_cmd = b.addSystemCommand(&.{ "idf.py", "-B", build_dir, "monitor" });
    const monitor = b.step("monitor", "Open the serial monitor");
    monitor.dependOn(&monitor_cmd.step);

    const clean_cmd = b.addSystemCommand(&.{ "idf.py", "-B", build_dir, "fullclean" });
    const clean = b.step("clean", "Clean idf artifacts");
    clean.dependOn(&clean_cmd.step);
}

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
        @compileError(std.fmt.comptimePrint(error_message, .{ current_zig, required_zig }));
    }

    const xtensa_supported = blk: {
        for (std.Target.Cpu.Arch.xtensa.allCpuModels()) |model| {
            if (std.mem.startsWith(u8, model.name, "esp")) break :blk true;
        } else break :blk false;
    };

    if (!xtensa_supported) {
        @compileError("Xtensa is not supported by your build of the compiler!");
    }
}
