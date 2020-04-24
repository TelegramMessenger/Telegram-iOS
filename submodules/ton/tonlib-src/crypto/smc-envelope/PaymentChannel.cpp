#include "PaymentChannel.h"
#include "GenericAccount.h"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "Ed25519.h"
#include "block/block-auto.h"
#include "block/block-parse.h"

#include "SmartContract.h"
#include "SmartContractCode.h"

namespace ton {
using smc::pack_grams;
using smc::unpack_grams;
namespace pchan {

td::Ref<vm::Cell> Config::serialize() const {
  block::gen::ChanConfig::Record rec;

  vm::CellBuilder a_addr_cb;
  block::tlb::t_MsgAddressInt.store_std_address(a_addr_cb, a_addr);
  rec.a_addr = a_addr_cb.finalize_novm();

  vm::CellBuilder b_addr_cb;
  block::tlb::t_MsgAddressInt.store_std_address(b_addr_cb, b_addr);
  rec.b_addr = b_addr_cb.finalize_novm();

  rec.a_key.as_slice().copy_from(a_key);
  rec.b_key.as_slice().copy_from(b_key);
  rec.init_timeout = init_timeout;
  rec.close_timeout = close_timeout;
  rec.channel_id = channel_id;

  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::Ref<vm::Cell> MsgInit::serialize() const {
  block::gen::ChanMsg::Record_chan_msg_init rec;
  rec.min_A = pack_grams(min_A);
  rec.min_B = pack_grams(min_B);
  rec.inc_A = pack_grams(inc_A);
  rec.inc_B = pack_grams(inc_B);
  rec.channel_id = channel_id;

  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::Ref<vm::Cell> Promise::serialize() const {
  block::gen::ChanPromise::Record rec;
  rec.channel_id = channel_id;
  rec.promise_A = pack_grams(promise_A);
  rec.promise_B = pack_grams(promise_B);
  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::SecureString sign(const td::Ref<vm::Cell>& msg, const td::Ed25519::PrivateKey* key) {
  return key->sign(msg->get_hash().as_slice()).move_as_ok();
}

td::Ref<vm::Cell> maybe_sign(const td::Ref<vm::Cell>& msg, const td::Ed25519::PrivateKey* key) {
  if (!key) {
    return {};
  }
  return vm::CellBuilder().store_bytes(sign(msg, key).as_slice()).finalize();
}

td::Ref<vm::CellSlice> maybe_ref(td::Ref<vm::Cell> msg) {
  vm::CellBuilder cb;
  CHECK(cb.store_maybe_ref(msg));
  return vm::load_cell_slice_ref(cb.finalize());
}

td::Ref<vm::Cell> MsgClose::serialize() const {
  block::gen::ChanMsg::Record_chan_msg_close rec;
  rec.extra_A = pack_grams(extra_A);
  rec.extra_B = pack_grams(extra_B);
  rec.promise = signed_promise;

  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::Ref<vm::Cell> MsgTimeout::serialize() const {
  block::gen::ChanMsg::Record_chan_msg_timeout rec;
  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::SecureString SignedPromise::signature(const td::Ed25519::PrivateKey* key, const td::Ref<vm::Cell>& promise) {
  return sign(promise, key);
}
td::Ref<vm::Cell> SignedPromise::create_and_serialize(td::Slice signature, const td::Ref<vm::Cell>& promise) {
  block::gen::ChanSignedPromise::Record rec;
  rec.promise = vm::load_cell_slice_ref(promise);
  LOG(ERROR) << "signature.size() = " << signature.size();
  rec.sig = maybe_ref(vm::CellBuilder().store_bytes(signature).finalize());
  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}
td::Ref<vm::Cell> SignedPromise::create_and_serialize(const td::Ed25519::PrivateKey* key,
                                                      const td::Ref<vm::Cell>& promise) {
  block::gen::ChanSignedPromise::Record rec;
  rec.promise = vm::load_cell_slice_ref(promise);
  rec.sig = maybe_ref(maybe_sign(promise, key));
  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

bool SignedPromise::unpack(td::Ref<vm::Cell> cell) {
  block::gen::ChanSignedPromise::Record rec;
  if (!tlb::unpack_cell(cell, rec)) {
    return false;
  }
  block::gen::ChanPromise::Record rec_promise;
  if (!tlb::csr_unpack(rec.promise, rec_promise)) {
    return false;
  }
  promise.channel_id = rec_promise.channel_id;
  if (!unpack_grams(rec_promise.promise_A, promise.promise_A)) {
    return false;
  }
  if (!unpack_grams(rec_promise.promise_B, promise.promise_B)) {
    return false;
  }
  td::Ref<vm::Cell> sig_cell;
  if (!rec.sig->prefetch_maybe_ref(sig_cell)) {
    return false;
  }
  td::SecureString signature(64);
  vm::CellSlice cs = vm::load_cell_slice(sig_cell);
  if (!cs.prefetch_bytes(signature.as_mutable_slice())) {
    return false;
  }
  o_signature = std::move(signature);
  return true;
}

td::Ref<vm::Cell> StateInit::serialize() const {
  block::gen::ChanState::Record_chan_state_init rec;
  rec.expire_at = expire_at;
  rec.min_A = pack_grams(min_A);
  rec.min_B = pack_grams(min_B);
  rec.A = pack_grams(A);
  rec.B = pack_grams(B);
  rec.signed_A = signed_A;
  rec.signed_B = signed_B;
  td::Ref<vm::Cell> res;
  CHECK(tlb::pack_cell(res, rec));
  return res;
}

td::Ref<vm::Cell> Data::serialize() const {
  block::gen::ChanData::Record rec;
  rec.config = config;
  rec.state = state;
  td::Ref<vm::Cell> res;
  CHECK(block::gen::t_ChanData.cell_pack(res, rec));
  return res;
}

td::Ref<vm::Cell> Data::init_state() {
  return StateInit().serialize();
}
}  // namespace pchan

td::Result<PaymentChannel::Info> PaymentChannel::get_info() const {
  block::gen::ChanData::Record data_rec;
  if (!tlb::unpack_cell(get_state().data, data_rec)) {
    return td::Status::Error("Can't unpack data");
  }
  block::gen::ChanConfig::Record config_rec;
  if (!tlb::unpack_cell(data_rec.config, config_rec)) {
    return td::Status::Error("Can't unpack config");
  }
  pchan::Config config;
  config.a_key = td::SecureString(config_rec.a_key.as_slice());
  config.b_key = td::SecureString(config_rec.b_key.as_slice());
  block::tlb::t_MsgAddressInt.extract_std_address(vm::load_cell_slice_ref(config_rec.a_addr), config.a_addr);
  block::tlb::t_MsgAddressInt.extract_std_address(vm::load_cell_slice_ref(config_rec.b_addr), config.b_addr);
  config.init_timeout = static_cast<td::int32>(config_rec.init_timeout);
  config.close_timeout = static_cast<td::int32>(config_rec.close_timeout);
  config.channel_id = static_cast<td::int64>(config_rec.channel_id);

  auto state_cs = vm::load_cell_slice(data_rec.state);
  Info res;
  switch (block::gen::t_ChanState.check_tag(state_cs)) {
    case block::gen::ChanState::chan_state_init: {
      pchan::StateInit state;
      block::gen::ChanState::Record_chan_state_init state_rec;
      if (!tlb::unpack_cell(data_rec.state, state_rec)) {
        return td::Status::Error("Can't unpack state");
      }
      bool ok = unpack_grams(state_rec.A, state.A) && unpack_grams(state_rec.B, state.B) &&
                unpack_grams(state_rec.min_A, state.min_A) && unpack_grams(state_rec.min_B, state.min_B);
      state.expire_at = state_rec.expire_at;
      state.signed_A = state_rec.signed_A;
      state.signed_B = state_rec.signed_B;
      if (!ok) {
        return td::Status::Error("Can't unpack state");
      }
      res.state = std::move(state);
      break;
    }
    case block::gen::ChanState::chan_state_close: {
      pchan::StateClose state;
      block::gen::ChanState::Record_chan_state_close state_rec;
      if (!tlb::unpack_cell(data_rec.state, state_rec)) {
        return td::Status::Error("Can't unpack state");
      }
      bool ok = unpack_grams(state_rec.A, state.A) && unpack_grams(state_rec.B, state.B) &&
                unpack_grams(state_rec.promise_A, state.promise_A) &&
                unpack_grams(state_rec.promise_B, state.promise_B);
      state.expire_at = state_rec.expire_at;
      state.signed_A = state_rec.signed_A;
      state.signed_B = state_rec.signed_B;
      if (!ok) {
        return td::Status::Error("Can't unpack state");
      }
      res.state = std::move(state);
      break;
    }
    case block::gen::ChanState::chan_state_payout: {
      pchan::StatePayout state;
      block::gen::ChanState::Record_chan_state_payout state_rec;
      if (!tlb::unpack_cell(data_rec.state, state_rec)) {
        return td::Status::Error("Can't unpack state");
      }
      bool ok = unpack_grams(state_rec.A, state.A) && unpack_grams(state_rec.B, state.B);
      if (!ok) {
        return td::Status::Error("Can't unpack state");
      }
      res.state = std::move(state);
      break;
    }
    default:
      return td::Status::Error("Can't unpack state");
  }

  res.config = std::move(config);
  res.description = block::gen::t_ChanState.as_string_ref(data_rec.state);

  return std::move(res);
}  // namespace ton

td::optional<td::int32> PaymentChannel::guess_revision(const vm::Cell::Hash& code_hash) {
  for (auto i : ton::SmartContractCode::get_revisions(ton::SmartContractCode::PaymentChannel)) {
    auto code = SmartContractCode::get_code(SmartContractCode::PaymentChannel, i);
    if (code->get_hash() == code_hash) {
      return i;
    }
  }
  return {};
}
}  // namespace ton
