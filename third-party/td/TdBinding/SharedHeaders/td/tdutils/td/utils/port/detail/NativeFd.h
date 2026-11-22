//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

extern int VERBOSITY_NAME(fd);

class NativeFd {
 public:
#if TD_PORT_POSIX
  using Fd = int;
  using Socket = int;
#elif TD_PORT_WINDOWS
  using Fd = HANDLE;
  using Socket = SOCKET;
#endif
  NativeFd() = default;
  explicit NativeFd(Fd fd);
  NativeFd(Fd fd, bool nolog);
#if TD_PORT_WINDOWS
  explicit NativeFd(Socket socket);
#endif
  NativeFd(const NativeFd &) = delete;
  NativeFd &operator=(const NativeFd &) = delete;
  NativeFd(NativeFd &&other) noexcept;
  NativeFd &operator=(NativeFd &&other) noexcept;
  ~NativeFd();

  explicit operator bool() const noexcept;

  Fd fd() const;
  Socket socket() const;

  Status set_is_blocking(bool is_blocking) const;

  Status set_is_blocking_unsafe(bool is_blocking) const;  // may drop other Fd flags on non-Windows

  Status duplicate(const NativeFd &to) const;

  Result<uint32> maximize_snd_buffer(uint32 max_size = 0) const;
  Result<uint32> maximize_rcv_buffer(uint32 max_size = 0) const;

  void close();
  Fd release();

  Status validate() const;

 private:
  static Fd empty_fd();

  Fd fd_ = empty_fd();
#if TD_PORT_WINDOWS
  bool is_socket_{false};
#endif
  static constexpr uint32 DEFAULT_MAX_SND_BUFFER_SIZE = (1 << 24);
  static constexpr uint32 DEFAULT_MAX_RCV_BUFFER_SIZE = (1 << 24);
};

StringBuilder &operator<<(StringBuilder &sb, const NativeFd &fd);

}  // namespace td
