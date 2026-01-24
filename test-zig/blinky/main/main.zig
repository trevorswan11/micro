const std = @import("std");
const builtin = @import("builtin");

const idf = @import("idf.zig");

const sys = idf.sys;
const log = std.log.scoped(.@"esp-idf");

const c = @cImport({
    @cInclude("sdkconfig.h");
});

pub const panic = idf.panic;
pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = idf.logger.espLogFn,
};

const blink_duration_ms = 1000;

export fn app_main() callconv(.C) void {
    log.info("Hello, {s}!", .{c.CONFIG_LWIP_LOCAL_HOSTNAME});

    idf.gpio.Direction.set(
        .GPIO_NUM_13,
        .GPIO_MODE_OUTPUT,
    ) catch @panic("GPIO init failure");
    log.info("GPIO 13 configured as output", .{});

    if (sys.xTaskCreate(blinkTask, "blink", 1024 * 2, null, 5, null) == 0) {
        @panic("Task creation failed");
    }
}

export fn blinkTask(_: ?*anyopaque) void {
    log.info("Blink task started!", .{});

    while (true) {
        log.info("LED: ON", .{});
        idf.gpio.Level.set(.GPIO_NUM_13, 1) catch @panic("GPIO set HI failure");
        sys.vTaskDelay(blink_duration_ms / sys.portTICK_PERIOD_MS);

        log.info("LED: OFF", .{});
        idf.gpio.Level.set(.GPIO_NUM_13, 0) catch @panic("GPIO set LO failure");
        sys.vTaskDelay(blink_duration_ms / sys.portTICK_PERIOD_MS);
    }
}
