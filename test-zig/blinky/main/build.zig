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
            .root_source_file = b.path("app.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = true,
            .imports = &.{idf_import},
        }),
    });

    try includeDeps(b, lib_blinky);
    b.installArtifact(lib_blinky);
}

fn includeDeps(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    const idf_path = b.graph.env_map.get("IDF_PATH") orelse @panic("IDF_PATH env var could not be resolved");
    const cmake_install_dir = b.pathJoin(&.{ "..", "zig-out" });
    var build_dir = try b.build_root.handle.openDir(
        cmake_install_dir,
        .{ .iterate = true },
    );
    defer build_dir.close();

    var build_walker = try build_dir.walk(b.allocator);
    defer build_walker.deinit();

    while (try build_walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const lib_ext = inline for (&.{".obj"}) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;
        if (lib_ext) {
            const cwd_path = b.pathJoin(&.{ cmake_install_dir, b.dupe(entry.path) });
            const lib_file: std.Build.LazyPath = .{ .cwd_relative = cwd_path };
            lib.addObjectFile(lib_file);
        }
    }

    const comp = b.pathJoin(&.{ idf_path, "components" });
    var component_dir = try std.fs.cwd().openDir(comp, .{
        .iterate = true,
    });
    defer component_dir.close();
    var component_walker = try component_dir.walk(b.allocator);
    defer component_walker.deinit();

    while (try component_walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = inline for (&.{".h"}) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;
        if (include_file) {
            const include_dir = b.pathJoin(&.{ comp, std.fs.path.dirname(b.dupe(entry.path)).? });
            lib.addIncludePath(.{ .cwd_relative = include_dir });
        }
    }
}

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
            .root_source_file = b.path(b.pathJoin(&.{ "esp32", m.file })),
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
        .root_source_file = b.path(b.pathJoin(&.{ "esp32", "idf.zig" })),
        .optimize = config.optimize,
        .target = config.target,
    });

    for (module_map.keys(), module_map.values()) |name, mod| {
        esp_mod.addImport(name, mod);
    }

    return .{ .name = "esp_idf", .module = esp_mod };
}
