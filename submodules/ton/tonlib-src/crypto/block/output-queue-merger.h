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
#pragma once
#include "ton/ton-types.h"
#include "vm/cells/CellSlice.h"
#include "block/mc-config.h"

namespace block {
using td::Ref;

struct OutputQueueMerger {
  struct MsgKeyValue {
    static constexpr int max_key_len = 32 + 64 + 256;
    Ref<vm::CellSlice> msg;
    unsigned long long lt;
    int source;
    int key_len{0};
    td::BitArray<max_key_len> key;
    MsgKeyValue() = default;
    MsgKeyValue(int src, Ref<vm::Cell> node);
    MsgKeyValue(td::ConstBitPtr key_pfx, int key_pfx_len, int src, Ref<vm::Cell> node);
    bool operator<(const MsgKeyValue& other) const;
    bool is_fork() const {
      return key_len < max_key_len;
    }
    bool invalidate();
    static bool less(const std::unique_ptr<MsgKeyValue>& he1, const std::unique_ptr<MsgKeyValue>& he2);
    static bool greater(const std::unique_ptr<MsgKeyValue>& he1, const std::unique_ptr<MsgKeyValue>& he2);

   protected:
    friend struct OutputQueueMerger;
    static ton::LogicalTime get_node_lt(Ref<vm::Cell> node, int key_pfx_len);
    bool replace_with_child(bool child_idx);
    bool replace_by_prefix(td::ConstBitPtr req_pfx, int req_pfx_len);
    bool unpack_node(td::ConstBitPtr key_pfx, int key_pfx_len, Ref<vm::Cell> node);
    bool split(MsgKeyValue& second);
  };
  //
  ton::ShardIdFull queue_for;
  std::vector<std::unique_ptr<MsgKeyValue>> msg_list;
  std::vector<block::McShardDescr> neighbors;

 public:
  OutputQueueMerger(ton::ShardIdFull _queue_for, std::vector<block::McShardDescr> _neighbors);
  bool is_eof() const {
    return eof;
  }
  MsgKeyValue* cur();
  std::unique_ptr<MsgKeyValue> extract_cur();
  bool next();

 private:
  td::BitArray<32 + 64> common_pfx;
  int common_pfx_len;
  std::vector<std::unique_ptr<MsgKeyValue>> heap;
  std::size_t pos{0};
  bool eof;
  bool failed;
  void init();
  bool add_root(int src, Ref<vm::Cell> outmsg_root);
  bool load();
};

}  // namespace block
