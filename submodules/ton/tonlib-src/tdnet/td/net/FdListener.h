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

#include "td/actor/actor.h"

#include "td/utils/Observer.h"
#include "td/utils/port/detail/PollableFd.h"

namespace td {
class FdListener : public td::actor::Actor {
 public:
  FdListener(td::PollableFd fd, std::unique_ptr<td::Destructor> guard)
      : fd_(std::move(fd)), fd_ref_(fd_.ref()), guard_(std::move(guard)) {
  }

 private:
  PollableFd fd_;
  PollableFdRef fd_ref_;
  std::unique_ptr<Destructor> guard_;

  void start_up() override;

  void tear_down() override;
};
}  // namespace td
