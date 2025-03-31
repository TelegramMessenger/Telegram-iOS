//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SynchronousRequests.h"

#include "td/telegram/CountryInfoManager.h"
#include "td/telegram/DialogFilter.h"
#include "td/telegram/JsonValue.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/Logging.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageQuote.h"
#include "td/telegram/misc.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.hpp"
#include "td/telegram/ThemeManager.h"

#include "td/utils/filesystem.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/PathView.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/utf8.h"

#include <limits>

namespace td {

td_api::object_ptr<td_api::Object> SynchronousRequests::run_request(td_api::object_ptr<td_api::Function> &&function) {
  if (function == nullptr) {
    return td_api::make_object<td_api::error>(400, "Request is empty");
  }

  auto function_id = function->get_id();
  bool need_logging = [function_id] {
    switch (function_id) {
      case td_api::parseTextEntities::ID:
      case td_api::parseMarkdown::ID:
      case td_api::getMarkdownText::ID:
      case td_api::searchStringsByPrefix::ID:
      case td_api::checkQuickReplyShortcutName::ID:
      case td_api::getCountryFlagEmoji::ID:
      case td_api::getFileMimeType::ID:
      case td_api::getFileExtension::ID:
      case td_api::cleanFileName::ID:
      case td_api::getChatFolderDefaultIconName::ID:
      case td_api::getJsonValue::ID:
      case td_api::getJsonString::ID:
      case td_api::getThemeParametersJsonString::ID:
      case td_api::testReturnError::ID:
        return true;
      default:
        return false;
    }
  }();

  if (need_logging) {
    VLOG(td_requests) << "Receive static request: " << to_string(function);
  }

  td_api::object_ptr<td_api::Object> response;
  downcast_call(*function, [&response](auto &request) { response = SynchronousRequests::do_request(request); });
  LOG_CHECK(response != nullptr) << function_id;

  if (need_logging) {
    VLOG(td_requests) << "Sending result for static request: " << to_string(response);
  }
  return response;
}

bool SynchronousRequests::is_synchronous_request(const td_api::Function *function) {
  switch (function->get_id()) {
    case td_api::searchQuote::ID:
    case td_api::getTextEntities::ID:
    case td_api::parseTextEntities::ID:
    case td_api::parseMarkdown::ID:
    case td_api::getMarkdownText::ID:
    case td_api::searchStringsByPrefix::ID:
    case td_api::checkQuickReplyShortcutName::ID:
    case td_api::getCountryFlagEmoji::ID:
    case td_api::getFileMimeType::ID:
    case td_api::getFileExtension::ID:
    case td_api::cleanFileName::ID:
    case td_api::getLanguagePackString::ID:
    case td_api::getPhoneNumberInfoSync::ID:
    case td_api::getChatFolderDefaultIconName::ID:
    case td_api::getJsonValue::ID:
    case td_api::getJsonString::ID:
    case td_api::getThemeParametersJsonString::ID:
    case td_api::getPushReceiverId::ID:
    case td_api::setLogStream::ID:
    case td_api::getLogStream::ID:
    case td_api::setLogVerbosityLevel::ID:
    case td_api::getLogVerbosityLevel::ID:
    case td_api::getLogTags::ID:
    case td_api::setLogTagVerbosityLevel::ID:
    case td_api::getLogTagVerbosityLevel::ID:
    case td_api::addLogMessage::ID:
    case td_api::testReturnError::ID:
      return true;
    case td_api::getOption::ID:
      return OptionManager::is_synchronous_option(static_cast<const td_api::getOption *>(function)->name_);
    default:
      return false;
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::searchQuote &request) {
  if (request.text_ == nullptr || request.quote_ == nullptr) {
    return make_error(400, "Text and quote must be non-empty");
  }
  if (!check_utf8(request.text_->text_) || !check_utf8(request.quote_->text_)) {
    return make_error(400, "Strings must be encoded in UTF-8");
  }
  auto r_text_entities = get_message_entities(nullptr, std::move(request.text_->entities_), false);
  if (r_text_entities.is_error()) {
    return make_error(400, r_text_entities.error().message());
  }
  auto r_quote_entities = get_message_entities(nullptr, std::move(request.quote_->entities_), false);
  if (r_quote_entities.is_error()) {
    return make_error(400, r_quote_entities.error().message());
  }
  auto position = MessageQuote::search_quote({std::move(request.text_->text_), r_text_entities.move_as_ok()},
                                             {std::move(request.quote_->text_), r_quote_entities.move_as_ok()},
                                             request.quote_position_);
  if (position == -1) {
    return make_error(404, "Not Found");
  }
  return td_api::make_object<td_api::foundPosition>(position);
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getTextEntities &request) {
  if (!check_utf8(request.text_)) {
    return make_error(400, "Text must be encoded in UTF-8");
  }
  auto text_entities = find_entities(request.text_, false, false);
  return td_api::make_object<td_api::textEntities>(
      get_text_entities_object(nullptr, text_entities, false, std::numeric_limits<int32>::max()));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::parseTextEntities &request) {
  if (!check_utf8(request.text_)) {  // must not use clean_input_string, because \r may be used as a separator
    return make_error(400, "Text must be encoded in UTF-8");
  }
  if (request.parse_mode_ == nullptr) {
    return make_error(400, "Parse mode must be non-empty");
  }

  auto r_entities = [&]() -> Result<vector<MessageEntity>> {
    if (utf8_length(request.text_) > 65536) {
      return Status::Error("Text is too long");
    }
    switch (request.parse_mode_->get_id()) {
      case td_api::textParseModeHTML::ID:
        return parse_html(request.text_);
      case td_api::textParseModeMarkdown::ID: {
        auto version = static_cast<const td_api::textParseModeMarkdown *>(request.parse_mode_.get())->version_;
        if (version == 0 || version == 1) {
          return parse_markdown(request.text_);
        }
        if (version == 2) {
          return parse_markdown_v2(request.text_);
        }
        return Status::Error("Wrong Markdown version specified");
      }
      default:
        UNREACHABLE();
        return Status::Error(500, "Unknown parse mode");
    }
  }();
  if (r_entities.is_error()) {
    return make_error(400, PSLICE() << "Can't parse entities: " << r_entities.error().message());
  }

  return td_api::make_object<td_api::formattedText>(std::move(request.text_),
                                                    get_text_entities_object(nullptr, r_entities.ok(), false, -1));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::parseMarkdown &request) {
  if (request.text_ == nullptr) {
    return make_error(400, "Text must be non-empty");
  }

  auto r_entities = get_message_entities(nullptr, std::move(request.text_->entities_), true);
  if (r_entities.is_error()) {
    return make_error(400, r_entities.error().message());
  }
  auto entities = r_entities.move_as_ok();
  auto status = fix_formatted_text(request.text_->text_, entities, true, true, true, true, true);
  if (status.is_error()) {
    return make_error(400, status.message());
  }

  auto parsed_text = parse_markdown_v3({std::move(request.text_->text_), std::move(entities)});
  fix_formatted_text(parsed_text.text, parsed_text.entities, true, true, true, true, true).ensure();
  return get_formatted_text_object(nullptr, parsed_text, false, std::numeric_limits<int32>::max());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getOption &request) {
  if (!is_synchronous_request(&request)) {
    return make_error(400, "The option can't be get synchronously");
  }
  return OptionManager::get_option_synchronously(request.name_);
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::getMarkdownText &request) {
  if (request.text_ == nullptr) {
    return make_error(400, "Text must be non-empty");
  }

  auto r_entities = get_message_entities(nullptr, std::move(request.text_->entities_));
  if (r_entities.is_error()) {
    return make_error(400, r_entities.error().message());
  }
  auto entities = r_entities.move_as_ok();
  auto status = fix_formatted_text(request.text_->text_, entities, true, true, true, true, true);
  if (status.is_error()) {
    return make_error(400, status.message());
  }

  return get_formatted_text_object(nullptr, get_markdown_v3({std::move(request.text_->text_), std::move(entities)}),
                                   false, std::numeric_limits<int32>::max());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::searchStringsByPrefix &request) {
  if (!clean_input_string(request.query_)) {
    return make_error(400, "Strings must be encoded in UTF-8");
  }
  for (auto &str : request.strings_) {
    if (!clean_input_string(str)) {
      return make_error(400, "Strings must be encoded in UTF-8");
    }
  }
  int32 total_count = 0;
  auto result = search_strings_by_prefix(std::move(request.strings_), std::move(request.query_), request.limit_,
                                         !request.return_none_for_empty_query_, total_count);
  return td_api::make_object<td_api::foundPositions>(total_count, std::move(result));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::checkQuickReplyShortcutName &request) {
  // don't check name UTF-8 correctness
  auto status = QuickReplyManager::check_shortcut_name(request.name_);
  if (status.is_ok()) {
    return td_api::make_object<td_api::ok>();
  }
  return make_error(200, status.message());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getCountryFlagEmoji &request) {
  // don't check country code UTF-8 correctness
  return td_api::make_object<td_api::text>(CountryInfoManager::get_country_flag_emoji(request.country_code_));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getFileMimeType &request) {
  // don't check file name UTF-8 correctness
  return td_api::make_object<td_api::text>(MimeType::from_extension(PathView(request.file_name_).extension()));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getFileExtension &request) {
  // don't check MIME type UTF-8 correctness
  return td_api::make_object<td_api::text>(MimeType::to_extension(request.mime_type_));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::cleanFileName &request) {
  // don't check file name UTF-8 correctness
  return td_api::make_object<td_api::text>(clean_filename(request.file_name_));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getLanguagePackString &request) {
  return LanguagePackManager::get_language_pack_string(
      request.language_pack_database_path_, request.localization_target_, request.language_pack_id_, request.key_);
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::getPhoneNumberInfoSync &request) {
  // don't check language_code/phone number UTF-8 correctness
  return CountryInfoManager::get_phone_number_info_sync(request.language_code_,
                                                        std::move(request.phone_number_prefix_));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getPushReceiverId &request) {
  // don't check push payload UTF-8 correctness
  auto r_push_receiver_id = NotificationManager::get_push_receiver_id(request.payload_);
  if (r_push_receiver_id.is_error()) {
    VLOG(notifications) << "Failed to get push notification receiver from \"" << format::escaped(request.payload_)
                        << '"';
    return make_error(r_push_receiver_id.error().code(), r_push_receiver_id.error().message());
  }
  return td_api::make_object<td_api::pushReceiverId>(r_push_receiver_id.ok());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(
    const td_api::getChatFolderDefaultIconName &request) {
  if (request.folder_ == nullptr) {
    return make_error(400, "Chat folder must be non-empty");
  }
  if (request.folder_->icon_ != nullptr && !check_utf8(request.folder_->icon_->name_)) {
    return make_error(400, "Chat folder icon name must be encoded in UTF-8");
  }
  return td_api::make_object<td_api::chatFolderIcon>(DialogFilter::get_default_icon_name(request.folder_.get()));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::getJsonValue &request) {
  if (!check_utf8(request.json_)) {
    return make_error(400, "JSON has invalid encoding");
  }
  auto result = get_json_value(request.json_);
  if (result.is_error()) {
    return make_error(400, result.error().message());
  } else {
    return result.move_as_ok();
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getJsonString &request) {
  return td_api::make_object<td_api::text>(get_json_string(request.json_value_.get()));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(
    const td_api::getThemeParametersJsonString &request) {
  return td_api::make_object<td_api::text>(ThemeManager::get_theme_parameters_json_string(request.theme_));
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::setLogStream &request) {
  auto result = Logging::set_current_stream(std::move(request.log_stream_));
  if (result.is_ok()) {
    return td_api::make_object<td_api::ok>();
  } else {
    return make_error(400, result.message());
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getLogStream &request) {
  auto result = Logging::get_current_stream();
  if (result.is_ok()) {
    return result.move_as_ok();
  } else {
    return make_error(400, result.error().message());
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::setLogVerbosityLevel &request) {
  auto result = Logging::set_verbosity_level(static_cast<int>(request.new_verbosity_level_));
  if (result.is_ok()) {
    return td_api::make_object<td_api::ok>();
  } else {
    return make_error(400, result.message());
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getLogVerbosityLevel &request) {
  return td_api::make_object<td_api::logVerbosityLevel>(Logging::get_verbosity_level());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getLogTags &request) {
  return td_api::make_object<td_api::logTags>(Logging::get_tags());
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::setLogTagVerbosityLevel &request) {
  auto result = Logging::set_tag_verbosity_level(request.tag_, static_cast<int>(request.new_verbosity_level_));
  if (result.is_ok()) {
    return td_api::make_object<td_api::ok>();
  } else {
    return make_error(400, result.message());
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::getLogTagVerbosityLevel &request) {
  auto result = Logging::get_tag_verbosity_level(request.tag_);
  if (result.is_ok()) {
    return td_api::make_object<td_api::logVerbosityLevel>(result.ok());
  } else {
    return make_error(400, result.error().message());
  }
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(const td_api::addLogMessage &request) {
  Logging::add_message(request.verbosity_level_, request.text_);
  return td_api::make_object<td_api::ok>();
}

td_api::object_ptr<td_api::Object> SynchronousRequests::do_request(td_api::testReturnError &request) {
  if (request.error_ == nullptr) {
    return td_api::make_object<td_api::error>(404, "Not Found");
  }

  return std::move(request.error_);
}

}  // namespace td
