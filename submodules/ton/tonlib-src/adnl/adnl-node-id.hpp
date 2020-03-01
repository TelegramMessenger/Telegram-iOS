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

#include "keys/keys.hpp"
#include "common/io.hpp"

namespace ton {

namespace adnl {

class AdnlNodeIdShort {
 public:
  explicit AdnlNodeIdShort(const PublicKeyHash &hash) : hash_(hash) {
  }
  explicit AdnlNodeIdShort(PublicKeyHash &&hash) : hash_(std::move(hash)) {
  }
  AdnlNodeIdShort() {
  }
  explicit AdnlNodeIdShort(td::Slice data) : hash_(data) {
  }
  explicit AdnlNodeIdShort(td::Bits256 value) : hash_(value) {
  }
  explicit AdnlNodeIdShort(tl_object_ptr<ton_api::adnl_id_short> obj) : hash_(obj->id_) {
  }

  const auto &pubkey_hash() const {
    return hash_;
  }

  bool operator==(const AdnlNodeIdShort &with) const {
    return hash_ == with.hash_;
  }
  bool operator!=(const AdnlNodeIdShort &with) const {
    return hash_ != with.hash_;
  }
  bool operator<(const AdnlNodeIdShort &with) const {
    return hash_ < with.hash_;
  }
  tl_object_ptr<ton_api::adnl_id_short> tl() const {
    return create_tl_object<ton_api::adnl_id_short>(hash_.tl());
  }
  auto as_slice() {
    return hash_.as_slice();
  }
  auto as_slice() const {
    return hash_.as_slice();
  }
  auto uint256_value() const {
    return hash_.uint256_value();
  }
  auto bits256_value() const {
    return hash_.bits256_value();
  }
  static AdnlNodeIdShort zero() {
    return AdnlNodeIdShort{PublicKeyHash::zero()};
  }
  bool is_zero() const {
    return hash_.is_zero();
  }

  static td::Result<AdnlNodeIdShort> parse(td::Slice key);

  std::string serialize();

 private:
  PublicKeyHash hash_;
};

class AdnlNodeIdFull {
 private:
  explicit AdnlNodeIdFull(const tl_object_ptr<ton_api::PublicKey> &pub) : pub_(pub) {
  }

 public:
  explicit AdnlNodeIdFull(const PublicKey &pub) : pub_(pub) {
  }
  explicit AdnlNodeIdFull(PublicKey &&pub) : pub_(std::move(pub)) {
  }
  static td::Result<AdnlNodeIdFull> create(const tl_object_ptr<ton_api::PublicKey> &pub) {
    return AdnlNodeIdFull{pub};
  }
  AdnlNodeIdFull() {
  }
  const auto &pubkey() const {
    return pub_;
  }
  bool empty() const {
    return pub_.empty();
  }
  bool operator==(const AdnlNodeIdFull &with) const {
    return pub_ == with.pub_;
  }
  bool operator!=(const AdnlNodeIdFull &with) const {
    return pub_ != with.pub_;
  }
  auto tl() const {
    return pub_.tl();
  }
  AdnlNodeIdShort compute_short_id() const {
    return AdnlNodeIdShort{pub_.compute_short_id()};
  }

 private:
  PublicKey pub_;
};

}  // namespace adnl

}  // namespace ton

namespace td {

inline StringBuilder &operator<<(StringBuilder &stream, const ton::adnl::AdnlNodeIdShort &value) {
  return stream << value.bits256_value();
}

}  // namespace td
