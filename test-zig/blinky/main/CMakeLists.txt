set(DEPS pthread driver)

idf_component_register(SRCS "empty.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES "${DEPS}"
)

find_program(XZIG_EXE xzig)
if (NOT XZIG_EXE)
    message(
        ERROR
            "Please download the xtensa zig compiler and add it to your path, renamed to 'xzig'"
            "https://github.com/kassane/zig-espressif-bootstrap/releases/tag/0.14.0-xtensa"
    )
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ZIG_BUILD_TYPE "Debug")
else()
    set(ZIG_BUILD_TYPE "ReleaseSafe")
endif()

set(include_dirs $<TARGET_PROPERTY:${COMPONENT_LIB},INCLUDE_DIRECTORIES> ${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES})
add_custom_target(zig_build
    COMMAND ${CMAKE_COMMAND} -E env
        "INCLUDE_DIRS=${include_dirs}"
        ${XZIG_EXE} build
        --build-file ${BUILD_PATH}/build.zig
        -Doptimize=${ZIG_BUILD_TYPE}
        -freference-trace
        --prominent-compile-errors
        --cache-dir ${CMAKE_BINARY_DIR}/../.zig-cache
        --prefix ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    BYPRODUCTS ${CMAKE_BINARY_DIR}/lib/libapp_zig.a
    VERBATIM
)

add_prebuilt_library(zig ${CMAKE_BINARY_DIR}/lib/libapp_zig.a)
add_dependencies(zig zig_build)
target_link_libraries(${COMPONENT_LIB} PRIVATE ${CMAKE_BINARY_DIR}/lib/libapp_zig.a)