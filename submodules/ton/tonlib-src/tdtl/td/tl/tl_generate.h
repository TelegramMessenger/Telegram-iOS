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
#pragma once

#include "tl_config.h"
#include "tl_outputer.h"
#include "tl_writer.h"

#include <string>

namespace td {
namespace tl {

void write_tl(const tl_config &config, tl_outputer &out, const TL_writer &w);

tl_config read_tl_config_from_file(const std::string &file_name);
bool write_tl_to_file(const tl_config &config, const std::string &file_name, const TL_writer &w);

}  // namespace tl
}  // namespace td
