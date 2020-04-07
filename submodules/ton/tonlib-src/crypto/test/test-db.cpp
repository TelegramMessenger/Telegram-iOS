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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "vm/boc.h"
#include "vm/cellslice.h"
#include "vm/cells.h"
#include "common/AtomicRef.h"
#include "vm/cells/MerkleProof.h"
#include "vm/cells/MerkleUpdate.h"
#include "vm/db/BlobView.h"
#include "vm/db/CellStorage.h"
#include "vm/db/CellHashTable.h"
#include "vm/db/TonDb.h"
#include "vm/db/StaticBagOfCellsDb.h"

#include "td/utils/base64.h"
#include "td/utils/benchmark.h"
#include "td/utils/crypto.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/Timer.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/optional.h"
#include "td/utils/tests.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_helpers.h"

#include "td/db/RocksDb.h"
#include "td/db/MemoryKeyValue.h"

#include <set>
#include <map>

#include <openssl/sha.h>

#include "openssl/digest.hpp"

namespace vm {

std::vector<int> do_get_serialization_modes() {
  std::vector<int> res;
  for (int i = 0; i < 32; i++) {
    if ((i & BagOfCells::Mode::WithCacheBits) && !(i & BagOfCells::Mode::WithIndex)) {
      continue;
    }
    res.push_back(i);
  }
  return res;
}
const std::vector<int> &get_serialization_modes() {
  static auto modes = do_get_serialization_modes();
  return modes;
}

template <class T>
int get_random_serialization_mode(T &rnd) {
  auto &modes = get_serialization_modes();
  return modes[rnd.fast(0, (int)modes.size() - 1)];
}

class BenchSha256 : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "SHA256";
  }

  void run(int n) override {
    int res = 0;
    for (int i = 0; i < n; i++) {
      digest::SHA256 hasher;
      hasher.feed("abcd", 4);
      unsigned char buf[32];
      hasher.extract(buf);
      res += buf[0];
    }
    td::do_not_optimize_away(res);
  }
};
class BenchSha256Reuse : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "SHA256 reuse";
  }

  void run(int n) override {
    int res = 0;
    digest::SHA256 hasher;
    for (int i = 0; i < n; i++) {
      hasher.reset();
      hasher.feed("abcd", 4);
      unsigned char buf[32];
      hasher.extract(buf);
      res += buf[0];
    }
    td::do_not_optimize_away(res);
  }
};
class BenchSha256Low : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "SHA256 low level";
  }

  void run(int n) override {
    int res = 0;
    SHA256_CTX ctx;
    for (int i = 0; i < n; i++) {
      SHA256_Init(&ctx);
      SHA256_Update(&ctx, "abcd", 4);
      unsigned char buf[32];
      SHA256_Final(buf, &ctx);
      res += buf[0];
    }
    td::do_not_optimize_away(res);
  }
};
class BenchSha256Tdlib : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "SHA256 TDLib";
  }

  void run(int n) override {
    int res = 0;
    static TD_THREAD_LOCAL td::Sha256State *ctx;
    for (int i = 0; i < n; i++) {
      td::init_thread_local<td::Sha256State>(ctx);
      ctx->init();
      ctx->feed("abcd");
      unsigned char buf[32];
      ctx->extract(td::MutableSlice(buf, 32), false);
      res += buf[0];
    }
    td::do_not_optimize_away(res);
  }
};
TEST(Cell, sha_benchmark) {
  bench(BenchSha256Tdlib());
  bench(BenchSha256Low());
  bench(BenchSha256Reuse());
  bench(BenchSha256());
}

std::string serialize_boc(Ref<Cell> cell, int mode = 31) {
  CHECK(cell.not_null());
  vm::BagOfCells boc;
  boc.add_root(std::move(cell));
  boc.import_cells().ensure();
  auto res = boc.serialize_to_string(mode);
  CHECK(res.size() != 0);
  return res;
}
std::string serialize_boc(td::Span<Ref<Cell>> cells, int mode = 31) {
  CHECK(!cells.empty());
  vm::BagOfCells boc;
  for (auto cell : cells) {
    boc.add_root(std::move(cell));
  }
  boc.import_cells().ensure();
  auto res = boc.serialize_to_string(mode);
  CHECK(res.size() != 0);
  return res;
}

Ref<Cell> deserialize_boc(td::Slice serialized) {
  vm::BagOfCells boc;
  boc.deserialize(serialized).ensure();
  return boc.get_root_cell();
}
std::vector<Ref<Cell>> deserialize_boc_multiple(td::Slice serialized) {
  vm::BagOfCells boc;
  boc.deserialize(serialized).ensure();
  std::vector<Ref<Cell>> res;
  for (int i = 0; i < boc.get_root_count(); i++) {
    res.push_back(boc.get_root_cell(i));
  }
  return res;
}

class CellExplorer {
 public:
  struct Op {
    enum { Pop, ReadCellSlice } type;
    bool should_load;
    int children_mask;
  };
  struct Exploration {
    std::vector<Op> ops;
    std::string log;
    std::set<Cell::Hash> visited;
    std::vector<Ref<Cell>> visited_cells;
  };

  static Exploration explore(Ref<Cell> root, std::vector<Op> ops) {
    CellExplorer e(root);
    for (auto op : ops) {
      e.do_op(op);
    }
    return e.get_exploration();
  }

  template <class T>
  static Exploration random_explore(Ref<Cell> root, T &rnd) {
    CellExplorer e(root);
    int it = 0;
    int cnt = rnd.fast(1, 100);
    while (it++ < cnt && e.do_random_op(rnd)) {
    }
    return e.get_exploration();
  }

 private:
  CellExplorer(Ref<Cell> root) {
    if (root.not_null()) {
      cells_.push_back(std::move(root));
    }
  }

  std::vector<Ref<Cell>> cells_;
  Ref<CellSlice> cs_;
  std::vector<Op> ops_;
  std::set<Cell::Hash> visited_;
  std::map<Cell::Hash, Ref<Cell>> visited_cells_;
  td::StringBuilder log_{{}, true};

  void do_op(Op op) {
    ops_.push_back(op);
    log_op(op);
    switch (op.type) {
      case op.Pop: {
        CHECK(!cells_.empty());
        CHECK(cs_.is_null());
        auto cell = std::move(cells_.back());
        cells_.pop_back();
        visited_cells_.emplace(cell->get_hash(), cell);
        log_cell(cell);
        if (op.should_load) {
          log_loaded_cell(cell);
          visited_.insert(cell->get_hash());
          // It is ok to visit the same vertex multiple times
          cs_ = Ref<CellSlice>{true, NoVm(), std::move(cell)};
        }
        break;
      }
      case op.ReadCellSlice: {
        CHECK(cs_.not_null());
        log_cell_slice(cs_);
        for (unsigned i = 0; i < cs_->size_refs(); i++) {
          if ((op.children_mask >> i) % 2 != 0) {
            cells_.push_back(cs_->prefetch_ref(i));
          }
        }
        cs_ = {};
        break;
      }
    }
  }

  template <class T>
  bool do_random_op(T &rnd) {
    if (cs_.not_null()) {
      int children_mask = 0;
      if (cs_->size_refs() != 0 && rnd.fast(0, 3) != 0) {
        //children_mask = rnd.fast(1, (1 << cs_->size_refs()) - 1);
        children_mask = (1 << cs_->size_refs()) - 1;
      }
      do_op({Op::ReadCellSlice, false, children_mask});
      return true;
    }
    if (!cells_.empty()) {
      do_op({Op::Pop, rnd.fast(0, 30) != 0, 0});
      return true;
    }
    return false;
  }

  Exploration get_exploration() {
    std::vector<Ref<Cell>> visited_cells;
    for (auto &it : visited_cells_) {
      visited_cells.push_back(it.second);
    }
    return {std::move(ops_), log_.as_cslice().str(), std::move(visited_), std::move(visited_cells)};
  }

  void log_op(Op op) {
    switch (op.type) {
      case op.Pop:
        log_ << "pop" << (op.should_load ? " and load" : "") << "\n";
        break;
      case op.ReadCellSlice:
        log_ << "read slice " << op.children_mask << "\n";
        break;
    }
  }
  void log_cell(const Ref<Cell> &cell) {
    log_ << cell->get_level_mask().get_mask() << " " << cell->get_hash() << "\n";
  }
  void log_loaded_cell(const Ref<Cell> &cell) {
    log_ << "depth: ";
    for (unsigned i = 0; i <= cell->get_level(); i++) {
      log_ << cell->get_depth(i) << " ";
    }
    log_ << "\n";
  }
  void log_cell_slice(const Ref<CellSlice> &cs) {
    log_ << cs->special_type() << " " << cs->size() << " " << cs->size_refs() << " "
         << td::bitstring::bits_to_hex(cs->data_bits(), cs->size()) << "\n";
  }
};

class RandomBagOfCells {
 public:
  template <class T>
  RandomBagOfCells(size_t size, T &rnd, bool with_prunned_branches, std::vector<Ref<Cell>> cells) {
    std::map<CellHash, int> depth;

    for (auto &cell : cells) {
      nodes_.emplace_back(cell, calc_depth(cell, depth));
    }

    for (size_t i = 0; i < size; i++) {
      add_random_cell(rnd, with_prunned_branches);
    }
  }

  Ref<Cell> get_root() {
    CHECK(!nodes_.empty());
    // Fix root to be zero level
    while (nodes_.back().cell->get_level() != 0) {
      nodes_.emplace_back(CellBuilder::create_merkle_proof(nodes_.back().cell), nodes_.back().merkle_depth + 1);
    }
    return nodes_.back().cell;
  }
  template <class T>
  std::vector<Ref<Cell>> get_random_roots(size_t size, T &rnd) {
    CHECK(!nodes_.empty());
    std::vector<Ref<Cell>> res(size);
    for (auto &c : res) {
      c = nodes_[rnd.fast(0, static_cast<int>(nodes_.size()) - 1)].cell;
    }
    return res;
  }

  size_t get_size() const {
    return nodes_.size();
  }

