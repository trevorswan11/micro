# The following lines of boilerplate have to be in your project's
# CMakeLists in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.5)

set(IDF_TARGET esp32)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
set(BUILD_PATH ${CMAKE_CURRENT_SOURCE_DIR})
project(blinky)
