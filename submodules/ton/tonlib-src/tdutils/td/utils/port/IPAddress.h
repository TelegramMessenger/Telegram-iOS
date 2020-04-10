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

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#if !TD_WINDOWS
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#endif

namespace td {

Result<string> idn_to_ascii(CSlice host);

class SocketFd;

class IPAddress {
 public:
  IPAddress();

  bool is_valid() const;
  bool is_ipv4() const;
  bool is_ipv6() const;

  bool is_reserved() const;

  int get_port() const;
  void set_port(int port);

  uint32 get_ipv4() const;
  Slice get_ipv6() const;
  Slice get_ip_str() const;

  IPAddress get_any_addr() const;

  static Result<IPAddress> get_ipv4_address(CSlice host);
  static Result<IPAddress> get_ipv6_address(CSlice host);

  Status init_ipv6_port(CSlice ipv6, int port) TD_WARN_UNUSED_RESULT;
  Status init_ipv6_as_ipv4_port(CSlice ipv4, int port) TD_WARN_UNUSED_RESULT;
  Status init_ipv4_port(CSlice ipv4, int port) TD_WARN_UNUSED_RESULT;
  Status init_host_port(CSlice host, int port, bool prefer_ipv6 = false) TD_WARN_UNUSED_RESULT;
  Status init_host_port(CSlice host, CSlice port, bool prefer_ipv6 = false) TD_WARN_UNUSED_RESULT;
  Status init_host_port(CSlice host_port) TD_WARN_UNUSED_RESULT;
  Status init_socket_address(const SocketFd &socket_fd) TD_WARN_UNUSED_RESULT;
  Status init_peer_address(const SocketFd &socket_fd) TD_WARN_UNUSED_RESULT;

  friend bool operator==(const IPAddress &a, const IPAddress &b);
  friend bool operator<(const IPAddress &a, const IPAddress &b);

  // for internal usage only
  const sockaddr *get_sockaddr() const;
  size_t get_sockaddr_len() const;
  int get_address_family() const;
  static CSlice ipv4_to_str(uint32 ipv4);
  static CSlice ipv6_to_str(Slice ipv6);
  Status init_sockaddr(sockaddr *addr);
  Status init_sockaddr(sockaddr *addr, socklen_t len) TD_WARN_UNUSED_RESULT;

 private:
  union {
    sockaddr sockaddr_;
    sockaddr_in ipv4_addr_;
    sockaddr_in6 ipv6_addr_;
  };
  static constexpr socklen_t storage_size() {
    return sizeof(ipv6_addr_);
  }
  bool is_valid_;

  void init_ipv4_any();
  void init_ipv6_any();
};

StringBuilder &operator<<(StringBuilder &builder, const IPAddress &address);

}  // namespace td
