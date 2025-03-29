if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

option(TDDB_ENABLE_INSTALL "Enable installation of the library." ON)

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR "lib")
endif()

set(TDDB_SOURCE
  td/db/binlog/Binlog.cpp
  td/db/binlog/BinlogEvent.cpp
  td/db/binlog/ConcurrentBinlog.cpp
  td/db/binlog/detail/BinlogEventsBuffer.cpp
  td/db/binlog/detail/BinlogEventsProcessor.cpp

  td/db/detail/RawSqliteDb.cpp

  td/db/SqliteConnectionSafe.cpp
  td/db/SqliteDb.cpp
  td/db/SqliteKeyValue.cpp
  td/db/SqliteKeyValueAsync.cpp
  td/db/SqliteStatement.cpp
  td/db/TQueue.cpp

  td/db/binlog/Binlog.h
  td/db/binlog/BinlogEvent.h
  td/db/binlog/BinlogHelper.h
  td/db/binlog/BinlogInterface.h
  td/db/binlog/ConcurrentBinlog.h
  td/db/binlog/detail/BinlogEventsBuffer.h
  td/db/binlog/detail/BinlogEventsProcessor.h

  td/db/BinlogKeyValue.h
  td/db/DbKey.h
  td/db/KeyValueSyncInterface.h
  td/db/SeqKeyValue.h
  td/db/SqliteConnectionSafe.h
  td/db/SqliteDb.h
  td/db/SqliteKeyValue.h
  td/db/SqliteKeyValueAsync.h
  td/db/SqliteKeyValueSafe.h
  td/db/SqliteStatement.h
  td/db/TQueue.h
  td/db/TsSeqKeyValue.h

  td/db/detail/RawSqliteDb.h
)

add_library(tddb STATIC ${TDDB_SOURCE})
target_include_directories(tddb PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tddb PUBLIC tdactor tdutils PRIVATE tdsqlite)

if (NOT CMAKE_CROSSCOMPILING)
  add_executable(binlog_dump td/db/binlog/binlog_dump.cpp)
  target_link_libraries(binlog_dump PRIVATE tddb)
endif()

if (TDDB_ENABLE_INSTALL)
  install(TARGETS tddb EXPORT TdStaticTargets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  )
endif()
