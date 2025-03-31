//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/BufferedUdp.h"

char disable_linker_warning_about_empty_file_buffered_udp_cpp TD_UNUSED;

namespace td {

#if TD_PORT_POSIX
TD_THREAD_LOCAL detail::UdpReader *BufferedUdp::udp_reader_;
#endif

}  // namespace td
