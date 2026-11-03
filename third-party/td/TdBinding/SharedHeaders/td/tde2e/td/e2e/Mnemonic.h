//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/Keys.h"

#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace tde2e_core {

class Mnemonic {
 public:
  static constexpr int PBKDF_ITERATIONS = 100000;
  static td::Result<Mnemonic> create(td::SecureString words, td::SecureString password);
  static td::Result<Mnemonic> create(std::vector<td::SecureString> words, td::SecureString password);
  struct Options {
    Options();
    int word_count = 24;
    td::SecureString password;
    td::SecureString entropy;
  };
  static td::Result<Mnemonic> create_new(Options options = {});

  td::SecureString to_entropy() const;

  td::SecureString to_seed() const;

  PrivateKey to_private_key() const;

  bool is_basic_seed() const;
  bool is_password_seed() const;

  std::vector<td::SecureString> get_words() const;
  td::SecureString get_words_string() const;

  static std::vector<td::SecureString> normalize_and_split(td::SecureString words);
  static td::Span<std::string> word_hints(td::Slice prefix);
  static std::vector<std::string> generate_verification_words(td::Slice data);

 private:
  std::vector<td::SecureString> words_;
  td::SecureString password_;

  Mnemonic(std::vector<td::SecureString> words, td::SecureString password);
  static td::SecureString join(td::Span<td::SecureString> words);
  static td::Result<Mnemonic> create_from_normalized(const std::vector<td::SecureString> &words,
                                                     td::SecureString password);
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const Mnemonic &mnemonic);
};

}  // namespace tde2e_core
