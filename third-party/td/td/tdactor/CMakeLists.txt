if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

option(TDACTOR_ENABLE_INSTALL "Enable installation of the library." ON)

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR "lib")
endif()

set(TDACTOR_SOURCE
  td/actor/ConcurrentScheduler.cpp
  td/actor/impl/Scheduler.cpp
  td/actor/MultiPromise.cpp
  td/actor/MultiTimeout.cpp

  td/actor/actor.h
  td/actor/ConcurrentScheduler.h
  td/actor/impl/Actor-decl.h
  td/actor/impl/Actor.h
  td/actor/impl/ActorId-decl.h
  td/actor/impl/ActorId.h
  td/actor/impl/ActorInfo-decl.h
  td/actor/impl/ActorInfo.h
  td/actor/impl/Event.h
  td/actor/impl/EventFull-decl.h
  td/actor/impl/EventFull.h
  td/actor/impl/Scheduler-decl.h
  td/actor/impl/Scheduler.h
  td/actor/MultiPromise.h
  td/actor/MultiTimeout.h
  td/actor/PromiseFuture.h
  td/actor/SchedulerLocalStorage.h
  td/actor/SignalSlot.h
  td/actor/SleepActor.h
  td/actor/Timeout.h
)

set(TDACTOR_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_main.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_simple.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_workers.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_bugs.cpp
  PARENT_SCOPE
)

add_library(tdactor STATIC ${TDACTOR_SOURCE})
target_include_directories(tdactor PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tdactor PUBLIC tdutils)

if (NOT CMAKE_CROSSCOMPILING)
  add_executable(example example/example.cpp)
  target_link_libraries(example PRIVATE tdactor)
endif()

if (TDACTOR_ENABLE_INSTALL)
  install(TARGETS tdactor EXPORT TdStaticTargets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  )
endif()
