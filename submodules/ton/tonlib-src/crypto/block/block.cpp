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
#include "td/utils/bits.h"
#include "block/block.h"
#include "block/block-auto.h"
#include "block/block-parse.h"
#include "block/mc-config.h"
#include "ton/ton-shard.h"
#include "common/bigexp.h"
#include "common/util.h"
#include "td/utils/crypto.h"
#include "td/utils/tl_storers.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"

namespace block {
using namespace std::literals::string_literals;

td::Result<PublicKey> PublicKey::from_bytes(td::Slice key) {
  if (key.size() != 32) {
    return td::Status::Error("Ed25519 public key must be exactly 32 bytes long");
  }
  PublicKey res;
  res.key = key.str();
  return res;
}

td::Result<PublicKey> PublicKey::parse(td::Slice key) {
  if (key.size() != 48) {
    return td::Status::Error("Serialized Ed25519 public key must be exactly 48 characters long");
  }
  td::uint8 buf[36];
  if (!buff_base64_decode(td::MutableSlice(buf, 36), key, true)) {
    return td::Status::Error("Public key is not serialized in base64 encoding");
  }

  td::uint16 hash = static_cast<td::uint16>((static_cast<unsigned>(buf[34]) << 8) + buf[35]);
  if (hash != td::crc16(td::Slice(buf, 34))) {
    return td::Status::Error("Public key has incorrect crc16 hash");
  }

  if (buf[0] != 0x3e) {
    return td::Status::Error("Not a public key");
  }
  if (buf[1] != 0xe6) {
    return td::Status::Error("Not an ed25519 public key");
  }

  return from_bytes(td::Slice(buf + 2, 32));
}

std::string PublicKey::serialize(bool base64_url) {
  CHECK(key.size() == 32);
  std::string buf(36, 0);
  td::MutableSlice bytes(buf);

  bytes[0] = static_cast<char>(0x3e);
  bytes[1] = static_cast<char>(0xe6);
  bytes.substr(2).copy_from(key);
  auto hash = td::crc16(bytes.substr(0, 34));
  bytes[34] = static_cast<char>(hash >> 8);
  bytes[35] = static_cast<char>(hash & 255);

  std::string res(48, 0);
  buff_base64_encode(res, bytes, base64_url);
  return res;
}

bool pack_std_smc_addr_to(char result[48], bool base64_url, ton::WorkchainId wc, const ton::StdSmcAddress& addr,
                          bool bounceable, bool testnet) {
  if (wc < -128 || wc >= 128) {
    return false;
  }
  unsigned char buffer[36];
  buffer[0] = (unsigned char)(0x51 - bounceable * 0x40 + testnet * 0x80);
  buffer[1] = (unsigned char)wc;
  std::memcpy(buffer + 2, addr.data(), 32);
  unsigned crc = td::crc16(td::Slice{buffer, 34});
  buffer[34] = (unsigned char)(crc >> 8);
  buffer[35] = (unsigned char)(crc & 0xff);
  CHECK(buff_base64_encode(td::MutableSlice{result, 48}, td::Slice{buffer, 36}, base64_url) == 48);
  return true;
}

std::string pack_std_smc_addr(bool base64_url, ton::WorkchainId wc, const ton::StdSmcAddress& addr, bool bounceable,
                              bool testnet) {
  char result[48];
  if (pack_std_smc_addr_to(result, base64_url, wc, addr, bounceable, testnet)) {
    return std::string{result, 48};
  } else {
    return "";
  }
}

bool unpack_std_smc_addr(const char packed[48], ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet) {
  unsigned char buffer[36];
  wc = ton::workchainInvalid;
  if (!buff_base64_decode(td::MutableSlice{buffer, 36}, td::Slice{packed, 48}, true)) {
    return false;
  }
  unsigned crc = td::crc16(td::Slice{buffer, 34});
  if (buffer[34] != (unsigned char)(crc >> 8) || buffer[35] != (unsigned char)(crc & 0xff)) {
    return false;
  }
  if ((buffer[0] & 0x3f) != 0x11) {
    return false;
  }
  testnet = (buffer[0] & 0x80);
  bounceable = !(buffer[0] & 0x40);
  wc = (td::int8)buffer[1];
  std::memcpy(addr.data(), buffer + 2, 32);
  return true;
}

bool unpack_std_smc_addr(td::Slice packed, ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet) {
  return packed.size() == 48 && unpack_std_smc_addr(packed.data(), wc, addr, bounceable, testnet);
}

bool unpack_std_smc_addr(std::string packed, ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet) {
  return packed.size() == 48 && unpack_std_smc_addr(packed.data(), wc, addr, bounceable, testnet);
}

StdAddress::StdAddress(std::string serialized) {
  rdeserialize(std::move(serialized));
}

StdAddress::StdAddress(td::Slice from) {
  rdeserialize(std::move(from));
}

std::string StdAddress::rserialize(bool base64_url) const {
  char buffer[48];
  return rserialize_to(buffer, base64_url) ? std::string{buffer, 48} : "";
}

bool StdAddress::rserialize_to(td::MutableSlice to, bool base64_url) const {
  return to.size() == 48 && rserialize_to(to.data(), base64_url);
}

bool StdAddress::rserialize_to(char to[48], bool base64_url) const {
  return pack_std_smc_addr_to(to, base64_url, workchain, addr, bounceable, testnet);
}

bool StdAddress::rdeserialize(td::Slice from) {
  return from.size() == 48 && unpack_std_smc_addr(from.data(), workchain, addr, bounceable, testnet);
}

bool StdAddress::rdeserialize(std::string from) {
  return from.size() == 48 && unpack_std_smc_addr(from.data(), workchain, addr, bounceable, testnet);
}

bool StdAddress::rdeserialize(const char from[48]) {
  return unpack_std_smc_addr(from, workchain, addr, bounceable, testnet);
}

bool StdAddress::operator==(const StdAddress& other) const {
  return workchain == other.workchain && addr == other.addr && bounceable == other.bounceable &&
         testnet == other.testnet;
}

int parse_hex_digit(int c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  c |= 0x20;
  if (c >= 'a' && c <= 'z') {
    return c - 'a' + 10;
  }
  return -1;
}

bool StdAddress::parse_addr(td::Slice acc_string) {
  if (rdeserialize(acc_string)) {
    return true;
  }
  testnet = false;
  bounceable = true;
  auto pos = acc_string.find(':');
  if (pos != std::string::npos) {
    if (pos > 10) {
      return invalidate();
    }
    auto tmp = acc_string.substr(0, pos);
    auto r_wc = td::to_integer_safe<ton::WorkchainId>(tmp);
    if (r_wc.is_error()) {
      return invalidate();
    }
    workchain = r_wc.move_as_ok();
    if (workchain == ton::workchainInvalid) {
      return invalidate();
    }
    ++pos;
  } else {
    pos = 0;
  }
  // LOG(DEBUG) << "parsing " << acc_string << " address";
  if (acc_string.size() != pos + 64) {
    return invalidate();
  }
  for (unsigned i = 0; i < 64; i++) {
    int x = parse_hex_digit(acc_string[pos + i]), m = 15;
    if (x < 0) {
      return invalidate();
    }
    if (!(i & 1)) {
      x <<= 4;
      m <<= 4;
    }
    addr.data()[i >> 1] = (unsigned char)((addr.data()[i >> 1] & ~m) | x);
  }
  return true;
}

bool parse_std_account_addr(td::Slice acc_string, ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool* bounceable,
                            bool* testnet_only) {
  StdAddress a;
  if (!a.parse_addr(acc_string)) {
    return false;
  }
  wc = a.workchain;
  addr = a.addr;
  if (testnet_only) {
    *testnet_only = a.testnet;
  }
  if (bounceable) {
    *bounceable = a.bounceable;
  }
  return true;
}

td::Result<StdAddress> StdAddress::parse(td::Slice acc_string) {
  StdAddress res;
  if (res.parse_addr(acc_string)) {
    return res;
  }
  return td::Status::Error("Failed to parse account address");
}

void ShardId::init() {
  if (!shard_pfx) {
    shard_pfx = (1ULL << 63);
    shard_pfx_len = 0;
  } else {
    shard_pfx_len = 63 - td::count_trailing_zeroes_non_zero64(shard_pfx);
  }
}

ShardId::ShardId(ton::WorkchainId wc_id, unsigned long long sh_pfx) : workchain_id(wc_id), shard_pfx(sh_pfx) {
  init();
}

ShardId::ShardId(ton::ShardIdFull ton_shard_id) : workchain_id(ton_shard_id.workchain), shard_pfx(ton_shard_id.shard) {
  init();
}

ShardId::ShardId(ton::BlockId ton_block_id) : workchain_id(ton_block_id.workchain), shard_pfx(ton_block_id.shard) {
  init();
}

ShardId::ShardId(const ton::BlockIdExt& ton_block_id)
    : workchain_id(ton_block_id.id.workchain), shard_pfx(ton_block_id.id.shard) {
  init();
}

ShardId::ShardId(ton::WorkchainId wc_id, unsigned long long sh_pfx, int sh_pfx_len)
    : workchain_id(wc_id), shard_pfx_len(sh_pfx_len) {
  if (sh_pfx_len < 0) {
    shard_pfx_len = 0;
    shard_pfx = (1ULL << 63);
  } else if (sh_pfx_len > 63) {
    shard_pfx_len = 63;
    shard_pfx = sh_pfx | 1;
  } else {
    unsigned long long pow = 1ULL << (63 - sh_pfx_len);
    shard_pfx = (sh_pfx | pow) & (pow - 1);
  }
}

std::ostream& operator<<(std::ostream& os, const ShardId& shard_id) {
  shard_id.show(os);
  return os;
}

void ShardId::show(std::ostream& os) const {
  if (workchain_id == ton::workchainInvalid) {
    os << '?';
    return;
  }
  os << workchain_id << ':' << shard_pfx_len << ',';
  unsigned long long t = shard_pfx;
  int cnt = 0;
  while ((t & ((1ULL << 63) - 1)) != 0) {
    static const char hex_digit[] = "0123456789ABCDEF";
    os << (char)hex_digit[t >> 60];
    t <<= 4;
    ++cnt;
  }
  if (!t || !cnt) {
    os << '_';
  }
}

std::string ShardId::to_str() const {
  std::ostringstream os;
  show(os);
  return os.str();
}

bool ShardId::serialize(vm::CellBuilder& cb) const {
  if (workchain_id == ton::workchainInvalid || cb.remaining_bits() < 104) {
    return false;
  }
  return cb.store_long_bool(0, 2) && cb.store_ulong_rchk_bool(shard_pfx_len, 6) &&
         cb.store_long_bool(workchain_id, 32) && cb.store_long_bool(shard_pfx & (shard_pfx - 1));
}

bool ShardId::deserialize(vm::CellSlice& cs) {
  if (cs.fetch_ulong(2) == 0 && cs.fetch_uint_to(6, shard_pfx_len) && cs.fetch_int_to(32, workchain_id) &&
      workchain_id != ton::workchainInvalid && cs.fetch_uint_to(64, shard_pfx)) {
    auto pow2 = (1ULL << (63 - shard_pfx_len));
    if (!(shard_pfx & (pow2 - 1))) {
      shard_pfx |= pow2;
      return true;
    }
  }

  invalidate();
  return false;
}

MsgProcessedUptoCollection::MsgProcessedUptoCollection(ton::ShardIdFull _owner, Ref<vm::CellSlice> cs_ref)
    : owner(_owner) {
  vm::Dictionary dict{std::move(cs_ref), 96};
  valid = dict.check_for_each([&](Ref<vm::CellSlice> value, td::ConstBitPtr key, int n) -> bool {
    if (value->size_ext() != 64 + 256) {
      return false;
    }
    list.emplace_back();
    MsgProcessedUpto& z = list.back();
    z.shard = key.get_uint(64);
    z.mc_seqno = (unsigned)((key + 64).get_uint(32));
    z.last_inmsg_lt = value.write().fetch_ulong(64);
    // std::cerr << "ProcessedUpto shard " << std::hex << z.shard << std::dec << std::endl;
    return value.write().fetch_bits_to(z.last_inmsg_hash) && z.shard && ton::shard_contains(owner.shard, z.shard);
  });
}

std::unique_ptr<MsgProcessedUptoCollection> MsgProcessedUptoCollection::unpack(ton::ShardIdFull _owner,
                                                                               Ref<vm::CellSlice> cs_ref) {
  auto v = std::make_unique<MsgProcessedUptoCollection>(_owner, std::move(cs_ref));
  return v && v->valid ? std::move(v) : std::unique_ptr<MsgProcessedUptoCollection>{};
}

bool MsgProcessedUpto::contains(const MsgProcessedUpto& other) const& {
  return ton::shard_is_ancestor(shard, other.shard) && mc_seqno >= other.mc_seqno &&
         (last_inmsg_lt > other.last_inmsg_lt ||
          (last_inmsg_lt == other.last_inmsg_lt && !(last_inmsg_hash < other.last_inmsg_hash)));
}

bool MsgProcessedUpto::contains(ton::ShardId other_shard, ton::LogicalTime other_lt, td::ConstBitPtr other_hash,
                                ton::BlockSeqno other_mc_seqno) const& {
  return ton::shard_is_ancestor(shard, other_shard) && mc_seqno >= other_mc_seqno &&
         (last_inmsg_lt > other_lt || (last_inmsg_lt == other_lt && !(last_inmsg_hash < other_hash)));
}

bool MsgProcessedUptoCollection::insert(ton::BlockSeqno mc_seqno, ton::LogicalTime last_proc_lt,
                                        td::ConstBitPtr last_proc_hash) {
  if (!last_proc_lt) {
    return false;
  }
  for (const auto& z : list) {
    if (z.contains(owner.shard, last_proc_lt, last_proc_hash, mc_seqno)) {
      return true;
    }
  }
  list.emplace_back(owner.shard, mc_seqno, last_proc_lt, last_proc_hash);
  return true;
}

bool MsgProcessedUptoCollection::insert_infty(ton::BlockSeqno mc_seqno, ton::LogicalTime last_proc_lt) {
  return insert(mc_seqno, last_proc_lt, td::Bits256::ones().bits());
}

bool MsgProcessedUptoCollection::is_reduced() const {
  if (!valid) {
    return false;
  }
  for (auto it = list.begin(); it < list.end(); ++it) {
    for (auto it2 = it + 1; it2 < list.end(); ++it2) {
      if (it->contains(*it2) || it2->contains(*it)) {
        return false;
      }
    }
  }
  return true;
}

bool MsgProcessedUptoCollection::contains(const MsgProcessedUpto& p_upto) const {
  for (const auto& z : list) {
    if (z.contains(p_upto)) {
      return true;
    }
  }
  return false;
}

bool MsgProcessedUptoCollection::contains(const MsgProcessedUptoCollection& other) const {
  for (const auto& w : other.list) {
    if (!contains(w)) {
      return false;
    }
  }
  return true;
}

const MsgProcessedUpto* MsgProcessedUptoCollection::is_simple_update_of(const MsgProcessedUptoCollection& other,
                                                                        bool& ok) const {
  ok = false;
  if (!contains(other)) {
    LOG(DEBUG) << "does not cointain the previous value";
    return nullptr;
  }
  if (other.contains(*this)) {
    LOG(DEBUG) << "coincides with the previous value";
    ok = true;
    return nullptr;
  }
  const MsgProcessedUpto* found = nullptr;
  for (const auto& z : list) {
    if (!other.contains(z)) {
      if (found) {
        LOG(DEBUG) << "has more than two new entries";
        return found;  // ok = false: update is not simple
      }
      found = &z;
    }
  }
  ok = true;
  return found;
}

ton::BlockSeqno MsgProcessedUptoCollection::min_mc_seqno() const {
  ton::BlockSeqno min_mc_seqno = ~0U;
  for (const auto& z : list) {
    min_mc_seqno = std::min(min_mc_seqno, z.mc_seqno);
  }
  return min_mc_seqno;
}

bool MsgProcessedUptoCollection::compactify() {
  std::sort(list.begin(), list.end());
  std::size_t i, j, k = 0, m = 0, n = list.size();
  std::vector<bool> mark(n, false);
  assert(mark.size() == n);
  for (i = 0; i < n; i++) {
    for (j = 0; j < n; j++) {
      if (j != i && !mark[j] && list[j].contains(list[i])) {
        mark[i] = true;
        ++m;
        break;
      }
    }
  }
  if (m) {
    for (i = 0; i < n; i++) {
      if (!mark[i]) {
        list[k++] = list[i];
      }
    }
    list.resize(k);
  }
  return true;
}

bool MsgProcessedUptoCollection::pack(vm::CellBuilder& cb) {
  if (!compactify()) {
    return false;
  }
  vm::Dictionary dict{96};
  for (const auto& z : list) {
    td::BitArray<96> key;
    vm::CellBuilder cb2;
    key.bits().store_uint(z.shard, 64);
    (key.bits() + 64).store_uint(z.mc_seqno, 32);
    if (!(cb2.store_long_bool(z.last_inmsg_lt) && cb2.store_bits_bool(z.last_inmsg_hash) &&
          dict.set_builder(key, cb2, vm::Dictionary::SetMode::Add))) {
      return false;
    }
  }
  return std::move(dict).append_dict_to_bool(cb);
}

bool MsgProcessedUptoCollection::split(ton::ShardIdFull new_owner) {
  if (!ton::shard_is_ancestor(owner, new_owner)) {
    return false;
  }
  if (owner == new_owner) {
    return true;
  }
  std::size_t n = list.size(), i, j = 0;
  for (i = 0; i < n; i++) {
    if (ton::shard_intersects(list[i].shard, new_owner.shard)) {
      list[i].shard = ton::shard_intersection(list[i].shard, new_owner.shard);
      if (j < i) {
        list[j] = std::move(list[i]);
      }
      j++;
    }
  }
  list.resize(j);
  owner = new_owner;
  return compactify();
}

bool MsgProcessedUptoCollection::combine_with(const MsgProcessedUptoCollection& other) {
  if (!(other.owner == owner || ton::shard_is_sibling(other.owner, owner))) {
    return false;
  }
  list.insert(list.end(), other.list.begin(), other.list.end());
  if (owner != other.owner) {
    owner = ton::shard_parent(owner);
  }
  return compactify();
}

bool MsgProcessedUpto::already_processed(const EnqueuedMsgDescr& msg) const {
  // LOG(DEBUG) << "compare msg (" << msg.lt_ << "," << msg.hash_.to_hex() << ") against record's (" << last_inmsg_lt
  //            << "," << last_inmsg_hash.to_hex() << ")";
  if (msg.lt_ > last_inmsg_lt) {
    return false;
  }
  if (!ton::shard_contains(shard, msg.next_prefix_.account_id_prefix)) {
    return false;
  }
  if (msg.lt_ == last_inmsg_lt && last_inmsg_hash < msg.hash_) {
    return false;
  }
  if (msg.same_workchain() && ton::shard_contains(shard, msg.cur_prefix_.account_id_prefix)) {
    // this branch is needed only for messages generated in the same shard
    // (such messages could have been processed without a reference from the masterchain)
    // ? enable this branch only if an extra boolean parameter is set ?
    return true;
  }
  auto shard_end_lt = compute_shard_end_lt(msg.cur_prefix_);
  // LOG(DEBUG) << "enqueued_lt = " << msg.enqueued_lt_ << " , shard_end_lt = " << shard_end_lt;
  return msg.enqueued_lt_ < shard_end_lt;
}

bool MsgProcessedUptoCollection::already_processed(const EnqueuedMsgDescr& msg) const {
  // LOG(DEBUG) << "checking message with cur_addr=" << msg.cur_prefix_.to_str()
  //            << " next_addr=" << msg.next_prefix_.to_str() << " against ProcessedUpto of neighbor " << owner.to_str();
  if (!ton::shard_contains(owner, msg.next_prefix_)) {
    return false;
  }
  for (const auto& rec : list) {
    if (rec.already_processed(msg)) {
      return true;
    }
  }
  return false;
}

bool MsgProcessedUptoCollection::can_check_processed() const {
  for (const auto& entry : list) {
    if (!entry.can_check_processed()) {
      return false;
    }
  }
  return true;
}

bool MsgProcessedUptoCollection::for_each_mcseqno(std::function<bool(ton::BlockSeqno)> func) const {
  for (const auto& entry : list) {
    if (!func(entry.mc_seqno)) {
      return false;
    }
  }
  return true;
}

std::ostream& MsgProcessedUpto::print(std::ostream& os) const {
  return os << "[" << ton::shard_to_str(shard) << "," << mc_seqno << "," << last_inmsg_lt << ","
            << last_inmsg_hash.to_hex() << "]";
}

std::ostream& MsgProcessedUptoCollection::print(std::ostream& os) const {
  os << "MsgProcessedUptoCollection of " << owner.to_str() << " = {";
  int i = 0;
  for (const auto& entry : list) {
    if (i++) {
      os << ", ";
    }
    os << entry;
  }
  os << "}";
  return os;
}

std::string MsgProcessedUpto::to_str() const {
  std::ostringstream os;
  print(os);
  return os.str();
}

std::string MsgProcessedUptoCollection::to_str() const {
  std::ostringstream os;
  print(os);
  return os.str();
}

// unpacks some fields from EnqueuedMsg
bool EnqueuedMsgDescr::unpack(vm::CellSlice& cs) {
  block::gen::EnqueuedMsg::Record enq;
  block::tlb::MsgEnvelope::Record_std env;
  block::gen::CommonMsgInfo::Record_int_msg_info info;
  if (!(tlb::unpack(cs, enq) && tlb::unpack_cell(enq.out_msg, env) && tlb::unpack_cell_inexact(env.msg, info))) {
    return invalidate();
  }
  src_prefix_ = block::tlb::t_MsgAddressInt.get_prefix(std::move(info.src));
  dest_prefix_ = block::tlb::t_MsgAddressInt.get_prefix(std::move(info.dest));
  if (!(src_prefix_.is_valid() && dest_prefix_.is_valid())) {
    return invalidate();
  }
  cur_prefix_ = interpolate_addr(src_prefix_, dest_prefix_, env.cur_addr);
  next_prefix_ = interpolate_addr(src_prefix_, dest_prefix_, env.next_addr);
  lt_ = info.created_lt;
  enqueued_lt_ = enq.enqueued_lt;
  hash_ = env.msg->get_hash().bits();
  msg_ = std::move(env.msg);
  msg_env_ = std::move(enq.out_msg);
  return true;
}

bool EnqueuedMsgDescr::check_key(td::ConstBitPtr key) const {
  return key.get_int(32) == next_prefix_.workchain && (key + 32).get_uint(64) == next_prefix_.account_id_prefix &&
         hash_ == key + 96;
}

bool ParamLimits::deserialize(vm::CellSlice& cs) {
  return cs.fetch_ulong(8) == 0xc3            // param_limits#c3
         && cs.fetch_uint_to(32, limits_[0])  // underload:uint32
         && cs.fetch_uint_to(32, limits_[1])  // soft_limit:uint32
         && cs.fetch_uint_to(32, limits_[3])  // hard_limit:uint32
         && limits_[0] <= limits_[1]          // { underload <= soft_limit }
         && limits_[1] <= limits_[3]          // { soft_limit <= hard_limit } = ParamLimits;
         && compute_medium_limit();
}

bool BlockLimits::deserialize(vm::CellSlice& cs) {
  return cs.fetch_ulong(8) == 0x5d     // block_limits#5d
         && bytes.deserialize(cs)      // bytes:ParamLimits
         && gas.deserialize(cs)        // gas:ParamLimits
         && lt_delta.deserialize(cs);  // lt_delta:ParamLimits
}

int ParamLimits::classify(td::uint64 value) const {
  int a = -1, b = limits_cnt;
  while (b - a > 1) {
    int c = (a + b) >> 1;
    if (value >= limits_[c]) {
      a = c;
    } else {
      b = c;
    }
  }
  return a + 1;
}

bool ParamLimits::fits(unsigned cls, td::uint64 value) const {
  return cls >= limits_cnt || value < limits_[cls];
}

int BlockLimits::classify_size(td::uint64 size) const {
  return bytes.classify(size);
}

int BlockLimits::classify_gas(td::uint64 gas_value) const {
  return gas.classify(gas_value);
}

int BlockLimits::classify_lt(ton::LogicalTime lt) const {
  return lt_delta.classify(lt - start_lt);
}

int BlockLimits::classify(td::uint64 size, td::uint64 gas, ton::LogicalTime lt) const {
  return std::max(std::max(classify_size(size), classify_gas(gas)), classify_lt(lt));
}

bool BlockLimits::fits(unsigned cls, td::uint64 size, td::uint64 gas_value, ton::LogicalTime lt) const {
  return bytes.fits(cls, size) && gas.fits(cls, gas_value) && lt_delta.fits(cls, lt - start_lt);
}

td::uint64 BlockLimitStatus::estimate_block_size(const vm::NewCellStorageStat::Stat* extra) const {
  auto sum = st_stat.get_total_stat();
  if (extra) {
    sum += *extra;
  }
  return 2000 + (sum.bits >> 3) + sum.cells * 12 + sum.internal_refs * 3 + sum.external_refs * 40 + accounts * 200 +
         transactions * 200 + (extra ? 200 : 0);
}

int BlockLimitStatus::classify() const {
  return limits.classify(estimate_block_size(), gas_used, cur_lt);
}

bool BlockLimitStatus::fits(unsigned cls) const {
  return cls >= ParamLimits::limits_cnt ||
         (limits.gas.fits(cls, gas_used) && limits.lt_delta.fits(cls, cur_lt - limits.start_lt) &&
          limits.bytes.fits(cls, estimate_block_size()));
}

bool BlockLimitStatus::would_fit(unsigned cls, ton::LogicalTime end_lt, td::uint64 more_gas,
                                 const vm::NewCellStorageStat::Stat* extra) const {
  return cls >= ParamLimits::limits_cnt || (limits.gas.fits(cls, gas_used + more_gas) &&
                                            limits.lt_delta.fits(cls, std::max(cur_lt, end_lt) - limits.start_lt) &&
                                            limits.bytes.fits(cls, estimate_block_size(extra)));
}

// SETS: account_dict, shard_libraries_, mc_state_extra
//    total_balance{,_extra}, total_validator_fees
// SETS: out_msg_queue, processed_upto_, ihr_pending (via unpack_out_msg_queue_info)
// SETS: utime_, lt_
td::Status ShardState::unpack_state(ton::BlockIdExt blkid, Ref<vm::Cell> prev_state_root) {
  if (!blkid.is_valid()) {
    return td::Status::Error(-666, "invalid block id supplied to ShardState::unpack");
  }
  if (prev_state_root.is_null()) {
    return td::Status::Error(-666, "the root cell supplied for the shardchain state "s + blkid.to_str() + " is null");
  }
  block::gen::ShardStateUnsplit::Record state;
  if (!tlb::unpack_cell(prev_state_root, state)) {
    return td::Status::Error(-666, "cannot unpack header of shardchain state "s + blkid.to_str());
  }
  if ((unsigned)state.seq_no != blkid.seqno()) {
    return td::Status::Error(
        -666, PSTRING() << "shardchain state for " << blkid.to_str() << " has incorrect seqno " << state.seq_no);
  }
  auto shard1 = ton::ShardIdFull(block::ShardId{state.shard_id});
  if (shard1 != blkid.shard_full()) {
    return td::Status::Error(-666, "shardchain state for "s + blkid.to_str() +
                                       " corresponds to incorrect workchain or shard " + shard1.to_str());
  }
  id_ = blkid;
  root_ = std::move(prev_state_root);
  vert_seqno_ = state.vert_seq_no;
  before_split_ = state.before_split;
  account_dict_ = std::make_unique<vm::AugmentedDictionary>(
      vm::load_cell_slice(std::move(state.accounts)).prefetch_ref(), 256, block::tlb::aug_ShardAccounts);
  // check that all keys in account_dict have correct prefixes
  td::BitArray<64> acc_pfx{(long long)shard1.shard};
  int acc_pfx_len = shard_prefix_length(shard1);
  if (!account_dict_->has_common_prefix(acc_pfx.bits(), acc_pfx_len)) {
    return td::Status::Error(-666, "account dictionary of previous state of "s + id_.to_str() + " does not have " +
                                       acc_pfx.bits().to_hex(acc_pfx_len) + " as common key prefix");
  }
  // get overload / underload history
  overload_history_ = state.r1.overload_history;
  underload_history_ = state.r1.underload_history;
  // get shard libraries
  shard_libraries_ = std::make_unique<vm::Dictionary>(state.r1.libraries->prefetch_ref(), 256);
  if (!shard_libraries_->is_empty() && !shard1.is_masterchain()) {
    return td::Status::Error(-666,
                             "shardchain state "s + id_.to_str() +
                                 " has a non-trivial shard libraries collection, but it is not in the masterchain");
  }
  mc_state_extra_ = state.custom->prefetch_ref();
  vm::CellSlice cs{*state.r1.master_ref};  // master_ref:(Maybe BlkMasterInfo)
  if ((int)cs.fetch_ulong(1) == 1) {
    if (!(block::tlb::t_ExtBlkRef.unpack(cs, mc_blk_ref_, &mc_blk_lt_) && cs.empty_ext())) {
      return td::Status::Error(-666, "cannot unpack master_ref in shardchain state of "s + id_.to_str());
    }
    mc_blk_seqno_ = mc_blk_ref_.seqno();
  } else {
    mc_blk_seqno_ = 0;
    mc_blk_lt_ = 0;
    mc_blk_ref_.invalidate();
  }
  min_ref_mc_seqno_ = state.min_ref_mc_seqno;
  global_id_ = state.global_id;
  utime_ = state.gen_utime;
  lt_ = state.gen_lt;
  if (!total_balance_.validate_unpack(state.r1.total_balance)) {
    return td::Status::Error(
        -666, "cannot unpack total_balance:CurrencyCollection from previous ShardState of "s + id_.to_str());
  }
  auto accounts_extra = account_dict_->get_root_extra();
  CurrencyCollection old_total_balance;
  if (!(accounts_extra.write().advance(5) && old_total_balance.fetch(accounts_extra.write()))) {
    return td::Status::Error(
        -666,
        "cannot extract total account balance from ShardAccounts contained in previous ShardState of "s + id_.to_str());
  }
  if (old_total_balance != total_balance_) {
    return td::Status::Error(-666, "invalid previous ShardState for "s + id_.to_str() + ": declared total balance " +
                                       total_balance_.to_str() + " differs from " + old_total_balance.to_str() +
                                       " obtained by summing over all Accounts");
  }
  if (!(total_validator_fees_.validate_unpack(state.r1.total_validator_fees) && !total_validator_fees_.has_extra())) {
    return td::Status::Error(
        -666, "cannot unpack total_validator_fees:CurrencyCollection from previous ShardState of "s + id_.to_str());
  }
  if (is_masterchain()) {
    if (mc_state_extra_.is_null()) {
      return td::Status::Error(-666, "ShardState of "s + id_.to_str() + " does not contain McStateExtra");
    }
    block::gen::McStateExtra::Record extra;
    if (!tlb::unpack_cell(mc_state_extra_, extra)) {
      return td::Status::Error(-666, "cannot unpack McStateExtra in ShardState of "s + id_.to_str());
    }
    if (!global_balance_.validate_unpack(extra.global_balance)) {
      return td::Status::Error(-666, "ShardState of "s + id_.to_str() + " does not contain a valid global_balance");
    }
    if (extra.r1.flags & 1) {
      if (extra.r1.block_create_stats->prefetch_ulong(8) == 0x17) {
        block_create_stats_ = std::make_unique<vm::Dictionary>(extra.r1.block_create_stats->prefetch_ref(), 256);
      } else {
        return td::Status::Error(-666, "ShardState of "s + id_.to_str() + " does not contain a valid BlockCreateStats");
      }
    } else {
      block_create_stats_ = std::make_unique<vm::Dictionary>(256);
    }
  }
  return unpack_out_msg_queue_info(std::move(state.out_msg_queue_info));
}

// SETS: out_msg_queue, processed_upto_, ihr_pending
td::Status ShardState::unpack_out_msg_queue_info(Ref<vm::Cell> out_msg_queue_info) {
  block::gen::OutMsgQueueInfo::Record qinfo;
  if (!tlb::unpack_cell(std::move(out_msg_queue_info), qinfo)) {
    return td::Status::Error(-666, "cannot unpack OutMsgQueueInfo in the state of "s + id_.to_str());
  }
  out_msg_queue_ =
      std::make_unique<vm::AugmentedDictionary>(std::move(qinfo.out_queue), 352, block::tlb::aug_OutMsgQueue);
  if (verbosity >= 3 * 1) {
    LOG(DEBUG) << "unpacking ProcessedUpto of our previous block " << id_.to_str();
    block::gen::t_ProcessedInfo.print(std::cerr, qinfo.proc_info);
  }
  if (!block::gen::t_ProcessedInfo.validate_csr(1024, qinfo.proc_info)) {
    return td::Status::Error(
        -666, "ProcessedInfo in the state of "s + id_.to_str() + " is invalid according to automated validity checks");
  }
  if (!block::gen::t_IhrPendingInfo.validate_csr(1024, qinfo.ihr_pending)) {
    return td::Status::Error(
        -666, "IhrPendingInfo in the state of "s + id_.to_str() + " is invalid according to automated validity checks");
  }
  processed_upto_ = block::MsgProcessedUptoCollection::unpack(ton::ShardIdFull(id_), std::move(qinfo.proc_info));
  ihr_pending_ = std::make_unique<vm::Dictionary>(std::move(qinfo.ihr_pending), 320);
  auto shard1 = id_.shard_full();
  td::BitArray<64> pfx{(long long)shard1.shard};
  int pfx_len = shard_prefix_length(shard1);
  if (!ihr_pending_->has_common_prefix(pfx.bits(), pfx_len)) {
    return td::Status::Error(-666, "IhrPendingInfo in the state of "s + id_.to_str() + " does not have " +
                                       pfx.bits().to_hex(pfx_len) + " as common key prefix");
  }
  return td::Status::OK();
}

// UPDATES: prev_state_utime_, prev_state_lt_
bool ShardState::update_prev_utime_lt(ton::UnixTime& prev_utime, ton::LogicalTime& prev_lt) const {
  prev_utime = std::max<ton::UnixTime>(prev_utime, utime_);
  prev_lt = std::max<ton::LogicalTime>(prev_lt, lt_);
  return true;
}

td::Status ShardState::check_before_split(bool req_before_split) const {
  CHECK(id_.is_valid());
  if (before_split_ != req_before_split) {
    return td::Status::Error(PSTRING() << "previous state for " << id_.to_str() << " has before_split=" << before_split_
                                       << ", but we have after_split=" << req_before_split);
  }
  return td::Status::OK();
}

td::Status ShardState::check_global_id(int req_global_id) const {
  if (global_id_ != req_global_id) {
    return td::Status::Error(-666, PSTRING() << "global blockchain id mismatch in shard state of " << id_.to_str()
                                             << ": expected " << req_global_id << ", found " << global_id_);
  }
  return td::Status::OK();
}

td::Status ShardState::check_mc_blk_seqno(ton::BlockSeqno last_mc_block_seqno) const {
  if (mc_blk_seqno_ > last_mc_block_seqno) {
    return td::Status::Error(
        -666, PSTRING() << "previous block refers to masterchain block with seqno " << mc_blk_seqno_
                        << " larger than the latest known masterchain block seqno " << last_mc_block_seqno);
  }
  return td::Status::OK();
}

td::Status ShardState::unpack_state_ext(ton::BlockIdExt id, Ref<vm::Cell> state_root, int global_id,
                                        ton::BlockSeqno prev_mc_block_seqno, bool after_split, bool clear_history,
                                        std::function<bool(ton::BlockSeqno)> for_each_mcseqno_func) {
  TRY_STATUS(unpack_state(id, std::move(state_root)));
  TRY_STATUS(check_global_id(global_id));
  TRY_STATUS(check_mc_blk_seqno(prev_mc_block_seqno));
  TRY_STATUS(check_before_split(after_split));
  clear_load_history_if(clear_history);
  if (!for_each_mcseqno(std::move(for_each_mcseqno_func))) {
    return td::Status::Error(
        -666, "cannot perform necessary actions for each mc_seqno mentioned in ProcessedUpto of "s + id_.to_str());
  }
  return td::Status::OK();
}

td::Status ShardState::merge_with(ShardState& sib) {
  // 1. check that the two states are valid and belong to sibling shards
  if (!is_valid() || !sib.is_valid()) {
    return td::Status::Error(-666, "cannot merge invalid or uninitialized states");
  }
  if (!ton::shard_is_sibling(id_.shard_full(), sib.id_.shard_full())) {
    return td::Status::Error(-666, "cannot merge non-sibling states of "s + id_.to_str() + " and " + sib.id_.to_str());
  }
  ton::ShardIdFull shard = ton::shard_parent(id_.shard_full());
  // 2. compute total_balance and total_validator_fees
  total_balance_ += std::move(sib.total_balance_);
  if (!total_balance_.is_valid()) {
    return td::Status::Error(-667, "cannot add total_balance_extra of the two states being merged");
  }
  total_validator_fees_ += std::move(sib.total_validator_fees_);
  // 3. merge account_dict with sibling_account_dict
  LOG(DEBUG) << "merging account dictionaries";
  if (!account_dict_->combine_with(*sib.account_dict_)) {
    return td::Status::Error(-666, "cannot merge account dictionaries of the two ancestors");
  }
  sib.account_dict_.reset();
  // 3.1. check that all keys in merged account_dict have correct prefixes
  td::BitArray<64> pfx{(long long)shard.shard};
  int pfx_len = shard_prefix_length(shard);
  if (!account_dict_->has_common_prefix(pfx.bits(), pfx_len)) {
    return td::Status::Error(-666, "merged account dictionary of previous states of "s + shard.to_str() +
                                       " does not have " + pfx.bits().to_hex(pfx_len) + " as common key prefix");
  }
  // 3.2. check total balance of the new account_dict
  auto accounts_extra = account_dict_->get_root_extra();
  CurrencyCollection old_total_balance;
  if (!(accounts_extra.write().advance(5) && old_total_balance.fetch(accounts_extra.write()))) {
    return td::Status::Error(-666, "cannot extract total account balance from merged accounts dictionary");
  }
  if (old_total_balance != total_balance_) {
    return td::Status::Error(
        -666,
        "invalid merged account dictionary: declared total balance differs from one obtained by summing over all "
        "Accounts");
  }
  // 4. merge shard libraries
  CHECK(shard_libraries_->is_empty() && sib.shard_libraries_->is_empty());
  // 5. merge out_msg_queue
  LOG(DEBUG) << "merging outbound message queues";
  if (!out_msg_queue_->combine_with(*sib.out_msg_queue_)) {
    return td::Status::Error(-666, "cannot merge outbound message queues of the two ancestor states");
  }
  sib.out_msg_queue_.reset();
  // 6. merge processed_upto
  LOG(DEBUG) << "merging ProcessedUpto structures";
  if (!processed_upto_->combine_with(*sib.processed_upto_)) {
    return td::Status::Error(-666, "cannot merge ProcessedUpto structures of the two ancestor states");
  }
  sib.processed_upto_.reset();
  // 7. merge ihr_pending
  LOG(DEBUG) << "merging IhrPendingInfo";
  if (!ihr_pending_->combine_with(*sib.ihr_pending_)) {
    return td::Status::Error(-666, "cannot merge IhrPendingInfo of the two ancestors");
  }
  sib.ihr_pending_.reset();
  // 7.1. check whether all keys of the new ihr_pending have correct prefix
  if (!ihr_pending_->has_common_prefix(pfx.bits(), pfx_len)) {
    return td::Status::Error(-666, "merged IhrPendingInfo of the two previous states of "s + shard.to_str() +
                                       " does not have " + pfx.bits().to_hex(pfx_len) + " as common key prefix");
  }
  // 8. compute merged utime_ and lt_
  utime_ = std::max(utime_, sib.utime_);
  lt_ = std::max(lt_, sib.lt_);
  // 9. compute underload & overload history
  underload_history_ = overload_history_ = 0;
  // 10. compute vert_seqno
  vert_seqno_ = std::max(vert_seqno_, sib.vert_seqno_);
  // Anything else? add here
  // ...

  // 100. compute new root
  if (!block::gen::t_ShardState.cell_pack_split_state(root_, std::move(root_), std::move(sib.root_))) {
    return td::Status::Error(-667, "cannot construct a virtual split_state after a merge");
  }
  // 101. invalidate sibling, change id_ to the (virtual) common parent
  sib.invalidate();
  id_.id.shard = shard.shard;
  id_.file_hash.set_zero();
  id_.root_hash.set_zero();
  return td::Status::OK();
}

td::Result<std::unique_ptr<vm::AugmentedDictionary>> ShardState::compute_split_out_msg_queue(
    ton::ShardIdFull subshard) {
  auto shard = id_.shard_full();
  if (!ton::shard_is_parent(shard, subshard)) {
    return td::Status::Error(-666, "cannot split subshard "s + subshard.to_str() + " from state of " + id_.to_str() +
                                       " because it is not a parent");
  }
  CHECK(out_msg_queue_);
  auto subqueue = std::make_unique<vm::AugmentedDictionary>(*out_msg_queue_);
  int res = block::filter_out_msg_queue(*subqueue, shard, subshard);
  if (res < 0) {
    return td::Status::Error(-666, "error splitting OutMsgQueue of "s + id_.to_str());
  }
  LOG(DEBUG) << "OutMsgQueue split counter: " << res << " messages";
  return std::move(subqueue);
}

td::Result<std::shared_ptr<block::MsgProcessedUptoCollection>> ShardState::compute_split_processed_upto(
    ton::ShardIdFull subshard) {
  if (!ton::shard_is_parent(id_.shard_full(), subshard)) {
    return td::Status::Error(-666, "cannot split subshard "s + subshard.to_str() + " from state of " + id_.to_str() +
                                       " because it is not a parent");
  }
  CHECK(processed_upto_);
  auto sub_processed_upto = std::make_shared<block::MsgProcessedUptoCollection>(*processed_upto_);
  if (!sub_processed_upto->split(subshard)) {
    return td::Status::Error(-666, "error splitting ProcessedUpto of "s + id_.to_str());
  }
  return std::move(sub_processed_upto);
}

td::Status ShardState::split(ton::ShardIdFull subshard) {
  if (!ton::shard_is_parent(id_.shard_full(), subshard)) {
    return td::Status::Error(-666, "cannot split subshard "s + subshard.to_str() + " from state of " + id_.to_str() +
                                       " because it is not a parent");
  }
  // Have to split:
  // 1. account_dict
  LOG(DEBUG) << "splitting account dictionary";
  td::BitArray<64> pfx{(long long)subshard.shard};
  int pfx_len = shard_prefix_length(subshard);
  CHECK(account_dict_);
  CHECK(account_dict_->cut_prefix_subdict(pfx.bits(), pfx_len));
  CHECK(account_dict_->has_common_prefix(pfx.bits(), pfx_len));
  // 2. out_msg_queue
  LOG(DEBUG) << "splitting OutMsgQueue";
  auto shard1 = id_.shard_full();
  CHECK(ton::shard_is_parent(shard1, subshard));
  CHECK(out_msg_queue_);
  int res1 = block::filter_out_msg_queue(*out_msg_queue_, shard1, subshard);
  if (res1 < 0) {
    return td::Status::Error(-666, "error splitting OutMsgQueue of "s + id_.to_str());
  }
  LOG(DEBUG) << "split counters: " << res1;
  // 3. processed_upto
  LOG(DEBUG) << "splitting ProcessedUpto";
  CHECK(processed_upto_);
  if (!processed_upto_->split(subshard)) {
    return td::Status::Error(-666, "error splitting ProcessedUpto of "s + id_.to_str());
  }
  // 4. ihr_pending
  LOG(DEBUG) << "splitting IhrPending";
  CHECK(ihr_pending_->cut_prefix_subdict(pfx.bits(), pfx_len));
  CHECK(ihr_pending_->has_common_prefix(pfx.bits(), pfx_len));
  // 5. adjust total_balance
  LOG(DEBUG) << "splitting total_balance";
  auto old_total_balance = total_balance_;
  auto accounts_extra = account_dict_->get_root_extra();
  if (!(accounts_extra.write().advance(5) && total_balance_.validate_unpack(accounts_extra, 1024))) {
    LOG(ERROR) << "cannot unpack CurrencyCollection from the root of newly-split accounts dictionary";
    return td::Status::Error(
        -666, "error splitting total balance in account dictionary of shardchain state "s + id_.to_str());
  }
  LOG(DEBUG) << "split total balance from " << old_total_balance.to_str() << " to our share of "
             << total_balance_.to_str();
  // 6. adjust total_fees
  LOG(DEBUG) << "split total validator fees (current value is " << total_validator_fees_.to_str() << ")";
  total_validator_fees_.grams = (total_validator_fees_.grams + is_right_child(subshard)) >> 1;
  LOG(DEBUG) << "new total_validator_fees is " << total_validator_fees_.to_str();
  // NB: if total_fees_extra will be allowed to be non-empty, split it here too
  // 7. reset overload/underload history
  overload_history_ = underload_history_ = 0;
  // 999. anything else?
  id_.id.shard = subshard.shard;
  id_.file_hash.set_zero();
  id_.root_hash.set_zero();
  return td::Status::OK();
}

int filter_out_msg_queue(vm::AugmentedDictionary& out_queue, ton::ShardIdFull old_shard, ton::ShardIdFull subshard) {
  return out_queue.filter([subshard, old_shard](vm::CellSlice& cs, td::ConstBitPtr key, int key_len) -> int {
    CHECK(key_len == 352);
    LOG(DEBUG) << "scanning OutMsgQueue entry with key " << key.to_hex(key_len);
    block::tlb::MsgEnvelope::Record_std env;
    block::gen::CommonMsgInfo::Record_int_msg_info info;
    if (!(cs.size_ext() == 0x10080  // (uint64) enqueued_lt:uint64 out_msg:^MsgEnvelope
          && tlb::unpack_cell(cs.prefetch_ref(), env) && tlb::unpack_cell_inexact(env.msg, info))) {
      LOG(ERROR) << "cannot unpack OutMsgQueue entry with key " << key.to_hex(key_len);
      return -1;
    }
    auto src_prefix = block::tlb::t_MsgAddressInt.get_prefix(info.src);
    auto dest_prefix = block::tlb::t_MsgAddressInt.get_prefix(info.dest);
    auto cur_prefix = block::interpolate_addr(src_prefix, dest_prefix, env.cur_addr);
    if (!(src_prefix.is_valid() && dest_prefix.is_valid() && cur_prefix.is_valid())) {
      LOG(ERROR) << "OutMsgQueue message with key " << key.to_hex(key_len)
                 << " has invalid source or destination address";
      return -1;
    }
    if (!ton::shard_contains(old_shard, cur_prefix)) {
      LOG(ERROR) << "OutMsgQueue message with key " << key.to_hex(key_len)
                 << " does not contain current address belonging to shard " << old_shard.to_str();
      return -1;
    }
    return ton::shard_contains(subshard, cur_prefix);
  });
}

bool CurrencyCollection::validate(int max_cells) const {
  return is_valid() && td::sgn(grams) >= 0 && validate_extra(max_cells);
}

bool CurrencyCollection::validate_extra(int max_cells) const {
  if (extra.is_null()) {
    return true;
  }
  vm::CellBuilder cb;
  return cb.store_maybe_ref(extra) && block::tlb::t_ExtraCurrencyCollection.validate_ref(max_cells, cb.finalize());
}

bool CurrencyCollection::add(const CurrencyCollection& a, const CurrencyCollection& b, CurrencyCollection& c) {
  return (a.is_valid() && b.is_valid() && (c.grams = a.grams + b.grams).not_null() && c.grams->is_valid() &&
          add_extra_currency(a.extra, b.extra, c.extra)) ||
         c.invalidate();
}

bool CurrencyCollection::add(const CurrencyCollection& a, CurrencyCollection&& b, CurrencyCollection& c) {
  return (a.is_valid() && b.is_valid() && (c.grams = a.grams + std::move(b.grams)).not_null() && c.grams->is_valid() &&
          add_extra_currency(a.extra, std::move(b.extra), c.extra)) ||
         c.invalidate();
}

CurrencyCollection& CurrencyCollection::operator+=(const CurrencyCollection& other) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other.is_valid() && (grams += other.grams).not_null() && grams->is_valid() &&
        add_extra_currency(extra, other.extra, extra))) {
    invalidate();
  }
  return *this;
}

