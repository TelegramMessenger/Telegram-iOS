#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/Slice.h"
#include "td/utils/UInt.h"

#include <cstdint>
#include <utility>
#include <vector>

namespace td {
class TlStorerCalcLength;
class TlStorerUnsafe;
class TlStorerToString;
class TlParser;

namespace mtproto_api {

using int32 = std::int32_t;
using int53 = std::int64_t;
using int64 = std::int64_t;

using string = Slice;

using bytes = Slice;

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

class BadMsgNotification: public Object {
 public:

  static object_ptr<BadMsgNotification> fetch(TlParser &p);
};

class bad_msg_notification final : public BadMsgNotification {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 bad_msg_id_;
  int32 bad_msg_seqno_;
  int32 error_code_;

  bad_msg_notification(int64 bad_msg_id_, int32 bad_msg_seqno_, int32 error_code_);

  static const std::int32_t ID = -1477445615;

  static object_ptr<BadMsgNotification> fetch(TlParser &p);

  explicit bad_msg_notification(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class bad_server_salt final : public BadMsgNotification {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 bad_msg_id_;
  int32 bad_msg_seqno_;
  int32 error_code_;
  int64 new_server_salt_;

  bad_server_salt(int64 bad_msg_id_, int32 bad_msg_seqno_, int32 error_code_, int64 new_server_salt_);

  static const std::int32_t ID = -307542917;

  static object_ptr<BadMsgNotification> fetch(TlParser &p);

  explicit bad_server_salt(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class bind_auth_key_inner final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 nonce_;
  int64 temp_auth_key_id_;
  int64 perm_auth_key_id_;
  int64 temp_session_id_;
  int32 expires_at_;

  bind_auth_key_inner(int64 nonce_, int64 temp_auth_key_id_, int64 perm_auth_key_id_, int64 temp_session_id_, int32 expires_at_);

  static const std::int32_t ID = 1973679973;

  static object_ptr<bind_auth_key_inner> fetch(TlParser &p);

  explicit bind_auth_key_inner(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class client_DH_inner_data final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  int64 retry_id_;
  string g_b_;

  client_DH_inner_data(UInt128 const &nonce_, UInt128 const &server_nonce_, int64 retry_id_, string const &g_b_);

  static const std::int32_t ID = 1715713620;

  static object_ptr<client_DH_inner_data> fetch(TlParser &p);

  explicit client_DH_inner_data(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class DestroyAuthKeyRes: public Object {
 public:

  static object_ptr<DestroyAuthKeyRes> fetch(TlParser &p);
};

class destroy_auth_key_ok final : public DestroyAuthKeyRes {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -161422892;

  static object_ptr<DestroyAuthKeyRes> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class destroy_auth_key_none final : public DestroyAuthKeyRes {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 178201177;

  static object_ptr<DestroyAuthKeyRes> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class destroy_auth_key_fail final : public DestroyAuthKeyRes {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -368010477;

  static object_ptr<DestroyAuthKeyRes> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class future_salt final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 valid_since_;
  int32 valid_until_;
  int64 salt_;

  future_salt(int32 valid_since_, int32 valid_until_, int64 salt_);

  static const std::int32_t ID = 155834844;

  static object_ptr<future_salt> fetch(TlParser &p);

  explicit future_salt(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class future_salt;

class future_salts final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 req_msg_id_;
  int32 now_;
  array<object_ptr<future_salt>> salts_;

  future_salts(int64 req_msg_id_, int32 now_, array<object_ptr<future_salt>> &&salts_);

  static const std::int32_t ID = -1370486635;

  static object_ptr<future_salts> fetch(TlParser &p);

  explicit future_salts(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class gzip_packed final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string packed_data_;

  explicit gzip_packed(string const &packed_data_);

  static const std::int32_t ID = 812830625;

  static object_ptr<gzip_packed> fetch(TlParser &p);

  explicit gzip_packed(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class dummyHttpWait final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -919090642;

  static object_ptr<dummyHttpWait> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class MsgDetailedInfo: public Object {
 public:

  static object_ptr<MsgDetailedInfo> fetch(TlParser &p);
};

class msg_detailed_info final : public MsgDetailedInfo {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 msg_id_;
  int64 answer_msg_id_;
  int32 bytes_;
  int32 status_;

  msg_detailed_info(int64 msg_id_, int64 answer_msg_id_, int32 bytes_, int32 status_);

  static const std::int32_t ID = 661470918;

  static object_ptr<MsgDetailedInfo> fetch(TlParser &p);

  explicit msg_detailed_info(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msg_new_detailed_info final : public MsgDetailedInfo {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 answer_msg_id_;
  int32 bytes_;
  int32 status_;

  msg_new_detailed_info(int64 answer_msg_id_, int32 bytes_, int32 status_);

  static const std::int32_t ID = -2137147681;

  static object_ptr<MsgDetailedInfo> fetch(TlParser &p);

  explicit msg_new_detailed_info(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msg_resend_req final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> msg_ids_;

  explicit msg_resend_req(array<int64> &&msg_ids_);

  static const std::int32_t ID = 2105940488;

  static object_ptr<msg_resend_req> fetch(TlParser &p);

  explicit msg_resend_req(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msgs_ack final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> msg_ids_;

  explicit msgs_ack(array<int64> &&msg_ids_);

  static const std::int32_t ID = 1658238041;

  static object_ptr<msgs_ack> fetch(TlParser &p);

  explicit msgs_ack(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msgs_all_info final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> msg_ids_;
  string info_;

  msgs_all_info(array<int64> &&msg_ids_, string const &info_);

  static const std::int32_t ID = -1933520591;

  static object_ptr<msgs_all_info> fetch(TlParser &p);

  explicit msgs_all_info(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msgs_state_info final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 req_msg_id_;
  string info_;

  msgs_state_info(int64 req_msg_id_, string const &info_);

  static const std::int32_t ID = 81704317;

  static object_ptr<msgs_state_info> fetch(TlParser &p);

  explicit msgs_state_info(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class msgs_state_req final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  array<int64> msg_ids_;

  explicit msgs_state_req(array<int64> &&msg_ids_);

  static const std::int32_t ID = -630588590;

  static object_ptr<msgs_state_req> fetch(TlParser &p);

  explicit msgs_state_req(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class new_session_created final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 first_msg_id_;
  int64 unique_id_;
  int64 server_salt_;

  new_session_created(int64 first_msg_id_, int64 unique_id_, int64 server_salt_);

  static const std::int32_t ID = -1631450872;

  static object_ptr<new_session_created> fetch(TlParser &p);

  explicit new_session_created(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class P_Q_inner_data: public Object {
 public:

  static object_ptr<P_Q_inner_data> fetch(TlParser &p);
};

class p_q_inner_data_dc final : public P_Q_inner_data {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string pq_;
  string p_;
  string q_;
  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt256 new_nonce_;
  int32 dc_;

  p_q_inner_data_dc(string const &pq_, string const &p_, string const &q_, UInt128 const &nonce_, UInt128 const &server_nonce_, UInt256 const &new_nonce_, int32 dc_);

  static const std::int32_t ID = -1443537003;

  static object_ptr<P_Q_inner_data> fetch(TlParser &p);

  explicit p_q_inner_data_dc(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class p_q_inner_data_temp_dc final : public P_Q_inner_data {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string pq_;
  string p_;
  string q_;
  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt256 new_nonce_;
  int32 dc_;
  int32 expires_in_;

  p_q_inner_data_temp_dc(string const &pq_, string const &p_, string const &q_, UInt128 const &nonce_, UInt128 const &server_nonce_, UInt256 const &new_nonce_, int32 dc_, int32 expires_in_);

  static const std::int32_t ID = 1459478408;

  static object_ptr<P_Q_inner_data> fetch(TlParser &p);

  explicit p_q_inner_data_temp_dc(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class pong final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 msg_id_;
  int64 ping_id_;

  pong(int64 msg_id_, int64 ping_id_);

  static const std::int32_t ID = 880243653;

  static object_ptr<pong> fetch(TlParser &p);

  explicit pong(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class rsa_public_key final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  string n_;
  string e_;

  rsa_public_key(string const &n_, string const &e_);

  static const std::int32_t ID = 2048510838;

  static object_ptr<rsa_public_key> fetch(TlParser &p);

  explicit rsa_public_key(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class resPQ final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  string pq_;
  array<int64> server_public_key_fingerprints_;

  resPQ(UInt128 const &nonce_, UInt128 const &server_nonce_, string const &pq_, array<int64> &&server_public_key_fingerprints_);

  static const std::int32_t ID = 85337187;

  static object_ptr<resPQ> fetch(TlParser &p);

  explicit resPQ(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class RpcDropAnswer: public Object {
 public:

  static object_ptr<RpcDropAnswer> fetch(TlParser &p);
};

class rpc_answer_unknown final : public RpcDropAnswer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = 1579864942;

  static object_ptr<RpcDropAnswer> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class rpc_answer_dropped_running final : public RpcDropAnswer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -847714938;

  static object_ptr<RpcDropAnswer> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class rpc_answer_dropped final : public RpcDropAnswer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 msg_id_;
  int32 seq_no_;
  int32 bytes_;

  rpc_answer_dropped(int64 msg_id_, int32 seq_no_, int32 bytes_);

  static const std::int32_t ID = -1539647305;

  static object_ptr<RpcDropAnswer> fetch(TlParser &p);

  explicit rpc_answer_dropped(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class rpc_error final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 error_code_;
  string error_message_;

  rpc_error(int32 error_code_, string const &error_message_);

  static const std::int32_t ID = 558156313;

  static object_ptr<rpc_error> fetch(TlParser &p);

  explicit rpc_error(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class server_DH_params_ok final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  string encrypted_answer_;

  server_DH_params_ok(UInt128 const &nonce_, UInt128 const &server_nonce_, string const &encrypted_answer_);

  static const std::int32_t ID = -790100132;

  static object_ptr<server_DH_params_ok> fetch(TlParser &p);

  explicit server_DH_params_ok(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class server_DH_inner_data final : public Object {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  int32 g_;
  string dh_prime_;
  string g_a_;
  int32 server_time_;

  server_DH_inner_data(UInt128 const &nonce_, UInt128 const &server_nonce_, int32 g_, string const &dh_prime_, string const &g_a_, int32 server_time_);

  static const std::int32_t ID = -1249309254;

  static object_ptr<server_DH_inner_data> fetch(TlParser &p);

  explicit server_DH_inner_data(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class Set_client_DH_params_answer: public Object {
 public:

  static object_ptr<Set_client_DH_params_answer> fetch(TlParser &p);
};

class dh_gen_ok final : public Set_client_DH_params_answer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt128 new_nonce_hash1_;

  dh_gen_ok(UInt128 const &nonce_, UInt128 const &server_nonce_, UInt128 const &new_nonce_hash1_);

  static const std::int32_t ID = 1003222836;

  static object_ptr<Set_client_DH_params_answer> fetch(TlParser &p);

  explicit dh_gen_ok(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class dh_gen_retry final : public Set_client_DH_params_answer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt128 new_nonce_hash2_;

  dh_gen_retry(UInt128 const &nonce_, UInt128 const &server_nonce_, UInt128 const &new_nonce_hash2_);

  static const std::int32_t ID = 1188831161;

  static object_ptr<Set_client_DH_params_answer> fetch(TlParser &p);

  explicit dh_gen_retry(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class dh_gen_fail final : public Set_client_DH_params_answer {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt128 new_nonce_hash3_;

  dh_gen_fail(UInt128 const &nonce_, UInt128 const &server_nonce_, UInt128 const &new_nonce_hash3_);

  static const std::int32_t ID = -1499615742;

  static object_ptr<Set_client_DH_params_answer> fetch(TlParser &p);

  explicit dh_gen_fail(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;
};

class DestroyAuthKeyRes;

class destroy_auth_key final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:

  static const std::int32_t ID = -784117408;

  using ReturnType = object_ptr<DestroyAuthKeyRes>;

  static object_ptr<destroy_auth_key> fetch(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class future_salts;

class get_future_salts final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 num_;

  explicit get_future_salts(int32 num_);

  static const std::int32_t ID = -1188971260;

  using ReturnType = object_ptr<future_salts>;

  static object_ptr<get_future_salts> fetch(TlParser &p);

  explicit get_future_salts(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class dummyHttpWait;

class http_wait final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int32 max_delay_;
  int32 wait_after_;
  int32 max_wait_;

  http_wait(int32 max_delay_, int32 wait_after_, int32 max_wait_);

  static const std::int32_t ID = -1835453025;

  using ReturnType = object_ptr<dummyHttpWait>;

  static object_ptr<http_wait> fetch(TlParser &p);

  explicit http_wait(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class pong;

class ping_delay_disconnect final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 ping_id_;
  int32 disconnect_delay_;

  ping_delay_disconnect(int64 ping_id_, int32 disconnect_delay_);

  static const std::int32_t ID = -213746804;

  using ReturnType = object_ptr<pong>;

  static object_ptr<ping_delay_disconnect> fetch(TlParser &p);

  explicit ping_delay_disconnect(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class server_DH_params_ok;

class req_DH_params final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  string p_;
  string q_;
  int64 public_key_fingerprint_;
  string encrypted_data_;

  req_DH_params(UInt128 const &nonce_, UInt128 const &server_nonce_, string const &p_, string const &q_, int64 public_key_fingerprint_, string const &encrypted_data_);

  static const std::int32_t ID = -686627650;

  using ReturnType = object_ptr<server_DH_params_ok>;

  static object_ptr<req_DH_params> fetch(TlParser &p);

  explicit req_DH_params(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class resPQ;

class req_pq_multi final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;

  explicit req_pq_multi(UInt128 const &nonce_);

  static const std::int32_t ID = -1099002127;

  using ReturnType = object_ptr<resPQ>;

  static object_ptr<req_pq_multi> fetch(TlParser &p);

  explicit req_pq_multi(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class RpcDropAnswer;

class rpc_drop_answer final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  int64 req_msg_id_;

  explicit rpc_drop_answer(int64 req_msg_id_);

  static const std::int32_t ID = 1491380032;

  using ReturnType = object_ptr<RpcDropAnswer>;

  static object_ptr<rpc_drop_answer> fetch(TlParser &p);

  explicit rpc_drop_answer(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

class Set_client_DH_params_answer;

class set_client_DH_params final : public Function {
  std::int32_t get_id() const final {
    return ID;
  }

 public:
  UInt128 nonce_;
  UInt128 server_nonce_;
  string encrypted_data_;

  set_client_DH_params(UInt128 const &nonce_, UInt128 const &server_nonce_, string const &encrypted_data_);

  static const std::int32_t ID = -184262881;

  using ReturnType = object_ptr<Set_client_DH_params_answer>;

  static object_ptr<set_client_DH_params> fetch(TlParser &p);

  explicit set_client_DH_params(TlParser &p);

  void store(TlStorerCalcLength &s) const final;

  void store(TlStorerUnsafe &s) const final;

  void store(TlStorerToString &s, const char *field_name) const final;

  static ReturnType fetch_result(TlParser &p);
};

}  // namespace mtproto_api
}  // namespace td
