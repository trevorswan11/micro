# ESP-IDF
This is the lord's way of doing things.

To get started, download the necessary system dependencies by following the instructions provided by [esp-idf](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/index.html).

Once you have `esp-idf` and have the dev environment enabled, create a project:
- `idf.py create-project <proj_name>` - Replace <proj_name> with your desired project
- `cd <proj_name>` 
- `idf.py add-dependency espressif/esp-idf-cxx^1.0.0-beta` - Add C++ dependency if desired (only run once)
- `idf.py build` - Try to build the project (has nothing in it yet but it should compile)
- You can then flash by running `idf.py flash` but this won't do much since you only have a single empty source

Once you have a project, read the documentation for your use case.

You can try running the code in the repository by doing `idf.py build` and then flashing it with `idf.py flash`. If flashing is successful, then you should see the LED on the board blinking :)
