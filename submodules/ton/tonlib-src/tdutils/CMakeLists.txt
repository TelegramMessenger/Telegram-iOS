cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

option(TDUTILS_MIME_TYPE "Generate mime types conversion (gperf is required)" ON)

if (WIN32)
  if (WINGETOPT_FOUND)
    set(TD_HAVE_GETOPT 1)
  endif()
else()
  set(TD_HAVE_GETOPT 1)
endif()

if (NOT ZLIB_FOUND)
  find_package(ZLIB)
endif()
if (ZLIB_FOUND)
  set(TD_HAVE_ZLIB 1)
  message(STATUS "Found ZLIB: ${ZLIB_INCLUDE_DIR} ${ZLIB_LIBRARIES}")

  # OpenSSL internally depends on zlib
  if (NOT OPENSSL_FOUND)
    find_package(OpenSSL)
  endif()
  if (OPENSSL_FOUND)
    set(TD_HAVE_OPENSSL 1)
  endif()
endif()

if (CRC32C_FOUND)
  set(TD_HAVE_CRC32C 1)
endif()

if (ABSL_FOUND)
  set(TD_HAVE_ABSL 1)
endif()

configure_file(td/utils/config.h.in td/utils/config.h @ONLY)

add_subdirectory(generate)

# TDUTILS
set_source_files_properties(${TDMIME_AUTO} PROPERTIES GENERATED TRUE)
if (CLANG OR GCC)
  set_property(SOURCE ${TDMIME_AUTO} APPEND_STRING PROPERTY COMPILE_FLAGS " -Wno-conversion")
elseif (MSVC)
  set_property(SOURCE ${TDMIME_AUTO} APPEND_STRING PROPERTY COMPILE_FLAGS " /wd4267")
endif()
if (CLANG)
  set_property(SOURCE ${TDMIME_AUTO} APPEND_STRING PROPERTY COMPILE_FLAGS " -Wno-deprecated-register")
endif()

