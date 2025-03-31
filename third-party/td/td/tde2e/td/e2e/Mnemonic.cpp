//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/Mnemonic.h"

#include "td/e2e/bip39.h"
#include "td/e2e/MessageEncryption.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/optional.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Span.h"
#include "td/utils/Timer.h"

#include <algorithm>
#include <vector>

namespace tde2e_core {

td::Result<Mnemonic> Mnemonic::create(td::SecureString words, td::SecureString password) {
  return create_from_normalized(normalize_and_split(std::move(words)), std::move(password));
}
td::Result<Mnemonic> Mnemonic::create(std::vector<td::SecureString> words, td::SecureString password) {
  return create(join(words), std::move(password));
}
Mnemonic::Options::Options() = default;
td::Result<Mnemonic> Mnemonic::create_from_normalized(const std::vector<td::SecureString> &words,
                                                      td::SecureString password) {
  auto new_words = normalize_and_split(join(words));
  if (new_words != words) {
    return td::Status::Error("Mnemonic string is not normalized");
  }
  return Mnemonic(std::move(new_words), std::move(password));
}

td::SecureString Mnemonic::to_entropy() const {
  td::SecureString res(64);
  td::hmac_sha512(join(words_), password_, res.as_mutable_slice());
  return res;
}

td::SecureString Mnemonic::to_seed() const {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "tde2e default seed", PBKDF_ITERATIONS, hash.as_mutable_slice());
  return hash;
}

PrivateKey Mnemonic::to_private_key() const {
  return PrivateKey::from_slice(to_seed().as_slice().substr(0, 32)).move_as_ok();
}

bool Mnemonic::is_basic_seed() const {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "tde2e seed version", td::max(1, PBKDF_ITERATIONS / 256),
                    hash.as_mutable_slice());
  return hash.as_slice()[0] == 0;
}

bool Mnemonic::is_password_seed() const {
  td::SecureString hash(64);
  td::pbkdf2_sha512(as_slice(to_entropy()), "tde2e fast seed version", 1, hash.as_mutable_slice());
  return hash.as_slice()[0] == 1;
}

std::vector<td::SecureString> Mnemonic::get_words() const {
  return td::transform(words_, [](const auto &word) { return word.copy(); });
}
td::SecureString Mnemonic::get_words_string() const {
  CHECK(words_.size() > 0);
  size_t length = words_.size() - 1;
  for (auto &word : words_) {
    length += word.size();
  }
  td::SecureString res(length);
  auto dest = res.as_mutable_slice();
  bool is_first = true;
  for (auto &word : words_) {
    if (!is_first) {
      dest[0] = ' ';
      dest.remove_prefix(1);
    } else {
      is_first = false;
    }
    dest.copy_from(word);
    dest.remove_prefix(word.size());
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
      res.emplace_back(s);
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
    return td::transform(bip_words, [](const auto &word) { return word.as_slice().str(); });
  }();
  if (prefix.empty()) {
    return words;
  }

  auto p = std::equal_range(words.begin(), words.end(), prefix, [&](td::Slice a, td::Slice b) {
    return a.truncate(prefix.size()) < b.truncate(prefix.size());
  });

  return td::Span<std::string>(&*p.first, p.second - p.first);
}

std::vector<std::string> Mnemonic::generate_verification_words(td::Slice data) {
  static constexpr size_t VERIFICATION_WORD_COUNT = 24;
  static constexpr size_t BITS_PER_WORD = 11;
  static constexpr size_t BIP_WORD_COUNT = 1 << BITS_PER_WORD;
  static constexpr size_t HASH_SIZE = 64;
  static_assert(VERIFICATION_WORD_COUNT * BITS_PER_WORD <= HASH_SIZE * 8, "Verification words count is too large");

  static auto bip_words = Mnemonic::normalize_and_split(td::SecureString(bip39_english()));
  CHECK(bip_words.size() == BIP_WORD_COUNT);

  auto hash = MessageEncryption::combine_secrets("MnemonicVerificationWords", data);
  CHECK(hash.size() == HASH_SIZE);

  std::vector<std::string> verification_words;

  std::size_t bit_pos = 0;
  for (size_t i = 0; i < VERIFICATION_WORD_COUNT; ++i) {
    td::uint16 index = 0;
    for (size_t bit = 0; bit < BITS_PER_WORD; ++bit, ++bit_pos) {
      if ((hash[bit_pos / 8] >> (bit_pos % 8)) & 1) {
        index |= (1 << bit);
      }
    }
    verification_words.push_back(bip_words.at(index % 2048).as_slice().str());
  }
  CHECK(bit_pos <= hash.size() * 8);

  return verification_words;
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
  return td::Status::Error("Failed to create a mnemonic (must not happen)");
}

}  // namespace tde2e_core
