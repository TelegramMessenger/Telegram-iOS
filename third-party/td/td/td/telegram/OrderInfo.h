//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct Address {
  string country_code;
  string state;
  string city;
  string street_line1;
  string street_line2;
  string postal_code;

  Address() = default;
  Address(string &&country_code, string &&state, string &&city, string &&street_line1, string &&street_line2,
          string &&postal_code)
      : country_code(std::move(country_code))
      , state(std::move(state))
      , city(std::move(city))
      , street_line1(std::move(street_line1))
      , street_line2(std::move(street_line2))
      , postal_code(std::move(postal_code)) {
  }
};

struct OrderInfo {
  string name;
  string phone_number;
  string email_address;
  unique_ptr<Address> shipping_address;

  OrderInfo() = default;
  OrderInfo(string &&name, string &&phone_number, string &&email_address, unique_ptr<Address> &&shipping_address)
      : name(std::move(name))
      , phone_number(std::move(phone_number))
      , email_address(std::move(email_address))
      , shipping_address(std::move(shipping_address)) {
  }
};

bool operator==(const Address &lhs, const Address &rhs);
bool operator!=(const Address &lhs, const Address &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Address &address);

unique_ptr<Address> get_address(tl_object_ptr<telegram_api::postAddress> &&address);

Result<Address> get_address(td_api::object_ptr<td_api::address> &&address);

tl_object_ptr<td_api::address> get_address_object(const unique_ptr<Address> &address);

tl_object_ptr<td_api::address> get_address_object(const Address &address);

string address_to_json(const Address &address);

Result<Address> address_from_json(Slice json);

Status check_country_code(string &country_code);

bool operator==(const OrderInfo &lhs, const OrderInfo &rhs);
bool operator!=(const OrderInfo &lhs, const OrderInfo &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const OrderInfo &order_info);

unique_ptr<OrderInfo> get_order_info(tl_object_ptr<telegram_api::paymentRequestedInfo> order_info);

tl_object_ptr<td_api::orderInfo> get_order_info_object(const unique_ptr<OrderInfo> &order_info);

}  // namespace td
