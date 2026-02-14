#include <print>
#include <thread>

#include "gpio_cxx.hpp"

using namespace idf;
using namespace std::chrono_literals;

extern "C" auto app_main() -> void {
    const GPIO_Output led{GPIONum(13)};

    while (true) {
        std::println("LED ON");
        led.set_high();
        std::this_thread::sleep_for(1s);

        std::println("LED OFF");
        led.set_low();
        std::this_thread::sleep_for(1s);
    }
}
