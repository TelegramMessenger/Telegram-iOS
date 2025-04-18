# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# ICC detection library used by the comparison and viewer tools.
if(JPEGXL_ENABLE_VIEWERS)
if(WIN32)
  find_package(Qt6 QUIET COMPONENTS Widgets)
  if (NOT Qt6_FOUND)
    message(WARNING "Qt6 was not found.")
  else()
    add_library(icc_detect STATIC EXCLUDE_FROM_ALL
      icc_detect/icc_detect_win32.cc
      icc_detect/icc_detect.h
    )
    target_include_directories(icc_detect PRIVATE "${PROJECT_SOURCE_DIR}")
    target_link_libraries(icc_detect PUBLIC Qt6::Widgets)
    if(JPEGXL_DEP_LICENSE_DIR)
      configure_file("${JPEGXL_DEP_LICENSE_DIR}/libqt6widgets6/copyright"
                     ${PROJECT_BINARY_DIR}/LICENSE.libqt6widgets6 COPYONLY)
    endif()  # JPEGXL_DEP_LICENSE_DIR
  endif()
elseif(APPLE)
  find_package(Qt6 QUIET COMPONENTS Widgets)
  if (Qt6_FOUND)
    add_library(icc_detect STATIC EXCLUDE_FROM_ALL
      icc_detect/icc_detect_empty.cc
      icc_detect/icc_detect.h
    )
    target_include_directories(icc_detect PRIVATE "${PROJECT_SOURCE_DIR}")
    target_link_libraries(icc_detect PUBLIC Qt6::Widgets)
  else()
    message(WARNING "APPLE: Qt6 was not found.")
  endif()
else()
  find_package(Qt6 QUIET COMPONENTS Widgets)
  find_package(ECM QUIET NO_MODULE)
  if (NOT Qt6_FOUND OR NOT ECM_FOUND)
    if (NOT Qt6_FOUND)
      message(WARNING "Qt6 was not found.")
    else()
      message(WARNING "extra-cmake-modules were not found.")
    endif()
  else()
    set(CMAKE_MODULE_PATH ${ECM_FIND_MODULE_DIR})
    find_package(XCB COMPONENTS XCB)
    if (XCB_FOUND)
      add_library(icc_detect STATIC EXCLUDE_FROM_ALL
        icc_detect/icc_detect_x11.cc
        icc_detect/icc_detect.h
      )
      target_link_libraries(icc_detect PUBLIC jxl-static Qt6::Widgets XCB::XCB)
    endif ()
  endif()
endif()
endif()  # JPEGXL_ENABLE_VIEWERS

# Tools are added conditionally below.
set(TOOL_BINARIES)
# Tools that depend on jxl internal functions.
set(INTERNAL_TOOL_BINARIES)
set(FUZZER_CORPUS_BINARIES)

add_library(jxl_tool STATIC EXCLUDE_FROM_ALL
  cmdline.cc
  codec_config.cc
  speed_stats.cc
  tool_version.cc
)
target_compile_options(jxl_tool PUBLIC "${JPEGXL_INTERNAL_FLAGS}")
target_include_directories(jxl_tool PUBLIC "${PROJECT_SOURCE_DIR}")
target_link_libraries(jxl_tool PUBLIC hwy)
jxl_link_libraries(jxl_tool jxl_base-obj)

# The JPEGXL_VERSION is set from the builders.
if(NOT DEFINED JPEGXL_VERSION OR JPEGXL_VERSION STREQUAL "")
  find_package(Git QUIET)
  execute_process(
      COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
      OUTPUT_VARIABLE GIT_REV
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      ERROR_QUIET)
  string(STRIP "${GIT_REV}" GIT_REV)
  if(GIT_REV STREQUAL "")
    set(JPEGXL_VERSION "(unknown)")
  endif()
endif()

