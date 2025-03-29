//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/Trie.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/misc.h"
#include "td/utils/Span.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

#include <iostream>
#include <utility>

namespace tde2e_core {

TrieNode::TrieNode() : data(Empty{}) {
  hash = compute_hash();
}

TrieNode::TrieNode(BitString key_suffix, std::string value) : data(Leaf{std::move(key_suffix), std::move(value)}) {
  hash = compute_hash();
}
TrieNode::TrieNode(BitString prefix, TrieRef left, TrieRef right)
    : data(Inner{std::move(prefix), std::move(left), std::move(right)}) {
  hash = compute_hash();
}

TrieNode::TrieNode(const td::UInt256 &hash_value) : hash(hash_value), data(Pruned{-1, {}}) {
}
TrieNode::TrieNode(const td::UInt256 &hash_value, td::int64 offset, BitString base_bit_string)
    : hash(hash_value), data(Pruned{offset, std::move(base_bit_string)}) {
}
TrieRef TrieNode::empty_node() {
  static TrieRef node = std::make_shared<TrieNode>();
  return node;
}

td::Result<TrieNode> fetch_node_from_snapshot(td::Slice, BitString &bs);

td::Status TrieNode::try_load(td::Slice snapshot) const {
  CHECK(get_type() == TrieNodeType::Pruned);
  const auto &pruned = get_pruned();
  if (pruned.offset < 0) {
    return td::Status::Error("Cannot load pruned node");
  }
  if (td::narrow_cast<size_t>(pruned.offset) > snapshot.size()) {
    return td::Status::Error("Cannot load pruned node: invalid offset");
  }
  auto bs = pruned.base_bit_string;
  if (!bs.data_) {
    bs = BitString(nullptr, bs.begin_bit_, bs.bits_size_);
  }
  TRY_RESULT(new_node, fetch_node_from_snapshot(snapshot.substr(td::narrow_cast<std::size_t>(pruned.offset)), bs));
  if (new_node.hash != hash) {
    return td::Status::Error("Cannot load pruned node: hash mismatch");
  }
  const_cast<TrieNode &>(*this) = std::move(new_node);
  return td::Status::OK();
}

template <class StorerT>
void store_for_hash(const TrieNode &node, StorerT &storer) {
  using td::store;
  auto type = node.get_type();
  if (type == TrieNodeType::Leaf) {
    store(type, storer);
    auto &leaf = node.get_leaf();
    store(leaf.key_suffix, storer);
    store(leaf.value, storer);
  } else if (type == TrieNodeType::Inner) {
    store(type, storer);
    auto &inner = node.get_inner();
    store(inner.prefix, storer);
    store(inner.left->hash, storer);
    store(inner.right->hash, storer);
  } else if (type == TrieNodeType::Empty) {
    store(type, storer);
  } else {
    UNREACHABLE();
  }
}

td::UInt256 TrieNode::compute_hash() const {
  td::TlStorerCalcLength calc_length;
  store_for_hash(*this, calc_length);
  std::string buf(calc_length.get_length(), 0);
  td::TlStorerUnsafe storer(td::MutableSlice(buf).ubegin());
  store_for_hash(*this, storer);
  td::UInt256 result_hash;
  sha256(buf, result_hash.as_mutable_slice());
  return result_hash;
}

td::Result<TrieRef> set(const TrieRef &n, BitString key, td::Slice value, td::Slice snapshot) {
  CHECK(n);
  auto type = n->get_type();

  if (type == TrieNodeType::Pruned) {
    TRY_STATUS(n->try_load(snapshot));
    type = n->get_type();
    CHECK(type != TrieNodeType::Pruned);
  }

  if (type == TrieNodeType::Empty) {
    return std::make_shared<TrieNode>(std::move(key), value.str());
  }

  if (type == TrieNodeType::Leaf) {
    const auto &leaf = n->get_leaf();
    if (key == leaf.key_suffix) {
      return std::make_shared<TrieNode>(key, value.str());
    } else {
      size_t i = key.common_prefix_length(leaf.key_suffix);
      // TODO: what if one key is prefix of another?.. Do we care?

      auto common_prefix = key.substr(0, i);

      auto bit = key.get_bit(i);
      auto left = std::make_shared<TrieNode>(key.substr(i + 1), value.str());
      auto right = std::make_shared<TrieNode>(leaf.key_suffix.substr(i + 1), leaf.value);
      if (bit) {
        std::swap(left, right);
      }
      return std::make_shared<TrieNode>(std::move(common_prefix), std::move(left), std::move(right));
    }
  }

  if (type == TrieNodeType::Inner) {
    const auto &inner = n->get_inner();
    size_t i = inner.prefix.common_prefix_length(key);

    if (i < inner.prefix.bit_length()) {
      auto common_prefix = inner.prefix.substr(0, i);
      auto remaining_prefix = inner.prefix.substr(i + 1);
      auto bit = inner.prefix.get_bit(i);

      auto left = std::make_shared<TrieNode>(remaining_prefix, inner.left, inner.right);
      auto right = std::make_shared<TrieNode>(key.substr(i + 1), value.str());

      if (bit) {
        std::swap(left, right);
      }

      return std::make_shared<TrieNode>(common_prefix, std::move(left), std::move(right));
    } else {
      auto key_bit = key.get_bit(i);
      auto left = inner.left;
      auto right = inner.right;
      if (key_bit) {
        TRY_RESULT_ASSIGN(right, set(right, key.substr(i + 1), value.str(), snapshot));
      } else {
        TRY_RESULT_ASSIGN(left, set(left, key.substr(i + 1), value.str(), snapshot));
      }
      return std::make_shared<TrieNode>(inner.prefix, std::move(left), std::move(right));
    }
  }

  return nullptr;
}

td::Result<std::string> get(const TrieRef &n, const BitString &key, td::Slice snapshot) {
  CHECK(n);
  auto type = n->get_type();

  if (type == TrieNodeType::Pruned) {
    TRY_STATUS(n->try_load(snapshot));
    type = n->get_type();
    CHECK(type != TrieNodeType::Pruned);
  }

  if (type == TrieNodeType::Empty) {
    return "";
  }

  if (type == TrieNodeType::Leaf) {
    auto &leaf = n->get_leaf();
    if (key == leaf.key_suffix) {
      return leaf.value;
    } else {
      return "";
    }
  }

  if (type == TrieNodeType::Inner) {
    const auto &inner = n->get_inner();
    auto prefix_length = inner.prefix.bit_length();
    if (key.common_prefix_length(inner.prefix) != prefix_length) {
      return "";
    }

    auto key_bit = key.get_bit(prefix_length);
    if (key_bit) {
      return get(inner.right, key.substr(prefix_length + 1), snapshot);
    } else {
      return get(inner.left, key.substr(prefix_length + 1), snapshot);
    }
  }

  return "";
}
BitString to_key(td::Slice key) {
  std::string buf;
  if (key.size() != 32) {
    buf.resize(32, 0);
    td::MutableSlice(buf).copy_from(key);
    key = buf;
  }
  return BitString(key);
}

td::Result<TrieRef> prune_node(const TrieRef &n, td::MutableSpan<BitString> keys, td::Slice snapshot) {
  CHECK(n);
  auto type = n->get_type();

  if (type == TrieNodeType::Pruned) {
    TRY_STATUS(n->try_load(snapshot));
    type = n->get_type();
    CHECK(type != TrieNodeType::Pruned);
  }

  if (type == TrieNodeType::Empty) {
    return n;
  }

  if (keys.empty()) {
    return std::make_shared<TrieNode>(n->hash);
  }

  if (type == TrieNodeType::Leaf) {
    return n;
  }

  if (type == TrieNodeType::Inner) {
    const auto &inner = n->get_inner();
    std::vector<BitString> left_keys;
    std::vector<BitString> right_keys;
    for (const auto &key : keys) {
      auto prefix_len = inner.prefix.bit_length();
      if (key.common_prefix_length(inner.prefix) == prefix_len) {
        if (key.get_bit(prefix_len)) {
          right_keys.push_back(key.substr(prefix_len + 1));
        } else {
          left_keys.push_back(key.substr(prefix_len + 1));
        }
      }
    }
    TRY_RESULT(left, prune_node(inner.left, left_keys, snapshot));
    TRY_RESULT(right, prune_node(inner.right, right_keys, snapshot));
    return std::make_shared<TrieNode>(inner.prefix, std::move(left), std::move(right));
  }
  return n;
}

td::Result<TrieRef> generate_pruned_tree(const TrieRef &n, td::Span<td::Slice> keys, td::Slice snapshot) {
  auto v = td::transform(keys, to_key);
  return prune_node(n, v, snapshot);
}

std::ostream &operator<<(std::ostream &os, const td::UInt256 &hash) {
  os << std::hex;
  for (auto c : hash.raw) {
    os << (c >> 4);
    os << (c & 0xF);
  }
  os << std::dec;  // Reset to decimal
  return os;
}

void print_tree(const TrieRef &node, const std::string &prefix, bool is_root) {
  if (!node) {
    std::cout << prefix << "(null)\n";
    return;
  }

  std::string type_str;
  auto type = node->get_type();
  switch (type) {
    case TrieNodeType::Empty:
      type_str = "Empty";
      break;
    case TrieNodeType::Leaf:
      type_str = "Leaf";
      break;
    case TrieNodeType::Inner:
      type_str = "Inner";
      break;
    case TrieNodeType::Pruned:
      type_str = "Pruned";
      break;
  }

  std::cout << prefix;
  if (is_root) {
    std::cout << "Root ";
  }
  std::cout << type_str << " Node, Hash: " << node->hash << "\n";

  if (type == TrieNodeType::Leaf) {
    const auto &leaf = node->get_leaf();
    std::cout << prefix << "  Key Suffix: " << leaf.key_suffix << "\n";
    std::cout << prefix << "  Value: " << leaf.value << "\n";
  } else if (type == TrieNodeType::Inner) {
    const auto &inner = node->get_inner();
    std::cout << prefix << "  Prefix: " << inner.prefix << "\n";
    std::cout << prefix << "  Children:\n";
    std::string child_prefix = prefix + "    ";
    std::cout << prefix << "    [0]\n";
    print_tree(inner.left, child_prefix, false);
    std::cout << prefix << "    [1]\n";
    print_tree(inner.right, child_prefix, false);
  }
}

template <class StorerT>
void store_for_network(const TrieNode &node, StorerT &storer) {
  using td::store;
  auto type = node.get_type();
  store(type, storer);
  if (type == TrieNodeType::Leaf) {
    auto &leaf = node.get_leaf();
    store(leaf.key_suffix, storer);
    store(leaf.value, storer);
  } else if (type == TrieNodeType::Inner) {
    auto &inner = node.get_inner();
    store(inner.prefix, storer);
    store_for_network(*inner.left, storer);
    store_for_network(*inner.right, storer);
  } else if (type == TrieNodeType::Pruned) {
    store(node.hash, storer);
  } else if (type == TrieNodeType::Empty) {
  } else {
    UNREACHABLE();
  }
}

template <class ParserT>
void parse_from_network(TrieRef &ref, ParserT &parser) {
  BitString bs(256);
  parse_from_network(ref, parser, bs);
}

template <class ParserT>
void parse_from_network(TrieRef &ref, ParserT &parser, BitString &bs) {
  using td::parse;
  TrieNodeType type;
  parse(type, parser);
  if (type == TrieNodeType::Leaf) {
    BitString key_suffix = fetch_bit_string(parser, bs);
    std::string value;
    parse(value, parser);
    ref = std::make_shared<TrieNode>(std::move(key_suffix), std::move(value));
  } else if (type == TrieNodeType::Inner) {
    BitString prefix = fetch_bit_string(parser, bs);
    TrieRef left;
    TrieRef right;

    auto left_bs = bs.substr(prefix.bit_length() + 1);
    parse_from_network(left, parser, left_bs);
    auto right_bs = BitString(nullptr, left_bs.begin_bit_, left_bs.bit_length());
    parse_from_network(right, parser, right_bs);
    ref = std::make_shared<TrieNode>(std::move(prefix), std::move(left), std::move(right));
  } else if (type == TrieNodeType::Pruned) {
    td::UInt256 hash;
    parse(hash, parser);
    ref = std::make_shared<TrieNode>(std::move(hash));
  } else if (type == TrieNodeType::Empty) {
    ref = TrieNode::empty_node();
  } else {
    UNREACHABLE();
  }
}

td::Result<std::string> TrieNode::serialize_for_network(const TrieRef &node) {
  td::TlStorerCalcLength calc_length;
  store_for_network(*node, calc_length);
  std::string buf(calc_length.get_length(), 0);
  td::TlStorerUnsafe storer(td::MutableSlice(buf).ubegin());
  store_for_network(*node, storer);
  return buf;
}

td::Result<TrieRef> TrieNode::fetch_from_network(td::Slice data) {
  td::TlParser parser(data);
  TrieRef res;
  parse_from_network(res, parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  CHECK(res);
  return res;
}

template <class StorerT, class F>
td::Result<td::int64> store_for_snapshot(const TrieNode &node, StorerT &storer, const F &get_offset,
                                         td::Slice snapshot) {
  using td::store;
  auto type = node.get_type();

  if (type == TrieNodeType::Pruned) {
    TRY_STATUS(node.try_load(snapshot));
    type = node.get_type();
    CHECK(type != TrieNodeType::Pruned);
  }

  if (type == TrieNodeType::Leaf) {
    auto &leaf = node.get_leaf();
    auto offset = get_offset();
    store(type, storer);
    store(leaf.key_suffix, storer);
    store(leaf.value, storer);
    return offset;
  } else if (type == TrieNodeType::Inner) {
    auto &inner = node.get_inner();
    TRY_RESULT(left_offset, store_for_snapshot(*inner.left, storer, get_offset, snapshot));
    TRY_RESULT(right_offset, store_for_snapshot(*inner.right, storer, get_offset, snapshot));
    auto offset = get_offset();
    store(type, storer);
    store(inner.prefix, storer);
    store(left_offset, storer);
    store(inner.left->hash, storer);
    store(right_offset, storer);
    store(inner.right->hash, storer);
    return offset;
  } else if (type == TrieNodeType::Empty) {
    auto offset = get_offset();
    store(type, storer);
    return offset;
  } else {
    UNREACHABLE();
  }
}

td::Result<std::string> TrieNode::serialize_for_snapshot(const TrieRef &node, td::Slice snapshot) {
  td::TlStorerCalcLength calc_length;
  TRY_STATUS(store_for_snapshot(
      *node, calc_length, [] { return td::int64{0}; }, snapshot));
  std::string buf(calc_length.get_length() + 8, 0);
  auto begin = td::MutableSlice(buf).ubegin();
  td::TlStorerUnsafe storer(begin + 8);
  auto get_offset = [&] {
    return td::int64{storer.get_buf() - begin};
  };
  TRY_RESULT(root_offset, store_for_snapshot(*node, storer, get_offset, snapshot));
  td::TlStorerUnsafe storer2(begin);
  storer2.store_long(root_offset);
  return buf;
}

td::Result<TrieNode> fetch_node_from_snapshot(td::Slice snapshot_slice, BitString &bs) {
  td::TlParser parser(snapshot_slice);
  using td::parse;
  TrieNodeType type;
  parse(type, parser);
  if (type == TrieNodeType::Leaf) {
    BitString key_suffix = fetch_bit_string(parser, bs);
    std::string value;
    parse(value, parser);
    //parser.fetch_end();
    TRY_STATUS(parser.get_status());
    return TrieNode(std::move(key_suffix), std::move(value));
  } else if (type == TrieNodeType::Inner) {
    BitString prefix = fetch_bit_string(parser, bs);
    td::int64 left_offset;
    td::UInt256 left_hash;
    parse(left_offset, parser);
    parse(left_hash, parser);
    td::int64 right_offset;
    td::UInt256 right_hash;
    parse(right_offset, parser);
    parse(right_hash, parser);
    //parser.fetch_end();
    TRY_STATUS(parser.get_status());

    auto left_bs = bs.substr(prefix.bit_length() + 1);
    BitString right_bs;
    right_bs.begin_bit_ = left_bs.begin_bit_;
    right_bs.bits_size_ = left_bs.bits_size_;
    auto left = std::make_shared<TrieNode>(left_hash, left_offset, std::move(left_bs));
    auto right = std::make_shared<TrieNode>(right_hash, right_offset, std::move(right_bs));
    return TrieNode(std::move(prefix), std::move(left), std::move(right));
  } else if (type == TrieNodeType::Empty) {
    return TrieNode();
  }
  return td::Status::Error("Failed to parse trie node");
}

td::Result<TrieRef> TrieNode::fetch_from_snapshot(td::Slice snapshot) {
  td::TlParser parser(snapshot);
  auto root_offset = static_cast<size_t>(parser.fetch_long());
  TRY_STATUS(parser.get_status());
  if (root_offset >= snapshot.size()) {
    return td::Status::Error("Failed to parse");
  }
  auto bs = BitString(256);
  TRY_RESULT(node, fetch_node_from_snapshot(snapshot.substr(root_offset), bs));
  return std::make_shared<TrieNode>(std::move(node));
}

}  // namespace tde2e_core
