target_sources(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_math.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_raster.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/v_ft_stroker.cpp"
    )

target_include_directories(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
