cmake_minimum_required( VERSION 3.3 )

#declare project
project( rlottie VERSION 0.0.1 LANGUAGES C CXX ASM)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE MinSizeRel)
endif()

if (NOT DEFINED BUILD_SHARED_LIBS)
    # Keep the previous behavior of the build system, consistent with Meson.
    set(BUILD_SHARED_LIBS ON)
endif()

#declare target
add_library( rlottie )
set_target_properties( rlottie PROPERTIES DEFINE_SYMBOL LOT_BUILD )

#declare version of the target
set(player_version_major 0)
set(player_version_minor 0)
set(player_version_patch 1)
set(player_version ${player_version_major}.${player_version_minor}.${player_version_patch} )
set_target_properties(rlottie PROPERTIES
                        VERSION    ${player_version}
                        SOVERSION  ${player_version_major}
                      )

#declare alias so that library can be used inside the build tree, e.g. when testing
add_library(rlottie::rlottie ALIAS rlottie)

option(LOTTIE_MODULE "Enable LOTTIE MODULE SUPPORT" ON)
option(LOTTIE_THREAD "Enable LOTTIE THREAD SUPPORT" ON)
option(LOTTIE_CACHE "Enable LOTTIE CACHE SUPPORT" ON)
option(LOTTIE_TEST "Build LOTTIE AUTOTESTS" OFF)

CONFIGURE_FILE(${CMAKE_CURRENT_LIST_DIR}/cmake/config.h.in config.h)

target_include_directories(rlottie
    PRIVATE
        "${CMAKE_CURRENT_BINARY_DIR}"
    )

#declare target compilation options
target_compile_options(rlottie
                    PUBLIC
                    PRIVATE
                        -std=c++14
                        -fno-exceptions
                        -fno-unwind-tables
                        -fno-asynchronous-unwind-tables
                        -fno-rtti
                        -Wall
                        -Werror
                        -Wextra
                        -Wnon-virtual-dtor
                        -Woverloaded-virtual
                        -Wno-unused-parameter
                        -fvisibility=hidden
                    )

#declare dependancy
set( CMAKE_THREAD_PREFER_PTHREAD TRUE )
find_package( Threads )

target_link_libraries(rlottie
                    PUBLIC
                        "${CMAKE_THREAD_LIBS_INIT}"
                     )

if (LOTTIE_MODULE)
    # for dlopen, dlsym and dlclose dependancy
    target_link_libraries(rlottie PRIVATE ${CMAKE_DL_LIBS})
endif()

if(APPLE)
    target_link_libraries(rlottie
                        PUBLIC
                             "-Wl, -undefined error"
                          )
else()
    target_link_libraries(rlottie
                        PUBLIC
                             "-Wl,--no-undefined"
                          )
endif()


if (NOT LIB_INSTALL_DIR)
    set (LIB_INSTALL_DIR "/usr/lib")
endif (NOT LIB_INSTALL_DIR)

#declare source and include files
add_subdirectory(inc)
add_subdirectory(src)
add_subdirectory(example)

if (LOTTIE_TEST)
    enable_testing()
    add_subdirectory(test)
endif()

SET(PREFIX ${CMAKE_INSTALL_PREFIX})
SET(EXEC_DIR ${PREFIX})
SET(LIBDIR ${LIB_INSTALL_DIR})
SET(INCDIR ${PREFIX}/include)

CONFIGURE_FILE(${PROJECT_NAME}.pc.in ${PROJECT_NAME}.pc)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc DESTINATION ${LIB_INSTALL_DIR}/pkgconfig)


#install header
install(FILES
        inc/rlottie.h
        inc/rlottie_capi.h
        inc/rlottiecommon.h
        DESTINATION include)

#install lib
install( TARGETS rlottie EXPORT rlottie-targets
         LIBRARY     DESTINATION    ${LIB_INSTALL_DIR}
         ARCHIVE     DESTINATION    ${LIB_INSTALL_DIR}
         INCLUDES    DESTINATION    include
       )

#install config file.

install( EXPORT rlottie-targets
         FILE          rlottieTargets.cmake
         NAMESPACE     rlottie::
         DESTINATION   ${LIB_INSTALL_DIR}/cmake/rlottie
       )


#Create a ConfigVersion.cmake file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/rlottieConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(${CMAKE_CURRENT_LIST_DIR}/cmake/rlottieConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/rlottieConfig.cmake
    INSTALL_DESTINATION ${LIB_INSTALL_DIR}/cmake/rlottie
)

#Install the config, configversion and custom find modules
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/rlottieConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/rlottieConfigVersion.cmake
    DESTINATION ${LIB_INSTALL_DIR}/cmake/rlottie
)


export(EXPORT rlottie-targets FILE ${CMAKE_CURRENT_BINARY_DIR}/rlottieTargets.cmake NAMESPACE rlottie::)

#Register package in user's package registry
export(PACKAGE rlottie)

