//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/bits.h"
#include "td/utils/common.h"
#include "td/utils/fixed_vector.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/MapNode.h"
#include "td/utils/SetNode.h"

#include <cstddef>
#include <functional>
#include <initializer_list>
#include <iterator>
#include <limits>
#include <utility>

#if defined(__SSE2__) || (TD_MSVC && (defined(_M_X64) || (defined(_M_IX86) && _M_IX86_FP >= 2)))
#define TD_SSE2 1
#endif

#ifdef __aarch64__
#include <arm_neon.h>
#endif

#if TD_SSE2
#include <emmintrin.h>
#endif

namespace td {
template <int shift>
struct MaskIterator {
  uint64 mask;
  explicit operator bool() const noexcept {
    return mask != 0;
  }
  int pos() const {
    return count_trailing_zeroes64(mask) / shift;
  }
  void next() {
    mask &= mask - 1;
  }

  // For foreach
  bool operator!=(MaskIterator &other) const {
    return mask != other.mask;
  }
  auto operator*() const {
    return pos();
  }
  void operator++() {
    next();
  }
  auto begin() {
    return *this;
  }
  auto end() {
    return MaskIterator{0u};
  }
};

struct MaskPortable {
  static MaskIterator<1> equal_mask(uint8 *bytes, uint8 needle) {
    uint64 res = 0;
    for (int i = 0; i < 16; i++) {
      res |= (bytes[i] == needle) << i;
    }
    return {res & ((1u << 14) - 1)};
  }
};

#ifdef __aarch64__
struct MaskNeonFolly {
  static MaskIterator<4> equal_mask(uint8 *bytes, uint8 needle) {
    uint8x16_t input_mask = vld1q_u8(bytes);
    auto needle_mask = vdupq_n_u8(needle);
    auto eq_mask = vceqq_u8(input_mask, needle_mask);
    // get info from every byte into the bottom half of every uint16
    // by shifting right 4, then round to get it into a 64-bit vector
    uint8x8_t shifted_eq_mask = vshrn_n_u16(vreinterpretq_u16_u8(eq_mask), 4);
    uint64 mask = vget_lane_u64(vreinterpret_u64_u8(shifted_eq_mask), 0);
    return {mask & 0x11111111111111};
  }
};

struct MaskNeon {
  static MaskIterator<1> equal_mask(uint8 *bytes, uint8 needle) {
    uint8x16_t input_mask = vld1q_u8(bytes);
    auto needle_mask = vdupq_n_u8(needle);
    auto eq_mask = vceqq_u8(input_mask, needle_mask);
    uint16x8_t MASK = vdupq_n_u16(0x180);
    uint16x8_t a_masked = vandq_u16(vreinterpretq_u16_u8(eq_mask), MASK);
    const int16 __attribute__((aligned(16))) SHIFT_ARR[8] = {-7, -5, -3, -1, 1, 3, 5, 7};
    int16x8_t SHIFT = vld1q_s16(SHIFT_ARR);
    uint16x8_t a_shifted = vshlq_u16(a_masked, SHIFT);
    return {vaddvq_u16(a_shifted) & ((1u << 14) - 1)};
  }
};
#elif TD_SSE2
struct MaskSse2 {
  static MaskIterator<1> equal_mask(uint8 *bytes, uint8 needle) {
    auto input_mask = _mm_loadu_si128(reinterpret_cast<const __m128i *>(bytes));
    auto needle_mask = _mm_set1_epi8(needle);
    auto match_mask = _mm_cmpeq_epi8(needle_mask, input_mask);
    return {static_cast<uint32>(_mm_movemask_epi8(match_mask)) & ((1u << 14) - 1)};
  }
};
#endif

#ifdef __aarch64__
using MaskHelper = MaskNeonFolly;
#elif TD_SSE2
using MaskHelper = MaskSse2;
#else
using MaskHelper = MaskPortable;
#endif

template <class NodeT, class HashT, class EqT>
class FlatHashTableChunks {
 public:
  using Self = FlatHashTableChunks<NodeT, HashT, EqT>;
  using Node = NodeT;
  using NodeIterator = typename fixed_vector<Node>::iterator;
  using ConstNodeIterator = typename fixed_vector<Node>::const_iterator;

  using KeyT = typename Node::public_key_type;
  using key_type = typename Node::public_key_type;
  using value_type = typename Node::public_type;

