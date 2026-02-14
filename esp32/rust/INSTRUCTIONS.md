## Installing Deps
1. cargo install espup --locked
2. espup install
    - On windows, it should automatically update your path
    - Otherwise, you may need to run the export script in $HOME/export-esp.sh
3. cargo install espflash cargo-espflash --locked
4. cargo install esp-generate --locked
5. If you were making a new project, `esp-generate --chip esp32 my-project`

## Flashing the ESP32
- `cargo run --release` should work, but it fails on my machine
