//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_config.h"
#include "td/tl/tl_writer.h"

#include <string>

namespace td {

void gen_json_converter(const tl::tl_config &config, const std::string &file_name, tl::TL_writer::Mode mode);

}  // namespace td
