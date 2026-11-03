//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class SynchronousRequests {
 public:
  static td_api::object_ptr<td_api::Object> run_request(td_api::object_ptr<td_api::Function> &&function);

  static bool is_synchronous_request(const td_api::Function *function);

 private:
  static td_api::object_ptr<td_api::error> make_error(int32 code, Slice error) {
    return td_api::make_object<td_api::error>(code, error.str());
  }

  template <class T>
  static td_api::object_ptr<td_api::Object> do_request(const T &request) {
    return td_api::make_object<td_api::error>(400, "The method can't be executed synchronously");
  }

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getOption &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::searchQuote &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getTextEntities &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::parseTextEntities &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::parseMarkdown &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::getMarkdownText &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::searchStringsByPrefix &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::checkQuickReplyShortcutName &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getCountryFlagEmoji &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getFileMimeType &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getFileExtension &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::cleanFileName &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getLanguagePackString &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::getPhoneNumberInfoSync &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getPushReceiverId &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getChatFolderDefaultIconName &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::getJsonValue &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getJsonString &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getThemeParametersJsonString &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::setLogStream &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getLogStream &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::setLogVerbosityLevel &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getLogVerbosityLevel &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getLogTags &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::setLogTagVerbosityLevel &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::getLogTagVerbosityLevel &request);

  static td_api::object_ptr<td_api::Object> do_request(const td_api::addLogMessage &request);

  static td_api::object_ptr<td_api::Object> do_request(td_api::testReturnError &request);
};

}  // namespace td
