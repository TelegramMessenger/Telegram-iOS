//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/PartsManager.h"

#include "td/telegram/files/FileLoaderUtils.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

#include <limits>
#include <numeric>

namespace td {

namespace {
int64 calc_part_count(int64 size, int64 part_size) {
  CHECK(part_size != 0);
  return (size + part_size - 1) / part_size;
}
}  // namespace

Status PartsManager::init_known_prefix(int64 known_prefix, size_t part_size, const std::vector<int> &ready_parts) {
  known_prefix_flag_ = true;
  known_prefix_size_ = known_prefix;
  return init_no_size(part_size, ready_parts);
}

int32 PartsManager::set_streaming_offset(int64 offset, int64 limit) {
  auto finish = [&] {
    set_streaming_limit(limit);
    update_first_not_ready_part();
    return first_streaming_not_ready_part_;
  };

  if (offset < 0 || need_check_ || (!unknown_size_flag_ && get_size() < offset)) {
    streaming_offset_ = 0;
    LOG_IF(ERROR, offset != 0) << "Ignore streaming_offset " << offset << ", need_check_ = " << need_check_
                               << ", unknown_size_flag_ = " << unknown_size_flag_ << ", size = " << get_size();

    return finish();
  }

  auto part_id = offset / part_size_;
  if (use_part_count_limit_ && part_id >= MAX_PART_COUNT_PREMIUM) {
    streaming_offset_ = 0;
    LOG(ERROR) << "Ignore streaming_offset " << offset << " in part " << part_id;

    return finish();
  }

  streaming_offset_ = offset;
  first_streaming_empty_part_ = narrow_cast<int>(part_id);
  first_streaming_not_ready_part_ = narrow_cast<int>(part_id);
  if (part_count_ < first_streaming_empty_part_) {
    part_count_ = first_streaming_empty_part_;
    part_status_.resize(part_count_, PartStatus::Empty);
  }

  return finish();
}

void PartsManager::set_streaming_limit(int64 limit) {
  streaming_limit_ = limit;
  streaming_ready_size_ = 0;
  if (streaming_limit_ == 0) {
    return;
  }
  for (int part_id = 0; part_id < part_count_; part_id++) {
    if (is_part_in_streaming_limit(part_id) && part_status_[part_id] == PartStatus::Ready) {
      streaming_ready_size_ += get_part(part_id).size;
    }
  }
}

Status PartsManager::init_no_size(size_t part_size, const std::vector<int> &ready_parts) {
  unknown_size_flag_ = true;
  size_ = 0;
  min_size_ = 0;
  max_size_ = std::numeric_limits<int64>::max();

  if (part_size != 0) {
    part_size_ = part_size;
  } else {
    part_size_ = 32 << 10;
    while (part_size_ < MAX_PART_SIZE && calc_part_count(expected_size_, part_size_) > MAX_PART_COUNT) {
      part_size_ *= 2;
    }
    // just in case if expected_size_ is wrong
    if (part_size_ < MAX_PART_SIZE) {
      part_size_ *= 2;
    }
  }
  part_count_ =
      std::accumulate(ready_parts.begin(), ready_parts.end(), 0, [](auto a, auto b) { return max(a, b + 1); });

  return init_common(ready_parts);
}

Status PartsManager::init(int64 size, int64 expected_size, bool is_size_final, size_t part_size,
                          const std::vector<int> &ready_parts, bool use_part_count_limit, bool is_upload) {
  CHECK(expected_size >= size);
  is_upload_ = is_upload;
  use_part_count_limit_ = use_part_count_limit;
  expected_size_ = expected_size;
  if (expected_size_ > MAX_FILE_SIZE) {
    return Status::Error("Too big file");
  }
  if (!is_size_final) {
    return init_known_prefix(size, part_size, ready_parts);
  }
  if (size == 0) {
    return init_no_size(part_size, ready_parts);
  }
  LOG_CHECK(size > 0) << tag("size", size) << ' ' << *this;
  unknown_size_flag_ = false;
  size_ = size;

  if (part_size != 0) {
    part_size_ = part_size;
    if (use_part_count_limit_ && part_size_ < MAX_PART_SIZE &&
        calc_part_count(expected_size_, part_size_) > MAX_PART_COUNT) {
      CHECK(is_upload_);
      return Status::Error("FILE_UPLOAD_RESTART");
    }
  } else {
    part_size_ = 64 << 10;
    while (part_size_ < MAX_PART_SIZE && calc_part_count(expected_size_, part_size_) > MAX_PART_COUNT) {
      part_size_ *= 2;
    }
  }
  LOG_CHECK(1 <= size_) << *this;
  LOG_CHECK(!use_part_count_limit || calc_part_count(expected_size_, part_size_) <= MAX_PART_COUNT_PREMIUM)
      << tag("is_size_final", is_size_final) << tag("ready_parts", ready_parts.size()) << ' ' << *this;
  part_count_ = static_cast<int>(calc_part_count(size_, part_size_));

  return init_common(ready_parts);
}

bool PartsManager::unchecked_ready() {
  VLOG(file_loader) << "Check readiness. Ready size is " << ready_size_ << ", total size is " << size_
                    << ", unknown_size_flag = " << unknown_size_flag_ << ", need_check = " << need_check_
                    << ", checked_prefix_size = " << checked_prefix_size_;
  return !unknown_size_flag_ && ready_size_ == size_;
}

bool PartsManager::may_finish() {
  if (is_streaming_limit_reached()) {
    return true;
  }
  return ready();
}

bool PartsManager::ready() {
  return unchecked_ready() && (!need_check_ || checked_prefix_size_ == size_);
}

Status PartsManager::finish() {
  if (ready()) {
    return Status::OK();
  }
  if (is_streaming_limit_reached()) {
    return Status::Error("FILE_DOWNLOAD_LIMIT");
  }
  return Status::Error("File transferring not finished");
}

void PartsManager::update_first_empty_part() {
  while (first_empty_part_ < part_count_ && part_status_[first_empty_part_] != PartStatus::Empty) {
    first_empty_part_++;
  }

  if (streaming_offset_ == 0) {
    first_streaming_empty_part_ = first_empty_part_;
    return;
  }
  while (first_streaming_empty_part_ < part_count_ && part_status_[first_streaming_empty_part_] != PartStatus::Empty) {
    first_streaming_empty_part_++;
  }
}

void PartsManager::update_first_not_ready_part() {
  while (first_not_ready_part_ < part_count_ && part_status_[first_not_ready_part_] == PartStatus::Ready) {
    first_not_ready_part_++;
  }
  if (streaming_offset_ == 0) {
    first_streaming_not_ready_part_ = first_not_ready_part_;
    return;
  }
  while (first_streaming_not_ready_part_ < part_count_ &&
         part_status_[first_streaming_not_ready_part_] == PartStatus::Ready) {
    first_streaming_not_ready_part_++;
  }
}

int32 PartsManager::get_unchecked_ready_prefix_count() {
  update_first_not_ready_part();
  return first_not_ready_part_;
}

int32 PartsManager::get_ready_prefix_count() {
  auto res = get_unchecked_ready_prefix_count();
  if (need_check_) {
    auto checked_parts = narrow_cast<int32>(checked_prefix_size_ / part_size_);
    if (checked_parts < res) {
      return checked_parts;
    }
  }
  return res;
}

int64 PartsManager::get_streaming_offset() const {
  return streaming_offset_;
}

string PartsManager::get_bitmask() {
  int32 prefix_count = -1;
  if (need_check_) {
    prefix_count = narrow_cast<int32>(checked_prefix_size_ / part_size_);
  }
  return bitmask_.encode(prefix_count);
}

bool PartsManager::is_part_in_streaming_limit(int part_id) const {
  CHECK(part_id < part_count_);
  auto offset_begin = static_cast<int64>(part_id) * static_cast<int64>(get_part_size());
  auto offset_end = offset_begin + static_cast<int64>(get_part(part_id).size);

  if (streaming_limit_ == 0) {
    return true;
  }

  auto is_intersect_with = [&](int64 begin, int64 end) {
    return max(begin, offset_begin) < min(end, offset_end);
  };

  auto streaming_begin = streaming_offset_;
  auto streaming_end = streaming_offset_ + streaming_limit_;
  if (is_intersect_with(streaming_begin, streaming_end)) {
    return true;
  }
  // wrap limit
  if (!unknown_size_flag_ && streaming_end > get_size() && is_intersect_with(0, streaming_end - get_size())) {
    return true;
  }
  return false;
}

bool PartsManager::is_streaming_limit_reached() {
  if (streaming_limit_ == 0) {
    return false;
  }
  update_first_not_ready_part();
  auto part_id = first_streaming_not_ready_part_;

  //LOG(ERROR) << unknown_size_flag_ << ' ' << part_id << ' ' << part_count_ << ' ' << first_not_ready_part_ << ' '
  //           << get_estimated_extra() << ' ' << (part_id == part_count_ ? true : is_part_in_streaming_limit(part_id));

  // wrap
  if (!unknown_size_flag_ && part_id == part_count_) {
    part_id = first_not_ready_part_;
  }
  if (part_id == part_count_ || !is_part_in_streaming_limit(part_id)) {
    return get_estimated_extra() == 0;
  }
  return false;
}

Result<Part> PartsManager::start_part() {
  update_first_empty_part();
  auto part_id = first_streaming_empty_part_;
  if (known_prefix_flag_ && part_id >= static_cast<int>(known_prefix_size_ / part_size_)) {
    return Status::Error(-1, "Wait for prefix to be known");
  }
  if (part_id == part_count_) {
    if (unknown_size_flag_) {
      part_count_++;
      if (part_count_ > MAX_PART_COUNT_PREMIUM + (use_part_count_limit_ ? 0 : 64)) {
        if (!is_upload_) {
          // Caller will try to increase part size if it is possible
          return Status::Error("FILE_DOWNLOAD_RESTART_INCREASE_PART_SIZE");
        }
        return Status::Error("Too big file with unknown size");
      }
      part_status_.push_back(PartStatus::Empty);
    } else {
      if (first_empty_part_ < part_count_) {
        part_id = first_empty_part_;
      } else {
        return get_empty_part();
      }
    }
  }

  if (!is_part_in_streaming_limit(part_id) ||
      static_cast<int64>(part_id) * static_cast<int64>(get_part_size()) >= (unknown_size_flag_ ? max_size_ : size_)) {
    return get_empty_part();
  }

  CHECK(part_status_[part_id] == PartStatus::Empty);
  on_part_start(part_id);
  return get_part(part_id);
}

Status PartsManager::set_known_prefix(int64 size, bool is_ready) {
  if (!known_prefix_flag_ || size < known_prefix_size_ ||
      (!is_ready && size / static_cast<int64>(part_size_) < static_cast<int64>(part_status_.size()))) {
    CHECK(is_upload_);
    return Status::Error("FILE_UPLOAD_RESTART");
  }
  known_prefix_size_ = size;
  expected_size_ = max(known_prefix_size_, expected_size_);

  CHECK(static_cast<size_t>(part_count_) == part_status_.size());
  if (is_ready) {
    part_count_ = static_cast<int>(calc_part_count(size, part_size_));

    size_ = size;
    unknown_size_flag_ = false;
    known_prefix_flag_ = false;
    if (streaming_limit_ != 0) {
      set_streaming_limit(streaming_limit_);
    }
  } else {
    part_count_ = static_cast<int>(size / static_cast<int64>(part_size_));
  }

  LOG_CHECK(static_cast<size_t>(part_count_) >= part_status_.size()) << size << ' ' << is_ready << ' ' << *this;
  part_status_.resize(part_count_);
  if (use_part_count_limit_ && part_size_ < MAX_PART_SIZE &&
      calc_part_count(expected_size_, part_size_) > MAX_PART_COUNT) {
    CHECK(is_upload_);
    return Status::Error("FILE_UPLOAD_RESTART");
  }
  return Status::OK();
}

Status PartsManager::on_part_ok(int part_id, size_t part_size, size_t actual_size) {
  LOG_CHECK(static_cast<size_t>(part_id) < part_status_.size())
      << part_id << ' ' << part_size << ' ' << actual_size << ' ' << *this;
  LOG_CHECK(part_status_[part_id] == PartStatus::Pending) << part_id << ' ' << static_cast<int32>(part_status_[part_id])
                                                          << ' ' << part_size << ' ' << actual_size << ' ' << *this;
  pending_count_--;

  part_status_[part_id] = PartStatus::Ready;
  if (actual_size != 0) {
    bitmask_.set(part_id);
  }
  ready_size_ += narrow_cast<int64>(actual_size);
  if (streaming_limit_ > 0 && is_part_in_streaming_limit(part_id)) {
    streaming_ready_size_ += narrow_cast<int64>(actual_size);
  }

  VLOG(file_loader) << "Transferred part " << part_id << " of size " << part_size << " with actual size " << actual_size
                    << ", total ready size = " << ready_size_;

  int64 offset = narrow_cast<int64>(part_size_) * part_id;
  int64 end_offset = offset + narrow_cast<int64>(actual_size);
  if (unknown_size_flag_) {
    CHECK(part_size == part_size_);
    bool is_size_changed = false;
    if (actual_size < part_size_ && end_offset < max_size_) {
      max_size_ = end_offset;
      is_size_changed = true;
    }
    if (actual_size) {
      min_size_ = max(min_size_, end_offset);
    }
    if (min_size_ > max_size_) {
      auto status = Status::Error(PSLICE() << "Failed to transfer file: " << tag("min_size", min_size_)
                                           << tag("max_size", max_size_));
      LOG(ERROR) << status << ' ' << *this;
      return status;
    } else if (min_size_ == max_size_) {
      unknown_size_flag_ = false;
      size_ = min_size_;
      is_size_changed = true;
    }

    if (is_size_changed && streaming_limit_ != 0) {
      set_streaming_limit(streaming_limit_);
    }
  } else {
    if ((actual_size < part_size && offset < size_) || (offset >= size_ && actual_size > 0)) {
      auto status = Status::Error(PSLICE() << "Failed to transfer file: " << tag("size", size_) << tag("offset", offset)
                                           << tag("transferred size", actual_size) << tag("part size", part_size));
      LOG(ERROR) << status << ' ' << *this;
      return status;
    }
  }
  return Status::OK();
}

void PartsManager::on_part_failed(int32 part_id) {
  CHECK(part_status_[part_id] == PartStatus::Pending);
  pending_count_--;
  part_status_[part_id] = PartStatus::Empty;
  if (part_id < first_empty_part_) {
    first_empty_part_ = part_id;
  }
  if (streaming_offset_ == 0) {
    first_streaming_empty_part_ = part_id;
    return;
  }
  auto offset_part_id = narrow_cast<int>(streaming_offset_ / part_size_);
  if (part_id >= offset_part_id && part_id < first_streaming_empty_part_) {
    first_streaming_empty_part_ = part_id;
  }
}

int64 PartsManager::get_size() const {
  CHECK(!unknown_size_flag_);
  return size_;
}

int64 PartsManager::get_size_or_zero() const {
  return size_;
}

int64 PartsManager::get_estimated_extra() const {
  auto total_estimated_extra = get_expected_size() - get_ready_size();
  if (streaming_limit_ != 0) {
    int64 part_size = get_part_size();
    auto round_up = [part_size](int64 size) {
      return (size + part_size - 1) / part_size * part_size;
    };
    int64 streaming_begin = streaming_offset_ / part_size * part_size;
    int64 streaming_size = 0;
    if (unknown_size_flag_) {
      streaming_begin = min(streaming_begin, max_size_);
      int64 streaming_end = min(round_up(streaming_offset_ + streaming_limit_), max_size_);
      streaming_size = streaming_end - streaming_begin;
    } else {
      if (streaming_offset_ + streaming_limit_ <= size_) {
        int64 streaming_end = min(round_up(streaming_offset_ + streaming_limit_), size_);
        streaming_size = streaming_end - streaming_begin;
      } else {
        if (streaming_offset_ < size_) {
          int64 prefix = min(round_up(streaming_offset_ + streaming_limit_ - size_), size_);
          int64 suffix = size_ - streaming_begin;
          streaming_size = min(size_, prefix + suffix);
        }
      }
    }
    int64 res = streaming_size;

    //TODO: delete this block if CHECK won't fail
    int64 sub = 0;
    for (int part_id = 0; part_id < part_count_; part_id++) {
      if (is_part_in_streaming_limit(part_id) && part_status_[part_id] == PartStatus::Ready) {
        sub += get_part(part_id).size;
      }
    }
    CHECK(sub == streaming_ready_size_);

    res -= streaming_ready_size_;
    CHECK(res >= 0);
    return res;
  }
  return total_estimated_extra;
}

int64 PartsManager::get_ready_size() const {
  return ready_size_;
}

int64 PartsManager::get_expected_size() const {
  if (unknown_size_flag_) {
    return min(max(min_size_ + static_cast<int64>(512 << 10), get_ready_size() * 2), max_size_);
  }
  return get_size();
}

size_t PartsManager::get_part_size() const {
  return part_size_;
}

int32 PartsManager::get_part_count() const {
  return part_count_;
}

Status PartsManager::init_common(const std::vector<int> &ready_parts) {
  ready_size_ = 0;
  streaming_ready_size_ = 0;
  pending_count_ = 0;
  first_empty_part_ = 0;
  first_not_ready_part_ = 0;
  part_status_ = vector<PartStatus>(part_count_);

  for (auto i : ready_parts) {
    if (known_prefix_flag_ && i >= static_cast<int>(known_prefix_size_ / part_size_)) {
      CHECK(is_upload_);
      return Status::Error("FILE_UPLOAD_RESTART");
    }
    if (is_upload_ && i >= part_count_) {
      return Status::Error("FILE_UPLOAD_RESTART");
    }
    LOG_CHECK(0 <= i && i < part_count_) << tag("i", i)
                                         << tag("real part_count",
                                                std::accumulate(ready_parts.begin(), ready_parts.end(), 0,
                                                                [](auto a, auto b) { return max(a, b + 1); }))
                                         << ' ' << *this;
    part_status_[i] = PartStatus::Ready;
    bitmask_.set(i);
    auto part = get_part(i);
    ready_size_ += narrow_cast<int64>(part.size);
  }

  checked_prefix_size_ = get_ready_prefix_count() * narrow_cast<int64>(part_size_);

  return Status::OK();
}

void PartsManager::set_need_check() {
  need_check_ = true;
  set_streaming_offset(0, 0);
}

void PartsManager::set_checked_prefix_size(int64 size) {
  checked_prefix_size_ = size;
}

int64 PartsManager::get_checked_prefix_size() const {
  return checked_prefix_size_;
}

int64 PartsManager::get_unchecked_ready_prefix_size() {
  update_first_not_ready_part();
  auto count = first_not_ready_part_;
  if (count == 0) {
    return 0;
  }
  auto part = get_part(count - 1);
  int64 res = part.offset;
  if (!unknown_size_flag_) {
    res += narrow_cast<int64>(part.size);
    res = min(res, get_size());
  }
  return res;
}

Part PartsManager::get_part(int part_id) const {
  auto size = narrow_cast<int64>(part_size_);
  auto offset = size * part_id;
  auto total_size = unknown_size_flag_ ? max_size_ : get_size();
  if (total_size < offset) {
    size = 0;
  } else {
    size = min(size, total_size - offset);
  }
  return Part{part_id, offset, static_cast<size_t>(size)};
}

Part PartsManager::get_empty_part() {
  return Part{-1, 0, 0};
}

void PartsManager::on_part_start(int32 part_id) {
  CHECK(part_status_[part_id] == PartStatus::Empty);
  part_status_[part_id] = PartStatus::Pending;
  pending_count_++;
}

StringBuilder &operator<<(StringBuilder &string_builder, const PartsManager &parts_manager) {
  return string_builder << "PartsManager[" << (parts_manager.is_upload_ ? "up" : "down")
                        << "load, need_check = " << parts_manager.need_check_
                        << ", checked_prefix_size = " << parts_manager.checked_prefix_size_
                        << ", known_prefix = " << parts_manager.known_prefix_flag_
                        << ", known_prefix_size = " << parts_manager.known_prefix_size_
                        << ", size = " << parts_manager.size_ << ", expected_size = " << parts_manager.expected_size_
                        << ", min_size = " << parts_manager.min_size_ << ", max_size = " << parts_manager.max_size_
                        << ", unknown_size = " << parts_manager.unknown_size_flag_
                        << ", ready_size = " << parts_manager.ready_size_
                        << ", streaming_ready_size = " << parts_manager.streaming_ready_size_
                        << ", part_size = " << parts_manager.part_size_
                        << ", part_count = " << parts_manager.part_count_
                        << ", pending_count = " << parts_manager.pending_count_
                        << ", first_empty_part = " << parts_manager.first_empty_part_
                        << ", first_not_ready_part = " << parts_manager.first_not_ready_part_
                        << ", streaming_offset = " << parts_manager.streaming_offset_
                        << ", streaming_limit = " << parts_manager.streaming_limit_
                        << ", first_streaming_empty_part = " << parts_manager.first_streaming_empty_part_
                        << ", first_streaming_not_ready_part = " << parts_manager.first_streaming_not_ready_part_
                        << ", use_part_count_limit = " << parts_manager.use_part_count_limit_
                        << ", part_status_count = " << parts_manager.part_status_.size() << ": "
                        << parts_manager.bitmask_ << ']';
}

}  // namespace td
