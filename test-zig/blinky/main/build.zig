const std = @import("std");
const builtin = @import("builtin");

// Reference: https://github.com/kassane/zig-esp-idf-sample/blob/main/build.zig
pub fn build(b: *std.Build) !void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32 },
        .os_tag = .freestanding,
        .abi = .none,
    });

    const esp_idf_mod = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const idf_import: std.Build.Module.Import = .{ .name = "idf", .module = esp_idf_mod };

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

    // try includeDeps(b, lib_blinky);
    b.installArtifact(lib_blinky);

    const lib_check = b.addLibrary(.{
        .name = "check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("app.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{idf_import},
            .link_libc = true,
        }),
    });

    b.getInstallStep().dependOn(&lib_check.step);
}

fn includeDeps(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    const idf_path = b.dupe(b.graph.env_map.get("IDF_PATH").?);
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
