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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/filesystem.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/unicode.h"
#include "td/utils/utf8.h"

namespace td {

namespace {

template <class T>
T create_empty(size_t size);

template <>
string create_empty<string>(size_t size) {
  return string(size, '\0');
}

template <>
BufferSlice create_empty<BufferSlice>(size_t size) {
  return BufferSlice{size};
}
template <>
SecureString create_empty<SecureString>(size_t size) {
  return SecureString{size};
}

template <class T>
Result<T> read_file_impl(CSlice path, int64 size, int64 offset) {
  TRY_RESULT(from_file, FileFd::open(path, FileFd::Read));
  TRY_RESULT(file_size, from_file.get_size());
  if (offset < 0 || offset > file_size) {
    return Status::Error("Failed to read file: invalid offset");
  }
  if (size == -1) {
    size = file_size - offset;
  } else if (size >= 0) {
    if (size + offset > file_size) {
      size = file_size - offset;
    }
  }
  if (size < 0) {
    return Status::Error("Failed to read file: invalid size");
  }
  auto content = create_empty<T>(narrow_cast<size_t>(size));
  TRY_RESULT(got_size, from_file.pread(as_mutable_slice(content), offset));
  if (got_size != static_cast<size_t>(size)) {
    return Status::Error("Failed to read file");
  }
  from_file.close();
  return std::move(content);
}

}  // namespace

Result<BufferSlice> read_file(CSlice path, int64 size, int64 offset) {
  return read_file_impl<BufferSlice>(path, size, offset);
}

Result<string> read_file_str(CSlice path, int64 size, int64 offset) {
  return read_file_impl<string>(path, size, offset);
}

Result<SecureString> read_file_secure(CSlice path, int64 size, int64 offset) {
  return read_file_impl<SecureString>(path, size, offset);
}

// Very straightforward function. Don't expect much of it.
Status copy_file(CSlice from, CSlice to, int64 size) {
  TRY_RESULT(content, read_file(from, size));
  return write_file(to, content.as_slice());
}

Status write_file(CSlice to, Slice data, WriteFileOptions options) {
  auto size = data.size();
  TRY_RESULT(to_file, FileFd::open(to, FileFd::Truncate | FileFd::Create | FileFd::Write));
  if (options.need_lock) {
    TRY_STATUS(to_file.lock(FileFd::LockFlags::Write, to.str(), 10));
    TRY_STATUS(to_file.truncate_to_current_position(0));
  }
  TRY_RESULT(written, to_file.write(data));
  if (written != size) {
    return Status::Error(PSLICE() << "Failed to write file: written " << written << " bytes instead of " << size);
  }
  if (options.need_sync) {
    TRY_STATUS(to_file.sync());
  }
  if (options.need_lock) {
    to_file.lock(FileFd::LockFlags::Unlock, to.str(), 10).ignore();
  }
  to_file.close();
  return Status::OK();
}

static string clean_filename_part(Slice name, int max_length) {
  auto is_ok = [](uint32 code) {
    if (code < 32) {
      return false;
    }
    if (code < 127) {
      switch (code) {
        case '<':
        case '>':
        case ':':
        case '"':
        case '/':
        case '\\':
        case '|':
        case '?':
        case '*':
        case '&':
        case '`':
        case '\'':
          return false;
        default:
          return true;
      }
    }
    auto category = get_unicode_simple_category(code);

    return category == UnicodeSimpleCategory::Letter || category == UnicodeSimpleCategory::DecimalNumber ||
           category == UnicodeSimpleCategory::Number;
  };

  std::string new_name;
  int size = 0;
  for (auto *it = name.ubegin(); it != name.uend() && size < max_length;) {
    uint32 code;
    it = next_utf8_unsafe(it, &code, "clean_filename_part");
    if (!is_ok(code)) {
      if (prepare_search_character(code) == 0) {
        continue;
      }
      code = ' ';
    }
    if (new_name.empty() && (code == ' ' || code == '.')) {
      continue;
    }
    append_utf8_character(new_name, code);
    size++;
  }

  while (!new_name.empty() && (new_name.back() == ' ' || new_name.back() == '.')) {
    new_name.pop_back();
  }
  return new_name;
}

string clean_filename(CSlice name) {
  if (!check_utf8(name)) {
    return {};
  }

  PathView path_view(name);
  auto filename = clean_filename_part(path_view.file_stem(), 60);
  auto extension = clean_filename_part(path_view.extension(), 20);
  if (!extension.empty()) {
    if (filename.empty()) {
      filename = std::move(extension);
    } else {
      filename.reserve(filename.size() + 1 + extension.size());
      filename += '.';
      filename += extension;
    }
  }

  return filename;
}

Status atomic_write_file(CSlice path, Slice data, CSlice path_tmp) {
  string path_tmp_buf;
  if (path_tmp.empty()) {
    path_tmp_buf = path.str() + ".tmp";
    path_tmp = path_tmp_buf;
  }

  WriteFileOptions options;
  options.need_sync = true;
  options.need_lock = true;
  TRY_STATUS(write_file(path_tmp, data, options));
  return rename(path_tmp, path);
}
}  // namespace td
