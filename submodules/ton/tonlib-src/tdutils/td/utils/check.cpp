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
#include "td/utils/check.h"

#include "td/utils/logging.h"
#include "td/utils/Slice.h"

namespace td {
namespace detail {

void process_check_error(const char *message, const char *file, int line) {
  ::td::Logger(*log_interface, log_options, VERBOSITY_NAME(FATAL), Slice(file), line, Slice())
      << "Check `" << message << "` failed";
  ::td::process_fatal_error(PSLICE() << "Check `" << message << "` failed in " << file << " at " << line);
}

}  // namespace detail
}  // namespace td
