//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BotQueries.h"

#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

class SendCustomRequestQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::customRequestResult>> promise_;

 public:
  explicit SendCustomRequestQuery(Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &method, const string &parameters) {
    send_query(G()->net_query_creator().create(
        telegram_api::bots_sendCustomRequest(method, telegram_api::make_object<telegram_api::dataJSON>(parameters))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_sendCustomRequest>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    promise_.set_value(td_api::make_object<td_api::customRequestResult>(result->data_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AnswerCustomQueryQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AnswerCustomQueryQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 custom_query_id, const string &data) {
    send_query(G()->net_query_creator().create(telegram_api::bots_answerWebhookJSONQuery(
        custom_query_id, telegram_api::make_object<telegram_api::dataJSON>(data))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_answerWebhookJSONQuery>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      LOG(INFO) << "Sending answer to a custom query has failed";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetBotUpdatesStatusQuery final : public Td::ResultHandler {
 public:
  void send(int32 pending_update_count, const string &error_message) {
    send_query(
        G()->net_query_creator().create(telegram_api::help_setBotUpdatesStatus(pending_update_count, error_message)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_setBotUpdatesStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG_IF(WARNING, !result) << "Set bot updates status has failed";
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(WARNING) << "Receive error for SetBotUpdatesStatusQuery: " << status;
    }
    status.ignore();
  }
};

void send_bot_custom_query(Td *td, const string &method, const string &parameters,
                           Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise) {
  td->create_handler<SendCustomRequestQuery>(std::move(promise))->send(method, parameters);
}

void answer_bot_custom_query(Td *td, int64 custom_query_id, const string &data, Promise<Unit> &&promise) {
  td->create_handler<AnswerCustomQueryQuery>(std::move(promise))->send(custom_query_id, data);
}

void set_bot_updates_status(Td *td, int32 pending_update_count, const string &error_message, Promise<Unit> &&promise) {
  td->create_handler<SetBotUpdatesStatusQuery>()->send(pending_update_count, error_message);
  promise.set_value(Unit());
}

}  // namespace td
