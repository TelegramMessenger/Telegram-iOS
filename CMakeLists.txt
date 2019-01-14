cmake_minimum_required( VERSION 3.2 )

#declare project
project( lottie-player VERSION 0.0.1 LANGUAGES C CXX ASM)

#declare target
add_library( lottie-player SHARED  "" )

#declare version of the target
set(player_version_major 0)
set(player_version_minor 0)
set(player_version_patch 1)
set(player_version ${player_version_major}.${player_version_minor}.${player_version_patch} )
set_target_properties(lottie-player PROPERTIES
                        VERSION    ${player_version}
                        SOVERSION  ${player_version_major}
                      )

#declare alias so that library can be used inside the build tree, e.g. when testing
add_library(lottie-player::lottie-player ALIAS lottie-player)

#declare target compilation options
target_compile_options(lottie-player
                    PUBLIC
                        -std=c++14
                    PRIVATE
                        -Wall -fvisibility=hidden -O2)

#declare dependancy
set( CMAKE_THREAD_PREFER_PTHREAD TRUE )
find_package( Threads )

target_link_libraries(lottie-player
                    PUBLIC
                        "${CMAKE_THREAD_LIBS_INIT}"
                     )

# for dlopen, dlsym and dlclose dependancy
target_link_libraries(lottie-player
                    PRIVATE
                    ${CMAKE_DL_LIBS})

target_link_libraries(lottie-player
                    PUBLIC
                         "-Wl,--no-undefined"
                      )

#declare source and include files
add_subdirectory(inc)
add_subdirectory(src)

SET(PREFIX ${CMAKE_INSTALL_PREFIX})
SET(EXEC_DIR ${PREFIX})
SET(LIBDIR ${LIB_INSTALL_DIR})
SET(INCDIR ${PREFIX}/include)
CONFIGURE_FILE(${PROJECT_NAME}.pc.in ${PROJECT_NAME}.pc @ONLY)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc DESTINATION ${LIB_INSTALL_DIR}/pkgconfig)

#install header
install(FILES inc/lottieanimation.h inc/lottieanimation_capi.h inc/lottiecommon.h  DESTINATION include)

#install lib
install( TARGETS lottie-player EXPORT lottie-player-targets
         LIBRARY     DESTINATION    ${LIB_INSTALL_DIR}
         ARCHIVE     DESTINATION    ${LIB_INSTALL_DIR}
         INCLUDES    DESTINATION    include
       )

#install config file.

install( EXPORT lottie-player-targets
         FILE          lottie-playerTargets.cmake
         NAMESPACE     lottie-player::
         DESTINATION   ${LIB_INSTALL_DIR}/cmake/lottie-player
       )


#Create a ConfigVersion.cmake file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/lottie-playerConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(${CMAKE_CURRENT_LIST_DIR}/cmake/lottie-playerConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/lottie-playerConfig.cmake
    INSTALL_DESTINATION ${LIB_INSTALL_DIR}/cmake/lottie-player
)

#Install the config, configversion and custom find modules
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/lottie-playerConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/lottie-playerConfigVersion.cmake
    DESTINATION ${LIB_INSTALL_DIR}/cmake/lottie-player
)


export(EXPORT lottie-player-targets FILE ${CMAKE_CURRENT_BINARY_DIR}/lottie-playerTargets.cmake NAMESPACE lottie-player::)

#Register package in user's package registry
export(PACKAGE lottie-player)

