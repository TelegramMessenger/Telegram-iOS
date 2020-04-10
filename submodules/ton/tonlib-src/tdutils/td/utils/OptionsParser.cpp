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
#include "td/utils/OptionsParser.h"

#if TD_HAVE_GETOPT
#include "getopt.h"
#endif

#if !TD_WINDOWS
#include <getopt.h>
#include <unistd.h>
#endif

namespace td {

void OptionsParser::set_description(std::string description) {
  description_ = std::move(description);
}

void OptionsParser::add_option(Option::Type type, char short_key, Slice long_key, Slice description,
                               std::function<Status(Slice)> callback) {
  for (auto &option : options_) {
    if (option.short_key == short_key || (!long_key.empty() && long_key == option.long_key)) {
      LOG(ERROR) << "Ignore duplicated option '" << short_key << "' '" << long_key << "'";
    }
  }
  options_.push_back(Option{type, short_key, long_key.str(), description.str(), std::move(callback)});
}

void OptionsParser::add_option(char short_key, Slice long_key, Slice description,
                               std::function<Status(Slice)> callback) {
  add_option(Option::Type::Arg, short_key, long_key, description, std::move(callback));
}

void OptionsParser::add_option(char short_key, Slice long_key, Slice description,
                               std::function<Status(void)> callback) {
  // Ouch. There must be some better way
  add_option(Option::Type::NoArg, short_key, long_key, description,
             std::bind([](std::function<Status(void)> &func, Slice) { return func(); }, std::move(callback),
                       std::placeholders::_1));
}

Result<int> OptionsParser::run(int argc, char *argv[]) {
#if TD_HAVE_GETOPT
  char buff[1024];
  StringBuilder sb(MutableSlice{buff, sizeof(buff)});
  for (auto &opt : options_) {
    CHECK(opt.type != Option::OptionalArg);
    sb << opt.short_key;
    if (opt.type == Option::Arg) {
      sb << ":";
    }
  }
  if (sb.is_error()) {
    return Status::Error("Can't parse options");
  }
  CSlice short_options = sb.as_cslice();

  vector<option> long_options;
  for (auto &opt : options_) {
    if (opt.long_key.empty()) {
      continue;
    }
    option o;
    o.flag = nullptr;
    o.val = opt.short_key;
    o.has_arg = opt.type == Option::Arg ? required_argument : no_argument;
    o.name = opt.long_key.c_str();
    long_options.push_back(o);
  }
  long_options.push_back({nullptr, 0, nullptr, 0});

  while (true) {
    int opt_i = getopt_long(argc, argv, short_options.c_str(), &long_options[0], nullptr);
    if (opt_i == ':') {
      return Status::Error("Missing argument");
    }
    if (opt_i == '?') {
      return Status::Error("Unrecognized option");
    }
    if (opt_i == -1) {
      break;
    }
    bool found = false;
    for (auto &opt : options_) {
      if (opt.short_key == opt_i) {
        Slice arg;
        if (opt.type == Option::Arg) {
          arg = Slice(optarg);
        }
        auto status = opt.arg_callback(arg);
        if (status.is_error()) {
          return std::move(status);
        }
        found = true;
        break;
      }
    }
    if (!found) {
      return Status::Error("Unknown argument");
    }
  }
  return optind;
#else
  return -1;
#endif
}

StringBuilder &operator<<(StringBuilder &sb, const OptionsParser &o) {
  sb << o.description_ << "\n";
  for (auto &opt : o.options_) {
    sb << "-" << opt.short_key;
    if (!opt.long_key.empty()) {
      sb << "|--" << opt.long_key;
    }
    if (opt.type == OptionsParser::Option::OptionalArg) {
      sb << "[";
    }
    if (opt.type != OptionsParser::Option::NoArg) {
      sb << "<arg>";
    }
    if (opt.type == OptionsParser::Option::OptionalArg) {
      sb << "]";
    }
    sb << "\t" << opt.description;
    sb << "\n";
  }
  return sb;
}

}  // namespace td
