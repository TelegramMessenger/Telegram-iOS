if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL REQUIRED)
  find_package(ZLIB REQUIRED)
endif()

# TODO: all benchmarks in one file
add_executable(bench_crypto bench_crypto.cpp)
target_link_libraries(bench_crypto PRIVATE tdutils ${OPENSSL_CRYPTO_LIBRARY} ${CMAKE_DL_LIBS} ${ZLIB_LIBRARIES})
if (WIN32)
  if (MINGW)
    target_link_libraries(bench_crypto PRIVATE ws2_32 mswsock crypt32)
  else()
    target_link_libraries(bench_crypto PRIVATE ws2_32 Mswsock Crypt32)
  endif()
endif()
target_include_directories(bench_crypto SYSTEM PRIVATE ${OPENSSL_INCLUDE_DIR})

add_executable(bench_actor bench_actor.cpp)
target_link_libraries(bench_actor PRIVATE tdactor tdutils)

add_executable(bench_http bench_http.cpp)
target_link_libraries(bench_http PRIVATE tdnet tdutils)

add_executable(bench_http_server bench_http_server.cpp)
target_link_libraries(bench_http_server PRIVATE tdnet tdutils)

add_executable(bench_http_server_cheat bench_http_server_cheat.cpp)
target_link_libraries(bench_http_server_cheat PRIVATE tdnet tdutils)

add_executable(bench_http_server_fast bench_http_server_fast.cpp)
target_link_libraries(bench_http_server_fast PRIVATE tdnet tdutils)

add_executable(bench_http_reader bench_http_reader.cpp)
target_link_libraries(bench_http_reader PRIVATE tdnet tdutils)

add_executable(bench_handshake bench_handshake.cpp)
target_link_libraries(bench_handshake PRIVATE tdmtproto tdutils)

add_executable(bench_db bench_db.cpp)
target_link_libraries(bench_db PRIVATE tdactor tddb tdutils)

add_executable(bench_tddb bench_tddb.cpp)
target_link_libraries(bench_tddb PRIVATE tdcore tddb tdutils)

add_executable(bench_misc bench_misc.cpp)
target_link_libraries(bench_misc PRIVATE tdcore tdutils)

add_executable(check_proxy check_proxy.cpp)
target_link_libraries(check_proxy PRIVATE tdclient tdutils)

add_executable(check_tls check_tls.cpp)
target_link_libraries(check_tls PRIVATE tdutils)

add_executable(rmdir rmdir.cpp)
target_link_libraries(rmdir PRIVATE tdutils)

add_executable(wget wget.cpp)
target_link_libraries(wget PRIVATE tdnet tdutils)

add_executable(bench_empty bench_empty.cpp)
target_link_libraries(bench_empty PRIVATE tdutils)

if (NOT WIN32 AND NOT CYGWIN)
  add_executable(bench_log bench_log.cpp)
  target_link_libraries(bench_log PRIVATE tdutils)

  set_source_files_properties(bench_queue.cpp PROPERTIES COMPILE_FLAGS -Wno-deprecated-declarations)
  add_executable(bench_queue bench_queue.cpp)
  target_link_libraries(bench_queue PRIVATE tdutils)
endif()

if (TD_TEST_FOLLY AND TD_WITH_ABSEIL)
  find_package(ABSL QUIET)
  find_package(folly QUIET)
  find_package(gflags QUIET)

  if (ABSL_FOUND AND folly_FOUND)
    add_executable(memory-hashset-memprof EXCLUDE_FROM_ALL hashset_memory.cpp)
    target_compile_definitions(memory-hashset-memprof PRIVATE USE_MEMPROF=1)
    target_link_libraries(memory-hashset-memprof PRIVATE tdutils memprof_stat Folly::folly absl::flat_hash_map absl::hash)

    add_executable(memory-hashset-os hashset_memory.cpp)
    target_compile_definitions(memory-hashset-os PRIVATE USE_MEMPROF=0)
    target_link_libraries(memory-hashset-os PRIVATE tdutils Folly::folly absl::flat_hash_map absl::hash)

    add_executable(hashmap-build hashmap_build.cpp)
    target_link_libraries(hashmap-build PRIVATE tdutils Folly::folly absl::flat_hash_map absl::hash)
  endif()
endif()
