// Copyright (c) the JPEG XL Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef LIB_JXL_THIRD_PARTY_DIRENT_H_
#define LIB_JXL_THIRD_PARTY_DIRENT_H_

// Emulates POSIX readdir for Windows

#if defined(_WIN32) || defined(_WIN64)

#include <sys/stat.h>  // S_IFREG

#ifndef _MODE_T_
typedef unsigned int mode_t;
#endif  // _MODE_T_
int mkdir(const char* path, mode_t mode);

struct dirent {
  char* d_name;  // no path
};

#define stat _stat64

#ifndef S_ISDIR
#define S_ISDIR(m) (m & S_IFDIR)
#endif  // S_ISDIR

#ifndef S_ISREG
#define S_ISREG(m) (m & S_IFREG)
#endif  // S_ISREG

struct DIR;
DIR* opendir(const char* path);
int closedir(DIR* dir);
dirent* readdir(DIR* d);

#endif  // #if defined(_WIN32) || defined(_WIN64)
#endif  // LIB_JXL_THIRD_PARTY_DIRENT_H_
