//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReplyMarkup.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/TargetDialogTypes.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#include <limits>

namespace td {

static bool operator==(const KeyboardButton &lhs, const KeyboardButton &rhs) {
  return lhs.type == rhs.type && lhs.text == rhs.text && lhs.url == rhs.url;
}

static StringBuilder &operator<<(StringBuilder &string_builder, const KeyboardButton &keyboard_button) {
  string_builder << "Button[";
  switch (keyboard_button.type) {
    case KeyboardButton::Type::Text:
      string_builder << "Text";
      break;
    case KeyboardButton::Type::RequestPhoneNumber:
      string_builder << "RequestPhoneNumber";
      break;
    case KeyboardButton::Type::RequestLocation:
      string_builder << "RequestLocation";
      break;
    case KeyboardButton::Type::RequestPoll:
      string_builder << "RequestPoll";
      break;
    case KeyboardButton::Type::RequestPollQuiz:
      string_builder << "RequestPollQuiz";
      break;
    case KeyboardButton::Type::RequestPollRegular:
      string_builder << "RequestPollRegular";
      break;
    case KeyboardButton::Type::WebView:
      string_builder << "WebApp";
      break;
    case KeyboardButton::Type::RequestDialog:
      string_builder << "RequestChat";
      break;
    default:
      UNREACHABLE();
  }
  return string_builder << ", " << keyboard_button.text << "]";
}

static bool operator==(const InlineKeyboardButton &lhs, const InlineKeyboardButton &rhs) {
  return lhs.type == rhs.type && lhs.text == rhs.text && lhs.data == rhs.data && lhs.id == rhs.id;
}

static StringBuilder &operator<<(StringBuilder &string_builder, const InlineKeyboardButton &keyboard_button) {
  string_builder << "Button[";
  switch (keyboard_button.type) {
    case InlineKeyboardButton::Type::Url:
      string_builder << "Url";
      break;
    case InlineKeyboardButton::Type::Callback:
      string_builder << "Callback";
      break;
    case InlineKeyboardButton::Type::CallbackGame:
      string_builder << "CallbackGame";
      break;
    case InlineKeyboardButton::Type::SwitchInline:
      string_builder << "SwitchInline, target chats = " << TargetDialogTypes(keyboard_button.id);
      break;
    case InlineKeyboardButton::Type::SwitchInlineCurrentDialog:
      string_builder << "SwitchInlineCurrentChat";
      break;
    case InlineKeyboardButton::Type::Buy:
      string_builder << "Buy";
      break;
    case InlineKeyboardButton::Type::UrlAuth:
      string_builder << "UrlAuth, ID = " << keyboard_button.id;
      break;
    case InlineKeyboardButton::Type::CallbackWithPassword:
      string_builder << "CallbackWithPassword";
      break;
    case InlineKeyboardButton::Type::User:
      string_builder << "User " << keyboard_button.user_id.get();
      break;
    case InlineKeyboardButton::Type::WebView:
      string_builder << "WebView";
      break;
    case InlineKeyboardButton::Type::Copy:
      string_builder << "Copy";
      break;
    default:
      UNREACHABLE();
  }
  return string_builder << ", text = " << keyboard_button.text << ", " << keyboard_button.data << "]";
}

bool operator==(const ReplyMarkup &lhs, const ReplyMarkup &rhs) {
  if (lhs.type != rhs.type) {
    return false;
  }
  if (lhs.type == ReplyMarkup::Type::InlineKeyboard) {
    return lhs.inline_keyboard == rhs.inline_keyboard;
  }

  if (lhs.is_personal != rhs.is_personal) {
    return false;
  }
  if (lhs.placeholder != rhs.placeholder) {
    return false;
  }
  if (lhs.type != ReplyMarkup::Type::ShowKeyboard) {
    return true;
  }
  return lhs.is_persistent == rhs.is_persistent && lhs.need_resize_keyboard == rhs.need_resize_keyboard &&
         lhs.is_one_time_keyboard == rhs.is_one_time_keyboard && lhs.keyboard == rhs.keyboard;
}

bool operator!=(const ReplyMarkup &lhs, const ReplyMarkup &rhs) {
  return !(lhs == rhs);
}

StringBuilder &ReplyMarkup::print(StringBuilder &string_builder) const {
  string_builder << "ReplyMarkup[";
  switch (type) {
    case ReplyMarkup::Type::InlineKeyboard:
      string_builder << "InlineKeyboard";
      break;
    case ReplyMarkup::Type::ShowKeyboard:
      string_builder << "ShowKeyboard";
      break;
    case ReplyMarkup::Type::RemoveKeyboard:
      string_builder << "RemoveKeyboard";
      break;
    case ReplyMarkup::Type::ForceReply:
      string_builder << "ForceReply";
      break;
    default:
      UNREACHABLE();
  }
  if (is_personal) {
    string_builder << ", personal";
  }
  if (!placeholder.empty()) {
    string_builder << ", placeholder \"" << placeholder << '"';
  }

  if (type == ReplyMarkup::Type::ShowKeyboard) {
    if (is_persistent) {
      string_builder << ", persistent";
    }
    if (need_resize_keyboard) {
      string_builder << ", need resize";
    }
    if (is_one_time_keyboard) {
      string_builder << ", one time";
    }
  }
  if (type == ReplyMarkup::Type::InlineKeyboard) {
    for (auto &row : inline_keyboard) {
      string_builder << ", " << row;
    }
  }
  if (type == ReplyMarkup::Type::ShowKeyboard) {
    for (auto &row : keyboard) {
      string_builder << ", " << row;
    }
  }

  string_builder << "]";
  return string_builder;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReplyMarkup &reply_markup) {
  return reply_markup.print(string_builder);
}

static KeyboardButton get_keyboard_button(tl_object_ptr<telegram_api::KeyboardButton> &&keyboard_button_ptr) {
  CHECK(keyboard_button_ptr != nullptr);

  KeyboardButton button;
  switch (keyboard_button_ptr->get_id()) {
    case telegram_api::keyboardButton::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButton>(keyboard_button_ptr);
      button.type = KeyboardButton::Type::Text;
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonRequestPhone::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonRequestPhone>(keyboard_button_ptr);
      button.type = KeyboardButton::Type::RequestPhoneNumber;
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonRequestGeoLocation::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonRequestGeoLocation>(keyboard_button_ptr);
      button.type = KeyboardButton::Type::RequestLocation;
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonRequestPoll::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonRequestPoll>(keyboard_button_ptr);
      if (keyboard_button->flags_ & telegram_api::keyboardButtonRequestPoll::QUIZ_MASK) {
        if (keyboard_button->quiz_) {
          button.type = KeyboardButton::Type::RequestPollQuiz;
        } else {
          button.type = KeyboardButton::Type::RequestPollRegular;
        }
      } else {
        button.type = KeyboardButton::Type::RequestPoll;
      }
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonSimpleWebView::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonSimpleWebView>(keyboard_button_ptr);
      auto r_url = LinkManager::check_link(keyboard_button->url_);
      if (r_url.is_error()) {
        LOG(ERROR) << "Keyboard Web App " << r_url.error().message();
        break;
      }

      button.type = KeyboardButton::Type::WebView;
      button.text = std::move(keyboard_button->text_);
      button.url = r_url.move_as_ok();
      break;
    }
    case telegram_api::keyboardButtonRequestPeer::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonRequestPeer>(keyboard_button_ptr);
      button.type = KeyboardButton::Type::RequestDialog;
      button.text = std::move(keyboard_button->text_);
      button.requested_dialog_type = td::make_unique<RequestedDialogType>(
          std::move(keyboard_button->peer_type_), keyboard_button->button_id_, keyboard_button->max_quantity_);
      break;
    }
    default:
      LOG(ERROR) << "Unsupported keyboard button: " << to_string(keyboard_button_ptr);
  }
  return button;
}

