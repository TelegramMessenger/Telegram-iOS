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

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Status.h"

#include <limits>
#include <memory>

namespace td {

FileFd &Stdin();
FileFd &Stdout();
FileFd &Stderr();

namespace detail {
class BufferedStdinImpl;
class BufferedStdinImplDeleter {
 public:
  void operator()(BufferedStdinImpl *impl);
};
}  // namespace detail

class BufferedStdin {
 public:
  BufferedStdin();
  BufferedStdin(const BufferedStdin &) = delete;
  BufferedStdin &operator=(const BufferedStdin &) = delete;
  BufferedStdin(BufferedStdin &&);
  BufferedStdin &operator=(BufferedStdin &&);
  ~BufferedStdin();
  ChainBufferReader &input_buffer();
  PollableFdInfo &get_poll_info();
  const PollableFdInfo &get_poll_info() const;
  Result<size_t> flush_read(size_t max_read = std::numeric_limits<size_t>::max()) TD_WARN_UNUSED_RESULT;

 private:
  std::unique_ptr<detail::BufferedStdinImpl, detail::BufferedStdinImplDeleter> impl_;
};

}  // namespace td