if(NOT DEFINED JPEGXL_VERSION OR JPEGXL_VERSION STREQUAL "")
  # We are building from a git environment and the user didn't set
  # JPEGXL_VERSION. Make a target that computes the GIT_REV at build-time always
  # but only updates the file if it changed. This allows rebuilds without
  # modifying cmake files to update the JPEGXL_VERSION.
  message(STATUS "Building with JPEGXL_VERSION=${GIT_REV} (auto-updated)")
  add_custom_target(
    tool_version_git
    ${CMAKE_COMMAND}
      -D JPEGXL_ROOT_DIR=${CMAKE_SOURCE_DIR}
      -D DST=${CMAKE_CURRENT_BINARY_DIR}/tool_version_git.h
      -P ${CMAKE_CURRENT_SOURCE_DIR}/git_version.cmake
    BYPRODUCTS "${CMAKE_CURRENT_BINARY_DIR}/tool_version_git.h"
  )
  add_dependencies(jxl_tool tool_version_git)

  set_source_files_properties(tool_version.cc PROPERTIES
    COMPILE_DEFINITIONS JPEGXL_VERSION_FROM_GIT=1)
  target_include_directories(jxl_tool PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
  # Note: Ninja looks for dependencies on the jxl_tool target before running
  # the tool_version_git targets, so when updating the tool_version_git.h the
  # jxl_tool target is not rebuilt. This forces to generate it at configure time
  # if needed.
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -D JPEGXL_ROOT_DIR=${CMAKE_SOURCE_DIR}
      -D DST=${CMAKE_CURRENT_BINARY_DIR}/tool_version_git.h
      -P ${CMAKE_CURRENT_SOURCE_DIR}/git_version.cmake)