CurrencyCollection& CurrencyCollection::operator+=(CurrencyCollection&& other) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other.is_valid() && (grams += std::move(other.grams)).not_null() && grams->is_valid() &&
        add_extra_currency(extra, std::move(other.extra), extra))) {
    invalidate();
  }
  return *this;
}

CurrencyCollection& CurrencyCollection::operator+=(td::RefInt256 other_grams) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other_grams.not_null() && (grams += other_grams).not_null())) {
    invalidate();
  }
  return *this;
}

CurrencyCollection CurrencyCollection::operator+(const CurrencyCollection& other) const {
  CurrencyCollection res;
  add(*this, other, res);
  return res;
}

CurrencyCollection CurrencyCollection::operator+(CurrencyCollection&& other) const {
  CurrencyCollection res;
  add(*this, std::move(other), res);
  return res;
}

CurrencyCollection CurrencyCollection::operator+(td::RefInt256 other_grams) {
  if (!is_valid()) {
    return *this;
  }
  auto sum = grams + other_grams;
  if (sum.not_null()) {
    return CurrencyCollection{std::move(sum), extra};
  } else {
    return CurrencyCollection{};
  }
}

bool CurrencyCollection::sub(const CurrencyCollection& a, const CurrencyCollection& b, CurrencyCollection& c) {
  return (a.is_valid() && b.is_valid() && (c.grams = a.grams - b.grams).not_null() && c.grams->is_valid() &&
          td::sgn(c.grams) >= 0 && sub_extra_currency(a.extra, b.extra, c.extra)) ||
         c.invalidate();
}

