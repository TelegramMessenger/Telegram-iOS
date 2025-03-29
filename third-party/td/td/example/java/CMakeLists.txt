cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

project(TdJavaExample VERSION 1.0 LANGUAGES CXX)

option(TD_JSON_JAVA "Use \"ON\" to build Java wrapper for JSON API.")

if (POLICY CMP0074)
  # use environment variables to find libraries
  cmake_policy(SET CMP0074 NEW)
endif()

find_package(Td REQUIRED)

if (NOT JNI_FOUND)
  find_package(JNI REQUIRED COMPONENTS JVM)
endif()
message(STATUS "Found JNI: ${JNI_INCLUDE_DIRS} ${JNI_LIBRARIES}")

if (NOT Java_FOUND)
  find_package(Java REQUIRED)
endif()
message(STATUS "Found Java: ${Java_JAVAC_EXECUTABLE} ${Java_JAVADOC_EXECUTABLE}")

# Generating TdApi.java
set(TD_API_JAVA_PACKAGE "org/drinkless/tdlib")
set(TD_API_JAVA_PATH ${CMAKE_CURRENT_SOURCE_DIR})
set(JAVA_SOURCE_PATH "${TD_API_JAVA_PATH}/${TD_API_JAVA_PACKAGE}")
if (TD_JSON_JAVA)
  add_custom_target(td_generate_java_api
    COMMAND cmake -E echo ""
    COMMENT "Skip generation of Java TDLib API source files"
  )

  set(JAVA_EXAMPLE_FILES "${JAVA_SOURCE_PATH}/example/JsonExample.java")
  set(JAVA_SOURCE_FILES "${JAVA_SOURCE_PATH}/JsonClient.java")
else()
  find_program(PHP_EXECUTABLE php)
  if ((CMAKE_SYSTEM_NAME MATCHES "FreeBSD") AND (CMAKE_SYSTEM_VERSION MATCHES "HBSD"))
    set(PHP_EXECUTABLE "PHP_EXECUTABLE-NOTFOUND")
  endif()

  set(TD_API_TLO_PATH ${CMAKE_CURRENT_SOURCE_DIR}/td/bin/td/generate/scheme/td_api.tlo)
  set(TD_API_TL_PATH ${CMAKE_CURRENT_SOURCE_DIR}/td/bin/td/generate/scheme/td_api.tl)
  set(JAVADOC_TL_DOCUMENTATION_GENERATOR_PATH ${CMAKE_CURRENT_SOURCE_DIR}/td/bin/td/generate/JavadocTlDocumentationGenerator.php)
  set(GENERATE_JAVA_API_CMD ${CMAKE_CURRENT_SOURCE_DIR}/td/bin/td_generate_java_api TdApi "${TD_API_TLO_PATH}" "${TD_API_JAVA_PATH}" "${TD_API_JAVA_PACKAGE}")
  if (PHP_EXECUTABLE)
    set(GENERATE_JAVA_API_CMD ${GENERATE_JAVA_API_CMD} && ${PHP_EXECUTABLE} "${JAVADOC_TL_DOCUMENTATION_GENERATOR_PATH}" "${TD_API_TL_PATH}" "${JAVA_SOURCE_PATH}/TdApi.java")
  endif()

  add_custom_target(td_generate_java_api
    COMMAND ${GENERATE_JAVA_API_CMD}
    COMMENT "Generating Java TDLib API source files"
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/td/bin/td_generate_java_api ${TD_API_TLO_PATH} ${TD_API_TL_PATH} ${JAVADOC_TL_DOCUMENTATION_GENERATOR_PATH}
  )

  set(JAVA_EXAMPLE_FILES "${JAVA_SOURCE_PATH}/example/Example.java")
  set(JAVA_SOURCE_FILES "${JAVA_SOURCE_PATH}/Client.java" "${JAVA_SOURCE_PATH}/TdApi.java")
endif()

