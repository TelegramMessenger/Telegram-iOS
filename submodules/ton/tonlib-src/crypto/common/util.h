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
#include <string>
#include "td/utils/Slice.h"
#include "td/utils/buffer.h"

namespace td {

std::size_t compute_base64_encoded_size(size_t bindata_size);
std::size_t buff_base64_encode(td::MutableSlice buffer, td::Slice raw, bool base64_url = false);
std::string str_base64_encode(std::string raw, bool base64_url = false);
std::string str_base64_encode(td::Slice raw, bool base64_url = false);

bool is_valid_base64(std::string encoded, bool allow_base64_url = true);
bool is_valid_base64(td::Slice encoded, bool allow_base64_url = true);
td::int32 decoded_base64_size(std::string encoded, bool allow_base64_url = true);
td::int32 decoded_base64_size(td::Slice encoded, bool allow_base64_url = true);

std::size_t buff_base64_decode(td::MutableSlice buffer, td::Slice data, bool allow_base64_url = true);
td::BufferSlice base64_decode(std::string encoded, bool allow_base64_url = true);
td::BufferSlice base64_decode(td::Slice encoded, bool allow_base64_url = true);
std::string str_base64_decode(std::string encoded, bool allow_base64_url = true);
std::string str_base64_decode(td::Slice encoded, bool allow_base64_url = true);

}  // namespace td
