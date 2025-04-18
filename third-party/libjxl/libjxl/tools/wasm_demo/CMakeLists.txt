if (NOT JPEGXL_ENABLE_TOOLS OR NOT JPEGXL_EMSCRIPTEN)
  return()
endif()

# WASM API facade.
add_executable(jxl_decoder jxl_decoder.cc jxl_decompressor.cc no_png.cc)
add_executable(jxl_decoder_for_test jxl_decoder.cc jxl_decompressor.cc no_png.cc)
target_link_libraries(jxl_decoder jxl_extras-static)
target_link_libraries(jxl_decoder_for_test jxl_extras-static)

set(JXL_C_SYMBOLS
  _free
  _malloc
)

set(JXL_DECODER_SYMBOLS
  _jxlCreateInstance
  _jxlDestroyInstance
  _jxlFlush
  _jxlProcessInput
)

set(JXL_DECOMPRESSOR_SYMBOLS
  _jxlDecompress
  _jxlCleanup
)

set(JXL_MODULE_SYMBOLS ${JXL_C_SYMBOLS} ${JXL_DECODER_SYMBOLS} ${JXL_DECOMPRESSOR_SYMBOLS})

list(JOIN JXL_MODULE_SYMBOLS ", " JXL_MODULE_EXPORTS)

set(JXL_WASM_SITE_LINK_FLAGS " -O3 -s FILESYSTEM=0 --closure 1 -mnontrapping-fptoint")
set(JXL_WASM_TEST_LINK_FLAGS " -O1 -s NODERAWFS=1 ")

set(JXL_WASM_BASE_LINK_FLAGS "\
  -s ALLOW_MEMORY_GROWTH=1 \
  -s DISABLE_EXCEPTION_CATCHING=1 \
  -s MODULARIZE=1 \
  -s USE_PTHREADS=1 \
  -s PTHREAD_POOL_SIZE=4 \
")

# libpng is used only by "decompressor"
set(JXL_DECODER_LINK_FLAGS "${JXL_WASM_BASE_LINK_FLAGS} \
  -s EXPORT_NAME=\"JxlDecoderModule\" \
  -s \"EXPORTED_FUNCTIONS=[${JXL_MODULE_EXPORTS}]\" \
")

set_target_properties(jxl_decoder PROPERTIES LINK_FLAGS
  "${JXL_DECODER_LINK_FLAGS} ${JXL_WASM_SITE_LINK_FLAGS}")

set_target_properties(jxl_decoder_for_test PROPERTIES LINK_FLAGS
  "${JXL_DECODER_LINK_FLAGS} ${JXL_WASM_TEST_LINK_FLAGS}")

if (BUILD_TESTING)
  add_test(
    NAME test_wasm_jxl_decoder
    COMMAND ${CMAKE_CROSSCOMPILING_EMULATOR}
            --no-experimental-fetch
            ${CMAKE_CURRENT_SOURCE_DIR}/jxl_decoder_test.js
  )
  set_tests_properties(test_wasm_jxl_decoder PROPERTIES
    ENVIRONMENT NODE_PATH=$<TARGET_FILE_DIR:jxl_decoder_for_test>)
endif()  # BUILD_TESTING
