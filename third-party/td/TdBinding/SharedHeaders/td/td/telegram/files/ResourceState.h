//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ResourceState {
 public:
  void start_use(int64 x);

  void stop_use(int64 x);

  void update_limit(int64 extra);

  bool update_estimated_limit(int64 extra);

  void set_unit_size(size_t new_unit_size) {
    unit_size_ = new_unit_size;
  }

  int64 active_limit() const;

  int64 get_using() const {
    return using_;
  }

  int64 unused() const;

  int64 estimated_extra() const;

  size_t unit_size() const {
    return unit_size_;
  }

  ResourceState &operator+=(const ResourceState &other);

  ResourceState &operator-=(const ResourceState &other);

  void update_master(const ResourceState &other);

  void update_slave(const ResourceState &other);

  friend StringBuilder &operator<<(StringBuilder &sb, const ResourceState &state);

 private:
  int64 estimated_limit_ = 0;  // me
  int64 limit_ = 0;            // master
  int64 used_ = 0;             // me
  int64 using_ = 0;            // me
  size_t unit_size_ = 1;       // me
};

StringBuilder &operator<<(StringBuilder &sb, const ResourceState &state);

}  // namespace td