set(TDUTILS_SOURCE
  td/utils/port/Clocks.cpp
  td/utils/port/FileFd.cpp
  td/utils/port/IPAddress.cpp
  td/utils/port/MemoryMapping.cpp
  td/utils/port/path.cpp
  td/utils/port/PollFlags.cpp
  td/utils/port/ServerSocketFd.cpp
  td/utils/port/signals.cpp
  td/utils/port/sleep.cpp
  td/utils/port/SocketFd.cpp
  td/utils/port/stacktrace.cpp
  td/utils/port/Stat.cpp
  td/utils/port/StdStreams.cpp
  td/utils/port/thread_local.cpp
  td/utils/port/user.cpp
  td/utils/port/UdpSocketFd.cpp
  td/utils/port/wstring_convert.cpp

  td/utils/port/detail/Epoll.cpp
  td/utils/port/detail/EventFdBsd.cpp
  td/utils/port/detail/EventFdLinux.cpp
  td/utils/port/detail/EventFdWindows.cpp
  td/utils/port/detail/Iocp.cpp
  td/utils/port/detail/KQueue.cpp
  td/utils/port/detail/NativeFd.cpp
  td/utils/port/detail/Poll.cpp
  td/utils/port/detail/Select.cpp
  td/utils/port/detail/ThreadIdGuard.cpp
  td/utils/port/detail/WineventPoll.cpp

  ${TDMIME_AUTO}

  td/utils/base64.cpp
  td/utils/BigNum.cpp
  td/utils/buffer.cpp
  td/utils/BufferedUdp.cpp
  td/utils/check.cpp
  td/utils/crypto.cpp
  td/utils/FileLog.cpp
  td/utils/filesystem.cpp
  td/utils/find_boundary.cpp
  td/utils/Gzip.cpp
  td/utils/GzipByteFlow.cpp
  td/utils/Hints.cpp
  td/utils/HttpUrl.cpp
  td/utils/JsonBuilder.cpp
  td/utils/logging.cpp
  td/utils/misc.cpp
  td/utils/MpmcQueue.cpp
  td/utils/OptionsParser.cpp
  td/utils/Random.cpp
  td/utils/Slice.cpp
  td/utils/SharedSlice.cpp
  td/utils/StackAllocator.cpp
  td/utils/Status.cpp
  td/utils/StringBuilder.cpp
  td/utils/Time.cpp
  td/utils/Timer.cpp
  td/utils/TsFileLog.cpp
  td/utils/tests.cpp
  td/utils/tl_parsers.cpp
  td/utils/translit.cpp
  td/utils/unicode.cpp
  td/utils/utf8.cpp

  td/utils/port/Clocks.h
  td/utils/port/config.h
  td/utils/port/CxCli.h
  td/utils/port/EventFd.h
  td/utils/port/EventFdBase.h
  td/utils/port/FileFd.h
  td/utils/port/IPAddress.h
  td/utils/port/IoSlice.h
  td/utils/port/MemoryMapping.h
  td/utils/port/path.h
  td/utils/port/platform.h
  td/utils/port/Poll.h
  td/utils/port/PollBase.h
  td/utils/port/PollFlags.h
  td/utils/port/RwMutex.h
  td/utils/port/ServerSocketFd.h
  td/utils/port/signals.h
  td/utils/port/sleep.h
  td/utils/port/SocketFd.h
  td/utils/port/stacktrace.h
  td/utils/port/Stat.h
  td/utils/port/StdStreams.h
  td/utils/port/thread.h
  td/utils/port/thread_local.h
  td/utils/port/user.h
  td/utils/port/UdpSocketFd.h
  td/utils/port/wstring_convert.h

  td/utils/port/detail/Epoll.h
  td/utils/port/detail/EventFdBsd.h
  td/utils/port/detail/EventFdLinux.h
  td/utils/port/detail/EventFdWindows.h
  td/utils/port/detail/Iocp.h
  td/utils/port/detail/KQueue.h
  td/utils/port/detail/NativeFd.h
  td/utils/port/detail/Poll.h
  td/utils/port/detail/PollableFd.h
  td/utils/port/detail/Select.h
  td/utils/port/detail/ThreadIdGuard.h
  td/utils/port/detail/ThreadPthread.h
  td/utils/port/detail/ThreadStl.h
  td/utils/port/detail/WineventPoll.h

  td/utils/AesCtrByteFlow.h
  td/utils/as.h
  td/utils/base64.h
  td/utils/benchmark.h
  td/utils/BigNum.h
  td/utils/bits.h
  td/utils/buffer.h
  td/utils/BufferedFd.h
  td/utils/BufferedReader.h
  td/utils/BufferedUdp.h
  td/utils/ByteFlow.h
  td/utils/CancellationToken.h
  td/utils/ChangesProcessor.h
  td/utils/check.h
  td/utils/Closure.h
  td/utils/common.h
  td/utils/ConcurrentHashTable.h
  td/utils/Container.h
  td/utils/Context.h
  td/utils/crypto.h
  td/utils/DecTree.h
  td/utils/Destructor.h
  td/utils/Enumerator.h
  td/utils/EpochBasedMemoryReclamation.h
  td/utils/FileLog.h
  td/utils/filesystem.h
  td/utils/find_boundary.h
  td/utils/FloodControlFast.h
  td/utils/FloodControlStrict.h
  td/utils/format.h
  td/utils/Gzip.h
  td/utils/GzipByteFlow.h
  td/utils/Hash.h
  td/utils/HashMap.h
  td/utils/HashSet.h
  td/utils/HazardPointers.h
  td/utils/Heap.h
  td/utils/Hints.h
  td/utils/HttpUrl.h
  td/utils/int_types.h
  td/utils/invoke.h
  td/utils/JsonBuilder.h
  td/utils/List.h
  td/utils/logging.h
  td/utils/MemoryLog.h
  td/utils/misc.h
  td/utils/MovableValue.h
  td/utils/MpmcQueue.h
  td/utils/MpmcWaiter.h
  td/utils/MpscPollableQueue.h
  td/utils/MpscLinkQueue.h
  td/utils/Named.h
  td/utils/ObjectPool.h
  td/utils/Observer.h
  td/utils/optional.h
  td/utils/OptionsParser.h
  td/utils/OrderedEventsProcessor.h
  td/utils/overloaded.h
  td/utils/Parser.h
  td/utils/PathView.h
  td/utils/queue.h
  td/utils/Random.h
  td/utils/ScopeGuard.h
  td/utils/SharedObjectPool.h
  td/utils/Slice-decl.h
  td/utils/Slice.h
  td/utils/Span.h
  td/utils/SpinLock.h
  td/utils/StackAllocator.h
  td/utils/Status.h
  td/utils/Storer.h
  td/utils/StorerBase.h
  td/utils/StringBuilder.h
  td/utils/tests.h
  td/utils/ThreadSafeCounter.h
  td/utils/Time.h
  td/utils/TimedStat.h
  td/utils/Timer.h
  td/utils/TsFileLog.h
  td/utils/tl_helpers.h
  td/utils/tl_parsers.h
  td/utils/tl_storers.h
  td/utils/translit.h
  td/utils/type_traits.h
  td/utils/UInt.h
  td/utils/uint128.h
  td/utils/unicode.h
  td/utils/unique_ptr.h
  td/utils/utf8.h
  td/utils/Variant.h
  td/utils/VectorQueue.h
)

