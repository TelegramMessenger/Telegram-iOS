cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL REQUIRED)
endif()

set(TERMINAL_SOURCE
  terminal.cpp

  terminal.h
  terminal.hpp
)

add_library(terminal STATIC ${TERMINAL_SOURCE})
target_include_directories(terminal PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>/.. 
  ${OPENSSL_INCLUDE_DIR}
)
target_link_libraries(terminal PRIVATE tdutils tdactor )
  
if (NOT READLINE_FOUND)
  find_package(Readline)
endif()
if (NOT READLINE_FOUND)
  message(STATUS "Could NOT find Readline (this is NOT an error)")
else()
  message(STATUS "Found Readline: ${READLINE_INCLUDE_DIR} ${READLINE_LIBRARY}")
  if (NOT USABLE_READLINE_FOUND)
    set(CMAKE_REQUIRED_INCLUDES "${READLINE_INCLUDE_DIR}")
    set(CMAKE_REQUIRED_LIBRARIES "${READLINE_LIBRARY}")
    include(CheckCXXSourceCompiles)
    unset(USABLE_READLINE_FOUND CACHE)
    check_cxx_source_compiles("#include <stdio.h>\n#include <readline/readline.h>\nint main() { rl_free(0); }" USABLE_READLINE_FOUND)
    if (NOT USABLE_READLINE_FOUND)
      message(STATUS "Found Readline is too old, ignore it (this is NOT an error)")
      unset(READLINE_INCLUDE_DIR CACHE)
      unset(READLINE_LIBRARY CACHE)
    endif()
  endif()
  if (USABLE_READLINE_FOUND)
    target_link_libraries(terminal PRIVATE ${READLINE_LIBRARY})
    target_include_directories(terminal SYSTEM PRIVATE ${READLINE_INCLUDE_DIR})
    target_compile_definitions(terminal PRIVATE -DUSE_READLINE=1)
  endif()
endif()



