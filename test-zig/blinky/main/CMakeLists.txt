set(DEPS pthread driver)

idf_component_register(SRCS "empty.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES "${DEPS}"
)

set(LIB_ARTIFACT "${CMAKE_BINARY_DIR}/../lib/libblinky.a")
target_link_libraries(${COMPONENT_LIB} PRIVATE ${LIB_ARTIFACT})
