target_sources(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_math.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_raster.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_stroker.cpp"
    )

target_include_directories(lottie-player
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )