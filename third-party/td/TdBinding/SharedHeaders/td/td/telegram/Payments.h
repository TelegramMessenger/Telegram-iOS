//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

void answer_shipping_query(Td *td, int64 shipping_query_id,
                           vector<tl_object_ptr<td_api::shippingOption>> &&shipping_options,
                           const string &error_message, Promise<Unit> &&promise);

void answer_pre_checkout_query(Td *td, int64 pre_checkout_query_id, const string &error_message,
                               Promise<Unit> &&promise);

void get_payment_form(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice,
                      const td_api::object_ptr<td_api::themeParameters> &theme,
                      Promise<tl_object_ptr<td_api::paymentForm>> &&promise);

void validate_order_info(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice,
                         td_api::object_ptr<td_api::orderInfo> &&order_info, bool allow_save,
                         Promise<td_api::object_ptr<td_api::validatedOrderInfo>> &&promise);

void send_payment_form(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice, int64 payment_form_id,
                       const string &order_info_id, const string &shipping_option_id,
                       const td_api::object_ptr<td_api::InputCredentials> &credentials, int64 tip_amount,
                       Promise<td_api::object_ptr<td_api::paymentResult>> &&promise);

void get_payment_receipt(Td *td, MessageFullId message_full_id,
                         Promise<tl_object_ptr<td_api::paymentReceipt>> &&promise);

void get_saved_order_info(Td *td, Promise<tl_object_ptr<td_api::orderInfo>> &&promise);

void delete_saved_order_info(Td *td, Promise<Unit> &&promise);

void delete_saved_credentials(Td *td, Promise<Unit> &&promise);

void export_invoice(Td *td, BusinessConnectionId business_connection_id,
                    td_api::object_ptr<td_api::InputMessageContent> &&invoice, Promise<string> &&promise);

void get_bank_card_info(Td *td, const string &bank_card_number,
                        Promise<td_api::object_ptr<td_api::bankCardInfo>> &&promise);

void get_collectible_info(Td *td, td_api::object_ptr<td_api::CollectibleItemType> type,
                          Promise<td_api::object_ptr<td_api::collectibleItemInfo>> &&promise);

}  // namespace td
