#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/UInt.h"

#include <cstdint>
#include <utility>
#include <vector>

namespace td {
class TlStorerCalcLength;
class TlStorerUnsafe;
class TlStorerToString;
class TlParser;

namespace e2e_api {

using int32 = std::int32_t;
using int53 = std::int64_t;
using int64 = std::int64_t;

using string = std::string;

using bytes = std::string;

using secure_string = std::string;

using secure_bytes = std::string;

template <class Type>
using array = std::vector<Type>;

using BaseObject = ::td::TlObject;

template <class Type>
using object_ptr = ::td::tl_object_ptr<Type>;

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

template <class T>
std::string to_string(const std::vector<object_ptr<T>> &values) {
  std::string result = "{\n";
  for (const auto &value : values) {
    if (value == nullptr) {
      result += "null\n";
    } else {
      result += to_string(*value);
    }
  }
  result += "}\n";
  return result;
}

class Object: public TlObject {
 public:

  static object_ptr<Object> fetch(TlParser &p);
};

class Function: public TlObject {
 public:

  static object_ptr<Function> fetch(TlParser &p);
};

class ok final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -722616727;

  static object_ptr<ok> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_callPacket final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 1084669673;

  static object_ptr<e2e_callPacket> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_callPacketLargeMsgId final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 484797485;

  static object_ptr<e2e_callPacketLargeMsgId> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_HandshakePrivate: public Object {
 public:

  static object_ptr<e2e_HandshakePrivate> fetch(TlParser &p);
};

class e2e_handshakePrivateAccept final : public e2e_HandshakePrivate {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 alice_PK_;
  UInt256 bob_PK_;
  int64 alice_user_id_;
  int64 bob_user_id_;
  UInt256 alice_nonce_;
  UInt256 bob_nonce_;

  e2e_handshakePrivateAccept(UInt256 const &alice_PK_, UInt256 const &bob_PK_, int64 alice_user_id_, int64 bob_user_id_, UInt256 const &alice_nonce_, UInt256 const &bob_nonce_);

  static const std::int32_t ID = -1711729321;

  static object_ptr<e2e_HandshakePrivate> fetch(TlParser &p);

