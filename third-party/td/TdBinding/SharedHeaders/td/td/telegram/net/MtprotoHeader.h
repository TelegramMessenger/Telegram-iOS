//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/Proxy.h"

#include "td/utils/common.h"
#include "td/utils/port/RwMutex.h"

namespace td {

class MtprotoHeader {
 public:
  struct Options {
    int32 api_id = -1;
    string system_language_code;
    string device_model;
    string system_version;
    string application_version;
    string language_pack;
    string language_code;
    string parameters;
    int32 tz_offset = 0;
    bool is_emulator = false;
    Proxy proxy;
  };

  explicit MtprotoHeader(const Options &options) : options_(options) {
    default_header_ = gen_header(options_, false);
    anonymous_header_ = gen_header(options_, true);
  }

  void set_proxy(Proxy proxy) {
    auto lock = rw_mutex_.lock_write();
    options_.proxy = std::move(proxy);
    default_header_ = gen_header(options_, false);
  }

  bool set_parameters(string parameters) {
    auto lock = rw_mutex_.lock_write();
    if (options_.parameters == parameters) {
      return false;
    }

    options_.parameters = std::move(parameters);
    default_header_ = gen_header(options_, false);
    return true;
  }

  bool set_is_emulator(bool is_emulator) {
    auto lock = rw_mutex_.lock_write();
    if (options_.is_emulator == is_emulator) {
      return false;
    }

    options_.is_emulator = is_emulator;
    default_header_ = gen_header(options_, false);
    return true;
  }

  bool set_language_pack(string language_pack) {
    auto lock = rw_mutex_.lock_write();
    if (options_.language_pack == language_pack) {
      return false;
    }

    options_.language_pack = std::move(language_pack);
    default_header_ = gen_header(options_, false);
    return true;
  }

  bool set_language_code(string language_code) {
    auto lock = rw_mutex_.lock_write();
    if (options_.language_code == language_code) {
      return false;
    }

    options_.language_code = std::move(language_code);
    default_header_ = gen_header(options_, false);
    return true;
  }

  bool set_tz_offset(int32 tz_offset) {
    auto lock = rw_mutex_.lock_write();
    if (options_.tz_offset == tz_offset) {
      return false;
    }

    options_.tz_offset = tz_offset;
    default_header_ = gen_header(options_, false);
    return true;
  }

  string get_default_header() const {
    auto lock = rw_mutex_.lock_read();
    return default_header_;
  }

  string get_anonymous_header() const {
    auto lock = rw_mutex_.lock_read();
    return anonymous_header_;
  }

  string get_system_language_code() const {
    auto lock = rw_mutex_.lock_read();
    return options_.system_language_code;
  }

 private:
  Options options_;
  string default_header_;
  string anonymous_header_;
  mutable RwMutex rw_mutex_;

  static string gen_header(const Options &options, bool is_anonymous);
};

}  // namespace td
