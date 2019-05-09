add_executable(lottie-gif "lottie2gif.cpp")

target_compile_options(lottie-gif
                       PRIVATE
                       -std=c++11)

target_link_libraries(lottie-gif rlottie)

target_include_directories(lottie-gif
                           PRIVATE
                           "${CMAKE_CURRENT_LIST_DIR}/../inc/")