bool CurrencyCollection::sub(const CurrencyCollection& a, CurrencyCollection&& b, CurrencyCollection& c) {
  return (a.is_valid() && b.is_valid() && (c.grams = a.grams - std::move(b.grams)).not_null() && c.grams->is_valid() &&
          td::sgn(c.grams) >= 0 && sub_extra_currency(a.extra, std::move(b.extra), c.extra)) ||
         c.invalidate();
}

CurrencyCollection& CurrencyCollection::operator-=(const CurrencyCollection& other) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other.is_valid() && (grams -= other.grams).not_null() && grams->is_valid() && td::sgn(grams) >= 0 &&
        sub_extra_currency(extra, other.extra, extra))) {
    invalidate();
  }
  return *this;
}

CurrencyCollection& CurrencyCollection::operator-=(CurrencyCollection&& other) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other.is_valid() && (grams -= std::move(other.grams)).not_null() && grams->is_valid() && td::sgn(grams) >= 0 &&
        sub_extra_currency(extra, std::move(other.extra), extra))) {
    invalidate();
  }
  return *this;
}

CurrencyCollection& CurrencyCollection::operator-=(td::RefInt256 other_grams) {
  if (!is_valid()) {
    return *this;
  }
  if (!(other_grams.not_null() && (grams -= other_grams).not_null() && td::sgn(grams) >= 0)) {
    invalidate();
  }
  return *this;
}

