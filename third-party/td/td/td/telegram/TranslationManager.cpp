//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TranslationManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

class TranslateTextQuery final : public Td::ResultHandler {
  Promise<vector<telegram_api::object_ptr<telegram_api::textWithEntities>>> promise_;

 public:
  explicit TranslateTextQuery(Promise<vector<telegram_api::object_ptr<telegram_api::textWithEntities>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(vector<FormattedText> &&texts, const string &to_language_code) {
    int flags = telegram_api::messages_translateText::TEXT_MASK;
    auto input_texts = transform(std::move(texts), [user_manager = td_->user_manager_.get()](FormattedText &&text) {
      return get_input_text_with_entities(user_manager, std::move(text), "TranslateTextQuery");
    });
    send_query(G()->net_query_creator().create(telegram_api::messages_translateText(
        flags, nullptr, vector<int32>{}, std::move(input_texts), to_language_code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_translateText>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for TranslateTextQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr->result_));
  }

  void on_error(Status status) final {
    if (status.message() == "INPUT_TEXT_EMPTY") {
      vector<telegram_api::object_ptr<telegram_api::textWithEntities>> result;
      result.push_back(telegram_api::make_object<telegram_api::textWithEntities>(string(), Auto()));
      return promise_.set_value(std::move(result));
    }
    promise_.set_error(std::move(status));
  }
};

TranslationManager::TranslationManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void TranslationManager::tear_down() {
  parent_.reset();
}

void TranslationManager::translate_text(td_api::object_ptr<td_api::formattedText> &&text,
                                        const string &to_language_code,
                                        Promise<td_api::object_ptr<td_api::formattedText>> &&promise) {
  if (text == nullptr) {
    return promise.set_error(Status::Error(400, "Text must be non-empty"));
  }
  bool skip_bot_commands = true;
  int32 max_media_timestamp = -1;
  for (const auto &entity : text->entities_) {
    if (entity == nullptr || entity->type_ == nullptr) {
      continue;
    }

    switch (entity->type_->get_id()) {
      case td_api::textEntityTypeBotCommand::ID:
        skip_bot_commands = false;
        break;
      case td_api::textEntityTypeMediaTimestamp::ID:
        max_media_timestamp =
            td::max(max_media_timestamp,
                    static_cast<const td_api::textEntityTypeMediaTimestamp *>(entity->type_.get())->media_timestamp_);
        break;
      default:
        // nothing to do
        break;
    }
  }

  TRY_RESULT_PROMISE(promise, entities, get_message_entities(td_->user_manager_.get(), std::move(text->entities_)));
  TRY_STATUS_PROMISE(promise, fix_formatted_text(text->text_, entities, true, true, true, true, true));

  translate_text(FormattedText{std::move(text->text_), std::move(entities)}, skip_bot_commands, max_media_timestamp,
                 to_language_code, std::move(promise));
}

void TranslationManager::translate_text(FormattedText text, bool skip_bot_commands, int32 max_media_timestamp,
                                        const string &to_language_code,
                                        Promise<td_api::object_ptr<td_api::formattedText>> &&promise) {
  vector<FormattedText> texts;
  texts.push_back(std::move(text));

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), skip_bot_commands, max_media_timestamp, promise = std::move(promise)](
          Result<vector<telegram_api::object_ptr<telegram_api::textWithEntities>>> result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &TranslationManager::on_get_translated_texts, result.move_as_ok(), skip_bot_commands,
                     max_media_timestamp, std::move(promise));
      });

  td_->create_handler<TranslateTextQuery>(std::move(query_promise))->send(std::move(texts), to_language_code);
}

void TranslationManager::on_get_translated_texts(vector<telegram_api::object_ptr<telegram_api::textWithEntities>> texts,
                                                 bool skip_bot_commands, int32 max_media_timestamp,
                                                 Promise<td_api::object_ptr<td_api::formattedText>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (texts.size() != 1u) {
    if (texts.empty()) {
      return promise.set_error(Status::Error(500, "Translation failed"));
    }
    return promise.set_error(Status::Error(500, "Receive invalid number of results"));
  }
  auto formatted_text = get_formatted_text(td_->user_manager_.get(), std::move(texts[0]), max_media_timestamp == -1,
                                           true, "on_get_translated_texts");
  promise.set_value(
      get_formatted_text_object(td_->user_manager_.get(), formatted_text, skip_bot_commands, max_media_timestamp));
}

}  // namespace td
