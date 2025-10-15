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

#if defined(_WIN32) || defined(_WIN64)
#include "third_party/dirent.h"

#include "lib/jxl/base/status.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif  // NOMINMAX
#include <windows.h>

#include <memory>
#include <string>

int mkdir(const char* path, mode_t /*mode*/) {
  const LPSECURITY_ATTRIBUTES sec = nullptr;
  if (!CreateDirectory(path, sec)) {
    JXL_NOTIFY_ERROR("Failed to create directory %s", path);
    return -1;
  }
  return 0;
}

// Modified from code bearing the following notice:
// https://trac.wildfiregames.com/browser/ps/trunk/source/lib/sysdep/os/
/* Copyright (C) 2010 Wildfire Games.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

struct DIR {
  HANDLE hFind;

  WIN32_FIND_DATA findData;  // indeterminate if hFind == INVALID_HANDLE_VALUE

  // readdir will return the address of this member.
  // (must be stored in DIR to allow multiple independent
  // opendir/readdir sequences).
  dirent ent;

  // used by readdir to skip the first FindNextFile.
  size_t numCalls = 0;
};

static bool IsValidDirectory(const char* path) {
  const DWORD fileAttributes = GetFileAttributes(path);

  // path not found
  if (fileAttributes == INVALID_FILE_ATTRIBUTES) return false;

  // not a directory
  if ((fileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) return false;

  return true;
}

DIR* opendir(const char* path) {
  if (!IsValidDirectory(path)) {
    errno = ENOENT;
    return nullptr;
  }

  std::unique_ptr<DIR> d(new DIR);

  // NB: "c:\\path" only returns information about that directory;
  // trailing slashes aren't allowed. append "\\*" to retrieve its entries.
  std::string searchPath(path);
  if (searchPath.back() != '/' && searchPath.back() != '\\') {
    searchPath += '\\';
  }
  searchPath += '*';

  // (we don't defer FindFirstFile until readdir because callers
  // expect us to return 0 if directory reading will/did fail.)
  d->hFind = FindFirstFile(searchPath.c_str(), &d->findData);
  if (d->hFind != INVALID_HANDLE_VALUE) return d.release();
  if (GetLastError() == ERROR_NO_MORE_FILES) return d.release();  // empty

  JXL_NOTIFY_ERROR("Failed to open directory %s", searchPath.c_str());
  return nullptr;
}

int closedir(DIR* dir) {
  delete dir;
  return 0;
}

dirent* readdir(DIR* d) {
  // "empty" case from opendir
  if (d->hFind == INVALID_HANDLE_VALUE) return nullptr;

  // until end of directory or a valid entry was found:
  for (;;) {
    if (d->numCalls++ != 0)  // (skip first call to FindNextFile - see opendir)
    {
      if (!FindNextFile(d->hFind, &d->findData)) {
        JXL_ASSERT(GetLastError() == ERROR_NO_MORE_FILES);
        SetLastError(0);
        return nullptr;  // end of directory or error
      }
    }

    // only return non-hidden and non-system entries
    if ((d->findData.dwFileAttributes &
         (FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM)) == 0) {
      d->ent.d_name = d->findData.cFileName;
      return &d->ent;
    }
  }
}

#endif  // #if defined(_WIN32) || defined(_WIN64)
