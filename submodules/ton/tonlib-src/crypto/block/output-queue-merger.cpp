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
#include "output-queue-merger.h"

namespace block {

/*
 * 
 *  OUTPUT QUEUE MERGER 
 * 
 */

bool OutputQueueMerger::MsgKeyValue::operator<(const MsgKeyValue& other) const {
  return lt < other.lt ||
         (lt == other.lt && td::bitstring::bits_memcmp(key.cbits() + 96, other.key.cbits() + 96, 256) < 0);
}

bool OutputQueueMerger::MsgKeyValue::less(const std::unique_ptr<MsgKeyValue>& he1,
                                          const std::unique_ptr<MsgKeyValue>& he2) {
  return *he1 < *he2;
}

bool OutputQueueMerger::MsgKeyValue::greater(const std::unique_ptr<MsgKeyValue>& he1,
                                             const std::unique_ptr<MsgKeyValue>& he2) {
  return *he2 < *he1;
}

OutputQueueMerger::MsgKeyValue::MsgKeyValue(td::ConstBitPtr key_pfx, int key_pfx_len, int _src, Ref<vm::Cell> node)
    : source(_src) {
  unpack_node(key_pfx, key_pfx_len, std::move(node));
}

OutputQueueMerger::MsgKeyValue::MsgKeyValue(int _src, Ref<vm::Cell> node) : source(_src) {
  unpack_node(td::ConstBitPtr{nullptr}, 0, std::move(node));
}

bool OutputQueueMerger::MsgKeyValue::invalidate() {
  msg.clear();
  lt = 0;
  source = -1;
  return false;
}

ton::LogicalTime OutputQueueMerger::MsgKeyValue::get_node_lt(Ref<vm::Cell> node, int key_pfx_len) {
  if (node.is_null() || (unsigned)key_pfx_len > (unsigned)max_key_len) {
    return std::numeric_limits<td::uint64>::max();
  }
  vm::dict::LabelParser label{std::move(node), max_key_len - key_pfx_len, vm::dict::LabelParser::chk_size};
  if (!label.is_valid()) {
    return std::numeric_limits<td::uint64>::max();
  }
  label.skip_label();
  return label.remainder->prefetch_ulong(64);
}

bool OutputQueueMerger::MsgKeyValue::unpack_node(td::ConstBitPtr key_pfx, int key_pfx_len, Ref<vm::Cell> node) {
  if (node.is_null() || (unsigned)key_pfx_len >= (unsigned)max_key_len) {
    return invalidate();
  }
  if (!key_pfx.is_null()) {
    td::bitstring::bits_memcpy(key.bits(), key_pfx, key_pfx_len);
  }
  vm::dict::LabelParser label{std::move(node), max_key_len - key_pfx_len, vm::dict::LabelParser::chk_size};
  if (!label.is_valid()) {
    return invalidate();
  }
  label.extract_label_to(key.bits() + key_pfx_len);
  key_len = key_pfx_len + label.l_bits;
  msg = std::move(label.remainder);
  if (!msg.write().fetch_uint_to(64, lt)) {
    return invalidate();
  }
  if (is_fork() && msg->size_ext() != 0x20000) {
    return invalidate();
  }
  return true;
}

bool OutputQueueMerger::MsgKeyValue::replace_with_child(bool child_idx) {
  if (!is_fork() || msg.is_null() || msg->size_ext() != 0x20000) {
    return false;
  }
  key[key_len] = child_idx;
  return unpack_node(td::ConstBitPtr{nullptr}, key_len + 1, msg->prefetch_ref(child_idx));
}

bool OutputQueueMerger::MsgKeyValue::replace_by_prefix(td::ConstBitPtr req_pfx, int req_pfx_len) {
  do {
    if (td::bitstring::bits_memcmp(req_pfx, key.cbits(), std::min(req_pfx_len, key_len))) {
      return false;
    }
    if (key_len >= req_pfx_len) {
      return true;
    }
  } while (replace_with_child(req_pfx[key_len]));
  return false;
}

bool OutputQueueMerger::MsgKeyValue::split(MsgKeyValue& second) {
  if (!is_fork() || msg.is_null()) {
    return false;
  }
  unsigned long long keep_lt = lt;
  unsigned long long left_lt = get_node_lt(msg->prefetch_ref(0), key_len + 1);
  bool sw = (left_lt == lt);
  second.source = source;
  key[key_len] = sw;
  if (!second.unpack_node(key.cbits(), key_len + 1, msg->prefetch_ref(sw))) {
    return false;
  }
  key[key_len] = 1 - sw;
  if (!unpack_node(td::ConstBitPtr{nullptr}, key_len + 1, msg->prefetch_ref(1 - sw))) {
    return false;
  }
  if (lt != keep_lt || second.lt < keep_lt) {
    return false;
  }
  return true;
}

bool OutputQueueMerger::add_root(int src, Ref<vm::Cell> outmsg_root) {
  if (outmsg_root.is_null()) {
    return true;
  }
  //block::gen::HashmapAug{352, block::gen::t_EnqueuedMsg, block::gen::t_uint64}.print_ref(std::cerr, outmsg_root);
  auto kv = std::make_unique<MsgKeyValue>(src, std::move(outmsg_root));
  if (kv->replace_by_prefix(common_pfx.cbits(), common_pfx_len)) {
    heap.push_back(std::move(kv));
  }
  return true;
}

OutputQueueMerger::OutputQueueMerger(ton::ShardIdFull _queue_for, std::vector<block::McShardDescr> _neighbors)
    : queue_for(_queue_for), neighbors(std::move(_neighbors)), eof(false), failed(false) {
  init();
}

void OutputQueueMerger::init() {
  common_pfx.bits().store_int(queue_for.workchain, 32);
  int l = queue_for.pfx_len();
  td::bitstring::bits_store_long_top(common_pfx.bits() + 32, queue_for.shard, l);
  common_pfx_len = 32 + l;
  int i = 0;
  for (block::McShardDescr& neighbor : neighbors) {
    if (!neighbor.is_disabled()) {
      LOG(DEBUG) << "adding " << (neighbor.outmsg_root.is_null() ? "" : "non-") << "empty output queue for neighbor #"
                 << i << " (" << neighbor.blk_.to_str() << ")";
      add_root(i++, neighbor.outmsg_root);
    } else {
      LOG(DEBUG) << "skipping output queue for disabled neighbor #" << i;
      i++;
    }
  }
  std::make_heap(heap.begin(), heap.end(), MsgKeyValue::greater);
  eof = heap.empty();
  if (!eof) {
    load();
  }
}

OutputQueueMerger::MsgKeyValue* OutputQueueMerger::cur() {
  return eof ? nullptr : msg_list.at(pos).get();
}

std::unique_ptr<OutputQueueMerger::MsgKeyValue> OutputQueueMerger::extract_cur() {
  return eof ? std::unique_ptr<MsgKeyValue>{} : std::move(msg_list.at(pos));
}

bool OutputQueueMerger::next() {
  if (eof) {
    return false;
  } else if (++pos < msg_list.size() || load()) {
    return true;
  } else {
    eof = true;
    return false;
  }
}

bool OutputQueueMerger::load() {
  if (heap.empty() || failed) {
    return false;
  }
  unsigned long long lt = heap[0]->lt;
  std::size_t orig_size = msg_list.size();
  do {
    while (heap[0]->is_fork()) {
      auto other = std::make_unique<MsgKeyValue>();
      if (!heap[0]->split(*other)) {
        failed = true;
        return false;
      }
      heap.push_back(std::move(other));
      std::push_heap(heap.begin(), heap.end(), MsgKeyValue::greater);
    }
    assert(heap[0]->lt == lt);
    std::pop_heap(heap.begin(), heap.end(), MsgKeyValue::greater);
    msg_list.push_back(std::move(heap.back()));
    heap.pop_back();
  } while (!heap.empty() && heap[0]->lt <= lt);
  std::sort(msg_list.begin() + orig_size, msg_list.end(), MsgKeyValue::less);
  return true;
}

}  // namespace block