  template <class T>
  void add_random_cell(T &rnd, bool with_prunned_branches = true) {
    int cnt = 0;
    while (true) {
      CellBuilder cb;
      int next_cnt = rnd.fast(0, Cell::max_refs);
      int merkle_depth = 0;
      for (int j = 0; j < next_cnt && !nodes_.empty(); j++) {
        int to = rnd.fast(j == 0 && nodes_.size() > 3 ? (int)nodes_.size() - 3 : 0, (int)nodes_.size() - 1);
        merkle_depth = td::max(merkle_depth, nodes_.at(to).merkle_depth);
        cb.store_ref(nodes_[to].cell);
      }
      int size = rnd.fast(0, 4);
      for (int j = 0; j < size; j++) {
        cb.store_bytes(&"ab"[rnd.fast(0, 1)], 1);
      }
      if (rnd.fast(0, 4) == 4) {
        cb.store_bits(rnd.fast(0, 1) ? "\xff" : "\x55", rnd.fast(1, 7));
      }
      Ref<Cell> cell = cb.finalize();
      auto cell_level = cell->get_level();
      if (with_prunned_branches) {
        if (rnd.fast(0, 5) == 0 && cell_level + 1 < Cell::max_level) {
          cell = CellBuilder::create_pruned_branch(std::move(cell), cell_level + 1);
        }
        if (merkle_depth + 1 + cell->get_level() < Cell::max_level && rnd.fast(0, 10) == 0) {
          cell = CellBuilder::create_merkle_proof(std::move(cell));
          merkle_depth++;
        }
      }
      if (merkle_depth + cell->get_level() >= Cell::max_level) {
        cnt++;
        CHECK(cnt < 1000);
        continue;
      }
      CHECK(cell.not_null());
      nodes_.emplace_back(std::move(cell), merkle_depth);
      break;
    }
  }

 private:
  struct Node {
    Node() = default;
    Node(Ref<Cell> cell, int merkle_depth) : cell(std::move(cell)), merkle_depth(merkle_depth) {
    }
    Ref<Cell> cell;
    int merkle_depth;
  };
  std::vector<Node> nodes_;

  auto calc_depth(const Ref<Cell> &root, std::map<CellHash, int> &depth) -> int {
    auto it_flag = depth.emplace(root->get_hash(), 0);
    if (!it_flag.second) {
      return it_flag.first->second;
    }
    auto res = 0;
    CellSlice cs(NoVm(), root);
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      res = std::max(res, calc_depth(cs.prefetch_ref(i), depth));
    }
    if (cs.special_type() == Cell::SpecialType::MerkleProof) {
      res++;
    }
    depth[root->get_hash()] = res;
    return res;
  };
};

template <class T>
void random_shuffle(td::MutableSpan<T> v, td::Random::Xorshift128plus &rnd) {
  for (std::size_t i = 1; i < v.size(); i++) {
    auto pos = static_cast<std::size_t>(rnd() % (i + 1));
    std::swap(v[i], v[pos]);
  }
}
Ref<Cell> gen_random_cell(int size, td::Random::Xorshift128plus &rnd, bool with_prunned_branches = true,
                          std::vector<Ref<Cell>> cells = {}) {
  if (!cells.empty()) {
    random_shuffle(td::MutableSpan<Ref<Cell>>(cells), rnd);
    cells.resize(cells.size() % rnd());
  }
  return RandomBagOfCells(size, rnd, with_prunned_branches, std::move(cells)).get_root();
}
std::vector<Ref<Cell>> gen_random_cells(int roots, int size, td::Random::Xorshift128plus &rnd,
                                        bool with_prunned_branches = true, std::vector<Ref<Cell>> cells = {}) {
  if (!cells.empty()) {
    random_shuffle(td::MutableSpan<Ref<Cell>>(cells), rnd);
    cells.resize(cells.size() % rnd());
  }
  return RandomBagOfCells(size, rnd, with_prunned_branches, std::move(cells)).get_random_roots(roots, rnd);
}

TEST(Cell, MerkleProof) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    bool with_prunned_branches = true;
    auto cell = gen_random_cell(rnd.fast(1, 1000), rnd, with_prunned_branches);
    auto exploration = CellExplorer::random_explore(cell, rnd);

    auto usage_tree = std::make_shared<CellUsageTree>();
    auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
    auto exploration2 = CellExplorer::explore(usage_cell, exploration.ops);
    ASSERT_EQ(exploration.log, exploration2.log);

    auto is_prunned = [&](const Ref<Cell> &cell) { return exploration.visited.count(cell->get_hash()) == 0; };
    auto proof = MerkleProof::generate(cell, is_prunned);
    // CellBuilder::virtualize(proof, 1);
    //ASSERT_EQ(1u, proof->get_level());
    auto virtualized_proof = MerkleProof::virtualize(proof, 1);
    auto exploration3 = CellExplorer::explore(virtualized_proof, exploration.ops);
    ASSERT_EQ(exploration.log, exploration3.log);

    auto proof2 = MerkleProof::generate(cell, usage_tree.get());
    CHECK(proof2->get_depth() == proof->get_depth());
    auto virtualized_proof2 = MerkleProof::virtualize(proof2, 1);
    auto exploration4 = CellExplorer::explore(virtualized_proof2, exploration.ops);
    ASSERT_EQ(exploration.log, exploration4.log);
  }
};

TEST(Cell, MerkleProofCombine) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    bool with_prunned_branches = true;
    auto cell = gen_random_cell(rnd.fast(1, 1000), rnd, with_prunned_branches);
    auto exploration1 = CellExplorer::random_explore(cell, rnd);
    auto exploration2 = CellExplorer::random_explore(cell, rnd);

    Ref<Cell> proof1;
    {
      auto usage_tree = std::make_shared<CellUsageTree>();
      auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
      CellExplorer::explore(usage_cell, exploration1.ops);
      proof1 = MerkleProof::generate(cell, usage_tree.get());

      auto virtualized_proof = MerkleProof::virtualize(proof1, 1);
      auto exploration = CellExplorer::explore(virtualized_proof, exploration1.ops);
      ASSERT_EQ(exploration.log, exploration1.log);
    }

    Ref<Cell> proof2;
    {
      auto usage_tree = std::make_shared<CellUsageTree>();
      auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
      CellExplorer::explore(usage_cell, exploration2.ops);
      proof2 = MerkleProof::generate(cell, usage_tree.get());

      auto virtualized_proof = MerkleProof::virtualize(proof2, 1);
      auto exploration = CellExplorer::explore(virtualized_proof, exploration2.ops);
      ASSERT_EQ(exploration.log, exploration2.log);
    }

    Ref<Cell> proof12;
    {
      auto usage_tree = std::make_shared<CellUsageTree>();
      auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
      CellExplorer::explore(usage_cell, exploration1.ops);
      CellExplorer::explore(usage_cell, exploration2.ops);
      proof12 = MerkleProof::generate(cell, usage_tree.get());

      auto virtualized_proof = MerkleProof::virtualize(proof12, 1);
      auto exploration_a = CellExplorer::explore(virtualized_proof, exploration1.ops);
      auto exploration_b = CellExplorer::explore(virtualized_proof, exploration2.ops);
      ASSERT_EQ(exploration_a.log, exploration1.log);
      ASSERT_EQ(exploration_b.log, exploration2.log);
    }

    {
      auto check = [&](auto proof_union) {
        auto virtualized_proof = MerkleProof::virtualize(proof_union, 1);
        auto exploration_a = CellExplorer::explore(virtualized_proof, exploration1.ops);
        auto exploration_b = CellExplorer::explore(virtualized_proof, exploration2.ops);
        ASSERT_EQ(exploration_a.log, exploration1.log);
        ASSERT_EQ(exploration_b.log, exploration2.log);
      };
      auto proof_union = MerkleProof::combine(proof1, proof2);
      ASSERT_EQ(proof_union->get_hash(), proof12->get_hash());
      check(proof_union);

      auto proof_union_fast = MerkleProof::combine_fast(proof1, proof2);
      check(proof_union_fast);
    }
    {
      auto cell = MerkleProof::virtualize(proof12, 1);

      auto usage_tree = std::make_shared<CellUsageTree>();
      auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
      CellExplorer::explore(usage_cell, exploration1.ops);
      auto proof = MerkleProof::generate(cell, usage_tree.get());

      auto virtualized_proof = MerkleProof::virtualize(proof, 2);
      auto exploration = CellExplorer::explore(virtualized_proof, exploration1.ops);
      ASSERT_EQ(exploration.log, exploration1.log);
      if (proof->get_hash() != proof1->get_hash()) {
        CellSlice(NoVm(), proof12).print_rec(std::cerr);
        CellSlice(NoVm(), proof).print_rec(std::cerr);
        CellSlice(NoVm(), proof1).print_rec(std::cerr);
        LOG(ERROR) << proof->get_level() << " " << proof->get_hash().to_hex();
        LOG(ERROR) << proof->get_level() << " " << proof1->get_hash().to_hex();
        LOG(FATAL) << "?";
      }
    }
  }
};

int X = 20;
Ref<Cell> gen_random_cell(int size, Ref<Cell> from, td::Random::Xorshift128plus &rnd,
                          bool with_prunned_branches = true) {
  auto exploration = CellExplorer::random_explore(from, rnd);
  return gen_random_cell(size, rnd, with_prunned_branches, std::move(exploration.visited_cells));
}
auto gen_merkle_update(Ref<Cell> cell, td::Random::Xorshift128plus &rnd, bool with_prunned_branches) {
  auto usage_tree = std::make_shared<CellUsageTree>();
  auto usage_cell = UsageCell::create(cell, usage_tree->root_ptr());
  auto new_cell = gen_random_cell(rnd.fast(1, X), usage_cell, rnd, with_prunned_branches);
  auto update = MerkleUpdate::generate(cell, new_cell, usage_tree.get());
  return std::make_tuple(new_cell, update, usage_tree);
};

void check_merkle_update(Ref<Cell> A, Ref<Cell> B, Ref<Cell> AB) {
  CHECK(AB.not_null());
  CHECK(A.not_null());
  MerkleUpdate::may_apply(A, AB).ensure();
  MerkleUpdate::validate(AB).ensure();
  auto got_B = MerkleUpdate::apply(A, AB);
  ASSERT_EQ(B->get_hash(), got_B->get_hash());
};

TEST(Cell, MerkleUpdate) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    bool with_prunned_branches = true;
    auto A = gen_random_cell(rnd.fast(1, 1000), rnd, with_prunned_branches);

    Ref<Cell> B;
    Ref<Cell> AB;
    std::tie(B, AB, std::ignore) = gen_merkle_update(A, rnd, with_prunned_branches);
    check_merkle_update(A, B, AB);
  }
};

TEST(Cell, MerkleUpdateCombine) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    bool with_prunned_branches = true;
    auto A = gen_random_cell(rnd.fast(1, X), rnd, with_prunned_branches);

    Ref<Cell> B;
    Ref<Cell> AB;
    std::tie(B, AB, std::ignore) = gen_merkle_update(A, rnd, with_prunned_branches);
    check_merkle_update(A, B, AB);

    Ref<Cell> C;
    Ref<Cell> BC;
    std::tie(C, BC, std::ignore) = gen_merkle_update(B, rnd, with_prunned_branches);
    check_merkle_update(B, C, BC);

    check_merkle_update(A, C, MerkleUpdate::combine(AB, BC));
  }
};

