//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Application.h"

#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"
#include "td/utils/tl_parsers.h"

namespace td {

class GetInviteTextQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit GetInviteTextQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_getInviteText()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getInviteText>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    promise_.set_value(std::move(result->message_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SaveAppLogQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveAppLogQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::inputAppEvent> &&input_app_event) {
    vector<telegram_api::object_ptr<telegram_api::inputAppEvent>> input_app_events;
    input_app_events.push_back(std::move(input_app_event));
    send_query(G()->net_query_creator().create_unauth(telegram_api::help_saveAppLog(std::move(input_app_events))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_saveAppLog>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(ERROR, !result) << "Receive false from help.saveAppLog";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

void get_invite_text(Td *td, Promise<string> &&promise) {
  td->create_handler<GetInviteTextQuery>(std::move(promise))->send();
}

class SaveAppLogLogEvent {
 public:
  const telegram_api::inputAppEvent *input_app_event_in_ = nullptr;
  telegram_api::object_ptr<telegram_api::inputAppEvent> input_app_event_out_;

  template <class StorerT>
  void store(StorerT &storer) const {
    input_app_event_in_->store(storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    auto buffer = parser.template fetch_string_raw<BufferSlice>(parser.get_left_len());
    TlBufferParser buffer_parser{&buffer};
    input_app_event_out_ = telegram_api::inputAppEvent::fetch(buffer_parser);
    buffer_parser.fetch_end();
    if (buffer_parser.get_error() != nullptr) {
      return parser.set_error(buffer_parser.get_error());
    }
  }
};

static void save_app_log_impl(Td *td, telegram_api::object_ptr<telegram_api::inputAppEvent> input_app_event,
                              uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    SaveAppLogLogEvent log_event;
    log_event.input_app_event_in_ = input_app_event.get();
    log_event_id =
        binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SaveAppLog, get_log_event_storer(log_event));
  }

  td->create_handler<SaveAppLogQuery>(get_erase_log_event_promise(log_event_id, std::move(promise)))
      ->send(std::move(input_app_event));
}

void save_app_log(Td *td, const string &type, DialogId dialog_id, tl_object_ptr<telegram_api::JSONValue> &&data,
                  Promise<Unit> &&promise) {
  CHECK(data != nullptr);
  auto input_app_event = telegram_api::make_object<telegram_api::inputAppEvent>(G()->server_time(), type,
                                                                                dialog_id.get(), std::move(data));
  save_app_log_impl(td, std::move(input_app_event), 0, std::move(promise));
}

void on_save_app_log_binlog_event(Td *td, BinlogEvent &&event) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(event.id_ != 0);
  CHECK(event.type_ == LogEvent::HandlerType::SaveAppLog);
  SaveAppLogLogEvent log_event;
  if (log_event_parse(log_event, event.get_data()).is_error()) {
    LOG(ERROR) << "Failed to parse application log event";
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  save_app_log_impl(td, std::move(log_event.input_app_event_out_), event.id_, Promise<Unit>());
}

}  // namespace td
