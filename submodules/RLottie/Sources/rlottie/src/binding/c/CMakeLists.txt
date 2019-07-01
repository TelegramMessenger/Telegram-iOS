target_sources(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/lottieanimation_capi.cpp"
    )

target_include_directories(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
