#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]

use esp_hal::{
    clock::CpuClock,
    gpio::{Level, Output, OutputConfig},
    main,
    time::{Duration, Instant},
};

use esp_println::println;
esp_bootloader_esp_idf::esp_app_desc!();

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

fn delay(ms: u64) {
    let start = Instant::now();
    while start.elapsed() < Duration::from_millis(ms) {}
}

#[allow(
    clippy::large_stack_frames,
    reason = "it's not unusual to allocate larger buffers etc. in main"
)]
#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    println!("Hello World");

    let mut led = Output::new(peripherals.GPIO13, Level::Low, OutputConfig::default());

    loop {
        led.set_high();
        println!("LED HIGH");
        delay(1000);
        led.set_low();
        println!("LED LOW");
        delay(1000);
    }
}
