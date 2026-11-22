# Copyright (c) the JPEG XL Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# We need to CACHE the SJPEG_BUILD_EXAMPLES to not be removed by the option()
# inside SJPEG.
set(SJPEG_BUILD_EXAMPLES NO CACHE BOOL "Examples")
# SJPEG uses OpenGL which throws a warning if multiple options are installed.
# This setting makes it prefer the new version.
set(OpenGL_GL_PREFERENCE GLVND)

# Build SJPEG as a static library.
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
add_subdirectory(sjpeg EXCLUDE_FROM_ALL)
target_include_directories(sjpeg PUBLIC "${CMAKE_CURRENT_LIST_DIR}/sjpeg/src/")
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP})