static InlineKeyboardButton get_inline_keyboard_button(
    tl_object_ptr<telegram_api::KeyboardButton> &&keyboard_button_ptr) {
  CHECK(keyboard_button_ptr != nullptr);

  InlineKeyboardButton button;
  switch (keyboard_button_ptr->get_id()) {
    case telegram_api::keyboardButtonUrl::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonUrl>(keyboard_button_ptr);
      auto r_url = LinkManager::check_link(keyboard_button->url_);
      if (r_url.is_error()) {
        LOG(ERROR) << "Inline keyboard " << r_url.error().message();
        break;
      }
      button.type = InlineKeyboardButton::Type::Url;
      button.text = std::move(keyboard_button->text_);
      button.data = r_url.move_as_ok();
      break;
    }
    case telegram_api::keyboardButtonCallback::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonCallback>(keyboard_button_ptr);
      button.type = keyboard_button->requires_password_ ? InlineKeyboardButton::Type::CallbackWithPassword
                                                        : InlineKeyboardButton::Type::Callback;
      button.text = std::move(keyboard_button->text_);
      button.data = keyboard_button->data_.as_slice().str();
      break;
    }
    case telegram_api::keyboardButtonGame::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonGame>(keyboard_button_ptr);
      button.type = InlineKeyboardButton::Type::CallbackGame;
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonSwitchInline::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonSwitchInline>(keyboard_button_ptr);
      button.type = keyboard_button->same_peer_ ? InlineKeyboardButton::Type::SwitchInlineCurrentDialog
                                                : InlineKeyboardButton::Type::SwitchInline;
      button.text = std::move(keyboard_button->text_);
      button.data = std::move(keyboard_button->query_);
      if (!keyboard_button->same_peer_) {
        button.id = TargetDialogTypes(keyboard_button->peer_types_).get_mask();
      }
      break;
    }
    case telegram_api::keyboardButtonBuy::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonBuy>(keyboard_button_ptr);
      button.type = InlineKeyboardButton::Type::Buy;
      button.text = std::move(keyboard_button->text_);
      break;
    }
    case telegram_api::keyboardButtonUrlAuth::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonUrlAuth>(keyboard_button_ptr);
      auto r_url = LinkManager::check_link(keyboard_button->url_);
      if (r_url.is_error()) {
        LOG(ERROR) << "Inline keyboard Login " << r_url.error().message();
        break;
      }
      button.type = InlineKeyboardButton::Type::UrlAuth;
      button.id = keyboard_button->button_id_;
      button.text = std::move(keyboard_button->text_);
      button.forward_text = std::move(keyboard_button->fwd_text_);
      button.data = r_url.move_as_ok();
      break;
    }
    case telegram_api::keyboardButtonUserProfile::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonUserProfile>(keyboard_button_ptr);
      auto user_id = UserId(keyboard_button->user_id_);
      if (!user_id.is_valid()) {
        LOG(ERROR) << "Receive " << user_id << " in inline keyboard";
        break;
      }
      button.type = InlineKeyboardButton::Type::User;
      button.text = std::move(keyboard_button->text_);
      button.user_id = user_id;
      break;
    }
    case telegram_api::keyboardButtonWebView::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonWebView>(keyboard_button_ptr);
      auto r_url = LinkManager::check_link(keyboard_button->url_);
      if (r_url.is_error()) {
        LOG(ERROR) << "Inline keyboard Web App " << r_url.error().message();
        break;
      }
      button.type = InlineKeyboardButton::Type::WebView;
      button.text = std::move(keyboard_button->text_);
      button.data = r_url.move_as_ok();
      break;
    }
    case telegram_api::keyboardButtonCopy::ID: {
      auto keyboard_button = move_tl_object_as<telegram_api::keyboardButtonCopy>(keyboard_button_ptr);
      button.type = InlineKeyboardButton::Type::Copy;
      button.text = std::move(keyboard_button->text_);
      button.data = std::move(keyboard_button->copy_text_);
      break;
    }
    default:
      LOG(ERROR) << "Unsupported inline keyboard button: " << to_string(keyboard_button_ptr);
  }
  return button;
}

unique_ptr<ReplyMarkup> get_reply_markup(tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup_ptr, bool is_bot,
                                         bool only_inline_keyboard, bool message_contains_mention) {
  if (reply_markup_ptr == nullptr) {
    return nullptr;
  }

  auto reply_markup = make_unique<ReplyMarkup>();
  auto constructor_id = reply_markup_ptr->get_id();
  if (only_inline_keyboard && constructor_id != telegram_api::replyInlineMarkup::ID) {
    LOG(ERROR) << "Inline keyboard expected";
    return nullptr;
  }
  switch (constructor_id) {
    case telegram_api::replyInlineMarkup::ID: {
      auto inline_markup = move_tl_object_as<telegram_api::replyInlineMarkup>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::InlineKeyboard;
      reply_markup->inline_keyboard.reserve(inline_markup->rows_.size());
      for (auto &row : inline_markup->rows_) {
        vector<InlineKeyboardButton> buttons;
        buttons.reserve(row->buttons_.size());
        for (auto &button : row->buttons_) {
          buttons.push_back(get_inline_keyboard_button(std::move(button)));
          if (buttons.back().text.empty()) {
            buttons.pop_back();
          }
        }
        if (!buttons.empty()) {
          reply_markup->inline_keyboard.push_back(std::move(buttons));
        }
      }
      if (reply_markup->inline_keyboard.empty()) {
        return nullptr;
      }
      break;
    }
    case telegram_api::replyKeyboardMarkup::ID: {
      auto keyboard_markup = move_tl_object_as<telegram_api::replyKeyboardMarkup>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::ShowKeyboard;
      reply_markup->is_persistent = keyboard_markup->persistent_;
      reply_markup->need_resize_keyboard = keyboard_markup->resize_;
      reply_markup->is_one_time_keyboard = keyboard_markup->single_use_;
      reply_markup->is_personal = keyboard_markup->selective_;
      reply_markup->placeholder = std::move(keyboard_markup->placeholder_);
      reply_markup->keyboard.reserve(keyboard_markup->rows_.size());
      for (auto &row : keyboard_markup->rows_) {
        vector<KeyboardButton> buttons;
        buttons.reserve(row->buttons_.size());
        for (auto &button : row->buttons_) {
          buttons.push_back(get_keyboard_button(std::move(button)));
          if (buttons.back().text.empty()) {
            buttons.pop_back();
          }
        }
        if (!buttons.empty()) {
          reply_markup->keyboard.push_back(std::move(buttons));
        }
      }
      if (reply_markup->keyboard.empty()) {
        return nullptr;
      }
      break;
    }
    case telegram_api::replyKeyboardHide::ID: {
      auto hide_keyboard_markup = move_tl_object_as<telegram_api::replyKeyboardHide>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::RemoveKeyboard;
      reply_markup->is_personal = hide_keyboard_markup->selective_;
      break;
    }
    case telegram_api::replyKeyboardForceReply::ID: {
      auto force_reply_markup = move_tl_object_as<telegram_api::replyKeyboardForceReply>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::ForceReply;
      reply_markup->is_personal = force_reply_markup->selective_;
      reply_markup->placeholder = std::move(force_reply_markup->placeholder_);
      break;
    }
    default:
      UNREACHABLE();
      return nullptr;
  }

  if (!is_bot && reply_markup->type != ReplyMarkup::Type::InlineKeyboard) {
    // incoming keyboard
    if (reply_markup->is_personal) {
      reply_markup->is_personal = message_contains_mention;
    } else {
      reply_markup->is_personal = true;
    }
  }

  return reply_markup;
}

static Result<KeyboardButton> get_keyboard_button(tl_object_ptr<td_api::keyboardButton> &&button,
                                                  bool request_buttons_allowed) {
  CHECK(button != nullptr);

  if (!clean_input_string(button->text_)) {
    return Status::Error(400, "Keyboard button text must be encoded in UTF-8");
  }
  if (button->text_.empty()) {
    return Status::Error(400, "Keyboard button text must be non-empty");
  }

  KeyboardButton current_button;
  current_button.text = std::move(button->text_);

  switch (button->type_ == nullptr ? td_api::keyboardButtonTypeText::ID : button->type_->get_id()) {
    case td_api::keyboardButtonTypeText::ID:
      current_button.type = KeyboardButton::Type::Text;
      break;
    case td_api::keyboardButtonTypeRequestPhoneNumber::ID:
      if (!request_buttons_allowed) {
        return Status::Error(400, "Phone number can be requested in private chats only");
      }
      current_button.type = KeyboardButton::Type::RequestPhoneNumber;
      break;
    case td_api::keyboardButtonTypeRequestLocation::ID:
      if (!request_buttons_allowed) {
        return Status::Error(400, "Location can be requested in private chats only");
      }
      current_button.type = KeyboardButton::Type::RequestLocation;
      break;
    case td_api::keyboardButtonTypeRequestPoll::ID: {
      if (!request_buttons_allowed) {
        return Status::Error(400, "Poll can be requested in private chats only");
      }
      auto *request_poll = static_cast<const td_api::keyboardButtonTypeRequestPoll *>(button->type_.get());
      if (request_poll->force_quiz_ && request_poll->force_regular_) {
        return Status::Error(400, "Can't force quiz mode and regular poll simultaneously");
      }
      if (request_poll->force_quiz_) {
        current_button.type = KeyboardButton::Type::RequestPollQuiz;
      } else if (request_poll->force_regular_) {
        current_button.type = KeyboardButton::Type::RequestPollRegular;
      } else {
        current_button.type = KeyboardButton::Type::RequestPoll;
      }
      break;
    }
    case td_api::keyboardButtonTypeWebApp::ID: {
      if (!request_buttons_allowed) {
        return Status::Error(400, "Web App buttons can be used in private chats only");
      }

      auto button_type = move_tl_object_as<td_api::keyboardButtonTypeWebApp>(button->type_);
      auto user_id = LinkManager::get_link_user_id(button_type->url_);
      if (user_id.is_valid()) {
        return Status::Error(400, "Link to a user can't be used in Web App URL buttons");
      }
      auto r_url = LinkManager::check_link(button_type->url_, true, !G()->is_test_dc());
      if (r_url.is_error()) {
        return Status::Error(400, PSLICE() << "Keyboard button Web App " << r_url.error().message());
      }
      current_button.type = KeyboardButton::Type::WebView;
      current_button.url = std::move(button_type->url_);
      break;
    }
    case td_api::keyboardButtonTypeRequestUsers::ID: {
      if (!request_buttons_allowed) {
        return Status::Error(400, "Users can be requested in private chats only");
      }
      auto button_type = move_tl_object_as<td_api::keyboardButtonTypeRequestUsers>(button->type_);
      current_button.type = KeyboardButton::Type::RequestDialog;
      current_button.requested_dialog_type = td::make_unique<RequestedDialogType>(std::move(button_type));
      break;
    }
    case td_api::keyboardButtonTypeRequestChat::ID: {
      if (!request_buttons_allowed) {
        return Status::Error(400, "Chats can be requested in private chats only");
      }
      auto button_type = move_tl_object_as<td_api::keyboardButtonTypeRequestChat>(button->type_);
      current_button.type = KeyboardButton::Type::RequestDialog;
      current_button.requested_dialog_type = td::make_unique<RequestedDialogType>(std::move(button_type));
      break;
    }
    default:
      UNREACHABLE();
  }
  return std::move(current_button);
}

