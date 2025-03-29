//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DeviceTokenManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/mtproto/DhHandshake.h"

#include "td/actor/PromiseFuture.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <type_traits>

namespace td {

template <class StorerT>
void DeviceTokenManager::TokenInfo::store(StorerT &storer) const {
  using td::store;
  bool has_other_user_ids = !other_user_ids.empty();
  bool is_sync = state == State::Sync;
  bool is_unregister = state == State::Unregister;
  bool is_register = state == State::Register;
  CHECK(state != State::Reregister);
  BEGIN_STORE_FLAGS();
  STORE_FLAG(false);
  STORE_FLAG(is_sync);
  STORE_FLAG(is_unregister);
  STORE_FLAG(is_register);
  STORE_FLAG(is_app_sandbox);
  STORE_FLAG(encrypt);
  STORE_FLAG(has_other_user_ids);
  END_STORE_FLAGS();
  store(token, storer);
  if (has_other_user_ids) {
    store(other_user_ids, storer);
  }
  if (encrypt) {
    store(encryption_key, storer);
    store(encryption_key_id, storer);
  }
}

template <class ParserT>
void DeviceTokenManager::TokenInfo::parse(ParserT &parser) {
  using td::parse;
  bool has_other_user_ids_legacy;
  bool has_other_user_ids;
  bool is_sync;
  bool is_unregister;
  bool is_register;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_other_user_ids_legacy);
  PARSE_FLAG(is_sync);
  PARSE_FLAG(is_unregister);
  PARSE_FLAG(is_register);
  PARSE_FLAG(is_app_sandbox);
  PARSE_FLAG(encrypt);
  PARSE_FLAG(has_other_user_ids);
  END_PARSE_FLAGS();
  CHECK(is_sync + is_unregister + is_register == 1);
  if (is_sync) {
    state = State::Sync;
  } else if (is_unregister) {
    state = State::Unregister;
  } else {
    state = State::Register;
  }
  parse(token, parser);
  if (has_other_user_ids_legacy) {
    vector<int32> other_user_ids_legacy;
    parse(other_user_ids_legacy, parser);
    other_user_ids = transform(other_user_ids_legacy, [](int32 user_id) { return static_cast<int64>(user_id); });
  }
  if (has_other_user_ids) {
    parse(other_user_ids, parser);
  }
  if (encrypt) {
    parse(encryption_key, parser);
    parse(encryption_key_id, parser);
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const DeviceTokenManager::TokenInfo::State &state) {
  switch (state) {
    case DeviceTokenManager::TokenInfo::State::Sync:
      return string_builder << "Synchronized";
    case DeviceTokenManager::TokenInfo::State::Unregister:
      return string_builder << "Unregister";
    case DeviceTokenManager::TokenInfo::State::Register:
      return string_builder << "Register";
    case DeviceTokenManager::TokenInfo::State::Reregister:
      return string_builder << "Reregister";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const DeviceTokenManager::TokenInfo &token_info) {
  string_builder << token_info.state << " token \"" << format::escaped(token_info.token) << "\"";
  if (!token_info.other_user_ids.empty()) {
    string_builder << ", with other users " << token_info.other_user_ids;
  }
  if (token_info.is_app_sandbox) {
    string_builder << ", sandboxed";
  }
  if (token_info.encrypt) {
    string_builder << ", encrypted with ID " << token_info.encryption_key_id;
  }
  return string_builder;
}

void DeviceTokenManager::register_device(tl_object_ptr<td_api::DeviceToken> device_token_ptr,
                                         const vector<UserId> &other_user_ids,
                                         Promise<td_api::object_ptr<td_api::pushReceiverId>> promise) {
  if (device_token_ptr == nullptr) {
    return promise.set_error(Status::Error(400, "Device token must be non-empty"));
  }
  TokenType token_type;
  string token;
  bool is_app_sandbox = false;
  bool encrypt = false;
  switch (device_token_ptr->get_id()) {
    case td_api::deviceTokenApplePush::ID: {
      auto device_token = static_cast<td_api::deviceTokenApplePush *>(device_token_ptr.get());
      token = std::move(device_token->device_token_);
      token_type = TokenType::Apns;
      is_app_sandbox = device_token->is_app_sandbox_;
      break;
    }
    case td_api::deviceTokenFirebaseCloudMessaging::ID: {
      auto device_token = static_cast<td_api::deviceTokenFirebaseCloudMessaging *>(device_token_ptr.get());
      token = std::move(device_token->token_);
      token_type = TokenType::Fcm;
      encrypt = device_token->encrypt_;
      break;
    }
    case td_api::deviceTokenMicrosoftPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenMicrosoftPush *>(device_token_ptr.get());
      token = std::move(device_token->channel_uri_);
      token_type = TokenType::Mpns;
      break;
    }
    case td_api::deviceTokenSimplePush::ID: {
      auto device_token = static_cast<td_api::deviceTokenSimplePush *>(device_token_ptr.get());
      token = std::move(device_token->endpoint_);
      token_type = TokenType::SimplePush;
      break;
    }
    case td_api::deviceTokenUbuntuPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenUbuntuPush *>(device_token_ptr.get());
      token = std::move(device_token->token_);
      token_type = TokenType::UbuntuPhone;
      break;
    }
    case td_api::deviceTokenBlackBerryPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenBlackBerryPush *>(device_token_ptr.get());
      token = std::move(device_token->token_);
      token_type = TokenType::BlackBerry;
      break;
    }
    case td_api::deviceTokenWindowsPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenWindowsPush *>(device_token_ptr.get());
      token = std::move(device_token->access_token_);
      token_type = TokenType::Wns;
      break;
    }
    case td_api::deviceTokenApplePushVoIP::ID: {
      auto device_token = static_cast<td_api::deviceTokenApplePushVoIP *>(device_token_ptr.get());
      token = std::move(device_token->device_token_);
      token_type = TokenType::ApnsVoip;
      is_app_sandbox = device_token->is_app_sandbox_;
      encrypt = device_token->encrypt_;
      break;
    }
    case td_api::deviceTokenWebPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenWebPush *>(device_token_ptr.get());
      if (device_token->endpoint_.find(',') != string::npos) {
        return promise.set_error(Status::Error(400, "Illegal endpoint value"));
      }
      if (!is_base64url(device_token->p256dh_base64url_)) {
        return promise.set_error(Status::Error(400, "Public key must be base64url-encoded"));
      }
      if (!is_base64url(device_token->auth_base64url_)) {
        return promise.set_error(Status::Error(400, "Authentication secret must be base64url-encoded"));
      }
      if (!clean_input_string(device_token->endpoint_)) {
        return promise.set_error(Status::Error(400, "Endpoint must be encoded in UTF-8"));
      }

      if (!device_token->endpoint_.empty()) {
        token = json_encode<string>(json_object([&device_token](auto &o) {
          o("endpoint", device_token->endpoint_);
          o("keys", json_object([&device_token](auto &o) {
              o("p256dh", device_token->p256dh_base64url_);
              o("auth", device_token->auth_base64url_);
            }));
        }));
      }
      token_type = TokenType::WebPush;
      break;
    }
    case td_api::deviceTokenMicrosoftPushVoIP::ID: {
      auto device_token = static_cast<td_api::deviceTokenMicrosoftPushVoIP *>(device_token_ptr.get());
      token = std::move(device_token->channel_uri_);
      token_type = TokenType::MpnsVoip;
      break;
    }
    case td_api::deviceTokenTizenPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenTizenPush *>(device_token_ptr.get());
      token = std::move(device_token->reg_id_);
      token_type = TokenType::Tizen;
      break;
    }
    case td_api::deviceTokenHuaweiPush::ID: {
      auto device_token = static_cast<td_api::deviceTokenHuaweiPush *>(device_token_ptr.get());
      token = std::move(device_token->token_);
      token_type = TokenType::Huawei;
      encrypt = device_token->encrypt_;
      break;
    }
    default:
      UNREACHABLE();
  }

  if (!clean_input_string(token)) {
    return promise.set_error(Status::Error(400, "Device token must be encoded in UTF-8"));
  }
  for (auto &other_user_id : other_user_ids) {
    if (!other_user_id.is_valid()) {
      return promise.set_error(Status::Error(400, "Invalid user_id among other user_ids"));
    }
  }
  auto input_user_ids = UserId::get_input_user_ids(other_user_ids);

  auto &info = tokens_[token_type];
  if (token.empty()) {
    if (info.token.empty()) {
      // already unregistered
      return promise.set_value(td_api::make_object<td_api::pushReceiverId>());
    }

    info.state = TokenInfo::State::Unregister;
  } else {
    if ((info.state == TokenInfo::State::Reregister || info.state == TokenInfo::State::Sync) && info.token == token &&
        info.other_user_ids == input_user_ids && info.is_app_sandbox == is_app_sandbox && encrypt == info.encrypt) {
      int64 push_token_id = encrypt ? info.encryption_key_id : G()->get_option_integer("my_id");
      return promise.set_value(td_api::make_object<td_api::pushReceiverId>(push_token_id));
    }

    info.state = TokenInfo::State::Register;
    info.token = std::move(token);
  }
  info.net_query_id = 0;
  info.other_user_ids = std::move(input_user_ids);
  info.is_app_sandbox = is_app_sandbox;
  if (encrypt != info.encrypt) {
    if (encrypt) {
      constexpr size_t ENCRYPTION_KEY_LENGTH = 256;
      constexpr auto MIN_ENCRYPTION_KEY_ID = static_cast<int64>(10000000000000ll);
      info.encryption_key.resize(ENCRYPTION_KEY_LENGTH);
      while (true) {
        Random::secure_bytes(info.encryption_key);
        info.encryption_key_id = mtproto::DhHandshake::calc_key_id(info.encryption_key);
        if (info.encryption_key_id <= -MIN_ENCRYPTION_KEY_ID || info.encryption_key_id >= MIN_ENCRYPTION_KEY_ID) {
          // ensure that encryption key ID never collide with anything
          break;
        }
      }
    } else {
      info.encryption_key.clear();
      info.encryption_key_id = 0;
    }
    info.encrypt = encrypt;
  }
  info.promise.set_value(td_api::make_object<td_api::pushReceiverId>());
  info.promise = std::move(promise);
  save_info(token_type);
}

