if (CMAKE_SYSTEM_NAME STREQUAL "SunOS")
  #
  # Determine if the host is running an illumos distribution:
  #
  execute_process(COMMAND /usr/bin/uname -o OUTPUT_VARIABLE UNAME_O OUTPUT_STRIP_TRAILING_WHITESPACE)

  if (UNAME_O STREQUAL "illumos")
    set(ILLUMOS 1)
  endif()
endif()
