#pragma once

#include "tl/TlObject.h"

#include "td/utils/int_types.h"

#include <string>
#include "td/utils/buffer.h"
#include "crypto/common/bitstring.h"

#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

namespace td {
class TlStorerCalcLength;
}  // namespace td
namespace td {
class TlStorerUnsafe;
}  // namespace td
namespace td {
class TlStorerToString;
}  // namespace td
namespace td {
class TlParser;
}  // namespace td

namespace ton {
namespace lite_api{
using BaseObject = ::ton::TlObject;

template <class Type>
using object_ptr = ::ton::tl_object_ptr<Type>;

template <class Type, class... Args>
object_ptr<Type> make_object(Args &&... args) {
  return object_ptr<Type>(new Type(std::forward<Args>(args)...));
}

template <class ToType, class FromType>
object_ptr<ToType> move_object_as(FromType &&from) {
  return object_ptr<ToType>(static_cast<ToType *>(from.release()));
}

std::string to_string(const BaseObject &value);

template <class T>
std::string to_string(const object_ptr<T> &value) {
  if (value == nullptr) {
    return "null";
  }

  return to_string(*value);
}

class adnl_Message;

class liteServer_accountId;

class liteServer_accountState;

class liteServer_allShardsInfo;

class liteServer_blockData;

class liteServer_blockHeader;

class liteServer_BlockLink;

class liteServer_blockState;

class liteServer_blockTransactions;

class liteServer_configInfo;

class liteServer_currentTime;

class liteServer_error;

class liteServer_masterchainInfo;

class liteServer_masterchainInfoExt;

class liteServer_partialBlockProof;

class liteServer_runMethodResult;

class liteServer_sendMsgStatus;

class liteServer_shardInfo;

class liteServer_signature;

class liteServer_signatureSet;

class liteServer_transactionId;

class liteServer_transactionId3;

class liteServer_transactionInfo;

class liteServer_transactionList;

class liteServer_validatorStats;

class liteServer_version;

class liteServer_debug_verbosity;

class tonNode_blockId;

class tonNode_blockIdExt;

class tonNode_zeroStateIdExt;

class Object;

class Object: public TlObject {
 public:

  static object_ptr<Object> fetch(td::TlParser &p);
};

class Function: public TlObject {
 public:

  static object_ptr<Function> fetch(td::TlParser &p);
};

class adnl_Message: public Object {
 public:

  static object_ptr<adnl_Message> fetch(td::TlParser &p);
};

class adnl_message_query final : public adnl_Message {
 public:
  td::Bits256 query_id_;
  td::BufferSlice query_;

  adnl_message_query();

  adnl_message_query(td::Bits256 const &query_id_, td::BufferSlice &&query_);

  static const std::int32_t ID = -1265895046;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<adnl_Message> fetch(td::TlParser &p);