else()
  message(STATUS "Building with JPEGXL_VERSION=${JPEGXL_VERSION}")
  set_source_files_properties(tool_version.cc PROPERTIES
    COMPILE_DEFINITIONS JPEGXL_VERSION=\"${JPEGXL_VERSION}\")
endif()

if(JPEGXL_ENABLE_TOOLS)
  # Main compressor.
  add_executable(cjxl cjxl_main.cc)
  target_link_libraries(cjxl
    jxl
    jxl_extras_codec
    jxl_threads
    jxl_tool
  )
  list(APPEND TOOL_BINARIES cjxl)

  # Main decompressor.
  add_executable(djxl djxl_main.cc)
  target_link_libraries(djxl
    jxl
    jxl_extras_codec
    jxl_threads
    jxl_tool
  )
  list(APPEND TOOL_BINARIES djxl)

  if(JPEGXL_ENABLE_JPEGLI)
    # Depends on parts of jxl_extras that are only built if libjpeg is found and
    # jpegli is enabled.
    add_executable(cjpegli cjpegli.cc)
    add_executable(djpegli djpegli.cc)
    list(APPEND INTERNAL_TOOL_BINARIES cjpegli djpegli)
  endif()

  add_executable(jxlinfo jxlinfo.c)
  target_link_libraries(jxlinfo jxl)
  list(APPEND TOOL_BINARIES jxlinfo)

  if(NOT SANITIZER STREQUAL "none")
    # Linking a C test binary with the C++ JPEG XL implementation when using
    # address sanitizer is not well supported by clang 9, so force using clang++
    # for linking this test if a sanitizer is used.
    set_target_properties(jxlinfo PROPERTIES LINKER_LANGUAGE CXX)
  endif()  # SANITIZER != "none"

endif()  # JPEGXL_ENABLE_TOOLS

# Other developer tools.
if(JPEGXL_ENABLE_DEVTOOLS)
  list(APPEND INTERNAL_TOOL_BINARIES
    butteraugli_main
    decode_and_encode
    display_to_hlg
    exr_to_pq
    pq_to_hlg
    render_hlg
    local_tone_map
    tone_map
    texture_to_cube
    generate_lut_template
    ssimulacra_main
    ssimulacra2
    xyb_range
    jxl_from_tree
  )

  add_executable(ssimulacra_main ssimulacra_main.cc ssimulacra.cc)
  add_executable(ssimulacra2 ssimulacra2_main.cc ssimulacra2.cc)
  add_executable(butteraugli_main butteraugli_main.cc)
  add_executable(decode_and_encode decode_and_encode.cc)
  add_executable(display_to_hlg hdr/display_to_hlg.cc)
  add_executable(exr_to_pq hdr/exr_to_pq.cc)
  add_executable(pq_to_hlg hdr/pq_to_hlg.cc)
  add_executable(render_hlg hdr/render_hlg.cc)
  add_executable(local_tone_map hdr/local_tone_map.cc)
  add_executable(tone_map hdr/tone_map.cc)
  add_executable(texture_to_cube hdr/texture_to_cube.cc)
  add_executable(generate_lut_template hdr/generate_lut_template.cc)
  add_executable(xyb_range xyb_range.cc)
  add_executable(jxl_from_tree jxl_from_tree.cc)

  list(APPEND FUZZER_CORPUS_BINARIES djxl_fuzzer_corpus)
  add_executable(djxl_fuzzer_corpus djxl_fuzzer_corpus.cc)
  target_link_libraries(djxl_fuzzer_corpus
    jxl_extras-static
    jxl_testlib-static
    jxl_tool
  )
  if(JPEGXL_ENABLE_JPEGLI)
    list(APPEND FUZZER_CORPUS_BINARIES jpegli_dec_fuzzer_corpus)
    add_executable(jpegli_dec_fuzzer_corpus jpegli_dec_fuzzer_corpus.cc)
    target_link_libraries(jpegli_dec_fuzzer_corpus
      jpegli-static
      jxl_tool
      jxl_threads-static
    )
  endif()
endif()  # JPEGXL_ENABLE_DEVTOOLS

# Benchmark tools.
if(JPEGXL_ENABLE_BENCHMARK AND JPEGXL_ENABLE_TOOLS)
  list(APPEND INTERNAL_TOOL_BINARIES
    benchmark_xl
  )

  add_executable(benchmark_xl
    benchmark/benchmark_xl.cc
    benchmark/benchmark_args.cc
    benchmark/benchmark_codec.cc
    benchmark/benchmark_file_io.cc
    benchmark/benchmark_stats.cc
    benchmark/benchmark_utils.cc
    benchmark/benchmark_utils.h
    benchmark/benchmark_codec_custom.cc
    benchmark/benchmark_codec_custom.h
    benchmark/benchmark_codec_jpeg.cc
    benchmark/benchmark_codec_jpeg.h
    benchmark/benchmark_codec_jxl.cc
    benchmark/benchmark_codec_jxl.h
    ssimulacra2.cc
    ../third_party/dirent.cc
  )
  target_link_libraries(benchmark_xl Threads::Threads)
  if(MINGW)
  # MINGW doesn't support glob.h.
  target_compile_definitions(benchmark_xl PRIVATE "-DHAS_GLOB=0")
  endif() # MINGW

  if(NOT JPEGXL_BUNDLE_LIBPNG)
    find_package(PNG)
  endif()
  if(PNG_FOUND)
    target_sources(benchmark_xl PRIVATE
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_png.cc"
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_png.h"
    )
  endif()

  find_package(PkgConfig)
  pkg_check_modules(WebP IMPORTED_TARGET libwebp)
  if(WebP_FOUND)
    target_sources(benchmark_xl PRIVATE
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_webp.cc"
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_webp.h"
    )
    target_compile_definitions(benchmark_xl PRIVATE -DBENCHMARK_WEBP)

    # Use the static version of webp if available.
    find_library(WebP_STATIC_LINK_LIBRARY NAMES libwebp.a
        PATHS "${WebP_LIBDIR}")
    find_library(SharpYuv_STATIC_LINK_LIBRARY NAMES libsharpyuv.a
        PATHS "${WebP_LIBDIR}")
    if(NOT WebP_STATIC_LINK_LIBRARY)
      message(WARNING "Using dynamic libwebp")
      target_link_libraries(benchmark_xl PkgConfig::WebP)
    else()
      target_link_libraries(benchmark_xl "${WebP_STATIC_LINK_LIBRARY}")
      if(SharpYuv_STATIC_LINK_LIBRARY)
        target_link_libraries(benchmark_xl "${SharpYuv_STATIC_LINK_LIBRARY}")
      endif()
      target_include_directories(benchmark_xl
          PRIVATE ${WebP_STATIC_INCLUDE_DIRS})
      target_compile_options(benchmark_xl PRIVATE ${WebP_STATIC_CFLAGS_OTHER})
    endif()  # NOT WebP_STATIC_LINK_LIBRARY
  endif()

  pkg_check_modules(AVIF IMPORTED_TARGET libavif)
  if(AVIF_FOUND)
    target_sources(benchmark_xl PRIVATE
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_avif.cc"
      "${CMAKE_CURRENT_LIST_DIR}/benchmark/benchmark_codec_avif.h"
    )
    target_compile_definitions(benchmark_xl PRIVATE -DBENCHMARK_AVIF)
    target_link_libraries(benchmark_xl PkgConfig::AVIF)
  endif()
endif()  # JPEGXL_ENABLE_BENCHMARK

# All tool binaries depend on "jxl" library and the tool helpers.
foreach(BINARY IN LISTS INTERNAL_TOOL_BINARIES)
  target_link_libraries("${BINARY}"
    jxl_extras-static
    jxl_tool
  )
endforeach()

list(APPEND TOOL_BINARIES ${INTERNAL_TOOL_BINARIES} ${FUZZER_CORPUS_BINARIES})

foreach(BINARY IN LISTS TOOL_BINARIES)
  if(JPEGXL_EMSCRIPTEN)
    set(JXL_WASM_TOOLS_LINK_FLAGS "\
      -s USE_LIBPNG=1 \
      -s ALLOW_MEMORY_GROWTH=1 \
      -s USE_PTHREADS=1 \
      -s PTHREAD_POOL_SIZE=16 \
    ")
    set_target_properties(${BINARY} PROPERTIES LINK_FLAGS "${JXL_WASM_TOOLS_LINK_FLAGS}")
  endif()
endforeach()

install(TARGETS ${TOOL_BINARIES} RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
message(STATUS "Building tools: ${TOOL_BINARIES}")

# djxl_fuzzer builds even when not JPEGXL_ENABLE_TOOLS
set(FUZZER_BINARIES djxl_fuzzer)
if(JPEGXL_ENABLE_TOOLS)
  list(APPEND FUZZER_BINARIES
    color_encoding_fuzzer
    decode_basic_info_fuzzer
    cjxl_fuzzer
    icc_codec_fuzzer
    fields_fuzzer
    rans_fuzzer
    set_from_bytes_fuzzer
    transforms_fuzzer
  )
if(JPEGXL_ENABLE_JPEGLI)
  list(APPEND FUZZER_BINARIES jpegli_dec_fuzzer)
endif()
endif()

# Fuzzers.
foreach(FUZZER IN LISTS FUZZER_BINARIES)
  if(JPEGXL_ENABLE_FUZZERS)
    set(BINARY "${FUZZER}")
    add_executable("${BINARY}" "${BINARY}.cc")
    target_link_libraries("${BINARY}" ${JPEGXL_FUZZER_LINK_FLAGS})
  else()
    # When not enabled we want a lightweight alternative for regular fuzzers
    # that just run the target.
    set(BINARY "${FUZZER}_runner")
    add_executable("${BINARY}" EXCLUDE_FROM_ALL
        "fuzzer_stub.cc" "${FUZZER}.cc")
  endif()  # JPEGXL_ENABLE_FUZZERS
  target_include_directories("${BINARY}" PRIVATE "${CMAKE_SOURCE_DIR}")
  if(FUZZER STREQUAL djxl_fuzzer)
    target_link_libraries("${BINARY}"
      jxl_dec-static
      jxl_threads-static
    )
  elseif(FUZZER STREQUAL jpegli_dec_fuzzer)
    target_link_libraries("${BINARY}" jpegli-static)
  else()
    target_link_libraries("${BINARY}"
      jxl_extras_nocodec-static
      jxl_testlib-static
      jxl_tool
    )
  endif()
endforeach()

# EMSCRIPTEN doesn't support dynamic libraries so testing for linkage there
# doesn't make much sense.
if(BUILD_TESTING AND TARGET jxl AND NOT JPEGXL_EMSCRIPTEN)
# Library API test. This test is only to check that we can link against the
# shared library from C99 file and don't need to use internal symbols.
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/tests)
add_executable(libjxl_test libjxl_test.c)
set_property(TARGET libjxl_test PROPERTY C_STANDARD 99)
if(NOT SANITIZER STREQUAL "none")
  # Linking a C test binary with the C++ JPEG XL implementation when using
  # address sanitizer is not well supported by clang 9, so force using clang++
  # for linking this test if a sanitizer is used.
  set_target_properties(libjxl_test PROPERTIES LINKER_LANGUAGE CXX)
endif()  # SANITIZER != "none"
set_target_properties(libjxl_test PROPERTIES PREFIX "tests/")
target_link_libraries(libjxl_test jxl)
if (NOT MSVC)
target_compile_options(libjxl_test PRIVATE -Wall -Wextra -Werror)
if(NOT WIN32)
  target_compile_options(libjxl_test PRIVATE -pedantic)
endif()  # NOT WIN32
endif()  # NOT MSVC

add_test(
  NAME LibraryCLinkageTest
  COMMAND libjxl_test
  WORKING_DIRECTORY $<TARGET_FILE_DIR:jxl>
)
# if user decide to set CMAKE_SKIP_RPATH:BOOL=ON make sure libjxl.so.0.7 can
# still be found:
if(UNIX AND CMAKE_SKIP_RPATH)
  set_property(TEST LibraryCLinkageTest PROPERTY ENVIRONMENT
     LD_LIBRARY_PATH=${CMAKE_CURRENT_BINARY_DIR}/..
     )
endif()

endif()  # BUILD_TESTING AND TARGET jxl AND NOT JPEGXL_EMSCRIPTEN

# Tools defined in subdirectories.
if(JPEGXL_ENABLE_VIEWERS)
add_subdirectory(viewer)
add_subdirectory(comparison_viewer)
add_subdirectory(flicker_test)
endif()

add_subdirectory(box)
add_subdirectory(conformance)
add_subdirectory(wasm_demo)

if(JPEGXL_ENABLE_JNI)
find_package(JNI QUIET)
find_package(Java QUIET)

if (JNI_FOUND AND Java_FOUND)
  include(UseJava)

  # decoder_jni_onload.cc might be necessary for Android; not used yet.
  add_library(jxl_jni SHARED jni/org/jpeg/jpegxl/wrapper/decoder_jni.cc)
  target_include_directories(jxl_jni PRIVATE "${JNI_INCLUDE_DIRS}" "${PROJECT_SOURCE_DIR}")
  target_link_libraries(jxl_jni PUBLIC jxl_dec-static jxl_threads-static)
  if(NOT DEFINED JPEGXL_INSTALL_JNIDIR)
    set(JPEGXL_INSTALL_JNIDIR ${CMAKE_INSTALL_LIBDIR})
  endif()
  install(TARGETS jxl_jni DESTINATION ${JPEGXL_INSTALL_JNIDIR})

  add_jar(jxl_jni_wrapper SOURCES
    jni/org/jpeg/jpegxl/wrapper/Decoder.java
    jni/org/jpeg/jpegxl/wrapper/DecoderJni.java
    jni/org/jpeg/jpegxl/wrapper/ImageData.java
    jni/org/jpeg/jpegxl/wrapper/PixelFormat.java
    jni/org/jpeg/jpegxl/wrapper/Status.java
    jni/org/jpeg/jpegxl/wrapper/StreamInfo.java
    OUTPUT_NAME org.jpeg.jpegxl
  )
  get_target_property(JXL_JNI_WRAPPER_JAR jxl_jni_wrapper JAR_FILE)
  if(NOT DEFINED JPEGXL_INSTALL_JARDIR)
    set(JPEGXL_INSTALL_JARDIR ${CMAKE_INSTALL_LIBDIR})
  endif()
  install_jar(jxl_jni_wrapper DESTINATION ${JPEGXL_INSTALL_JARDIR})

  add_jar(jxl_jni_wrapper_test
    SOURCES jni/org/jpeg/jpegxl/wrapper/DecoderTest.java
    INCLUDE_JARS jxl_jni_wrapper
  )
  get_target_property(JXL_JNI_WRAPPER_TEST_JAR jxl_jni_wrapper_test JAR_FILE)

  if(NOT SANITIZER MATCHES ".san")
    # NB: Vanilla OpenJDK 8 / 11 are known to work well (i.e. either
    #     "which java" or JAVA_HOME environment variable point to the path like
    #     "/usr/lib/jvm/java-xx-openjdk-yyy" on Debian Linux).
    add_test(
      NAME test_jxl_jni_wrapper
      COMMAND ${Java_JAVA_EXECUTABLE}
              -cp "${JXL_JNI_WRAPPER_JAR}:${JXL_JNI_WRAPPER_TEST_JAR}"
              -Dorg.jpeg.jpegxl.wrapper.lib=$<TARGET_FILE:jxl_jni>
              org.jpeg.jpegxl.wrapper.DecoderTest
    )
  endif()  # JPEGXL_ENABLE_FUZZERS
endif()  # JNI_FOUND & Java_FOUND
endif()  # JPEGXL_ENABLE_JNI

# End-to-end tests for the tools
if(JPEGXL_TEST_TOOLS)
find_program (BASH_PROGRAM bash)
if (BASH_PROGRAM)
  set(TEST_SCRIPTS)
  find_package(JPEG)
  if (JPEG_FOUND AND JPEGXL_ENABLE_TRANSCODE_JPEG)
    list(APPEND TEST_SCRIPTS roundtrip_test)
  endif()
  if (JPEG_FOUND AND JPEGXL_ENABLE_JPEGLI)
    list(APPEND TEST_SCRIPTS jpegli_tools_test)
  endif()
  foreach(SCRIPT IN LISTS TEST_SCRIPTS)
    add_test(NAME ${SCRIPT}
      COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/scripts/${SCRIPT}.sh
      ${CMAKE_BINARY_DIR})
  endforeach()
endif()  # BASH_PROGRAM
endif()  # JPEGXL_TEST_TOOLS
