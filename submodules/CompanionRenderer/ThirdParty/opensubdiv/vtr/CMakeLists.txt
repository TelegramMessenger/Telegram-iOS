#
#   Copyright 2013 Pixar
#
#   Licensed under the terms set forth in the LICENSE.txt file available at
#   https://opensubdiv.org/license.
#

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# source & headers
set(SOURCE_FILES
     fvarLevel.cpp
     fvarRefinement.cpp
     level.cpp
     quadRefinement.cpp
     refinement.cpp
     sparseSelector.cpp
     triRefinement.cpp
)

set(PRIVATE_HEADER_FILES
     quadRefinement.h
     triRefinement.h
)

set(PUBLIC_HEADER_FILES
     array.h
     componentInterfaces.h
     fvarLevel.h
     fvarRefinement.h
     level.h
     refinement.h
     sparseSelector.h
     stackBuffer.h
     types.h
)

set(DOXY_HEADER_FILES ${PUBLIC_HEADER_FILES})

include_directories("${CMAKE_CURRENT_BINARY_DIR}")

if (NOT NO_LIB)

    # Compile objs first for both the CPU and GPU libs -----
    add_library(vtr_obj
        OBJECT
            ${SOURCE_FILES}
            ${PRIVATE_HEADER_FILES}
            ${PUBLIC_HEADER_FILES}
    )

    set_target_properties(vtr_obj
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
        "${CMAKE_INCDIR_BASE}/vtr"
    PERMISSIONS
        OWNER_READ
        GROUP_READ
        WORLD_READ )

#-------------------------------------------------------------------------------