class BenchCellBuilder : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "BenchCellBuilder";
  }

  void run(int n) override {
    td::Random::Xorshift128plus rnd(123);
    std::string data(128, ' ');
    for (auto &c : data) {
      c = static_cast<char>(rnd());
    }

    for (int i = 0; i < n; i++) {
      CellBuilder cb;
      cb.store_bytes(data.data(), rnd() & 127);
      cb.finalize(false);
    }
  }
};
TEST(TonDb, BenchCellBuilder) {
  td::bench(BenchCellBuilder());
}
class BenchCellBuilder2 : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "BenchCellBuilder";
  }

  void run(int n) override {
    td::Random::Xorshift128plus rnd(123);

    for (int i = 0; i < n; i++) {
      gen_random_cell(rnd.fast(1, 1000), rnd);
    }
  }
};
TEST(TonDb, BenchCellBuilder2) {
  td::bench(BenchCellBuilder2());
}
class BenchCellBuilder3 : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "BenchCellBuilder";
  }

  void run(int n) override {
    td::Random::Xorshift128plus rnd(123);

    for (int i = 0; i < n; i++) {
      auto cell = gen_random_cell(rnd.fast(1, 1000), rnd, false);
      auto cell_hash = cell->get_hash().to_hex();

      int mode = get_random_serialization_mode(rnd);

      auto serialized = serialize_boc(std::move(cell), mode);
      CHECK(serialized.size() != 0);

      auto loaded_cell = deserialize_boc(serialized);
      ASSERT_EQ(cell_hash, loaded_cell->get_hash().to_hex());

      auto new_serialized = serialize_boc(std::move(loaded_cell), mode);
      ASSERT_EQ(serialized, new_serialized);
    }
  }
};
TEST(TonDb, BenchCellBuilder3) {
  td::bench(BenchCellBuilder3());
}

TEST(TonDb, BocFuzz) {
  vm::std_boc_deserialize(td::base64_decode("te6ccgEBAQEAAgAoAAA=").move_as_ok()).ensure_error();
  vm::std_boc_deserialize(td::base64_decode("te6ccgQBQQdQAAAAAAEAte6ccgQBB1BBAAAAAAEAAAAAAP/"
                                            "wAACJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJicmJiYmJiYmJiYmJiQ0NDQ0NDQ0NDQ0NDQ0ND"
                                            "Q0NiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiYmJiQAA//AAAO4=")
                              .move_as_ok());
  vm::std_boc_deserialize(td::base64_decode("SEkh/w==").move_as_ok()).ensure_error();
  vm::std_boc_deserialize(
      td::base64_decode(
          "te6ccqwBMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMAKCEAAAAgAQ==")
          .move_as_ok())
      .ensure_error();
}
void test_parse_prefix(td::Slice boc) {
  for (size_t i = 0; i <= boc.size(); i++) {
    auto prefix = boc.substr(0, i);
    vm::BagOfCells::Info info;
    auto res = info.parse_serialized_header(prefix);
    if (res > 0) {
      break;
    }
    CHECK(res != 0);
    CHECK(-res > (int)i);
  }
}

TEST(TonDb, Boc) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    auto cell = gen_random_cell(rnd.fast(1, 1000), rnd);
    auto cell_hash = cell->get_hash();
    auto mode = get_random_serialization_mode(rnd);

    auto serialized = serialize_boc(std::move(cell), mode);
    CHECK(serialized.size() != 0);

    test_parse_prefix(serialized);

    auto loaded_cell = deserialize_boc(serialized);
    ASSERT_EQ(cell_hash, loaded_cell->get_hash());

    auto new_serialized = serialize_boc(std::move(loaded_cell), mode);
    ASSERT_EQ(serialized, new_serialized);
  }
};
TEST(TonDb, BocMultipleRoots) {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 200; t++) {
    auto cells = gen_random_cells(rnd.fast(1, 10), rnd.fast(1, 1000), rnd);
    std::vector<Cell::Hash> cell_hashes;
    for (size_t i = 0; i < cells.size(); i++) {
      cell_hashes.push_back(cells[i]->get_hash());
    }
    auto mode = get_random_serialization_mode(rnd);
    auto serialized = serialize_boc(cells, mode);
    CHECK(serialized.size() != 0);

    auto loaded_cells = deserialize_boc_multiple(serialized);
    ASSERT_EQ(cell_hashes.size(), loaded_cells.size());

    for (size_t i = 0; i < cell_hashes.size(); i++) {
      ASSERT_EQ(cell_hashes[i], loaded_cells[i]->get_hash());
    }
    auto new_serialized = serialize_boc(std::move(loaded_cells), mode);
    ASSERT_EQ(serialized, new_serialized);
  }
};

TEST(TonDb, DynamicBoc) {
  td::Random::Xorshift128plus rnd{123};
  std::string old_root_hash;
  std::string old_root_serialization;
  auto kv = std::make_shared<td::MemoryKeyValue>();
  auto dboc = DynamicBagOfCellsDb::create();
  dboc->set_loader(std::make_unique<CellLoader>(kv));
  for (int t = 1000; t >= 0; t--) {
    if (rnd() % 10 == 0) {
      dboc = DynamicBagOfCellsDb::create();
    }
    dboc->set_loader(std::make_unique<CellLoader>(kv));
    Ref<Cell> old_root;
    if (!old_root_hash.empty()) {
      old_root = dboc->load_cell(old_root_hash).move_as_ok();
      auto serialization = serialize_boc(old_root);
      ASSERT_EQ(old_root_serialization, serialization);
    }

    auto cell = gen_random_cell(rnd.fast(1, 1000), rnd);
    old_root_hash = cell->get_hash().as_slice().str();
    old_root_serialization = serialize_boc(cell);

    // Check that DynamicBagOfCells properly loads cells
    cell = vm::StaticBagOfCellsDbLazy::create(vm::BufferSliceBlobView::create(td::BufferSlice(old_root_serialization)))
               .move_as_ok()
               ->get_root_cell(0)
               .move_as_ok();

    dboc->dec(old_root);
    if (t != 0) {
      dboc->inc(cell);
    }
    dboc->prepare_commit();
    {
      CellStorer cell_storer(*kv);
      dboc->commit(cell_storer);
    }
  }
  ASSERT_EQ(0u, kv->count("").ok());
};

TEST(TonDb, DynamicBoc2) {
  int VERBOSITY_NAME(boc) = VERBOSITY_NAME(DEBUG) + 10;
  td::Random::Xorshift128plus rnd{123};
  int total_roots = 10000;
  int max_roots = 20;
  std::vector<std::string> root_hashes(max_roots);
  std::vector<Ref<Cell>> roots(max_roots);
  int last_commit_at = 0;
  int first_root_id = 0;
  int last_root_id = 0;
  auto kv = std::make_shared<td::MemoryKeyValue>();
  auto dboc = DynamicBagOfCellsDb::create();
  dboc->set_loader(std::make_unique<CellLoader>(kv));

  auto add_root = [&](Ref<Cell> root) {
    dboc->inc(root);
    root_hashes[last_root_id % max_roots] = (root->get_hash().as_slice().str());
    roots[last_root_id % max_roots] = root;
    last_root_id++;
  };

  auto get_root = [&](int root_id) {
    VLOG(boc) << "  from older root #" << root_id;
    auto from_root = roots[root_id % max_roots];
    if (from_root.is_null()) {
      VLOG(boc) << "  from db";
      auto from_root_hash = root_hashes[root_id % max_roots];
      from_root = dboc->load_cell(from_root_hash).move_as_ok();
    } else {
      VLOG(boc) << "FROM MEMORY";
    }
    return from_root;
  };
  auto new_root = [&] {
    if (last_root_id == total_roots) {
      return;
    }
    if (last_root_id - first_root_id >= max_roots) {
      return;
    }
    VLOG(boc) << "add root";
    Ref<Cell> from_root;
    if (first_root_id != last_root_id) {
      from_root = get_root(rnd.fast(first_root_id, last_root_id - 1));
    }
    VLOG(boc) << "  ...";
    add_root(gen_random_cell(rnd.fast(1, 20), from_root, rnd));
    VLOG(boc) << "  OK";
  };

  auto commit = [&] {
    VLOG(boc) << "commit";
    dboc->prepare_commit();
    {
      CellStorer cell_storer(*kv);
      dboc->commit(cell_storer);
    }
    dboc->set_loader(std::make_unique<CellLoader>(kv));
    for (int i = last_commit_at; i < last_root_id; i++) {
      roots[i % max_roots].clear();
    }
    last_commit_at = last_root_id;
  };
  auto reset = [&] {
    VLOG(boc) << "reset";
    commit();
    dboc = DynamicBagOfCellsDb::create();
    dboc->set_loader(std::make_unique<CellLoader>(kv));
  };

  auto delete_root = [&] {
    VLOG(boc) << "Delete root";
    if (first_root_id == last_root_id) {
      return;
    }
    dboc->dec(get_root(first_root_id));
    first_root_id++;
    VLOG(boc) << "  OK";
  };

  td::RandomSteps steps({{new_root, 10}, {delete_root, 9}, {commit, 2}, {reset, 1}});
  while (first_root_id != total_roots) {
    VLOG(boc) << first_root_id << " " << last_root_id << " " << kv->count("").ok();
    steps.step(rnd);
  }
  commit();
  ASSERT_EQ(0u, kv->count("").ok());
}

template <class BocDeserializerT>
td::Status test_boc_deserializer(std::vector<Ref<Cell>> cells, int mode) {
  auto total_data_cells_before = vm::DataCell::get_total_data_cells();
  SCOPE_EXIT {
    auto total_data_cells_after = vm::DataCell::get_total_data_cells();
    ASSERT_EQ(total_data_cells_before, total_data_cells_after);
  };
  auto serialized = serialize_boc(cells, mode);
  CHECK(serialized.size() != 0);

  TRY_RESULT(boc_deserializer, BocDeserializerT::create(serialized));
  TRY_RESULT(root_count, boc_deserializer->get_root_count());
  ASSERT_EQ(cells.size(), root_count);

  std::vector<Ref<Cell>> loaded_cells;
  for (size_t root_i = 0; root_i < root_count; root_i++) {
    TRY_RESULT(loaded_cell, boc_deserializer->get_root_cell(root_i));
    auto cell = cells[root_i];
    ASSERT_EQ(cell->get_level(), loaded_cell->get_level());
    for (int i = 0; i <= (int)cell->get_level(); i++) {
      ASSERT_EQ(cell->get_hash(i), loaded_cell->get_hash(i));
    }
    ASSERT_EQ(loaded_cell->get_hash(cell->get_level()), loaded_cell->get_hash());
    loaded_cells.push_back(std::move(loaded_cell));
  }

  auto new_serialized = serialize_boc(std::move(loaded_cells), mode);
  ASSERT_EQ(serialized, new_serialized);
  return td::Status::OK();
}

