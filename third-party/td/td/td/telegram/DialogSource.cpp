//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogSource.h"

#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

namespace td {

DialogSource DialogSource::mtproto_proxy() {
  DialogSource result;
  result.type_ = Type::MtprotoProxy;
  return result;
}

DialogSource DialogSource::public_service_announcement(string psa_type, string psa_text) {
  DialogSource result;
  result.type_ = Type::PublicServiceAnnouncement;
  result.psa_type_ = std::move(psa_type);
  result.psa_text_ = std::move(psa_text);
  return result;
}

Result<DialogSource> DialogSource::unserialize(Slice str) {
  if (str.empty()) {
    // legacy
    return mtproto_proxy();
  }
  auto type_data = split(str);
  TRY_RESULT(type, to_integer_safe<int32>(type_data.first));
  switch (type) {
    case static_cast<int32>(Type::MtprotoProxy):
      return mtproto_proxy();
    case static_cast<int32>(Type::PublicServiceAnnouncement): {
      auto data = split(type_data.second, '\x01');
      return public_service_announcement(data.first.str(), data.second.str());
    }
    default:
      return Status::Error("Unexpected chat source type");
  }
}

string DialogSource::serialize() const {
  switch (type_) {
    case DialogSource::Type::Membership:
      UNREACHABLE();
      return "";
    case DialogSource::Type::MtprotoProxy:
      return "1";
    case DialogSource::Type::PublicServiceAnnouncement:
      return PSTRING() << "2 " << psa_type_ << '\x01' << psa_text_;
    default:
      UNREACHABLE();
      return "";
  }
}

td_api::object_ptr<td_api::ChatSource> DialogSource::get_chat_source_object() const {
  switch (type_) {
    case DialogSource::Type::Membership:
      return nullptr;
    case DialogSource::Type::MtprotoProxy:
      return td_api::make_object<td_api::chatSourceMtprotoProxy>();
    case DialogSource::Type::PublicServiceAnnouncement:
      return td_api::make_object<td_api::chatSourcePublicServiceAnnouncement>(psa_type_, psa_text_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool operator==(const DialogSource &lhs, const DialogSource &rhs) {
  return lhs.type_ == rhs.type_ && lhs.psa_type_ == rhs.psa_type_ && lhs.psa_text_ == rhs.psa_text_;
}

bool operator!=(const DialogSource &lhs, const DialogSource &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogSource &source) {
  switch (source.type_) {
    case DialogSource::Type::Membership:
      return string_builder << "chat list";
    case DialogSource::Type::MtprotoProxy:
      return string_builder << "MTProto proxy sponsor";
    case DialogSource::Type::PublicServiceAnnouncement:
      return string_builder << "public service announcement of type " << source.psa_type_;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
