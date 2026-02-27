//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/Mnemonic.h"

#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/tl_helpers.h"

#include <string>
#include <vector>

namespace tde2e_core {

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
  DecryptedKey(std::vector<td::SecureString> mnemonic_words, PrivateKey key);
  explicit DecryptedKey(RawDecryptedKey key);

  std::vector<td::SecureString> mnemonic_words;
  PrivateKey private_key;

  EncryptedKey encrypt(td::Slice local_password, td::Slice secret = {}) const;
};

}  // namespace tde2e_core
