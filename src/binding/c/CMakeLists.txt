target_sources(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/lottieanimation_capi.cpp"
    )

target_include_directories(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