template <class BocDeserializerT>
td::Status test_boc_deserializer_threads(Ref<Cell> cell, int mode, td::Random::Xorshift128plus &rnd,
                                         size_t threads_n = 4) {
  auto serialized = serialize_boc(cell, mode);
  CHECK(serialized.size() != 0);
  std::vector<CellExplorer::Exploration> explorations;
  for (size_t i = 0; i < threads_n; i++) {
    explorations.push_back(CellExplorer::random_explore(cell, rnd));
  }
  TRY_RESULT(boc_deserializer, BocDeserializerT::create(serialized));
  TRY_RESULT(root_count, boc_deserializer->get_root_count());
  ASSERT_EQ(1u, root_count);
  TRY_RESULT(loaded_cell, boc_deserializer->get_root_cell(0));
  std::vector<td::thread> threads;
  for (auto &exploration : explorations) {
    threads.emplace_back([&] {
      auto exploration2 = CellExplorer::explore(loaded_cell, exploration.ops);
      ASSERT_EQ(exploration.log, exploration2.log);
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }

  return td::Status::OK();
}

td::Status test_boc_deserializer_full(std::vector<Ref<Cell>> cells) {
  for (auto mode : get_serialization_modes()) {
    TRY_STATUS(vm::test_boc_deserializer<vm::StaticBagOfCellsDbBaseline>(cells, mode));
    TRY_STATUS(vm::test_boc_deserializer<vm::StaticBagOfCellsDbLazy>(cells, mode));
  }
  return td::Status::OK();
}
td::Status test_boc_deserializer_full(Ref<Cell> cell) {
  return test_boc_deserializer_full(std::vector<Ref<Cell>>{std::move(cell)});
}

template <class BocDeserializerT>
void test_boc_deserializer() {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 1000; t++) {
    auto cells = gen_random_cells(rnd.fast(1, 10), static_cast<int>(rnd() % 1000 + 1), rnd);
    for (auto mode : get_serialization_modes()) {
      test_boc_deserializer<BocDeserializerT>(cells, mode).ensure();
    }
  }
}

TEST(TonDb, BocDeserializerBaseline) {
  test_boc_deserializer<StaticBagOfCellsDbBaseline>();
}

TEST(TonDb, BocDeserializerSimple) {
  test_boc_deserializer<StaticBagOfCellsDbLazy>();
}

template <class BocDeserializerT>
void test_boc_deserializer_threads() {
  td::Random::Xorshift128plus rnd{123};
  for (int t = 0; t < 20; t++) {
    auto cell = gen_random_cell(static_cast<int>(rnd() % 1000 + 1), rnd);
    for (auto mode : get_serialization_modes()) {
      test_boc_deserializer_threads<BocDeserializerT>(cell, mode, rnd).ensure();
    }
  }
}

TEST(TonDb, BocDeserializerSimpleThreads) {
  test_boc_deserializer_threads<StaticBagOfCellsDbLazy>();
}

class CompactArray {
 public:
  CompactArray(size_t size) {
    root_ = create(size, 0);
    size_ = size;
  }
  CompactArray(size_t size, Ref<Cell> root) {
    root_ = std::move(root);
    size_ = size;
  }
  CompactArray(td::Span<td::uint64> span) {
    root_ = create(span);
    size_ = span.size();
  }
  CompactArray(CompactArray &&other) = default;
  CompactArray &operator=(CompactArray &&other) = default;

  td::Slice hash() const {
    return root()->get_hash().as_slice();
  }
  void set(size_t pos, td::uint64 value) {
    root_ = set(root_, size_, pos, value);
  }
  td::uint64 get(size_t pos) {
    return get(root_, size_, pos, nullptr);
  }

  const Ref<Cell> &root() const {
    return root_;
  }
  size_t size() const {
    return size_;
  }

  Ref<Cell> merkle_proof(std::vector<size_t> keys) {
    std::set<Cell::Hash> hashes;
    for (auto key : keys) {
      get(root_, size_, key, &hashes);
    }

    auto is_prunned = [&](const Ref<Cell> &cell) { return hashes.count(cell->get_hash()) == 0; };
    return MerkleProof::generate_raw(root_, is_prunned);
  }

 private:
  Ref<Cell> root_;
  size_t size_;

  static Ref<DataCell> create_list(td::uint64 value) {
    CellBuilder cb;
    cb.store_long(value, 64);
    return cb.finalize();
  }
  static Ref<DataCell> create_node(Ref<Cell> left, Ref<Cell> right) {
    CellBuilder cb;
    cb.store_ref(std::move(left));
    cb.store_ref(std::move(right));
    return cb.finalize();
  }
  static Ref<DataCell> create(size_t size, td::uint64 value) {
    if (size == 1) {
      return create_list(value);
    }
    return create_node(create(size / 2, value), create((size + 1) / 2, value));
  }
  static Ref<DataCell> create(td::Span<td::uint64> value) {
    if (value.size() == 1) {
      return create_list(value[0]);
    }
    return create_node(create(value.substr(0, value.size() / 2)), create(value.substr(value.size() / 2)));
  }

  static td::uint64 get(Ref<Cell> any_cell, size_t size, size_t pos, std::set<Cell::Hash> *hashes) {
    if (hashes) {
      hashes->insert(any_cell->get_hash());
    }
    CellSlice cs(NoVm(), any_cell);
    assert(pos < size);
    if (size == 1) {
      return cs.fetch_long(64);
    }
    auto left = cs.fetch_ref();
    if (pos < size / 2) {
      return get(left, size / 2, pos, hashes);
    }
    pos -= size / 2;
    auto right = cs.fetch_ref();
    return get(right, (size + 1) / 2, pos, hashes);
  }

  static Ref<DataCell> set(Ref<Cell> any_cell, size_t size, size_t pos, td::uint64 value) {
    CellSlice cs(NoVm(), any_cell);
    assert(pos < size);
    if (size == 1) {
      return create_list(value);
    }
    //LOG(ERROR) << cell->size_refs() << " " << cell->size_bits();
    auto left = cs.fetch_ref();
    auto right = cs.fetch_ref();
    if (pos < size / 2) {
      left = set(left, size / 2, pos, value);
    } else {
      pos -= size / 2;
      right = set(right, (size + 1) / 2, pos, value);
    }
    return create_node(left, right);
  }
};

class FastCompactArray {
 public:
  FastCompactArray(size_t size) : v_(size) {
  }
  void set(size_t pos, td::uint64 value) {
    v_.at(pos) = value;
  }
  td::uint64 get(size_t pos) {
    return v_.at(pos);
  }
  td::Span<td::uint64> as_span() const {
    return v_;
  }

 private:
  std::vector<td::uint64> v_;
};

TEST(Cell, BocHands) {
  serialize_boc(CellBuilder{}.store_bytes("AAAAAAAA").finalize());
  auto a = CellBuilder{}.store_bytes("abcd").store_ref(CellBuilder{}.store_bytes("???").finalize()).finalize();
  a = CellBuilder{}
          .store_bits("XXX", 3)
          .store_ref(CellBuilder::create_pruned_branch(std::move(a), Cell::max_level))
          .finalize();
  auto serialized = serialize_boc(a);
  deserialize_boc(serialized);
  deserialize_boc(serialize_boc(std::vector<Ref<Cell>>{a, a}));

  // CHECK backward compatibility with
  // serialized_boc_idx and serialized_boc_idx_crc32c
  //auto serialized_idx_crc_x = serialize_boc(a, BagOfCells::WithIndex | BagOfCells::WithCRC32C);
  //LOG(ERROR) << td::format::escaped(serialized_idx_crc_x);
  std::string serialized_idx_crc =
      td::Slice(
          "\254\303\247(\001\001\002\001\000*\004*\201\001P\001\210H\001\004\024\271\313\264\253\277\265\350dN\250{,"
          "\372\021\012:I\354\322|\255\245\330\204+&\345\214\026\300\064\000\001\032\231\063\274")
          .str();
  //auto serialized_idx_x = serialize_boc(a, BagOfCells::WithIndex);
  //LOG(ERROR) << td::format::escaped(serialized_idx_x);
  std::string serialized_idx =
      td::Slice(
          "h\377e\363\001\001\002\001\000*\004*\201\001P\001\210H\001\004\024\271\313\264\253\277\265\350dN\250{,"
          "\372\021\012:I\354\322|\255\245\330\204+&\345\214\026\300\064\000\001")
          .str();

  ASSERT_EQ(serialized, serialize_boc(deserialize_boc(serialized_idx)));
  ASSERT_EQ(serialized, serialize_boc(deserialize_boc(serialized_idx_crc)));
}

TEST(Cell, MerkleProofHands) {
  // data has a reference, because we do not prune lists
  auto data = CellBuilder{}.store_bytes("pruned data").store_ref(CellBuilder{}.finalize()).finalize();
  auto prunned_data = CellBuilder::create_pruned_branch(data, data->get_level() + 1);
  ASSERT_EQ(1u, prunned_data->get_level());
  ASSERT_EQ(prunned_data->get_hash(0), data->get_hash(0));
  ASSERT_EQ(data->get_hash(0), data->get_hash(1));
  ASSERT_TRUE(prunned_data->get_hash(1) != prunned_data->get_hash(0));

  auto node = CellBuilder{}.store_bytes("protected data").store_ref(data).finalize();
  auto proof = CellBuilder{}.store_bits(node->get_data(), node->get_bits()).store_ref(prunned_data).finalize();
  ASSERT_EQ(0u, node->get_level());
  ASSERT_EQ(1u, proof->get_level());
  ASSERT_EQ(proof->get_hash(0), node->get_hash(0));
  ASSERT_TRUE(proof->get_hash(1) != node->get_hash(1));
  test_boc_deserializer_full(proof).ensure();

  auto merkle_proof = CellBuilder::create_merkle_proof(proof);
  ASSERT_EQ(0u, merkle_proof->get_level());
  test_boc_deserializer_full(merkle_proof).ensure();

  {
    auto virtual_node = proof->virtualize({0, 1});
    ASSERT_EQ(0u, virtual_node->get_level());
    ASSERT_EQ(1u, virtual_node->get_virtualization());
    CellSlice cs{NoVm(), virtual_node};
    auto virtual_data = cs.fetch_ref();
    ASSERT_EQ(0u, virtual_data->get_level());
    ASSERT_EQ(1u, virtual_data->get_virtualization());
    ASSERT_EQ(data->get_hash(), virtual_data->get_hash());

    auto virtual_node_copy =
        CellBuilder{}.store_bits(node->get_data(), node->get_bits()).store_ref(virtual_data).finalize();
    ASSERT_EQ(0u, virtual_node_copy->get_level());
    ASSERT_EQ(1u, virtual_node_copy->get_virtualization());
    ASSERT_EQ(virtual_node->get_hash(), virtual_node_copy->get_hash());

    {
      auto two_nodes = CellBuilder{}.store_ref(virtual_node).store_ref(node).finalize();
      ASSERT_EQ(0u, two_nodes->get_level());
      ASSERT_EQ(1u, two_nodes->get_virtualization());
      CellSlice cs2(NoVm(), two_nodes);
      ASSERT_EQ(1u, cs2.prefetch_ref(0)->get_virtualization());
      ASSERT_EQ(0u, cs2.prefetch_ref(1)->get_virtualization());
    }
  }
  LOG(ERROR) << td::NamedThreadSafeCounter::get_default();
}

TEST(Cell, MerkleProofArrayHands) {
  // create simple array
  CompactArray arr(17);
  for (size_t i = 0; i < arr.size(); i++) {
    arr.set(i, i / 3);
  }

  // create merke proof for 4 5 6 and 16th elements
  std::vector<size_t> keys = {4, 5, 6, 16};
  auto proof = arr.merkle_proof(keys);

  ASSERT_EQ(1u, proof->get_level());
  ASSERT_EQ(proof->get_hash(0), arr.root()->get_hash(0));
  ASSERT_TRUE(proof->get_hash(1) != arr.root()->get_hash(1));
  ASSERT_EQ(arr.root()->get_hash(0), arr.root()->get_hash(1));

  CompactArray new_arr(arr.size(), proof->virtualize({0, 1}));
  for (auto k : keys) {
    ASSERT_EQ(arr.get(k), new_arr.get(k));
  }
  test_boc_deserializer_full(proof).ensure();
  test_boc_deserializer_full(CellBuilder::create_merkle_proof(proof)).ensure();
}

TEST(Cell, MerkleProofCombineArray) {
  size_t n = 1 << 15;
  std::vector<td::uint64> data;
  for (size_t i = 0; i < n; i++) {
    data.push_back(i / 3);
  }
  CompactArray arr(data);

  td::Ref<vm::Cell> root = vm::CellBuilder::create_merkle_proof(arr.merkle_proof({}));
  td::Timer timer;
  for (size_t i = 0; i < n; i++) {
    auto new_root = vm::CellBuilder::create_merkle_proof(arr.merkle_proof({i}));
    root = vm::MerkleProof::combine_fast(root, new_root);
    if ((i - 1) % 100 == 0) {
      LOG(ERROR) << timer;
      timer = {};
    }
  }

  CompactArray arr2(n, vm::MerkleProof::virtualize(root, 1));
  for (size_t i = 0; i < n; i++) {
    CHECK(arr.get(i) == arr2.get(i));
  }
}

TEST(Cell, MerkleProofCombineArray2) {
  auto a = vm::CellBuilder().store_long(1, 8).finalize();
  auto b = vm::CellBuilder().store_long(2, 8).finalize();
  auto c = vm::CellBuilder().store_long(3, 8).finalize();
  auto d = vm::CellBuilder().store_long(4, 8).finalize();
  auto left = vm::CellBuilder().store_ref(a).store_ref(b).finalize();
  auto right = vm::CellBuilder().store_ref(c).store_ref(d).finalize();
  auto x = vm::CellBuilder().store_ref(left).store_ref(right).finalize();
  size_t n = 18;
  //TODO: n = 100, currently TL
  for (size_t i = 0; i < n; i++) {
    x = vm::CellBuilder().store_ref(x).store_ref(x).finalize();
  }

  td::Ref<vm::Cell> root;
  auto apply_op = [&](auto op) {
    auto usage_tree = std::make_shared<CellUsageTree>();
    auto usage_cell = UsageCell::create(x, usage_tree->root_ptr());
    root = usage_cell;
    op();
    return MerkleProof::generate(root, usage_tree.get());
  };

  auto first = apply_op([&] {
    auto x = root;
    while (true) {
      auto cs = vm::load_cell_slice(x);
      if (cs.size_refs() == 0) {
        break;
      }
      x = cs.prefetch_ref(0);
    }
  });
  auto second = apply_op([&] {
    auto x = root;
    while (true) {
      auto cs = vm::load_cell_slice(x);
      if (cs.size_refs() == 0) {
        break;
      }
      x = cs.prefetch_ref(1);
    }
  });

  {
    td::Timer t;
    auto x = vm::MerkleProof::combine(first, second);
    LOG(ERROR) << "slow " << t;
  }
  {
    td::Timer t;
    auto x = vm::MerkleProof::combine_fast(first, second);
    LOG(ERROR) << "fast " << t;
  }
}

TEST(Cell, MerkleUpdateHands) {
  auto data = CellBuilder{}.store_bytes("pruned data").store_ref(CellBuilder{}.finalize()).finalize();
  auto node = CellBuilder{}.store_bytes("protected data").store_ref(data).finalize();
  auto other_node = CellBuilder{}.store_bytes("other protected data").store_ref(data).finalize();
  auto usage_tree = std::make_shared<CellUsageTree>();
  auto other_usage_tree = std::make_shared<CellUsageTree>();
  auto usage_cell = UsageCell::create(node, usage_tree->root_ptr());
  auto child = CellSlice(vm::NoVm(), usage_cell).prefetch_ref(0);
  auto new_node = CellBuilder{}.store_bytes("new data").store_ref(child).finalize();
  auto new_child = CellSlice(vm::NoVm(), new_node).prefetch_ref(0);
  auto update = MerkleUpdate::generate(usage_cell, new_node, usage_tree.get());

  MerkleUpdate::may_apply(node, update).ensure();
  MerkleUpdate::validate(update).ensure();
  auto x = MerkleUpdate::apply(node, update);
  ASSERT_TRUE(serialize_boc(new_node) == serialize_boc(x));

  MerkleUpdate::may_apply(other_node, update).ensure_error();
  ASSERT_TRUE(MerkleUpdate::apply(other_node, update).is_null());
  auto other_update = CellBuilder::create_merkle_update(CellBuilder::create_pruned_branch(other_node, 1),
                                                        CellBuilder::create_pruned_branch(new_node, 1));
  MerkleUpdate::may_apply(node, other_update).ensure_error();
  MerkleUpdate::validate(other_update).ensure_error();
  ASSERT_TRUE(MerkleUpdate::apply(other_node, other_update).is_null());
  auto bad_update = CellBuilder::create_merkle_update(CellBuilder::create_pruned_branch(new_node, 1),
                                                      CellBuilder::create_pruned_branch(other_node, 1));
  CHECK(MerkleUpdate::combine(update, bad_update).is_null());
}

TEST(Cell, MerkleUpdateArray) {
  // create simple array
  size_t n = 1 << 20;
  std::vector<td::uint64> data;
  for (size_t i = 0; i < n; i++) {
    data.push_back(i / 3);
  }
  CompactArray arr(data);
  auto root = arr.root();
  auto usage_tree = std::make_shared<CellUsageTree>();
  auto usage_cell = UsageCell::create(root, usage_tree->root_ptr());
  arr = CompactArray(n, usage_cell);
  arr.set(n / 2, 0);
  arr.set(n / 2 + 1, 1);
  arr.set(n / 2 + 2, 2414221111);
  arr.set(n / 2 + 3, 2);

  auto update = MerkleUpdate::generate(usage_cell, arr.root(), usage_tree.get());
  CellStorageStat stat;
  stat.compute_used_storage(update, false);
  ASSERT_EQ(stat.cells, 81u);
  //CellSlice(NoVm(), update).print_rec(std::cerr);

  check_merkle_update(root, arr.root(), update);
}

TEST(Cell, MerkleUpdateCombineArray) {
  size_t n = 1 << 10;
  std::vector<td::uint64> data;
  for (size_t i = 0; i < n; i++) {
    data.push_back(i / 3);
  }
  CompactArray arr(data);
  auto from = arr.root();
  std::shared_ptr<CellUsageTree> usage_tree;
  Ref<Cell> usage_cell;

  std::vector<Ref<Cell>> updates;

  auto apply_op = [&](auto op) {
    auto A = arr.root();
    usage_tree = std::make_shared<CellUsageTree>();
    usage_cell = UsageCell::create(arr.root(), usage_tree->root_ptr());
    arr = CompactArray(n, usage_cell);
    op();
    updates.push_back(MerkleUpdate::generate(A, arr.root(), usage_tree.get()));
  };

  auto combine_all = [&]() {
    while (updates.size() > 1) {
      size_t i = updates.size() - 2;
      updates[i] = MerkleUpdate::combine(updates[i], updates[i + 1]);
      updates.pop_back();
      CellStorageStat stat;
      stat.compute_used_storage(updates[i], false);
    }
  };
  auto validate = [&](size_t size) {
    combine_all();
    check_merkle_update(from, arr.root(), updates.at(0));
    CellStorageStat stat;
    stat.compute_used_storage(updates[0], false);
    if (size != 0) {
      ASSERT_EQ(size, stat.cells);
    }
  };
  apply_op([] {});
  validate(3);
  apply_op([] {});
  apply_op([] {});
  apply_op([] {});
  validate(3);

  apply_op([&] {
    for (size_t i = 0; i < n; i++) {
      arr.set(i, i / 3 + 10);
    }
  });
  apply_op([&] {
    for (size_t i = 0; i < n; i++) {
      arr.set(i, i / 3);
    }
  });
  validate(3);

  for (size_t i = 0; i + 1 < n; i++) {
    apply_op([&] {
      arr.set(i, i / 3 + 1);
      if (i != 0) {
        arr.set(i - 1, (i - 1) / 3);
      }
    });
  }

  validate(41);
}

}  // namespace vm

