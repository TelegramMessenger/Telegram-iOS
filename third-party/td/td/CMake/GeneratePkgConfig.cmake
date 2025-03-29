function(get_relative_link OUTPUT PATH)
  if (PATH MATCHES "^[$]<[$]<CONFIG:DEBUG>:")
    set(${OUTPUT} "" PARENT_SCOPE)
    return()
  endif()
  string(REGEX REPLACE "^[$]<[$]<NOT:[$]<CONFIG:DEBUG>>:(.*)>$" "\\1" PATH "${PATH}")

  get_filename_component(NAME "${PATH}" NAME_WE)
  if (IS_ABSOLUTE ${PATH})
    get_filename_component(DIRECTORY_NAME "${PATH}" DIRECTORY)
    if (WIN32)
      set(${OUTPUT} "-l\"${DIRECTORY_NAME}/${NAME}\"" PARENT_SCOPE)
    else()
      get_filename_component(FULL_NAME "${PATH}" NAME)
      set(${OUTPUT} "-L\"${DIRECTORY_NAME}\" -l:${FULL_NAME}" PARENT_SCOPE)
    endif()
    return()
  endif()

  if (NOT WIN32 AND NAME MATCHES "^lib")
    string(REGEX REPLACE "^lib" "-l" LINK "${NAME}")
  elseif (NAME MATCHES "^-")
    set(LINK "${NAME}")
  else()
    string(CONCAT LINK "-l" "${NAME}")
  endif()
  set(${OUTPUT} "${LINK}" PARENT_SCOPE)
endfunction()

function(generate_pkgconfig TARGET DESCRIPTION)
  # message("Generating pkg-config for ${TARGET}")
  get_filename_component(PREFIX "${CMAKE_INSTALL_PREFIX}" REALPATH)

  get_target_property(LIST "${TARGET}" LINK_LIBRARIES)
  set(REQS "")
  set(LIBS "")
  foreach (LIB ${LIST})
    if (TARGET "${LIB}")
      set(HAS_REQS 1)
      list(APPEND REQS "${LIB}")
    else()
      set(HAS_LIBS 1)
      get_relative_link(LINK "${LIB}")
      if (NOT LINK EQUAL "")
        list(APPEND LIBS "${LINK}")
      endif()
    endif()
  endforeach()

  if (HAS_REQS)
    set(REQUIRES "")
    foreach (REQ ${REQS})
      set(REQUIRES "${REQUIRES} ${REQ}")
    endforeach()
    set(REQUIRES "Requires.private:${REQUIRES}\n")
  endif()
  if (HAS_LIBS)
    set(LIBRARIES "")
    list(REVERSE LIBS)
    list(REMOVE_DUPLICATES LIBS)
    foreach (LIB ${LIBS})
      set(LIBRARIES " ${LIB}${LIBRARIES}")
    endforeach()
    set(LIBRARIES "Libs.private:${LIBRARIES}\n")
  endif()

  if (IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
    set(PKGCONFIG_INCLUDEDIR "${CMAKE_INSTALL_INCLUDEDIR}")
  else()
    set(PKGCONFIG_INCLUDEDIR "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
  endif()

  if (IS_ABSOLUTE "${CMAKE_INSTALL_LIBDIR}")
    set(PKGCONFIG_LIBDIR "${CMAKE_INSTALL_LIBDIR}")
  else()
    set(PKGCONFIG_LIBDIR "\${prefix}/${CMAKE_INSTALL_LIBDIR}")
  endif()

  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/pkgconfig")
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/pkgconfig/${TARGET}.pc" CONTENT
"prefix=${PREFIX}

Name: ${TARGET}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}

CFlags: -I\"${PKGCONFIG_INCLUDEDIR}\"
Libs: -L\"${PKGCONFIG_LIBDIR}\" -l${TARGET}
${REQUIRES}${LIBRARIES}")

  get_target_property(LIBRARY_TYPE "${TARGET}" TYPE)
  if (LIBRARY_TYPE STREQUAL "STATIC_LIBRARY" OR LIBRARY_TYPE STREQUAL "SHARED_LIBRARY")
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/pkgconfig/${TARGET}.pc" DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
  elseif (LIBRARY_TYPE STREQUAL "INTERFACE_LIBRARY")
    # TODO: support interface libraries
  else()
    message(FATAL_ERROR "Don't know how to handle ${TARGET} of type ${LIBRARY_TYPE}")
  endif()
endfunction()
