//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#define _WINSOCK_DEPRECATED_NO_WARNINGS  // we need to use inet_addr instead of inet_pton

#include "td/utils/port/IPAddress.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/utf8.h"

#if TD_WINDOWS
#include "td/utils/port/wstring_convert.h"
#else
#include <netdb.h>
#include <netinet/tcp.h>
#include <sys/types.h>
#endif

#include <cstring>
#include <limits>

namespace td {

static bool is_ascii_host_char(char c) {
  return static_cast<unsigned char>(c) <= 127;
}

static bool is_ascii_host(Slice host) {
  for (auto c : host) {
    if (!is_ascii_host_char(c)) {
      return false;
    }
  }
  return true;
}

#if !TD_WINDOWS
static void punycode(string &result, Slice part) {
  vector<uint32> codes;
  codes.reserve(utf8_length(part));
  uint32 processed = 0;
  auto begin = part.ubegin();
  auto end = part.uend();
  while (begin != end) {
    uint32 code;
    begin = next_utf8_unsafe(begin, &code);
    if (code <= 127u) {
      result += to_lower(static_cast<char>(code));
      processed++;
    }
    codes.push_back(code);
  }

  if (processed > 0) {
    result += '-';
  }

  uint32 n = 127;
  uint32 delta = 0;
  int bias = -72;
  bool is_first = true;
  while (processed < codes.size()) {
    // choose lowest not processed code
    uint32 next_n = 0x110000;
    for (auto code : codes) {
      if (code > n && code < next_n) {
        next_n = code;
      }
    }
    delta += (next_n - n - 1) * (processed + 1);

    for (auto code : codes) {
      if (code < next_n) {
        delta++;
      }

      if (code == next_n) {
        // found next symbol, encode delta
        auto left = static_cast<int>(delta);
        while (true) {
          bias += 36;
          auto t = clamp(bias, 1, 26);
          if (left < t) {
            result += static_cast<char>(left + 'a');
            break;
          }

          left -= t;
          auto digit = t + left % (36 - t);
          result += static_cast<char>(digit < 26 ? digit + 'a' : digit - 26 + '0');
          left /= 36 - t;
        }
        processed++;

        // update bias
        if (is_first) {
          delta /= 700;
          is_first = false;
        } else {
          delta /= 2;
        }
        delta += delta / processed;

        bias = 0;
        while (delta > 35 * 13) {
          delta /= 35;
          bias -= 36;
        }
        bias -= static_cast<int>(36 * delta / (delta + 38));
        delta = 0;
      }
    }

    delta++;
    n = next_n;
  }
}
#endif

Result<string> idn_to_ascii(CSlice host) {
  if (is_ascii_host(host)) {
    return to_lower(host);
  }
  if (!check_utf8(host)) {
    return Status::Error("Host name must be encoded in UTF-8");
  }

  const int MAX_DNS_NAME_LENGTH = 255;
  if (host.size() >= MAX_DNS_NAME_LENGTH * 4) {  // upper bound, 4 characters per symbol
    return Status::Error("Host name is too long");
  }

#if TD_WINDOWS
  TRY_RESULT(whost, to_wstring(host));
  wchar_t punycode[MAX_DNS_NAME_LENGTH + 1];
  int result_length =
      IdnToAscii(IDN_ALLOW_UNASSIGNED, whost.c_str(), narrow_cast<int>(whost.size()), punycode, MAX_DNS_NAME_LENGTH);
  if (result_length == 0) {
    return Status::Error("Host can't be converted to ASCII");
  }

  TRY_RESULT(idn_host, from_wstring(punycode, result_length));
  return idn_host;
#else
  auto parts = full_split(Slice(host), '.');
  bool is_first = true;
  string result;
  result.reserve(host.size());
  for (auto part : parts) {
    if (!is_first) {
      result += '.';
    }
    if (is_ascii_host(part)) {
      result.append(part.data(), part.size());
    } else {
      // TODO nameprep should be applied first, but punycode is better than nothing.
      // It is better to use libidn/ICU here if available
      result += "xn--";
      punycode(result, part);
    }
    is_first = false;
  }
  return result;
#endif
}

static CSlice get_ip_str(int family, const void *addr) {
  const int buf_size = INET6_ADDRSTRLEN;
  static TD_THREAD_LOCAL char *buf;
  init_thread_local<char[]>(buf, buf_size);

  const char *res = inet_ntop(family,
#if TD_WINDOWS
                              const_cast<PVOID>(addr),
#else
                              addr,
#endif
                              buf, buf_size);
  if (res == nullptr) {
    return CSlice();
  } else {
    return CSlice(res);
  }
}

IPAddress::IPAddress() : is_valid_(false) {
}

bool IPAddress::is_valid() const {
  return is_valid_;
}

bool IPAddress::is_reserved() const {
  CHECK(is_valid());

  if (is_ipv6()) {
    // TODO proper check for reserved IPv6 addresses
    return true;
  }

  uint32 ip = get_ipv4();
  struct IpBlock {
    CSlice ip;
    int mask;
    IpBlock(CSlice ip, int mask) : ip(ip), mask(mask) {
    }
  };
  static const IpBlock blocks[] = {{"0.0.0.0", 8},      {"10.0.0.0", 8},     {"100.64.0.0", 10}, {"127.0.0.0", 8},
                                   {"169.254.0.0", 16}, {"172.16.0.0", 12},  {"192.0.0.0", 24},  {"192.0.2.0", 24},
                                   {"192.88.99.0", 24}, {"192.168.0.0", 16}, {"198.18.0.0", 15}, {"198.51.100.0", 24},
                                   {"203.0.113.0", 24}, {"224.0.0.0", 3}};
  for (auto &block : blocks) {
    IPAddress block_ip_address;
    block_ip_address.init_ipv4_port(block.ip, 80).ensure();
    uint32 range = block_ip_address.get_ipv4();
    CHECK(block.mask != 0);
    uint32 mask = std::numeric_limits<uint32>::max() >> (32 - block.mask) << (32 - block.mask);
    if ((ip & mask) == (range & mask)) {
      return true;
    }
  }
  return false;
}

const sockaddr *IPAddress::get_sockaddr() const {
  CHECK(is_valid());
  return &sockaddr_;
}

size_t IPAddress::get_sockaddr_len() const {
  CHECK(is_valid());
  switch (sockaddr_.sa_family) {
    case AF_INET6:
      return sizeof(ipv6_addr_);
    case AF_INET:
      return sizeof(ipv4_addr_);
    default:
      UNREACHABLE();
      return 0;
  }
}

int IPAddress::get_address_family() const {
  return get_sockaddr()->sa_family;
}

bool IPAddress::is_ipv4() const {
  return is_valid() && get_address_family() == AF_INET;
}

bool IPAddress::is_ipv6() const {
  return is_valid() && get_address_family() == AF_INET6;
}

uint32 IPAddress::get_ipv4() const {
  CHECK(is_valid());
  CHECK(is_ipv4());
  return htonl(ipv4_addr_.sin_addr.s_addr);
}

string IPAddress::get_ipv6() const {
  static_assert(sizeof(ipv6_addr_.sin6_addr) == 16, "ipv6 size == 16");
  CHECK(is_valid());
  CHECK(!is_ipv4());
  return Slice(ipv6_addr_.sin6_addr.s6_addr, 16).str();
}

IPAddress IPAddress::get_any_addr() const {
  IPAddress res;
  switch (get_address_family()) {
    case AF_INET6:
      res.init_ipv6_any();
      break;
    case AF_INET:
      res.init_ipv4_any();
      break;
    default:
      UNREACHABLE();
      break;
  }
  return res;
}

void IPAddress::init_ipv4_any() {
  is_valid_ = true;
  std::memset(&ipv4_addr_, 0, sizeof(ipv4_addr_));
  ipv4_addr_.sin_family = AF_INET;
  ipv4_addr_.sin_addr.s_addr = INADDR_ANY;
  ipv4_addr_.sin_port = 0;
}

void IPAddress::init_ipv6_any() {
  is_valid_ = true;
  std::memset(&ipv6_addr_, 0, sizeof(ipv6_addr_));
  ipv6_addr_.sin6_family = AF_INET6;
  ipv6_addr_.sin6_addr = in6addr_any;
  ipv6_addr_.sin6_port = 0;
}

Status IPAddress::init_ipv6_port(CSlice ipv6, int port) {
  is_valid_ = false;
  if (port <= 0 || port >= (1 << 16)) {
    return Status::Error(PSLICE() << "Invalid [IPv6 address port=" << port << "]");
  }
  string ipv6_plain;
  if (ipv6.size() > 2 && ipv6[0] == '[' && ipv6.back() == ']') {
    ipv6_plain.assign(ipv6.begin() + 1, ipv6.size() - 2);
    ipv6 = ipv6_plain;
  }
  std::memset(&ipv6_addr_, 0, sizeof(ipv6_addr_));
  ipv6_addr_.sin6_family = AF_INET6;
  ipv6_addr_.sin6_port = htons(static_cast<uint16>(port));
  int err = inet_pton(AF_INET6, ipv6.c_str(), &ipv6_addr_.sin6_addr);
  if (err == 0) {
    return Status::Error(PSLICE() << "Failed inet_pton(AF_INET6, " << ipv6 << ")");
  } else if (err == -1) {
    return OS_SOCKET_ERROR(PSLICE() << "Failed inet_pton(AF_INET6, " << ipv6 << ")");
  }
  is_valid_ = true;
  return Status::OK();
}

Status IPAddress::init_ipv6_as_ipv4_port(CSlice ipv4, int port) {
  return init_ipv6_port(string("::FFFF:").append(ipv4.begin(), ipv4.size()), port);
}

Status IPAddress::init_ipv4_port(CSlice ipv4, int port) {
  is_valid_ = false;
  if (port <= 0 || port >= (1 << 16)) {
    return Status::Error(PSLICE() << "Invalid [IPv4 address port=" << port << "]");
  }
  std::memset(&ipv4_addr_, 0, sizeof(ipv4_addr_));
  ipv4_addr_.sin_family = AF_INET;
  ipv4_addr_.sin_port = htons(static_cast<uint16>(port));
  int err = inet_pton(AF_INET, ipv4.c_str(), &ipv4_addr_.sin_addr);
  if (err == 0) {
    return Status::Error(PSLICE() << "Failed inet_pton(AF_INET, " << ipv4 << ")");
  } else if (err == -1) {
    return OS_SOCKET_ERROR(PSLICE() << "Failed inet_pton(AF_INET, " << ipv4 << ")");
  }
  is_valid_ = true;
  return Status::OK();
}

Result<IPAddress> IPAddress::get_ip_address(CSlice host) {
  auto r_address = get_ipv4_address(host);
  if (r_address.is_ok()) {
    return r_address.move_as_ok();
  }
  r_address = get_ipv6_address(host);
  if (r_address.is_ok()) {
    return r_address.move_as_ok();
  }
  return Status::Error(PSLICE() << '"' << host << "\" is not a valid IP address");
}

Result<IPAddress> IPAddress::get_ipv4_address(CSlice host) {
  // sometimes inet_addr allows much more valid IPv4 hosts than inet_pton,
  // like 0x12.0x34.0x56.0x78, or 0x12345678, or 0x7f.001
  auto ipv4_numeric_addr = inet_addr(host.c_str());
  if (ipv4_numeric_addr == INADDR_NONE) {
    return Status::Error(PSLICE() << '"' << host << "\" is not a valid IPv4 address");
  }

  host = ::td::get_ip_str(AF_INET, &ipv4_numeric_addr);
  IPAddress result;
  auto status = result.init_ipv4_port(host, 1);
  if (status.is_error()) {
    return std::move(status);
  }
  return std::move(result);
}

Result<IPAddress> IPAddress::get_ipv6_address(CSlice host) {
  IPAddress result;
  auto status = result.init_ipv6_port(host, 1);
  if (status.is_error()) {
    return Status::Error(PSLICE() << '"' << host << "\" is not a valid IPv6 address");
  }
  return std::move(result);
}

Status IPAddress::init_host_port(CSlice host, int port, bool prefer_ipv6) {
  if (host.size() > 2 && host[0] == '[' && host.back() == ']') {
    return init_ipv6_port(host, port == 0 ? 1 : port);
  }

  return init_host_port(host, PSLICE() << port, prefer_ipv6);
}

Status IPAddress::init_host_port(CSlice host, CSlice port, bool prefer_ipv6) {
  is_valid_ = false;
  if (host.empty()) {
    return Status::Error("Host is empty");
  }
#if TD_WINDOWS
  if (host == "..localmachine") {
    return Status::Error("Host is invalid");
  }
#endif
  TRY_RESULT(ascii_host, idn_to_ascii(host));
  host = ascii_host;  // assign string to CSlice

  if (host[0] == '[' && host.back() == ']') {
    auto port_int = to_integer<int>(port);
    return init_ipv6_port(host, port_int == 0 ? 1 : port_int);
  }

  // some getaddrinfo implementations use inet_pton instead of inet_aton and support only decimal-dotted IPv4 form,
  // and so doesn't recognize 0x12.0x34.0x56.0x78, or 0x12345678, or 0x7f.001 as valid IPv4 addresses
  auto ipv4_numeric_addr = inet_addr(host.c_str());
  if (ipv4_numeric_addr != INADDR_NONE) {
    host = ::td::get_ip_str(AF_INET, &ipv4_numeric_addr);
  }

  addrinfo hints;
  addrinfo *info = nullptr;
  std::memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;
  LOG(DEBUG + 10) << "Trying to init IP address of " << host << " with port " << port;
  auto err = getaddrinfo(host.c_str(), port.c_str(), &hints, &info);
  if (err != 0) {
#if TD_WINDOWS
    return OS_SOCKET_ERROR("Failed to resolve host");
#else
    return Status::Error(PSLICE() << "Failed to resolve host: " << gai_strerror(err));
#endif
  }
  SCOPE_EXIT {
    freeaddrinfo(info);
  };

  addrinfo *best_info = nullptr;
  for (auto *ptr = info; ptr != nullptr; ptr = ptr->ai_next) {
    if (ptr->ai_family == AF_INET && (!prefer_ipv6 || best_info == nullptr)) {
      // just use first IPv4 address if there is no IPv6 and it isn't preferred
      best_info = ptr;
      if (!prefer_ipv6) {
        break;
      }
    }
    if (ptr->ai_family == AF_INET6 && (prefer_ipv6 || best_info == nullptr)) {
      // or first IPv6 address if there is no IPv4 and it isn't preferred
      best_info = ptr;
      if (prefer_ipv6) {
        break;
      }
    }
  }
  if (best_info == nullptr) {
    return Status::Error("Failed to find IPv4/IPv6 address");
  }
  return init_sockaddr(best_info->ai_addr, narrow_cast<socklen_t>(best_info->ai_addrlen));
}

Status IPAddress::init_host_port(CSlice host_port) {
  auto pos = host_port.rfind(':');
  if (pos == static_cast<size_t>(-1)) {
    return Status::Error("Can't split string into host and port");
  }
  return init_host_port(host_port.substr(0, pos).str(), host_port.substr(pos + 1).str());
}

Status IPAddress::init_sockaddr(sockaddr *addr) {
  if (addr->sa_family == AF_INET6) {
    return init_sockaddr(addr, sizeof(ipv6_addr_));
  } else if (addr->sa_family == AF_INET) {
    return init_sockaddr(addr, sizeof(ipv4_addr_));
  } else {
    return init_sockaddr(addr, 0);
  }
}
Status IPAddress::init_sockaddr(sockaddr *addr, socklen_t len) {
  if (addr->sa_family == AF_INET6) {
    CHECK(len == sizeof(ipv6_addr_));
    std::memcpy(&ipv6_addr_, reinterpret_cast<sockaddr_in6 *>(addr), sizeof(ipv6_addr_));
  } else if (addr->sa_family == AF_INET) {
    CHECK(len == sizeof(ipv4_addr_));
    std::memcpy(&ipv4_addr_, reinterpret_cast<sockaddr_in *>(addr), sizeof(ipv4_addr_));
  } else {
    return Status::Error(PSLICE() << "Unknown " << tag("sa_family", addr->sa_family));
  }

  is_valid_ = true;
  LOG(DEBUG + 10) << "Have address " << get_ip_str() << " with port " << get_port();
  return Status::OK();
}

Status IPAddress::init_socket_address(const SocketFd &socket_fd) {
  is_valid_ = false;
  if (socket_fd.empty()) {
    return Status::Error("Socket is empty");
  }
  auto socket = socket_fd.get_native_fd().socket();
  socklen_t len = storage_size();
  int ret = getsockname(socket, &sockaddr_, &len);
  if (ret != 0) {
    return OS_SOCKET_ERROR("Failed to get socket address");
  }
  is_valid_ = true;
  return Status::OK();
}

Status IPAddress::init_peer_address(const SocketFd &socket_fd) {
  is_valid_ = false;
  if (socket_fd.empty()) {
    return Status::Error("Socket is empty");
  }
  auto socket = socket_fd.get_native_fd().socket();
  socklen_t len = storage_size();
  int ret = getpeername(socket, &sockaddr_, &len);
  if (ret != 0) {
    return OS_SOCKET_ERROR("Failed to get peer socket address");
  }
  is_valid_ = true;
  return Status::OK();
}

void IPAddress::clear_ipv6_interface() {
  if (!is_valid() || get_address_family() != AF_INET6) {
    return;
  }

  auto *begin = ipv6_addr_.sin6_addr.s6_addr;
  static_assert(sizeof(ipv6_addr_.sin6_addr.s6_addr) == 16, "expected 16 bytes buffer for ipv6");
  static_assert(sizeof(*begin) == 1, "expected array of bytes");
  std::memset(begin + 8, 0, 8 * sizeof(*begin));
}

string IPAddress::ipv4_to_str(uint32 ipv4) {
  ipv4 = ntohl(ipv4);
  return ::td::get_ip_str(AF_INET, &ipv4).str();
}

string IPAddress::ipv6_to_str(Slice ipv6) {
  CHECK(ipv6.size() == 16);
  return ::td::get_ip_str(AF_INET6, ipv6.ubegin()).str();
}

CSlice IPAddress::get_ip_str() const {
  if (!is_valid()) {
    return CSlice("0.0.0.0");
  }

  switch (get_address_family()) {
    case AF_INET6:
      return ::td::get_ip_str(AF_INET6, &ipv6_addr_.sin6_addr);
    case AF_INET:
      return ::td::get_ip_str(AF_INET, &ipv4_addr_.sin_addr);
    default:
      UNREACHABLE();
      return CSlice();
  }
}

string IPAddress::get_ip_host() const {
  if (!is_valid()) {
    return "0.0.0.0";
  }

  switch (get_address_family()) {
    case AF_INET6:
      return PSTRING() << '[' << ::td::get_ip_str(AF_INET6, &ipv6_addr_.sin6_addr) << ']';
    case AF_INET:
      return ::td::get_ip_str(AF_INET, &ipv4_addr_.sin_addr).str();
    default:
      UNREACHABLE();
      return string();
  }
}

int IPAddress::get_port() const {
  if (!is_valid()) {
    return 0;
  }

  switch (get_address_family()) {
    case AF_INET6:
      return ntohs(ipv6_addr_.sin6_port);
    case AF_INET:
      return ntohs(ipv4_addr_.sin_port);
    default:
      UNREACHABLE();
      return 0;
  }
}

void IPAddress::set_port(int port) {
  CHECK(is_valid());

  switch (get_address_family()) {
    case AF_INET6:
      ipv6_addr_.sin6_port = htons(static_cast<uint16>(port));
      break;
    case AF_INET:
      ipv4_addr_.sin_port = htons(static_cast<uint16>(port));
      break;
    default:
      UNREACHABLE();
  }
}

bool operator==(const IPAddress &a, const IPAddress &b) {
  if (!a.is_valid() || !b.is_valid()) {
    return !a.is_valid() && !b.is_valid();
  }
  if (a.get_address_family() != b.get_address_family()) {
    return false;
  }

  if (a.get_address_family() == AF_INET) {
    return a.ipv4_addr_.sin_port == b.ipv4_addr_.sin_port &&
           std::memcmp(&a.ipv4_addr_.sin_addr, &b.ipv4_addr_.sin_addr, sizeof(a.ipv4_addr_.sin_addr)) == 0;
  } else if (a.get_address_family() == AF_INET6) {
    return a.ipv6_addr_.sin6_port == b.ipv6_addr_.sin6_port &&
           std::memcmp(&a.ipv6_addr_.sin6_addr, &b.ipv6_addr_.sin6_addr, sizeof(a.ipv6_addr_.sin6_addr)) == 0;
  }

  UNREACHABLE();
  return false;
}

bool operator<(const IPAddress &a, const IPAddress &b) {
  if (!a.is_valid() || !b.is_valid()) {
    return !a.is_valid() && b.is_valid();
  }
  if (a.get_address_family() != b.get_address_family()) {
    return a.get_address_family() < b.get_address_family();
  }

  if (a.get_address_family() == AF_INET) {
    if (a.ipv4_addr_.sin_port != b.ipv4_addr_.sin_port) {
      return a.ipv4_addr_.sin_port < b.ipv4_addr_.sin_port;
    }
    return std::memcmp(&a.ipv4_addr_.sin_addr, &b.ipv4_addr_.sin_addr, sizeof(a.ipv4_addr_.sin_addr)) < 0;
  } else if (a.get_address_family() == AF_INET6) {
    if (a.ipv6_addr_.sin6_port != b.ipv6_addr_.sin6_port) {
      return a.ipv6_addr_.sin6_port < b.ipv6_addr_.sin6_port;
    }
    return std::memcmp(&a.ipv6_addr_.sin6_addr, &b.ipv6_addr_.sin6_addr, sizeof(a.ipv6_addr_.sin6_addr)) < 0;
  }

  UNREACHABLE();
  return false;
}

StringBuilder &operator<<(StringBuilder &string_builder, const IPAddress &address) {
  if (!address.is_valid()) {
    return string_builder << "[invalid]";
  }
  return string_builder << "[" << address.get_ip_host() << ":" << address.get_port() << "]";
}

}  // namespace td
