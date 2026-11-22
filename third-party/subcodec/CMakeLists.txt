cmake_minimum_required(VERSION 3.16)
project(subcodec C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# OpenH264 root — sibling directory in telegram-ios/third-party/
set(OH264_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../openh264/third_party/openh264/src/codec"
    CACHE PATH "Path to OpenH264 codec source directory")

if(NOT EXISTS "${OH264_ROOT}/api/wels/codec_api.h")
    message(FATAL_ERROR "OpenH264 not found at ${OH264_ROOT}. "
        "Expected sibling directory: ../openh264/third_party/openh264/src/codec/")
endif()

# Find FFmpeg via pkg-config (required)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
    libavcodec
    libavformat
    libavutil
    libswscale
)

# --- OpenH264 (from sibling directory) ---

# Common sources (shared by encoder and decoder)
file(GLOB OH264_COMMON_SOURCES ${OH264_ROOT}/common/src/*.cpp)
list(FILTER OH264_COMMON_SOURCES EXCLUDE REGEX "(_neon|_mmi|_msa|_lsx|_lasx)")

add_library(oh264_common STATIC ${OH264_COMMON_SOURCES})
set_target_properties(oh264_common PROPERTIES CXX_STANDARD 11)
target_compile_options(oh264_common PRIVATE -w)
target_include_directories(oh264_common PUBLIC
    ${OH264_ROOT}/api/wels
    ${OH264_ROOT}/common/inc
)

# Processing sources
file(GLOB_RECURSE OH264_PROCESSING_SOURCES ${OH264_ROOT}/processing/src/*.cpp)
list(FILTER OH264_PROCESSING_SOURCES EXCLUDE REGEX "(_neon|_mmi|_msa|_lsx|_lasx|loongarch)")

add_library(oh264_processing STATIC ${OH264_PROCESSING_SOURCES})
set_target_properties(oh264_processing PROPERTIES CXX_STANDARD 11)
target_compile_options(oh264_processing PRIVATE -w)
target_link_libraries(oh264_processing PRIVATE oh264_common)
target_include_directories(oh264_processing PRIVATE
    ${OH264_ROOT}/processing/interface
    ${OH264_ROOT}/processing/src/common
)

# Encoder sources
file(GLOB OH264_ENCODER_SOURCES ${OH264_ROOT}/encoder/core/src/*.cpp)
list(FILTER OH264_ENCODER_SOURCES EXCLUDE REGEX "(_neon|_mmi|_msa|_lsx|_lasx)")
list(APPEND OH264_ENCODER_SOURCES ${OH264_ROOT}/encoder/plus/src/welsEncoderExt.cpp)

add_library(oh264_encoder STATIC ${OH264_ENCODER_SOURCES})
set_target_properties(oh264_encoder PROPERTIES CXX_STANDARD 11)
target_compile_options(oh264_encoder PRIVATE -w)
target_link_libraries(oh264_encoder PRIVATE oh264_common oh264_processing)
target_include_directories(oh264_encoder PRIVATE
    ${OH264_ROOT}/encoder/core/inc
    ${OH264_ROOT}/encoder/plus/inc
    ${OH264_ROOT}/processing/interface
)

# Decoder sources
file(GLOB OH264_DECODER_SOURCES
    ${OH264_ROOT}/decoder/core/src/*.cpp
    ${OH264_ROOT}/decoder/plus/src/*.cpp
)
list(FILTER OH264_DECODER_SOURCES EXCLUDE REGEX "(_neon|_mmi|_msa|_lsx|_lasx|DllEntry)")

add_library(oh264_decoder STATIC ${OH264_DECODER_SOURCES})
set_target_properties(oh264_decoder PROPERTIES CXX_STANDARD 11)
target_compile_options(oh264_decoder PRIVATE -w)
target_link_libraries(oh264_decoder PRIVATE oh264_common)
target_include_directories(oh264_decoder PRIVATE
    ${OH264_ROOT}/decoder/core/inc
    ${OH264_ROOT}/decoder/plus/inc
)

# Umbrella interface library
add_library(openh264 INTERFACE)
target_link_libraries(openh264 INTERFACE oh264_encoder oh264_decoder oh264_common oh264_processing)
target_include_directories(openh264 INTERFACE ${OH264_ROOT}/api/wels)

# --- Vendored h264bitstream ---

add_library(h264bitstream STATIC
    third_party/h264bitstream/h264_stream.c
    third_party/h264bitstream/h264_nal.c
    third_party/h264bitstream/h264_sei.c
)
target_include_directories(h264bitstream PUBLIC third_party/h264bitstream)

# --- Core subcodec library ---

add_library(subcodec STATIC
    src/frame_writer.cpp
    src/cavlc.cpp
    src/h264_parser.cpp
    src/sprite_data.cpp
    src/mbs_encode.cpp
    src/mbs_mux_common.cpp
    src/mux_surface.cpp
)
target_include_directories(subcodec PUBLIC src)
target_link_libraries(subcodec PUBLIC h264bitstream)

# --- Sprite encoder library (OpenH264 wrapper) ---

add_library(sprite_encode STATIC src/sprite_encode.cpp src/sprite_extractor.cpp)
target_compile_options(sprite_encode PRIVATE -w)
target_link_libraries(sprite_encode PUBLIC subcodec openh264)
target_include_directories(sprite_encode PUBLIC src)

# --- Tools (require FFmpeg) ---

add_executable(sprite_extract tools/sprite_extract.cpp)
target_link_libraries(sprite_extract sprite_encode PkgConfig::LIBAV)

add_executable(sprite_mux tools/sprite_mux.cpp)
target_link_libraries(sprite_mux subcodec)
target_include_directories(sprite_mux PRIVATE src)

add_executable(bench_profile tools/bench_profile.cpp)
target_link_libraries(bench_profile sprite_encode PkgConfig::LIBAV)
target_compile_options(bench_profile PRIVATE -w)

# --- Fixture generation ---

add_executable(generate_fixtures Tests/SubcodecTests/generate_fixtures.cpp)

set(FIXTURE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Tests/SubcodecTests/Fixtures)

add_custom_target(fixtures
    COMMAND ${CMAKE_COMMAND} -E make_directory ${FIXTURE_DIR}
    COMMAND $<TARGET_FILE:generate_fixtures> ${FIXTURE_DIR}
    DEPENDS generate_fixtures
    COMMENT "Generating YUV test fixtures in Tests/SubcodecTests/Fixtures/"
)

# --- Tests ---

# Core tests (link subcodec only)
set(CORE_TESTS
    test_cavlc test_cavlc_read test_cavlc_split test_ct_lut
    test_mb_p16x16 test_mb_i16x16
    test_p_frame_ex test_idr_frame_ex test_h264_parse
    test_mbs_format test_mbs_encode
    test_bs_copy_bits test_ebsp_writer test_rbsp_writer
    test_row_plans test_mux_perf
)

foreach(t ${CORE_TESTS})
    add_executable(${t} test/${t}.cpp)
    target_link_libraries(${t} subcodec)
    target_include_directories(${t} PRIVATE src third_party/h264bitstream)
endforeach()

# E2E tests (link sprite_encode = subcodec + openh264)
set(E2E_TESTS
    test_mux test_mux_surface test_mux_alpha
    test_cavlc_diag test_sprite_extractor test_sprite_encode_alpha
    test_high_profile test_ipcm test_resize
)

foreach(t ${E2E_TESTS})
    add_executable(${t} test/${t}.cpp)
    target_link_libraries(${t} sprite_encode)
endforeach()

# --- CTest registration ---

enable_testing()

foreach(t ${CORE_TESTS} ${E2E_TESTS})
    add_test(NAME ${t} COMMAND ${t})
endforeach()
