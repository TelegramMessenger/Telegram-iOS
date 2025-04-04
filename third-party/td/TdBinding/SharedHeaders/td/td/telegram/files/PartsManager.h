//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileBitmask.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct Part {
  int id;
  int64 offset;
  size_t size;
};

class PartsManager {
 public:
  Status init(int64 size, int64 expected_size, bool is_size_final, size_t part_size,
              const std::vector<int> &ready_parts, bool use_part_count_limit, bool is_upload) TD_WARN_UNUSED_RESULT;
  bool may_finish();
  bool ready();
  bool unchecked_ready();
  Status finish() TD_WARN_UNUSED_RESULT;

  // returns empty part if nothing to return
  Result<Part> start_part() TD_WARN_UNUSED_RESULT;
  Status on_part_ok(int part_id, size_t part_size, size_t actual_size) TD_WARN_UNUSED_RESULT;
  void on_part_failed(int part_id);
  Status set_known_prefix(int64 size, bool is_ready);
  void set_need_check();
  void set_checked_prefix_size(int64 size);
  int32 set_streaming_offset(int64 offset, int64 limit);
  void set_streaming_limit(int64 limit);

  int64 get_checked_prefix_size() const;
  int64 get_unchecked_ready_prefix_size();
  int64 get_size() const;
  int64 get_size_or_zero() const;
  int64 get_estimated_extra() const;
  int64 get_ready_size() const;
  size_t get_part_size() const;
  int32 get_part_count() const;
  int32 get_unchecked_ready_prefix_count();
  int32 get_ready_prefix_count();
  int64 get_streaming_offset() const;
  string get_bitmask();

 private:
  static constexpr int MAX_PART_COUNT = 4000;
  static constexpr int MAX_PART_COUNT_PREMIUM = 8000;
  static constexpr size_t MAX_PART_SIZE = 512 << 10;
  static constexpr int64 MAX_FILE_SIZE = static_cast<int64>(MAX_PART_SIZE) * MAX_PART_COUNT_PREMIUM;

  enum class PartStatus : int32 { Empty, Pending, Ready };

  bool is_upload_{false};
  bool need_check_{false};
  int64 checked_prefix_size_{0};

  bool known_prefix_flag_{false};
  int64 known_prefix_size_{0};

  int64 size_{0};
  int64 expected_size_{0};
  int64 min_size_{0};
  int64 max_size_{0};
  bool unknown_size_flag_{false};
  int64 ready_size_{0};
  int64 streaming_ready_size_{0};

  size_t part_size_{0};
  int part_count_{0};
  int pending_count_{0};
  int first_empty_part_{0};
  int first_not_ready_part_{0};
  int64 streaming_offset_{0};
  int64 streaming_limit_{0};
  int first_streaming_empty_part_{0};
  int first_streaming_not_ready_part_{0};
  vector<PartStatus> part_status_;
  Bitmask bitmask_;
  bool use_part_count_limit_{false};

  Status init_common(const vector<int> &ready_parts);
  Status init_known_prefix(int64 known_prefix, size_t part_size,
                           const std::vector<int> &ready_parts) TD_WARN_UNUSED_RESULT;
  Status init_no_size(size_t part_size, const std::vector<int> &ready_parts) TD_WARN_UNUSED_RESULT;

  static Part get_empty_part();

  Part get_part(int part_id) const;
  void on_part_start(int part_id);
  void update_first_empty_part();
  void update_first_not_ready_part();

  int64 get_expected_size() const;

  bool is_streaming_limit_reached();

  bool is_part_in_streaming_limit(int part_id) const;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const PartsManager &parts_manager);
};

StringBuilder &operator<<(StringBuilder &string_builder, const PartsManager &parts_manager);

}  // namespace td
