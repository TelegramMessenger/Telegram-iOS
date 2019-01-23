target_sources(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/vregion.cpp"
    )

IF("${ARCH}" STREQUAL "arm")
SET(CMAKE_ASM_FLAGS "${CFLAGS} -x assembler-with-cpp")
target_sources(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/pixman-arm-neon-asm.S"
    )
ENDIF("${ARCH}" STREQUAL "arm")

target_include_directories(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
