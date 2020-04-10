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
#include <vector>
#include <string>

#include "td/utils/tl_helpers.h"
#include "td/utils/SharedSlice.h"

#include "tonlib/keys/Mnemonic.h"

namespace tonlib {

struct RawDecryptedKey {
  std::vector<td::SecureString> mnemonic_words;
  td::SecureString private_key;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    store(mnemonic_words, storer);
    store(private_key, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    parse(mnemonic_words, parser);
    parse(private_key, parser);
  }
};

struct EncryptedKey;
struct DecryptedKey {
  DecryptedKey() = delete;
  explicit DecryptedKey(const Mnemonic &mnemonic);
  DecryptedKey(std::vector<td::SecureString> mnemonic_words, td::Ed25519::PrivateKey key);
  DecryptedKey(RawDecryptedKey key);

  std::vector<td::SecureString> mnemonic_words;
  td::Ed25519::PrivateKey private_key;

  EncryptedKey encrypt(td::Slice local_password, td::Slice secret = {}) const;
};

}  // namespace tonlib
