/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "Config.h"
#include "adnl/adnl-node-id.hpp"
#include "td/utils/JsonBuilder.h"

namespace tonlib {
td::Result<ton::BlockIdExt> parse_block_id_ext(td::JsonObject &obj) {
  ton::WorkchainId zero_workchain_id;
  {
    TRY_RESULT(wc, td::get_json_object_int_field(obj, "workchain"));
    zero_workchain_id = wc;
  }
  ton::ShardId zero_shard_id;  // uint64
  {
    TRY_RESULT(shard_id, td::get_json_object_long_field(obj, "shard"));
    zero_shard_id = static_cast<ton::ShardId>(shard_id);
  }
  ton::BlockSeqno zero_seqno;
  {
    TRY_RESULT(seqno, td::get_json_object_int_field(obj, "seqno"));
    zero_seqno = seqno;
  }

  ton::RootHash zero_root_hash;
  {
    TRY_RESULT(hash_b64, td::get_json_object_string_field(obj, "root_hash"));
    TRY_RESULT(hash, td::base64_decode(hash_b64));
    if (hash.size() * 8 != ton::RootHash::size()) {
      return td::Status::Error("Invalid config (8)");
    }
    zero_root_hash = ton::RootHash(td::ConstBitPtr(td::Slice(hash).ubegin()));
  }
  ton::FileHash zero_file_hash;
  {
    TRY_RESULT(hash_b64, td::get_json_object_string_field(obj, "file_hash"));
    TRY_RESULT(hash, td::base64_decode(hash_b64));
    if (hash.size() * 8 != ton::FileHash::size()) {
      return td::Status::Error("Invalid config (9)");
    }
    zero_file_hash = ton::RootHash(td::ConstBitPtr(td::Slice(hash).ubegin()));
  }

  return ton::BlockIdExt(zero_workchain_id, zero_shard_id, zero_seqno, std::move(zero_root_hash),
                         std::move(zero_file_hash));
}
td::Result<Config> Config::parse(std::string str) {
  TRY_RESULT(json, td::json_decode(str));
  if (json.type() != td::JsonValue::Type::Object) {
    return td::Status::Error("Invalid config (1)");
  }
  //TRY_RESULT(main_type, td::get_json_object_string_field(json.get_object(), "@type", false));
  //if (main_type != "config.global") {
  //return td::Status::Error("Invalid config (3)");
  //}
  TRY_RESULT(lite_clients_obj,
             td::get_json_object_field(json.get_object(), "liteservers", td::JsonValue::Type::Array, false));
  auto &lite_clients = lite_clients_obj.get_array();

  Config res;
  for (auto &value : lite_clients) {
    if (value.type() != td::JsonValue::Type::Object) {
      return td::Status::Error("Invalid config (2)");
    }
    auto &object = value.get_object();
    //TRY_RESULT(value_type, td::get_json_object_string_field(object, "@type", false));
    //if (value_type != "liteclient.config.global") {
    //return td::Status::Error("Invalid config (4)");
    //}

    TRY_RESULT(ip, td::get_json_object_int_field(object, "ip", false));
    TRY_RESULT(port, td::get_json_object_int_field(object, "port", false));
    Config::LiteClient client;
    TRY_STATUS(client.address.init_host_port(td::IPAddress::ipv4_to_str(ip), port));

    TRY_RESULT(id_obj, td::get_json_object_field(object, "id", td::JsonValue::Type::Object, false));
    auto &id = id_obj.get_object();
    TRY_RESULT(id_type, td::get_json_object_string_field(id, "@type", false));
    if (id_type != "pub.ed25519") {
      return td::Status::Error("Invalid config (5)");
    }
    TRY_RESULT(key_base64, td::get_json_object_string_field(id, "key", false));
    TRY_RESULT(key, td::base64_decode(key_base64));
    if (key.size() != 32) {
      return td::Status::Error("Invalid config (6)");
    }

    client.adnl_id = ton::adnl::AdnlNodeIdFull(ton::pubkeys::Ed25519(td::Bits256(td::Slice(key).ubegin())));
    res.lite_clients.push_back(std::move(client));
  }

  TRY_RESULT(validator_obj,
             td::get_json_object_field(json.get_object(), "validator", td::JsonValue::Type::Object, false));
  auto &validator = validator_obj.get_object();
  TRY_RESULT(validator_type, td::get_json_object_string_field(validator, "@type", false));
  if (validator_type != "validator.config.global") {
    return td::Status::Error("Invalid config (7)");
  }
  TRY_RESULT(zero_state_obj, td::get_json_object_field(validator, "zero_state", td::JsonValue::Type::Object, false));
  TRY_RESULT(zero_state_id, parse_block_id_ext(zero_state_obj.get_object()));
  res.zero_state_id = zero_state_id;
  auto r_init_block_obj = td::get_json_object_field(validator, "init_block", td::JsonValue::Type::Object, false);
  if (r_init_block_obj.is_ok()) {
    TRY_RESULT(init_block_id, parse_block_id_ext(r_init_block_obj.move_as_ok().get_object()));
    res.init_block_id = init_block_id;
  }

  return res;
}
}  // namespace tonlib
