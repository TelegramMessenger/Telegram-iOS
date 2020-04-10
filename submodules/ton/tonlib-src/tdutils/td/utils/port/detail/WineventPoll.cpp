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
#include "td/utils/port/detail/WineventPoll.h"

char disable_linker_warning_about_empty_file_wineventpoll_cpp TD_UNUSED;

#ifdef TD_POLL_WINEVENT

#include "td/utils/common.h"

namespace td {
namespace detail {

void WineventPoll::init() {
}

void WineventPoll::clear() {
}

void WineventPoll::subscribe(PollableFd fd, PollFlags flags) {
  fd.release_as_list_node();
}

void WineventPoll::unsubscribe(PollableFdRef fd) {
  auto pollable_fd = fd.lock();  // unlocked in destructor
}

void WineventPoll::unsubscribe_before_close(PollableFdRef fd) {
  unsubscribe(std::move(fd));
}

void WineventPoll::run(int timeout_ms) {
  UNREACHABLE();
}

}  // namespace detail
}  // namespace td

#endif