if (CMAKE_VERSION VERSION_LESS "3.17")
  set(CMAKE_RM_COMMAND remove_directory)
else()
  set(CMAKE_RM_COMMAND rm -rf --)
endif()

get_filename_component(JAVA_OUTPUT_DIRECTORY ${CMAKE_INSTALL_PREFIX}/bin REALPATH BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
file(MAKE_DIRECTORY ${JAVA_OUTPUT_DIRECTORY})
add_custom_target(build_java
  COMMAND ${CMAKE_COMMAND} -E ${CMAKE_RM_COMMAND} "${JAVA_OUTPUT_DIRECTORY}/${TD_API_JAVA_PACKAGE}"
  COMMAND ${Java_JAVAC_EXECUTABLE} -encoding UTF-8 -d "${JAVA_OUTPUT_DIRECTORY}" ${JAVA_EXAMPLE_FILES} ${JAVA_SOURCE_FILES}
  COMMENT "Building Java code"
  DEPENDS td_generate_java_api
)

add_custom_target(generate_javadoc
  COMMAND ${CMAKE_COMMAND} -E ${CMAKE_RM_COMMAND} "${JAVA_OUTPUT_DIRECTORY}/../docs"
  COMMAND ${Java_JAVADOC_EXECUTABLE} -encoding UTF-8 -charset UTF-8 -d "${JAVA_OUTPUT_DIRECTORY}/../docs" ${JAVA_SOURCE_FILES}
  WORKING_DIRECTORY ${TD_API_JAVA_PATH}
  COMMENT "Generating Javadoc documentation"
  DEPENDS td_generate_java_api
)

# Building shared library
add_library(tdjni SHARED
  td_jni.cpp
)
target_include_directories(tdjni PRIVATE ${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
target_link_libraries(tdjni PRIVATE ${JAVA_JVM_LIBRARY})
target_compile_definitions(tdjni PRIVATE PACKAGE_NAME="${TD_API_JAVA_PACKAGE}")

if (TD_JSON_JAVA)
  target_link_libraries(tdjni PRIVATE Td::TdJsonStatic)
  target_compile_definitions(tdjni PRIVATE TD_JSON_JAVA=1)
  set_target_properties(tdjni PROPERTIES OUTPUT_NAME "tdjsonjava")
else()
  target_link_libraries(tdjni PRIVATE Td::TdStatic)
endif()

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(GCC 1)
elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  set(CLANG 1)
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
  set(INTEL 1)
elseif (NOT MSVC)
  message(FATAL_ERROR "Compiler isn't supported")
endif()

include(CheckCXXCompilerFlag)

if (GCC OR CLANG OR INTEL)
  if (WIN32 AND INTEL)
    set(STD14_FLAG /Qstd=c++14)
  else()
    set(STD14_FLAG -std=c++14)
  endif()
  check_cxx_compiler_flag(${STD14_FLAG} HAVE_STD14)
  if (NOT HAVE_STD14)
    string(REPLACE "c++14" "c++1y" STD14_FLAG "${STD14_FLAG}")
    check_cxx_compiler_flag(${STD14_FLAG} HAVE_STD1Y)
    set(HAVE_STD14 ${HAVE_STD1Y})
  endif()

  target_compile_options(tdjni PRIVATE "${STD14_FLAG}")
elseif (MSVC)
  set(HAVE_STD14 MSVC_VERSION>=1900)
endif()

if (NOT HAVE_STD14)
  message(FATAL_ERROR "No C++14 support in the compiler. Please upgrade the compiler.")
endif()

add_dependencies(tdjni td_generate_java_api build_java generate_javadoc)

install(TARGETS tdjni
  LIBRARY DESTINATION bin
  RUNTIME DESTINATION bin
)
if (MSVC AND VCPKG_TOOLCHAIN)
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/" DESTINATION bin FILES_MATCHING PATTERN "*.dll" PATTERN "*.pdb")
endif()
