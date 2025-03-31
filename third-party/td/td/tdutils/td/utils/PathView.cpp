//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/PathView.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"

namespace td {

PathView::PathView(Slice path) : path_(path) {
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

Slice PathView::parent_dir_noslash() const {
  if (last_slash_ < 0) {
    return Slice(".");
  }
  if (last_slash_ == 0) {
    static char buf[1];
    buf[0] = TD_DIR_SLASH;
    return Slice(buf, 1);
  }
  return path_.substr(0, last_slash_);
}

Slice PathView::relative(Slice path, Slice dir, bool force) {
  if (begins_with(path, dir)) {
    path.remove_prefix(dir.size());
    return path;
  }
  if (force) {
    return Slice();
  }
  return path;
}

Slice PathView::dir_and_file(Slice path) {
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

}  // namespace td
