if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

if (NOT DEFINED CMAKE_INSTALL_BINDIR)
  set(CMAKE_INSTALL_BINDIR "bin")
endif()

file(MAKE_DIRECTORY auto/td/telegram)
file(MAKE_DIRECTORY auto/td/mtproto)
file(MAKE_DIRECTORY auto/tlo)

set(TL_TD_AUTO_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/auto PARENT_SCOPE)

set(TD_AUTO_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/auto/td)

set(TL_MTPROTO_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/mtproto/mtproto_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/mtproto/mtproto_api.h
  ${TD_AUTO_INCLUDE_DIR}/mtproto/mtproto_api.hpp
  PARENT_SCOPE
)

set(TL_TD_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/telegram_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/telegram_api.h
  ${TD_AUTO_INCLUDE_DIR}/telegram/telegram_api.hpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/secret_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/secret_api.h
  ${TD_AUTO_INCLUDE_DIR}/telegram/secret_api.hpp
  PARENT_SCOPE
)

set(TL_E2E_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/e2e_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/e2e_api.h
  ${TD_AUTO_INCLUDE_DIR}/telegram/e2e_api.hpp
  PARENT_SCOPE
)

set(TL_TD_API_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_api.h
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_api.hpp
  PARENT_SCOPE
)

set(TL_TD_JSON_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_api_json.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_api_json.h
  PARENT_SCOPE
)

set(TL_C_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_tdc_api.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_tdc_api.h
  ${TD_AUTO_INCLUDE_DIR}/telegram/td_tdc_api_inner.h
  PARENT_SCOPE
)

set(TL_DOTNET_AUTO_SOURCE
  ${TD_AUTO_INCLUDE_DIR}/telegram/TdDotNetApi.cpp
  ${TD_AUTO_INCLUDE_DIR}/telegram/TdDotNetApi.h
  PARENT_SCOPE
)

set(TL_WRITER_CPP_SOURCE
  tl_writer_cpp.cpp
  tl_writer_h.cpp
  tl_writer_hpp.cpp
  tl_writer_jni_cpp.cpp
  tl_writer_jni_h.cpp
  tl_writer_td.cpp

  tl_writer_cpp.h
  tl_writer_h.h
  tl_writer_hpp.h
  tl_writer_jni_cpp.h
  tl_writer_jni_h.h
  tl_writer_td.h
)

set(TL_GENERATE_MTPROTO_SOURCE
  generate_mtproto.cpp
)

set(TL_GENERATE_COMMON_SOURCE
  generate_common.cpp
)

set(TL_GENERATE_C_SOURCE
  generate_c.cpp

  tl_writer_c.h
)

set(TL_GENERATE_JAVA_SOURCE
  generate_java.cpp

  tl_writer_java.cpp

  tl_writer_java.h
)

set(TL_GENERATE_JSON_SOURCE
  generate_json.cpp

  tl_json_converter.cpp

  tl_json_converter.h
)

