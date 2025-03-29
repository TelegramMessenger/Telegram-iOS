//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CountryInfoManager.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/tests.h"

static void check_phone_number_info(td::string phone_number_prefix, const td::string &country_code,
                                    const td::string &calling_code, const td::string &formatted_phone_number,
                                    bool is_anonymous = false) {
  auto result = td::CountryInfoManager::get_phone_number_info_sync(td::string(), phone_number_prefix);
  CHECK(result != nullptr);
  if (result->country_ == nullptr) {
    CHECK(country_code.empty());
  } else {
    CHECK(result->country_->country_code_ == country_code);
  }
  CHECK(result->country_calling_code_ == calling_code);
  if (result->formatted_phone_number_ != formatted_phone_number) {
    LOG(ERROR) << phone_number_prefix << ' ' << result->formatted_phone_number_ << ' ' << formatted_phone_number;
    CHECK(result->formatted_phone_number_ == formatted_phone_number);
  }
  CHECK(result->is_anonymous_ == is_anonymous);
}

TEST(CountryInfo, phone_number_info) {
  check_phone_number_info("", "", "", "");
  check_phone_number_info("aba c aba", "", "", "");

  td::string str;
  td::string reverse_str;
  for (auto i = 0; i < 256; i++) {
    str += static_cast<char>(i);
    reverse_str += static_cast<char>(255 - i);
  }
  check_phone_number_info(str, "", "", "0123456789");
  check_phone_number_info(reverse_str, "IR", "98", "765 432 10--");

  check_phone_number_info("1", "US", "1", "--- --- ----");
  check_phone_number_info("12", "US", "1", "2-- --- ----");
  check_phone_number_info("126", "US", "1", "26- --- ----");
  check_phone_number_info("128", "US", "1", "28- --- ----");
  check_phone_number_info("1289", "CA", "1", "289 --- ----");
  check_phone_number_info("1289123123", "CA", "1", "289 123 123-");
  check_phone_number_info("128912312345", "CA", "1", "289 123 12345");
  check_phone_number_info("1268", "AG", "1268", "--- ----");
  check_phone_number_info("126801", "AG", "1268", "01- ----");
  check_phone_number_info("12680123", "AG", "1268", "012 3---");
  check_phone_number_info("12680123456", "AG", "1268", "012 3456");
  check_phone_number_info("1268012345678", "AG", "1268", "012 345678");
  check_phone_number_info("7", "RU", "7", "--- --- ----");
  check_phone_number_info("71234567", "RU", "7", "123 456 7---");
  check_phone_number_info("77654321", "KZ", "7", "765 432 1- --");
  check_phone_number_info("3", "", "3", "");
  check_phone_number_info("37", "", "37", "");
  check_phone_number_info("372", "EE", "372", "---- ---");
  check_phone_number_info("42", "", "42", "");
  check_phone_number_info("420", "CZ", "420", "--- --- ---");
  check_phone_number_info("421", "SK", "421", "--- --- ---");
  check_phone_number_info("422", "", "", "422");
  check_phone_number_info("423", "LI", "423", "--- ----");
  check_phone_number_info("424", "YL", "42", "4");
  check_phone_number_info("4241234567890", "YL", "42", "41234567890");
  check_phone_number_info("4", "", "4", "");
  check_phone_number_info("49", "DE", "49", "");
  check_phone_number_info("491", "DE", "49", "1");
  check_phone_number_info("492", "DE", "49", "2");
  check_phone_number_info("4915", "DE", "49", "15");
  check_phone_number_info("4916", "DE", "49", "16");
  check_phone_number_info("4917", "DE", "49", "17");
  check_phone_number_info("4918", "DE", "49", "18");
  check_phone_number_info("493", "DE", "49", "3");
  check_phone_number_info("4936", "DE", "49", "36");
  check_phone_number_info("49360", "DE", "49", "360");
  check_phone_number_info("493601", "DE", "49", "3601");
  check_phone_number_info("4936014", "DE", "49", "36014");
  check_phone_number_info("4936015", "DE", "49", "36015");
  check_phone_number_info("493601419", "DE", "49", "3601419");
  check_phone_number_info("4936014198", "DE", "49", "36014198");
  check_phone_number_info("49360141980", "DE", "49", "360141980");
  check_phone_number_info("841234567890", "VN", "84", "1234567890");
  check_phone_number_info("31", "NL", "31", "- -- -- -- --");
  check_phone_number_info("318", "NL", "31", "8 -- -- -- --");
  check_phone_number_info("319", "NL", "31", "9 -- -- -- --");
  check_phone_number_info("3196", "NL", "31", "9 6- -- -- --");
  check_phone_number_info("3197", "NL", "31", "9 7- -- -- --");
  check_phone_number_info("3198", "NL", "31", "9 8- -- -- --");
  check_phone_number_info("88", "", "88", "");
  check_phone_number_info("888", "FT", "888", "---- ----", true);
  check_phone_number_info("8888", "FT", "888", "8 ---", true);
  check_phone_number_info("88888", "FT", "888", "8 8--", true);
  check_phone_number_info("888888", "FT", "888", "8 88-", true);
  check_phone_number_info("8888888", "FT", "888", "8 888", true);
  check_phone_number_info("88888888", "FT", "888", "8 8888", true);
  check_phone_number_info("888888888", "FT", "888", "8 88888", true);
  check_phone_number_info("8888888888", "FT", "888", "8 888888", true);
}
