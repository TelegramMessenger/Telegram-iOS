//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Slice.h"
#include "td/utils/UInt.h"

namespace td {
namespace mtproto {

void KDF(Slice auth_key, const UInt128 &msg_key, int X, UInt256 *aes_key, UInt256 *aes_iv);

void tmp_KDF(const UInt128 &server_nonce, const UInt256 &new_nonce, UInt256 *tmp_aes_key, UInt256 *tmp_aes_iv);

void KDF2(Slice auth_key, const UInt128 &msg_key, int X, UInt256 *aes_key, UInt256 *aes_iv);

}  // namespace mtproto
}  // namespace td
