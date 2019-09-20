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
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"

namespace td {
namespace actor {
namespace core {
class SchedulerId {
 public:
  SchedulerId() : id_(-1) {
  }
  explicit SchedulerId(uint8 id) : id_(id) {
  }
  bool is_valid() const {
    return id_ >= 0;
  }
  uint8 value() const {
    CHECK(is_valid());
    return static_cast<uint8>(id_);
  }
  bool operator==(SchedulerId scheduler_id) const {
    return id_ == scheduler_id.id_;
  }

 private:
  int32 id_{0};
};
}  // namespace core
}  // namespace actor
}  // namespace td
