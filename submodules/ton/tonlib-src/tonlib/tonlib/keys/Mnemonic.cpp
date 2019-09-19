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
#include "Mnemonic.h"

#include "tonlib/keys/bip39.h"

#include <vector>

#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/Random.h"
#include "td/utils/Span.h"
#include "td/utils/misc.h"
#include "td/utils/optional.h"
#include "td/utils/Timer.h"

#include "crypto/Ed25519.h"

#include <algorithm>

namespace tonlib {
td::Result<Mnemonic> Mnemonic::create(td::SecureString words, td::SecureString password) {
  return create_from_normalized(normalize_and_split(std::move(words)), std::move(password));
}
td::Result<Mnemonic> Mnemonic::create(std::vector<td::SecureString> words, td::SecureString password) {
  return create(join(words), std::move(password));
}
td::Result<Mnemonic> Mnemonic::create_from_normalized(std::vector<td::SecureString> words, td::SecureString password) {
  auto new_words = normalize_and_split(join(words));
  if (new_words != words) {
    return td::Status::Error("Mnemonic string is not normalized");
  }
  return Mnemonic(std::move(words), std::move(password));
}

td::SecureString Mnemonic::to_entropy() const {
  td::SecureString res(64);
  td::hmac_sha512(join(words_), password_, res.as_mutable_slice());
  return res;
}

td::SecureString Mnemonic::to_seed() const {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "TON default seed", PBKDF_ITERATIONS, hash.as_mutable_slice());
  return hash;
}

td::Ed25519::PrivateKey Mnemonic::to_private_key() const {
  return td::Ed25519::PrivateKey(td::SecureString(as_slice(to_seed()).substr(0, td::Ed25519::PrivateKey::LENGTH)));
}

bool Mnemonic::is_basic_seed() {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "TON seed version", td::max(1, PBKDF_ITERATIONS / 256),
                    hash.as_mutable_slice());
  return hash.as_slice()[0] == 0;
}

bool Mnemonic::is_password_seed() {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "TON fast seed version", 1, hash.as_mutable_slice());
  return hash.as_slice()[0] == 1;
}

std::vector<td::SecureString> Mnemonic::get_words() const {
  std::vector<td::SecureString> res;
  for (auto &word : words_) {
    res.push_back(word.copy());
  }
  return res;
}

std::vector<td::SecureString> Mnemonic::normalize_and_split(td::SecureString words) {
  for (auto &c : words.as_mutable_slice()) {
    if (td::is_alpha(c)) {
      c = td::to_lower(c);
    } else {
      c = ' ';
    }
  }
  auto vec = td::full_split(words.as_slice(), ' ');
  std::vector<td::SecureString> res;
  for (auto &s : vec) {
    if (!s.empty()) {
      res.push_back(td::SecureString(s));
    }
  }
  return res;
}

td::StringBuilder &operator<<(td::StringBuilder &sb, const Mnemonic &mnemonic) {
  sb << "Mnemonic" << td::format::as_array(mnemonic.words_);
  if (!mnemonic.password_.empty()) {
    sb << " with password[" << mnemonic.password_ << "]";
  }
  return sb;
}

Mnemonic::Mnemonic(std::vector<td::SecureString> words, td::SecureString password)
    : words_(std::move(words)), password_(std::move(password)) {
}
td::SecureString Mnemonic::join(td::Span<td::SecureString> words) {
  size_t res_size = 0;
  for (size_t i = 0; i < words.size(); i++) {
    if (i != 0) {
      res_size++;
    }
    res_size += words[i].size();
  }
  td::SecureString res(res_size);
  auto dst = res.as_mutable_slice();
  for (size_t i = 0; i < words.size(); i++) {
    if (i != 0) {
      dst[0] = ' ';
      dst.remove_prefix(1);
    }
    dst.copy_from(words[i].as_slice());
    dst.remove_prefix(words[i].size());
  }
  return res;
}

td::Span<std::string> Mnemonic::word_hints(td::Slice prefix) {
  static std::vector<std::string> words = [] {
    auto bip_words = Mnemonic::normalize_and_split(td::SecureString(bip39_english()));
    std::vector<std::string> res;
    for (auto &word : bip_words) {
      res.push_back(word.as_slice().str());
    }
    return res;
  }();
  if (prefix.empty()) {
    return words;
  }

  auto p = std::equal_range(words.begin(), words.end(), prefix, [&](td::Slice a, td::Slice b) {
    return a.truncate(prefix.size()) < b.truncate(prefix.size());
  });

  return td::Span<std::string>(&*p.first, p.second - p.first);
}

td::Result<Mnemonic> Mnemonic::create_new(Options options) {
  td::Timer timer;
  if (options.words_count == 0) {
    options.words_count = 24;
  }
  if (options.words_count < 8 || options.words_count > 48) {
    return td::Status::Error(PSLICE() << "Invalid words count(" << options.words_count
                                      << ") requested for mnemonic creation");
  }
  td::int32 max_iterations = 256 * 20;
  if (!options.password.empty()) {
    max_iterations *= 256;
  }

  td::Random::add_seed(options.entropy.as_slice());
  SCOPE_EXIT {
    td::Random::secure_cleanup();
  };

  auto bip_words = Mnemonic::normalize_and_split(td::SecureString(bip39_english()));
  CHECK(bip_words.size() == 2048);

  int A = 0, B = 0, C = 0;
  for (int iteration = 0; iteration < max_iterations; iteration++) {
    std::vector<td::SecureString> words;
    td::SecureString rnd((options.words_count * 11 + 7) / 8);
    td::Random::secure_bytes(rnd.as_mutable_slice());
    for (int i = 0; i < options.words_count; i++) {
      size_t word_i = 0;
      for (size_t j = 0; j < 11; j++) {
        size_t offset = i * 11 + j;
        if ((rnd[offset / 8] & (1 << (offset & 7))) != 0) {
          word_i |= 1 << j;
        }
      }
      words.push_back(bip_words[word_i].copy());
    }

    bool has_password = !options.password.empty();

    td::optional<Mnemonic> mnemonic_without_password;
    if (has_password) {
      auto copy_words = td::transform(words, [](auto &w) { return w.copy(); });
      mnemonic_without_password = Mnemonic::create(std::move(copy_words), {}).move_as_ok();
      if (!mnemonic_without_password.value().is_password_seed()) {
        A++;
        continue;
      }
    }

    auto mnemonic = Mnemonic::create(std::move(words), options.password.copy()).move_as_ok();

    if (!mnemonic.is_basic_seed()) {
      B++;
      continue;
    }

    if (has_password && mnemonic_without_password.value().is_basic_seed()) {
      C++;
      continue;
    }

    LOG(INFO) << "Mnemonic generation debug stats: " << A << " " << B << " " << C << " " << timer;
    return std::move(mnemonic);
  }
  return td::Status::Error("Failed to create a mnemonic (should not happen)");
}
}  // namespace tonlib
