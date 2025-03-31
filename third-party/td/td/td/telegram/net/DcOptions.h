//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/DcId.h"
#include "td/telegram/telegram_api.h"

#include "td/mtproto/ProxySecret.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class DcOption {
  // do not forget to update PrintFlags
  enum Flags : int32 { IPv6 = 1, MediaOnly = 2, ObfuscatedTcpOnly = 4, Cdn = 8, Static = 16, HasSecret = 32 };

  int32 flags_ = 0;
  DcId dc_id_;
  IPAddress ip_address_;
  mtproto::ProxySecret secret_;

  struct PrintFlags {
    int32 flags;
  };

 public:
  DcOption() = default;

  DcOption(DcId dc_id, const IPAddress &ip_address)
      : flags_(ip_address.is_ipv4() ? 0 : IPv6), dc_id_(dc_id), ip_address_(ip_address) {
  }

  explicit DcOption(const telegram_api::dcOption &option) {
    auto ip = option.ip_address_;
    auto port = option.port_;
    flags_ = 0;
    if (!DcId::is_valid(option.id_)) {
      dc_id_ = DcId::invalid();
      return;
    }

    if (option.cdn_) {
      dc_id_ = DcId::external(option.id_);
      flags_ |= Flags::Cdn;
    } else {
      dc_id_ = DcId::internal(option.id_);
    }
    if (option.ipv6_) {
      flags_ |= Flags::IPv6;
    }
    if (option.media_only_) {
      flags_ |= Flags::MediaOnly;
    }
    if (option.tcpo_only_) {
      flags_ |= Flags::ObfuscatedTcpOnly;
    }
    if (option.static_) {
      flags_ |= Flags::Static;
    }
    if (!option.secret_.empty()) {
      flags_ |= Flags::HasSecret;
      auto r_secret = mtproto::ProxySecret::from_binary(option.secret_.as_slice());
      if (r_secret.is_error()) {
        return;
      }
      secret_ = r_secret.move_as_ok();
    }
    init_ip_address(ip, port);
  }

  DcOption(DcId new_dc_id, const telegram_api::IpPort &ip_port_ref) {
    switch (ip_port_ref.get_id()) {
      case telegram_api::ipPort::ID: {
        auto &ip_port = static_cast<const telegram_api::ipPort &>(ip_port_ref);
        init_ip_address(IPAddress::ipv4_to_str(static_cast<uint32>(ip_port.ipv4_)), ip_port.port_);
        break;
      }
      case telegram_api::ipPortSecret::ID: {
        auto &ip_port = static_cast<const telegram_api::ipPortSecret &>(ip_port_ref);
        auto r_secret = mtproto::ProxySecret::from_binary(ip_port.secret_.as_slice());
        if (r_secret.is_error()) {
          return;
        }
        flags_ |= Flags::HasSecret;
        secret_ = r_secret.move_as_ok();
        init_ip_address(IPAddress::ipv4_to_str(static_cast<uint32>(ip_port.ipv4_)), ip_port.port_);
        break;
      }
      default:
        UNREACHABLE();
    }
    flags_ |= Flags::ObfuscatedTcpOnly;
    dc_id_ = new_dc_id;
  }

  DcId get_dc_id() const {
    return dc_id_;
  }

  const IPAddress &get_ip_address() const {
    return ip_address_;
  }

  bool is_ipv6() const {
    return (flags_ & Flags::IPv6) != 0;
  }

  bool is_media_only() const {
    return (flags_ & Flags::MediaOnly) != 0;
  }

  bool is_obfuscated_tcp_only() const {
    return (flags_ & Flags::ObfuscatedTcpOnly) != 0;
  }

  bool is_static() const {
    return (flags_ & Flags::Static) != 0;
  }

  bool is_valid() const {
    return ip_address_.is_valid() && dc_id_.is_exact();
  }

  const mtproto::ProxySecret &get_secret() const {
    return secret_;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_int(flags_);
    storer.store_int(dc_id_.get_raw_id());
    CHECK(ip_address_.is_valid());
    storer.store_string(ip_address_.get_ip_str());
    storer.store_int(ip_address_.get_port());
    if ((flags_ & Flags::HasSecret) != 0) {
      td::store(secret_.get_raw_secret(), storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    flags_ = parser.fetch_int();
    auto raw_dc_id = parser.fetch_int();
    if (!DcId::is_valid(raw_dc_id)) {
      LOG(ERROR) << "Have invalid DC ID " << raw_dc_id;
      dc_id_ = DcId::invalid();
    } else {
      if ((flags_ & Flags::Cdn) != 0) {
        dc_id_ = DcId::external(raw_dc_id);
      } else {
        dc_id_ = DcId::internal(raw_dc_id);
      }
    }
    auto ip = parser.template fetch_string<std::string>();
    auto port = parser.fetch_int();
    init_ip_address(ip, port);
    if ((flags_ & Flags::HasSecret) != 0) {
      secret_ = mtproto::ProxySecret::from_raw(parser.template fetch_string<Slice>());
    }
  }

  friend bool operator==(const DcOption &lhs, const DcOption &rhs);

  friend StringBuilder &operator<<(StringBuilder &sb, const PrintFlags &flags);

  friend StringBuilder &operator<<(StringBuilder &sb, const DcOption &dc_option);

 private:
  void init_ip_address(CSlice ip, int32 port) {
    if (is_ipv6()) {
      ip_address_.init_ipv6_port(ip, port).ignore();
    } else {
      ip_address_.init_ipv4_port(ip, port).ignore();
    }
  }
};

inline bool operator==(const DcOption &lhs, const DcOption &rhs) {
  return lhs.dc_id_ == rhs.dc_id_ && lhs.ip_address_ == rhs.ip_address_ && lhs.flags_ == rhs.flags_ &&
         lhs.secret_ == rhs.secret_;
}

inline StringBuilder &operator<<(StringBuilder &sb, const DcOption::PrintFlags &flags) {
  if ((flags.flags & DcOption::Flags::ObfuscatedTcpOnly) != 0) {
    sb << "(ObfuscatedTcpOnly)";
  }
  if ((flags.flags & DcOption::Flags::MediaOnly) != 0) {
    sb << "(MediaOnly)";
  }
  if ((flags.flags & DcOption::Flags::IPv6) != 0) {
    sb << "(IPv6)";
  }
  if ((flags.flags & DcOption::Flags::Cdn) != 0) {
    sb << "(Cdn)";
  }
  if ((flags.flags & DcOption::Flags::Static) != 0) {
    sb << "(Static)";
  }
  if ((flags.flags & DcOption::Flags::HasSecret) != 0) {
    sb << "(HasSecret)";
  }
  return sb;
}

inline StringBuilder &operator<<(StringBuilder &sb, const DcOption &dc_option) {
  return sb << tag("DcOption", format::concat(dc_option.dc_id_, tag("ip", dc_option.ip_address_.get_ip_str()),
                                              tag("port", dc_option.ip_address_.get_port()),
                                              tag("secret_len", dc_option.get_secret().get_raw_secret().size()),
                                              tag("flags", DcOption::PrintFlags{dc_option.flags_})));
}

class DcOptions {
 public:
  DcOptions() = default;
  explicit DcOptions(const std::vector<tl_object_ptr<telegram_api::dcOption>> &server_dc_options) {
    for (auto &dc_option : server_dc_options) {
      DcOption option(*dc_option);
      if (option.is_valid()) {
        dc_options.push_back(std::move(option));
      }
    }
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    ::td::store(dc_options, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    ::td::parse(dc_options, parser);
  }

  std::vector<DcOption> dc_options;
};

inline StringBuilder &operator<<(StringBuilder &sb, const DcOptions &dc_options) {
  return sb << "DcOptions" << dc_options.dc_options;
}

}  // namespace td
