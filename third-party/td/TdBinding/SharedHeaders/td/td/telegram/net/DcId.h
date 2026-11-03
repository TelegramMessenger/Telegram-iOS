//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <tuple>

namespace td {

class DcId {
 public:
  DcId() = default;

  static constexpr int32 MAX_RAW_DC_ID = 1000;

  static bool is_valid(int32 dc_id) {
    return 1 <= dc_id && dc_id <= MAX_RAW_DC_ID;
  }
  static DcId main() {
    return DcId{MainDc, false};
  }
  static DcId invalid() {
    return DcId{Invalid, false};
  }
  static DcId internal(int32 id) {
    CHECK(is_valid(id));
    return DcId{id, false};
  }
  static DcId external(int32 id) {
    CHECK(is_valid(id));
    return DcId{id, true};
  }
  static DcId empty() {
    return {};
  }
  static DcId from_value(int32 value) {
    return DcId{value, false};
  }
  static DcId create(int32 dc_id_value) {
    if (DcId::is_valid(dc_id_value)) {
      return DcId(dc_id_value, false);
    } else {
      return DcId::invalid();
    }
  }

  bool is_empty() const {
    return !is_valid();
  }
  bool is_main() const {
    return dc_id_ == MainDc;
  }
  int32 get_raw_id() const {
    CHECK(is_exact());
    return dc_id_;
  }
  int32 get_value() const {
    return dc_id_;
  }
  bool is_internal() const {
    return !is_external();
  }
  bool is_external() const {
    return is_external_;
  }
  bool is_exact() const {
    return dc_id_ > 0;
  }
  bool operator==(DcId other) const {
    return dc_id_ == other.dc_id_ && is_external_ == other.is_external_;
  }
  bool operator<(DcId other) const {
    return std::tie(dc_id_, is_external_) < std::tie(other.dc_id_, other.is_external_);
  }
  bool operator!=(DcId other) const {
    return !(*this == other);
  }

 private:
  enum : int32 { Empty = 0, MainDc = -1, Invalid = -2 };
  int32 dc_id_{Empty};
  bool is_external_{false};

  DcId(int32 dc_id, bool is_external) : dc_id_(dc_id), is_external_(is_external) {
  }

  bool is_valid() const {
    return is_exact() || is_main();
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, const DcId &dc_id) {
  sb << "DcId{";
  if (dc_id == DcId::invalid()) {
    sb << "invalid";
  } else if (dc_id == DcId()) {
    sb << "empty";
  } else if (dc_id.is_empty()) {
    sb << "is_empty";
  } else if (dc_id.is_main()) {
    sb << "main";
  } else {
    sb << dc_id.get_raw_id();
    if (dc_id.is_external()) {
      sb << " external";
    }
  }
  sb << "}";
  return sb;
}

}  // namespace td