  struct Iterator {
    using iterator_category = std::bidirectional_iterator_tag;
    using difference_type = std::ptrdiff_t;
    using value_type = FlatHashTableChunks::value_type;
    using pointer = value_type *;
    using reference = value_type &;

    friend class FlatHashTableChunks;
    Iterator &operator++() {
      do {
        ++it_;
      } while (it_ != map_->nodes_.end() && it_->empty());
      return *this;
    }
    Iterator &operator--() {
      do {
        --it_;
      } while (it_->empty());
      return *this;
    }
    reference operator*() {
      return it_->get_public();
    }
    pointer operator->() {
      return &it_->get_public();
    }
    bool operator==(const Iterator &other) const {
      DCHECK(map_ == other.map_);
      return it_ == other.it_;
    }
    bool operator!=(const Iterator &other) const {
      DCHECK(map_ == other.map_);
      return it_ != other.it_;
    }

    Iterator() = default;
    Iterator(NodeIterator it, Self *map) : it_(std::move(it)), map_(map) {
    }

   private:
    NodeIterator it_;
    Self *map_;
  };

  struct ConstIterator {
    using iterator_category = std::bidirectional_iterator_tag;
    using difference_type = std::ptrdiff_t;
    using value_type = FlatHashTableChunks::value_type;
    using pointer = const value_type *;
    using reference = const value_type &;

    friend class FlatHashTableChunks;
    ConstIterator &operator++() {
      ++it_;
      return *this;
    }
    ConstIterator &operator--() {
      --it_;
      return *this;
    }
    reference operator*() {
      return *it_;
    }
    pointer operator->() {
      return &*it_;
    }
    bool operator==(const ConstIterator &other) const {
      return it_ == other.it_;
    }
    bool operator!=(const ConstIterator &other) const {
      return it_ != other.it_;
    }

    ConstIterator() = default;
    ConstIterator(Iterator it) : it_(std::move(it)) {
    }

   private:
    Iterator it_;
  };
  using iterator = Iterator;
  using const_iterator = ConstIterator;

  FlatHashTableChunks() = default;
  FlatHashTableChunks(const FlatHashTableChunks &other) {
    assign(other);
  }
  FlatHashTableChunks &operator=(const FlatHashTableChunks &other) {
    clear();
    assign(other);
    return *this;
  }

  FlatHashTableChunks(std::initializer_list<Node> nodes) {
    reserve(nodes.size());
    for (auto &new_node : nodes) {
      CHECK(!new_node.empty());
      if (count(new_node.key()) > 0) {
        continue;
      }
      Node node;
      node.copy_from(new_node);
      emplace_node(std::move(node));
    }
  }

  FlatHashTableChunks(FlatHashTableChunks &&other) noexcept {
    swap(other);
  }
  FlatHashTableChunks &operator=(FlatHashTableChunks &&other) noexcept {
    swap(other);
    return *this;
  }
  void swap(FlatHashTableChunks &other) noexcept {
    nodes_.swap(other.nodes_);
    chunks_.swap(other.chunks_);
    std::swap(used_nodes_, other.used_nodes_);
  }
  ~FlatHashTableChunks() = default;

  size_t bucket_count() const {
    return nodes_.size();
  }

  Iterator find(const KeyT &key) {
    if (empty() || is_hash_table_key_empty<EqT>(key)) {
      return end();
    }
    const auto hash = calc_hash(key);
    auto chunk_it = get_chunk_it(hash.chunk_i);
    while (true) {
      auto chunk_i = chunk_it.pos();
      auto chunk_begin = nodes_.begin() + chunk_i * Chunk::CHUNK_SIZE;
      //__builtin_prefetch(chunk_begin);
      auto &chunk = chunks_[chunk_i];
      auto mask_it = MaskHelper::equal_mask(chunk.ctrl, hash.small_hash);
      for (auto pos : mask_it) {
        auto it = chunk_begin + pos;
        if (likely(EqT()(it->key(), key))) {
          return Iterator{it, this};
        }
      }
      if (chunk.skipped_cnt == 0) {
        break;
      }
      chunk_it.next();
    }
    return end();
  }

  ConstIterator find(const KeyT &key) const {
    return ConstIterator(const_cast<Self *>(this)->find(key));
  }

  size_t size() const {
    return used_nodes_;
  }

  bool empty() const {
    return size() == 0;
  }