class BenchBocSerializerImport : public td::Benchmark {
 public:
  BenchBocSerializerImport() {
    std::vector<td::uint64> v(array_size);
    td::Random::Xorshift128plus rnd{123};
    for (auto &x : v) {
      x = rnd();
    }
    arr = vm::CompactArray(v);
    //serialization_ = td::BufferSlice(boc.serialize_to_string(15));
  }
  std::string get_description() const override {
    return "BenchBocSerializer";
  }

  void run(int n) override {
    for (int i = 0; i < n; i++) {
      vm::BagOfCells boc;
      boc.add_root(arr.root());
      boc.import_cells().ensure();
    }
  }

 private:
  td::BufferSlice serialization_;
  static constexpr td::uint32 array_size = 1024;
  vm::CompactArray arr{1};
};

class BenchBocSerializerSerialize : public td::Benchmark {
 public:
  BenchBocSerializerSerialize() {
    std::vector<td::uint64> v(array_size);
    td::Random::Xorshift128plus rnd{123};
    for (auto &x : v) {
      x = rnd();
    }
    arr = vm::CompactArray(v);
    boc.add_root(arr.root());
    boc.import_cells().ensure();
  }
  std::string get_description() const override {
    return "BenchBocSerializer";
  }

  void run(int n) override {
    for (int i = 0; i < n; i++) {
      boc.serialize_to_string(31);
    }
  }

