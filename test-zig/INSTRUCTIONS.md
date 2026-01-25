# ESP-IDF
Since Zig has strong c integration, this example attempts to be a wrapper over the esp-idf library. Thus, you must have ESP-IDF installed on your system. You can read more about that [here](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/index.html). This means you must also have the `IDF_PATH` environment variable set as the build system is going to look for it.

You must also have a custom zig version installed since zig uses LLVM's HEAD which does not support Xtensa yet. You can download precompiled releases of the required Zig binary and standard library [here](https://github.com/kassane/zig-espressif-bootstrap/releases). For the purposes of these instructions, `zig` is assumed to be this fork.

After that, compiling _should_ be as easy as running `zig build`. All commands:
- `zig build` Builds the entire app, including all ESP-IDF dependencies and components required
- `zig build flash` Builds the entire app and then flashes the board (auto detected)
- `zig build monitor` Hooks into the serial monitor of the connected board (does not reflash or rebuild)
- `zig build clean` Runs the equivalent of `fullclean` through `idf.py`
- `zig build fmt` Enforce canonical formatting on all zig project files
- `-Dreconfigure` This is an option that should be used if any build system changes are made after the first project configuration. It forces the reconfigure phase of the build system, which is generally not needed. If the include directory list file is not found, then this is automatically set to true, but is false by default otherwise.

Keep in mind that this is not the latest version of Zig, specifically, the compiler fork we are using here is based on Zig 0.14.0, which was released mid-2025. This does not matter much for the purposes of this repository and associated work, though. Since we are using an older version of zig, you must also match zls to be 0.14.0. I do this in a project specific `.zed` file, but it will be different per editor.

For example:
```json
{
    "lsp": {
        "zls": {
            "binary": {
                "path": "/Users/trevor/esp/xtensa-zig/zls/zls",
            },
            "settings": {
                "zls": {
                    "zig_exe_path": "/Users/trevor/esp/xtensa-zig/zig/zig",
                }
            }
        }
    }
}
```

ZLS is probably still going to warn you about using 0.14.0-xtensa with 0.14.0, but its ok!

_The build system here is a heavily modified version of the one found [here](https://github.com/kassane/zig-esp-idf-sample). It was used for reference throughout this process, and the zig wrappers it provides are used in this example._
