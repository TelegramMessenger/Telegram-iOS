//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/InputGroupCallId.h"

namespace td {

InputGroupCallId::InputGroupCallId(const tl_object_ptr<telegram_api::inputGroupCall> &input_group_call)
    : group_call_id(input_group_call->id_), access_hash(input_group_call->access_hash_) {
}

tl_object_ptr<telegram_api::inputGroupCall> InputGroupCallId::get_input_group_call() const {
  return make_tl_object<telegram_api::inputGroupCall>(group_call_id, access_hash);
}

StringBuilder &operator<<(StringBuilder &string_builder, InputGroupCallId input_group_call_id) {
  return string_builder << "input group call " << input_group_call_id.group_call_id;
}

}  // namespace td
