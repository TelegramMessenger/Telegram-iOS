/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "vm/stack.hpp"
#include <cassert>
#include <algorithm>
#include <string>
#include <vector>
#include <iostream>
#include <sstream>
#include <fstream>
#include <memory>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <map>
#include <functional>
#include <getopt.h>

#include "Fift.h"
#include "Dictionary.h"
#include "SourceLookup.h"
#include "words.h"

#include "vm/db/TonDb.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Parser.h"
#include "td/utils/port/path.h"

void usage(const char* progname) {
  std::cerr << "A simple Fift interpreter. Type `bye` to quit, or `words` to get a list of all commands\n";
  std::cerr
      << "usage: " << progname
      << " [-i] [-n] [-I <source-include-path>] {-L <library-fif-file>} <source-file1-fif> <source-file2-fif> ...\n";
  std::cerr << "\t-n\tDo not preload standard preamble file `Fift.fif`\n"
               "\t-i\tForce interactive mode even if explicit source file names are indicated\n"
               "\t-I<source-search-path>\tSets colon-separated library source include path. If not indicated, "
               "$FIFTPATH is used instead.\n"
               "\t-L<library-fif-file>\tPre-loads a library source file\n"
               "\t-d<ton-db-path>\tUse a ton database\n"
               "\t-s\tScript mode: use first argument as a fift source file and import remaining arguments as $n)\n"
               "\t-v<verbosity-level>\tSet verbosity level\n";
  std::exit(2);
}

void parse_include_path_set(std::string include_path_set, std::vector<std::string>& res) {
  td::Parser parser(include_path_set);
  while (!parser.empty()) {
    auto path = parser.read_till_nofail(':');
    if (!path.empty()) {
      res.push_back(path.str());
    }
    parser.skip_nofail(':');
  }
}

int main(int argc, char* const argv[]) {
  bool interactive = false;
  bool fift_preload = true, no_env = false;
  bool script_mode = false;
  std::vector<std::string> library_source_files, source_list;
  std::vector<std::string> source_include_path;
  std::string ton_db_path;

  fift::Fift::Config config;

  int i;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  while (!script_mode && (i = getopt(argc, argv, "hinI:L:d:sv:")) != -1) {
    switch (i) {
      case 'i':
        interactive = true;
        break;
      case 'n':
        fift_preload = false;
        break;
      case 'I':
        parse_include_path_set(optarg, source_include_path);
        no_env = true;
        break;
      case 'L':
        library_source_files.emplace_back(optarg);
        break;
      case 'd':
        ton_db_path = optarg;
        break;
      case 's':
        script_mode = true;
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + td::to_integer<int>(td::Slice(optarg));
        break;
      case 'h':
      default:
        usage(argv[0]);
    }
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);

  while (optind < argc) {
    source_list.emplace_back(argv[optind++]);
    if (script_mode) {
      break;
    }
  }

  if (!no_env) {
    const char* path = std::getenv("FIFTPATH");
    parse_include_path_set(path ? path : "/usr/lib/fift", source_include_path);
  }
  std::string current_dir;
  auto r_current_dir = td::realpath(".");
  if (r_current_dir.is_ok()) {
    current_dir = r_current_dir.move_as_ok();
    source_include_path.push_back(current_dir);
  }
  config.source_lookup = fift::SourceLookup(std::make_unique<fift::OsFileLoader>());
  for (auto& path : source_include_path) {
    config.source_lookup.add_include_path(path);
  }

  if (!ton_db_path.empty()) {
    auto r_ton_db = vm::TonDbImpl::open(ton_db_path);
    if (r_ton_db.is_error()) {
      LOG(ERROR) << "Error opening ton database: " << r_ton_db.error().to_string();
      std::exit(2);
    }
    config.ton_db = r_ton_db.move_as_ok();
    // FIXME //std::atexit([&] { config.ton_db.reset(); });
  }

  fift::init_words_common(config.dictionary);
  fift::init_words_vm(config.dictionary);
  fift::init_words_ton(config.dictionary);

  if (script_mode) {
    fift::import_cmdline_args(config.dictionary, source_list.empty() ? "" : source_list[0], argc - optind,
                              argv + optind);
  }

  fift::Fift fift(std::move(config));

  if (fift_preload) {
    auto status = fift.interpret_file("Fift.fif", "");
    if (status.is_error()) {
      LOG(ERROR) << "Error interpreting standard preamble file `Fift.fif`: " << status.error().message()
                 << "\nCheck that correct include path is set by -I or by FIFTPATH environment variable, or disable "
                    "standard preamble by -n.\n";
      std::exit(2);
    }
  }

  for (auto source : library_source_files) {
    auto status = fift.interpret_file(source, "");
    if (status.is_error()) {
      LOG(ERROR) << "Error interpreting preloaded file `" << source << "`: " << status.error().message();
      std::exit(2);
    }
  }

  if (source_list.empty()) {
    interactive = true;
  }
  for (const auto& source : source_list) {
    bool is_stdin = (source.empty() || source == "-");
    auto status =
        !is_stdin ? fift.interpret_file(source, current_dir) : fift.interpret_istream(std::cin, current_dir, false);
    if (status.is_error()) {
      if (!is_stdin) {
        LOG(ERROR) << "Error interpreting file `" << source << "`: " << status.error().message();
      } else {
        LOG(ERROR) << "Error interpreting stdin: " << status.error().message();
      }
      std::exit(2);
    }
    auto res = status.move_as_ok();
    if (res) {
      std::exit(~res);
    }
  }
  if (interactive) {
    auto status = fift.interpret_istream(std::cin, current_dir);
    if (status.is_error()) {
      LOG(ERROR) << status.error().message();
      std::exit(2);
    } else {
      int res = status.move_as_ok();
      if (res) {
        std::exit(~res);
      }
    }
  }
}
