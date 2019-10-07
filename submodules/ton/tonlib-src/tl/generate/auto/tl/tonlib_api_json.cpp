#include "auto/tl/tonlib_api_json.h"

#include "auto/tl/tonlib_api.h"
#include "auto/tl/tonlib_api.hpp"

#include "tl/tl_json.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <unordered_map>

namespace ton {
namespace tonlib_api{
  using namespace td;
Result<int32> tl_constructor_from_string(tonlib_api::KeyStoreType *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"keyStoreTypeDirectory", -378990038},
    {"keyStoreTypeInMemory", -2106848825}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(tonlib_api::LogStream *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"logStreamDefault", 1390581436},
    {"logStreamFile", -1880085930},
    {"logStreamEmpty", -499912244}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(tonlib_api::generic_AccountState *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"generic.accountStateRaw", -1387096685},
    {"generic.accountStateTestWallet", -1041955397},
    {"generic.accountStateWallet", 942582925},
    {"generic.accountStateTestGiver", 1134654598},
    {"generic.accountStateUninited", -908702008}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(tonlib_api::Object *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"accountAddress", 755613099},
    {"bip39Hints", 1012243456},
    {"config", -1538391496},
    {"data", -414733967},
    {"error", -1679978726},
    {"exportedEncryptedKey", 2024406612},
    {"exportedKey", -1449248297},
    {"exportedPemKey", 1425473725},
    {"inputKey", 869287093},
    {"key", -1978362923},
    {"keyStoreTypeDirectory", -378990038},
    {"keyStoreTypeInMemory", -2106848825},
    {"logStreamDefault", 1390581436},
    {"logStreamFile", -1880085930},
    {"logStreamEmpty", -499912244},
    {"logTags", -1604930601},
    {"logVerbosityLevel", 1734624234},
    {"ok", -722616727},
    {"options", -1924388359},
    {"sendGramsResult", 426872238},
    {"unpackedAccountAddress", 1892946998},
    {"updateSendLiteServerQuery", -1555130916},
    {"generic.accountStateRaw", -1387096685},
    {"generic.accountStateTestWallet", -1041955397},
    {"generic.accountStateWallet", 942582925},
    {"generic.accountStateTestGiver", 1134654598},
    {"generic.accountStateUninited", -908702008},
    {"internal.transactionId", -989527262},
    {"raw.accountState", 1205935434},
    {"raw.initialAccountState", 777456197},
    {"raw.message", -906281442},
    {"raw.transaction", 1887601793},
    {"raw.transactions", -2063931155},
    {"testGiver.accountState", 860930426},
    {"testWallet.accountState", 305698744},
    {"testWallet.initialAccountState", -1231516227},
    {"uninited.accountState", -918880075},
    {"wallet.accountState", -1919815977},
    {"wallet.initialAccountState", -1079249978}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(tonlib_api::Function *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"addLogMessage", 1597427692},
    {"changeLocalPassword", -1685491421},
    {"close", -1187782273},
    {"createNewKey", -1861385712},
    {"decrypt", 357991854},
    {"deleteAllKeys", 1608776483},
    {"deleteKey", -1579595571},
    {"encrypt", -1821422820},
    {"exportEncryptedKey", 155352861},
    {"exportKey", 399723440},
    {"exportPemKey", -2047752448},
    {"generic.getAccountState", -657000446},
    {"generic.sendGrams", -758801136},
    {"getBip39Hints", -1889640982},
    {"getLogStream", 1167608667},
    {"getLogTagVerbosityLevel", 951004547},
    {"getLogTags", -254449190},
    {"getLogVerbosityLevel", 594057956},
    {"importEncryptedKey", 656724958},
    {"importKey", -1607900903},
    {"importPemKey", 76385617},
    {"init", -2014661877},
    {"kdf", -1667861635},
    {"onLiteServerQueryError", -677427533},
    {"onLiteServerQueryResult", 2056444510},
    {"options.setConfig", 646497241},
    {"packAccountAddress", -1388561940},
    {"raw.getAccountAddress", -521283849},
    {"raw.getAccountState", 663706721},
    {"raw.getTransactions", 935377269},
    {"raw.sendMessage", 473889461},
    {"runTests", -2039925427},
    {"setLogStream", -1364199535},
    {"setLogTagVerbosityLevel", -2095589738},
    {"setLogVerbosityLevel", -303429678},
    {"testGiver.getAccountAddress", -540100768},
    {"testGiver.getAccountState", 267738275},
    {"testGiver.sendGrams", -1785750375},
    {"testWallet.getAccountAddress", -1557748223},
    {"testWallet.getAccountState", 654082364},
    {"testWallet.init", 419055225},
    {"testWallet.sendGrams", 1290131585},
    {"unpackAccountAddress", -682459063},
    {"wallet.getAccountAddress", -1004103180},
    {"wallet.getAccountState", 462294850},
    {"wallet.init", 1528056782},
    {"wallet.sendGrams", -1837893526}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Status from_json(tonlib_api::accountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::bip39Hints &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "words", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.words_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "config", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.config_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "blockchain_name", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blockchain_name_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "use_callbacks_for_network", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.use_callbacks_for_network_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ignore_cache", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ignore_cache_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::data &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "bytes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.bytes_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::error &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "code", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.code_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportedEncryptedKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportedKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "word_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.word_list_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportedPemKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "pem", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.pem_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::inputKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.local_password_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "public_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.public_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "secret", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.secret_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::keyStoreTypeDirectory &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "directory", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.directory_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::keyStoreTypeInMemory &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::logStreamDefault &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::logStreamFile &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "path", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.path_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_file_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_file_size_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::logStreamEmpty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::logTags &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "tags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.tags_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::logVerbosityLevel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "verbosity_level", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.verbosity_level_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::ok &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::options &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "config", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.config_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "keystore_type", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.keystore_type_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::sendGramsResult &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "sent_until", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sent_until_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "body_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.body_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::unpackedAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "bounceable", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.bounceable_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "testnet", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.testnet_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "addr", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.addr_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::updateSendLiteServerQuery &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_accountStateRaw &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_accountStateTestWallet &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_accountStateWallet &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_accountStateTestGiver &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_accountStateUninited &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::internal_transactionId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "lt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.lt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_accountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "balance", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.balance_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "code", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.code_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "frozen_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.frozen_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "sync_utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sync_utime_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_initialAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "code", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.code_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_message &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "source", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.source_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fwd_fee", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fwd_fee_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ihr_fee", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ihr_fee_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "created_lt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.created_lt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "body_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.body_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_transaction &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.utime_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fee", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fee_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "storage_fee", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.storage_fee_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "other_fee", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.other_fee_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "in_msg", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_msg_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_msgs", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_msgs_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_transactions &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "transactions", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.transactions_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "previous_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.previous_transaction_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testGiver_accountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "balance", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.balance_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "sync_utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sync_utime_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_accountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "balance", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.balance_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "sync_utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sync_utime_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_initialAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "public_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.public_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::uninited_accountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "balance", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.balance_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "frozen_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.frozen_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "sync_utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sync_utime_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_accountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "balance", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.balance_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_transaction_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "sync_utime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sync_utime_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_initialAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "public_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.public_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::addLogMessage &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "verbosity_level", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.verbosity_level_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "text", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.text_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::changeLocalPassword &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "input_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.input_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "new_local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.new_local_password_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::close &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::createNewKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.local_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "mnemonic_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.mnemonic_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "random_extra_seed", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.random_extra_seed_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::decrypt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "encrypted_data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.encrypted_data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "secret", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.secret_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::deleteAllKeys &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::deleteKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::encrypt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "decrypted_data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.decrypted_data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "secret", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.secret_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportEncryptedKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "input_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.input_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.key_password_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "input_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.input_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::exportPemKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "input_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.input_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.key_password_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_getAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::generic_sendGrams &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "private_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.private_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "source", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.source_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "amount", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.amount_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "timeout", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.timeout_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "allow_send_to_uninited", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.allow_send_to_uninited_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::getBip39Hints &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "prefix", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prefix_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::getLogStream &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::getLogTagVerbosityLevel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "tag", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.tag_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::getLogTags &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::getLogVerbosityLevel &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::importEncryptedKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.local_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.key_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "exported_encrypted_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.exported_encrypted_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::importKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.local_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "mnemonic_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.mnemonic_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "exported_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.exported_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::importPemKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.local_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.key_password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "exported_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.exported_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::init &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "options", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.options_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::kdf &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "password", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.password_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "salt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.salt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "iterations", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.iterations_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::onLiteServerQueryError &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "error", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.error_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::onLiteServerQueryResult &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "bytes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.bytes_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::options_setConfig &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "config", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.config_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::packAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_getAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "initital_account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.initital_account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_getAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_getTransactions &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "from_transaction_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.from_transaction_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::raw_sendMessage &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "initial_account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.initial_account_state_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::runTests &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "dir", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dir_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::setLogStream &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "log_stream", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.log_stream_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::setLogTagVerbosityLevel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "tag", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.tag_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "new_verbosity_level", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.new_verbosity_level_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::setLogVerbosityLevel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "new_verbosity_level", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.new_verbosity_level_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testGiver_getAccountAddress &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::testGiver_getAccountState &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(tonlib_api::testGiver_sendGrams &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "amount", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.amount_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_getAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "initital_account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.initital_account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_getAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_init &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "private_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.private_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::testWallet_sendGrams &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "private_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.private_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "amount", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.amount_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::unpackAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_getAccountAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "initital_account_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.initital_account_state_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_getAccountState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "account_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.account_address_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_init &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "private_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.private_key_, value));
    }
  }
  return Status::OK();
}
Status from_json(tonlib_api::wallet_sendGrams &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "private_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.private_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "destination", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.destination_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "valid_until", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.valid_until_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "amount", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.amount_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.message_, value));
    }
  }
  return Status::OK();
}
void to_json(JsonValueScope &jv, const tonlib_api::accountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "accountAddress");
  jo << ctie("account_address", ToJson(object.account_address_));
}
void to_json(JsonValueScope &jv, const tonlib_api::bip39Hints &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "bip39Hints");
  jo << ctie("words", ToJson(object.words_));
}
void to_json(JsonValueScope &jv, const tonlib_api::config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "config");
  jo << ctie("config", ToJson(object.config_));
  jo << ctie("blockchain_name", ToJson(object.blockchain_name_));
  jo << ctie("use_callbacks_for_network", ToJson(object.use_callbacks_for_network_));
  jo << ctie("ignore_cache", ToJson(object.ignore_cache_));
}
void to_json(JsonValueScope &jv, const tonlib_api::data &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "data");
  jo << ctie("bytes", ToJson(JsonBytes{object.bytes_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::error &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "error");
  jo << ctie("code", ToJson(object.code_));
  jo << ctie("message", ToJson(object.message_));
}
void to_json(JsonValueScope &jv, const tonlib_api::exportedEncryptedKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportedEncryptedKey");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::exportedKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportedKey");
  jo << ctie("word_list", ToJson(object.word_list_));
}
void to_json(JsonValueScope &jv, const tonlib_api::exportedPemKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportedPemKey");
  jo << ctie("pem", ToJson(object.pem_));
}
void to_json(JsonValueScope &jv, const tonlib_api::inputKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "inputKey");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
  jo << ctie("local_password", ToJson(JsonBytes{object.local_password_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "key");
  jo << ctie("public_key", ToJson(object.public_key_));
  jo << ctie("secret", ToJson(JsonBytes{object.secret_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::KeyStoreType &object) {
  tonlib_api::downcast_call(const_cast<tonlib_api::KeyStoreType &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const tonlib_api::keyStoreTypeDirectory &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "keyStoreTypeDirectory");
  jo << ctie("directory", ToJson(object.directory_));
}
void to_json(JsonValueScope &jv, const tonlib_api::keyStoreTypeInMemory &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "keyStoreTypeInMemory");
}
void to_json(JsonValueScope &jv, const tonlib_api::LogStream &object) {
  tonlib_api::downcast_call(const_cast<tonlib_api::LogStream &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const tonlib_api::logStreamDefault &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "logStreamDefault");
}
void to_json(JsonValueScope &jv, const tonlib_api::logStreamFile &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "logStreamFile");
  jo << ctie("path", ToJson(object.path_));
  jo << ctie("max_file_size", ToJson(object.max_file_size_));
}
void to_json(JsonValueScope &jv, const tonlib_api::logStreamEmpty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "logStreamEmpty");
}
void to_json(JsonValueScope &jv, const tonlib_api::logTags &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "logTags");
  jo << ctie("tags", ToJson(object.tags_));
}
void to_json(JsonValueScope &jv, const tonlib_api::logVerbosityLevel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "logVerbosityLevel");
  jo << ctie("verbosity_level", ToJson(object.verbosity_level_));
}
void to_json(JsonValueScope &jv, const tonlib_api::ok &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "ok");
}
void to_json(JsonValueScope &jv, const tonlib_api::options &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "options");
  if (object.config_) {
    jo << ctie("config", ToJson(object.config_));
  }
  if (object.keystore_type_) {
    jo << ctie("keystore_type", ToJson(object.keystore_type_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::sendGramsResult &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "sendGramsResult");
  jo << ctie("sent_until", ToJson(object.sent_until_));
  jo << ctie("body_hash", ToJson(JsonBytes{object.body_hash_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::unpackedAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "unpackedAccountAddress");
  jo << ctie("workchain_id", ToJson(object.workchain_id_));
  jo << ctie("bounceable", ToJson(object.bounceable_));
  jo << ctie("testnet", ToJson(object.testnet_));
  jo << ctie("addr", ToJson(JsonBytes{object.addr_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::updateSendLiteServerQuery &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "updateSendLiteServerQuery");
  jo << ctie("id", ToJson(JsonInt64{object.id_}));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_AccountState &object) {
  tonlib_api::downcast_call(const_cast<tonlib_api::generic_AccountState &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_accountStateRaw &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.accountStateRaw");
  if (object.account_state_) {
    jo << ctie("account_state", ToJson(object.account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_accountStateTestWallet &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.accountStateTestWallet");
  if (object.account_state_) {
    jo << ctie("account_state", ToJson(object.account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_accountStateWallet &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.accountStateWallet");
  if (object.account_state_) {
    jo << ctie("account_state", ToJson(object.account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_accountStateTestGiver &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.accountStateTestGiver");
  if (object.account_state_) {
    jo << ctie("account_state", ToJson(object.account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_accountStateUninited &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.accountStateUninited");
  if (object.account_state_) {
    jo << ctie("account_state", ToJson(object.account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::internal_transactionId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "internal.transactionId");
  jo << ctie("lt", ToJson(JsonInt64{object.lt_}));
  jo << ctie("hash", ToJson(JsonBytes{object.hash_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_accountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.accountState");
  jo << ctie("balance", ToJson(JsonInt64{object.balance_}));
  jo << ctie("code", ToJson(JsonBytes{object.code_}));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  if (object.last_transaction_id_) {
    jo << ctie("last_transaction_id", ToJson(object.last_transaction_id_));
  }
  jo << ctie("frozen_hash", ToJson(JsonBytes{object.frozen_hash_}));
  jo << ctie("sync_utime", ToJson(object.sync_utime_));
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_initialAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.initialAccountState");
  jo << ctie("code", ToJson(JsonBytes{object.code_}));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_message &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.message");
  jo << ctie("source", ToJson(object.source_));
  jo << ctie("destination", ToJson(object.destination_));
  jo << ctie("value", ToJson(JsonInt64{object.value_}));
  jo << ctie("fwd_fee", ToJson(JsonInt64{object.fwd_fee_}));
  jo << ctie("ihr_fee", ToJson(JsonInt64{object.ihr_fee_}));
  jo << ctie("created_lt", ToJson(JsonInt64{object.created_lt_}));
  jo << ctie("body_hash", ToJson(JsonBytes{object.body_hash_}));
  jo << ctie("message", ToJson(JsonBytes{object.message_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_transaction &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.transaction");
  jo << ctie("utime", ToJson(object.utime_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  if (object.transaction_id_) {
    jo << ctie("transaction_id", ToJson(object.transaction_id_));
  }
  jo << ctie("fee", ToJson(JsonInt64{object.fee_}));
  jo << ctie("storage_fee", ToJson(JsonInt64{object.storage_fee_}));
  jo << ctie("other_fee", ToJson(JsonInt64{object.other_fee_}));
  if (object.in_msg_) {
    jo << ctie("in_msg", ToJson(object.in_msg_));
  }
  jo << ctie("out_msgs", ToJson(object.out_msgs_));
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_transactions &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.transactions");
  jo << ctie("transactions", ToJson(object.transactions_));
  if (object.previous_transaction_id_) {
    jo << ctie("previous_transaction_id", ToJson(object.previous_transaction_id_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::testGiver_accountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testGiver.accountState");
  jo << ctie("balance", ToJson(JsonInt64{object.balance_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  if (object.last_transaction_id_) {
    jo << ctie("last_transaction_id", ToJson(object.last_transaction_id_));
  }
  jo << ctie("sync_utime", ToJson(object.sync_utime_));
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_accountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.accountState");
  jo << ctie("balance", ToJson(JsonInt64{object.balance_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  if (object.last_transaction_id_) {
    jo << ctie("last_transaction_id", ToJson(object.last_transaction_id_));
  }
  jo << ctie("sync_utime", ToJson(object.sync_utime_));
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_initialAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.initialAccountState");
  jo << ctie("public_key", ToJson(object.public_key_));
}
void to_json(JsonValueScope &jv, const tonlib_api::uninited_accountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "uninited.accountState");
  jo << ctie("balance", ToJson(JsonInt64{object.balance_}));
  if (object.last_transaction_id_) {
    jo << ctie("last_transaction_id", ToJson(object.last_transaction_id_));
  }
  jo << ctie("frozen_hash", ToJson(JsonBytes{object.frozen_hash_}));
  jo << ctie("sync_utime", ToJson(object.sync_utime_));
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_accountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.accountState");
  jo << ctie("balance", ToJson(JsonInt64{object.balance_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  if (object.last_transaction_id_) {
    jo << ctie("last_transaction_id", ToJson(object.last_transaction_id_));
  }
  jo << ctie("sync_utime", ToJson(object.sync_utime_));
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_initialAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.initialAccountState");
  jo << ctie("public_key", ToJson(object.public_key_));
}
void to_json(JsonValueScope &jv, const tonlib_api::addLogMessage &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "addLogMessage");
  jo << ctie("verbosity_level", ToJson(object.verbosity_level_));
  jo << ctie("text", ToJson(object.text_));
}
void to_json(JsonValueScope &jv, const tonlib_api::changeLocalPassword &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "changeLocalPassword");
  if (object.input_key_) {
    jo << ctie("input_key", ToJson(object.input_key_));
  }
  jo << ctie("new_local_password", ToJson(JsonBytes{object.new_local_password_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::close &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "close");
}
void to_json(JsonValueScope &jv, const tonlib_api::createNewKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "createNewKey");
  jo << ctie("local_password", ToJson(JsonBytes{object.local_password_}));
  jo << ctie("mnemonic_password", ToJson(JsonBytes{object.mnemonic_password_}));
  jo << ctie("random_extra_seed", ToJson(JsonBytes{object.random_extra_seed_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::decrypt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "decrypt");
  jo << ctie("encrypted_data", ToJson(JsonBytes{object.encrypted_data_}));
  jo << ctie("secret", ToJson(JsonBytes{object.secret_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::deleteAllKeys &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "deleteAllKeys");
}
void to_json(JsonValueScope &jv, const tonlib_api::deleteKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "deleteKey");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::encrypt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "encrypt");
  jo << ctie("decrypted_data", ToJson(JsonBytes{object.decrypted_data_}));
  jo << ctie("secret", ToJson(JsonBytes{object.secret_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::exportEncryptedKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportEncryptedKey");
  if (object.input_key_) {
    jo << ctie("input_key", ToJson(object.input_key_));
  }
  jo << ctie("key_password", ToJson(JsonBytes{object.key_password_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::exportKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportKey");
  if (object.input_key_) {
    jo << ctie("input_key", ToJson(object.input_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::exportPemKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "exportPemKey");
  if (object.input_key_) {
    jo << ctie("input_key", ToJson(object.input_key_));
  }
  jo << ctie("key_password", ToJson(JsonBytes{object.key_password_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_getAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.getAccountState");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::generic_sendGrams &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "generic.sendGrams");
  if (object.private_key_) {
    jo << ctie("private_key", ToJson(object.private_key_));
  }
  if (object.source_) {
    jo << ctie("source", ToJson(object.source_));
  }
  if (object.destination_) {
    jo << ctie("destination", ToJson(object.destination_));
  }
  jo << ctie("amount", ToJson(JsonInt64{object.amount_}));
  jo << ctie("timeout", ToJson(object.timeout_));
  jo << ctie("allow_send_to_uninited", ToJson(object.allow_send_to_uninited_));
  jo << ctie("message", ToJson(JsonBytes{object.message_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::getBip39Hints &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getBip39Hints");
  jo << ctie("prefix", ToJson(object.prefix_));
}
void to_json(JsonValueScope &jv, const tonlib_api::getLogStream &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getLogStream");
}
void to_json(JsonValueScope &jv, const tonlib_api::getLogTagVerbosityLevel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getLogTagVerbosityLevel");
  jo << ctie("tag", ToJson(object.tag_));
}
void to_json(JsonValueScope &jv, const tonlib_api::getLogTags &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getLogTags");
}
void to_json(JsonValueScope &jv, const tonlib_api::getLogVerbosityLevel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getLogVerbosityLevel");
}
void to_json(JsonValueScope &jv, const tonlib_api::importEncryptedKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "importEncryptedKey");
  jo << ctie("local_password", ToJson(JsonBytes{object.local_password_}));
  jo << ctie("key_password", ToJson(JsonBytes{object.key_password_}));
  if (object.exported_encrypted_key_) {
    jo << ctie("exported_encrypted_key", ToJson(object.exported_encrypted_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::importKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "importKey");
  jo << ctie("local_password", ToJson(JsonBytes{object.local_password_}));
  jo << ctie("mnemonic_password", ToJson(JsonBytes{object.mnemonic_password_}));
  if (object.exported_key_) {
    jo << ctie("exported_key", ToJson(object.exported_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::importPemKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "importPemKey");
  jo << ctie("local_password", ToJson(JsonBytes{object.local_password_}));
  jo << ctie("key_password", ToJson(JsonBytes{object.key_password_}));
  if (object.exported_key_) {
    jo << ctie("exported_key", ToJson(object.exported_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::init &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "init");
  if (object.options_) {
    jo << ctie("options", ToJson(object.options_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::kdf &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "kdf");
  jo << ctie("password", ToJson(JsonBytes{object.password_}));
  jo << ctie("salt", ToJson(JsonBytes{object.salt_}));
  jo << ctie("iterations", ToJson(object.iterations_));
}
void to_json(JsonValueScope &jv, const tonlib_api::onLiteServerQueryError &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "onLiteServerQueryError");
  jo << ctie("id", ToJson(JsonInt64{object.id_}));
  if (object.error_) {
    jo << ctie("error", ToJson(object.error_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::onLiteServerQueryResult &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "onLiteServerQueryResult");
  jo << ctie("id", ToJson(JsonInt64{object.id_}));
  jo << ctie("bytes", ToJson(JsonBytes{object.bytes_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::options_setConfig &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "options.setConfig");
  if (object.config_) {
    jo << ctie("config", ToJson(object.config_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::packAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "packAccountAddress");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_getAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.getAccountAddress");
  if (object.initital_account_state_) {
    jo << ctie("initital_account_state", ToJson(object.initital_account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_getAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.getAccountState");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_getTransactions &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.getTransactions");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
  if (object.from_transaction_id_) {
    jo << ctie("from_transaction_id", ToJson(object.from_transaction_id_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::raw_sendMessage &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "raw.sendMessage");
  if (object.destination_) {
    jo << ctie("destination", ToJson(object.destination_));
  }
  jo << ctie("initial_account_state", ToJson(JsonBytes{object.initial_account_state_}));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::runTests &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "runTests");
  jo << ctie("dir", ToJson(object.dir_));
}
void to_json(JsonValueScope &jv, const tonlib_api::setLogStream &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "setLogStream");
  if (object.log_stream_) {
    jo << ctie("log_stream", ToJson(object.log_stream_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::setLogTagVerbosityLevel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "setLogTagVerbosityLevel");
  jo << ctie("tag", ToJson(object.tag_));
  jo << ctie("new_verbosity_level", ToJson(object.new_verbosity_level_));
}
void to_json(JsonValueScope &jv, const tonlib_api::setLogVerbosityLevel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "setLogVerbosityLevel");
  jo << ctie("new_verbosity_level", ToJson(object.new_verbosity_level_));
}
void to_json(JsonValueScope &jv, const tonlib_api::testGiver_getAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testGiver.getAccountAddress");
}
void to_json(JsonValueScope &jv, const tonlib_api::testGiver_getAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testGiver.getAccountState");
}
void to_json(JsonValueScope &jv, const tonlib_api::testGiver_sendGrams &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testGiver.sendGrams");
  if (object.destination_) {
    jo << ctie("destination", ToJson(object.destination_));
  }
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("amount", ToJson(JsonInt64{object.amount_}));
  jo << ctie("message", ToJson(JsonBytes{object.message_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_getAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.getAccountAddress");
  if (object.initital_account_state_) {
    jo << ctie("initital_account_state", ToJson(object.initital_account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_getAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.getAccountState");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_init &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.init");
  if (object.private_key_) {
    jo << ctie("private_key", ToJson(object.private_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::testWallet_sendGrams &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testWallet.sendGrams");
  if (object.private_key_) {
    jo << ctie("private_key", ToJson(object.private_key_));
  }
  if (object.destination_) {
    jo << ctie("destination", ToJson(object.destination_));
  }
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("amount", ToJson(JsonInt64{object.amount_}));
  jo << ctie("message", ToJson(JsonBytes{object.message_}));
}
void to_json(JsonValueScope &jv, const tonlib_api::unpackAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "unpackAccountAddress");
  jo << ctie("account_address", ToJson(object.account_address_));
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_getAccountAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.getAccountAddress");
  if (object.initital_account_state_) {
    jo << ctie("initital_account_state", ToJson(object.initital_account_state_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_getAccountState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.getAccountState");
  if (object.account_address_) {
    jo << ctie("account_address", ToJson(object.account_address_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_init &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.init");
  if (object.private_key_) {
    jo << ctie("private_key", ToJson(object.private_key_));
  }
}
void to_json(JsonValueScope &jv, const tonlib_api::wallet_sendGrams &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "wallet.sendGrams");
  if (object.private_key_) {
    jo << ctie("private_key", ToJson(object.private_key_));
  }
  if (object.destination_) {
    jo << ctie("destination", ToJson(object.destination_));
  }
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("valid_until", ToJson(object.valid_until_));
  jo << ctie("amount", ToJson(JsonInt64{object.amount_}));
  jo << ctie("message", ToJson(JsonBytes{object.message_}));
}
}  // namespace tonlib_api
}  // namespace ton