void DeviceTokenManager::reregister_device() {
  for (int32 token_type = 1; token_type < TokenType::Size; token_type++) {
    auto &token = tokens_[token_type];
    if (token.state == TokenInfo::State::Sync && !token.token.empty()) {
      token.state = TokenInfo::State::Reregister;
    }
  }
  loop();
}

vector<std::pair<int64, Slice>> DeviceTokenManager::get_encryption_keys() const {
  vector<std::pair<int64, Slice>> result;
  for (int32 token_type = 1; token_type < TokenType::Size; token_type++) {
    auto &info = tokens_[token_type];
    if (!info.token.empty() && info.state != TokenInfo::State::Unregister) {
      if (info.encrypt) {
        result.emplace_back(info.encryption_key_id, info.encryption_key);
      } else {
        result.emplace_back(G()->get_option_integer("my_id"), Slice());
      }
    }
  }
  return result;
}

string DeviceTokenManager::get_database_key(int32 token_type) {
  return PSTRING() << "device_token" << token_type;
}

void DeviceTokenManager::start_up() {
  for (int32 token_type = 1; token_type < TokenType::Size; token_type++) {
    auto serialized = G()->td_db()->get_binlog_pmc()->get(get_database_key(token_type));
    if (serialized.empty()) {
      continue;
    }

    auto &token = tokens_[token_type];
    char c = serialized[0];
    if (c == '*') {
      auto status = unserialize(token, serialized.substr(1));
      if (status.is_error()) {
        token = TokenInfo();
        LOG(ERROR) << "Invalid serialized TokenInfo: " << format::escaped(serialized) << ' ' << status;
        continue;
      }
    } else {
      // legacy
      if (c == '+') {
        token.state = TokenInfo::State::Register;
      } else if (c == '-') {
        token.state = TokenInfo::State::Unregister;
      } else if (c == '=') {
        token.state = TokenInfo::State::Sync;
      } else {
        LOG(ERROR) << "Invalid serialized TokenInfo: " << format::escaped(serialized);
        continue;
      }
      token.token = serialized.substr(1);
    }
    LOG(INFO) << "Have device token " << token_type << "--->" << token;
    if (token.state == TokenInfo::State::Sync && !token.token.empty()) {
      token.state = TokenInfo::State::Reregister;
    }
  }
  loop();
}