CurrencyCollection CurrencyCollection::operator-(const CurrencyCollection& other) const {
  CurrencyCollection res;
  sub(*this, other, res);
  return res;
}

CurrencyCollection CurrencyCollection::operator-(CurrencyCollection&& other) const {
  CurrencyCollection res;
  sub(*this, std::move(other), res);
  return res;
}

CurrencyCollection CurrencyCollection::operator-(td::RefInt256 other_grams) const {
  if (!(is_valid() && other_grams.not_null())) {
    return {};
  }
  auto x = grams - other_grams;
  if (td::sgn(x) >= 0) {
    return CurrencyCollection{std::move(x), extra};
  } else {
    return {};
  }
}

bool CurrencyCollection::operator==(const CurrencyCollection& other) const {
  return is_valid() && other.is_valid() && !td::cmp(grams, other.grams) &&
         (extra.not_null() == other.extra.not_null()) &&
         (extra.is_null() || extra->get_hash() == other.extra->get_hash());
}

bool CurrencyCollection::operator>=(const CurrencyCollection& other) const {
  Ref<vm::Cell> tmp;
  return is_valid() && other.is_valid() && td::cmp(grams, other.grams) >= 0 &&
         sub_extra_currency(extra, other.extra, tmp);
}

bool CurrencyCollection::store(vm::CellBuilder& cb) const {
  return is_valid() && store_CurrencyCollection(cb, grams, extra);
}