static Result<InlineKeyboardButton> get_inline_keyboard_button(tl_object_ptr<td_api::inlineKeyboardButton> &&button,
                                                               bool switch_inline_buttons_allowed) {
  CHECK(button != nullptr);
  if (!clean_input_string(button->text_)) {
    return Status::Error(400, "Inline keyboard button text must be encoded in UTF-8");
  }
  if (button->text_.empty()) {
    return Status::Error(400, "Inline keyboard button text must be non-empty");
  }
  if (button->type_ == nullptr) {
    return Status::Error(400, "Inline keyboard button type must be non-empty");
  }

  InlineKeyboardButton current_button;
  current_button.text = std::move(button->text_);

  switch (button->type_->get_id()) {
    case td_api::inlineKeyboardButtonTypeUrl::ID: {
      auto button_type = move_tl_object_as<td_api::inlineKeyboardButtonTypeUrl>(button->type_);
      auto user_id = LinkManager::get_link_user_id(button_type->url_);
      if (user_id.is_valid()) {
        current_button.type = InlineKeyboardButton::Type::User;
        current_button.user_id = user_id;
        break;
      }
      auto r_url = LinkManager::check_link(button_type->url_);
      if (r_url.is_error()) {
        return Status::Error(400, PSLICE() << "Inline keyboard button " << r_url.error().message());
      }
      current_button.type = InlineKeyboardButton::Type::Url;
      current_button.data = r_url.move_as_ok();
      if (!clean_input_string(current_button.data)) {
        return Status::Error(400, "Inline keyboard button URL must be encoded in UTF-8");
      }
      break;
    }
    case td_api::inlineKeyboardButtonTypeCallback::ID: {
      auto button_type = move_tl_object_as<td_api::inlineKeyboardButtonTypeCallback>(button->type_);
      current_button.type = InlineKeyboardButton::Type::Callback;
      current_button.data = std::move(button_type->data_);
      break;
    }
    case td_api::inlineKeyboardButtonTypeCallbackGame::ID:
      current_button.type = InlineKeyboardButton::Type::CallbackGame;
      break;
    case td_api::inlineKeyboardButtonTypeCallbackWithPassword::ID:
      return Status::Error(400, "Can't use CallbackWithPassword inline button");
    case td_api::inlineKeyboardButtonTypeSwitchInline::ID: {
      auto button_type = move_tl_object_as<td_api::inlineKeyboardButtonTypeSwitchInline>(button->type_);
      if (button_type->target_chat_ == nullptr) {
        return Status::Error(400, "Target chat must be non-empty");
      }
      switch (button_type->target_chat_->get_id()) {
        case td_api::targetChatChosen::ID: {
          TRY_RESULT(types,
                     TargetDialogTypes::get_target_dialog_types(
                         static_cast<const td_api::targetChatChosen *>(button_type->target_chat_.get())->types_));
          current_button.id = types.get_mask();
          current_button.type = InlineKeyboardButton::Type::SwitchInline;
          break;
        }
        case td_api::targetChatCurrent::ID:
          current_button.type = InlineKeyboardButton::Type::SwitchInlineCurrentDialog;
          break;
        case td_api::targetChatInternalLink::ID:
          return Status::Error(400, "Unsupported target chat specified");
        default:
          UNREACHABLE();
      }
      if (!switch_inline_buttons_allowed) {
        const char *button_name = current_button.type == InlineKeyboardButton::Type::SwitchInline
                                      ? "switch_inline_query"
                                      : "switch_inline_query_current_chat";
        return Status::Error(400, PSLICE() << "Can't use " << button_name
                                           << " button in a channel chat, because users will not be able to use the "
                                              "button without knowing bot's username");
      }

      current_button.data = std::move(button_type->query_);
      if (!clean_input_string(current_button.data)) {
        return Status::Error(400, "Inline keyboard button switch inline query must be encoded in UTF-8");
      }
      break;
    }
    case td_api::inlineKeyboardButtonTypeBuy::ID:
      current_button.type = InlineKeyboardButton::Type::Buy;
      break;
    case td_api::inlineKeyboardButtonTypeLoginUrl::ID: {
      auto button_type = td_api::move_object_as<td_api::inlineKeyboardButtonTypeLoginUrl>(button->type_);
      auto user_id = LinkManager::get_link_user_id(button_type->url_);
      if (user_id.is_valid()) {
        return Status::Error(400, "Link to a user can't be used in login URL buttons");
      }
      auto r_url = LinkManager::check_link(button_type->url_, true, !G()->is_test_dc());
      if (r_url.is_error()) {
        return Status::Error(400, PSLICE() << "Inline keyboard button login " << r_url.error().message());
      }
      current_button.type = InlineKeyboardButton::Type::UrlAuth;
      current_button.data = r_url.move_as_ok();
      current_button.forward_text = std::move(button_type->forward_text_);
      if (!clean_input_string(current_button.data)) {
        return Status::Error(400, "Inline keyboard button login URL must be encoded in UTF-8");
      }
      if (!clean_input_string(current_button.forward_text)) {
        return Status::Error(400, "Inline keyboard button forward text must be encoded in UTF-8");
      }
      current_button.id = button_type->id_;
      if (current_button.id == std::numeric_limits<int64>::min() ||
          !UserId(current_button.id >= 0 ? current_button.id : -current_button.id).is_valid()) {
        return Status::Error(400, "Invalid bot_user_id specified");
      }
      break;
    }
    case td_api::inlineKeyboardButtonTypeUser::ID: {
      auto button_type = td_api::move_object_as<td_api::inlineKeyboardButtonTypeUser>(button->type_);
      current_button.type = InlineKeyboardButton::Type::User;
      current_button.user_id = UserId(button_type->user_id_);
      if (!current_button.user_id.is_valid()) {
        return Status::Error(400, "Invalid user_id specified");
      }
      break;
    }
    case td_api::inlineKeyboardButtonTypeWebApp::ID: {
      auto button_type = move_tl_object_as<td_api::inlineKeyboardButtonTypeWebApp>(button->type_);
      auto user_id = LinkManager::get_link_user_id(button_type->url_);
      if (user_id.is_valid()) {
        return Status::Error(400, "Link to a user can't be used in Web App URL buttons");
      }
      auto r_url = LinkManager::check_link(button_type->url_, true, !G()->is_test_dc());
      if (r_url.is_error()) {
        return Status::Error(400, PSLICE() << "Inline keyboard button Web App " << r_url.error().message());
      }
      current_button.type = InlineKeyboardButton::Type::WebView;
      current_button.data = r_url.move_as_ok();
      if (!clean_input_string(current_button.data)) {
        return Status::Error(400, "Inline keyboard button Web App URL must be encoded in UTF-8");
      }
      break;
    }
    case td_api::inlineKeyboardButtonTypeCopyText::ID: {
      auto button_type = move_tl_object_as<td_api::inlineKeyboardButtonTypeCopyText>(button->type_);
      current_button.type = InlineKeyboardButton::Type::Copy;
      current_button.data = std::move(button_type->text_);
      if (!clean_input_string(current_button.data)) {
        return Status::Error(400, "Inline keyboard button copied text must be encoded in UTF-8");
      }
      break;
    }
    default:
      UNREACHABLE();
  }

  return std::move(current_button);
}

