target_sources(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/vregion.cpp"
    )

IF("${ARCH}" STREQUAL "arm")
SET(CMAKE_ASM_FLAGS "${CFLAGS} -x assembler-with-cpp")
target_sources(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/pixman-arm-neon-asm.S"
    )
ENDIF("${ARCH}" STREQUAL "arm")

target_include_directories(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
