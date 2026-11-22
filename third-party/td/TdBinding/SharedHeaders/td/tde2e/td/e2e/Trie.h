//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/BitString.h"
#include "td/e2e/utils.h"

#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <memory>
#include <tuple>
#include <utility>
#include <variant>

namespace tde2e_core {

enum class TrieNodeType : td::int32 { Empty, Leaf, Inner, Pruned };

struct TrieNode;
using TrieRef = std::shared_ptr<const TrieNode>;

struct TrieNode {
  td::UInt256 hash{};

  struct Empty {};
  struct Leaf {
    BitString key_suffix;
    std::string value;
  };
  struct Inner {
    BitString prefix;
    TrieRef left;
    TrieRef right;
  };
  struct Pruned {
    td::int64 offset;
    BitString base_bit_string;
  };
  std::variant<Empty, Leaf, Inner, Pruned> data;

  TrieNodeType get_type() const {
    return static_cast<TrieNodeType>(data.index());
  }

  const Leaf &get_leaf() const {
    return std::get<Leaf>(data);
  }
  const Inner &get_inner() const {
    return std::get<Inner>(data);
  }
  const Pruned &get_pruned() const {
    return std::get<Pruned>(data);
  }

  td::Status try_load(td::Slice snapshot) const;

  TrieNode();
  TrieNode(BitString key_suffix, std::string value);
  TrieNode(BitString prefix, TrieRef left, TrieRef right);
  explicit TrieNode(const td::UInt256 &hash_value);
  TrieNode(const td::UInt256 &hash_value, td::int64 offset, BitString base_bit_string);
  TrieNode(TrieNode &&) = default;
  TrieNode &operator=(TrieNode &&) = default;
  static TrieRef empty_node();

  static td::Result<std::string> serialize_for_network(const TrieRef &node);
  static td::Result<TrieRef> fetch_from_network(td::Slice data);
  static td::Result<std::string> serialize_for_snapshot(const TrieRef &node, td::Slice snapshot);
  static td::Result<TrieRef> fetch_from_snapshot(td::Slice snapshot);

 private:
  td::UInt256 compute_hash() const;
};

td::Result<TrieRef> set(const TrieRef &n, BitString key, td::Slice value, td::Slice snapshot = {});

td::Result<std::string> get(const TrieRef &n, const BitString &key, td::Slice snapshot = {});

td::Result<TrieRef> generate_pruned_tree(const TrieRef &n, td::Span<td::Slice> keys, td::Slice snapshot = {});

std::ostream &operator<<(std::ostream &os, const td::UInt256 &hash);

void print_tree(const TrieRef &node, const std::string &prefix = "", bool is_root = true);

BitString to_key(td::Slice key);

inline td::Result<TrieRef> set(const TrieRef &n, td::Slice key, td::Slice value) {
  return set(n, to_key(key), value);
}

inline td::Result<std::string> get(const TrieRef &n, td::Slice key, td::Slice snapshot = {}) {
  return get(n, to_key(key), snapshot);
}

}  // namespace tde2e_core