if (NOT CMAKE_CROSSCOMPILING)
  find_program(PHP_EXECUTABLE php)

  if ((CMAKE_SYSTEM_NAME MATCHES "FreeBSD") AND (CMAKE_SYSTEM_VERSION MATCHES "HBSD"))
    set(PHP_EXECUTABLE "PHP_EXECUTABLE-NOTFOUND")
  endif()

  if (PHP_EXECUTABLE AND NOT TD_ENABLE_DOTNET)
    set(GENERATE_COMMON_CMD generate_common && ${PHP_EXECUTABLE} ../DoxygenTlDocumentationGenerator.php ../scheme/td_api.tl td/telegram/td_api.h)
  else()
    set(GENERATE_COMMON_CMD generate_common)
  endif()

  add_subdirectory(tl-parser)

  set(TLO_AUTO_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/auto/tlo)
  set(TLO_FILES ${TLO_AUTO_INCLUDE_DIR}/mtproto_api.tlo ${TLO_AUTO_INCLUDE_DIR}/secret_api.tlo ${TLO_AUTO_INCLUDE_DIR}/e2e_api.tlo ${TLO_AUTO_INCLUDE_DIR}/td_api.tlo ${TLO_AUTO_INCLUDE_DIR}/telegram_api.tlo)
  set(TD_API_TLO_FILE ${TLO_AUTO_INCLUDE_DIR}/td_api.tlo)

  # Ninja generator uses relative paths and can't correctly handle these dependencies
  # See https://gitlab.kitware.com/cmake/cmake/-/issues/13894
  if (CMAKE_GENERATOR STREQUAL "Ninja")
    set(TLO_FILES)
    set(TD_API_TLO_FILE)
  endif()

  add_custom_target(tl_generate_tlo
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMAND tl-parser -e auto/tlo/mtproto_api.tlo scheme/mtproto_api.tl
    COMMAND tl-parser -e auto/tlo/secret_api.tlo scheme/secret_api.tl
    COMMAND tl-parser -e auto/tlo/e2e_api.tlo scheme/e2e_api.tl
    COMMAND tl-parser -e auto/tlo/td_api.tlo scheme/td_api.tl
    COMMAND tl-parser -e auto/tlo/telegram_api.tlo scheme/telegram_api.tl
    COMMENT "Generate TLO files"
    DEPENDS tl-parser ${CMAKE_CURRENT_SOURCE_DIR}/scheme/mtproto_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/scheme/secret_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/scheme/e2e_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/scheme/td_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/scheme/telegram_api.tl
  )

  add_library(tl_writer_cpp STATIC ${TL_WRITER_CPP_SOURCE})
  target_link_libraries(tl_writer_cpp PRIVATE tdtl)
  target_include_directories(tl_writer_cpp PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
  if (TD_ENABLE_JNI)
    target_compile_definitions(tl_writer_cpp PRIVATE TD_ENABLE_JNI=1 GIT_COMMIT_HASH=${TD_GIT_COMMIT_HASH})
  endif()
  if (TD_ENABLE_DOTNET)
    target_compile_definitions(tl_writer_cpp PRIVATE DISABLE_HPP_DOCUMENTATION=1)
  endif()

  add_executable(generate_mtproto ${TL_GENERATE_MTPROTO_SOURCE})
  target_link_libraries(generate_mtproto PRIVATE tdtl tl_writer_cpp)
  add_custom_target(tl_generate_mtproto
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/auto
    COMMAND generate_mtproto
    COMMENT "Generate MTProto API source files"
    DEPENDS generate_mtproto tl_generate_tlo ${TLO_FILES}
  )

  add_executable(generate_common ${TL_GENERATE_COMMON_SOURCE})
  target_link_libraries(generate_common PRIVATE tdtl tl_writer_cpp)
  add_custom_target(tl_generate_common
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/auto
    COMMAND ${GENERATE_COMMON_CMD}
    COMMENT "Generate common TL source files"
    DEPENDS generate_common tl_generate_tlo ${TLO_FILES} ${CMAKE_CURRENT_SOURCE_DIR}/scheme/td_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/DoxygenTlDocumentationGenerator.php
  )
  if (TD_ENABLE_JNI)
    target_compile_definitions(generate_common PRIVATE TD_ENABLE_JNI=1)
  endif()

  add_executable(generate_c ${TL_GENERATE_C_SOURCE})
  target_link_libraries(generate_c PRIVATE tdtl)
  add_custom_target(tl_generate_c
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/auto
    COMMAND generate_c
    COMMENT "Generate C TL source files"
    DEPENDS generate_c tl_generate_tlo ${TD_API_TLO_FILE} ${CMAKE_CURRENT_SOURCE_DIR}/scheme/td_api.tl
  )

  add_executable(td_generate_java_api ${TL_GENERATE_JAVA_SOURCE})
  target_link_libraries(td_generate_java_api PRIVATE tdtl)
  target_compile_definitions(td_generate_java_api PRIVATE GIT_COMMIT_HASH=${TD_GIT_COMMIT_HASH})

  add_executable(generate_json ${TL_GENERATE_JSON_SOURCE})
  target_link_libraries(generate_json PRIVATE tdtl tdutils)
  add_custom_target(tl_generate_json
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/auto
    COMMAND generate_json
    COMMENT "Generate JSON TL source files"
    DEPENDS generate_json tl_generate_tlo ${TD_API_TLO_FILE} ${CMAKE_CURRENT_SOURCE_DIR}/scheme/td_api.tl
  )

  if (TD_ENABLE_JNI)
    install(TARGETS td_generate_java_api RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
    install(FILES JavadocTlDocumentationGenerator.php TlDocumentationGenerator.php DESTINATION "${CMAKE_INSTALL_BINDIR}/td/generate")
    install(FILES ${TLO_AUTO_INCLUDE_DIR}/td_api.tlo scheme/td_api.tl DESTINATION "${CMAKE_INSTALL_BINDIR}/td/generate/scheme")
  endif()

  if (TD_ENABLE_DOTNET)
    if (PHP_EXECUTABLE)
      set(GENERATE_DOTNET_API_CMD td_generate_dotnet_api ${TD_API_TLO_FILE} && ${PHP_EXECUTABLE} ../DotnetTlDocumentationGenerator.php ../scheme/td_api.tl td/telegram/TdDotNetApi.h)
    else()
      set(GENERATE_DOTNET_API_CMD td_generate_dotnet_api ${TD_API_TLO_FILE})
    endif()

    add_executable(td_generate_dotnet_api generate_dotnet.cpp tl_writer_dotnet.h)
    target_link_libraries(td_generate_dotnet_api PRIVATE tdtl)
    add_custom_target(generate_dotnet_api
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/auto
      COMMAND ${GENERATE_DOTNET_API_CMD}
      COMMENT "Generate .NET API files"
      DEPENDS td_generate_dotnet_api tl_generate_tlo ${TD_API_TLO_FILE} ${CMAKE_CURRENT_SOURCE_DIR}/scheme/td_api.tl ${CMAKE_CURRENT_SOURCE_DIR}/DotnetTlDocumentationGenerator.php
    )
  endif()

  add_executable(remove_documentation remove_documentation.cpp)
  target_link_libraries(remove_documentation PRIVATE tdtl)
endif()
