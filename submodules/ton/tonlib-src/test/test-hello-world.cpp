/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include <iostream>

#include "auto/tl/ton_api.h"
#include "auto/tl/ton_api_json.h"

#include "tl/tl_json.h"
#include "td/utils/Random.h"

namespace {
std::string config = R"json(
{
  "@type" : "config.local",
  "dht": [
    {
      "@type" : "dht.config.local",
      "id" : {
        "@type" : "adnl.id.pk.ed25519",
        "key" : "VdeZz3BEIE8+tuPSBUNKN0jQXL/0T/SoK4ZpJ9vTCNQ="
      },
      "addr_list" : {
        "@type" : "adnl.addressList",
        "version" : 0,
        "addrs" : [
          {
            "@type" : "adnl.address.udp",
            "ip" : 2130706433,
            "port" : 16000
          }
        ]
      }
    }
  ]
}
)json";
std::string config2 = R"json(
{
  "@type" : "config.local",
  "dht": [
    {
      "@type" : "dht.config.local",
      "id" : {
        "@type" : "adnl.id.pk.ed25519",
        "key" : "VdeZz3BEIE8+tuPSBUNKN0jQXL/0T/SoK4ZpJ9vTCNQ="
      },
      "addr_list" : {
        "@type" : "adnl.addressList",
        "version" : 0,
        "addrs" : [
          {
            "@type" : "adnl.address.udp",
            "ip" : 2130706433,
            "port" : 16000
          }
        ]
      }
    }
  ],
  "adnl" : {
    "@type" : "adnl.config.local"
  }
}
)json";
}  // namespace

int main() {
  std::cout << "hello world!\n";

  auto decode_encode = [](auto obj_json) {
    auto as_json_value = td::json_decode(obj_json).move_as_ok();
    ton::ton_api::object_ptr<ton::ton_api::Object> obj2;
    from_json(obj2, as_json_value).ensure();
    CHECK(obj2 != nullptr);
    return td::json_encode<std::string>(td::ToJson(obj2));
  };

  auto test_tl_json = [&decode_encode](auto obj) {
    auto obj_json = td::json_encode<std::string>(td::ToJson(obj));
    std::cout << obj_json << "\n";

    auto obj2_json = decode_encode(obj_json);
    CHECK(obj_json == obj2_json);
  };

  td::Bits256 uint256;
  uint256.set_ones();
  test_tl_json(ton::ton_api::make_object<ton::ton_api::adnl_id_short>(uint256));

  test_tl_json(ton::ton_api::make_object<ton::ton_api::testObject>(
      1, ton::ton_api::make_object<ton::ton_api::adnl_id_short>(uint256),
      ton::ton_api::make_object<ton::ton_api::getTestObject>()));

  std::cout << decode_encode(config) << std::endl;
  std::cout << decode_encode(config2) << std::endl;

  auto decode_encode_local = [](auto obj_json) {
    auto as_json_value = td::json_decode(obj_json).move_as_ok();
    ton::ton_api::config_local config_local;
    from_json(config_local, as_json_value.get_object()).ensure();
    return td::json_encode<std::string>(td::ToJson(config_local));
  };
  std::cout << decode_encode_local(config) << std::endl;
  std::cout << decode_encode_local(config2) << std::endl;

  auto create_vector_bytes = [] {
    std::vector<td::BufferSlice> res;
    res.emplace_back("fdjskld");
    res.emplace_back("fdj\0kld");
    res.emplace_back("fdj\0\x01\xff\x7fkld");
    return res;
  };
  test_tl_json(ton::ton_api::make_object<ton::ton_api::testVectorBytes>(create_vector_bytes()));

  td::Bits256 x;
  td::Random::secure_bytes(x.as_slice());

  auto s = x.to_hex();

  auto v = td::hex_decode(s).move_as_ok();

  auto w = td::buffer_to_hex(x.as_slice());

  td::Bits256 y;
  y.as_slice().copy_from(v);

  CHECK(x == y);

  auto w2 = td::hex_decode(w).move_as_ok();
  td::Bits256 z;
  z.as_slice().copy_from(w2);

  LOG_CHECK(x == z) << s << " " << w;
  return 0;
}
