cmake_minimum_required( VERSION 3.2 )

#declare project
project( lottie-player LANGUAGES C CXX )

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

#declare source and include files
add_subdirectory(inc)
add_subdirectory(src)

CONFIGURE_FILE(${PROJECT_NAME}.pc.in ${PROJECT_NAME}.pc @ONLY)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc DESTINATION lib/pkgconfig)

#install header
install(FILES inc/lottieplayer.h DESTINATION include)

#install lib
install( TARGETS lottie-player EXPORT lottie-player-targets
         LIBRARY     DESTINATION    lib
         ARCHIVE     DESTINATION    lib
         INCLUDES    DESTINATION    include
       )

#install config file.
install( EXPORT lottie-player-targets
         FILE          lottie-player.cmake
         NAMESPACE     lottie-player::
         DESTINATION   lib/cmake/lottie-player
       )


#Register package in user's package registry
export(PACKAGE lottie-player)
