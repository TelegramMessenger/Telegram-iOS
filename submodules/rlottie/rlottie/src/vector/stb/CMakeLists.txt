if(LOTTIE_MODULE)
    add_library(rlottie-image-loader SHARED
                stb_image.cpp
               )
    target_compile_options(rlottie-image-loader PRIVATE
                           -fvisibility=hidden
                          )
    set_target_properties(rlottie-image-loader PROPERTIES
                          DEFINE_SYMBOL LOT_BUILD
                         )
    install(TARGETS rlottie-image-loader
            LIBRARY DESTINATION ${LIB_INSTALL_DIR}
            ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
           )
else()
    target_sources(rlottie
        PRIVATE
            "${CMAKE_CURRENT_LIST_DIR}/stb_image.cpp"
        )
endif()