 private:
  td::BufferSlice serialization_;
  static constexpr td::uint32 array_size = 1024;
  vm::CompactArray arr{1};
  vm::BagOfCells boc;
};

struct BenchBocDeserializerConfig {
  enum BlobType { File, Memory, FileMemoryMap, RocksDb } blob_type;
  int k{100};
  enum Mode { Prefix, Range, Random } mode{Random};
  bool with_index{true};
  int threads_n{1};
};

td::StringBuilder &operator<<(td::StringBuilder &sb, const BenchBocDeserializerConfig &config) {
  sb << "load from ";
  switch (config.blob_type) {
    case BenchBocDeserializerConfig::File:
      sb << "file";
      break;
    case BenchBocDeserializerConfig::Memory:
      sb << "memory";
      break;
    case BenchBocDeserializerConfig::FileMemoryMap:
      sb << "file mmap";
      break;
    case BenchBocDeserializerConfig::RocksDb:
      sb << "rocksdb";
      break;
  }
  sb << td::tag("k", config.k) << " ";
  switch (config.mode) {
    case BenchBocDeserializerConfig::Prefix:
      sb << "prefix";
      break;
    case BenchBocDeserializerConfig::Range:
      sb << "range";
      break;
    case BenchBocDeserializerConfig::Random:
      sb << "random";
      break;
  }
  sb << " " << (config.with_index ? "with" : "without") << " index";
  sb << " " << config.threads_n << " threads";
  return sb;
}

template <class DeserializerT>
class BenchBocDeserializer : public td::Benchmark {
 public:
  BenchBocDeserializer(std::string name, BenchBocDeserializerConfig config) : name_(std::move(name)), config_(config) {
    fast_array_ = vm::FastCompactArray(array_size);
    td::Random::Xorshift128plus rnd{123};
    for (td::uint32 i = 0; i < array_size; i++) {
      auto val = rnd();
      fast_array_.set(i, val);
    }
    vm::CompactArray arr(fast_array_.as_span());
    auto db_path = "serialization_rocksdb";
    if (config.blob_type == BenchBocDeserializerConfig::RocksDb) {
      {
        td::RocksDb::destroy(td::Slice(db_path)).ensure();
        auto db = vm::TonDbImpl::open(td::Slice(db_path)).move_as_ok();
        auto txn = db->begin_transaction();
        auto smt = txn->begin_smartcontract();
        SCOPE_EXIT {
          db->commit_transaction(std::move(txn));
        };
        SCOPE_EXIT {
          txn->commit_smartcontract(std::move(smt));
        };
        smt->set_root(arr.root());
      }
      db_ = vm::TonDbImpl::open(td::Slice(db_path)).move_as_ok();
    } else {
      serialization_ = td::BufferSlice(serialize_boc(
          arr.root(), vm::BagOfCells::WithIntHashes | vm::BagOfCells::WithTopHash |
                          (config.with_index ? vm::BagOfCells::WithIndex | vm::BagOfCells::WithCacheBits : 0)));

      if (config.blob_type == BenchBocDeserializerConfig::File ||
          config.blob_type == BenchBocDeserializerConfig::FileMemoryMap) {
        td::unlink("serialization").ignore();
        td::write_file("serialization", serialization_.as_slice()).ensure();
      }
    }
    root_ = arr.root();
  }
  std::string get_description() const override {
    return PSTRING() << "BocDeserializer " << name_ << " " << config_;
  }

  vm::Ref<vm::Cell> load_root() {
    if (config_.blob_type == BenchBocDeserializerConfig::RocksDb) {
      auto txn = db_->begin_transaction();
      auto smt = txn->begin_smartcontract();
      SCOPE_EXIT {
        db_->abort_transaction(std::move(txn));
      };
      SCOPE_EXIT {
        txn->commit_smartcontract(std::move(smt));
      };
      LOG(ERROR) << "load root from rocksdb";
      return smt->get_root();
    }
    auto blob = [&] {
      switch (config_.blob_type) {
        case BenchBocDeserializerConfig::File:
          return vm::FileBlobView::create("serialization").move_as_ok();
        case BenchBocDeserializerConfig::Memory:
          return vm::BufferSliceBlobView::create(serialization_.clone());
        case BenchBocDeserializerConfig::FileMemoryMap:
          return vm::FileMemoryMappingBlobView::create("serialization").move_as_ok();
        default:
          UNREACHABLE();
      }
      UNREACHABLE();
    }();
    auto boc_deserializer = DeserializerT::create(std::move(blob)).move_as_ok();
    ASSERT_EQ(1u, boc_deserializer->get_root_count().move_as_ok());
    return boc_deserializer->get_root_cell(0).move_as_ok();
  }

