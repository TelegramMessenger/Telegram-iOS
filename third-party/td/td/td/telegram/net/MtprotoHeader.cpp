//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/MtprotoHeader.h"

#include "td/telegram/JsonValue.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/Version.h"

#include "td/tl/tl_object_store.h"

#include "td/utils/Slice.h"
#include "td/utils/tl_helpers.h"

namespace td {

namespace {

class HeaderStorer {
 public:
  HeaderStorer(const MtprotoHeader::Options &options, bool is_anonymous)
      : options(options), is_anonymous(is_anonymous) {
  }
  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    // invokeWithLayer
    store(static_cast<int32>(0xda9b0d0d), storer);
    store(MTPROTO_LAYER, storer);
    // initConnection
    store(static_cast<int32>(0xc1cd5ea9), storer);
    int32 flags = 0;
    bool have_proxy = !is_anonymous && options.proxy.type() == Proxy::Type::Mtproto;
    if (have_proxy) {
      flags |= 1 << 0;
    }
    if (!is_anonymous) {
      flags |= 1 << 1;
    }
    if (options.is_emulator) {
      flags |= 1 << 10;
    }
    store(flags, storer);
    store(options.api_id, storer);
    if (is_anonymous) {
      store(Slice("n/a"), storer);
      store(Slice("n/a"), storer);
    } else {
      store(options.device_model, storer);
      store(options.system_version, storer);
    }
    store(options.application_version, storer);
    store(options.system_language_code, storer);
    if (is_anonymous || options.language_pack.empty() ||
        LanguagePackManager::is_custom_language_code(options.language_code)) {
      store(Slice(), storer);
      store(Slice(), storer);
    } else {
      store(options.language_pack, storer);
      if (options.language_code.empty()) {
        store(Slice("en"), storer);
      } else {
        store(options.language_code, storer);
      }
    }
    if (have_proxy) {
      // inputClientProxy
      store(static_cast<int32>(0x75588b3f), storer);
      store(Slice(options.proxy.server()), storer);
      store(options.proxy.port(), storer);
    }
    if (!is_anonymous) {
      telegram_api::object_ptr<telegram_api::JSONValue> json_value;
      if (options.parameters.empty()) {
        json_value = make_tl_object<telegram_api::jsonObject>(vector<tl_object_ptr<telegram_api::jsonObjectValue>>());
      } else {
        auto parameters_copy = options.parameters;
        json_value = get_input_json_value(parameters_copy).move_as_ok();
      }
      CHECK(json_value != nullptr);
      if (json_value->get_id() == telegram_api::jsonObject::ID) {
        auto &values = static_cast<telegram_api::jsonObject *>(json_value.get())->value_;
        bool has_tz_offset = false;
        for (auto &value : values) {
          if (value->key_ == "tz_offset") {
            has_tz_offset = true;
            value->value_ = make_tl_object<telegram_api::jsonNumber>(options.tz_offset);
          }
        }
        if (!has_tz_offset) {
          values.push_back(make_tl_object<telegram_api::jsonObjectValue>(
              "tz_offset", make_tl_object<telegram_api::jsonNumber>(options.tz_offset)));
        }
      }
      TlStoreBoxedUnknown<TlStoreObject>::store(json_value, storer);
    }
  }

 private:
  const MtprotoHeader::Options &options;
  bool is_anonymous;
};

}  // namespace

string MtprotoHeader::gen_header(const MtprotoHeader::Options &options, bool is_anonymous) {
  HeaderStorer storer(options, is_anonymous);
  return serialize(storer);
}

}  // namespace td
