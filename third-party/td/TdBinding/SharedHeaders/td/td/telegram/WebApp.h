//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class WebApp {
  int64 id_ = 0;
  int64 access_hash_ = 0;
  string short_name_;
  string title_;
  string description_;
  Photo photo_;
  FileId animation_file_id_;
  int64 hash_ = 0;

  friend bool operator==(const WebApp &lhs, const WebApp &rhs);
  friend bool operator!=(const WebApp &lhs, const WebApp &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const WebApp &web_app);

 public:
  WebApp() = default;

  WebApp(Td *td, telegram_api::object_ptr<telegram_api::botApp> &&web_app, DialogId owner_dialog_id);

  bool is_empty() const;

  vector<FileId> get_file_ids(const Td *td) const;

  td_api::object_ptr<td_api::webApp> get_web_app_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const WebApp &lhs, const WebApp &rhs);
bool operator!=(const WebApp &lhs, const WebApp &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const WebApp &web_app);

}  // namespace td
