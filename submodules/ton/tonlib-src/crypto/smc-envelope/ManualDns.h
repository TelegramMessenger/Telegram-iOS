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
#pragma once
#include "td/utils/Variant.h"
#include "td/utils/Status.h"
#include "vm/cells/Cell.h"
#include "vm/cells/CellSlice.h"
#include "vm/cells/CellString.h"

#include "smc-envelope/SmartContract.h"

#include "Ed25519.h"

#include <map>

namespace ton {
class DnsInterface {
 public:
  struct EntryDataText {
    std::string text;
    bool operator==(const EntryDataText& other) const {
      return text == other.text;
    }
  };

  struct EntryDataNextResolver {
    block::StdAddress resolver;
    bool operator==(const EntryDataNextResolver& other) const {
      return resolver == other.resolver;
    }
  };

  struct EntryDataAdnlAddress {
    ton::Bits256 adnl_address;
    // TODO: proto
    bool operator==(const EntryDataAdnlAddress& other) const {
      return adnl_address == other.adnl_address;
    }
  };

  struct EntryDataSmcAddress {
    block::StdAddress smc_address;
    bool operator==(const EntryDataSmcAddress& other) const {
      return smc_address == other.smc_address;
    }
    // TODO: capability
  };

  struct EntryData {
    enum Type { Empty, Text, NextResolver, AdnlAddress, SmcAddress } type{Empty};
    td::Variant<EntryDataText, EntryDataNextResolver, EntryDataAdnlAddress, EntryDataSmcAddress> data;

    static EntryData text(std::string text) {
      return {Text, EntryDataText{text}};
    }
    static EntryData next_resolver(block::StdAddress resolver) {
      return {NextResolver, EntryDataNextResolver{resolver}};
    }
    static EntryData adnl_address(ton::Bits256 adnl_address) {
      return {AdnlAddress, EntryDataAdnlAddress{adnl_address}};
    }
    static EntryData smc_address(block::StdAddress smc_address) {
      return {SmcAddress, EntryDataSmcAddress{smc_address}};
    }

    bool operator==(const EntryData& other) const {
      return data == other.data;
    }
    friend td::StringBuilder& operator<<(td::StringBuilder& sb, const EntryData& data);

    td::Result<td::Ref<vm::Cell>> as_cell() const;
    static td::Result<EntryData> from_cellslice(vm::CellSlice& cs);
  };

  struct Entry {
    std::string name;
    td::int16 category;
    EntryData data;
    auto key() const {
      return std::tie(name, category);
    }
    bool operator<(const Entry& other) const {
      return key() < other.key();
    }
    bool operator==(const Entry& other) const {
      return key() == other.key() && data == other.data;
    }
    friend td::StringBuilder& operator<<(td::StringBuilder& sb, const Entry& entry) {
      sb << entry.name << ":" << entry.category << ":" << entry.data;
      return sb;
    }
  };
  struct RawEntry {
    std::string name;
    td::int16 category;
    td::Ref<vm::Cell> data;
  };

  struct ActionExt {
    std::string name;
    td::int16 category;
    td::optional<EntryData> data;
    static td::Result<ActionExt> parse(td::Slice);
  };

  struct Action {
    std::string name;
    td::int16 category;
    td::optional<td::Ref<vm::Cell>> data;

    bool does_create_category() const {
      CHECK(!name.empty());
      CHECK(category != 0);
      return static_cast<bool>(data);
    }
    bool does_change_empty() const {
      CHECK(!name.empty());
      CHECK(category != 0);
      return static_cast<bool>(data) && data.value().not_null();
    }
    void make_non_empty() {
      CHECK(!name.empty());
      CHECK(category != 0);
      if (!data) {
        data = td::Ref<vm::Cell>();
      }
    }
    friend td::StringBuilder& operator<<(td::StringBuilder& sb, const Action& action) {
      sb << action.name << ":" << action.category << ":";
      if (action.data) {
        if (action.data.value().is_null()) {
          sb << "<null>";
        } else {
          sb << "<data>";
        }
      } else {
        sb << "<empty>";
      }
      return sb;
    }
  };

  virtual ~DnsInterface() {
  }
  virtual size_t get_max_name_size() const = 0;
  virtual td::Result<std::vector<RawEntry>> resolve_raw(td::Slice name, td::int32 category) const = 0;
  virtual td::Result<td::Ref<vm::Cell>> create_update_query(
      td::Ed25519::PrivateKey& pk, td::Span<Action> actions,
      td::uint32 valid_until = std::numeric_limits<td::uint32>::max()) const = 0;

  td::Result<std::vector<Entry>> resolve(td::Slice name, td::int32 category) const;

  static std::string encode_name(td::Slice name);
  static std::string decode_name(td::Slice name);

  static size_t get_default_max_name_size() {
    return 128;
  }
  static SmartContract::Args resolve_args_raw(td::Slice encoded_name, td::int16 category);
  static td::Result<SmartContract::Args> resolve_args(td::Slice name, td::int32 category);
};

class ManualDns : public ton::SmartContract, public DnsInterface {
 public:
  ManualDns(State state) : SmartContract(std::move(state)) {
  }

  ManualDns* make_copy() const override {
    return new ManualDns{state_};
  }

  // creation
  static td::Ref<ManualDns> create(State state) {
    return td::Ref<ManualDns>(true, std::move(state));
  }
  static td::Ref<ManualDns> create(td::Ref<vm::Cell> data = {}, int revision = 0);
  static td::Ref<ManualDns> create(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id, int revision = 0);