  Iterator begin() {
    if (empty()) {
      return end();
    }
    auto it = nodes_.begin();
    while (it->empty()) {
      ++it;
    }
    return Iterator(it, this);
  }
  Iterator end() {
    return Iterator(nodes_.end(), this);
  }

  ConstIterator begin() const {
    return ConstIterator(const_cast<Self *>(this)->begin());
  }
  ConstIterator end() const {
    return ConstIterator(const_cast<Self *>(this)->end());
  }

  void reserve(size_t size) {
    //size_t want_size = normalize(size * 5 / 3 + 1);
    size_t want_size = normalize(size * 14 / 12 + 1);
    // size_t want_size = size * 2;
    if (want_size > nodes_.size()) {
      resize(want_size);
    }
  }

  template <class... ArgsT>
  std::pair<Iterator, bool> emplace(KeyT key, ArgsT &&...args) {
    CHECK(!is_hash_table_key_empty<EqT>(key));
    auto it = find(key);
    if (it != end()) {
      return {it, false};
    }
    try_grow();

    auto hash = calc_hash(key);
    auto chunk_it = get_chunk_it(hash.chunk_i);
    while (true) {
      auto chunk_i = chunk_it.pos();
      auto &chunk = chunks_[chunk_i];
      auto mask_it = MaskHelper::equal_mask(chunk.ctrl, 0);
      if (mask_it) {
        auto shift = mask_it.pos();
        DCHECK(chunk.ctrl[shift] == 0);
        auto node_it = nodes_.begin() + shift + chunk_i * Chunk::CHUNK_SIZE;
        DCHECK(node_it->empty());
        node_it->emplace(std::move(key), std::forward<ArgsT>(args)...);
        DCHECK(!node_it->empty());
        chunk.ctrl[shift] = hash.small_hash;
        used_nodes_++;
        return {{node_it, this}, true};
      }
      CHECK(chunk.skipped_cnt != std::numeric_limits<uint16>::max());
      chunk.skipped_cnt++;
      chunk_it.next();
    }
  }

  std::pair<Iterator, bool> insert(KeyT key) {
    return emplace(std::move(key));
  }

  template <class ItT>
  void insert(ItT begin, ItT end) {
    for (; begin != end; ++begin) {
      emplace(*begin);
    }
  }

  template <class T = typename Node::second_type>
  T &operator[](const KeyT &key) {
    return emplace(key).first->second;
  }

  size_t erase(const KeyT &key) {
    auto it = find(key);
    if (it == end()) {
      return 0;
    }
    erase(it);
    try_shrink();
    return 1;
  }

  size_t count(const KeyT &key) const {
    return find(key) != end();
  }

  void clear() {
    used_nodes_ = 0;
    nodes_ = {};
    chunks_ = {};
  }

  void erase(Iterator it) {
    DCHECK(it != end());
    DCHECK(!it.it_->empty());
    erase_node(it.it_);
  }

  template <class F>
  bool remove_if(F &&f) {
    bool is_removed = false;
    for (auto it = nodes_.begin(), end = nodes_.end(); it != end; ++it) {
      if (!it->empty() && f(it->get_public())) {
        erase_node(it);
        is_removed = true;
      }
    }
    try_shrink();
    return is_removed;
  }

 private:
  struct Chunk {
    static constexpr int CHUNK_SIZE = 14;
    static constexpr int MASK = (1 << CHUNK_SIZE) - 1;
    // 0x0 - empty
    uint8 ctrl[CHUNK_SIZE] = {};
    uint16 skipped_cnt{0};
  };
  fixed_vector<Node> nodes_;
  fixed_vector<Chunk> chunks_;
  size_t used_nodes_{};

  void assign(const FlatHashTableChunks &other) {
    reserve(other.size());
    for (const auto &new_node : other) {
      Node node;
      node.copy_from(new_node);
      emplace_node(std::move(node));
    }
  }

  void try_grow() {
    if (should_grow(used_nodes_ + 1, nodes_.size())) {
      grow();
    }
  }
  static bool should_grow(size_t used_count, size_t bucket_count) {
    return used_count * 14 > bucket_count * 12;
  }
  void try_shrink() {
    if (should_shrink(used_nodes_, nodes_.size())) {
      shrink();
    }
  }
  static bool should_shrink(size_t used_count, size_t bucket_count) {
    return used_count * 10 < bucket_count;
  }

