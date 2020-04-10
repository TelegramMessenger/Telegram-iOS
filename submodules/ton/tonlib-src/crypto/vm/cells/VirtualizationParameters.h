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

#include "td/utils/int_types.h"
#include "td/utils/logging.h"

#include <limits>

namespace vm {
namespace detail {
class VirtualizationParameters {
 public:
  static constexpr td::uint8 max_level() {
    return std::numeric_limits<td::uint8>::max();
  }

  VirtualizationParameters() = default;

  VirtualizationParameters(td::uint8 level, td::uint8 virtualization) : level_(level), virtualization_(virtualization) {
    CHECK(virtualization_ != 0 || empty());
  }

  bool empty() const {
    return level_ == max_level() && virtualization_ == 0;
  }

  VirtualizationParameters apply(VirtualizationParameters outer) const {
    if (outer.level_ >= level_) {
      return *this;
    }
    CHECK(virtualization_ <= outer.virtualization_);
    return {outer.level_, outer.virtualization_};
  }

  td::uint8 get_level() const {
    return level_;
  }

  td::uint8 get_virtualization() const {
    return virtualization_;
  }

  bool operator==(const VirtualizationParameters &other) const {
    return level_ == other.level_ && virtualization_ == other.virtualization_;
  }

 private:
  td::uint8 level_ = max_level();
  td::uint8 virtualization_ = 0;
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const VirtualizationParameters &virt) {
  return sb << "{level: " << virt.get_level() << ", virtualization: " << virt.get_virtualization() << "}";
}
}  // namespace detail
}  // namespace vm