  explicit e2e_handshakePrivateAccept(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_handshakePrivateFinish final : public e2e_HandshakePrivate {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 alice_PK_;
  UInt256 bob_PK_;
  int64 alice_user_id_;
  int64 bob_user_id_;
  UInt256 alice_nonce_;
  UInt256 bob_nonce_;

  e2e_handshakePrivateFinish(UInt256 const &alice_PK_, UInt256 const &bob_PK_, int64 alice_user_id_, int64 bob_user_id_, UInt256 const &alice_nonce_, UInt256 const &bob_nonce_);

  static const std::int32_t ID = 353768245;

  static object_ptr<e2e_HandshakePrivate> fetch(TlParser &p);

  explicit e2e_handshakePrivateFinish(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_HandshakePublic: public Object {
 public:

  static object_ptr<e2e_HandshakePublic> fetch(TlParser &p);
};

class e2e_handshakeQR final : public e2e_HandshakePublic {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 bob_ephemeral_PK_;
  UInt256 bob_nonce_;

  e2e_handshakeQR(UInt256 const &bob_ephemeral_PK_, UInt256 const &bob_nonce_);

  static const std::int32_t ID = -746741414;

  static object_ptr<e2e_HandshakePublic> fetch(TlParser &p);

  explicit e2e_handshakeQR(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_handshakeEncryptedMessage final : public e2e_HandshakePublic {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes message_;

  explicit e2e_handshakeEncryptedMessage(bytes const &message_);

  static const std::int32_t ID = -1757409540;

  static object_ptr<e2e_HandshakePublic> fetch(TlParser &p);

  explicit e2e_handshakeEncryptedMessage(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_handshakeLoginExport final : public e2e_HandshakePublic {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes accept_;
  bytes encrypted_key_;

  e2e_handshakeLoginExport(bytes const &accept_, bytes const &encrypted_key_);

  static const std::int32_t ID = -152012972;

  static object_ptr<e2e_HandshakePublic> fetch(TlParser &p);

  explicit e2e_handshakeLoginExport(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_Key: public Object {
 public:

  static object_ptr<e2e_Key> fetch(TlParser &p);
};

class e2e_keyContactByUserId final : public e2e_Key {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 user_id_;

  explicit e2e_keyContactByUserId(int64 user_id_);

  static const std::int32_t ID = 1925266987;

  static object_ptr<e2e_Key> fetch(TlParser &p);

  explicit e2e_keyContactByUserId(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_keyContactByPublicKey final : public e2e_Key {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 public_key_;

  explicit e2e_keyContactByPublicKey(UInt256 const &public_key_);

  static const std::int32_t ID = 1817152664;

  static object_ptr<e2e_Key> fetch(TlParser &p);

  explicit e2e_keyContactByPublicKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_Personal: public Object {
 public:

  static object_ptr<e2e_Personal> fetch(TlParser &p);
};

class e2e_personalUserId final : public e2e_Personal {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 user_id_;

  explicit e2e_personalUserId(int64 user_id_);

  static const std::int32_t ID = 380090592;

  static object_ptr<e2e_Personal> fetch(TlParser &p);

  explicit e2e_personalUserId(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalName final : public e2e_Personal {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string first_name_;
  string last_name_;

  e2e_personalName(string const &first_name_, string const &last_name_);

  static const std::int32_t ID = 1760192213;

  static object_ptr<e2e_Personal> fetch(TlParser &p);

  explicit e2e_personalName(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalPhoneNumber final : public e2e_Personal {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string phone_number_;

  explicit e2e_personalPhoneNumber(string const &phone_number_);

  static const std::int32_t ID = 1124597274;

  static object_ptr<e2e_Personal> fetch(TlParser &p);

  explicit e2e_personalPhoneNumber(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalContactState final : public e2e_Personal {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  bool is_contact_;

  e2e_personalContactState();

  e2e_personalContactState(int32 flags_, bool is_contact_);

  static const std::int32_t ID = -1052064682;

  static object_ptr<e2e_Personal> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalEmojiNonces final : public e2e_Personal {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  UInt256 self_nonce_;
  UInt256 contact_nonce_hash_;
  UInt256 contact_nonce_;
  enum Flags : std::int32_t { SELF_NONCE_MASK = 1, CONTACT_NONCE_HASH_MASK = 2, CONTACT_NONCE_MASK = 4 };

  e2e_personalEmojiNonces();

  e2e_personalEmojiNonces(int32 flags_, UInt256 const &self_nonce_, UInt256 const &contact_nonce_hash_, UInt256 const &contact_nonce_);

  static const std::int32_t ID = -2046934345;

  static object_ptr<e2e_Personal> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalOnServer;

class e2e_personalData final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 public_key_;
  array<object_ptr<e2e_personalOnServer>> data_;

  e2e_personalData(UInt256 const &public_key_, array<object_ptr<e2e_personalOnServer>> &&data_);

  static const std::int32_t ID = 1037793350;

  static object_ptr<e2e_personalData> fetch(TlParser &p);

  explicit e2e_personalData(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_Personal;

class e2e_personalOnClient final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 signed_at_;
  object_ptr<e2e_Personal> personal_;

  e2e_personalOnClient(int32 signed_at_, object_ptr<e2e_Personal> &&personal_);

  static const std::int32_t ID = -341421551;

  static object_ptr<e2e_personalOnClient> fetch(TlParser &p);

  explicit e2e_personalOnClient(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_Personal;

class e2e_personalOnServer final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt512 signature_;
  int32 signed_at_;
  object_ptr<e2e_Personal> personal_;

  e2e_personalOnServer(UInt512 const &signature_, int32 signed_at_, object_ptr<e2e_Personal> &&personal_);

  static const std::int32_t ID = -800248701;

  static object_ptr<e2e_personalOnServer> fetch(TlParser &p);

  explicit e2e_personalOnServer(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_personalOnClient;

class e2e_Value: public Object {
 public:

  static object_ptr<e2e_Value> fetch(TlParser &p);
};

class e2e_valueContactByUserId final : public e2e_Value {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<UInt256> public_keys_;

  explicit e2e_valueContactByUserId(array<UInt256> &&public_keys_);

  static const std::int32_t ID = 113903379;

  static object_ptr<e2e_Value> fetch(TlParser &p);

  explicit e2e_valueContactByUserId(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_valueContactByPublicKey final : public e2e_Value {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<object_ptr<e2e_personalOnClient>> entries_;

  explicit e2e_valueContactByPublicKey(array<object_ptr<e2e_personalOnClient>> &&entries_);

  static const std::int32_t ID = -1418478879;

  static object_ptr<e2e_Value> fetch(TlParser &p);

  explicit e2e_valueContactByPublicKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_Change;

class e2e_chain_stateProof;

class e2e_chain_block final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt512 signature_;
  int32 flags_;
  UInt256 prev_block_hash_;
  array<object_ptr<e2e_chain_Change>> changes_;
  int32 height_;
  object_ptr<e2e_chain_stateProof> state_proof_;
  UInt256 signature_public_key_;
  enum Flags : std::int32_t { SIGNATURE_PUBLIC_KEY_MASK = 1 };

  e2e_chain_block();

  e2e_chain_block(UInt512 const &signature_, int32 flags_, UInt256 const &prev_block_hash_, array<object_ptr<e2e_chain_Change>> &&changes_, int32 height_, object_ptr<e2e_chain_stateProof> &&state_proof_, UInt256 const &signature_public_key_);

  static const std::int32_t ID = 1671052726;

  static object_ptr<e2e_chain_block> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_groupState;

class e2e_chain_sharedKey;

class e2e_chain_Change: public Object {
 public:

  static object_ptr<e2e_chain_Change> fetch(TlParser &p);
};

class e2e_chain_changeNoop final : public e2e_chain_Change {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 nonce_;

  explicit e2e_chain_changeNoop(UInt256 const &nonce_);

  static const std::int32_t ID = -558586853;

  static object_ptr<e2e_chain_Change> fetch(TlParser &p);

  explicit e2e_chain_changeNoop(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_changeSetValue final : public e2e_chain_Change {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  bytes key_;
  bytes value_;

  e2e_chain_changeSetValue(bytes const &key_, bytes const &value_);

  static const std::int32_t ID = -33474100;

  static object_ptr<e2e_chain_Change> fetch(TlParser &p);

  explicit e2e_chain_changeSetValue(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_changeSetGroupState final : public e2e_chain_Change {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  object_ptr<e2e_chain_groupState> group_state_;

  explicit e2e_chain_changeSetGroupState(object_ptr<e2e_chain_groupState> &&group_state_);

  static const std::int32_t ID = 754020678;

  static object_ptr<e2e_chain_Change> fetch(TlParser &p);

  explicit e2e_chain_changeSetGroupState(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_changeSetSharedKey final : public e2e_chain_Change {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  object_ptr<e2e_chain_sharedKey> shared_key_;

  explicit e2e_chain_changeSetSharedKey(object_ptr<e2e_chain_sharedKey> &&shared_key_);

  static const std::int32_t ID = -1736826536;

  static object_ptr<e2e_chain_Change> fetch(TlParser &p);

  explicit e2e_chain_changeSetSharedKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_GroupBroadcast: public Object {
 public:

  static object_ptr<e2e_chain_GroupBroadcast> fetch(TlParser &p);
};

class e2e_chain_groupBroadcastNonceCommit final : public e2e_chain_GroupBroadcast {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt512 signature_;
  int64 user_id_;
  int32 chain_height_;
  UInt256 chain_hash_;
  UInt256 nonce_hash_;

  e2e_chain_groupBroadcastNonceCommit(UInt512 const &signature_, int64 user_id_, int32 chain_height_, UInt256 const &chain_hash_, UInt256 const &nonce_hash_);

  static const std::int32_t ID = -783209753;

  static object_ptr<e2e_chain_GroupBroadcast> fetch(TlParser &p);

  explicit e2e_chain_groupBroadcastNonceCommit(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_groupBroadcastNonceReveal final : public e2e_chain_GroupBroadcast {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt512 signature_;
  int64 user_id_;
  int32 chain_height_;
  UInt256 chain_hash_;
  UInt256 nonce_;

  e2e_chain_groupBroadcastNonceReveal(UInt512 const &signature_, int64 user_id_, int32 chain_height_, UInt256 const &chain_hash_, UInt256 const &nonce_);

  static const std::int32_t ID = -2081097256;

  static object_ptr<e2e_chain_GroupBroadcast> fetch(TlParser &p);

  explicit e2e_chain_groupBroadcastNonceReveal(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_groupParticipant final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 user_id_;
  UInt256 public_key_;
  int32 flags_;
  bool add_users_;
  bool remove_users_;
  int32 version_;

  e2e_chain_groupParticipant();

  e2e_chain_groupParticipant(int64 user_id_, UInt256 const &public_key_, int32 flags_, bool add_users_, bool remove_users_, int32 version_);

  static const std::int32_t ID = 418617119;

  static object_ptr<e2e_chain_groupParticipant> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_groupParticipant;

class e2e_chain_groupState final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<object_ptr<e2e_chain_groupParticipant>> participants_;
  int32 external_permissions_;

  e2e_chain_groupState(array<object_ptr<e2e_chain_groupParticipant>> &&participants_, int32 external_permissions_);

  static const std::int32_t ID = 500987268;

  static object_ptr<e2e_chain_groupState> fetch(TlParser &p);

  explicit e2e_chain_groupState(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_sharedKey final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt256 ek_;
  string encrypted_shared_key_;
  array<int64> dest_user_id_;
  array<bytes> dest_header_;

  e2e_chain_sharedKey(UInt256 const &ek_, string const &encrypted_shared_key_, array<int64> &&dest_user_id_, array<bytes> &&dest_header_);

  static const std::int32_t ID = -1971028353;

  static object_ptr<e2e_chain_sharedKey> fetch(TlParser &p);

  explicit e2e_chain_sharedKey(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_chain_groupState;

class e2e_chain_sharedKey;

class e2e_chain_stateProof final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 flags_;
  UInt256 kv_hash_;
  object_ptr<e2e_chain_groupState> group_state_;
  object_ptr<e2e_chain_sharedKey> shared_key_;
  enum Flags : std::int32_t { GROUP_STATE_MASK = 1, SHARED_KEY_MASK = 2 };

  e2e_chain_stateProof();

  e2e_chain_stateProof(int32 flags_, UInt256 const &kv_hash_, object_ptr<e2e_chain_groupState> &&group_state_, object_ptr<e2e_chain_sharedKey> &&shared_key_);

  static const std::int32_t ID = -692684314;

  static object_ptr<e2e_chain_stateProof> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class e2e_nop final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 1479594067;

  using ReturnType = bool;

  static object_ptr<e2e_nop> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

}  // namespace e2e_api
}  // namespace td
