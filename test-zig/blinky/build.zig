const std = @import("std");
const builtin = @import("builtin");

// Reference: https://github.com/kassane/zig-esp-idf-sample/blob/main/build.zig
pub fn build(b: *std.Build) !void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32 },
        .os_tag = .freestanding,
        .abi = .none,
    });
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "app_zig",
        .root_source_file = b.path("main/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("esp_idf", idf_wrapped_modules(b));
    lib.linkLibC();

    try includeDeps(b, lib);
    b.installArtifact(lib);
}

fn includeDeps(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    const include_dirs = std.process.getEnvVarOwned(b.allocator, "INCLUDE_DIRS") catch "";
    if (!std.mem.eql(u8, include_dirs, "")) {
        var it_inc = std.mem.tokenizeAny(u8, include_dirs, ";");
        while (it_inc.next()) |dir| {
            lib.addIncludePath(.{ .cwd_relative = dir });
        }
    }

    const idf_path = std.process.getEnvVarOwned(b.allocator, "IDF_PATH") catch "";
    if (!std.mem.eql(u8, idf_path, "")) {
        try searched_idf_include(b, lib, idf_path);
        try searched_idf_libs(b, lib);
    }

    const home_dir = std.process.getEnvVarOwned(b.allocator, "HOME") catch "";
    if (!std.mem.eql(u8, home_dir, "")) {
        const archtools = b.fmt("{s}-esp-elf", .{
            @tagName(lib.rootModuleTarget().cpu.arch),
        });

        lib.addIncludePath(.{
            .cwd_relative = b.pathJoin(&.{
                home_dir,
                ".espressif",
                "tools",
                archtools,
                "esp-14.2.0_20241119",
                archtools,
                "include",
            }),
        });
        lib.addSystemIncludePath(.{
            .cwd_relative = b.pathJoin(&.{
                home_dir,
                ".espressif",
                "tools",
                archtools,
                "esp-14.2.0_20241119",
                archtools,
                archtools,
                "sys-include",
            }),
        });
        lib.addIncludePath(.{
            .cwd_relative = b.pathJoin(&.{
                home_dir,
                ".espressif",
                "tools",
                archtools,
                "esp-14.2.0_20241119",
                archtools,
                archtools,
                "include",
            }),
        });
    }

    // user include dirs
    lib.addIncludePath(b.path("include"));
}

pub fn searched_idf_libs(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    var dir = try std.fs.cwd().openDir("../build", .{
        .iterate = true,
    });
    defer dir.close();
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const lib_ext = inline for (&.{".obj"}) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;
        if (lib_ext) {
            const src_path = std.fs.path.dirname(@src().file) orelse b.pathResolve(&.{".."});
            const cwd_path = b.pathJoin(&.{ src_path, "build", b.dupe(entry.path) });
            const lib_file: std.Build.LazyPath = .{ .cwd_relative = cwd_path };
            lib.addObjectFile(lib_file);
        }
    }
}

pub fn searched_idf_include(b: *std.Build, lib: *std.Build.Step.Compile, idf_path: []const u8) !void {
    const comp = b.pathJoin(&.{ idf_path, "components" });
    var dir = try std.fs.cwd().openDir(comp, .{
        .iterate = true,
    });
    defer dir.close();
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
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

pub fn idf_wrapped_modules(b: *std.Build) *std.Build.Module {
    const src_path = std.fs.path.dirname(@src().file) orelse b.pathResolve(&.{"."});
    const sys = b.addModule("sys", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "idf-sys.zig",
        })),
    });
    const rtos = b.addModule("rtos", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "rtos.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const version = b.addModule("ver", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "version.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const log = b.addModule("log", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "logger.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const panic = b.addModule("panic", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "panic.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "log",
                .module = log,
            },
        },
    });
    const led = b.addModule("led", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "led-strip.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const bootloader = b.addModule("bootloader", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "bootloader.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const errors = b.addModule("error", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "error.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const lwip = b.addModule("lwip", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "lwip.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const mqtt = b.addModule("mqtt", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "mqtt.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const heap = b.addModule("heap", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "heap.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const http = b.addModule("http", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "http.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const pcnt = b.addModule("pulse", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "pcnt.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const bt = b.addModule("bluetooth", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "bluetooth.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const wifi = b.addModule("wifi", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "wifi.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const gpio = b.addModule("gpio", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "gpio.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const uart = b.addModule("uart", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "uart.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const i2c = b.addModule("i2c", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "i2c.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const i2s = b.addModule("i2s", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "i2s.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const spi = b.addModule("spi", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "spi.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
            .{
                .name = "error",
                .module = errors,
            },
        },
    });
    const phy = b.addModule("phy", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "phy.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const segger = b.addModule("segger", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "segger.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const dsp = b.addModule("dsp", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "dsp.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    const crc = b.addModule("crc", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "crc.zig",
        })),
        .imports = &.{
            .{
                .name = "sys",
                .module = sys,
            },
        },
    });
    return b.addModule("esp_idf", .{
        .root_source_file = b.path(b.pathJoin(&.{
            src_path,
            "imports",
            "idf.zig",
        })),
        .imports = &.{
            .{
                .name = "led",
                .module = led,
            },
            .{
                .name = "crc",
                .module = crc,
            },
            .{
                .name = "bootloader",
                .module = bootloader,
            },
            .{
                .name = "rtos",
                .module = rtos,
            },
            .{
                .name = "ver",
                .module = version,
            },
            .{
                .name = "lwip",
                .module = lwip,
            },
            .{
                .name = "mqtt",
                .module = mqtt,
            },
            .{
                .name = "panic",
                .module = panic,
            },
            .{
                .name = "log",
                .module = log,
            },
            .{
                .name = "heap",
                .module = heap,
            },
            .{
                .name = "gpio",
                .module = gpio,
            },
            .{
                .name = "uart",
                .module = uart,
            },
            .{
                .name = "i2c",
                .module = i2c,
            },
            .{
                .name = "i2s",
                .module = i2s,
            },
            .{
                .name = "phy",
                .module = phy,
            },
            .{
                .name = "spi",
                .module = spi,
            },
            .{
                .name = "error",
                .module = errors,
            },
            .{
                .name = "wifi",
                .module = wifi,
            },
            .{
                .name = "bluetooth",
                .module = bt,
            },
            .{
                .name = "dsp",
                .module = dsp,
            },
            .{
                .name = "segger",
                .module = segger,
            },
            .{
                .name = "http",
                .module = http,
            },
            .{
                .name = "pulse",
                .module = pcnt,
            },
        },
    });
}

fn isEspXtensa() bool {
    var result = false;
    for (std.Target.Cpu.Arch.xtensa.allCpuModels()) |model| {
        result = std.mem.startsWith(u8, model.name, "esp");
        if (result) break;
    }
    return result;
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
    } else if (!isEspXtensa()) {
        @compileError("Xtensa is not supported by your build of the compiler!");
    }
}
