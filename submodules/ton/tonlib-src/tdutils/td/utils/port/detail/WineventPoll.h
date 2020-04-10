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

#include "td/utils/port/config.h"

#ifdef TD_POLL_WINEVENT

#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/PollBase.h"
#include "td/utils/port/PollFlags.h"

namespace td {
namespace detail {

class WineventPoll final : public PollBase {
 public:
  WineventPoll() = default;
  WineventPoll(const WineventPoll &) = delete;
  WineventPoll &operator=(const WineventPoll &) = delete;
  WineventPoll(WineventPoll &&) = delete;
  WineventPoll &operator=(WineventPoll &&) = delete;
  ~WineventPoll() override = default;

  void init() override;

  void clear() override;

  void subscribe(PollableFd fd, PollFlags flags) override;

  void unsubscribe(PollableFdRef fd) override;

  void unsubscribe_before_close(PollableFdRef fd) override;

  void run(int timeout_ms) override;

  static bool is_edge_triggered() {
    return true;
  }
};

}  // namespace detail
}  // namespace td

#endif
