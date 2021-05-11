ifeq ($(NDK_TOOLCHAIN_VERSION), clang)
APP_STL := c++_shared
else
APP_STL := stlport_shared
endif
APP_PLATFORM := android-12
