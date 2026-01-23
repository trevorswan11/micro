const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn main() !void {
    pin_config.apply();
    const pin = gpio.num(25);

    while (true) {
        pin.toggle();
        time.sleep_ms(500);
    }
}
