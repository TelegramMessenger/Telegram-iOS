/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/buffer.h"
#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Status.h"

namespace td {

Result<BufferSlice> read_file(CSlice path, int64 size = -1, int64 offset = 0);
Result<string> read_file_str(CSlice path, int64 size = -1, int64 offset = 0);
Result<SecureString> read_file_secure(CSlice path, int64 size = -1, int64 offset = 0);

Status copy_file(CSlice from, CSlice to, int64 size = -1) TD_WARN_UNUSED_RESULT;

struct WriteFileOptions {
  bool need_sync = true;
  bool need_lock = true;
};
Status write_file(CSlice to, Slice data, WriteFileOptions options = {}) TD_WARN_UNUSED_RESULT;

string clean_filename(CSlice name);

// write file and ensure that it either fully overriden with new data, or left intact.
// Uses path_tmp to temporary storat data, than calls rename
Status atomic_write_file(CSlice path, Slice data, CSlice path_tmp = {});

}  // namespace td
