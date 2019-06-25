add_library(rlottie-image-loader SHARED
            stb_image.cpp
           )
install(TARGETS rlottie-image-loader
        LIBRARY DESTINATION ${LIB_INSTALL_DIR}
        ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
       )
