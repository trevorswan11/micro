const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");

extern "c" fn printf(format: [*:0]const u8, ...) c_int;

const log = std.log.scoped(.@"esp-idf");

pub const panic = idf.panic;
pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = idf.espLogFn,
};

const blink_duration_ms = 1000;

export fn app_main() callconv(.C) void {
    var heap: idf.heap.HeapCapsAllocator = .init(.MALLOC_CAP_8BIT);
    if (builtin.mode == .Debug) heap.dump();
    _ = idf.sys.esp_log_level_set("esp-idf", .ESP_LOG_VERBOSE);

    _ = printf("=== APP_MAIN STARTED ===\n");

    idf.gpio.Direction.set(
        .GPIO_NUM_13,
        .GPIO_MODE_OUTPUT,
    ) catch @panic("GPIO init failure");
    log.info("GPIO 13 configured as output", .{});

    if (idf.xTaskCreate(blinkTask, "blink", 1024 * 2, null, 5, null) == 0) {
        _ = printf("ERROR: Failed to create blink task\n");
        @panic("Task creation failed");
    }

    _ = printf("=== APP_MAIN ENDED ===\n");
}

export fn blinkTask(_: ?*anyopaque) void {
    log.info("Blink task started!", .{});

    while (true) {
        log.info("LED: ON", .{});
        idf.gpio.Level.set(.GPIO_NUM_13, 1) catch @panic("GPIO set HI failure");
        idf.vTaskDelay(blink_duration_ms / idf.portTICK_PERIOD_MS);

        log.info("LED: OFF", .{});
        idf.gpio.Level.set(.GPIO_NUM_13, 0) catch @panic("GPIO set LO failure");
        idf.vTaskDelay(blink_duration_ms / idf.portTICK_PERIOD_MS);
    }
}
