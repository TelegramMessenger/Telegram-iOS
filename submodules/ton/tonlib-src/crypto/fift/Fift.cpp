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
#include "Fift.h"

#include "words.h"

#include "td/utils/PathView.h"

namespace fift {

Fift::Fift(Config config) : config_(std::move(config)) {
}

Fift::Config& Fift::config() {
  return config_;
}

td::Result<int> Fift::interpret_file(std::string fname, std::string current_dir, bool is_interactive) {
  auto r_file = config_.source_lookup.lookup_source(fname, current_dir);
  if (r_file.is_error()) {
    return td::Status::Error("cannot locate file `" + fname + "`");
  }
  auto file = r_file.move_as_ok();
  IntCtx ctx;
  std::stringstream ss(file.data);
  ctx.input_stream = &ss;
  ctx.filename = td::PathView(file.path).file_name().str();
  ctx.currentd_dir = td::PathView(file.path).parent_dir().str();
  ctx.include_depth = is_interactive ? 0 : 1;
  return do_interpret(ctx);
}

td::Result<int> Fift::interpret_istream(std::istream& stream, std::string current_dir, bool is_interactive) {
  IntCtx ctx;
  ctx.input_stream = &stream;
  ctx.filename = "stdin";
  ctx.currentd_dir = current_dir;
  ctx.include_depth = is_interactive ? 0 : 1;
  return do_interpret(ctx);
}

td::Result<int> Fift::do_interpret(IntCtx& ctx) {
  ctx.ton_db = &config_.ton_db;
  ctx.source_lookup = &config_.source_lookup;
  ctx.dictionary = &config_.dictionary;
  ctx.output_stream = config_.output_stream;
  ctx.error_stream = config_.error_stream;
  if (!ctx.output_stream) {
    return td::Status::Error("Cannot run interpreter without output_stream");
  }
  try {
    return funny_interpret_loop(ctx);
  } catch (fift::IntError ab) {
    return td::Status::Error(ab.msg);
  } catch (fift::Quit q) {
    return q.res;
  }
  return 0;
}
}  // namespace fift