Result<unique_ptr<ReplyMarkup>> get_reply_markup(td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup_ptr,
                                                 bool is_bot, bool only_inline_keyboard, bool request_buttons_allowed,
                                                 bool switch_inline_buttons_allowed) {
  CHECK(!only_inline_keyboard || !request_buttons_allowed);
  if (reply_markup_ptr == nullptr || !is_bot) {
    return nullptr;
  }

  auto reply_markup = make_unique<ReplyMarkup>();
  auto constructor_id = reply_markup_ptr->get_id();
  if (only_inline_keyboard && constructor_id != td_api::replyMarkupInlineKeyboard::ID) {
    return Status::Error(400, "Inline keyboard expected");
  }

  switch (constructor_id) {
    case td_api::replyMarkupShowKeyboard::ID: {
      auto show_keyboard_markup = move_tl_object_as<td_api::replyMarkupShowKeyboard>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::ShowKeyboard;
      reply_markup->is_persistent = show_keyboard_markup->is_persistent_;
      reply_markup->need_resize_keyboard = show_keyboard_markup->resize_keyboard_;
      reply_markup->is_one_time_keyboard = show_keyboard_markup->one_time_;
      reply_markup->is_personal = show_keyboard_markup->is_personal_;
      reply_markup->placeholder = std::move(show_keyboard_markup->input_field_placeholder_);

      reply_markup->keyboard.reserve(show_keyboard_markup->rows_.size());
      int32 total_button_count = 0;
      for (auto &row : show_keyboard_markup->rows_) {
        vector<KeyboardButton> row_buttons;
        row_buttons.reserve(row.size());

        int32 row_button_count = 0;
        for (auto &button : row) {
          if (button->text_.empty()) {
            continue;
          }

          TRY_RESULT(current_button, get_keyboard_button(std::move(button), request_buttons_allowed));

          row_buttons.push_back(std::move(current_button));
          row_button_count++;
          total_button_count++;
          if (row_button_count >= 12 || total_button_count >= 300) {
            break;
          }
        }
        if (!row_buttons.empty()) {
          reply_markup->keyboard.push_back(std::move(row_buttons));
        }
        if (total_button_count >= 300) {
          break;
        }
      }
      if (reply_markup->keyboard.empty()) {
        return nullptr;
      }
      break;
    }
    case td_api::replyMarkupInlineKeyboard::ID: {
      auto inline_keyboard_markup = move_tl_object_as<td_api::replyMarkupInlineKeyboard>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::InlineKeyboard;

      reply_markup->inline_keyboard.reserve(inline_keyboard_markup->rows_.size());
      int32 total_button_count = 0;
      for (auto &row : inline_keyboard_markup->rows_) {
        vector<InlineKeyboardButton> row_buttons;
        row_buttons.reserve(row.size());

        int32 row_button_count = 0;
        for (auto &button : row) {
          if (button->text_.empty()) {
            continue;
          }

          TRY_RESULT(current_button, get_inline_keyboard_button(std::move(button), switch_inline_buttons_allowed));

          row_buttons.push_back(std::move(current_button));
          row_button_count++;
          total_button_count++;
          if (row_button_count >= 12 || total_button_count >= 300) {
            break;
          }
        }
        if (!row_buttons.empty()) {
          reply_markup->inline_keyboard.push_back(std::move(row_buttons));
        }
        if (total_button_count >= 300) {
          break;
        }
      }
      if (reply_markup->inline_keyboard.empty()) {
        return nullptr;
      }
      break;
    }
    case td_api::replyMarkupRemoveKeyboard::ID: {
      auto remove_keyboard_markup = move_tl_object_as<td_api::replyMarkupRemoveKeyboard>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::RemoveKeyboard;
      reply_markup->is_personal = remove_keyboard_markup->is_personal_;
      break;
    }
    case td_api::replyMarkupForceReply::ID: {
      auto force_reply_markup = move_tl_object_as<td_api::replyMarkupForceReply>(reply_markup_ptr);
      reply_markup->type = ReplyMarkup::Type::ForceReply;
      reply_markup->is_personal = force_reply_markup->is_personal_;
      reply_markup->placeholder = std::move(force_reply_markup->input_field_placeholder_);
      break;
    }
    default:
      UNREACHABLE();
  }

  return std::move(reply_markup);
}