  static std::string serialize_data(const EntryData& data);
  static td::Result<td::optional<ManualDns::EntryData>> parse_data(td::Slice cmd);
  static td::Result<ManualDns::ActionExt> parse_line(td::Slice cmd);
  static td::Result<std::vector<ManualDns::ActionExt>> parse(td::Slice cmd);

  static td::optional<td::int32> guess_revision(const vm::Cell::Hash& code_hash);
  static td::optional<td::int32> guess_revision(const block::StdAddress& address,
                                                const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id);

  td::Ref<vm::Cell> create_init_data(const td::Ed25519::PublicKey& public_key, td::uint32 valid_until) const {
    return create_init_data_fast(public_key, valid_until);
  }

  td::Result<td::uint32> get_wallet_id() const;
  td::Result<td::uint32> get_wallet_id_or_throw() const;

  td::Result<td::Ref<vm::Cell>> create_set_value_unsigned(td::int16 category, td::Slice name,
                                                          td::Ref<vm::Cell> data) const;
  td::Result<td::Ref<vm::Cell>> create_delete_value_unsigned(td::int16 category, td::Slice name) const;
  td::Result<td::Ref<vm::Cell>> create_delete_all_unsigned() const;
  td::Result<td::Ref<vm::Cell>> create_set_all_unsigned(td::Span<Action> entries) const;
  td::Result<td::Ref<vm::Cell>> create_delete_name_unsigned(td::Slice name) const;
  td::Result<td::Ref<vm::Cell>> create_set_name_unsigned(td::Slice name, td::Span<Action> entries) const;

  td::Result<td::Ref<vm::Cell>> prepare(td::Ref<vm::Cell> data, td::uint32 valid_until) const;

  static td::Result<td::Ref<vm::Cell>> sign(const td::Ed25519::PrivateKey& private_key, td::Ref<vm::Cell> data);
  static td::Ref<vm::Cell> create_init_data_fast(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id);

  size_t get_max_name_size() const override;
  td::Result<std::vector<RawEntry>> resolve_raw(td::Slice name, td::int32 category_big) const override;
  td::Result<std::vector<RawEntry>> resolve_raw_or_throw(td::Slice name, td::int32 category_big) const;

  td::Result<td::Ref<vm::Cell>> create_init_query(
      const td::Ed25519::PrivateKey& private_key,
      td::uint32 valid_until = std::numeric_limits<td::uint32>::max()) const;
  td::Result<td::Ref<vm::Cell>> create_update_query(
      td::Ed25519::PrivateKey& pk, td::Span<Action> actions,
      td::uint32 valid_until = std::numeric_limits<td::uint32>::max()) const override;

  template <class ActionT>
  struct CombinedActions {
    std::string name;
    td::int16 category{0};
    td::optional<std::vector<ActionT>> actions;
    friend td::StringBuilder& operator<<(td::StringBuilder& sb, const CombinedActions& action) {
      sb << action.name << ":" << action.category << ":";
      if (action.actions) {
        sb << "<data>" << action.actions.value().size();
      } else {
        sb << "<empty>";
      }
      return sb;
    }
  };

  template <class ActionT = Action>
  static std::vector<CombinedActions<ActionT>> combine_actions(td::Span<ActionT> actions) {
    struct Info {
      std::set<td::int16> known_category;
      std::vector<ActionT> actions;
      bool closed{false};
      bool non_empty{false};
    };

    std::map<std::string, Info> mp;
    std::vector<CombinedActions<ActionT>> res;
    for (auto& action : td::reversed(actions)) {
      if (action.name.empty()) {
        CombinedActions<ActionT> set_all;
        set_all.actions = std::vector<ActionT>();
        for (auto& it : mp) {
          for (auto& e : it.second.actions) {
            if (e.does_create_category()) {
              set_all.actions.value().push_back(std::move(e));
            }
          }
        }
        res.push_back(std::move(set_all));
        return res;
      }

      Info& info = mp[action.name];
      if (info.closed) {
        continue;
      }
      if (action.category != 0 && action.does_create_category()) {
        info.non_empty = true;
      }
      if (!info.known_category.insert(action.category).second) {
        continue;
      }
      if (action.category == 0) {
        info.closed = true;
        auto old_actions = std::move(info.actions);
        bool is_empty = true;
        for (auto& action : old_actions) {
          if (is_empty && action.does_create_category()) {
            info.actions.push_back(std::move(action));
            is_empty = false;
          } else if (!is_empty && action.does_change_empty()) {
            info.actions.push_back(std::move(action));
          }
        }
      } else {
        info.actions.push_back(std::move(action));
      }
    }

    for (auto& it : mp) {
      auto& info = it.second;
      if (info.closed) {
        CombinedActions<ActionT> ca;
        ca.name = it.first;
        ca.category = 0;
        if (!info.actions.empty() || info.non_empty) {
          ca.actions = std::move(info.actions);
        }
        res.push_back(std::move(ca));
      } else {
        bool need_non_empty = info.non_empty;
        for (auto& a : info.actions) {
          if (need_non_empty) {
            a.make_non_empty();
            need_non_empty = false;
          }
          CombinedActions<ActionT> ca;
          ca.name = a.name;
          ca.category = a.category;
          ca.actions = std::vector<ActionT>();
          ca.actions.value().push_back(std::move(a));
          res.push_back(ca);
        }
      }
    }
    return res;
  }
  td::Result<td::Ref<vm::Cell>> create_update_query(CombinedActions<Action>& combined) const;
};

}  // namespace ton
