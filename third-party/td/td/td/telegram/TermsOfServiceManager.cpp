//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TermsOfServiceManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Status.h"

namespace td {

class GetTermsOfServiceUpdateQuery final : public Td::ResultHandler {
  Promise<std::pair<int32, TermsOfService>> promise_;

 public:
  explicit GetTermsOfServiceUpdateQuery(Promise<std::pair<int32, TermsOfService>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    // we don't poll terms of service before authorization
    send_query(G()->net_query_creator().create(telegram_api::help_getTermsOfServiceUpdate()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getTermsOfServiceUpdate>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    switch (result->get_id()) {
      case telegram_api::help_termsOfServiceUpdateEmpty::ID: {
        auto update = move_tl_object_as<telegram_api::help_termsOfServiceUpdateEmpty>(result);
        promise_.set_value(std::make_pair(update->expires_, TermsOfService()));
        break;
      }
      case telegram_api::help_termsOfServiceUpdate::ID: {
        auto update = move_tl_object_as<telegram_api::help_termsOfServiceUpdate>(result);
        promise_.set_value(std::make_pair(update->expires_, TermsOfService(std::move(update->terms_of_service_))));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AcceptTermsOfServiceQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AcceptTermsOfServiceQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &terms_of_service_id) {
    send_query(G()->net_query_creator().create(telegram_api::help_acceptTermsOfService(
        telegram_api::make_object<telegram_api::dataJSON>(terms_of_service_id))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_acceptTermsOfService>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.ok();
    if (!result) {
      LOG(ERROR) << "Failed to accept terms of service";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

TermsOfServiceManager::TermsOfServiceManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void TermsOfServiceManager::tear_down() {
  parent_.reset();
}

void TermsOfServiceManager::start_up() {
  init();
}

void TermsOfServiceManager::init() {
  if (G()->close_flag()) {
    return;
  }
  if (is_inited_ || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }
  is_inited_ = true;

  schedule_get_terms_of_service(0);
}

void TermsOfServiceManager::schedule_get_terms_of_service(int32 expires_in) {
  if (G()->close_flag() || !is_inited_) {
    return;
  }

  set_timeout_in(expires_in);
}

void TermsOfServiceManager::timeout_expired() {
  if (G()->close_flag() || !is_inited_) {
    return;
  }

  get_terms_of_service(
      PromiseCreator::lambda([actor_id = actor_id(this)](Result<std::pair<int32, TermsOfService>> result) {
        send_closure(actor_id, &TermsOfServiceManager::on_get_terms_of_service, std::move(result), false);
      }));
}

td_api::object_ptr<td_api::updateTermsOfService> TermsOfServiceManager::get_update_terms_of_service_object() const {
  auto terms_of_service = pending_terms_of_service_.get_terms_of_service_object();
  if (terms_of_service == nullptr) {
    return nullptr;
  }
  return td_api::make_object<td_api::updateTermsOfService>(pending_terms_of_service_.get_id().str(),
                                                           std::move(terms_of_service));
}

void TermsOfServiceManager::on_get_terms_of_service(Result<std::pair<int32, TermsOfService>> result, bool dummy) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(is_inited_);

  int32 expires_in = 0;
  if (result.is_error()) {
    expires_in = Random::fast(10, 60);
  } else {
    auto terms = result.move_as_ok();
    pending_terms_of_service_ = std::move(terms.second);
    auto update = get_update_terms_of_service_object();
    if (update == nullptr) {
      expires_in = clamp(terms.first - G()->unix_time(), 3600, 86400);
    } else {
      send_closure(G()->td(), &Td::send_update, std::move(update));
    }
  }
  if (expires_in > 0) {
    schedule_get_terms_of_service(expires_in);
  }
}

void TermsOfServiceManager::get_terms_of_service(Promise<std::pair<int32, TermsOfService>> promise) {
  td_->create_handler<GetTermsOfServiceUpdateQuery>(std::move(promise))->send();
}

void TermsOfServiceManager::accept_terms_of_service(string &&terms_of_service_id, Promise<Unit> &&promise) {
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &TermsOfServiceManager::on_accept_terms_of_service, std::move(promise));
      });
  td_->create_handler<AcceptTermsOfServiceQuery>(std::move(query_promise))->send(terms_of_service_id);
}

void TermsOfServiceManager::on_accept_terms_of_service(Promise<Unit> &&promise) {
  pending_terms_of_service_ = TermsOfService();
  promise.set_value(Unit());
  schedule_get_terms_of_service(0);
}

void TermsOfServiceManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (!is_inited_) {
    return;
  }

  auto update_terms_of_service_object = get_update_terms_of_service_object();
  if (update_terms_of_service_object != nullptr) {
    updates.push_back(std::move(update_terms_of_service_object));
  }
}

}  // namespace td