Result<unique_ptr<ReplyMarkup>> get_reply_markup(td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup_ptr,
                                                 DialogType dialog_type, bool is_bot, bool is_anonymous) {
  bool only_inline_keyboard = is_anonymous;
  bool request_buttons_allowed = dialog_type == DialogType::User;
  bool switch_inline_buttons_allowed = !is_anonymous;

  TRY_RESULT(reply_markup, get_reply_markup(std::move(reply_markup_ptr), is_bot, only_inline_keyboard,
                                            request_buttons_allowed, switch_inline_buttons_allowed));
  if (reply_markup == nullptr) {
    return nullptr;
  }
  switch (dialog_type) {
    case DialogType::User:
      if (reply_markup->type != ReplyMarkup::Type::InlineKeyboard) {
        reply_markup->is_personal = false;
      }
      break;
    case DialogType::Channel:
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
      // nothing special
      break;
    default:
      UNREACHABLE();
  }
  return std::move(reply_markup);
}

unique_ptr<ReplyMarkup> dup_reply_markup(const unique_ptr<ReplyMarkup> &reply_markup) {
  if (reply_markup == nullptr) {
    return nullptr;
  }
  auto result = make_unique<ReplyMarkup>();
  result->type = reply_markup->type;
  result->is_personal = reply_markup->is_personal;
  result->is_persistent = reply_markup->is_persistent;
  result->need_resize_keyboard = reply_markup->need_resize_keyboard;
  result->keyboard = transform(reply_markup->keyboard, [](const vector<KeyboardButton> &row) {
    return transform(row, [](const KeyboardButton &button) {
      KeyboardButton result;
      result.type = button.type;
      result.text = button.text;
      result.url = button.url;
      result.requested_dialog_type = td::make_unique<RequestedDialogType>(*button.requested_dialog_type);
      return result;
    });
  });
  result->placeholder = reply_markup->placeholder;
  result->inline_keyboard = reply_markup->inline_keyboard;
  return result;
}

