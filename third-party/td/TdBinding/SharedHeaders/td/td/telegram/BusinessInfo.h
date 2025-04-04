//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessAwayMessage.h"
#include "td/telegram/BusinessGreetingMessage.h"
#include "td/telegram/BusinessIntro.h"
#include "td/telegram/BusinessWorkHours.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"

namespace td {

class Dependencies;
class Td;

class BusinessInfo {
 public:
  td_api::object_ptr<td_api::businessInfo> get_business_info_object(Td *td) const;

  bool is_empty() const;

  static bool set_location(unique_ptr<BusinessInfo> &business_info, DialogLocation &&location);

  static bool set_work_hours(unique_ptr<BusinessInfo> &business_info, BusinessWorkHours &&work_hours);

  static bool set_away_message(unique_ptr<BusinessInfo> &business_info, BusinessAwayMessage &&away_message);

  static bool set_greeting_message(unique_ptr<BusinessInfo> &business_info, BusinessGreetingMessage &&greeting_message);

  static bool set_intro(unique_ptr<BusinessInfo> &business_info, BusinessIntro &&intro);

  void add_dependencies(Dependencies &dependencies) const;

  vector<FileId> get_file_ids(const Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  static bool is_empty_location(const DialogLocation &location);

  DialogLocation location_;
  BusinessWorkHours work_hours_;
  BusinessAwayMessage away_message_;
  BusinessGreetingMessage greeting_message_;
  BusinessIntro intro_;
};

}  // namespace td
