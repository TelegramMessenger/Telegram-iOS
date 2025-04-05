//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <functional>

namespace td {

class OptionParser {
  class Option {
   public:
    enum class Type { NoArg, Arg };
    Type type;
    char short_key;
    string long_key;
    string description;
    std::function<Status(Slice)> arg_callback;
  };

  void add_option(Option::Type type, char short_key, Slice long_key, Slice description,
                  std::function<Status(Slice)> callback);

 public:
  template <class T>
  static std::function<Status(Slice)> parse_integer(T &value) {
    return [&value](Slice value_str) {
      TRY_RESULT_ASSIGN(value, to_integer_safe<T>(value_str));
      return Status::OK();
    };
  }

  static std::function<void(Slice)> parse_string(string &value) {
    return [&value](Slice value_str) {
      value = value_str.str();
    };
  }

  void set_usage(Slice executable_name, Slice usage);

  void set_description(string description);

  void add_checked_option(char short_key, Slice long_key, Slice description, std::function<Status(Slice)> callback);

  void add_checked_option(char short_key, Slice long_key, Slice description, std::function<Status(void)> callback);

  void add_option(char short_key, Slice long_key, Slice description, std::function<Status(Slice)> callback) = delete;

  void add_option(char short_key, Slice long_key, Slice description, std::function<Status(void)> callback) = delete;

  void add_option(char short_key, Slice long_key, Slice description, std::function<void(Slice)> callback);

  void add_option(char short_key, Slice long_key, Slice description, std::function<void(void)> callback);

  void add_check(std::function<Status()> check);

  // returns found non-option parameters
  Result<vector<char *>> run(int argc, char *argv[], int expected_non_option_count = -1) TD_WARN_UNUSED_RESULT;

  // for testing only
  Result<vector<char *>> run_impl(int argc, char *argv[], int expected_non_option_count) TD_WARN_UNUSED_RESULT;

  friend StringBuilder &operator<<(StringBuilder &sb, const OptionParser &o);

 private:
  vector<Option> options_;
  vector<std::function<Status()>> checks_;
  string usage_;
  string description_;
};

}  // namespace td
