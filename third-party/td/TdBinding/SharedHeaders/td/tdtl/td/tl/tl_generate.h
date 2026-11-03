//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_config.h"
#include "td/tl/tl_outputer.h"
#include "td/tl/tl_writer.h"

#include <string>

namespace td {
namespace tl {

void write_tl(const tl_config &config, tl_outputer &out, const TL_writer &w);

tl_config read_tl_config_from_file(const std::string &file_name);

bool write_tl_to_file(const tl_config &config, const std::string &file_name, const TL_writer &w);

bool write_tl_to_multiple_files(const tl_config &config, const std::string &file_name_prefix,
                                const std::string &file_name_suffix, const TL_writer &w);

}  // namespace tl
}  // namespace td
