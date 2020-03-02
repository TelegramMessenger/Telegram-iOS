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

    Copyright 2019-2020 Telegram Systems LLP
*/
#include "ManualDns.h"

#include "smc-envelope/SmartContractCode.h"

#include "vm/dict.h"

#include "td/utils/format.h"
#include "td/utils/overloaded.h"
#include "td/utils/Parser.h"
#include "td/utils/Random.h"

#include "block/block-auto.h"
#include "block/block-parse.h"

#include "common/util.h"

namespace ton {
td::StringBuilder& operator<<(td::StringBuilder& sb, const ManualDns::EntryData& data) {
  switch (data.type) {
    case ManualDns::EntryData::Type::Empty:
      return sb << "DELETED";
    case ManualDns::EntryData::Type::Text:
      return sb << "TEXT:" << data.data.get<ManualDns::EntryDataText>().text;
    case ManualDns::EntryData::Type::NextResolver:
      return sb << "NEXT:" << data.data.get<ManualDns::EntryDataNextResolver>().resolver.rserialize();
    case ManualDns::EntryData::Type::AdnlAddress:
      return sb << "ADNL:"
                << td::adnl_id_encode(data.data.get<ManualDns::EntryDataAdnlAddress>().adnl_address.as_slice())
                       .move_as_ok();
    case ManualDns::EntryData::Type::SmcAddress:
      return sb << "SMC:" << data.data.get<ManualDns::EntryDataSmcAddress>().smc_address.rserialize();
  }
  return sb << "<unknown>";
}

//proto_list_nil$0 = ProtoList;
//proto_list_next$1 head:Protocol tail:ProtoList = ProtoList;
//proto_http#4854 = Protocol;

//cap_list_nil$0 = SmcCapList;
//cap_list_next$1 head:SmcCapability tail:SmcCapList = SmcCapList;
//cap_method_seqno#5371 = SmcCapability;
//cap_method_pubkey#71f4 = SmcCapability;
//cap_is_wallet#2177 = SmcCapability;
//cap_name#ff name:Text = SmcCapability;
//
td::Result<td::Ref<vm::Cell>> DnsInterface::EntryData::as_cell() const {
  td::Ref<vm::Cell> res;
  td::Status error;
  data.visit(td::overloaded(
      [&](const EntryDataText& text) {
        block::gen::DNSRecord::Record_dns_text dns;
        vm::CellBuilder cb;
        vm::CellText::store(cb, text.text);
        dns.x = vm::load_cell_slice_ref(cb.finalize());
        tlb::pack_cell(res, dns);
      },
      [&](const EntryDataNextResolver& resolver) {
        block::gen::DNSRecord::Record_dns_next_resolver dns;
        vm::CellBuilder cb;
        block::tlb::t_MsgAddressInt.store_std_address(cb, resolver.resolver.workchain, resolver.resolver.addr);
        dns.resolver = vm::load_cell_slice_ref(cb.finalize());
        tlb::pack_cell(res, dns);
      },
      [&](const EntryDataAdnlAddress& adnl_address) {
        block::gen::DNSRecord::Record_dns_adnl_address dns;
        dns.adnl_addr = adnl_address.adnl_address;
        dns.flags = 0;
        tlb::pack_cell(res, dns);
      },
      [&](const EntryDataSmcAddress& smc_address) {
        block::gen::DNSRecord::Record_dns_smc_address dns;
        vm::CellBuilder cb;
        block::tlb::t_MsgAddressInt.store_std_address(cb, smc_address.smc_address.workchain,
                                                      smc_address.smc_address.addr);
        dns.smc_addr = vm::load_cell_slice_ref(cb.finalize());
        tlb::pack_cell(res, dns);
      }));
  if (error.is_error()) {
    return error;
  }
  if (res.is_null()) {
    return td::Status::Error("Entry data is emtpy");
  }
  return res;
  //dns_text#1eda _:Text = DNSRecord;

  //dns_next_resolver#ba93 resolver:MsgAddressInt = DNSRecord;  // usually in record #-1
  //dns_adnl_address#ad01 adnl_addr:bits256 flags:(## 8) { flags <= 1 } proto_list:flags . 0?ProtoList = DNSRecord;  // often in record #2

  //dns_smc_address#9fd3 smc_addr:MsgAddressInt flags:(## 8) { flags <= 1 } cap_list:flags . 0?SmcCapList = DNSRecord;   // often in record #1
}

td::Result<DnsInterface::EntryData> DnsInterface::EntryData::from_cellslice(vm::CellSlice& cs) {
  switch (block::gen::t_DNSRecord.get_tag(cs)) {
    case block::gen::DNSRecord::dns_text: {
      block::gen::DNSRecord::Record_dns_text dns;
      tlb::unpack(cs, dns);
      TRY_RESULT(text, vm::CellText::load(dns.x.write()));
      return EntryData::text(std::move(text));
    }
    case block::gen::DNSRecord::dns_next_resolver: {
      block::gen::DNSRecord::Record_dns_next_resolver dns;
      tlb::unpack(cs, dns);
      ton::WorkchainId wc;
      ton::StdSmcAddress addr;
      if (!block::tlb::t_MsgAddressInt.extract_std_address(dns.resolver, wc, addr)) {
        return td::Status::Error("Invalid address");
      }
      return EntryData::next_resolver(block::StdAddress(wc, addr));
    }
    case block::gen::DNSRecord::dns_adnl_address: {
      block::gen::DNSRecord::Record_dns_adnl_address dns;
      tlb::unpack(cs, dns);
      return EntryData::adnl_address(dns.adnl_addr);
    }
    case block::gen::DNSRecord::dns_smc_address: {
      block::gen::DNSRecord::Record_dns_smc_address dns;
      tlb::unpack(cs, dns);
      ton::WorkchainId wc;
      ton::StdSmcAddress addr;
      if (!block::tlb::t_MsgAddressInt.extract_std_address(dns.smc_addr, wc, addr)) {
        return td::Status::Error("Invalid address");
      }
      return EntryData::smc_address(block::StdAddress(wc, addr));
    }
  }
  return td::Status::Error("Unknown entry data");
}

SmartContract::Args DnsInterface::resolve_args_raw(td::Slice encoded_name, td::int16 category) {
  SmartContract::Args res;
  res.set_method_id("dnsresolve");
  res.set_stack(
      {vm::load_cell_slice_ref(vm::CellBuilder().store_bytes(encoded_name).finalize()), td::make_refint(category)});
  return res;
}

td::Result<SmartContract::Args> DnsInterface::resolve_args(td::Slice name, td::int32 category_big) {
  TRY_RESULT(category, td::narrow_cast_safe<td::int16>(category_big));
  if (name.size() > get_default_max_name_size()) {
    return td::Status::Error("Name is too long");
  }
  auto encoded_name = encode_name(name);
  return resolve_args_raw(encoded_name, category);
}

td::Result<std::vector<DnsInterface::Entry>> DnsInterface::resolve(td::Slice name, td::int32 category) const {
  TRY_RESULT(raw_entries, resolve_raw(name, category));
  std::vector<Entry> entries;
  entries.reserve(raw_entries.size());
  for (auto& raw_entry : raw_entries) {
    Entry entry;
    entry.name = std::move(raw_entry.name);
    entry.category = raw_entry.category;
    auto cs = vm::load_cell_slice(raw_entry.data);
    TRY_RESULT(data, EntryData::from_cellslice(cs));
    entry.data = std::move(data);
    entries.push_back(std::move(entry));
  }
  return entries;
}

/*
    External message structure:
      [Bytes<512b>:signature] [UInt<32b>:seqno] [UInt<6b>:operation]
      [Either b0: inline name (<= 58-x Bytes) or b1: reference-stored name)
                                     x depends on operation
      Use of 6-bit op instead of 32-bit allows to save 4 bytes for inline name
    Inline [Name] structure: [UInt<6b>:length] [Bytes<lengthB>:data]
    Operations (continuation of message):
    00 Contract initialization message (only if seqno = 0) (x=-)
	31 TSet: replace ENTIRE DOMAIN TABLE with the provided tree root cell (x=-)
		[Cell<1r>:new_domains_table]
	51 OSet: replace owner public key with a new one (x=-)
		[UInt<256b>:new_public_key]
*/
// creation
td::Ref<ManualDns> ManualDns::create(td::Ref<vm::Cell> data, int revision) {
  return td::Ref<ManualDns>(
      true, State{ton::SmartContractCode::get_code(ton::SmartContractCode::ManualDns, revision), std::move(data)});
}

td::Ref<ManualDns> ManualDns::create(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id, int revision) {
  return create(create_init_data_fast(public_key, wallet_id), revision);
}

td::optional<td::int32> ManualDns::guess_revision(const vm::Cell::Hash& code_hash) {
  for (auto i : ton::SmartContractCode::get_revisions(ton::SmartContractCode::ManualDns)) {
    if (ton::SmartContractCode::get_code(ton::SmartContractCode::ManualDns, i)->get_hash() == code_hash) {
      return i;
    }
  }
  return {};
}
td::optional<td::int32> ManualDns::guess_revision(const block::StdAddress& address,
                                                  const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id) {
  for (auto i : {-1, 1}) {
    auto dns = ton::ManualDns::create(public_key, wallet_id, i);
    if (dns->get_address() == address) {
      return i;
    }
  }
  return {};
}

td::Result<td::uint32> ManualDns::get_wallet_id() const {
  return TRY_VM(get_wallet_id_or_throw());
}
td::Result<td::uint32> ManualDns::get_wallet_id_or_throw() const {
  if (state_.data.is_null()) {
    return 0;
  }
  //FIXME use get method
  return static_cast<td::uint32>(vm::load_cell_slice(state_.data).fetch_ulong(32));
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_set_value_unsigned(td::int16 category, td::Slice name,
                                                                   td::Ref<vm::Cell> data) const {
  //11 VSet: set specified value to specified subdomain->category (x=2)
  //[Int<16b>:category] [Name<?>:subdomain] [Cell<1r>:value]
  vm::CellBuilder cb;
  cb.store_long(11, 6);
  if (name.size() <= 58 - 2) {
    cb.store_long(category, 16);
    cb.store_long(0, 1);
    cb.store_long(name.size(), 6);
    cb.store_bytes(name);
  } else {
    cb.store_long(category, 16);
    cb.store_long(1, 1);
    cb.store_ref(vm::CellBuilder().store_bytes(name).finalize());
  }
  cb.store_maybe_ref(std::move(data));
  return cb.finalize();
}
td::Result<td::Ref<vm::Cell>> ManualDns::create_delete_value_unsigned(td::int16 category, td::Slice name) const {
  //12 VDel: delete specified subdomain->category (x=2)
  //[Int<16b>:category] [Name<?>:subdomain]
  vm::CellBuilder cb;
  cb.store_long(12, 6);
  if (name.size() <= 58 - 2) {
    cb.store_long(category, 16);
    cb.store_long(0, 1);
    cb.store_long(name.size(), 6);
    cb.store_bytes(name);
  } else {
    cb.store_long(category, 16);
    cb.store_long(1, 1);
    cb.store_ref(vm::CellBuilder().store_bytes(name).finalize());
  }
  return cb.finalize();
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_delete_all_unsigned() const {
  // 32 TDel: nullify ENTIRE DOMAIN TABLE (x=-)
  vm::CellBuilder cb;
  cb.store_long(32, 6);
  return cb.finalize();
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_set_all_unsigned(td::Span<Action> entries) const {
  vm::PrefixDictionary pdict(1023);
  for (auto& action : entries) {
    auto name_key = encode_name(action.name);
    int zero_cnt = 0;
    for (auto c : name_key) {
      if (c == 0) {
        zero_cnt++;
      }
    }
    auto new_name_key = vm::load_cell_slice(vm::CellBuilder().store_long(zero_cnt, 7).store_bytes(name_key).finalize());
    auto ptr = new_name_key.data_bits();
    auto ptr_size = new_name_key.size();
    auto o_dict = pdict.lookup(ptr, ptr_size);
    td::Ref<vm::Cell> dict_root;
    if (o_dict.not_null()) {
      o_dict->prefetch_maybe_ref(dict_root);
    }
    vm::Dictionary dict(dict_root, 16);
    if (!action.data.value().is_null()) {
      auto key = dict.integer_key(td::make_refint(action.category), 16);
      dict.set_ref(key.bits(), 16, action.data.value());
    }
    pdict.set(ptr, ptr_size, dict.get_root());
  }

  vm::CellBuilder cb;
  cb.store_long(31, 6);

  cb.store_maybe_ref(pdict.get_root_cell());

  return cb.finalize();
}

//21 DSet: replace entire category dictionary of domain with provided (x=0)
//[Name<?>:subdomain] [Cell<1r>:new_cat_table]
//22 DDel: delete entire category dictionary of specified domain (x=0)
//[Name<?>:subdomain]
td::Result<td::Ref<vm::Cell>> ManualDns::create_delete_name_unsigned(td::Slice name) const {
  vm::CellBuilder cb;
  cb.store_long(22, 6);
  if (name.size() <= 58) {
    cb.store_long(0, 1);
    cb.store_long(name.size(), 6);
    cb.store_bytes(name);
  } else {
    cb.store_long(1, 1);
    cb.store_ref(vm::CellBuilder().store_bytes(name).finalize());
  }
  return cb.finalize();
}
td::Result<td::Ref<vm::Cell>> ManualDns::create_set_name_unsigned(td::Slice name, td::Span<Action> entries) const {
  vm::CellBuilder cb;
  cb.store_long(21, 6);
  if (name.size() <= 58) {
    cb.store_long(0, 1);
    cb.store_long(name.size(), 6);
    cb.store_bytes(name);
  } else {
    cb.store_long(1, 1);
    cb.store_ref(vm::CellBuilder().store_bytes(name).finalize());
  }

  vm::Dictionary dict(16);

  for (auto& action : entries) {
    if (action.data.value().is_null()) {
      continue;
    }
    auto key = dict.integer_key(td::make_refint(action.category), 16);
    dict.set_ref(key.bits(), 16, action.data.value());
  }
  cb.store_maybe_ref(dict.get_root_cell());

  return cb.finalize();
}

td::Result<td::Ref<vm::Cell>> ManualDns::prepare(td::Ref<vm::Cell> data, td::uint32 valid_until) const {
  TRY_RESULT(wallet_id, get_wallet_id());
  auto hash = data->get_hash().as_slice().substr(28, 4).str();

  vm::CellBuilder cb;
  cb.store_long(wallet_id, 32).store_long(valid_until, 32);
  //cb.store_bytes(hash);
  cb.store_long(td::Random::secure_uint32(), 32);
  cb.append_cellslice(vm::load_cell_slice(data));
  return cb.finalize();
}

td::Result<td::Ref<vm::Cell>> ManualDns::sign(const td::Ed25519::PrivateKey& private_key, td::Ref<vm::Cell> data) {
  auto signature = private_key.sign(data->get_hash().as_slice()).move_as_ok();
  vm::CellBuilder cb;
  cb.store_bytes(signature.as_slice());
  cb.append_cellslice(vm::load_cell_slice(data));
  return cb.finalize();
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_init_query(const td::Ed25519::PrivateKey& private_key,
                                                           td::uint32 valid_until) const {
  vm::CellBuilder cb;
  cb.store_long(0, 6);

  TRY_RESULT(prepared, prepare(cb.finalize(), valid_until));
  return sign(private_key, std::move(prepared));
}

td::Ref<vm::Cell> ManualDns::create_init_data_fast(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id) {
  vm::CellBuilder cb;
  cb.store_long(wallet_id, 32).store_long(0, 64).store_bytes(public_key.as_octet_string());
  CHECK(cb.store_maybe_ref({}));
  CHECK(cb.store_maybe_ref({}));
  return cb.finalize();
}

size_t ManualDns::get_max_name_size() const {
  return get_default_max_name_size();
}

td::Result<std::vector<ManualDns::RawEntry>> ManualDns::resolve_raw(td::Slice name, td::int32 category_big) const {
  return TRY_VM(resolve_raw_or_throw(name, category_big));
}
td::Result<std::vector<ManualDns::RawEntry>> ManualDns::resolve_raw_or_throw(td::Slice name,
                                                                             td::int32 category_big) const {
  TRY_RESULT(category, td::narrow_cast_safe<td::int16>(category_big));
  if (name.size() > get_max_name_size()) {
    return td::Status::Error("Name is too long");
  }
  auto encoded_name = encode_name(name);
  auto res = run_get_method(resolve_args_raw(encoded_name, category));
  if (!res.success) {
    return td::Status::Error("get method failed");
  }
  std::vector<RawEntry> vec;
  auto data = res.stack.write().pop_maybe_cell();
  if (data.is_null()) {
    return vec;
  }
  size_t prefix_size = res.stack.write().pop_smallint_range((int)encoded_name.size() * 8);
  if (prefix_size % 8 != 0) {
    return td::Status::Error("Prefix size is not divisible by 8");
  }
  prefix_size /= 8;
  if (prefix_size < encoded_name.size()) {
    vec.push_back({decode_name(td::Slice(encoded_name).substr(0, prefix_size)), -1, data});
  } else {
    if (category == 0) {
      vm::Dictionary dict(std::move(data), 16);
      dict.check_for_each([&](auto cs, auto x, auto y) {
        td::BigInt256 cat;
        cat.import_bits(x, y, true);
        vec.push_back({name.str(), td::narrow_cast<td::int16>(cat.to_long()), cs->prefetch_ref()});
        return true;
      });
    } else {
      vec.push_back({name.str(), category, data});
    }
  }

  return vec;
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_update_query(CombinedActions<Action>& combined) const {
  if (combined.name.empty()) {
    if (combined.actions.value().empty()) {
      return create_delete_all_unsigned();
    }
    return create_set_all_unsigned(combined.actions.value());
  }
  if (combined.category == 0) {
    if (!combined.actions) {
      return create_delete_name_unsigned(encode_name(combined.name));
    }
    return create_set_name_unsigned(encode_name(combined.name), combined.actions.value());
  }
  CHECK(combined.actions.value().size() == 1);
  auto& action = combined.actions.value()[0];
  if (action.data) {
    return create_set_value_unsigned(action.category, encode_name(action.name), action.data.value());
  } else {
    return create_delete_value_unsigned(action.category, encode_name(action.name));
  }
}

td::Result<td::Ref<vm::Cell>> ManualDns::create_update_query(td::Ed25519::PrivateKey& pk, td::Span<Action> actions,
                                                             td::uint32 valid_until) const {
  auto combined = combine_actions(actions);
  std::vector<td::Ref<vm::Cell>> queries;
  for (auto& c : combined) {
    TRY_RESULT(q, create_update_query(c));
    queries.push_back(std::move(q));
  }

  td::Ref<vm::Cell> combined_query;
  for (auto& query : td::reversed(queries)) {
    if (combined_query.is_null()) {
      combined_query = std::move(query);
    } else {
      auto next = vm::load_cell_slice(combined_query);
      combined_query = vm::CellBuilder()
                           .append_cellslice(vm::load_cell_slice(query))
                           .store_ref(vm::CellBuilder().append_cellslice(next).finalize())
                           .finalize();
    }
  }

  TRY_RESULT(prepared, prepare(std::move(combined_query), valid_until));
  return sign(pk, std::move(prepared));
}

std::string DnsInterface::encode_name(td::Slice name) {
  std::string res;
  while (!name.empty()) {
    auto pos = name.rfind('.');
    if (pos == name.npos) {
      res += name.str();
      name = td::Slice();
    } else {
      res += name.substr(pos + 1).str();
      name.truncate(pos);
    }
    res += '\0';
  }
  return res;
}

std::string DnsInterface::decode_name(td::Slice name) {
  std::string res;
  if (!name.empty() && name.back() == 0) {
    name.remove_suffix(1);
  }
  while (!name.empty()) {
    auto pos = name.rfind('\0');
    if (!res.empty()) {
      res += '.';
    }
    if (pos == name.npos) {
      res += name.str();
      name = td::Slice();
    } else {
      res += name.substr(pos + 1).str();
      name.truncate(pos);
    }
  }
  return res;
}

std::string ManualDns::serialize_data(const EntryData& data) {
  std::string res;
  data.data.visit(td::overloaded([&](const ton::ManualDns::EntryDataText& text) { res = "UNSUPPORTED"; },
                                 [&](const ton::ManualDns::EntryDataNextResolver& resolver) { res = "UNSUPPORTED"; },
                                 [&](const ton::ManualDns::EntryDataAdnlAddress& adnl_address) { res = "UNSUPPORTED"; },
                                 [&](const ton::ManualDns::EntryDataSmcAddress& text) { res = "UNSUPPORTED"; }));
  return res;
}

td::Result<td::optional<ManualDns::EntryData>> ManualDns::parse_data(td::Slice cmd) {
  td::ConstParser parser(cmd);
  parser.skip_whitespaces();
  auto type = parser.read_till(':');
  parser.skip(':');
  if (type == "TEXT") {
    return ManualDns::EntryData::text(parser.read_all().str());
  } else if (type == "ADNL") {
    TRY_RESULT(address, td::adnl_id_decode(parser.read_all()));
    return ManualDns::EntryData::adnl_address(address);
  } else if (type == "SMC") {
    TRY_RESULT(address, block::StdAddress::parse(parser.read_all()));
    return ManualDns::EntryData::smc_address(address);
  } else if (type == "NEXT") {
    TRY_RESULT(address, block::StdAddress::parse(parser.read_all()));
    return ManualDns::EntryData::next_resolver(address);
  } else if (parser.data() == "DELETED") {
    return {};
  }
  return td::Status::Error(PSLICE() << "Unknown entry type: " << type);
}

td::Result<ManualDns::ActionExt> ManualDns::parse_line(td::Slice cmd) {
  // Cmd =
  //   set name category data |
  //   delete.name name |
  //   delete.all
  // data =
  //   TEXT:<text> |
  //   SMC:<smartcontract address> |
  //   NEXT:<smartcontract address> |
  //   ADNL:<adnl address>
  //   DELETED
  td::ConstParser parser(cmd);
  auto type = parser.read_word();
  if (type == "set") {
    auto name = parser.read_word();
    auto category_str = parser.read_word();
    TRY_RESULT(category, td::to_integer_safe<td::int16>(category_str));
    TRY_RESULT(data, parse_data(parser.read_all()));
    return ManualDns::ActionExt{name.str(), category, std::move(data)};
  } else if (type == "delete.name") {
    auto name = parser.read_word();
    if (name.empty()) {
      return td::Status::Error("name is empty");
    }
    return ManualDns::ActionExt{name.str(), 0, {}};
  } else if (type == "delete.all") {
    return ManualDns::ActionExt{"", 0, {}};
  }
  return td::Status::Error(PSLICE() << "Unknown command: " << type);
}

td::Result<std::vector<ManualDns::ActionExt>> ManualDns::parse(td::Slice cmd) {
  auto lines = td::full_split(cmd, '\n');
  std::vector<ManualDns::ActionExt> res;
  res.reserve(lines.size());
  for (auto& line : lines) {
    td::ConstParser parser(line);
    parser.skip_whitespaces();
    if (parser.empty()) {
      continue;
    }
    TRY_RESULT(action, parse_line(parser.read_all()));
    res.push_back(std::move(action));
  }
  return res;
}

}  // namespace ton
