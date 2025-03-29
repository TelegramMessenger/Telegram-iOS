//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/path.h"
#include "td/utils/Slice.h"

int main(int argc, char *argv[]) {
  if (argc < 1) {
    return 1;
  }
  td::CSlice dir(argv[1]);
  int cnt = 0;
  auto status = td::walk_path(dir, [&](td::CSlice path, auto type) {
    if (type != td::WalkPath::Type::EnterDir) {
      cnt++;
    }
    auto type_name = [&] {
      switch (type) {
        case td::WalkPath::Type::EnterDir:
          return td::CSlice("Open");
        case td::WalkPath::Type::ExitDir:
          return td::CSlice("Exit");
        case td::WalkPath::Type::RegularFile:
          return td::CSlice("File");
        case td::WalkPath::Type::Symlink:
          return td::CSlice("Link");
        default:
          UNREACHABLE();
          return td::CSlice();
      }
    }();
    LOG(INFO) << type_name << ' ' << path;
    //if (is_dir) {
    // td::rmdir(path);
    //} else {
    // td::unlink(path);
    //}
  });
  LOG(INFO) << status << ": " << cnt;
}