  void run(int n) override {
    td::Random::Xorshift128plus rnd{123};

    std::vector<td::thread> threads;
    //TODO: use config.k
    auto K = config_.k == 0 ? n : config_.k;
    td::Stage stage;
    vm::Ref<vm::Cell> root;
    for (int t = 0; t < config_.threads_n; t++) {
      threads.emplace_back([&, seed = rnd(), thread_i = t] {
        for (int round_i = 0; round_i < n / K; round_i++) {
          if (thread_i == 0) {
            root = load_root();
          }
          stage.wait(config_.threads_n * (2 * round_i + 1));

          vm::CompactArray array(array_size, root);
          td::Random::Xorshift128plus rnd{seed};
          td::uint64 start_pos =
              config_.mode == BenchBocDeserializerConfig::Range ? array_size / config_.threads_n * thread_i : 0;
          for (int k = 0; k < K; k++) {
            auto pos = start_pos;
            switch (config_.mode) {
              case BenchBocDeserializerConfig::Prefix:
              case BenchBocDeserializerConfig::Range:
                pos = (pos + k) % array_size;
                break;
              case BenchBocDeserializerConfig::Random:
                pos = rnd() % array_size;
                break;
            }
            ASSERT_EQ(fast_array_.get(td::narrow_cast<std::size_t>(pos)), array.get(td::narrow_cast<std::size_t>(pos)));
          }
          stage.wait(config_.threads_n * (2 * round_i + 2));
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }

 private:
  std::string name_;
  td::BufferSlice serialization_;
  BenchBocDeserializerConfig config_;
  static constexpr td::uint32 array_size = 1024 * 1024;
  vm::FastCompactArray fast_array_{array_size};
  vm::Ref<vm::Cell> root_;
  vm::TonDb db_;
};

TEST(TonDb, BenchBocSerializerImport) {
  if (0) {
    BenchBocSerializerImport b;
    while (true) {
      td::bench_n(b, 1000000);
    }
  }
  td::bench(BenchBocSerializerImport());
}
TEST(TonDb, BenchBocSerializerSerialize) {
  td::bench(BenchBocSerializerSerialize());
}

template <class DeserializerT>
void bench_deserializer(std::string name, bool full) {
  using Config = BenchBocDeserializerConfig;
  if (full) {
    for (auto k : {1, 10, 100}) {
      for (auto with_index : {false, true}) {
        for (auto mode : {Config::Prefix, Config::Range, Config::Random}) {
          for (auto blob_type : {Config::Memory, Config::File, Config::FileMemoryMap}) {
            BenchBocDeserializerConfig config;
            config.k = k;
            config.with_index = with_index;
            config.mode = mode;
            config.blob_type = blob_type;
            td::bench(BenchBocDeserializer<DeserializerT>(name, config));
          }
        }
      }
    }
  } else {
    td::bench(BenchBocDeserializer<DeserializerT>(name, BenchBocDeserializerConfig()));
  }
}
template <class DeserializerT>
void bench_deserializer_threads(std::string name) {
  using Config = BenchBocDeserializerConfig;
  for (auto threads_n : {1, 4, 16}) {
    //for (auto threads_n : {16}) {
    //for (auto with_index : {false, true}) {
    //for (auto mode : {BenchBocDeserializerConfig::Prefix, BenchBocDeserializerConfig::Range,
    //BenchBocDeserializerConfig::Random}) {
    //for (auto from_file : {false, true}) {
    BenchBocDeserializerConfig config;
    config.threads_n = threads_n;
    config.k = 0;
    config.with_index = true;
    config.mode = Config::Random;
    config.mode = Config::Range;
    config.mode = Config::Prefix;
    config.blob_type = Config::Memory;
    td::bench(BenchBocDeserializer<DeserializerT>(name, config));
    //td::bench_n(BenchBocThreadsDeserializer<DeserializerT>(name, config), 1000000);
    //}
    //}
    //}
  }
}

TEST(TonDb, BenchBocThreadsDeserializerSimple) {
  //td::bench_n(BenchBocDeserializer<vm::StaticBagOfCellsDbLazy>("simple", BenchBocDeserializerConfig()), 1000000);
  //std::exit(0);
  bench_deserializer_threads<vm::StaticBagOfCellsDbLazy>("simple");
}
TEST(TonDb, BenchBocDeserializerSimple) {
  //td::bench_n(BenchBocDeserializer<vm::StaticBagOfCellsDbLazy>("simple", BenchBocDeserializerConfig()), 1000000);
  //std::exit(0);
  bench_deserializer<vm::StaticBagOfCellsDbLazy>("simple", false);
}
TEST(TonDb, BenchBocDeserializerBaseline) {
  //td::bench_n(BenchBocDeserializer<vm::StaticBagOfCellsDbBaseline>("baseline", BenchBocDeserializerConfig()), 1000000);
  //std::exit(0);
  bench_deserializer<vm::StaticBagOfCellsDbBaseline>("baseline", false);
}
TEST(TonDb, BenchBocDeserializerRocksDb) {
  //td::bench_n(BenchBocDeserializer<vm::StaticBagOfCellsDbBaseline>("baseline", BenchBocDeserializerConfig()), 1000000);
  //std::exit(0);
  auto config = BenchBocDeserializerConfig();
  config.blob_type = BenchBocDeserializerConfig::RocksDb;
  config.threads_n = 4;
  config.k = 0;
  td::bench(BenchBocDeserializer<vm::StaticBagOfCellsDbBaseline>("rockdb", config));
}

TEST(TonDb, CompactArray) {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(ERROR));
  td::Slice db_path = "compact_array_db";
  td::RocksDb::destroy(db_path).ensure();

  td::Random::Xorshift128plus rnd(123);

  auto next_array_size = [&rnd]() {
    static std::vector<size_t> array_sizes = {1, 2, 4, 10, 37, 100, 1000, 10000};
    return array_sizes[rnd() % array_sizes.size()];
  };

  vm::CompactArray array(2);
  vm::FastCompactArray fast_array(2);
  auto next_pos = [&] { return static_cast<size_t>(rnd() % array.size()); };

  auto db = vm::TonDbImpl::open(db_path).move_as_ok();
  auto txn = db->begin_transaction();
  auto smt = txn->begin_smartcontract();
  SCOPE_EXIT {
    db->commit_transaction(std::move(txn));
  };
  SCOPE_EXIT {
    txn->commit_smartcontract(std::move(smt));
  };

  auto flush_to_db = [&] {
    if (rnd() % 10 != 0) {
      return;
    }
    bool restart_db = rnd() % 20 == 0;
    bool reload_array = rnd() % 5 == 0;
    smt->set_root(array.root());
    txn->commit_smartcontract(std::move(smt));
    db->commit_transaction(std::move(txn));
    if (restart_db) {
      db->clear_cache();
      //db.reset();
      //db = vm::TonDbImpl::open(db_path).move_as_ok();
    }
    txn = db->begin_transaction();
    smt = txn->begin_smartcontract();
    smt->validate_meta().ensure();
    ASSERT_EQ(smt->get_root()->get_hash(), array.root()->get_hash());
    if (reload_array) {
      auto size = array.size();
      array = vm::CompactArray(size, smt->get_root());
    }
  };

  auto do_validate = [&](size_t pos) { ASSERT_EQ(array.get(pos), fast_array.get(pos)); };
  auto validate = [&] { do_validate(next_pos()); };
  auto validate_full = [&] {
    for (size_t pos = 0; pos < array.size(); pos++) {
      do_validate(pos);
    }
  };

  auto set_value = [&] {
    auto pos = static_cast<size_t>(rnd() % array.size());
    auto value = rnd() % 3;
    array.set(pos, value);
    fast_array.set(pos, value);
  };

  auto reset_array = [&] {
    auto size = next_array_size();
    array = vm::CompactArray(size);
    fast_array = vm::FastCompactArray(size);
  };

  td::RandomSteps steps({{reset_array, 1}, {set_value, 1000}, {validate, 10}, {validate_full, 2}, {flush_to_db, 1}});
  for (size_t t = 0; t < 100000; t++) {
    if (t % 10000 == 0) {
      LOG(ERROR) << t;
    }
    steps.step(rnd);
  }
};

TEST(TonDb, CompactArrayOld) {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(ERROR));
  using namespace vm;
  //auto kv = std::make_unique<MemoryKeyValue>();
  td::RocksDb::destroy("ttt").ensure();

  auto ton_db = vm::TonDbImpl::open("ttt").move_as_ok();

  //auto storage = std::make_unique<CellStorage>(kv.get());

  size_t array_size = 1000;
  std::string hash;
  td::Random::Xorshift128plus rnd(123);
  FastCompactArray fast_array(array_size);
  {
    auto txn = ton_db->begin_transaction();
    SCOPE_EXIT {
      ton_db->commit_transaction(std::move(txn));
    };
    auto smart = txn->begin_smartcontract("");
    SCOPE_EXIT {
      txn->commit_smartcontract(std::move(smart));
    };
    CompactArray arr(array_size);
    arr.set(array_size / 2, 124);
    fast_array.set(array_size / 2, 124);
    //for (size_t i = 0; i < array_size; i++) {
    //int x = rnd() % 2;
    //arr.set(i, x);
    //fast_array.set(i, x);
    //}
    smart->set_root(arr.root());
    LOG(ERROR) << smart->get_root()->get_hash().to_hex();
  }
  //LOG(ERROR) << "OK";

  for (int i = 0; i < 100; i++) {
    if (i % 10 == 9) {
      //LOG(ERROR) << ton_db->stat();
      ton_db.reset();
      ton_db = vm::TonDbImpl::open("ttt").move_as_ok();
    }
    auto txn = ton_db->begin_transaction();
    SCOPE_EXIT {
      ton_db->commit_transaction(std::move(txn));
    };
    auto smart = txn->begin_smartcontract("");
    //smart->validate_meta();
    SCOPE_EXIT {
      txn->commit_smartcontract(std::move(smart));
    };
    if (i % 1000 == 0) {
      LOG(ERROR) << "i = " << i;
    }
    CompactArray arr(array_size, smart->get_root());
    auto key = static_cast<size_t>(rnd() % array_size);
    auto value = rnd() % 2;
    arr.set(key, value);
    fast_array.set(key, value);
    smart->set_root(arr.root());
    //LOG(ERROR) << storage->size();
  }
  {
    auto txn = ton_db->begin_transaction();
    SCOPE_EXIT {
      ton_db->abort_transaction(std::move(txn));
    };
    auto smart = txn->begin_smartcontract("");
    SCOPE_EXIT {
      txn->abort_smartcontract(std::move(smart));
    };

    CompactArray arr(array_size, smart->get_root());
    for (size_t i = 0; i < array_size; i++) {
      ASSERT_EQ(fast_array.get(i), arr.get(i));
    }
  }
}

TEST(TonDb, StackOverflow) {
  try {
    td::Ref<vm::Cell> cell = vm::CellBuilder().finalize();
    for (int i = 0; i < 10000000; i++) {
      vm::CellBuilder cb;
      cb.store_ref(std::move(cell));
      cell = cb.finalize();
    }
    LOG(ERROR) << "A";
    vm::test_boc_deserializer<vm::StaticBagOfCellsDbBaseline>({cell}, 31);
    LOG(ERROR) << "B";
    vm::test_boc_deserializer<vm::StaticBagOfCellsDbLazy>({cell}, 31);
    LOG(ERROR) << "C";
  } catch (...) {
  }

  struct A : public td::CntObject {
    explicit A(td::Ref<A> next) : next(next) {
    }
    td::Ref<A> next;
  };
  {
    td::Ref<A> head;
    for (int i = 0; i < 10000000; i++) {
      td::Ref<A> new_head = td::Ref<A>(true, std::move(head));
      head = std::move(new_head);
    }
  }
}

TEST(TonDb, BocRespectsUsageCell) {
  td::Random::Xorshift128plus rnd(123);
  auto cell = vm::gen_random_cell(20, rnd, true);
  auto usage_tree = std::make_shared<vm::CellUsageTree>();
  auto usage_cell = vm::UsageCell::create(cell, usage_tree->root_ptr());
  auto serialization = serialize_boc(usage_cell);
  auto proof = vm::MerkleProof::generate(cell, usage_tree.get());
  auto virtualized_proof = vm::MerkleProof::virtualize(proof, 1);
  auto serialization_of_virtualized_cell = serialize_boc(virtualized_proof);
  ASSERT_STREQ(serialization, serialization_of_virtualized_cell);
}

TEST(TonDb, DynamicBocRespectsUsageCell) {
  td::Random::Xorshift128plus rnd(123);
  auto cell = vm::gen_random_cell(20, rnd, true);
  auto usage_tree = std::make_shared<vm::CellUsageTree>();
  auto usage_cell = vm::UsageCell::create(cell, usage_tree->root_ptr());

  auto kv = std::make_shared<td::MemoryKeyValue>();
  auto dboc = vm::DynamicBagOfCellsDb::create();
  dboc->set_loader(std::make_unique<vm::CellLoader>(kv));
  dboc->inc(usage_cell);
  {
    vm::CellStorer cell_storer(*kv);
    dboc->commit(cell_storer);
  }

  auto proof = vm::MerkleProof::generate(cell, usage_tree.get());
  auto virtualized_proof = vm::MerkleProof::virtualize(proof, 1);
  auto serialization_of_virtualized_cell = serialize_boc(virtualized_proof);
  auto serialization = serialize_boc(cell);
  ASSERT_STREQ(serialization, serialization_of_virtualized_cell);
}

TEST(TonDb, DoNotMakeListsPrunned) {
  auto cell = vm::CellBuilder().store_bytes("abc").finalize();
  auto is_prunned = [&](const td::Ref<vm::Cell> &cell) { return true; };
  auto proof = vm::MerkleProof::generate(cell, is_prunned);
  auto virtualized_proof = vm::MerkleProof::virtualize(proof, 1);
  ASSERT_TRUE(virtualized_proof->get_virtualization() == 0);
}

TEST(TonDb, CellStat) {
  td::Random::Xorshift128plus rnd(123);
  bool with_prunned_branches = true;
  for (int i = 0; i < 1000; i++) {
    auto A = vm::gen_random_cell(100, rnd, with_prunned_branches);
    td::Ref<vm::Cell> B, AB, B_proof;
    std::shared_ptr<vm::CellUsageTree> usage_tree;
    std::tie(B, AB, usage_tree) = gen_merkle_update(A, rnd, with_prunned_branches);
    B_proof = vm::CellSlice(vm::NoVm(), AB).prefetch_ref(1);

    vm::CellStorageStat stat;
    stat.add_used_storage(B);

    vm::NewCellStorageStat new_stat;
    new_stat.add_cell({});
    new_stat.add_cell(B);
    ASSERT_EQ(stat.cells, new_stat.get_stat().cells);
    ASSERT_EQ(stat.bits, new_stat.get_stat().bits);

    vm::CellStorageStat proof_stat;
    proof_stat.add_used_storage(B_proof);

    vm::NewCellStorageStat new_proof_stat;
    new_proof_stat.add_proof(B, usage_tree.get());
    CHECK(new_proof_stat.get_stat().cells == 0);
    CHECK(new_proof_stat.get_proof_stat().cells <= proof_stat.cells);
    //CHECK(new_proof_stat.get_proof_stat().cells + new_proof_stat.get_proof_stat().external_refs >= proof_stat.cells);

    vm::NewCellStorageStat new_all_stat;
    new_all_stat.add_cell_and_proof(B, usage_tree.get());
    CHECK(new_proof_stat.get_proof_stat() == new_all_stat.get_proof_stat());
    CHECK(new_stat.get_stat() == new_all_stat.get_stat());

    stat.add_used_storage(A);
    auto AB_stat = new_stat.get_stat() + const_cast<vm::NewCellStorageStat &>(new_stat).tentative_add_cell(A);
    new_stat.add_cell(A);
    CHECK(AB_stat == new_stat.get_stat());
    ASSERT_EQ(stat.cells, new_stat.get_stat().cells);
    ASSERT_EQ(stat.bits, new_stat.get_stat().bits);

    CHECK(usage_tree.unique());
    usage_tree.reset();
    td::Ref<vm::Cell> C, BC, C_proof;
    std::shared_ptr<vm::CellUsageTree> usage_tree_B;
    std::tie(C, BC, usage_tree_B) = gen_merkle_update(B, rnd, with_prunned_branches);
    C_proof = vm::CellSlice(vm::NoVm(), BC).prefetch_ref(1);

    auto BC_proof_stat = new_proof_stat.get_proof_stat() + new_proof_stat.tentative_add_proof(C, usage_tree_B.get());
    new_proof_stat.add_proof(C, usage_tree_B.get());
    CHECK(BC_proof_stat == new_proof_stat.get_proof_stat());
  }
}

struct String {
  String() {
    total_strings.add(1);
  }
  String(std::string str) : str(std::move(str)) {
    total_strings.add(1);
  }
  ~String() {
    total_strings.add(-1);
  }
  static td::ThreadSafeCounter total_strings;
  std::string str;
};

td::ThreadSafeCounter String::total_strings;
TEST(Ref, AtomicRef) {
  struct Node {
    td::AtomicRefLockfree<td::Cnt<String>> name_;
    char pad[64];
  };

  int threads_n = 10;
  std::vector<Node> nodes(threads_n);
  std::vector<td::thread> threads(threads_n);
  int thread_id = 0;
  for (auto &thread : threads) {
    thread = td::thread([&] {
      for (int i = 0; i < 1000000; i++) {
        auto &node = nodes[td::Random::fast(0, threads_n / 3 - 1)];
        auto name = node.name_.load();
        if (name.not_null()) {
          CHECK(name->str == "one" || name->str == "twotwo");
        }
        if (td::Random::fast(0, 5) == 0) {
          auto new_string = td::Ref<td::Cnt<String>>{true, td::Random::fast(0, 1) == 0 ? "one" : "twotwo"};
          node.name_.store(std::move(new_string));
        }
      }
    });
    thread_id++;
  }
  for (auto &thread : threads) {
    thread.join();
  }
  nodes.clear();
  LOG(ERROR) << String::total_strings.sum();
}

class FileMerkleTree {
 public:
  FileMerkleTree(size_t chunks_count, td::Ref<vm::Cell> root = {}) {
    log_n_ = 0;
    while ((size_t(1) << log_n_) < chunks_count) {
      log_n_++;
    }
    n_ = size_t(1) << log_n_;
    mark_.resize(n_ * 2);
    proof_.resize(n_ * 2);

    CHECK(n_ == chunks_count);  // TODO: support other chunks_count
    //auto x = vm::CellBuilder().finalize();
    root_ = std::move(root);
  }

  struct Chunk {
    td::size_t index{0};
    td::Slice hash;
  };

  void remove_chunk(td::size_t index) {
    CHECK(index < n_);
    index += n_;
    while (proof_[index].not_null()) {
      proof_[index] = {};
      index /= 2;
    }
  }

  bool has_chunk(td::size_t index) const {
    CHECK(index < n_);
    index += n_;
    return proof_[index].not_null();
  }

  void add_chunk(td::size_t index, td::Slice hash) {
    CHECK(hash.size() == 32);
    CHECK(index < n_);
    index += n_;
    auto cell = vm::CellBuilder().store_bytes(hash).finalize();
    CHECK(proof_[index].is_null());
    proof_[index] = std::move(cell);
    for (index /= 2; index != 0; index /= 2) {
      CHECK(proof_[index].is_null());
      auto &left = proof_[index * 2];
      auto &right = proof_[index * 2 + 1];
      if (left.not_null() && right.not_null()) {
        proof_[index] = vm::CellBuilder().store_ref(left).store_ref(right).finalize();
      } else {
        mark_[index] = mark_id_;
      }
    }
  }

  td::Status validate_proof(td::Ref<vm::Cell> new_root) {
    // TODO: check structure
    return td::Status::OK();
  }

  td::Status add_proof(td::Ref<vm::Cell> new_root) {
    TRY_STATUS(validate_proof(new_root));
    auto combined = vm::MerkleProof::combine_fast_raw(root_, new_root);
    if (combined.is_null()) {
      return td::Status::Error("Can't combine proofs");
    }
    root_ = std::move(combined);
    return td::Status::OK();
  }

  td::Status try_add_chunks(td::Span<Chunk> chunks) {
    for (auto chunk : chunks) {
      if (has_chunk(chunk.index)) {
        return td::Status::Error("Already has chunk");
      }
    }
    mark_id_++;
    for (auto chunk : chunks) {
      add_chunk(chunk.index, chunk.hash);
    }
    auto r_new_root = merge(root_, 1);
    if (r_new_root.is_error()) {
      for (auto chunk : chunks) {
        remove_chunk(chunk.index);
      }
      return r_new_root.move_as_error();
    }
    root_ = r_new_root.move_as_ok();
    return td::Status::OK();
  }

  td::Result<td::Ref<vm::Cell>> merge(td::Ref<vm::Cell> root, size_t index) {
    const auto &down = proof_[index];
    if (down.not_null()) {
      if (down->get_hash() != root->get_hash(0)) {
        return td::Status::Error("Hash mismatch");
      }
      return down;
    }

    if (mark_[index] != mark_id_) {
      return root;
    }

    vm::CellSlice cs(vm::NoVm(), root);
    if (cs.is_special()) {
      return td::Status::Error("Proof is not enough to validate chunks");
    }

    CHECK(cs.size_refs() == 2);
    vm::CellBuilder cb;
    cb.store_bits(cs.fetch_bits(cs.size()));
    TRY_RESULT(left, merge(cs.fetch_ref(), index * 2));
    TRY_RESULT(right, merge(cs.fetch_ref(), index * 2 + 1));
    cb.store_ref(std::move(left)).store_ref(std::move(right));
    return cb.finalize();
  }

  void init_proof() {
    CHECK(proof_[1].not_null());
    root_ = proof_[1];
  }

  td::Result<td::Ref<vm::Cell>> gen_proof(size_t l, size_t r) {
    auto usage_tree = std::make_shared<vm::CellUsageTree>();
    auto usage_cell = vm::UsageCell::create(root_, usage_tree->root_ptr());
    TRY_STATUS(do_gen_proof(std::move(usage_cell), 0, n_ - 1, l, r));
    auto res = vm::MerkleProof::generate_raw(root_, usage_tree.get());
    CHECK(res.not_null());
    return res;
  }

 private:
  td::size_t n_;  // n = 2^log_n
  td::size_t log_n_;
  td::size_t mark_id_{0};
  std::vector<td::size_t> mark_;          // n_ * 2
  std::vector<td::Ref<vm::Cell>> proof_;  // n_ * 2
  td::Ref<vm::Cell> root_;

  td::Status do_gen_proof(td::Ref<vm::Cell> node, size_t il, size_t ir, size_t l, size_t r) {
    if (ir < l || il > r) {
      return td::Status::OK();
    }
    if (l <= il && ir <= r) {
      return td::Status::OK();
    }
    vm::CellSlice cs(vm::NoVm(), std::move(node));
    if (cs.is_special()) {
      return td::Status::Error("Can't generate a proof");
    }
    CHECK(cs.size_refs() == 2);
    auto ic = (il + ir) / 2;
    TRY_STATUS(do_gen_proof(cs.fetch_ref(), il, ic, l, r));
    TRY_STATUS(do_gen_proof(cs.fetch_ref(), ic + 1, ir, l, r));
    return td::Status::OK();
  }
};

TEST(FileMerkleTree, Manual) {
  // create big random file
  size_t chunk_size = 768;
  // for simplicity numer of chunks in a file is a power of two
  size_t chunks_count = 1 << 16;
  size_t file_size = chunk_size * chunks_count;
  td::Timer timer;
  LOG(INFO) << "Generate random string";
  const auto file = td::rand_string('a', 'z', td::narrow_cast<int>(file_size));
  LOG(INFO) << timer;

  timer = {};
  LOG(INFO) << "Calculate all hashes";
  std::vector<td::UInt256> hashes(chunks_count);
  for (size_t i = 0; i < chunks_count; i++) {
    td::sha256(td::Slice(file).substr(i * chunk_size, chunk_size), hashes[i].as_slice());
  }
  LOG(INFO) << timer;

  timer = {};
  LOG(INFO) << "Init merkle tree";
  FileMerkleTree tree(chunks_count);
  for (size_t i = 0; i < chunks_count; i++) {
    tree.add_chunk(i, hashes[i].as_slice());
  }
  tree.init_proof();
  LOG(INFO) << timer;

  auto root_proof = tree.gen_proof(0, chunks_count - 1).move_as_ok();

  // first download each chunk one by one

  for (size_t stride : {1 << 6, 1}) {
    timer = {};
    LOG(INFO) << "Gen all proofs, stride = " << stride;
    for (size_t i = 0; i < chunks_count; i += stride) {
      tree.gen_proof(i, i + stride - 1).move_as_ok();
    }
    LOG(INFO) << timer;
    timer = {};
    LOG(INFO) << "Proof size: " << vm::std_boc_serialize(tree.gen_proof(0, stride - 1).move_as_ok()).ok().size();
    LOG(INFO) << "Download file, stride = " << stride;
    {
      FileMerkleTree new_tree(chunks_count, root_proof);
      for (size_t i = 0; i < chunks_count; i += stride) {
        new_tree.add_proof(tree.gen_proof(i, i + stride - 1).move_as_ok()).ensure();
        std::vector<FileMerkleTree::Chunk> chunks;
        for (size_t j = 0; j < stride; j++) {
          chunks.push_back({i + j, hashes[i + j].as_slice()});
        }
        new_tree.try_add_chunks(chunks).ensure();
      }
    }
    LOG(INFO) << timer;
  }
}

//TEST(Tmp, Boc) {
//LOG(ERROR) << "A";
//auto data = td::read_file("boc");
//LOG(ERROR) << "B";
//auto cell = vm::deserialize_boc(data.move_as_ok().as_slice());
//vm::CellStorageStat stat;
//stat.add_used_storage(cell, false);
//LOG(ERROR) << stat.cells;
////LOG(ERROR) << "C";
////auto new_data = vm::serialize_boc(cell);
////LOG(ERROR) << "D";
//vm::test_boc_deserializer<vm::StaticBagOfCellsDbLazy>({cell}, 31);
//}
