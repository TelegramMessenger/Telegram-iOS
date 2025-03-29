include(CMakeFindDependencyMacro)
#TODO: write all external dependencies
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/TdTargets.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/TdTargets.cmake")
endif()
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/TdStaticTargets.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/TdStaticTargets.cmake")
endif()
