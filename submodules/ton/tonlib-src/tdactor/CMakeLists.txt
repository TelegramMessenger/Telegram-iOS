cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

#SOURCE SETS
set(TDACTOR_SOURCE
  td/actor/core/ActorExecutor.cpp
  td/actor/core/CpuWorker.cpp
  td/actor/core/IoWorker.cpp
  td/actor/core/Scheduler.cpp

  td/actor/MultiPromise.cpp

  td/actor/actor.h
  td/actor/ActorId.h
  td/actor/ActorOwn.h
  td/actor/ActorShared.h
  td/actor/common.h
  td/actor/PromiseFuture.h
  td/actor/MultiPromise.h

  td/actor/core/Actor.h
  td/actor/core/ActorExecuteContext.h
  td/actor/core/ActorExecutor.h
  td/actor/core/ActorInfo.h
  td/actor/core/ActorInfoCreator.h
  td/actor/core/ActorLocker.h
  td/actor/core/ActorMailbox.h
  td/actor/core/ActorMessage.h
  td/actor/core/ActorSignals.h
  td/actor/core/ActorState.h
  td/actor/core/CpuWorker.h
  td/actor/core/Context.h
  td/actor/core/IoWorker.h
  td/actor/core/Scheduler.h
  td/actor/core/SchedulerContext.h
  td/actor/core/SchedulerId.h
  td/actor/core/SchedulerMessage.h
)

set(TDACTOR_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_promise.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/test/actors_core.cpp
  PARENT_SCOPE
)

#RULES

#LIBRARIES

add_library(tdactor STATIC ${TDACTOR_SOURCE})
target_include_directories(tdactor PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tdactor PUBLIC tdutils)

# BEGIN-INTERNAL
add_subdirectory(benchmark)

# END-INTERNAL
install(TARGETS tdactor EXPORT TdTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)
