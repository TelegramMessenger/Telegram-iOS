//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/ResourceState.h"

#include "td/utils/format.h"

namespace td {

void ResourceState::start_use(int64 x) {
  using_ += x;
  CHECK(used_ + using_ <= limit_);
}

void ResourceState::stop_use(int64 x) {
  CHECK(x <= using_);
  using_ -= x;
  used_ += x;
}

void ResourceState::update_limit(int64 extra) {
  limit_ += extra;
}

bool ResourceState::update_estimated_limit(int64 extra) {
  // unused() must be positive, i.e. used_ + using_ must be less than limit_
  // TODO: use exact intersection between using_ and extra.
  auto using_and_extra_intersection = min(using_, extra);  // between 0 and min(using_, extra)
  auto new_estimated_limit = used_ + using_ + extra - using_and_extra_intersection;

  // Use extra extra limit
  if (new_estimated_limit < limit_) {
    auto extra_limit = limit_ - new_estimated_limit;
    used_ += extra_limit;
    new_estimated_limit += extra_limit;
  }

  if (new_estimated_limit == estimated_limit_) {
    return false;
  }
  estimated_limit_ = new_estimated_limit;
  return true;
}

int64 ResourceState::active_limit() const {
  return limit_ - used_;
}

int64 ResourceState::unused() const {
  return limit_ - using_ - used_;
}

int64 ResourceState::estimated_extra() const {
  auto new_unused = max(limit_, estimated_limit_) - using_ - used_;
  new_unused = static_cast<int64>((new_unused + unit_size() - 1) / unit_size() * unit_size());
  return new_unused + using_ + used_ - limit_;
}

ResourceState &ResourceState::operator+=(const ResourceState &other) {
  using_ += other.active_limit();
  used_ += other.used_;
  return *this;
}

ResourceState &ResourceState::operator-=(const ResourceState &other) {
  using_ -= other.active_limit();
  used_ -= other.used_;
  return *this;
}

void ResourceState::update_master(const ResourceState &other) {
  estimated_limit_ = other.estimated_limit_;
  used_ = other.used_;
  using_ = other.using_;
  unit_size_ = other.unit_size_;
}

void ResourceState::update_slave(const ResourceState &other) {
  limit_ = other.limit_;
}

StringBuilder &operator<<(StringBuilder &sb, const ResourceState &state) {
  return sb << tag("estimated_limit", state.estimated_limit_) << tag("used", state.used_) << tag("using", state.using_)
            << tag("limit", state.limit_);
}

}  // namespace td