bool CurrencyCollection::store_or_zero(vm::CellBuilder& cb) const {
  return is_valid() ? store(cb) : cb.store_long_bool(0, 5);
}

bool CurrencyCollection::fetch(vm::CellSlice& cs) {
  return block::tlb::t_CurrencyCollection.unpack_special(cs, *this, true) || invalidate();
}

bool CurrencyCollection::fetch_exact(vm::CellSlice& cs) {
  return block::tlb::t_CurrencyCollection.unpack_special(cs, *this, false) || invalidate();
}

bool CurrencyCollection::unpack(Ref<vm::CellSlice> csr) {
  return unpack_CurrencyCollection(std::move(csr), grams, extra) || invalidate();
}

bool CurrencyCollection::validate_unpack(Ref<vm::CellSlice> csr, int max_cells) {
  return (csr.not_null() && block::tlb::t_CurrencyCollection.validate_upto(max_cells, *csr) &&
          unpack_CurrencyCollection(std::move(csr), grams, extra)) ||
         invalidate();
}

Ref<vm::CellSlice> CurrencyCollection::pack() const {
  vm::CellBuilder cb;
  if (store(cb)) {
    return vm::load_cell_slice_ref(cb.finalize());
  } else {
    return {};
  }
}

bool CurrencyCollection::show(std::ostream& os) const {
  if (!is_valid()) {
    os << "<invalid-cc>";
    return false;
  }
  if (extra.not_null()) {
    os << '(';
  }
  os << grams << "ng";
  if (extra.not_null()) {
    vm::Dictionary dict{extra, 32};
    if (!dict.check_for_each([&os](Ref<vm::CellSlice> csr, td::ConstBitPtr key, int n) {
          CHECK(n == 32);
          int x = (int)key.get_int(n);
          auto val = block::tlb::t_VarUIntegerPos_32.as_integer_skip(csr.write());
          if (val.is_null() || !csr->empty_ext()) {
            os << "+<invalid>.$" << x << "...)";
            return false;
          }
          os << '+' << val << ".$" << x;
          return true;
        })) {
      return false;
    }
    os << ')';
  }
  return true;
}

std::string CurrencyCollection::to_str() const {
  std::ostringstream os;
  show(os);
  return os.str();
}

std::ostream& operator<<(std::ostream& os, const CurrencyCollection& cc) {
  cc.show(os);
  return os;
}

bool ValueFlow::set_zero() {
  return from_prev_blk.set_zero() && to_next_blk.set_zero() && imported.set_zero() && exported.set_zero() &&
         fees_collected.set_zero() && fees_imported.set_zero() && recovered.set_zero() && created.set_zero() &&
         minted.set_zero();
}

bool ValueFlow::validate() const {
  return is_valid() && from_prev_blk + imported + fees_imported + created + minted + recovered ==
                           to_next_blk + exported + fees_collected;
}

bool ValueFlow::store(vm::CellBuilder& cb) const {
  vm::CellBuilder cb2;
  return cb.store_long_bool(block::gen::ValueFlow::cons_tag[0], 32)  // value_flow ^[
         && from_prev_blk.store(cb2)                                 //   from_prev_blk:CurrencyCollection
         && to_next_blk.store(cb2)                                   //   to_next_blk:CurrencyCollection
         && imported.store(cb2)                                      //   imported:CurrencyCollection
         && exported.store(cb2)                                      //   exported:CurrencyCollection
         && cb.store_ref_bool(cb2.finalize())                        // ]
         && fees_collected.store(cb)                                 // fees_collected:CurrencyCollection
         && fees_imported.store(cb2)                                 // ^[ fees_imported:CurrencyCollection
         && recovered.store(cb2)                                     //    recovered:CurrencyCollection
         && created.store(cb2)                                       //    created:CurrencyCollection
         && minted.store(cb2)                                        //    minted:CurrencyCollection
         && cb.store_ref_bool(cb2.finalize());                       // ] = ValueFlow;
}

bool ValueFlow::fetch(vm::CellSlice& cs) {
  block::gen::ValueFlow::Record f;
  if (!(tlb::unpack(cs, f) && from_prev_blk.validate_unpack(std::move(f.r1.from_prev_blk)) &&
        to_next_blk.validate_unpack(std::move(f.r1.to_next_blk)) &&
        imported.validate_unpack(std::move(f.r1.imported)) && exported.validate_unpack(std::move(f.r1.exported)) &&
        fees_collected.validate_unpack(std::move(f.fees_collected)) &&
        fees_imported.validate_unpack(std::move(f.r2.fees_imported)) &&
        recovered.validate_unpack(std::move(f.r2.recovered)) && created.validate_unpack(std::move(f.r2.created)) &&
        minted.validate_unpack(std::move(f.r2.minted)))) {
    return invalidate();
  }
  return true;
}

bool ValueFlow::unpack(Ref<vm::CellSlice> csr) {
  return (csr.not_null() && fetch(csr.write()) && csr->empty_ext()) || invalidate();
}

static inline bool say(std::ostream& os, const char* str) {
  os << str;
  return true;
}

bool ValueFlow::show_one(std::ostream& os, const char* str, const CurrencyCollection& cc) const {
  return say(os, str) && cc.show(os);
}

bool ValueFlow::show(std::ostream& os) const {
  if (!is_valid()) {
    os << "<invalid-value-flow>";
    return false;
  }
  return (say(os, "(value-flow ") && show_one(os, "from_prev_blk:", from_prev_blk) &&
          show_one(os, " to_next_blk:", to_next_blk) && show_one(os, " imported:", imported) &&
          show_one(os, " exported:", exported) && show_one(os, " fees_collected:", fees_collected) &&
          show_one(os, " fees_imported:", fees_imported) && show_one(os, " recovered:", recovered) &&
          show_one(os, " created:", created) && show_one(os, " minted:", minted) && say(os, ")")) ||
         (say(os, "...<invalid-value-flow>)") && false);
}

std::string ValueFlow::to_str() const {
  std::ostringstream os;
  show(os);
  return os.str();
}

std::ostream& operator<<(std::ostream& os, const ValueFlow& vflow) {
  vflow.show(os);
  return os;
}

