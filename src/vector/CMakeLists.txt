add_subdirectory(freetype)
add_subdirectory(pixman)
add_subdirectory(stb)


target_sources(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/vrect.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdasher.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vbrush.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vbitmap.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vpainter.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vcompositionfunctions.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdrawhelper.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdrawhelper_sse2.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdrawhelper_neon.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vrle.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vpath.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vpathmesure.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vmatrix.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/velapsedtimer.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdebug.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vinterpolator.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vbezier.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vraster.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vdrawable.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/vimageloader.cpp"
    )

target_include_directories(rlottie
    PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
    )
