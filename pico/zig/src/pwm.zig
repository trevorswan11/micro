const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const pwm = microzig.chip.peripherals.PWM;

const pin_config: rp2xxx.pins.GlobalConfiguration = .{
    .GPIO15 = .{
        .name = "led",
        .direction = .out,
        .function = .PWM7_B,
    },
};
const pins = pin_config.pins();

const LOW: u1 = 0;
const HIGH: u1 = 1;

// Nuked example from microzig, for some reason
pub fn main() !void {
    pin_config.apply();
    pins.led.slice().set_wrap(100);
    pins.led.slice().enable();

    while (true) {
        for (0..101) |level| {
            pins.led.set_level(@truncate(level));
            time.sleep_ms(10);
        }
        for (1..100) |level| {
            pins.led.set_level(@truncate(100 - level));
            time.sleep_ms(10);
        }
    }
}