bool DiscountedCounter::increase_by(unsigned count, ton::UnixTime now) {
  if (!validate()) {
    return false;
  }
  td::uint64 scaled = (td::uint64(count) << 32);
  if (!total) {
    last_updated = now;
    total = count;
    cnt2048 = scaled;
    cnt65536 = scaled;
    return true;
  }
  if (count > ~total || cnt2048 > ~scaled || cnt65536 > ~scaled) {
    return false /* invalidate() */;  // overflow
  }
  unsigned dt = (now >= last_updated ? now - last_updated : 0);
  if (dt > 0) {
    // more precise version of cnt2048 = llround(cnt2048 * exp(-dt / 2048.));
    // (rounding error has absolute value < 1)
    cnt2048 = (dt >= 48 * 2048 ? 0 : td::umulnexps32(cnt2048, dt << 5));
    // more precise version of cnt65536 = llround(cnt65536 * exp(-dt / 65536.));
    // (rounding error has absolute value < 1)
    cnt65536 = td::umulnexps32(cnt65536, dt);
  }
  total += count;
  cnt2048 += scaled;
  cnt65536 += scaled;
  last_updated = now;
  return true;
}

bool DiscountedCounter::validate() {
  if (!is_valid()) {
    return false;
  }
  if (!total) {
    if (cnt2048 | cnt65536) {
      return invalidate();
    }
  } else if (!last_updated) {
    return invalidate();
  }
  return true;
}

bool DiscountedCounter::fetch(vm::CellSlice& cs) {
  valid = (cs.fetch_uint_to(32, last_updated) && cs.fetch_uint_to(64, total) && cs.fetch_uint_to(64, cnt2048) &&
           cs.fetch_uint_to(64, cnt65536));
  return validate() || invalidate();
}

bool DiscountedCounter::unpack(Ref<vm::CellSlice> csr) {
  return (csr.not_null() && fetch(csr.write()) && csr->empty_ext()) || invalidate();
}

bool DiscountedCounter::store(vm::CellBuilder& cb) const {
  return is_valid() && cb.store_long_bool(last_updated, 32) && cb.store_long_bool(total, 64) &&
         cb.store_long_bool(cnt2048, 64) && cb.store_long_bool(cnt65536, 64);
}

Ref<vm::CellSlice> DiscountedCounter::pack() const {
  vm::CellBuilder cb;
  if (store(cb)) {
    return vm::load_cell_slice_ref(cb.finalize());
  } else {
    return {};
  }
}

bool DiscountedCounter::show(std::ostream& os) const {
  if (!is_valid()) {
    os << "<invalid-counter>";
    return false;
  }
  os << "(counter last_updated:" << last_updated << " total:" << total << " cnt2048: " << (double)cnt2048 / (1LL << 32)
     << " cnt65536: " << (double)cnt65536 / (1LL << 32) << ")";
  return true;
}

std::string DiscountedCounter::to_str() const {
  std::ostringstream stream;
  if (show(stream)) {
    return stream.str();
  } else {
    return "<invalid-counter>";
  }
}

bool fetch_CreatorStats(vm::CellSlice& cs, DiscountedCounter& mc_cnt, DiscountedCounter& shard_cnt) {
  return cs.fetch_ulong(4) == 4   // creator_info#4
         && mc_cnt.fetch(cs)      // mc_blocks:Counters
         && shard_cnt.fetch(cs);  // shard_blocks:Counters
}

bool store_CreatorStats(vm::CellBuilder& cb, const DiscountedCounter& mc_cnt, const DiscountedCounter& shard_cnt) {
  return cb.store_long_bool(4, 4)  // creator_info#4
         && mc_cnt.store(cb)       // mc_blocks:Counters
         && shard_cnt.store(cb);   // shard_blocks:Counters
}

bool unpack_CreatorStats(Ref<vm::CellSlice> cs, DiscountedCounter& mc_cnt, DiscountedCounter& shard_cnt) {
  if (cs.is_null()) {
    return mc_cnt.set_zero() && shard_cnt.set_zero();
  } else {
    return fetch_CreatorStats(cs.write(), mc_cnt, shard_cnt) && cs->empty_ext();
  }
}

/*
 *
 *    Monte Carlo simulator for computing the share of shardchain blocks generated by each validator
 *
 */

bool MtCarloComputeShare::compute() {
  ok = false;
  if (W.size() >= (1U << 31) || W.empty()) {
    return false;
  }
  K = std::min(K, N);
  if (K <= 0 || iterations <= 0) {
    return false;
  }
  double tot_weight = 0., acc = 0.;
  for (int i = 0; i < N; i++) {
    if (W[i] <= 0.) {
      return false;
    }
    tot_weight += W[i];
  }
  CW.resize(N);
  RW.resize(N);
  for (int i = 0; i < N; i++) {
    CW[i] = acc;
    acc += W[i] /= tot_weight;
    RW[i] = 0.;
  }
  R0 = 0.;
  H.resize(N);
  A.resize(K);
  for (long long it = 0; it < iterations; ++it) {
    gen_vset();
  }
  for (int i = 0; i < N; i++) {
    RW[i] = W[i] * (RW[i] + R0) / (double)iterations;
  }
  return ok = true;
}

void MtCarloComputeShare::gen_vset() {
  double total_wt = 1.;
  int hc = 0;
  for (int i = 0; i < K; i++) {
    CHECK(total_wt > 0);
    double inv_wt = 1. / total_wt;
    R0 += inv_wt;
    for (int j = 0; j < i; j++) {
      RW[A[j]] -= inv_wt;
    }
    // double p = drand48() * total_wt;
    double p = (double)td::Random::fast_uint64() * total_wt / (1. * (1LL << 32) * (1LL << 32));
    for (int h = 0; h < hc; h++) {
      if (p < H[h].first) {
        break;
      }
      p += H[h].second;
    }
    int a = -1, b = N, c;
    while (b - a > 1) {
      c = ((a + b) >> 1);
      if (CW[c] <= p) {
        a = c;
      } else {
        b = c;
      }
    }
    CHECK(a >= 0 && a < N);
    CHECK(total_wt >= W[a]);
    total_wt -= W[a];
    double x = CW[a];
    c = hc++;
    while (c > 0 && H[c - 1].first > x) {
      H[c] = H[c - 1];
      --c;
    }
    H[c].first = x;
    H[c].second = W[a];
    A[i] = a;
  }
}

/*
 * 
 *    Other block-related functions
 * 
 */

bool store_UInt7(vm::CellBuilder& cb, unsigned long long value) {
  return block::tlb::t_VarUInteger_7.store_long(cb, (long long)value);
}

bool store_UInt7(vm::CellBuilder& cb, unsigned long long value1, unsigned long long value2) {
  return store_UInt7(cb, value1) && store_UInt7(cb, value2);
}

bool store_Maybe_Grams(vm::CellBuilder& cb, td::RefInt256 value) {
  if (value.is_null()) {
    return cb.store_long_bool(0, 1);
  } else {
    return cb.store_long_bool(1, 1) && block::tlb::t_Grams.store_integer_ref(cb, std::move(value));
  }
}

bool store_Maybe_Grams_nz(vm::CellBuilder& cb, td::RefInt256 value) {
  if (value.is_null() || !value->sgn()) {
    return cb.store_long_bool(0, 1);
  } else {
    return cb.store_long_bool(1, 1) && block::tlb::t_Grams.store_integer_ref(cb, std::move(value));
  }
}

bool store_CurrencyCollection(vm::CellBuilder& cb, td::RefInt256 value, Ref<vm::Cell> extra) {
  return block::tlb::t_CurrencyCollection.pack_special(cb, std::move(value), std::move(extra));
}

bool fetch_CurrencyCollection(vm::CellSlice& cs, td::RefInt256& value, Ref<vm::Cell>& extra, bool inexact) {
  return block::tlb::t_CurrencyCollection.unpack_special(cs, value, extra, inexact);
}

bool unpack_CurrencyCollection(Ref<vm::CellSlice> csr, td::RefInt256& value, Ref<vm::Cell>& extra) {
  if (csr.is_null()) {
    return false;
  } else if (csr->is_unique()) {
    return block::tlb::t_CurrencyCollection.unpack_special(csr.write(), value, extra);
  } else {
    vm::CellSlice cs{*csr};
    return block::tlb::t_CurrencyCollection.unpack_special(cs, value, extra);
  }
}

bool check_one_library(Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) {
  assert(n == 256);
  if (cs_ref->size_ext() != 0x10001) {
    return false;
  }
  Ref<vm::Cell> cell = cs_ref->prefetch_ref();
  const auto& cell_hash = cell->get_hash();
  return !td::bitstring::bits_memcmp(cell_hash.bits(), key, n);
}

bool valid_library_collection(Ref<vm::Cell> cell, bool catch_errors) {
  if (cell.is_null()) {
    return true;
  }
  if (!catch_errors) {
    vm::Dictionary dict{std::move(cell), 256};
    return dict.check_for_each(check_one_library);
  }
  try {
    vm::Dictionary dict{std::move(cell), 256};
    return dict.check_for_each(check_one_library);
  } catch (vm::VmError&) {
    return false;
  }
}

bool check_one_config_param(Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, td::ConstBitPtr addr, bool relax_par0) {
  if (cs_ref->size_ext() != 0x10000) {
    return false;
  }
  Ref<vm::Cell> cell = cs_ref->prefetch_ref();
  int idx = (int)key.get_int(32);
  if (!idx) {
    auto cs = load_cell_slice(std::move(cell));
    return cs.size_ext() == 256 && (relax_par0 || cs.fetch_bits(256) == addr);
  } else if (idx < 0) {
    return true;
  }
  bool ok = block::gen::ConfigParam{idx}.validate_ref(1024, std::move(cell));
  if (!ok) {
    LOG(ERROR) << "configuration parameter #" << idx << " is invalid";
  }
  return ok;
}

const int mandatory_config_params[] = {18, 20, 21, 22, 23, 24, 25, 28, 34};

bool valid_config_data(Ref<vm::Cell> cell, const td::BitArray<256>& addr, bool catch_errors, bool relax_par0,
                       Ref<vm::Cell> old_mparams) {
  using namespace std::placeholders;
  if (cell.is_null()) {
    return false;
  }
  if (catch_errors) {
    try {
      return valid_config_data(std::move(cell), addr, false, relax_par0, std::move(old_mparams));
    } catch (vm::VmError&) {
      return false;
    }
  }
  vm::Dictionary dict{std::move(cell), 32};
  if (!dict.check_for_each(std::bind(check_one_config_param, _1, _2, addr.cbits(), relax_par0))) {
    return false;
  }
  for (int x : mandatory_config_params) {
    if (!dict.int_key_exists(x)) {
      LOG(ERROR) << "mandatory configuration parameter #" << x << " is missing";
      return false;
    }
  }
  return config_params_present(dict, dict.lookup_ref(td::BitArray<32>{9})) &&
         config_params_present(dict, std::move(old_mparams));
}

bool config_params_present(vm::Dictionary& dict, Ref<vm::Cell> param_dict_root) {
  auto res = block::Config::unpack_param_dict(std::move(param_dict_root));
  if (res.is_error()) {
    LOG(ERROR)
        << "invalid mandatory parameters dictionary while checking existence of all mandatory configuration parameters";
    return false;
  }
  for (int x : res.move_as_ok()) {
    // LOG(DEBUG) << "checking whether mandatory configuration parameter #" << x << " exists";
    if (!dict.int_key_exists(x)) {
      LOG(ERROR) << "configuration parameter #" << x
                 << " (declared as mandatory in configuration parameter #9) is missing";
      return false;
    }
  }
  // LOG(DEBUG) << "all mandatory configuration parameters present";
  return true;
}

bool add_extra_currency(Ref<vm::Cell> extra1, Ref<vm::Cell> extra2, Ref<vm::Cell>& res) {
  if (extra2.is_null()) {
    res = extra1;
    return true;
  } else if (extra1.is_null()) {
    res = extra2;
    return true;
  } else {
    return block::tlb::t_ExtraCurrencyCollection.add_values_ref(res, std::move(extra1), std::move(extra2));
  }
}

