//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/OrderInfo.h"

#include "td/telegram/misc.h"

#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"

namespace td {

bool operator==(const Address &lhs, const Address &rhs) {
  return lhs.country_code == rhs.country_code && lhs.state == rhs.state && lhs.city == rhs.city &&
         lhs.street_line1 == rhs.street_line1 && lhs.street_line2 == rhs.street_line2 &&
         lhs.postal_code == rhs.postal_code;
}

bool operator!=(const Address &lhs, const Address &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Address &address) {
  return string_builder << "[Address " << tag("country_code", address.country_code) << tag("state", address.state)
                        << tag("city", address.city) << tag("street_line1", address.street_line1)
                        << tag("street_line2", address.street_line2) << tag("postal_code", address.postal_code) << "]";
}

unique_ptr<Address> get_address(tl_object_ptr<telegram_api::postAddress> &&address) {
  if (address == nullptr) {
    return nullptr;
  }
  return td::make_unique<Address>(std::move(address->country_iso2_), std::move(address->state_),
                                  std::move(address->city_), std::move(address->street_line1_),
                                  std::move(address->street_line2_), std::move(address->post_code_));
}

static bool is_capital_alpha(char c) {
  return 'A' <= c && c <= 'Z';
}

Status check_country_code(string &country_code) {
  if (!clean_input_string(country_code)) {
    return Status::Error(400, "Country code must be encoded in UTF-8");
  }
  if (country_code.size() != 2 || !is_capital_alpha(country_code[0]) || !is_capital_alpha(country_code[1])) {
    return Status::Error(400, "Wrong country code specified");
  }
  return Status::OK();
}

static Status check_state(string &state) {
  if (!clean_input_string(state)) {
    return Status::Error(400, "State must be encoded in UTF-8");
  }
  return Status::OK();
}

static Status check_city(string &city) {
  if (!clean_input_string(city)) {
    return Status::Error(400, "City must be encoded in UTF-8");
  }
  return Status::OK();
}

static Status check_street_line(string &street_line) {
  if (!clean_input_string(street_line)) {
    return Status::Error(400, "Street line must be encoded in UTF-8");
  }
  return Status::OK();
}

static Status check_postal_code(string &postal_code) {
  if (!clean_input_string(postal_code)) {
    return Status::Error(400, "Postal code must be encoded in UTF-8");
  }
  return Status::OK();
}

Result<Address> get_address(td_api::object_ptr<td_api::address> &&address) {
  if (address == nullptr) {
    return Status::Error(400, "Address must be non-empty");
  }
  TRY_STATUS(check_country_code(address->country_code_));
  TRY_STATUS(check_state(address->state_));
  TRY_STATUS(check_city(address->city_));
  TRY_STATUS(check_street_line(address->street_line1_));
  TRY_STATUS(check_street_line(address->street_line2_));
  TRY_STATUS(check_postal_code(address->postal_code_));

  return Address(std::move(address->country_code_), std::move(address->state_), std::move(address->city_),
                 std::move(address->street_line1_), std::move(address->street_line2_),
                 std::move(address->postal_code_));
}

tl_object_ptr<td_api::address> get_address_object(const unique_ptr<Address> &address) {
  if (address == nullptr) {
    return nullptr;
  }
  return get_address_object(*address);
}

tl_object_ptr<td_api::address> get_address_object(const Address &address) {
  return make_tl_object<td_api::address>(address.country_code, address.state, address.city, address.street_line1,
                                         address.street_line2, address.postal_code);
}

string address_to_json(const Address &address) {
  return json_encode<std::string>(json_object([&](auto &o) {
    o("country_code", address.country_code);
    o("state", address.state);
    o("city", address.city);
    o("street_line1", address.street_line1);
    o("street_line2", address.street_line2);
    o("post_code", address.postal_code);
  }));
}

Result<Address> address_from_json(Slice json) {
  auto json_copy = json.str();
  auto r_value = json_decode(json_copy);
  if (r_value.is_error()) {
    return Status::Error(400, "Can't parse address JSON object");
  }

  auto value = r_value.move_as_ok();
  if (value.type() != JsonValue::Type::Object) {
    return Status::Error(400, "Address must be an Object");
  }

  auto &object = value.get_object();
  TRY_RESULT(country_code, object.get_optional_string_field("country_code"));
  TRY_RESULT(state, object.get_optional_string_field("state"));
  TRY_RESULT(city, object.get_optional_string_field("city"));
  TRY_RESULT(street_line1, object.get_optional_string_field("street_line1"));
  TRY_RESULT(street_line2, object.get_optional_string_field("street_line2"));
  TRY_RESULT(postal_code, object.get_optional_string_field("post_code"));

  TRY_STATUS(check_country_code(country_code));
  TRY_STATUS(check_state(state));
  TRY_STATUS(check_city(city));
  TRY_STATUS(check_street_line(street_line1));
  TRY_STATUS(check_street_line(street_line2));
  TRY_STATUS(check_postal_code(postal_code));

  return Address(std::move(country_code), std::move(state), std::move(city), std::move(street_line1),
                 std::move(street_line2), std::move(postal_code));
}

bool operator==(const OrderInfo &lhs, const OrderInfo &rhs) {
  return lhs.name == rhs.name && lhs.phone_number == rhs.phone_number && lhs.email_address == rhs.email_address &&
         ((lhs.shipping_address == nullptr && rhs.shipping_address == nullptr) ||
          (lhs.shipping_address != nullptr && rhs.shipping_address != nullptr &&
           *lhs.shipping_address == *rhs.shipping_address));
}

bool operator!=(const OrderInfo &lhs, const OrderInfo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const OrderInfo &order_info) {
  string_builder << "[OrderInfo " << tag("name", order_info.name) << tag("phone_number", order_info.phone_number)
                 << tag("email_address", order_info.email_address);
  if (order_info.shipping_address != nullptr) {
    string_builder << *order_info.shipping_address;
  }
  return string_builder << "]";
}

unique_ptr<OrderInfo> get_order_info(tl_object_ptr<telegram_api::paymentRequestedInfo> order_info) {
  if (order_info == nullptr || order_info->flags_ == 0) {
    return nullptr;
  }
  return td::make_unique<OrderInfo>(std::move(order_info->name_), std::move(order_info->phone_),
                                    std::move(order_info->email_),
                                    get_address(std::move(order_info->shipping_address_)));
}

tl_object_ptr<td_api::orderInfo> get_order_info_object(const unique_ptr<OrderInfo> &order_info) {
  if (order_info == nullptr) {
    return nullptr;
  }
  return make_tl_object<td_api::orderInfo>(order_info->name, order_info->phone_number, order_info->email_address,
                                           get_address_object(order_info->shipping_address));
}

}  // namespace td
