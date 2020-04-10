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

#include "td/utils/misc.h"
#include "td/utils/Slice.h"

namespace td {

class PathView {
 public:
  explicit PathView(Slice path) : path_(path) {
    last_slash_ = narrow_cast<int32>(path_.size()) - 1;
    while (last_slash_ >= 0 && !is_slash(path_[last_slash_])) {
      last_slash_--;
    }

    last_dot_ = static_cast<int32>(path_.size());
    for (auto i = last_dot_ - 1; i > last_slash_ + 1; i--) {
      if (path_[i] == '.') {
        last_dot_ = i;
        break;
      }
    }
  }

  bool empty() const {
    return path_.empty();
  }

  bool is_dir() const {
    if (empty()) {
      return false;
    }
    return is_slash(path_.back());
  }

  Slice parent_dir() const {
    return path_.substr(0, last_slash_ + 1);
  }

  Slice extension() const {
    if (last_dot_ == static_cast<int32>(path_.size())) {
      return Slice();
    }
    return path_.substr(last_dot_ + 1);
  }

  Slice without_extension() const {
    return path_.substr(0, last_dot_);
  }

  Slice file_stem() const {
    return path_.substr(last_slash_ + 1, last_dot_ - last_slash_ - 1);
  }

  Slice file_name() const {
    return path_.substr(last_slash_ + 1);
  }

  Slice path() const {
    return path_;
  }

  bool is_absolute() const {
    return !empty() && (is_slash(path_[0]) || (path_.size() >= 3 && path_[1] == ':' && is_slash(path_[2])));
  }

  bool is_relative() const {
    return !is_absolute();
  }

  static Slice relative(Slice path, Slice dir, bool force = false) {
    if (begins_with(path, dir)) {
      path.remove_prefix(dir.size());
      return path;
    }
    if (force) {
      return Slice();
    }
    return path;
  }

  static Slice dir_and_file(Slice path) {
    auto last_slash = static_cast<int32>(path.size()) - 1;
    while (last_slash >= 0 && !is_slash(path[last_slash])) {
      last_slash--;
    }
    if (last_slash < 0) {
      return Slice();
    }
    last_slash--;
    while (last_slash >= 0 && !is_slash(path[last_slash])) {
      last_slash--;
    }
    if (last_slash < 0) {
      return Slice();
    }
    return path.substr(last_slash + 1);
  }

 private:
  static bool is_slash(char c) {
    return c == '/' || c == '\\';
  }

  Slice path_;
  int32 last_slash_;
  int32 last_dot_;
};

}  // namespace td