bool sub_extra_currency(Ref<vm::Cell> extra1, Ref<vm::Cell> extra2, Ref<vm::Cell>& res) {
  if (extra2.is_null()) {
    res = extra1;
    return true;
  } else if (extra1.is_null()) {
    res.clear();
    return false;
  } else {
    return block::tlb::t_ExtraCurrencyCollection.sub_values_ref(res, std::move(extra1), std::move(extra2)) >= 0;
  }
}

// combine d bits from dest, remaining 64 - d bits from src
ton::AccountIdPrefixFull interpolate_addr(const ton::AccountIdPrefixFull& src, const ton::AccountIdPrefixFull& dest,
                                          int d) {
  if (d <= 0) {
    return src;
  } else if (d >= 96) {
    return dest;
  } else if (d >= 32) {
    unsigned long long mask = (std::numeric_limits<td::uint64>::max() >> (d - 32));
    return ton::AccountIdPrefixFull{dest.workchain, (dest.account_id_prefix & ~mask) | (src.account_id_prefix & mask)};
  } else {
    int mask = (int)(~0U >> d);
    return ton::AccountIdPrefixFull{(dest.workchain & ~mask) | (src.workchain & mask), src.account_id_prefix};
  }
}

bool interpolate_addr_to(const ton::AccountIdPrefixFull& src, const ton::AccountIdPrefixFull& dest, int d,
                         ton::AccountIdPrefixFull& res) {
  res = interpolate_addr(src, dest, d);
  return true;
}

// result: (transit_addr_dest_bits, nh_addr_dest_bits)
std::pair<int, int> perform_hypercube_routing(ton::AccountIdPrefixFull src, ton::AccountIdPrefixFull dest,
                                              ton::ShardIdFull cur, int used_dest_bits) {
  ton::AccountIdPrefixFull transit = interpolate_addr(src, dest, used_dest_bits);
  if (!ton::shard_contains(cur, transit)) {
    return {-1, -1};
  }
  if (ton::shard_contains(cur, dest)) {
    // if destination is in this shard, set cur:=next_hop:=dest
    return {96, 96};
  }
  if (transit.workchain == ton::masterchainId || dest.workchain == ton::masterchainId) {
    return {used_dest_bits, 96};  // route messages to/from masterchain directly
  }
  if (transit.workchain != dest.workchain) {
    return {used_dest_bits, 32};
  }
  unsigned long long x = cur.shard & (cur.shard - 1), y = cur.shard | (cur.shard - 1);
  unsigned long long t = transit.account_id_prefix, q = dest.account_id_prefix ^ t;
  int i = (td::count_leading_zeroes64(q) & -4);  // top i bits match, next 4 bits differ
  unsigned long long m = (std::numeric_limits<td::uint64>::max() >> i), h;
  do {
    m >>= 4;
    h = t ^ (q & ~m);
    i += 4;
  } while (h >= x && h <= y);
  return {28 + i, 32 + i};
}

bool compute_out_msg_queue_key(Ref<vm::Cell> msg_env, td::BitArray<352>& key) {
  block::tlb::MsgEnvelope::Record_std env;
  block::gen::CommonMsgInfo::Record_int_msg_info info;
  if (!(tlb::unpack_cell(msg_env, env) && tlb::unpack_cell_inexact(env.msg, info))) {
    return false;
  }
  auto src_prefix = block::tlb::t_MsgAddressInt.get_prefix(std::move(info.src));
  auto dest_prefix = block::tlb::t_MsgAddressInt.get_prefix(std::move(info.dest));
  auto next_hop = interpolate_addr(src_prefix, dest_prefix, env.next_addr);
  key.bits().store_int(next_hop.workchain, 32);
  (key.bits() + 32).store_int(next_hop.account_id_prefix, 64);
  (key.bits() + 96).copy_from(env.msg->get_hash().bits(), 256);
  return true;
}

bool unpack_block_prev_blk(Ref<vm::Cell> block_root, const ton::BlockIdExt& id, std::vector<ton::BlockIdExt>& prev,
                           ton::BlockIdExt& mc_blkid, bool& after_split, ton::BlockIdExt* fetch_blkid) {
  return unpack_block_prev_blk_ext(std::move(block_root), id, prev, mc_blkid, after_split, fetch_blkid).is_ok();
}

td::Status unpack_block_prev_blk_try(Ref<vm::Cell> block_root, const ton::BlockIdExt& id,
                                     std::vector<ton::BlockIdExt>& prev, ton::BlockIdExt& mc_blkid, bool& after_split,
                                     ton::BlockIdExt* fetch_blkid) {
  try {
    return unpack_block_prev_blk_ext(std::move(block_root), id, prev, mc_blkid, after_split, fetch_blkid);
  } catch (vm::VmError err) {
    return td::Status::Error(std::string{"error while processing Merkle proof: "} + err.get_msg());
  } catch (vm::VmVirtError err) {
    return td::Status::Error(std::string{"error while processing Merkle proof: "} + err.get_msg());
  }
}

td::Status unpack_block_prev_blk_ext(Ref<vm::Cell> block_root, const ton::BlockIdExt& id,
                                     std::vector<ton::BlockIdExt>& prev, ton::BlockIdExt& mc_blkid, bool& after_split,
                                     ton::BlockIdExt* fetch_blkid) {
  block::gen::Block::Record blk;
  block::gen::BlockInfo::Record info;
  block::gen::ExtBlkRef::Record mcref;  // _ ExtBlkRef = BlkMasterInfo;
  ton::ShardIdFull shard;
  if (!(tlb::unpack_cell(block_root, blk) && tlb::unpack_cell(blk.info, info) && !info.version &&
        block::tlb::t_ShardIdent.unpack(info.shard.write(), shard) &&
        (!info.not_master || tlb::unpack_cell(info.master_ref, mcref)))) {
    return td::Status::Error("cannot unpack block header");
  }
  if (fetch_blkid) {
    fetch_blkid->id = ton::BlockId{shard, (unsigned)info.seq_no};
    fetch_blkid->root_hash = block_root->get_hash().bits();
    fetch_blkid->file_hash.clear();
  } else {
    ton::BlockId hdr_id{shard, (unsigned)info.seq_no};
    if (id.id != hdr_id) {
      return td::Status::Error("block header contains block id "s + hdr_id.to_str() + ", expected " + id.id.to_str());
    }
    if (id.root_hash != block_root->get_hash().bits()) {
      return td::Status::Error("block header has incorrect root hash "s + block_root->get_hash().bits().to_hex(256) +
                               " instead of expected " + id.root_hash.to_hex());
    }
  }
  if (info.not_master != !shard.is_masterchain()) {
    return td::Status::Error("block has invalid not_master flag in its (Merkelized) header");
  }
  after_split = info.after_split;
  block::gen::ExtBlkRef::Record prev1, prev2;
  if (info.after_merge) {
    auto cs = vm::load_cell_slice(std::move(info.prev_ref));
    CHECK(cs.size_ext() == 0x20000);  // prev_blks_info$_ prev1:^ExtBlkRef prev2:^ExtBlkRef = BlkPrevInfo 1;
    if (!(tlb::unpack_cell(cs.prefetch_ref(0), prev1) && tlb::unpack_cell(cs.prefetch_ref(1), prev2))) {
      return td::Status::Error("cannot unpack two previous block references from block header");
    }
  } else {
    // prev_blk_info$_ prev:ExtBlkRef = BlkPrevInfo 0;
    if (!(tlb::unpack_cell(std::move(info.prev_ref), prev1))) {
      return td::Status::Error("cannot unpack previous block reference from block header");
    }
  }
  prev.clear();
  ton::BlockSeqno prev_seqno = prev1.seq_no;
  if (!info.after_merge) {
    prev.emplace_back(shard.workchain, info.after_split ? ton::shard_parent(shard.shard) : shard.shard, prev1.seq_no,
                      prev1.root_hash, prev1.file_hash);
    if (info.after_split && !prev1.seq_no) {
      return td::Status::Error("shardchains cannot be split immediately after initial state");
    }
  } else {
    if (info.after_split) {
      return td::Status::Error("shardchains cannot be simultaneously split and merged at the same block");
    }
    prev.emplace_back(shard.workchain, ton::shard_child(shard.shard, true), prev1.seq_no, prev1.root_hash,
                      prev1.file_hash);
    prev.emplace_back(shard.workchain, ton::shard_child(shard.shard, false), prev2.seq_no, prev2.root_hash,
                      prev2.file_hash);
    prev_seqno = std::max<unsigned>(prev1.seq_no, prev2.seq_no);
    if (!prev1.seq_no || !prev2.seq_no) {
      return td::Status::Error("shardchains cannot be merged immediately after initial state");
    }
  }
  if (id.id.seqno != prev_seqno + 1) {
    return td::Status::Error("new block has invalid seqno (not equal to one plus maximum of seqnos of its ancestors)");
  }
  if (shard.is_masterchain()) {
    mc_blkid = prev.at(0);
  } else {
    mc_blkid = ton::BlockIdExt{ton::masterchainId, ton::shardIdAll, mcref.seq_no, mcref.root_hash, mcref.file_hash};
  }
  if (shard.is_masterchain() && info.vert_seqno_incr && !info.key_block) {
    return td::Status::Error("non-key masterchain block cannot have vert_seqno_incr set");
  }
  return td::Status::OK();
}

td::Status check_block_header(Ref<vm::Cell> block_root, const ton::BlockIdExt& id, ton::Bits256* store_shard_hash_to) {
  block::gen::Block::Record blk;
  block::gen::BlockInfo::Record info;
  ton::ShardIdFull shard;
  if (!(tlb::unpack_cell(block_root, blk) && tlb::unpack_cell(blk.info, info) && !info.version &&
        block::tlb::t_ShardIdent.unpack(info.shard.write(), shard))) {
    return td::Status::Error("cannot unpack block header");
  }
  ton::BlockId hdr_id{shard, (unsigned)info.seq_no};
  if (id.id != hdr_id) {
    return td::Status::Error("block header contains block id "s + hdr_id.to_str() + ", expected " + id.id.to_str());
  }
  if (id.root_hash != block_root->get_hash().bits()) {
    return td::Status::Error("block header has incorrect root hash "s + block_root->get_hash().bits().to_hex(256) +
                             " instead of expected " + id.root_hash.to_hex());
  }
  if (info.not_master != !shard.is_masterchain()) {
    return td::Status::Error("block has invalid not_master flag in its (Merkelized) header");
  }
  if (store_shard_hash_to) {
    vm::CellSlice upd_cs{vm::NoVmSpec(), blk.state_update};
    if (!(upd_cs.is_special() && upd_cs.prefetch_long(8) == 4  // merkle update
          && upd_cs.size_ext() == 0x20228)) {
      return td::Status::Error("invalid Merkle update in block header");
    }
    auto upd_hash = upd_cs.prefetch_ref(1)->get_hash(0);
    *store_shard_hash_to = upd_hash.bits();
  }
  return td::Status::OK();
}

std::unique_ptr<vm::Dictionary> get_block_create_stats_dict(Ref<vm::Cell> state_root) {
  block::gen::ShardStateUnsplit::Record info;
  block::gen::McStateExtra::Record extra;
  block::gen::BlockCreateStats::Record_block_create_stats cstats;
  if (!(::tlb::unpack_cell(std::move(state_root), info) && info.custom->size_refs() &&
        ::tlb::unpack_cell(info.custom->prefetch_ref(), extra) && (extra.r1.flags & 1) &&
        ::tlb::csr_unpack(std::move(extra.r1.block_create_stats), cstats))) {
    return {};
  }
  return std::make_unique<vm::Dictionary>(std::move(cstats.counters), 256);
}

std::unique_ptr<vm::AugmentedDictionary> get_prev_blocks_dict(Ref<vm::Cell> state_root) {
  block::gen::ShardStateUnsplit::Record info;
  block::gen::McStateExtra::Record extra_info;
  if (!(::tlb::unpack_cell(std::move(state_root), info) && info.custom->size_refs() &&
        ::tlb::unpack_cell(info.custom->prefetch_ref(), extra_info))) {
    return {};
  }
  return std::make_unique<vm::AugmentedDictionary>(extra_info.r1.prev_blocks, 32, block::tlb::aug_OldMcBlocksInfo);
}

