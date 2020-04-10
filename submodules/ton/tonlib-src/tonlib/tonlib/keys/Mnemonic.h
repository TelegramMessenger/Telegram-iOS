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

#include "crypto/Ed25519.h"

#include "td/utils/int_types.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

namespace tonlib {
class Mnemonic {
 public:
  static constexpr int PBKDF_ITERATIONS = 100000;
  static td::Result<Mnemonic> create(td::SecureString words, td::SecureString password);
  static td::Result<Mnemonic> create(std::vector<td::SecureString> words, td::SecureString password);
  struct Options {
    Options() {
    }
    int words_count = 24;
    td::SecureString password;
    td::SecureString entropy;
  };
  static td::Result<Mnemonic> create_new(Options options = {});

  td::SecureString to_entropy() const;

  td::SecureString to_seed() const;

  td::Ed25519::PrivateKey to_private_key() const;

  bool is_basic_seed();
  bool is_password_seed();

  std::vector<td::SecureString> get_words() const;

  static std::vector<td::SecureString> normalize_and_split(td::SecureString words);
  static td::Span<std::string> word_hints(td::Slice prefix);

 private:
  std::vector<td::SecureString> words_;
  td::SecureString password_;

  Mnemonic(std::vector<td::SecureString> words, td::SecureString password);
  static td::SecureString join(td::Span<td::SecureString> words);
  static td::Result<Mnemonic> create_from_normalized(std::vector<td::SecureString> words, td::SecureString password);
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const Mnemonic &mnemonic);
};

}  // namespace tonlib