void DeviceTokenManager::save_info(int32 token_type) {
  LOG(INFO) << "SET device token " << token_type << "--->" << tokens_[token_type];
  if (tokens_[token_type].token.empty()) {
    G()->td_db()->get_binlog_pmc()->erase(get_database_key(token_type));
  } else {
    G()->td_db()->get_binlog_pmc()->set(get_database_key(token_type), "*" + serialize(tokens_[token_type]));
  }
  sync_cnt_++;
  G()->td_db()->get_binlog_pmc()->force_sync(
      create_event_promise(self_closure(this, &DeviceTokenManager::dec_sync_cnt)), "DeviceTokenManager::save_info");
}

void DeviceTokenManager::dec_sync_cnt() {
  sync_cnt_--;
  loop();
}

void DeviceTokenManager::loop() {
  if (G()->close_flag() || sync_cnt_ != 0) {
    return;
  }
  for (int32 token_type = 1; token_type < TokenType::Size; token_type++) {
    auto &info = tokens_[token_type];
    if (info.state == TokenInfo::State::Sync) {
      continue;
    }
    if (info.net_query_id != 0) {
      continue;
    }
    // have to send query
    NetQueryPtr net_query;
    if (info.state == TokenInfo::State::Unregister) {
      net_query = G()->net_query_creator().create(
          telegram_api::account_unregisterDevice(token_type, info.token, vector<int64>(info.other_user_ids)));
    } else {
      int32 flags = telegram_api::account_registerDevice::NO_MUTED_MASK;
      net_query = G()->net_query_creator().create(
          telegram_api::account_registerDevice(flags, false /*ignored*/, token_type, info.token, info.is_app_sandbox,
                                               BufferSlice(info.encryption_key), vector<int64>(info.other_user_ids)));
    }
    info.net_query_id = net_query->id();
    G()->net_query_dispatcher().dispatch_with_callback(std::move(net_query), actor_shared(this, token_type));
  }
}

