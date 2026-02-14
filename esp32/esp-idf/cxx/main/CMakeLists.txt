set(DEPS pthread driver)

idf_component_register(SRCS "potion.cpp"
    INCLUDE_DIRS "."
    PRIV_REQUIRES "${DEPS}"
)

set(IMPLICIT_C_INC "$<JOIN:${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES},;>")
set(IMPLICIT_CXX_INC "$<JOIN:${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES},;>")
set(TARGET_INC
    "$<JOIN:$<TARGET_PROPERTY:${COMPONENT_LIB},INCLUDE_DIRECTORIES>,;>"
)

set(INCLUDE_PATH_FILE "${CMAKE_BINARY_DIR}/include_dirs.txt")
file(GENERATE
    OUTPUT "${INCLUDE_PATH_FILE}"
    CONTENT "${TARGET_INC};${IMPLICIT_INC};${IMPLICIT_CXX_INC}"
)

add_custom_target(fix_clangd
    COMMAND ${PYTHON} "${CMAKE_SOURCE_DIR}/scripts/resolve_includes.py"
        "${CMAKE_BINARY_DIR}/compile_commands.json"
        ${INCLUDE_PATH_FILE}
    DEPENDS "${INCLUDE_PATH_FILE}"
    COMMENT "Resolving C/C++ includes..."
    VERBATIM
)

add_dependencies(${COMPONENT_LIB} fix_clangd)
