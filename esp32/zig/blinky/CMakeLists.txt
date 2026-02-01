cmake_minimum_required(VERSION 3.15)

set(IDF_TARGET esp32)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
set(BUILD_PATH ${CMAKE_CURRENT_SOURCE_DIR})
project(blinky)
