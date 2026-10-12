#
#   Copyright 2013 Pixar
#
#   Licensed under the terms set forth in the LICENSE.txt file available at
#   https://opensubdiv.org/license.
#

#-------------------------------------------------------------------------------
set(PUBLIC_HEADER_FILES
    bilinearScheme.h
    catmarkScheme.h
    crease.h
    loopScheme.h
    options.h
    scheme.h
    types.h
)

set(PRIVATE_HEADER_FILES )

#-------------------------------------------------------------------------------
# source & headers
set(SOURCE_FILES
    crease.cpp
    typeTraits.cpp
)

set(DOXY_HEADER_FILES ${PUBLIC_HEADER_FILES})

include_directories("${CMAKE_CURRENT_BINARY_DIR}")

if (NOT NO_LIB)
    add_library(sdc_obj
        OBJECT
            ${SOURCE_FILES}
            ${PRIVATE_HEADER_FILES}
            ${PUBLIC_HEADER_FILES}
    )

    set_target_properties(sdc_obj
        PROPERTIES
            FOLDER "opensubdiv"
    )

endif()

#-------------------------------------------------------------------------------
osd_add_doxy_headers( "${DOXY_HEADER_FILES}" )

install(
    FILES
        ${PUBLIC_HEADER_FILES}
    DESTINATION
        "${CMAKE_INCDIR_BASE}/sdc"
    PERMISSIONS
        OWNER_READ
        GROUP_READ
        WORLD_READ )