bool get_old_mc_block_id(vm::AugmentedDictionary* prev_blocks_dict, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                         ton::LogicalTime* end_lt) {
  return prev_blocks_dict && get_old_mc_block_id(*prev_blocks_dict, seqno, blkid, end_lt);
}

bool get_old_mc_block_id(vm::AugmentedDictionary& prev_blocks_dict, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                         ton::LogicalTime* end_lt) {
  return unpack_old_mc_block_id(prev_blocks_dict.lookup(td::BitArray<32>{seqno}), seqno, blkid, end_lt);
}

bool unpack_old_mc_block_id(Ref<vm::CellSlice> old_blk_info, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                            ton::LogicalTime* end_lt) {
  return old_blk_info.not_null() && old_blk_info.write().advance(1) &&
         block::tlb::t_ExtBlkRef.unpack(std::move(old_blk_info), blkid, end_lt) && blkid.seqno() == seqno;
}

bool check_old_mc_block_id(vm::AugmentedDictionary* prev_blocks_dict, const ton::BlockIdExt& blkid) {
  return prev_blocks_dict && check_old_mc_block_id(*prev_blocks_dict, blkid);
}

bool check_old_mc_block_id(vm::AugmentedDictionary& prev_blocks_dict, const ton::BlockIdExt& blkid) {
  if (!blkid.id.is_masterchain_ext()) {
    return false;
  }
  ton::BlockIdExt old_blkid;
  return unpack_old_mc_block_id(prev_blocks_dict.lookup(td::BitArray<32>{blkid.id.seqno}), blkid.id.seqno, old_blkid) &&
         old_blkid == blkid;
}

td::Result<Ref<vm::Cell>> get_block_transaction(Ref<vm::Cell> block_root, ton::WorkchainId workchain,
                                                const ton::StdSmcAddress& addr, ton::LogicalTime lt) {
  block::gen::Block::Record block;
  block::gen::BlockInfo::Record info;
  if (!(tlb::unpack_cell(std::move(block_root), block) && tlb::unpack_cell(std::move(block.info), info))) {
    return td::Status::Error("cannot unpack block header");
  }
  Ref<vm::Cell> trans_root;
  if (lt > info.start_lt && lt < info.end_lt) {
    // lt belongs to this block
    block::gen::BlockExtra::Record extra;
    if (!(tlb::unpack_cell(block.extra, extra))) {
      return td::Status::Error("cannot unpack block extra information");
    }
    vm::AugmentedDictionary account_blocks_dict{vm::load_cell_slice_ref(extra.account_blocks), 256,
                                                block::tlb::aug_ShardAccountBlocks};
    auto ab_csr = account_blocks_dict.lookup(addr);
    if (ab_csr.not_null()) {
      // account block for this account exists
      block::gen::AccountBlock::Record acc_block;
      if (!(tlb::csr_unpack(std::move(ab_csr), acc_block) && acc_block.account_addr == addr)) {
        return td::Status::Error("cannot unpack AccountBlock");
      }
      vm::AugmentedDictionary trans_dict{vm::DictNonEmpty(), acc_block.transactions, 64,
                                         block::tlb::aug_AccountTransactions};
      return trans_dict.lookup_ref(td::BitArray<64>{static_cast<long long>(lt)});
    }
  }
  return Ref<vm::Cell>{};
}

td::Result<Ref<vm::Cell>> get_block_transaction_try(Ref<vm::Cell> block_root, ton::WorkchainId workchain,
                                                    const ton::StdSmcAddress& addr, ton::LogicalTime lt) {
  try {
    return get_block_transaction(std::move(block_root), workchain, addr, lt);
  } catch (vm::VmError err) {
    return td::Status::Error(std::string{"error while extracting transaction from block : "} + err.get_msg());
  } catch (vm::VmVirtError err) {
    return td::Status::Error(std::string{"virtualization error while traversing transaction proof : "} + err.get_msg());
  }
}

bool get_transaction_in_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell>& in_msg) {
  block::gen::Transaction::Record trans;
  if (!tlb::unpack_cell(std::move(trans_ref), trans)) {
    return false;
  } else {
    in_msg = trans.r1.in_msg->prefetch_ref();
    return true;
  }
}

bool is_transaction_in_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell> msg) {
  Ref<vm::Cell> imsg;
  return get_transaction_in_msg(std::move(trans_ref), imsg) && imsg.not_null() == msg.not_null() &&
         (imsg.is_null() || imsg->get_hash() == msg->get_hash());
}

bool is_transaction_out_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell> msg) {
  block::gen::Transaction::Record trans;
  vm::CellSlice cs;
  unsigned long long created_lt;
  if (!(trans_ref.not_null() && msg.not_null() && tlb::unpack_cell(std::move(trans_ref), trans) && cs.load_ord(msg) &&
        block::tlb::t_CommonMsgInfo.get_created_lt(cs, created_lt))) {
    return false;
  }
  if (created_lt <= trans.lt || created_lt > trans.lt + trans.outmsg_cnt) {
    return false;
  }
  try {
    auto o_msg =
        vm::Dictionary{trans.r1.out_msgs, 15}.lookup_ref(td::BitArray<15>{(long long)(created_lt - trans.lt - 1)});
    return o_msg.not_null() && o_msg->get_hash() == msg->get_hash();
  } catch (vm::VmError&) {
    return false;
  }
}

// transaction$0111 account_addr:bits256 lt:uint64 ...
bool get_transaction_id(Ref<vm::Cell> trans_ref, ton::StdSmcAddress& account_addr, ton::LogicalTime& lt) {
  if (trans_ref.is_null()) {
    return false;
  }
  vm::CellSlice cs{vm::NoVmOrd(), trans_ref};
  return cs.fetch_ulong(4) == 7             // transaction$0111
         && cs.fetch_bits_to(account_addr)  // account_addr:bits256
         && cs.fetch_uint_to(64, lt);       // lt:uint64
}

bool get_transaction_owner(Ref<vm::Cell> trans_ref, ton::StdSmcAddress& addr) {
  ton::LogicalTime lt;
  return get_transaction_id(std::move(trans_ref), addr, lt);
}

td::uint32 compute_validator_set_hash(ton::CatchainSeqno cc_seqno, ton::ShardIdFull from,
                                      const std::vector<ton::ValidatorDescr>& nodes) {
  /*
  std::vector<tl_object_ptr<ton_api::test0_validatorSetItem>> s_vec;

  for (auto& n : nodes) {
    auto id = ValidatorFullId{n.key}.short_id();
    s_vec.emplace_back(create_tl_object<ton_api::test0_validatorSetItem>(id, n.weight));
  }

  auto obj = create_tl_object<ton_api::test0_validatorSet>(cc_seqno, std::move(s_vec));
  auto B = serialize_tl_object(obj, true);
  return td::crc32c(B.as_slice());
  */
  CHECK(nodes.size() <= 0xffffffff);
  auto tot_size = 1 + 1 + 1 + nodes.size() * (8 + 2 + 8);
  auto buff = std::make_unique<td::uint32[]>(tot_size);
  td::TlStorerUnsafe storer(reinterpret_cast<unsigned char*>(buff.get()));
  auto* begin = storer.get_buf();
  storer.store_int(-1877581587);  // magic inherited from test0.validatorSet
  storer.store_int(cc_seqno);
  storer.store_binary((td::uint32)nodes.size());
  for (auto& n : nodes) {
    storer.store_binary(n.key.as_bits256());
    storer.store_long(n.weight);
    storer.store_binary(n.addr);
  }
  auto* end = storer.get_buf();
  CHECK(static_cast<size_t>(end - begin) == 4 * tot_size);
  return td::crc32c(td::Slice(begin, end));
}

td::Result<Ref<vm::Cell>> get_config_data_from_smc(Ref<vm::Cell> acc_root) {
  if (acc_root.is_null()) {
    return td::Status::Error("configuration smart contract not found or it has no state, cannot extract configuration");
  }
  block::gen::Account::Record_account acc;
  block::gen::AccountStorage::Record storage;
  block::gen::StateInit::Record state;
  if (!(tlb::unpack_cell(acc_root, acc) && tlb::csr_unpack(acc.storage, storage) &&
        storage.state.write().fetch_ulong(1) == 1 && tlb::csr_unpack(storage.state, state) &&
        state.data->have_refs(1))) {
    return td::Status::Error("cannot extract persistent data from configuration smart contract state");
  }
  Ref<vm::Cell> data_cell = state.data->prefetch_ref();
  auto res = vm::load_cell_slice(data_cell).prefetch_ref();
  if (res.is_null()) {
    return td::Status::Error(
        "configuration smart contract does not contain a valid configuration in the first reference of its persistent "
        "data");
  }
  return std::move(res);
}

td::Result<Ref<vm::Cell>> get_config_data_from_smc(Ref<vm::CellSlice> acc_csr) {
  if (acc_csr.is_null()) {
    return td::Status::Error("configuration smart contract not found, cannot extract configuration");
  }
  if (acc_csr->size_ext() != 0x10140) {
    return td::Status::Error("configuration smart contract does not have a valid non-empty state");
  }
  return get_config_data_from_smc(acc_csr->prefetch_ref());
}

// when these parameters change, the block must be marked as a key block
bool important_config_parameters_changed(Ref<vm::Cell> old_cfg_root, Ref<vm::Cell> new_cfg_root, bool coarse) {
  if (old_cfg_root->get_hash() == new_cfg_root->get_hash()) {
    return false;
  }
  if (coarse) {
    return true;
  }
  // for now, all parameters are "important"
  // at least the parameters affecting the computations of validator sets must be considered important
  // ...
  return true;
}

bool is_public_library(td::ConstBitPtr key, Ref<vm::CellSlice> val) {
  return val.not_null() && val->prefetch_ulong(1) == 1 && val->have_refs() &&
         !key.compare(val->prefetch_ref()->get_hash().bits(), 256);
}

bool parse_hex_hash(const char* str, const char* end, td::Bits256& hash) {
  if (end - str != 64) {
    return false;
  }
  int y = 0;
  for (int i = 0; i < 64; i++) {
    int c = *str++, x = c - '0';
    if (x < 0) {
      return false;
    } else if (x > 10) {
      x = (c | 0x20) - ('a' - 10);
      if (x < 10 || x > 16) {
        return false;
      }
    }
    y = (y << 4) | x;
    if (i & 1) {
      hash.data()[i >> 1] = (unsigned char)y;
      y = 0;
    }
  }
  return true;
}

bool parse_hex_hash(td::Slice str, td::Bits256& hash) {
  return parse_hex_hash(str.begin(), str.end(), hash);
}

bool parse_block_id_ext(const char* str, const char* end, ton::BlockIdExt& blkid) {
  blkid.invalidate();
  if (!str || !end || str >= end || end - str > 255) {
    return false;
  }
  if (*str != '(') {
    return false;
  }
  if (!std::memchr(str, ')', end - str)) {
    return false;
  }
  int wc, pos = 0;
  unsigned seqno;
  unsigned long long shard;
  if (std::sscanf(str, "(%d,%llx,%u):%n", &wc, &shard, &seqno, &pos) < 3 || pos <= 0 || pos >= end - str) {
    return false;
  }
  if (!shard || wc == ton::workchainInvalid) {
    return false;
  }
  str += pos;
  if (end - str != 64 * 2 + 1 || str[64] != ':') {
    return false;
  }
  blkid.id = ton::BlockId{wc, shard, seqno};
  return (parse_hex_hash(str, str + 64, blkid.root_hash) && parse_hex_hash(str + 65, end, blkid.file_hash)) ||
         blkid.invalidate();
}

bool parse_block_id_ext(td::Slice str, ton::BlockIdExt& blkid) {
  return parse_block_id_ext(str.begin(), str.end(), blkid);
}

}  // namespace block