static tl_object_ptr<telegram_api::KeyboardButton> get_input_keyboard_button(const KeyboardButton &keyboard_button) {
  switch (keyboard_button.type) {
    case KeyboardButton::Type::Text:
      return make_tl_object<telegram_api::keyboardButton>(keyboard_button.text);
    case KeyboardButton::Type::RequestPhoneNumber:
      return make_tl_object<telegram_api::keyboardButtonRequestPhone>(keyboard_button.text);
    case KeyboardButton::Type::RequestLocation:
      return make_tl_object<telegram_api::keyboardButtonRequestGeoLocation>(keyboard_button.text);
    case KeyboardButton::Type::RequestPoll:
      return make_tl_object<telegram_api::keyboardButtonRequestPoll>(0, false, keyboard_button.text);
    case KeyboardButton::Type::RequestPollQuiz:
      return make_tl_object<telegram_api::keyboardButtonRequestPoll>(1, true, keyboard_button.text);
    case KeyboardButton::Type::RequestPollRegular:
      return make_tl_object<telegram_api::keyboardButtonRequestPoll>(1, false, keyboard_button.text);
    case KeyboardButton::Type::WebView:
      return make_tl_object<telegram_api::keyboardButtonSimpleWebView>(keyboard_button.text, keyboard_button.url);
    case KeyboardButton::Type::RequestDialog:
      CHECK(keyboard_button.requested_dialog_type != nullptr);
      return keyboard_button.requested_dialog_type->get_input_keyboard_button_request_peer(keyboard_button.text);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

static tl_object_ptr<telegram_api::KeyboardButton> get_input_keyboard_button(
    UserManager *user_manager, const InlineKeyboardButton &keyboard_button) {
  switch (keyboard_button.type) {
    case InlineKeyboardButton::Type::Url:
      return make_tl_object<telegram_api::keyboardButtonUrl>(keyboard_button.text, keyboard_button.data);
    case InlineKeyboardButton::Type::Callback:
      return make_tl_object<telegram_api::keyboardButtonCallback>(0, false, keyboard_button.text,
                                                                  BufferSlice(keyboard_button.data));
    case InlineKeyboardButton::Type::CallbackGame:
      return make_tl_object<telegram_api::keyboardButtonGame>(keyboard_button.text);
    case InlineKeyboardButton::Type::SwitchInline: {
      int32 flags = 0;
      auto peer_types = TargetDialogTypes(keyboard_button.id).get_input_peer_types();
      if (!peer_types.empty()) {
        flags |= telegram_api::keyboardButtonSwitchInline::PEER_TYPES_MASK;
      }
      return make_tl_object<telegram_api::keyboardButtonSwitchInline>(flags, false, keyboard_button.text,
                                                                      keyboard_button.data, std::move(peer_types));
    }
    case InlineKeyboardButton::Type::SwitchInlineCurrentDialog:
      return make_tl_object<telegram_api::keyboardButtonSwitchInline>(
          telegram_api::keyboardButtonSwitchInline::SAME_PEER_MASK, true, keyboard_button.text, keyboard_button.data,
          vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>>());
    case InlineKeyboardButton::Type::Buy:
      return make_tl_object<telegram_api::keyboardButtonBuy>(keyboard_button.text);
    case InlineKeyboardButton::Type::UrlAuth: {
      int32 flags = 0;
      int64 bot_user_id = keyboard_button.id;
      if (bot_user_id > 0) {
        flags |= telegram_api::inputKeyboardButtonUrlAuth::REQUEST_WRITE_ACCESS_MASK;
      } else {
        bot_user_id = -bot_user_id;
      }
      if (!keyboard_button.forward_text.empty()) {
        flags |= telegram_api::inputKeyboardButtonUrlAuth::FWD_TEXT_MASK;
      }
      auto r_input_user = user_manager->get_input_user(UserId(bot_user_id));
      if (r_input_user.is_error()) {
        LOG(ERROR) << "Failed to get InputUser for " << bot_user_id << ": " << r_input_user.error();
        return make_tl_object<telegram_api::keyboardButtonUrl>(keyboard_button.text, keyboard_button.data);
      }
      return make_tl_object<telegram_api::inputKeyboardButtonUrlAuth>(flags, false /*ignored*/, keyboard_button.text,
                                                                      keyboard_button.forward_text,
                                                                      keyboard_button.data, r_input_user.move_as_ok());
    }
    case InlineKeyboardButton::Type::CallbackWithPassword:
      UNREACHABLE();
      break;
    case InlineKeyboardButton::Type::User: {
      auto r_input_user = user_manager->get_input_user(keyboard_button.user_id);
      if (r_input_user.is_error()) {
        LOG(ERROR) << "Failed to get InputUser for " << keyboard_button.user_id << ": " << r_input_user.error();
        r_input_user = make_tl_object<telegram_api::inputUserEmpty>();
      }
      return make_tl_object<telegram_api::inputKeyboardButtonUserProfile>(keyboard_button.text,
                                                                          r_input_user.move_as_ok());
    }
    case InlineKeyboardButton::Type::WebView:
      return make_tl_object<telegram_api::keyboardButtonWebView>(keyboard_button.text, keyboard_button.data);
    case InlineKeyboardButton::Type::Copy:
      return make_tl_object<telegram_api::keyboardButtonCopy>(keyboard_button.text, keyboard_button.data);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

tl_object_ptr<telegram_api::ReplyMarkup> ReplyMarkup::get_input_reply_markup(UserManager *user_manager) const {
  switch (type) {
    case ReplyMarkup::Type::InlineKeyboard: {
      vector<tl_object_ptr<telegram_api::keyboardButtonRow>> rows;
      rows.reserve(inline_keyboard.size());
      for (auto &row : inline_keyboard) {
        vector<tl_object_ptr<telegram_api::KeyboardButton>> buttons;
        buttons.reserve(row.size());
        for (auto &button : row) {
          buttons.push_back(get_input_keyboard_button(user_manager, button));
        }
        rows.push_back(make_tl_object<telegram_api::keyboardButtonRow>(std::move(buttons)));
      }
      return make_tl_object<telegram_api::replyInlineMarkup>(std::move(rows));
    }
    case ReplyMarkup::Type::ShowKeyboard: {
      vector<tl_object_ptr<telegram_api::keyboardButtonRow>> rows;
      rows.reserve(keyboard.size());
      for (auto &row : keyboard) {
        vector<tl_object_ptr<telegram_api::KeyboardButton>> buttons;
        buttons.reserve(row.size());
        for (auto &button : row) {
          buttons.push_back(get_input_keyboard_button(button));
        }
        rows.push_back(make_tl_object<telegram_api::keyboardButtonRow>(std::move(buttons)));
      }
      int32 flags = 0;
      if (is_persistent) {
        flags |= telegram_api::replyKeyboardMarkup::PERSISTENT_MASK;
      }
      if (need_resize_keyboard) {
        flags |= telegram_api::replyKeyboardMarkup::RESIZE_MASK;
      }
      if (is_one_time_keyboard) {
        flags |= telegram_api::replyKeyboardMarkup::SINGLE_USE_MASK;
      }
      if (is_personal) {
        flags |= telegram_api::replyKeyboardMarkup::SELECTIVE_MASK;
      }
      if (!placeholder.empty()) {
        flags |= telegram_api::replyKeyboardMarkup::PLACEHOLDER_MASK;
      }
      return make_tl_object<telegram_api::replyKeyboardMarkup>(flags, false /*ignored*/, false /*ignored*/,
                                                               false /*ignored*/, false /*ignored*/, std::move(rows),
                                                               placeholder);
    }
    case ReplyMarkup::Type::ForceReply: {
      int32 flags = 0;
      if (is_one_time_keyboard) {
        flags |= telegram_api::replyKeyboardForceReply::SINGLE_USE_MASK;
      }
      if (is_personal) {
        flags |= telegram_api::replyKeyboardForceReply::SELECTIVE_MASK;
      }
      if (!placeholder.empty()) {
        flags |= telegram_api::replyKeyboardForceReply::PLACEHOLDER_MASK;
      }
      return make_tl_object<telegram_api::replyKeyboardForceReply>(flags, false /*ignored*/, false /*ignored*/,
                                                                   placeholder);
    }
    case ReplyMarkup::Type::RemoveKeyboard: {
      int32 flags = 0;
      if (is_personal) {
        flags |= telegram_api::replyKeyboardHide::SELECTIVE_MASK;
      }
      return make_tl_object<telegram_api::replyKeyboardHide>(flags, false /*ignored*/);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

static tl_object_ptr<td_api::keyboardButton> get_keyboard_button_object(const KeyboardButton &keyboard_button) {
  tl_object_ptr<td_api::KeyboardButtonType> type;
  switch (keyboard_button.type) {
    case KeyboardButton::Type::Text:
      type = make_tl_object<td_api::keyboardButtonTypeText>();
      break;
    case KeyboardButton::Type::RequestPhoneNumber:
      type = make_tl_object<td_api::keyboardButtonTypeRequestPhoneNumber>();
      break;
    case KeyboardButton::Type::RequestLocation:
      type = make_tl_object<td_api::keyboardButtonTypeRequestLocation>();
      break;
    case KeyboardButton::Type::RequestPoll:
      type = make_tl_object<td_api::keyboardButtonTypeRequestPoll>(false, false);
      break;
    case KeyboardButton::Type::RequestPollQuiz:
      type = make_tl_object<td_api::keyboardButtonTypeRequestPoll>(false, true);
      break;
    case KeyboardButton::Type::RequestPollRegular:
      type = make_tl_object<td_api::keyboardButtonTypeRequestPoll>(true, false);
      break;
    case KeyboardButton::Type::WebView:
      type = make_tl_object<td_api::keyboardButtonTypeWebApp>(keyboard_button.url + "#kb");
      break;
    case KeyboardButton::Type::RequestDialog:
      type = keyboard_button.requested_dialog_type->get_keyboard_button_type_object();
      break;
    default:
      UNREACHABLE();
      return nullptr;
  }
  return make_tl_object<td_api::keyboardButton>(keyboard_button.text, std::move(type));
}

static tl_object_ptr<td_api::inlineKeyboardButton> get_inline_keyboard_button_object(
    UserManager *user_manager, const InlineKeyboardButton &keyboard_button) {
  tl_object_ptr<td_api::InlineKeyboardButtonType> type;
  switch (keyboard_button.type) {
    case InlineKeyboardButton::Type::Url:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeUrl>(keyboard_button.data);
      break;
    case InlineKeyboardButton::Type::Callback:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeCallback>(keyboard_button.data);
      break;
    case InlineKeyboardButton::Type::CallbackGame:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeCallbackGame>();
      break;
    case InlineKeyboardButton::Type::SwitchInline: {
      type = make_tl_object<td_api::inlineKeyboardButtonTypeSwitchInline>(
          keyboard_button.data, td_api::make_object<td_api::targetChatChosen>(
                                    TargetDialogTypes(keyboard_button.id).get_target_chat_types_object()));
      break;
    }
    case InlineKeyboardButton::Type::SwitchInlineCurrentDialog:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeSwitchInline>(
          keyboard_button.data, td_api::make_object<td_api::targetChatCurrent>());
      break;
    case InlineKeyboardButton::Type::Buy:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeBuy>();
      break;
    case InlineKeyboardButton::Type::UrlAuth:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeLoginUrl>(keyboard_button.data, keyboard_button.id,
                                                                      keyboard_button.forward_text);
      break;
    case InlineKeyboardButton::Type::CallbackWithPassword:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeCallbackWithPassword>(keyboard_button.data);
      break;
    case InlineKeyboardButton::Type::User: {
      bool need_user = user_manager != nullptr && !user_manager->is_user_bot(user_manager->get_my_id());
      auto user_id =
          need_user ? user_manager->get_user_id_object(keyboard_button.user_id, "get_inline_keyboard_button_object")
                    : keyboard_button.user_id.get();
      type = make_tl_object<td_api::inlineKeyboardButtonTypeUser>(user_id);
      break;
    }
    case InlineKeyboardButton::Type::WebView:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeWebApp>(keyboard_button.data);
      break;
    case InlineKeyboardButton::Type::Copy:
      type = make_tl_object<td_api::inlineKeyboardButtonTypeCopyText>(keyboard_button.data);
      break;
    default:
      UNREACHABLE();
      return nullptr;
  }
  return make_tl_object<td_api::inlineKeyboardButton>(keyboard_button.text, std::move(type));
}

tl_object_ptr<td_api::ReplyMarkup> ReplyMarkup::get_reply_markup_object(UserManager *user_manager) const {
  switch (type) {
    case ReplyMarkup::Type::InlineKeyboard: {
      vector<vector<tl_object_ptr<td_api::inlineKeyboardButton>>> rows;
      rows.reserve(inline_keyboard.size());
      for (auto &row : inline_keyboard) {
        vector<tl_object_ptr<td_api::inlineKeyboardButton>> buttons;
        buttons.reserve(row.size());
        for (auto &button : row) {
          buttons.push_back(get_inline_keyboard_button_object(user_manager, button));
        }
        rows.push_back(std::move(buttons));
      }

      return make_tl_object<td_api::replyMarkupInlineKeyboard>(std::move(rows));
    }
    case ReplyMarkup::Type::ShowKeyboard: {
      vector<vector<tl_object_ptr<td_api::keyboardButton>>> rows;
      rows.reserve(keyboard.size());
      for (auto &row : keyboard) {
        vector<tl_object_ptr<td_api::keyboardButton>> buttons;
        buttons.reserve(row.size());
        for (auto &button : row) {
          buttons.push_back(get_keyboard_button_object(button));
        }
        rows.push_back(std::move(buttons));
      }

      return make_tl_object<td_api::replyMarkupShowKeyboard>(std::move(rows), is_persistent, need_resize_keyboard,
                                                             is_one_time_keyboard, is_personal, placeholder);
    }
    case ReplyMarkup::Type::RemoveKeyboard:
      return make_tl_object<td_api::replyMarkupRemoveKeyboard>(is_personal);
    case ReplyMarkup::Type::ForceReply:
      return make_tl_object<td_api::replyMarkupForceReply>(is_personal, placeholder);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

Status ReplyMarkup::check_shared_dialog(Td *td, int32 button_id, DialogId dialog_id) const {
  for (auto &row : keyboard) {
    for (auto &button : row) {
      if (button.requested_dialog_type != nullptr && button.requested_dialog_type->get_button_id() == button_id) {
        return button.requested_dialog_type->check_shared_dialog(td, dialog_id);
      }
    }
  }
  return Status::Error(400, "Button not found");
}

Status ReplyMarkup::check_shared_dialog_count(int32 button_id, size_t count) const {
  for (auto &row : keyboard) {
    for (auto &button : row) {
      if (button.requested_dialog_type != nullptr && button.requested_dialog_type->get_button_id() == button_id) {
        return button.requested_dialog_type->check_shared_dialog_count(count);
      }
    }
  }
  return Status::Error(400, "Button not found");
}

tl_object_ptr<telegram_api::ReplyMarkup> get_input_reply_markup(UserManager *user_manager,
                                                                const unique_ptr<ReplyMarkup> &reply_markup) {
  if (reply_markup == nullptr) {
    return nullptr;
  }

  return reply_markup->get_input_reply_markup(user_manager);
}

tl_object_ptr<td_api::ReplyMarkup> get_reply_markup_object(UserManager *user_manager,
                                                           const unique_ptr<ReplyMarkup> &reply_markup) {
  if (reply_markup == nullptr) {
    return nullptr;
  }

  return reply_markup->get_reply_markup_object(user_manager);
}

void add_reply_markup_dependencies(Dependencies &dependencies, const ReplyMarkup *reply_markup) {
  if (reply_markup == nullptr) {
    return;
  }
  for (auto &row : reply_markup->inline_keyboard) {
    for (auto &button : row) {
      dependencies.add(button.user_id);
    }
  }
}

}  // namespace td
