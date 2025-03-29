//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/PublicRsaKeySharedCdn.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#include <algorithm>

namespace td {

PublicRsaKeySharedCdn::PublicRsaKeySharedCdn(DcId dc_id) : dc_id_(dc_id) {
  CHECK(!dc_id_.is_empty());
  CHECK(!dc_id_.is_internal());
}

void PublicRsaKeySharedCdn::add_rsa(mtproto::RSA rsa) {
  auto lock = rw_mutex_.lock_write();
  auto fingerprint = rsa.get_fingerprint();
  if (get_rsa_key_unsafe(fingerprint) != nullptr) {
    return;
  }
  keys_.push_back(RsaKey{std::move(rsa), fingerprint});
}

Result<mtproto::PublicRsaKeyInterface::RsaKey> PublicRsaKeySharedCdn::get_rsa_key(const vector<int64> &fingerprints) {
  auto lock = rw_mutex_.lock_read();
  for (auto fingerprint : fingerprints) {
    auto *rsa_key = get_rsa_key_unsafe(fingerprint);
    if (rsa_key != nullptr) {
      return RsaKey{rsa_key->rsa.clone(), fingerprint};
    }
  }
  return Status::Error(PSLICE() << "Unknown CDN fingerprints " << fingerprints);
}

void PublicRsaKeySharedCdn::drop_keys() {
  LOG(INFO) << "Drop " << keys_.size() << " keys for " << dc_id_;
  auto lock = rw_mutex_.lock_write();
  keys_.clear();
  notify();
}

bool PublicRsaKeySharedCdn::has_keys() {
  auto lock = rw_mutex_.lock_read();
  return !keys_.empty();
}

void PublicRsaKeySharedCdn::add_listener(unique_ptr<Listener> listener) {
  if (listener->notify()) {
    auto lock = rw_mutex_.lock_write();
    listeners_.push_back(std::move(listener));
  }
}

mtproto::PublicRsaKeyInterface::RsaKey *PublicRsaKeySharedCdn::get_rsa_key_unsafe(int64 fingerprint) {
  auto it = std::find_if(keys_.begin(), keys_.end(),
                         [fingerprint](const auto &value) { return value.fingerprint == fingerprint; });
  if (it == keys_.end()) {
    return nullptr;
  }
  return &*it;
}

void PublicRsaKeySharedCdn::notify() {
  td::remove_if(listeners_, [&](auto &listener) { return !listener->notify(); });
}

}  // namespace td
