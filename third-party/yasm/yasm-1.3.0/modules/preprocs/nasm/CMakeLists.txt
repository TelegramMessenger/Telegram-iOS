add_executable(genversion preprocs/nasm/genversion.c)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/version.mac
    COMMAND $<TARGET_FILE:genversion> ${CMAKE_CURRENT_BINARY_DIR}/version.mac
    DEPENDS genversion
    )

YASM_GENMACRO(
    ${CMAKE_CURRENT_BINARY_DIR}/version.mac
    ${CMAKE_CURRENT_BINARY_DIR}/nasm-version.c
    nasm_version_mac
    )

SET_SOURCE_FILES_PROPERTIES(preprocs/nasm/nasm-preproc.c PROPERTIES
    OBJECT_DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/nasm-version.c
    )

YASM_ADD_MODULE(preproc_nasm
    preprocs/nasm/nasm-preproc.c
    preprocs/nasm/nasm-pp.c
    preprocs/nasm/nasmlib.c
    preprocs/nasm/nasm-eval.c
    )

