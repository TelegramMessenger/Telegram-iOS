//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/InputMessageText.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"

#include "td/utils/common.h"

namespace td {

bool operator==(const InputMessageText &lhs, const InputMessageText &rhs) {
  return lhs.text == rhs.text && lhs.disable_web_page_preview == rhs.disable_web_page_preview &&
         lhs.clear_draft == rhs.clear_draft;
}

bool operator!=(const InputMessageText &lhs, const InputMessageText &rhs) {
  return !(lhs == rhs);
}

Result<InputMessageText> process_input_message_text(const Td *td, DialogId dialog_id,
                                                    tl_object_ptr<td_api::InputMessageContent> &&input_message_content,
                                                    bool is_bot, bool for_draft) {
  CHECK(input_message_content != nullptr);
  CHECK(input_message_content->get_id() == td_api::inputMessageText::ID);
  auto input_message_text = static_cast<td_api::inputMessageText *>(input_message_content.get());
  string web_page_url;
  bool disable_web_page_preview = false;
  bool force_small_media = false;
  bool force_large_media = false;
  bool show_above_text = false;
  if (input_message_text->link_preview_options_ != nullptr) {
    auto options = std::move(input_message_text->link_preview_options_);
    web_page_url = std::move(options->url_);
    disable_web_page_preview = options->is_disabled_;
    force_small_media = options->force_small_media_;
    force_large_media = options->force_large_media_;
    show_above_text = options->show_above_text_;

    if (!clean_input_string(web_page_url)) {
      return Status::Error(400, "Link preview URL must be encoded in UTF-8");
    }

    if (disable_web_page_preview ||
        (dialog_id.get_type() == DialogType::Channel &&
         !td->chat_manager_->get_channel_permissions(dialog_id.get_channel_id()).can_add_web_page_previews())) {
      web_page_url.clear();
    }
    if (web_page_url.empty()) {
      force_small_media = false;
      force_large_media = false;
    }
  }
  TRY_RESULT(text, get_formatted_text(td, dialog_id, std::move(input_message_text->text_), is_bot,
                                      for_draft || !web_page_url.empty(), for_draft, for_draft));
  if (!disable_web_page_preview && web_page_url.empty() && dialog_id.get_type() == DialogType::SecretChat) {
    web_page_url = get_first_url(text).str();
  }
  return InputMessageText{
      std::move(text),   std::move(web_page_url), disable_web_page_preview,        force_small_media,
      force_large_media, show_above_text,         input_message_text->clear_draft_};
}

void InputMessageText::add_dependencies(Dependencies &dependencies) const {
  add_formatted_text_dependencies(dependencies, &text);
}

telegram_api::object_ptr<telegram_api::InputMedia> InputMessageText::get_input_media_web_page() const {
  if (web_page_url.empty()) {
    return nullptr;
  }
  auto is_optional = !text.text.empty();
  return telegram_api::make_object<telegram_api::inputMediaWebPage>(0, force_large_media, force_small_media,
                                                                    is_optional, web_page_url);
}

// used only for draft
td_api::object_ptr<td_api::inputMessageText> InputMessageText::get_input_message_text_object(
    const UserManager *user_manager) const {
  td_api::object_ptr<td_api::linkPreviewOptions> options;
  if (!web_page_url.empty() || disable_web_page_preview || force_small_media || force_large_media || show_above_text) {
    options = td_api::make_object<td_api::linkPreviewOptions>(disable_web_page_preview, web_page_url, force_small_media,
                                                              force_large_media, show_above_text);
  }
  return td_api::make_object<td_api::inputMessageText>(get_formatted_text_object(user_manager, text, false, -1),
                                                       std::move(options), clear_draft);
}

}  // namespace td
