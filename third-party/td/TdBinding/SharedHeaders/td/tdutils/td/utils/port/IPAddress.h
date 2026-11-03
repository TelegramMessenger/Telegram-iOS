//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
  string get_ipv6() const;

  // returns result in a static thread-local buffer, which may be overwritten by any subsequent method call
  CSlice get_ip_str() const;

  // returns IP address as a host, i.e. IPv4 or [IPv6]
  string get_ip_host() const;

  static string ipv4_to_str(uint32 ipv4);
  static string ipv6_to_str(Slice ipv6);

  IPAddress get_any_addr() const;

  static Result<IPAddress> get_ip_address(CSlice host);  // host must be any IPv4 or IPv6
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

  void clear_ipv6_interface();

  friend bool operator==(const IPAddress &a, const IPAddress &b);
  friend bool operator<(const IPAddress &a, const IPAddress &b);

  // for internal usage only
  const sockaddr *get_sockaddr() const;
  size_t get_sockaddr_len() const;
  int get_address_family() const;
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

StringBuilder &operator<<(StringBuilder &string_builder, const IPAddress &address);

}  // namespace td
