set(DEPS pthread driver)

idf_component_register(SRCS "esp32/empty.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES "${DEPS}"
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ZIG_BUILD_TYPE "Debug")
else()
    set(ZIG_BUILD_TYPE "ReleaseSafe")
endif()

find_program(XZIG_EXE xzig)

set(lib_artifact ${CMAKE_BINARY_DIR}/lib/libblinky.a)
set(include_dirs
    $<TARGET_PROPERTY:${COMPONENT_LIB},INCLUDE_DIRECTORIES>
    ${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES}
)

add_custom_target(zig_build
    COMMAND ${CMAKE_COMMAND} -E env
        "INCLUDE_DIRS=${include_dirs}"
        ${XZIG_EXE} build
        --build-file ${BUILD_PATH}/main/build.zig
        -Doptimize=${ZIG_BUILD_TYPE}
        -freference-trace
        --prominent-compile-errors
        --cache-dir ${CMAKE_BINARY_DIR}/.zig-cache
        --prefix ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    BYPRODUCTS ${lib_artifact}
    VERBATIM
)

add_prebuilt_library(zig ${lib_artifact})
add_dependencies(zig zig_build)
target_link_libraries(${COMPONENT_LIB} PRIVATE ${lib_artifact})
