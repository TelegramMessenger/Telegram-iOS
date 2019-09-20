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

#include "tonlib/Client.h"

#include "td/utils/Slice.h"

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>

namespace tonlib {

class ClientJson final {
 public:
  void send(td::Slice request);

  td::CSlice receive(double timeout);

  static td::CSlice execute(td::Slice request);

 private:
  Client client_;
  std::mutex mutex_;  // for extra_
  std::unordered_map<std::int64_t, std::string> extra_;
  std::atomic<std::uint64_t> extra_id_{1};
};

}  // namespace tonlib
