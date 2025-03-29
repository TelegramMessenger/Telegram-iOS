//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/Handshake.h"

#include "td/mtproto/DhCallback.h"
#include "td/mtproto/DhHandshake.h"
#include "td/mtproto/KDF.h"
#include "td/mtproto/mtproto_api.h"
#include "td/mtproto/utils.h"

#include "td/utils/as.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"
#include "td/utils/tl_parsers.h"

#include <algorithm>

namespace td {
namespace mtproto {

template <class T>
static Result<typename T::ReturnType> fetch_result(Slice message, bool check_end = true) {
  TlParser parser(message);
  auto result = T::fetch_result(parser);

  if (check_end) {
    parser.fetch_end();
  }
  const char *error = parser.get_error();
  if (error != nullptr) {
    LOG(ERROR) << "Can't parse: " << format::as_hex_dump<4>(message);
    return Status::Error(500, Slice(error));
  }

  return std::move(result);
}

AuthKeyHandshake::AuthKeyHandshake(int32 dc_id, int32 expires_in)
    : mode_(expires_in == 0 ? Mode::Main : Mode::Temp)
    , dc_id_(dc_id)
    , expires_in_(expires_in)
    , start_time_(Time::now())
    , timeout_in_(1e9) {
}

void AuthKeyHandshake::set_timeout_in(double timeout_in) {
  start_time_ = Time::now();
  timeout_in_ = timeout_in;
}

void AuthKeyHandshake::clear() {
  last_query_ = string();
  state_ = State::Start;
  start_time_ = Time::now();
  timeout_in_ = 1e9;
}

bool AuthKeyHandshake::is_ready_for_finish() const {
  return state_ == State::Finish;
}

void AuthKeyHandshake::on_finish() {
  clear();
}

template <class T>
string AuthKeyHandshake::store_object(const T &object) {
  auto storer = TLObjectStorer<T>(object);
  size_t size = storer.size();
  string result(size, '\0');
  auto real_size = storer.store(MutableSlice(result).ubegin());
  CHECK(real_size == size);
  return result;
}

Status AuthKeyHandshake::on_res_pq(Slice message, Callback *connection, PublicRsaKeyInterface *public_rsa_key) {
  if (Time::now() >= start_time_ + timeout_in_ * 0.6) {
    return Status::Error("Handshake ResPQ timeout expired");
  }

  TRY_RESULT(res_pq, fetch_result<mtproto_api::req_pq_multi>(message, false));
  if (res_pq->nonce_ != nonce_) {
    return Status::Error("Nonce mismatch");
  }

  server_nonce_ = res_pq->server_nonce_;

  auto r_rsa_key = public_rsa_key->get_rsa_key(res_pq->server_public_key_fingerprints_);
  if (r_rsa_key.is_error()) {
    public_rsa_key->drop_keys();
    return r_rsa_key.move_as_error();
  }
  auto rsa_key = r_rsa_key.move_as_ok();

  string p;
  string q;
  if (pq_factorize(res_pq->pq_, &p, &q) == -1) {
    return Status::Error("Failed to factorize");
  }

  Random::secure_bytes(new_nonce_.raw, sizeof(new_nonce_));

  string data;
  switch (mode_) {
    case Mode::Main:
      data = store_object(mtproto_api::p_q_inner_data_dc(res_pq->pq_, p, q, nonce_, server_nonce_, new_nonce_, dc_id_));
      break;
    case Mode::Temp:
      data = store_object(mtproto_api::p_q_inner_data_temp_dc(res_pq->pq_, p, q, nonce_, server_nonce_, new_nonce_,
                                                              dc_id_, expires_in_));
      expires_at_ = Time::now() + expires_in_;
      break;
    default:
      UNREACHABLE();
  }

  string encrypted_data(256, '\0');
  auto data_size = data.size();
  if (data_size > 144) {
    return Status::Error("Too big data");
  }

  data.resize(192);
  Random::secure_bytes(MutableSlice(data).substr(data_size));

  while (true) {
    string aes_key(32, '\0');
    Random::secure_bytes(MutableSlice(aes_key));

    string data_with_hash = PSTRING() << data << sha256(aes_key + data);
    std::reverse(data_with_hash.begin(), data_with_hash.begin() + data.size());

    string decrypted_data(256, '\0');
    string aes_iv(32, '\0');
    aes_ige_encrypt(aes_key, aes_iv, data_with_hash, MutableSlice(decrypted_data).substr(32));

    auto hash = sha256(MutableSlice(decrypted_data).substr(32));
    for (size_t i = 0; i < 32; i++) {
      decrypted_data[i] = static_cast<char>(aes_key[i] ^ hash[i]);
    }

    if (rsa_key.rsa.encrypt(decrypted_data, encrypted_data)) {
      break;
    }
  }

  mtproto_api::req_DH_params req_dh_params(nonce_, server_nonce_, p, q, rsa_key.fingerprint, encrypted_data);
  send(connection, create_function_storer(req_dh_params));
  state_ = State::ServerDHParams;
  return Status::OK();
}

Status AuthKeyHandshake::on_server_dh_params(Slice message, Callback *connection, DhCallback *dh_callback) {
  if (Time::now() >= start_time_ + timeout_in_ * 0.8) {
    return Status::Error("Handshake DH params timeout expired");
  }

  TRY_RESULT(dh_params, fetch_result<mtproto_api::req_DH_params>(message, false));

  // server_DH_params_ok#d0e8075c nonce:int128 server_nonce:int128 encrypted_answer:string = Server_DH_Params;
  if (dh_params->nonce_ != nonce_) {
    return Status::Error("Nonce mismatch");
  }
  if (dh_params->server_nonce_ != server_nonce_) {
    return Status::Error("Server nonce mismatch");
  }
  if (dh_params->encrypted_answer_.size() & 15) {
    return Status::Error("Bad padding for encrypted part");
  }

  UInt256 tmp_aes_key;
  UInt256 tmp_aes_iv;
  tmp_KDF(server_nonce_, new_nonce_, &tmp_aes_key, &tmp_aes_iv);
  auto save_tmp_aes_iv = tmp_aes_iv;
  // encrypted_answer := AES256_ige_encrypt (answer_with_hash, tmp_aes_key, tmp_aes_iv);
  MutableSlice answer(const_cast<char *>(dh_params->encrypted_answer_.begin()), dh_params->encrypted_answer_.size());
  aes_ige_decrypt(as_slice(tmp_aes_key), as_mutable_slice(tmp_aes_iv), answer, answer);
  tmp_aes_iv = save_tmp_aes_iv;

  // answer_with_hash := SHA1(answer) + answer + (0-15 random bytes)
  TlParser answer_parser(answer);
  UInt<160> answer_sha1 = answer_parser.fetch_binary<UInt<160>>();
  int32 id = answer_parser.fetch_int();
  if (id != mtproto_api::server_DH_inner_data::ID) {
    return Status::Error("Failed to fetch server_DH_inner_data");
  }
  mtproto_api::server_DH_inner_data dh_inner_data(answer_parser);
  if (answer_parser.get_error() != nullptr) {
    return Status::Error("Failed to fetch server_DH_inner_data");
  }

  size_t pad = answer_parser.get_left_len();
  if (pad >= 16) {
    return Status::Error("Too much pad");
  }

  size_t dh_inner_data_size = answer.size() - pad - 20;
  UInt<160> answer_real_sha1;
  sha1(answer.substr(20, dh_inner_data_size), answer_real_sha1.raw);
  if (answer_sha1 != answer_real_sha1) {
    return Status::Error("SHA1 mismatch");
  }

  if (dh_inner_data.nonce_ != nonce_) {
    return Status::Error("Nonce mismatch");
  }
  if (dh_inner_data.server_nonce_ != server_nonce_) {
    return Status::Error("Server nonce mismatch");
  }

  server_time_diff_ = dh_inner_data.server_time_ - Time::now();

  DhHandshake handshake;
  handshake.set_config(dh_inner_data.g_, dh_inner_data.dh_prime_);
  handshake.set_g_a(dh_inner_data.g_a_);
  TRY_STATUS(handshake.run_checks(false, dh_callback));
  string g_b = handshake.get_g_b();
  auto auth_key_params = handshake.gen_key();

  auto data = store_object(mtproto_api::client_DH_inner_data(nonce_, server_nonce_, 0, g_b));
  size_t encrypted_data_size = 20 + data.size();
  size_t encrypted_data_size_with_pad = (encrypted_data_size + 15) & -16;
  string encrypted_data_str(encrypted_data_size_with_pad, '\0');
  MutableSlice encrypted_data = encrypted_data_str;
  sha1(data, encrypted_data.ubegin());
  encrypted_data.substr(20, data.size()).copy_from(data);
  Random::secure_bytes(encrypted_data.ubegin() + encrypted_data_size,
                       encrypted_data_size_with_pad - encrypted_data_size);
  tmp_KDF(server_nonce_, new_nonce_, &tmp_aes_key, &tmp_aes_iv);
  aes_ige_encrypt(as_slice(tmp_aes_key), as_mutable_slice(tmp_aes_iv), encrypted_data, encrypted_data);

  mtproto_api::set_client_DH_params set_client_dh_params(nonce_, server_nonce_, encrypted_data);
  send(connection, create_function_storer(set_client_dh_params));

  auth_key_ = AuthKey(auth_key_params.first, std::move(auth_key_params.second));
  if (mode_ == Mode::Temp) {
    auth_key_.set_expires_at(expires_at_);
  }
  auth_key_.set_created_at(dh_inner_data.server_time_);

  server_salt_ = as<int64>(new_nonce_.raw) ^ as<int64>(server_nonce_.raw);

  state_ = State::DHGenResponse;
  return Status::OK();
}

Status AuthKeyHandshake::on_dh_gen_response(Slice message, Callback *connection) {
  TRY_RESULT(answer, fetch_result<mtproto_api::set_client_DH_params>(message, false));
  switch (answer->get_id()) {
    case mtproto_api::dh_gen_ok::ID: {
      auto dh_gen_ok = move_tl_object_as<mtproto_api::dh_gen_ok>(answer);
      if (dh_gen_ok->nonce_ != nonce_) {
        return Status::Error("Nonce mismatch");
      }
      if (dh_gen_ok->server_nonce_ != server_nonce_) {
        return Status::Error("Server nonce mismatch");
      }

      UInt<160> auth_key_sha1;
      sha1(auth_key_.key(), auth_key_sha1.raw);
      auto new_nonce_hash = sha1(PSLICE() << new_nonce_.as_slice() << '\x01' << auth_key_sha1.as_slice().substr(0, 8));
      if (dh_gen_ok->new_nonce_hash1_.as_slice() != Slice(new_nonce_hash).substr(4)) {
        return Status::Error("New nonce hash mismatch");
      }
      state_ = State::Finish;
      return Status::OK();
    }
    case mtproto_api::dh_gen_fail::ID:
      return Status::Error("DhGenFail");
    case mtproto_api::dh_gen_retry::ID:
      return Status::Error("DhGenRetry");
    default:
      UNREACHABLE();
      return Status::Error("Unknown set_client_DH_params response");
  }
}

void AuthKeyHandshake::send(Callback *connection, const Storer &storer) {
  auto size = storer.size();
  last_query_.resize(size);
  auto real_size = storer.store(MutableSlice(last_query_).ubegin());
  CHECK(real_size == size);
  do_send(connection, create_storer(Slice(last_query_)));
}

void AuthKeyHandshake::do_send(Callback *connection, const Storer &storer) {
  connection->send_no_crypto(storer);
}

void AuthKeyHandshake::resume(Callback *connection) {
  if (state_ == State::Start) {
    return on_start(connection).ignore();
  }
  if (state_ == State::Finish) {
    LOG(ERROR) << "State is Finish during resume. UNREACHABLE";
    return clear();
  }
  if (last_query_.empty()) {
    LOG(ERROR) << "Last query empty! UNREACHABLE " << state_;
    return clear();
  }
  LOG(INFO) << "Resume handshake";
  do_send(connection, create_storer(Slice(last_query_)));
}

Status AuthKeyHandshake::on_start(Callback *connection) {
  if (state_ != State::Start) {
    clear();
    return Status::Error(PSLICE() << "on_start called after start " << tag("state", state_));
  }
  Random::secure_bytes(nonce_.raw, sizeof(nonce_));
  send(connection, create_function_storer(mtproto_api::req_pq_multi(nonce_)));
  state_ = State::ResPQ;

  return Status::OK();
}

Status AuthKeyHandshake::on_message(Slice message, Callback *connection, AuthKeyHandshakeContext *context) {
  Status status = [&] {
    switch (state_) {
      case State::ResPQ:
        return on_res_pq(message, connection, context->get_public_rsa_key_interface());
      case State::ServerDHParams:
        return on_server_dh_params(message, connection, context->get_dh_callback());
      case State::DHGenResponse:
        return on_dh_gen_response(message, connection);
      default:
        UNREACHABLE();
    }
  }();
  if (status.is_error()) {
    LOG(WARNING) << "Failed to process hasdshake response in state " << state_ << ": " << status.message();
    clear();
  }
  return status;
}

StringBuilder &operator<<(StringBuilder &string_builder, const AuthKeyHandshake::State &state) {
  switch (state) {
    case AuthKeyHandshake::State::Start:
      return string_builder << "Start";
    case AuthKeyHandshake::State::ResPQ:
      return string_builder << "ResPQ";
    case AuthKeyHandshake::State::ServerDHParams:
      return string_builder << "ServerDHParams";
    case AuthKeyHandshake::State::DHGenResponse:
      return string_builder << "DHGenResponse";
    case AuthKeyHandshake::State::Finish:
      return string_builder << "Finish";
    default:
      UNREACHABLE();
  }
}

}  // namespace mtproto
}  // namespace td