if (TDUTILS_MIME_TYPE)
  set(TDUTILS_SOURCE
    ${TDUTILS_SOURCE}
    td/utils/MimeType.cpp
    td/utils/MimeType.h
  )
endif()

set(TDUTILS_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/buffer.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/ConcurrentHashMap.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/crypto.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/Enumerator.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/filesystem.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/gzip.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/HazardPointers.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/heap.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/json.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/log.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/misc.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/MpmcQueue.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/MpmcWaiter.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/MpscLinkQueue.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/OrderedEventsProcessor.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/port.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/pq.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/SharedObjectPool.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/SharedSlice.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/variant.cpp
  PARENT_SCOPE
)

#RULES
#LIBRARIES
add_library(tdutils STATIC ${TDUTILS_SOURCE})
if (WIN32)
  # find_library(WS2_32_LIBRARY ws2_32)
  # find_library(MSWSOCK_LIBRARY Mswsock)
  # target_link_libraries(tdutils PRIVATE ${WS2_32_LIBRARY} ${MSWSOCK_LIBRARY})
  target_link_libraries(tdutils PRIVATE ws2_32 Mswsock Normaliz)
endif()
if (NOT CMAKE_CROSSCOMPILING AND TDUTILS_MIME_TYPE)
  add_dependencies(tdutils tdmime_auto)
endif()

if (DEFINED CMAKE_THREAD_LIBS_INIT)
  target_link_libraries(tdutils PUBLIC ${CMAKE_THREAD_LIBS_INIT})
endif()
target_include_directories(tdutils PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)

if (OPENSSL_FOUND)
  target_link_libraries(tdutils PRIVATE ${OPENSSL_CRYPTO_LIBRARY} ${CMAKE_DL_LIBS} ${ZLIB_LIBRARIES})
  target_include_directories(tdutils SYSTEM PRIVATE ${OPENSSL_INCLUDE_DIR})
endif()

if (ZLIB_FOUND)
  target_link_libraries(tdutils PRIVATE ${ZLIB_LIBRARIES})
  target_include_directories(tdutils SYSTEM PRIVATE ${ZLIB_INCLUDE_DIR})
endif()

if (CRC32C_FOUND)
  target_link_libraries(tdutils PRIVATE crc32c)
endif()
if (ABSL_FOUND)
  target_link_libraries_system(tdutils absl::flat_hash_map absl::flat_hash_set absl::hash)
endif()

if (WIN32 AND WINGETOPT_FOUND)
  target_link_libraries(tdutils PRIVATE wingetopt)
endif()

if (ANDROID)
  target_link_libraries(tdutils PRIVATE log)
endif()

if (CMAKE_HOST_SYSTEM_NAME MATCHES "NetBSD")
  target_link_libraries(tdutils PUBLIC /usr/pkg/gcc5/i486--netbsdelf/lib/libatomic.so)
endif()

install(TARGETS tdutils EXPORT TdTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)