  explicit adnl_message_query(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class adnl_message_answer final : public adnl_Message {
 public:
  td::Bits256 query_id_;
  td::BufferSlice answer_;

  adnl_message_answer();

  adnl_message_answer(td::Bits256 const &query_id_, td::BufferSlice &&answer_);

  static const std::int32_t ID = 262964246;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<adnl_Message> fetch(td::TlParser &p);

  explicit adnl_message_answer(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_accountId final : public Object {
 public:
  std::int32_t workchain_;
  td::Bits256 id_;

  liteServer_accountId();

  liteServer_accountId(std::int32_t workchain_, td::Bits256 const &id_);

  static const std::int32_t ID = 1973478085;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_accountId> fetch(td::TlParser &p);

  explicit liteServer_accountId(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_accountState final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<tonNode_blockIdExt> shardblk_;
  td::BufferSlice shard_proof_;
  td::BufferSlice proof_;
  td::BufferSlice state_;

  liteServer_accountState();

  liteServer_accountState(object_ptr<tonNode_blockIdExt> &&id_, object_ptr<tonNode_blockIdExt> &&shardblk_, td::BufferSlice &&shard_proof_, td::BufferSlice &&proof_, td::BufferSlice &&state_);

  static const std::int32_t ID = 1887029073;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_accountState> fetch(td::TlParser &p);

  explicit liteServer_accountState(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_allShardsInfo final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  td::BufferSlice proof_;
  td::BufferSlice data_;

  liteServer_allShardsInfo();

  liteServer_allShardsInfo(object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&proof_, td::BufferSlice &&data_);

  static const std::int32_t ID = 160425773;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_allShardsInfo> fetch(td::TlParser &p);

  explicit liteServer_allShardsInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_blockData final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  td::BufferSlice data_;

  liteServer_blockData();

  liteServer_blockData(object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&data_);

  static const std::int32_t ID = -1519063700;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_blockData> fetch(td::TlParser &p);

  explicit liteServer_blockData(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_blockHeader final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t mode_;
  td::BufferSlice header_proof_;

  liteServer_blockHeader();

  liteServer_blockHeader(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t mode_, td::BufferSlice &&header_proof_);

  static const std::int32_t ID = 1965916697;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_blockHeader> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_BlockLink: public Object {
 public:

  static object_ptr<liteServer_BlockLink> fetch(td::TlParser &p);
};

class liteServer_blockLinkBack final : public liteServer_BlockLink {
 public:
  bool to_key_block_;
  object_ptr<tonNode_blockIdExt> from_;
  object_ptr<tonNode_blockIdExt> to_;
  td::BufferSlice dest_proof_;
  td::BufferSlice proof_;
  td::BufferSlice state_proof_;

  liteServer_blockLinkBack();

  liteServer_blockLinkBack(bool to_key_block_, object_ptr<tonNode_blockIdExt> &&from_, object_ptr<tonNode_blockIdExt> &&to_, td::BufferSlice &&dest_proof_, td::BufferSlice &&proof_, td::BufferSlice &&state_proof_);

  static const std::int32_t ID = -276947985;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_BlockLink> fetch(td::TlParser &p);

  explicit liteServer_blockLinkBack(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_blockLinkForward final : public liteServer_BlockLink {
 public:
  bool to_key_block_;
  object_ptr<tonNode_blockIdExt> from_;
  object_ptr<tonNode_blockIdExt> to_;
  td::BufferSlice dest_proof_;
  td::BufferSlice config_proof_;
  object_ptr<liteServer_signatureSet> signatures_;

  liteServer_blockLinkForward();

  liteServer_blockLinkForward(bool to_key_block_, object_ptr<tonNode_blockIdExt> &&from_, object_ptr<tonNode_blockIdExt> &&to_, td::BufferSlice &&dest_proof_, td::BufferSlice &&config_proof_, object_ptr<liteServer_signatureSet> &&signatures_);

  static const std::int32_t ID = 1376767516;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_BlockLink> fetch(td::TlParser &p);

  explicit liteServer_blockLinkForward(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_blockState final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  td::Bits256 root_hash_;
  td::Bits256 file_hash_;
  td::BufferSlice data_;

  liteServer_blockState();

  liteServer_blockState(object_ptr<tonNode_blockIdExt> &&id_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_, td::BufferSlice &&data_);

  static const std::int32_t ID = -1414669300;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_blockState> fetch(td::TlParser &p);

  explicit liteServer_blockState(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_blockTransactions final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t req_count_;
  bool incomplete_;
  std::vector<object_ptr<liteServer_transactionId>> ids_;
  td::BufferSlice proof_;

  liteServer_blockTransactions();

  liteServer_blockTransactions(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t req_count_, bool incomplete_, std::vector<object_ptr<liteServer_transactionId>> &&ids_, td::BufferSlice &&proof_);

  static const std::int32_t ID = -1114854101;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_blockTransactions> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_configInfo final : public Object {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  td::BufferSlice state_proof_;
  td::BufferSlice config_proof_;

  liteServer_configInfo();

  liteServer_configInfo(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&state_proof_, td::BufferSlice &&config_proof_);

  static const std::int32_t ID = -1367660753;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_configInfo> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_currentTime final : public Object {
 public:
  std::int32_t now_;

  liteServer_currentTime();

  explicit liteServer_currentTime(std::int32_t now_);

  static const std::int32_t ID = -380436467;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_currentTime> fetch(td::TlParser &p);

  explicit liteServer_currentTime(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_error final : public Object {
 public:
  std::int32_t code_;
  std::string message_;

  liteServer_error();

  liteServer_error(std::int32_t code_, std::string const &message_);

  static const std::int32_t ID = -1146494648;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_error> fetch(td::TlParser &p);

  explicit liteServer_error(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_masterchainInfo final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> last_;
  td::Bits256 state_root_hash_;
  object_ptr<tonNode_zeroStateIdExt> init_;

  liteServer_masterchainInfo();

  liteServer_masterchainInfo(object_ptr<tonNode_blockIdExt> &&last_, td::Bits256 const &state_root_hash_, object_ptr<tonNode_zeroStateIdExt> &&init_);

  static const std::int32_t ID = -2055001983;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_masterchainInfo> fetch(td::TlParser &p);

  explicit liteServer_masterchainInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_masterchainInfoExt final : public Object {
 public:
  std::int32_t mode_;
  std::int32_t version_;
  std::int64_t capabilities_;
  object_ptr<tonNode_blockIdExt> last_;
  std::int32_t last_utime_;
  std::int32_t now_;
  td::Bits256 state_root_hash_;
  object_ptr<tonNode_zeroStateIdExt> init_;

  liteServer_masterchainInfoExt();

  liteServer_masterchainInfoExt(std::int32_t mode_, std::int32_t version_, std::int64_t capabilities_, object_ptr<tonNode_blockIdExt> &&last_, std::int32_t last_utime_, std::int32_t now_, td::Bits256 const &state_root_hash_, object_ptr<tonNode_zeroStateIdExt> &&init_);

  static const std::int32_t ID = -1462968075;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_masterchainInfoExt> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_partialBlockProof final : public Object {
 public:
  bool complete_;
  object_ptr<tonNode_blockIdExt> from_;
  object_ptr<tonNode_blockIdExt> to_;
  std::vector<object_ptr<liteServer_BlockLink>> steps_;

  liteServer_partialBlockProof();

  liteServer_partialBlockProof(bool complete_, object_ptr<tonNode_blockIdExt> &&from_, object_ptr<tonNode_blockIdExt> &&to_, std::vector<object_ptr<liteServer_BlockLink>> &&steps_);

  static const std::int32_t ID = -1898917183;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_partialBlockProof> fetch(td::TlParser &p);

  explicit liteServer_partialBlockProof(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_runMethodResult final : public Object {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<tonNode_blockIdExt> shardblk_;
  td::BufferSlice shard_proof_;
  td::BufferSlice proof_;
  td::BufferSlice state_proof_;
  td::BufferSlice init_c7_;
  td::BufferSlice lib_extras_;
  std::int32_t exit_code_;
  td::BufferSlice result_;
  enum Flags : std::int32_t {SHARD_PROOF_MASK = 1, PROOF_MASK = 1, STATE_PROOF_MASK = 2, INIT_C7_MASK = 8, LIB_EXTRAS_MASK = 16, RESULT_MASK = 4};

  liteServer_runMethodResult();

  liteServer_runMethodResult(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, object_ptr<tonNode_blockIdExt> &&shardblk_, td::BufferSlice &&shard_proof_, td::BufferSlice &&proof_, td::BufferSlice &&state_proof_, td::BufferSlice &&init_c7_, td::BufferSlice &&lib_extras_, std::int32_t exit_code_, td::BufferSlice &&result_);

  static const std::int32_t ID = -1550163605;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_runMethodResult> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_sendMsgStatus final : public Object {
 public:
  std::int32_t status_;

  liteServer_sendMsgStatus();

  explicit liteServer_sendMsgStatus(std::int32_t status_);

  static const std::int32_t ID = 961602967;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_sendMsgStatus> fetch(td::TlParser &p);

  explicit liteServer_sendMsgStatus(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_shardInfo final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<tonNode_blockIdExt> shardblk_;
  td::BufferSlice shard_proof_;
  td::BufferSlice shard_descr_;

  liteServer_shardInfo();

  liteServer_shardInfo(object_ptr<tonNode_blockIdExt> &&id_, object_ptr<tonNode_blockIdExt> &&shardblk_, td::BufferSlice &&shard_proof_, td::BufferSlice &&shard_descr_);

  static const std::int32_t ID = -1612264060;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_shardInfo> fetch(td::TlParser &p);

  explicit liteServer_shardInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_signature final : public Object {
 public:
  td::Bits256 node_id_short_;
  td::BufferSlice signature_;

  liteServer_signature();

  liteServer_signature(td::Bits256 const &node_id_short_, td::BufferSlice &&signature_);

  static const std::int32_t ID = -1545668523;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_signature> fetch(td::TlParser &p);

  explicit liteServer_signature(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_signatureSet final : public Object {
 public:
  std::int32_t validator_set_hash_;
  std::int32_t catchain_seqno_;
  std::vector<object_ptr<liteServer_signature>> signatures_;

  liteServer_signatureSet();

  liteServer_signatureSet(std::int32_t validator_set_hash_, std::int32_t catchain_seqno_, std::vector<object_ptr<liteServer_signature>> &&signatures_);

  static const std::int32_t ID = -163272986;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_signatureSet> fetch(td::TlParser &p);

  explicit liteServer_signatureSet(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_transactionId final : public Object {
 public:
  std::int32_t mode_;
  td::Bits256 account_;
  std::int64_t lt_;
  td::Bits256 hash_;
  enum Flags : std::int32_t {ACCOUNT_MASK = 1, LT_MASK = 2, HASH_MASK = 4};

  liteServer_transactionId();

  liteServer_transactionId(std::int32_t mode_, td::Bits256 const &account_, std::int64_t lt_, td::Bits256 const &hash_);

  static const std::int32_t ID = -1322293841;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_transactionId> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_transactionId3 final : public Object {
 public:
  td::Bits256 account_;
  std::int64_t lt_;

  liteServer_transactionId3();

  liteServer_transactionId3(td::Bits256 const &account_, std::int64_t lt_);

  static const std::int32_t ID = 746707575;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_transactionId3> fetch(td::TlParser &p);

  explicit liteServer_transactionId3(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_transactionInfo final : public Object {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  td::BufferSlice proof_;
  td::BufferSlice transaction_;

  liteServer_transactionInfo();

  liteServer_transactionInfo(object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&proof_, td::BufferSlice &&transaction_);

  static const std::int32_t ID = 249490759;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_transactionInfo> fetch(td::TlParser &p);

  explicit liteServer_transactionInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_transactionList final : public Object {
 public:
  std::vector<object_ptr<tonNode_blockIdExt>> ids_;
  td::BufferSlice transactions_;

  liteServer_transactionList();

  liteServer_transactionList(std::vector<object_ptr<tonNode_blockIdExt>> &&ids_, td::BufferSlice &&transactions_);

  static const std::int32_t ID = 1864812043;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_transactionList> fetch(td::TlParser &p);

  explicit liteServer_transactionList(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_validatorStats final : public Object {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t count_;
  bool complete_;
  td::BufferSlice state_proof_;
  td::BufferSlice data_proof_;

  liteServer_validatorStats();

  liteServer_validatorStats(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, std::int32_t count_, bool complete_, td::BufferSlice &&state_proof_, td::BufferSlice &&data_proof_);

  static const std::int32_t ID = -1174956328;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_validatorStats> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_version final : public Object {
 public:
  std::int32_t mode_;
  std::int32_t version_;
  std::int64_t capabilities_;
  std::int32_t now_;

  liteServer_version();

  liteServer_version(std::int32_t mode_, std::int32_t version_, std::int64_t capabilities_, std::int32_t now_);

  static const std::int32_t ID = 1510248933;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_version> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_debug_verbosity final : public Object {
 public:
  std::int32_t value_;

  liteServer_debug_verbosity();

  explicit liteServer_debug_verbosity(std::int32_t value_);

  static const std::int32_t ID = 1564493619;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<liteServer_debug_verbosity> fetch(td::TlParser &p);

  explicit liteServer_debug_verbosity(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tonNode_blockId final : public Object {
 public:
  std::int32_t workchain_;
  std::int64_t shard_;
  std::int32_t seqno_;

  tonNode_blockId();

  tonNode_blockId(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_);

  static const std::int32_t ID = -1211256473;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<tonNode_blockId> fetch(td::TlParser &p);

  explicit tonNode_blockId(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tonNode_blockIdExt final : public Object {
 public:
  std::int32_t workchain_;
  std::int64_t shard_;
  std::int32_t seqno_;
  td::Bits256 root_hash_;
  td::Bits256 file_hash_;

  tonNode_blockIdExt();

  tonNode_blockIdExt(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_);

  static const std::int32_t ID = 1733487480;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<tonNode_blockIdExt> fetch(td::TlParser &p);

  explicit tonNode_blockIdExt(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tonNode_zeroStateIdExt final : public Object {
 public:
  std::int32_t workchain_;
  td::Bits256 root_hash_;
  td::Bits256 file_hash_;

  tonNode_zeroStateIdExt();

  tonNode_zeroStateIdExt(std::int32_t workchain_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_);

  static const std::int32_t ID = 494024110;
  std::int32_t get_id() const final {
    return ID;
  }

  static object_ptr<tonNode_zeroStateIdExt> fetch(td::TlParser &p);

  explicit tonNode_zeroStateIdExt(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class liteServer_getAccountState final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<liteServer_accountId> account_;

  liteServer_getAccountState();

  liteServer_getAccountState(object_ptr<tonNode_blockIdExt> &&id_, object_ptr<liteServer_accountId> &&account_);

  static const std::int32_t ID = 1804144165;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_accountState>;

  static object_ptr<liteServer_getAccountState> fetch(td::TlParser &p);

  explicit liteServer_getAccountState(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getAllShardsInfo final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;

  liteServer_getAllShardsInfo();

  explicit liteServer_getAllShardsInfo(object_ptr<tonNode_blockIdExt> &&id_);

  static const std::int32_t ID = 1960050027;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_allShardsInfo>;

  static object_ptr<liteServer_getAllShardsInfo> fetch(td::TlParser &p);

  explicit liteServer_getAllShardsInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getBlock final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;

  liteServer_getBlock();

  explicit liteServer_getBlock(object_ptr<tonNode_blockIdExt> &&id_);

  static const std::int32_t ID = 1668796173;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_blockData>;

  static object_ptr<liteServer_getBlock> fetch(td::TlParser &p);

  explicit liteServer_getBlock(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getBlockHeader final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t mode_;
  mutable std::int32_t var0;

  liteServer_getBlockHeader();

  liteServer_getBlockHeader(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t mode_);

  static const std::int32_t ID = 569116318;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_blockHeader>;

  static object_ptr<liteServer_getBlockHeader> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getBlockProof final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> known_block_;
  object_ptr<tonNode_blockIdExt> target_block_;
  enum Flags : std::int32_t {TARGET_BLOCK_MASK = 1};
  mutable std::int32_t var0;

  liteServer_getBlockProof();

  liteServer_getBlockProof(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&known_block_, object_ptr<tonNode_blockIdExt> &&target_block_);

  static const std::int32_t ID = -1964336060;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_partialBlockProof>;

  static object_ptr<liteServer_getBlockProof> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getConfigAll final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  mutable std::int32_t var0;

  liteServer_getConfigAll();

  liteServer_getConfigAll(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_);

  static const std::int32_t ID = -1860491593;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_configInfo>;

  static object_ptr<liteServer_getConfigAll> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getConfigParams final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  std::vector<std::int32_t> param_list_;
  mutable std::int32_t var0;

  liteServer_getConfigParams();

  liteServer_getConfigParams(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, std::vector<std::int32_t> &&param_list_);

  static const std::int32_t ID = 705764377;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_configInfo>;

  static object_ptr<liteServer_getConfigParams> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getMasterchainInfo final : public Function {
 public:

  liteServer_getMasterchainInfo();

  static const std::int32_t ID = -1984567762;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_masterchainInfo>;

  static object_ptr<liteServer_getMasterchainInfo> fetch(td::TlParser &p);

  explicit liteServer_getMasterchainInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getMasterchainInfoExt final : public Function {
 public:
  std::int32_t mode_;
  mutable std::int32_t var0;

  liteServer_getMasterchainInfoExt();

  explicit liteServer_getMasterchainInfoExt(std::int32_t mode_);

  static const std::int32_t ID = 1889956319;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_masterchainInfoExt>;

  static object_ptr<liteServer_getMasterchainInfoExt> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getOneTransaction final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<liteServer_accountId> account_;
  std::int64_t lt_;

  liteServer_getOneTransaction();

  liteServer_getOneTransaction(object_ptr<tonNode_blockIdExt> &&id_, object_ptr<liteServer_accountId> &&account_, std::int64_t lt_);

  static const std::int32_t ID = -737205014;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_transactionInfo>;

  static object_ptr<liteServer_getOneTransaction> fetch(td::TlParser &p);

  explicit liteServer_getOneTransaction(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getShardInfo final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t workchain_;
  std::int64_t shard_;
  bool exact_;

  liteServer_getShardInfo();

  liteServer_getShardInfo(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t workchain_, std::int64_t shard_, bool exact_);

  static const std::int32_t ID = 1185084453;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_shardInfo>;

  static object_ptr<liteServer_getShardInfo> fetch(td::TlParser &p);

  explicit liteServer_getShardInfo(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getState final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;

  liteServer_getState();

  explicit liteServer_getState(object_ptr<tonNode_blockIdExt> &&id_);

  static const std::int32_t ID = -1167184202;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_blockState>;

  static object_ptr<liteServer_getState> fetch(td::TlParser &p);

  explicit liteServer_getState(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getTime final : public Function {
 public:

  liteServer_getTime();

  static const std::int32_t ID = 380459572;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_currentTime>;

  static object_ptr<liteServer_getTime> fetch(td::TlParser &p);

  explicit liteServer_getTime(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getTransactions final : public Function {
 public:
  std::int32_t count_;
  object_ptr<liteServer_accountId> account_;
  std::int64_t lt_;
  td::Bits256 hash_;
  mutable std::int32_t var0;

  liteServer_getTransactions();

  liteServer_getTransactions(std::int32_t count_, object_ptr<liteServer_accountId> &&account_, std::int64_t lt_, td::Bits256 const &hash_);

  static const std::int32_t ID = 474015649;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_transactionList>;

  static object_ptr<liteServer_getTransactions> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getValidatorStats final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t limit_;
  td::Bits256 start_after_;
  std::int32_t modified_after_;
  enum Flags : std::int32_t {START_AFTER_MASK = 1, MODIFIED_AFTER_MASK = 4};
  mutable std::int32_t var0;

  liteServer_getValidatorStats();

  liteServer_getValidatorStats(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, std::int32_t limit_, td::Bits256 const &start_after_, std::int32_t modified_after_);

  static const std::int32_t ID = 152721596;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_validatorStats>;

  static object_ptr<liteServer_getValidatorStats> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_getVersion final : public Function {
 public:

  liteServer_getVersion();

  static const std::int32_t ID = 590058507;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_version>;

  static object_ptr<liteServer_getVersion> fetch(td::TlParser &p);

  explicit liteServer_getVersion(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_listBlockTransactions final : public Function {
 public:
  object_ptr<tonNode_blockIdExt> id_;
  std::int32_t mode_;
  std::int32_t count_;
  object_ptr<liteServer_transactionId3> after_;
  bool reverse_order_;
  bool want_proof_;
  enum Flags : std::int32_t {AFTER_MASK = 128, REVERSE_ORDER_MASK = 64, WANT_PROOF_MASK = 32};
  mutable std::int32_t var0;
  mutable std::int32_t var1;

  liteServer_listBlockTransactions();

  liteServer_listBlockTransactions(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t mode_, std::int32_t count_, object_ptr<liteServer_transactionId3> &&after_, bool reverse_order_, bool want_proof_);

  static const std::int32_t ID = -1375942694;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_blockTransactions>;

  static object_ptr<liteServer_listBlockTransactions> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_lookupBlock final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockId> id_;
  std::int64_t lt_;
  std::int32_t utime_;
  enum Flags : std::int32_t {LT_MASK = 2, UTIME_MASK = 4};
  mutable std::int32_t var0;

  liteServer_lookupBlock();

  liteServer_lookupBlock(std::int32_t mode_, object_ptr<tonNode_blockId> &&id_, std::int64_t lt_, std::int32_t utime_);

  static const std::int32_t ID = -87492834;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_blockHeader>;

  static object_ptr<liteServer_lookupBlock> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_query final : public Function {
 public:
  td::BufferSlice data_;

  liteServer_query();

  explicit liteServer_query(td::BufferSlice &&data_);

  static const std::int32_t ID = 2039219935;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<Object>;

  static object_ptr<liteServer_query> fetch(td::TlParser &p);

  explicit liteServer_query(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_queryPrefix final : public Function {
 public:

  liteServer_queryPrefix();

  static const std::int32_t ID = 1926489734;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<Object>;

  static object_ptr<liteServer_queryPrefix> fetch(td::TlParser &p);

  explicit liteServer_queryPrefix(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_runSmcMethod final : public Function {
 public:
  std::int32_t mode_;
  object_ptr<tonNode_blockIdExt> id_;
  object_ptr<liteServer_accountId> account_;
  std::int64_t method_id_;
  td::BufferSlice params_;
  mutable std::int32_t var0;

  liteServer_runSmcMethod();

  liteServer_runSmcMethod(std::int32_t mode_, object_ptr<tonNode_blockIdExt> &&id_, object_ptr<liteServer_accountId> &&account_, std::int64_t method_id_, td::BufferSlice &&params_);

  static const std::int32_t ID = 1556504018;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_runMethodResult>;

  static object_ptr<liteServer_runSmcMethod> fetch(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_sendMessage final : public Function {
 public:
  td::BufferSlice body_;

  liteServer_sendMessage();

  explicit liteServer_sendMessage(td::BufferSlice &&body_);

  static const std::int32_t ID = 1762317442;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_sendMsgStatus>;

  static object_ptr<liteServer_sendMessage> fetch(td::TlParser &p);

  explicit liteServer_sendMessage(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

class liteServer_waitMasterchainSeqno final : public Function {
 public:
  std::int32_t seqno_;
  std::int32_t timeout_ms_;

  liteServer_waitMasterchainSeqno();

  liteServer_waitMasterchainSeqno(std::int32_t seqno_, std::int32_t timeout_ms_);

  static const std::int32_t ID = -1159022446;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<Object>;

  static object_ptr<liteServer_waitMasterchainSeqno> fetch(td::TlParser &p);

  explicit liteServer_waitMasterchainSeqno(td::TlParser &p);

  void store(td::TlStorerCalcLength &s) const final;

  void store(td::TlStorerUnsafe &s) const final;

  void store(td::TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(td::TlParser &p);
};

}  // namespace lite_api
}  // namespace ton
