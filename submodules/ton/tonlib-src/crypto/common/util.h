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
#include <string>
#include "td/utils/Slice.h"
#include "td/utils/buffer.h"

#include "bitstring.h"

namespace td {

std::size_t compute_base64_encoded_size(size_t bindata_size);
std::size_t buff_base64_encode(td::MutableSlice buffer, td::Slice raw, bool base64_url = false);
std::string str_base64_encode(td::Slice raw, bool base64_url = false);

bool is_valid_base64(td::Slice encoded, bool allow_base64_url = true);
td::int32 decoded_base64_size(td::Slice encoded, bool allow_base64_url = true);

std::size_t buff_base64_decode(td::MutableSlice buffer, td::Slice data, bool allow_base64_url = true);
td::BufferSlice base64_decode(td::Slice encoded, bool allow_base64_url = true);
std::string str_base64_decode(td::Slice encoded, bool allow_base64_url = true);

//TODO: move it somewhere else
td::Result<std::string> adnl_id_encode(td::Slice id, bool upper_case = false);
std::string adnl_id_encode(Bits256 adnl_addr, bool upper_case = false);
td::Result<Bits256> adnl_id_decode(td::Slice id);

}  // namespace td
