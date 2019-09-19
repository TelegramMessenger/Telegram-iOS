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

#include "SourceLookup.h"
#include "vm/db/TonDb.h"
#include "Dictionary.h"

#include "td/utils/Status.h"

namespace fift {
struct IntCtx;
int funny_interpret_loop(IntCtx& ctx);

struct Fift {
 public:
  struct Config {
    fift::SourceLookup source_lookup;
    vm::TonDb ton_db;
    fift::Dictionary dictionary;
    std::ostream* output_stream{&std::cout};
    std::ostream* error_stream{&std::cerr};
  };
  // Fift must own ton_db and dictionary, no concurrent access is allowed
  explicit Fift(Config config);

  td::Result<int> interpret_file(std::string fname, std::string current_dir, bool interactive = false);
  td::Result<int> interpret_istream(std::istream& stream, std::string current_dir, bool interactive = true);

  Config& config();

 private:
  Config config_;

  td::Result<int> do_interpret(IntCtx& ctx);
};
}  // namespace fift
