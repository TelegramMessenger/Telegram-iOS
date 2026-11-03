#
#   Copyright 2013 Pixar
#
#   Licensed under the terms set forth in the LICENSE.txt file available at
#   https://opensubdiv.org/license.
#

#-------------------------------------------------------------------------------
# source & headers
set(SOURCE_FILES
    bilinearPatchBuilder.cpp
    catmarkPatchBuilder.cpp
    error.cpp
    loopPatchBuilder.cpp
    patchBasis.cpp
    patchBuilder.cpp
    patchDescriptor.cpp
    patchMap.cpp
    patchTable.cpp
    patchTableFactory.cpp
    ptexIndices.cpp
    stencilTable.cpp
    stencilTableFactory.cpp
    stencilBuilder.cpp
    topologyDescriptor.cpp
    topologyRefiner.cpp
    topologyRefinerFactory.cpp
)

set(PRIVATE_HEADER_FILES
    bilinearPatchBuilder.h
    catmarkPatchBuilder.h
    loopPatchBuilder.h
    patchBasis.h
    patchBuilder.h
    sparseMatrix.h
    stencilBuilder.h
)

set(PUBLIC_HEADER_FILES
    error.h
    patchDescriptor.h
    patchParam.h
    patchMap.h
    patchTable.h
    patchTableFactory.h
    primvarRefiner.h
    ptexIndices.h
    stencilTable.h
    stencilTableFactory.h
    topologyDescriptor.h
    topologyLevel.h
    topologyRefiner.h
    topologyRefinerFactory.h
    types.h
)

set(DOXY_HEADER_FILES ${PUBLIC_HEADER_FILES})

#-------------------------------------------------------------------------------
if (NOT NO_LIB)

    # Compile objs first for both the CPU and GPU libs -----
    add_library(far_obj
        OBJECT
            ${SOURCE_FILES}
            ${PRIVATE_HEADER_FILES}
            ${PUBLIC_HEADER_FILES}
    )

    set_target_properties(far_obj
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
        "${CMAKE_INCDIR_BASE}/far"
    PERMISSIONS
        OWNER_READ
        GROUP_READ
        WORLD_READ )

#-------------------------------------------------------------------------------
