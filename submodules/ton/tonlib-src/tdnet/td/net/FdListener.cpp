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
#include "td/net/FdListener.h"

namespace td {
void FdListener::start_up() {
  fd_.add_flags(PollFlags::ReadWrite());
  td::actor::SchedulerContext::get()->get_poll().subscribe(std::move(fd_), PollFlags::ReadWrite());
}

void FdListener::tear_down() {
  td::actor::SchedulerContext::get()->get_poll().unsubscribe(fd_ref_);
}
}  // namespace td