  static size_t normalize(size_t size) {
    auto x = (size / Chunk::CHUNK_SIZE) | 1;
    auto y = static_cast<size_t>(1) << (64 - count_leading_zeroes64(x));
    return y * Chunk::CHUNK_SIZE;
  }

  void shrink() {
    size_t want_size = normalize((used_nodes_ + 1) * 5 / 3 + 1);
    resize(want_size);
  }

  void grow() {
    size_t want_size = normalize(2 * nodes_.size() - !nodes_.empty());
    resize(want_size);
  }

  struct HashInfo {
    size_t chunk_i;
    uint8 small_hash;
  };
  struct ChunkIt {
    size_t chunk_i;
    size_t chunk_mask;
    size_t shift;

    size_t pos() const {
      return chunk_i;
    }
    void next() {
      DCHECK((chunk_mask & (chunk_mask + 1)) == 0);
      shift++;
      chunk_i += shift;
      chunk_i &= chunk_mask;
    }
  };

  ChunkIt get_chunk_it(size_t chunk_i) {
    return ChunkIt{chunk_i, chunks_.size() - 1, 0};
  }

  HashInfo calc_hash(const KeyT &key) {
    auto h = HashT()(key);
    return {(h >> 8) % chunks_.size(), static_cast<uint8>(0x80 | h)};
  }

  void resize(size_t new_size) {
    CHECK(new_size >= Chunk::CHUNK_SIZE);
    fixed_vector<Node> old_nodes(new_size);
    fixed_vector<Chunk> chunks(new_size / Chunk::CHUNK_SIZE);
    old_nodes.swap(nodes_);
    chunks_ = std::move(chunks);
    used_nodes_ = 0;

    for (auto &node : old_nodes) {
      if (node.empty()) {
        continue;
      }
      emplace_node(std::move(node));
    }
  }

  void emplace_node(Node &&node) {
    DCHECK(!node.empty());
    auto hash = calc_hash(node.key());
    auto chunk_it = get_chunk_it(hash.chunk_i);
    while (true) {
      auto chunk_i = chunk_it.pos();
      auto &chunk = chunks_[chunk_i];
      auto mask_it = MaskHelper::equal_mask(chunk.ctrl, 0);
      if (mask_it) {
        auto shift = mask_it.pos();
        auto node_it = nodes_.begin() + shift + chunk_i * Chunk::CHUNK_SIZE;
        DCHECK(node_it->empty());
        *node_it = std::move(node);
        DCHECK(chunk.ctrl[shift] == 0);
        chunk.ctrl[shift] = hash.small_hash;
        DCHECK(chunk.ctrl[shift] != 0);
        used_nodes_++;
        break;
      }
      CHECK(chunk.skipped_cnt != std::numeric_limits<uint16>::max());
      chunk.skipped_cnt++;
      chunk_it.next();
    }
  }

  void next_bucket(size_t &bucket) const {
    bucket++;
    if (unlikely(bucket == nodes_.size())) {
      bucket = 0;
    }
  }

  void erase_node(NodeIterator it) {
    DCHECK(!it->empty());
    size_t empty_i = it - nodes_.begin();
    DCHECK(0 <= empty_i && empty_i < nodes_.size());
    auto empty_chunk_i = empty_i / Chunk::CHUNK_SIZE;
    auto hash = calc_hash(it->key());
    auto chunk_it = get_chunk_it(hash.chunk_i);
    while (true) {
      auto chunk_i = chunk_it.pos();
      auto &chunk = chunks_[chunk_i];
      if (chunk_i == empty_chunk_i) {
        chunk.ctrl[empty_i - empty_chunk_i * Chunk::CHUNK_SIZE] = 0;
        break;
      }
      chunk.skipped_cnt--;
      chunk_it.next();
    }
    it->clear();
    used_nodes_--;
  }
};

template <class KeyT, class ValueT, class HashT = Hash<KeyT>, class EqT = std::equal_to<KeyT>>
using FlatHashMapChunks = FlatHashTableChunks<MapNode<KeyT, ValueT, EqT>, HashT, EqT>;

template <class KeyT, class HashT = Hash<KeyT>, class EqT = std::equal_to<KeyT>>
using FlatHashSetChunks = FlatHashTableChunks<SetNode<KeyT, EqT>, HashT, EqT>;

template <class NodeT, class HashT, class EqT, class FuncT>
bool table_remove_if(FlatHashTableChunks<NodeT, HashT, EqT> &table, FuncT &&func) {
  return table.remove_if(func);
}

}  // namespace td
