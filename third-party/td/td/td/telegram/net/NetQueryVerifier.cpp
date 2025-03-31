//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetQueryVerifier.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/Storer.h"
#include "td/utils/utf8.h"

#include <tuple>

namespace td {

void NetQueryVerifier::verify(NetQueryPtr query, string nonce) {
  CHECK(query->is_ready());
  CHECK(query->is_error());

  int64 cloud_project_number = 0;
  auto status = [&] {
    if (!check_utf8(nonce)) {
      return Status::Error(400, "Invalid encoding");
    }
#if TD_ANDROID
    string cloud_project_number_str;
    std::tie(cloud_project_number_str, nonce) = split(nonce, '_');
    TRY_RESULT_ASSIGN(cloud_project_number, to_integer_safe<int64>(cloud_project_number_str));
    TRY_RESULT_ASSIGN(nonce, hex_decode(nonce));
    nonce = base64url_encode(nonce);
#endif
    return Status::OK();
  }();
  if (status.is_error()) {
    LOG(ERROR) << "Receive " << status;
    query->set_error(Status::Error(400, "Invalid verification nonce"));
    G()->net_query_dispatcher().dispatch(std::move(query));
    return;
  }

  auto query_id = next_query_id_++;
  Query verification_query;
  verification_query.type_ = Query::Type::Verification;
  verification_query.nonce_or_action_ = nonce;
  queries_.emplace(query_id, std::make_pair(std::move(query), std::move(verification_query)));

  send_closure(
      G()->td(), &Td::send_update,
      td_api::make_object<td_api::updateApplicationVerificationRequired>(query_id, nonce, cloud_project_number));
}

void NetQueryVerifier::check_recaptcha(NetQueryPtr query, string action, string recaptcha_key_id) {
  CHECK(query->is_ready());
  CHECK(query->is_error());

  if (!check_utf8(action) || !check_utf8(recaptcha_key_id)) {
    LOG(ERROR) << "Receive invalid reCAPTCHA parameters";
    query->set_error(Status::Error(400, "Invalid reCAPTCHA parameters"));
    G()->net_query_dispatcher().dispatch(std::move(query));
    return;
  }

  auto query_id = next_query_id_++;
  Query verification_query;
  verification_query.type_ = Query::Type::Recaptcha;
  verification_query.nonce_or_action_ = action;
  verification_query.recaptcha_key_id_ = recaptcha_key_id;
  queries_.emplace(query_id, std::make_pair(std::move(query), std::move(verification_query)));

  send_closure(
      G()->td(), &Td::send_update,
      td_api::make_object<td_api::updateApplicationRecaptchaVerificationRequired>(query_id, action, recaptcha_key_id));
}

void NetQueryVerifier::set_verification_token(int64 query_id, string &&token, Promise<Unit> &&promise) {
  auto it = queries_.find(query_id);
  if (it == queries_.end()) {
    return promise.set_error(Status::Error(400, "Verification not found"));
  }
  auto query = std::move(it->second.first);
  auto verification_query = std::move(it->second.second);
  queries_.erase(it);
  promise.set_value(Unit());

  if (token.empty()) {
    query->set_error(Status::Error(400, "VERIFICATION_FAILED"));
  } else if (verification_query.type_ == Query::Type::Verification) {
#if TD_ANDROID
    telegram_api::invokeWithGooglePlayIntegrityPrefix prefix(verification_query.nonce_or_action_, token);
#else
    telegram_api::invokeWithApnsSecretPrefix prefix(verification_query.nonce_or_action_, token);
#endif
    auto storer = DefaultStorer<telegram_api::Function>(prefix);
    string prefix_str(storer.size(), '\0');
    auto real_size = storer.store(MutableSlice(prefix_str).ubegin());
    CHECK(real_size == prefix_str.size());
    query->add_verification_prefix(prefix_str);
    query->resend();
  } else if (verification_query.type_ == Query::Type::Recaptcha) {
    telegram_api::invokeWithReCaptchaPrefix prefix(token);
    auto storer = DefaultStorer<telegram_api::Function>(prefix);
    string prefix_str(storer.size(), '\0');
    auto real_size = storer.store(MutableSlice(prefix_str).ubegin());
    CHECK(real_size == prefix_str.size());
    query->add_verification_prefix(prefix_str);
    query->resend();
  } else {
    UNREACHABLE();
  }
  G()->net_query_dispatcher().dispatch(std::move(query));
}

void NetQueryVerifier::tear_down() {
  for (auto &it : queries_) {
    it.second.first->set_error(Global::request_aborted_error());
    G()->net_query_dispatcher().dispatch(std::move(it.second.first));
  }
  queries_.clear();
  parent_.reset();
}

}  // namespace td
