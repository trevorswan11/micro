const std = @import("std");
const builtin = @import("builtin");

// Reference: https://github.com/kassane/zig-esp-idf-sample/blob/main/build.zig
pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32 },
        .os_tag = .freestanding,
        .abi = .none,
    });

    const idf_import = makeIDFImport(b, .{
        .optimize = optimize,
        .target = target,
    });

    const lib_blinky = b.addLibrary(.{
        .name = "blinky",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main/app.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = true,
            .imports = &.{idf_import},
        }),
    });
    lib_blinky.addIncludePath(b.path("include"));

    const idf_build_dir = b.pathJoin(&.{ b.install_prefix, "esp32" });
    const idf_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "build" });
    b.getInstallStep().dependOn(&idf_cmd.step);

    const clean_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "fullclean" });
    const clean = b.step("clean", "Clean idf artifacts");
    clean.dependOn(&clean_cmd.step);

    const flash_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "flash" });
    flash_cmd.step.dependOn(&idf_cmd.step);
    const flash_step = b.step("flash", "Flash the binary to the device");
    flash_step.dependOn(&flash_cmd.step);

    const monitor_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "monitor" });
    const monitor = b.step("monitor", "Open the serial monitor");
    monitor.dependOn(&monitor_cmd.step);

    const idf_path = std.process.getEnvVarOwned(b.allocator, "IDF_PATH") catch @panic("IDF_PATH env var could not be resolved");
    const scanner = IDFScanner.init(b, "esp32", lib_blinky, idf_path);
    scanner.step.dependOn(&idf_cmd.step);
    lib_blinky.step.dependOn(&scanner.step);

    b.installArtifact(lib_blinky);
}

const IDFScanner = struct {
    step: std.Build.Step,
    lib_blinky: *std.Build.Step.Compile,

    esp32_build_dirname: []const u8,
    idf_path: []const u8,

    pub fn init(
        b: *std.Build,
        esp32_build_dirname: []const u8,
        lib_blinky: *std.Build.Step.Compile,
        idf_path: []const u8,
    ) *IDFScanner {
        const self = b.allocator.create(IDFScanner) catch @panic("OOM");
        self.* = .{
            .step = .init(.{
                .id = .custom,
                .name = "idf-scanner",
                .owner = b,
                .makeFn = scan,
            }),
            .lib_blinky = lib_blinky,
            .esp32_build_dirname = esp32_build_dirname,
            .idf_path = idf_path,
        };
        return self;
    }

    pub fn scan(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *IDFScanner = @fieldParentPtr("step", step);

        const b = step.owner;
        const allocator = b.allocator;

        const build_dir_path: std.Build.LazyPath = .{
            .cwd_relative = b.pathJoin(&.{ b.install_prefix, self.esp32_build_dirname }),
        };
        var build_dir = try b.build_root.handle.openDir(
            b.pathJoin(&.{ "zig-out", self.esp32_build_dirname }),
            .{ .iterate = true },
        );
        defer build_dir.close();

        var walker = try build_dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".obj")) {
                self.lib_blinky.addObjectFile(build_dir_path.path(b, entry.path));
            }
        }

        const comp_path = b.pathJoin(&.{ self.idf_path, "components" });
        var comp_dir = try std.fs.openDirAbsolute(comp_path, .{ .iterate = true });
        defer comp_dir.close();

        var inc_walker = try comp_dir.walk(allocator);
        defer inc_walker.deinit();

        while (try inc_walker.next()) |entry| {
            if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".h")) {
                if (std.fs.path.dirname(entry.path)) |dir| {
                    const full_inc_path = b.pathJoin(&.{ comp_path, dir });
                    self.lib_blinky.addIncludePath(.{ .cwd_relative = b.dupe(full_inc_path) });
                }
            }
        }
    }
};

fn makeIDFImport(b: *std.Build, config: struct {
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
}) std.Build.Module.Import {
    const IDFModuleDef = struct {
        name: []const u8,
        file: []const u8,
        deps: []const []const u8 = &.{},
    };

    const modules = [_]IDFModuleDef{
        .{ .name = "sys", .file = "idf-sys.zig" },
        .{ .name = "error", .file = "error.zig", .deps = &.{"sys"} },
        .{ .name = "rtos", .file = "rtos.zig", .deps = &.{"sys"} },
        .{ .name = "ver", .file = "version.zig", .deps = &.{"sys"} },
        .{ .name = "log", .file = "logger.zig", .deps = &.{"sys"} },
        .{ .name = "panic", .file = "panic.zig", .deps = &.{ "sys", "log" } },
        .{ .name = "led", .file = "led-strip.zig", .deps = &.{"sys"} },
        .{ .name = "bootloader", .file = "bootloader.zig", .deps = &.{"sys"} },
        .{ .name = "lwip", .file = "lwip.zig", .deps = &.{"sys"} },
        .{ .name = "mqtt", .file = "mqtt.zig", .deps = &.{"sys"} },
        .{ .name = "heap", .file = "heap.zig", .deps = &.{"sys"} },
        .{ .name = "http", .file = "http.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "pulse", .file = "pcnt.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "bluetooth", .file = "bluetooth.zig", .deps = &.{"sys"} },
        .{ .name = "wifi", .file = "wifi.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "gpio", .file = "gpio.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "uart", .file = "uart.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "i2c", .file = "i2c.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "i2s", .file = "i2s.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "spi", .file = "spi.zig", .deps = &.{ "sys", "error" } },
        .{ .name = "phy", .file = "phy.zig", .deps = &.{"sys"} },
        .{ .name = "segger", .file = "segger.zig", .deps = &.{"sys"} },
        .{ .name = "dsp", .file = "dsp.zig", .deps = &.{"sys"} },
        .{ .name = "crc", .file = "crc.zig", .deps = &.{"sys"} },
    };

    var module_map = std.StringArrayHashMap(*std.Build.Module).init(b.allocator);
    for (modules) |m| {
        const mod = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{ "imports", m.file })),
            .optimize = config.optimize,
            .target = config.target,
        });
        module_map.put(m.name, mod) catch @panic("OOM");
    }

    for (modules) |m| {
        const mod = module_map.get(m.name).?;
        for (m.deps) |dep_name| {
            mod.addImport(dep_name, module_map.get(dep_name).?);
        }
    }

    const esp_mod = b.createModule(.{
        .root_source_file = b.path("imports/idf.zig"),
        .optimize = config.optimize,
        .target = config.target,
    });

    for (module_map.keys(), module_map.values()) |name, mod| {
        esp_mod.addImport(name, mod);
    }

    return .{ .name = "esp_idf", .module = esp_mod };
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
