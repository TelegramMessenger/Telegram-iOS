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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <functional>

namespace td {

class OptionsParser {
  class Option {
   public:
    enum Type { NoArg, Arg, OptionalArg };
    Type type;
    char short_key;
    std::string long_key;
    std::string description;
    std::function<Status(Slice)> arg_callback;
  };

 public:
  void set_description(std::string description);

  void add_option(Option::Type type, char short_key, Slice long_key, Slice description,
                  std::function<Status(Slice)> callback);

  void add_option(char short_key, Slice long_key, Slice description, std::function<Status(Slice)> callback);

  void add_option(char short_key, Slice long_key, Slice description, std::function<Status(void)> callback);

  Result<int> run(int argc, char *argv[]) TD_WARN_UNUSED_RESULT;

  friend StringBuilder &operator<<(StringBuilder &sb, const OptionsParser &o);

 private:
  std::vector<Option> options_;
  std::string description_;
};

}  // namespace td