void DeviceTokenManager::on_result(NetQueryPtr net_query) {
  auto token_type = static_cast<TokenType>(get_link_token());
  CHECK(token_type >= 1 && token_type < TokenType::Size);
  auto &info = tokens_[token_type];
  if (info.net_query_id != net_query->id()) {
    net_query->clear();
    return;
  }
  info.net_query_id = 0;
  CHECK(info.state != TokenInfo::State::Sync);

  static_assert(std::is_same<telegram_api::account_registerDevice::ReturnType,
                             telegram_api::account_unregisterDevice::ReturnType>::value,
                "");
  auto r_flag = fetch_result<telegram_api::account_registerDevice>(std::move(net_query));
  if (r_flag.is_ok() && r_flag.ok()) {
    if (info.promise) {
      int64 push_token_id = 0;
      if (info.state == TokenInfo::State::Register) {
        if (info.encrypt) {
          push_token_id = info.encryption_key_id;
        } else {
          push_token_id = G()->get_option_integer("my_id");
        }
      }
      info.promise.set_value(td_api::make_object<td_api::pushReceiverId>(push_token_id));
    }
    if (info.state == TokenInfo::State::Unregister) {
      info.token.clear();
    }
    info.state = TokenInfo::State::Sync;
  } else {
    int32 retry_after = 0;
    if (r_flag.is_error()) {
      auto &error = r_flag.error();
      if (!G()->is_expected_error(error)) {
        LOG(ERROR) << "Failed to " << info.state << " device: " << error;
      } else {
        retry_after = Global::get_retry_after(error);
      }
      info.promise.set_error(r_flag.move_as_error());
    } else {
      info.promise.set_error(Status::Error(400, "Receive false as result of registerDevice server request"));
    }
    if (info.state == TokenInfo::State::Reregister) {
      // keep trying to reregister the token
      return set_timeout_in(clamp(retry_after, 1, 3600));
    } else if (info.state == TokenInfo::State::Register) {
      info.state = TokenInfo::State::Unregister;
    } else {
      CHECK(info.state == TokenInfo::State::Unregister);
      info.state = TokenInfo::State::Sync;
      info.token.clear();
    }
  }
  save_info(token_type);
}

}  // namespace td
