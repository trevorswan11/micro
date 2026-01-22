## Installing Deps
1. cargo install espup --locked
2. espup install
    - On windows, it should automatically update your path
    - Otherwise, you may need to run the export script in $HOME/export-esp.sh
3. cargo install espflash cargo-espflash --locked
4. cargo install esp-generate --locked
5. If you were making a new project, `esp-generate --chip esp32 my-project`

## Flashing the ESP32
- `cargo run --release` should work, but it fails on my machine. I've found this can flash: `espflash flash --monitor --chip esp32 --baud 74880 --flash-mode dio --flash-freq 40mhz --no-verify target\xtensa-esp32-none-elf\release\blinky` but it fails to boot
- This is ran from the `blinky` directory
- The error is:
```shell
rst:0x10 (RTCWDT_RTC_RESET),boot:0x37 (SPI_FAST_FLASH_BOOT)
configsip: 271414342, SPIWP:0xee
clk_drv:0x00,q_drv:0x00,d_drv:0x00,cs0_drv:0x00,hd_drv:0x00,wp_drv:0x00
mode:DIO, clock div:2
load:0x3fff0030,len:6384
load:0x40078000,len:15916
load:0x40080400,len:3920
csum err:0x6a!=0x18
ets_main.c 384
ets Jul 29 2019 12:21:46
```

I'm lost.
