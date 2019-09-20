cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

#SOURCE SETS
set(TDDB_SOURCE
  td/db/MemoryKeyValue.cpp

  td/db/KeyValue.h
  td/db/KeyValueAsync.h
  td/db/MemoryKeyValue.h

  td/db/utils/ChainBuffer.cpp
  td/db/utils/CyclicBuffer.cpp
  td/db/utils/FileSyncState.cpp
  td/db/utils/StreamInterface.cpp
  td/db/utils/StreamToFileActor.cpp
  td/db/utils/FileToStreamActor.cpp

  td/db/utils/ChainBuffer.h
  td/db/utils/CyclicBuffer.h
  td/db/utils/FileSyncState.h
  td/db/utils/StreamInterface.h
  td/db/utils/StreamToFileActor.h
  td/db/utils/FileToStreamActor.h

  td/db/binlog/Binlog.cpp
  td/db/binlog/BinlogReaderHelper.cpp

  td/db/binlog/Binlog.h
  td/db/binlog/BinlogReaderHelper.h
  td/db/binlog/BinlogReaderInterface.h
)

set(TDDB_ROCKSDB_SOURCE
  td/db/RocksDb.cpp
  td/db/RocksDb.h
)

set(TDDB_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/key_value.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/binlog.cpp
  PARENT_SCOPE
)

#RULES

#LIBRARIES

add_library(tddb STATIC ${TDDB_SOURCE})
target_include_directories(tddb PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tddb PUBLIC tdutils tdactor)

if (TDDB_USE_ROCKSDB)
  target_sources(tddb PRIVATE ${TDDB_ROCKSDB_SOURCE})
  target_compile_definitions(tddb PUBLIC -DTDDB_USE_ROCKSDB)
  target_link_libraries(tddb PRIVATE rocksdb)
  target_include_directories(tddb PRIVATE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../third-party/rocksdb/include>)
endif()

add_executable(io-bench test/io-bench.cpp)
target_link_libraries(io-bench tdutils tdactor tddb)

# BEGIN-INTERNAL
#add_subdirectory(benchmark)

# END-INTERNAL
install(TARGETS tddb EXPORT TdTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)
