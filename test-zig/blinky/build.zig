const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    _ = b.graph.env_map.get("IDF_PATH") orelse return error.MissingIDFPath;
    _ = try b.findProgram(&.{"idf.py"}, &.{});

    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32 },
        .os_tag = .freestanding,
        .abi = .none,
    });

    const lib_blinky = b.addLibrary(.{
        .name = "blinky",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main/main.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        }),
    });
    const blinky_art = b.addInstallArtifact(lib_blinky, .{});

    var reconfigure = b.option(bool, "reconfigure", "Force the reconfigure phase") orelse false;
    const idf_build_dir = b.pathJoin(&.{ b.install_prefix, "esp32" });
    const include_dirs_file = b.pathJoin(&.{ idf_build_dir, "include_dirs.txt" });

    const include_dirs_content: ?[]const u8 = b.build_root.handle.readFileAlloc(
        b.allocator,
        include_dirs_file,
        std.math.maxInt(usize),
    ) catch |err| blk: switch (err) {
        error.FileNotFound => {
            reconfigure = true;
            break :blk null;
        },
        else => return err,
    };

    const includer: *IncludeResolver = .init(
        b,
        lib_blinky,
        if (include_dirs_content) |content|
            .{ .content = content }
        else
            .{ .path = include_dirs_file },
    );
    lib_blinky.step.dependOn(&includer.step);

    if (reconfigure) {
        const configure_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "reconfigure" });
        lib_blinky.step.dependOn(&configure_cmd.step);
        includer.step.dependOn(&configure_cmd.step);
    }

    const idf_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "build" });
    idf_cmd.step.dependOn(&blinky_art.step);
    b.getInstallStep().dependOn(&idf_cmd.step);

    const flash_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "flash" });
    flash_cmd.step.dependOn(&idf_cmd.step);
    const flash_step = b.step("flash", "Flash the binary to the device");
    flash_step.dependOn(&flash_cmd.step);

    const run_step = b.step("run", "Flash the esp32 and open the serial monitor");
    const monitor_runner_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "monitor" });
    monitor_runner_cmd.step.dependOn(&flash_cmd.step);
    run_step.dependOn(&monitor_runner_cmd.step);

    addTooling(b, idf_build_dir);
}

const IncludeResolver = struct {
    pub const IncludeDirs = union(enum) {
        path: []const u8,
        content: []const u8,
    };

    step: std.Build.Step,
    lib: *std.Build.Step.Compile,
    include_dirs: IncludeDirs,

    pub fn init(
        b: *std.Build,
        lib: *std.Build.Step.Compile,
        include_dirs: IncludeDirs,
    ) *IncludeResolver {
        const self = b.allocator.create(IncludeResolver) catch @panic("OOM");
        self.* = .{
            .step = .init(.{
                .id = .custom,
                .name = "idf-scanner",
                .owner = b,
                .makeFn = addIncludePaths,
            }),
            .lib = lib,
            .include_dirs = include_dirs,
        };
        return self;
    }

    pub fn addIncludePaths(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *IncludeResolver = @fieldParentPtr("step", step);

        const b = step.owner;
        const allocator = b.allocator;

        const contents = switch (self.include_dirs) {
            .path => |p| try b.build_root.handle.readFileAlloc(
                allocator,
                p,
                std.math.maxInt(usize),
            ),
            .content => |c| c,
        };
        var seen_set: std.StringHashMap(void) = .init(allocator);
        var it = std.mem.tokenizeScalar(u8, contents, ';');

        while (it.next()) |inc_path| {
            const trimmed = std.mem.trim(u8, inc_path, " \n\r\t");
            if (trimmed.len > 0 and !seen_set.contains(trimmed)) {
                try seen_set.put(trimmed, {});
                self.lib.root_module.addIncludePath(.{ .cwd_relative = trimmed });
            }
        }
        self.lib.root_module.addIncludePath(b.path("include"));
    }
};

fn addTooling(b: *std.Build, idf_build_dir: []const u8) void {
    const fmt = b.addFmt(.{ .paths = &.{ "build.zig", "main" } });
    const fmt_step = b.step("fmt", "Format all zig files");
    fmt_step.dependOn(&fmt.step);

    const monitor_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "monitor" });
    const monitor = b.step("monitor", "Open the serial monitor");
    monitor.dependOn(&monitor_cmd.step);

    const clean_cmd = b.addSystemCommand(&.{ "idf.py", "-B", idf_build_dir, "fullclean" });
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
