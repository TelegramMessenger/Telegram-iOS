#pragma once
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "Ed25519.h"
#include "block/block-auto.h"
#include "block/block-parse.h"

#include "td/utils/Variant.h"

#include "SmartContract.h"
#include "SmartContractCode.h"

namespace ton {
namespace pchan {

//
// Payment channels
//
struct Config {
  td::uint32 init_timeout{0};
  td::uint32 close_timeout{0};
  td::SecureString a_key;
  td::SecureString b_key;
  block::StdAddress a_addr;
  block::StdAddress b_addr;
  td::uint64 channel_id{0};

  td::Ref<vm::Cell> serialize() const;
};

struct MsgInit {
  td::uint64 inc_A{0};
  td::uint64 inc_B{0};
  td::uint64 min_A{0};
  td::uint64 min_B{0};
  td::uint64 channel_id{0};

  td::Ref<vm::Cell> serialize() const;
};

struct Promise {
  td::uint64 channel_id;
  td::uint64 promise_A{0};
  td::uint64 promise_B{0};
  td::Ref<vm::Cell> serialize() const;
};

td::Ref<vm::Cell> maybe_sign(const td::Ref<vm::Cell>& msg, const td::Ed25519::PrivateKey* key);
td::Ref<vm::CellSlice> maybe_ref(td::Ref<vm::Cell> msg);

struct MsgClose {
  td::uint64 extra_A{0};
  td::uint64 extra_B{0};
  td::Ref<vm::CellSlice> signed_promise;
  td::Ref<vm::Cell> serialize() const;
};

struct MsgTimeout {
  td::Ref<vm::Cell> serialize() const;
};

struct SignedPromise {
  Promise promise;
  td::optional<td::SecureString> o_signature;

  bool unpack(td::Ref<vm::Cell> cell);
  static td::SecureString signature(const td::Ed25519::PrivateKey* key, const td::Ref<vm::Cell>& promise);
  static td::Ref<vm::Cell> create_and_serialize(td::Slice signature, const td::Ref<vm::Cell>& promise);
  static td::Ref<vm::Cell> create_and_serialize(const td::Ed25519::PrivateKey* key, const td::Ref<vm::Cell>& promise);
};

struct StateInit {
  bool signed_A{false};
  bool signed_B{false};
  td::uint64 min_A{0};
  td::uint64 min_B{0};
  td::uint64 A{0};
  td::uint64 B{0};
  td::uint32 expire_at{0};

  td::Ref<vm::Cell> serialize() const;
};

struct StateClose {
  bool signed_A{false};
  bool signed_B{false};
  td::uint64 promise_A{0};
  td::uint64 promise_B{0};
  td::uint64 A{0};
  td::uint64 B{0};
  td::uint32 expire_at{0};
};

struct StatePayout {
  td::uint64 A{0};
  td::uint64 B{0};
};

struct Data {
  td::Ref<vm::Cell> config;
  td::Ref<vm::Cell> state;

  static td::Ref<vm::Cell> init_state();

  td::Ref<vm::Cell> serialize() const;
};

template <class T>
struct MsgBuilder {
  td::Ed25519::PrivateKey* a_key{nullptr};
  td::Ed25519::PrivateKey* b_key{nullptr};

  T&& with_a_key(td::Ed25519::PrivateKey* key) && {
    a_key = key;
    return static_cast<T&&>(*this);
  }
  T&& with_b_key(td::Ed25519::PrivateKey* key) && {
    b_key = key;
    return static_cast<T&&>(*this);
  }

  td::Ref<vm::Cell> finalize() && {
    block::gen::ChanSignedMsg::Record rec;
    auto msg = static_cast<T&&>(*this).msg.serialize();
    rec.msg = vm::load_cell_slice_ref(msg);
    rec.sig_A = maybe_ref(maybe_sign(msg, a_key));
    rec.sig_B = maybe_ref(maybe_sign(msg, b_key));
    td::Ref<vm::Cell> res;
    CHECK(tlb::pack_cell(res, rec));
    return res;
  }
};

struct MsgInitBuilder : public MsgBuilder<MsgInitBuilder> {
  MsgInit msg;

