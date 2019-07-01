add_executable(lottie2gif "lottie2gif.cpp")

target_compile_options(lottie2gif
                       PRIVATE
                       -std=c++11)

target_link_libraries(lottie2gif rlottie)

target_include_directories(lottie2gif
                           PRIVATE
                           "${CMAKE_CURRENT_LIST_DIR}/../inc/")
