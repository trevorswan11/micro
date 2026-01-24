# ESP-IDF
Since Zig has strong c integration, this example attempts to be a wrapper over the esp-idf library. Thus, you must have ESP-IDF installed on your system. You can read more about that [here](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/index.html). This means you must also have the `IDF_PATH` environment variable set as the build system is going to look for it.

You must also have a custom zig version installed since zig uses LLVM's HEAD which does not support Xtensa yet. You can download precompiled releases of the required Zig binary and standard library [here](https://github.com/kassane/zig-espressif-bootstrap/releases).

After that, compiling _should_ be as easy as running `xzig build` (`xzig` is _required_ to be the custom zig binary). Since you are already in an environment with IDF, you can flash the board with `xzig build flash`. Also keep in mind that this is not the latest version of Zig, specifically, the compiler fork we are using here is based on Zig 0.14.0, which was released mid-2025. This does not matter much for the purposes of this repository and associated work, though. Since we are using an older version of zig, you must also match zls to be 0.14.0. I do this in a project specific `.zed` file, but it will be different per editor.

For example:
```json
{
    "lsp": {
        "zls": {
            "binary": {
                "path": "/Users/trevor/esp/xtensa-zig/zls/xzls",
            },
            "settings": {
                "zls": {
                    "zig_exe_path": "/Users/trevor/esp/xtensa-zig/zig/xzig",
                }
            }
        }
    }
}
```

ZLS is probably still going to warn you about using 0.14.0-xtensa with 0.14.0, but its ok!