  MsgInitBuilder&& min_A(td::uint64 value) && {
    msg.min_A = value;
    return std::move(*this);
  }
  MsgInitBuilder&& min_B(td::uint64 value) && {
    msg.min_B = value;
    return std::move(*this);
  }
  MsgInitBuilder&& inc_A(td::uint64 value) && {
    msg.inc_A = value;
    return std::move(*this);
  }
  MsgInitBuilder&& inc_B(td::uint64 value) && {
    msg.inc_B = value;
    return std::move(*this);
  }
  MsgInitBuilder&& channel_id(td::uint64 value) && {
    msg.channel_id = value;
    return std::move(*this);
  }
};

struct MsgTimeoutBuilder : public MsgBuilder<MsgTimeoutBuilder> {
  MsgTimeout msg;
};

struct MsgCloseBuilder : public MsgBuilder<MsgCloseBuilder> {
  MsgClose msg;

  MsgCloseBuilder&& extra_A(td::uint64 value) && {
    msg.extra_A = value;
    return std::move(*this);
  }
  MsgCloseBuilder&& extra_B(td::uint64 value) && {
    msg.extra_B = value;
    return std::move(*this);
  }
  MsgCloseBuilder&& signed_promise(td::Ref<vm::Cell> signed_promise) && {
    msg.signed_promise = vm::load_cell_slice_ref(signed_promise);
    return std::move(*this);
  }
};

struct SignedPromiseBuilder {
  Promise promise;
  td::optional<td::SecureString> o_signature;
  td::Ed25519::PrivateKey* key{nullptr};

  SignedPromiseBuilder& with_key(td::Ed25519::PrivateKey* key) {
    this->key = key;
    return *this;
  }
  SignedPromiseBuilder& promise_A(td::uint64 value) {
    promise.promise_A = value;
    return *this;
  }
  SignedPromiseBuilder& promise_B(td::uint64 value) {
    promise.promise_B = value;
    return *this;
  }
  SignedPromiseBuilder& channel_id(td::uint64 value) {
    promise.channel_id = value;
    return *this;
  }
  SignedPromiseBuilder& signature(td::SecureString signature) {
    o_signature = std::move(signature);
    return *this;
  }

  bool check_signature(td::Slice signature, const td::Ed25519::PublicKey& pk) {
    return pk.verify_signature(promise.serialize()->get_hash().as_slice(), signature).is_ok();
  }
  td::SecureString calc_signature() {
    CHECK(key);
    return SignedPromise::signature(key, promise.serialize());
  }
  td::Ref<vm::Cell> finalize() {
    if (o_signature) {
      return SignedPromise::create_and_serialize(o_signature.value().copy(), promise.serialize());
    } else {
      return SignedPromise::create_and_serialize(key, promise.serialize());
    }
  }
};

}  // namespace pchan

class PaymentChannel : public SmartContract {
 public:
  PaymentChannel(State state) : SmartContract(std::move(state)) {
  }

  struct Info {
    pchan::Config config;
    td::Variant<pchan::StateInit, pchan::StateClose, pchan::StatePayout> state;
    std::string description;
  };
  td::Result<Info> get_info() const;

  static td::Ref<PaymentChannel> create(State state) {
    return td::Ref<PaymentChannel>(true, std::move(state));
  }
  static td::optional<td::int32> guess_revision(const vm::Cell::Hash& code_hash);
  static td::Ref<PaymentChannel> create(const pchan::Config& config, td::int32 revision) {
    State state;
    state.code = SmartContractCode::get_code(SmartContractCode::PaymentChannel, revision);
    pchan::Data data;
    data.config = config.serialize();
    pchan::StateInit init;
    data.state = init.serialize();
    state.data = data.serialize();
    return create(std::move(state));
  }
};
}  // namespace ton
