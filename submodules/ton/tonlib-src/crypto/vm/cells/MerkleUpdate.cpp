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
#include "vm/cells/MerkleUpdate.h"
#include "vm/cells/MerkleProof.h"

#include "td/utils/HashMap.h"
#include "td/utils/HashSet.h"

namespace vm {
namespace detail {
class MerkleUpdateApply {
 public:
  Ref<Cell> apply(Ref<Cell> from, Ref<Cell> update_from, Ref<Cell> update_to, td::uint32 from_level,
                  td::uint32 to_level) {
    if (from_level != from->get_level()) {
      return {};
    }
    dfs_both(from, update_from, from_level);
    return dfs(update_to, to_level);
  }

 private:
  using Key = std::pair<Cell::Hash, int>;
  td::HashMap<Cell::Hash, Ref<Cell>> known_cells_;
  td::HashMap<Key, Ref<Cell>> ready_cells_;

  void dfs_both(Ref<Cell> original, Ref<Cell> update_from, int merkle_depth) {
    CellSlice cs_update_from(NoVm(), update_from);
    known_cells_.emplace(original->get_hash(merkle_depth), original);
    if (cs_update_from.special_type() == Cell::SpecialType::PrunnedBranch) {
      return;
    }
    int child_merkle_depth = cs_update_from.child_merkle_depth(merkle_depth);

    CellSlice cs_original(NoVm(), original);
    for (unsigned i = 0; i < cs_original.size_refs(); i++) {
      dfs_both(cs_original.prefetch_ref(i), cs_update_from.prefetch_ref(i), child_merkle_depth);
    }
  }

  Ref<Cell> dfs(Ref<Cell> cell, int merkle_depth) {
    CellSlice cs(NoVm(), cell);
    if (cs.special_type() == Cell::SpecialType::PrunnedBranch) {
      if ((int)cell->get_level() == merkle_depth + 1) {
        auto it = known_cells_.find(cell->get_hash(merkle_depth));
        if (it != known_cells_.end()) {
          return it->second;
        }
        return {};
      }
      return cell;
    }
    Key key{cell->get_hash(), merkle_depth};
    {
      auto it = ready_cells_.find(key);
      if (it != ready_cells_.end()) {
        return it->second;
      }
    }

    int child_merkle_depth = cs.child_merkle_depth(merkle_depth);

    CellBuilder cb;
    cb.store_bits(cs.fetch_bits(cs.size()));
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      auto ref = dfs(cs.prefetch_ref(i), child_merkle_depth);
      if (ref.is_null()) {
        return {};
      }
      cb.store_ref(std::move(ref));
    }
    auto res = cb.finalize(cs.is_special());
    ready_cells_.emplace(key, res);
    return res;
  }
};

class MerkleUpdateValidator {
 public:
  td::Status validate(Ref<Cell> update_from, Ref<Cell> update_to, td::uint32 from_level, td::uint32 to_level) {
    dfs_from(update_from, from_level);
    return dfs_to(update_to, to_level);
  }

 private:
  td::HashSet<Cell::Hash> known_cells_;
  using Key = std::pair<Cell::Hash, int>;
  td::HashSet<Key> visited_from_;
  td::HashSet<Key> visited_to_;

  void dfs_from(Ref<Cell> cell, int merkle_depth) {
    if (!visited_from_.emplace(cell->get_hash(), merkle_depth).second) {
      return;
    }
    CellSlice cs(NoVm(), cell);
    known_cells_.insert(cell->get_hash(merkle_depth));
    if (cs.special_type() == Cell::SpecialType::PrunnedBranch) {
      return;
    }
    int child_merkle_depth = cs.child_merkle_depth(merkle_depth);
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      dfs_from(cs.prefetch_ref(i), child_merkle_depth);
    }
  }

  td::Status dfs_to(Ref<Cell> cell, int merkle_depth) {
    if (!visited_to_.emplace(cell->get_hash(), merkle_depth).second) {
      return td::Status::OK();
    }
    CellSlice cs(NoVm(), cell);
    if (cs.special_type() == Cell::SpecialType::PrunnedBranch) {
      if ((int)cell->get_level() == merkle_depth + 1) {
        if (known_cells_.count(cell->get_hash(merkle_depth)) == 0) {
          return td::Status::Error(PSLICE()
                                   << "Unknown prunned cell (validate): " << cell->get_hash(merkle_depth).to_hex());
        }
      }
      return td::Status::OK();
    }
    int child_merkle_depth = cs.child_merkle_depth(merkle_depth);

    for (unsigned i = 0; i < cs.size_refs(); i++) {
      TRY_STATUS(dfs_to(cs.prefetch_ref(i), child_merkle_depth));
    }
    return td::Status::OK();
  }
};
}  // namespace detail

td::Status MerkleUpdate::may_apply(Ref<Cell> from, Ref<Cell> update) {
  if (update->get_level() != 0 || from->get_level() != 0) {
    return td::Status::Error("Level of update of from is not zero");
  }
  CellSlice cs(NoVm(), std::move(update));
  if (cs.special_type() != Cell::SpecialType::MerkleUpdate) {
    return td::Status::Error("Update cell is not a MerkeUpdate");
  }
  auto update_from = cs.fetch_ref();
  if (from->get_hash(0) != update_from->get_hash(0)) {
    return td::Status::Error("Hash mismatch");
  }
  return td::Status::OK();
}

Ref<Cell> MerkleUpdate::apply(Ref<Cell> from, Ref<Cell> update) {
  if (update->get_level() != 0 || from->get_level() != 0) {
    return {};
  }
  CellSlice cs(NoVm(), std::move(update));
  if (cs.special_type() != Cell::SpecialType::MerkleUpdate) {
    return {};
  }
  auto update_from = cs.fetch_ref();
  auto update_to = cs.fetch_ref();
  return apply_raw(std::move(from), std::move(update_from), std::move(update_to), 0, 0);
}

Ref<Cell> MerkleUpdate::apply_raw(Ref<Cell> from, Ref<Cell> update_from, Ref<Cell> update_to, td::uint32 from_level,
                                  td::uint32 to_level) {
  if (from->get_hash(from_level) != update_from->get_hash(from_level)) {
    LOG(DEBUG) << "invalid Merkle update: expected old value hash = " << update_from->get_hash(from_level).to_hex()
               << ", applied to value with hash = " << from->get_hash(from_level).to_hex();
    return {};
  }
  return detail::MerkleUpdateApply().apply(from, std::move(update_from), std::move(update_to), from_level, to_level);
}

std::pair<Ref<Cell>, Ref<Cell>> MerkleUpdate::generate_raw(Ref<Cell> from, Ref<Cell> to, CellUsageTree *usage_tree) {
  // create Merkle update cell->new_cell
  auto update_to = MerkleProof::generate_raw(to, [tree = usage_tree](const Ref<Cell> &cell) {
    auto loaded_cell = cell->load_cell().move_as_ok();  // FIXME
    if (loaded_cell.data_cell->size_refs() == 0) {
      return false;
    }
    return !loaded_cell.tree_node.empty() && loaded_cell.tree_node.mark_path(tree);
  });
  usage_tree->set_use_mark_for_is_loaded(true);
  auto update_from = MerkleProof::generate_raw(from, usage_tree);

  return {std::move(update_from), std::move(update_to)};
}

td::Status MerkleUpdate::validate_raw(Ref<Cell> update_from, Ref<Cell> update_to, td::uint32 from_level,
                                      td::uint32 to_level) {
  return detail::MerkleUpdateValidator().validate(std::move(update_from), std::move(update_to), from_level, to_level);
}

td::Status MerkleUpdate::validate(Ref<Cell> update) {
  if (update->get_level() != 0) {
    return td::Status::Error("nonzero level");
  }
  CellSlice cs(NoVm(), std::move(update));
  if (cs.special_type() != Cell::SpecialType::MerkleUpdate) {
    return td::Status::Error("not a MerkleUpdate cell");
  }
  auto update_from = cs.fetch_ref();
  auto update_to = cs.fetch_ref();
  return validate_raw(std::move(update_from), std::move(update_to), 0, 0);
}

Ref<Cell> MerkleUpdate::generate(Ref<Cell> from, Ref<Cell> to, CellUsageTree *usage_tree) {
  auto from_level = from->get_level();
  auto to_level = to->get_level();
  if (from_level != 0 || to_level != 0) {
    return {};
  }
  auto res = generate_raw(std::move(from), std::move(to), usage_tree);
  return CellBuilder::create_merkle_update(res.first, res.second);
}

namespace detail {
class MerkleCombine {
 public:
  MerkleCombine(Ref<Cell> AB, Ref<Cell> CD) : AB_(std::move(AB)), CD_(std::move(CD)) {
  }

  td::Result<Ref<Cell>> run() {
    TRY_RESULT(AB, unpack_update(std::move(AB_)));
    TRY_RESULT(CD, unpack_update(std::move(CD_)));
    std::tie(A_, B_) = AB;
    std::tie(C_, D_) = CD;
    if (B_->get_hash(0) != C_->get_hash(0)) {
      return td::Status::Error("Impossible to combine merkle updates");
    }

    auto log = [](td::Slice name, auto cell) {
      CellSlice cs(NoVm(), cell);
      LOG(ERROR) << name << " " << cell->get_level();
      cs.print_rec(std::cerr);
    };
    if (0) {
      log("A", A_);
      log("B", B_);
      log("C", C_);
      log("D", D_);
    }

    // We have four bags of cells. A, B, C and D.
    // X = Virtualize(A), A is subtree (merkle proof) of X
    // Y = Virtualize(B) = Virtualize(C), B and C are  subrees of Y
    // Z = Virtualize(D), D is subtree of Z
    //
    // Prunned cells bounded by merkle proof P are essentially cells which are impossible to load during traversal of Virtualize(P)
    //
    // We want to create new_A and new_D
    // Virtualize(new_A) = X
    // Virtualize(new_D) = Z
    // All prunned branches bounded by new_D must be in new_A
    // i.e. if we have all cells reachable in Virtualize(new_A) we may construct Z from them (and from new_D)
    //
    // Main idea is following
    // 1. Create maximum subtrees of X and Z with all cells in A, B, C and D
    // Max(V) - such maximum subtree
    //
    // 2. Max(A) and Max(D) should be merkle update already. But we want to minimize it
    // So we cut all branches of Max(D) which are in maxA
    // When we cut branch q in Max(D) we mark some path to q in Max(A)
    // Then we cut all branches of Max(A) which are not marked.
    //
    // How to create Max(A)?
    // We just store all cells reachable from A, B, C and D in big cache.
    // It we reach bounded prunned cell during traversion we may continue traversial with a cell from the cache.
    //
    //
    // 1. load_cells(root) - caches all cell reachable in Virtualize(root);
    visited_.clear();
    load_cells(A_, 0);
    visited_.clear();
    load_cells(B_, 0);
    visited_.clear();
    load_cells(C_, 0);
    visited_.clear();
    load_cells(D_, 0);

    // 2. mark_A(A) - Traverse Max(A), but uses all cached cells from step 1. Mark all visited cells
    A_usage_tree_ = std::make_shared<CellUsageTree>();
    mark_A(A_, 0, A_usage_tree_->root_id());

    // 3. create_D(D) - create new_D. Traverse Max(D), and stop at marked cells. Mark path in A to marked cells
    auto new_D = create_D(D_, 0, 0);
    if (new_D.is_null()) {
      return td::Status::Error("Failed to combine updates. One of them is probably an invalid update");
    }

    // 4. create_A(A) - create new_A. Traverse Max(A), and stop at cells not marked at step 3.
    auto new_A = create_A(A_, 0, 0);
    if (0) {
      log("NewD", new_D);
    }

    return CellBuilder::create_merkle_update(new_A, new_D);
  }

 private:
  Ref<Cell> AB_, CD_;
  Ref<Cell> A_, B_, C_, D_;

  std::shared_ptr<CellUsageTree> A_usage_tree_;

  struct Info {
    Ref<Cell> cell_;
    Ref<Cell> prunned_cells_[Cell::max_level];  // Cache prunned cells with different levels to reuse them
    CellUsageTree::NodeId A_node_id{0};

    Ref<Cell> get_prunned_cell(int depth) {
      if (depth < Cell::max_level) {
        return prunned_cells_[depth];
      }
      return {};
    }
    Ref<Cell> get_any_cell() const {
      if (cell_.not_null()) {
        return cell_;
      }
      for (auto &cell : prunned_cells_) {
        if (cell.not_null()) {
          return cell;
        }
      }
      UNREACHABLE();
    }
  };
  using Key = std::pair<Cell::Hash, int>;
  td::HashMap<Cell::Hash, Info> cells_;
  td::HashMap<Key, Ref<Cell>> create_A_res_;
  td::HashMap<Key, Ref<Cell>> create_D_res_;
  td::HashSet<Key> visited_;

  void load_cells(Ref<Cell> cell, int merkle_depth) {
    if (!visited_.emplace(cell->get_hash(), merkle_depth).second) {
      return;
    }

    auto &info = cells_[cell->get_hash(merkle_depth)];
    CellSlice cs(NoVm(), cell);

    // check if prunned cell is bounded
    if (cs.special_type() == Cell::SpecialType::PrunnedBranch && static_cast<int>(cell->get_level()) > merkle_depth) {
      info.prunned_cells_[cell->get_level() - 1] = std::move(cell);
      return;
    }

    info.cell_ = std::move(cell);

    auto child_merkle_depth = cs.child_merkle_depth(merkle_depth);
    for (size_t i = 0, size = cs.size_refs(); i < size; i++) {
      load_cells(cs.fetch_ref(), child_merkle_depth);
    }
  }

  void mark_A(Ref<Cell> cell, int merkle_depth, CellUsageTree::NodeId node_id) {
    CHECK(node_id != 0);

    // cell in cache may be virtualized with different level
    // so we make merkle_depth as small as possible
    merkle_depth = cell->get_level_mask().apply(merkle_depth).get_level();

    auto &info = cells_[cell->get_hash(merkle_depth)];
    if (info.A_node_id != 0) {
      return;
    }
    info.A_node_id = node_id;
    if (info.cell_.is_null()) {
      return;
    }

    CellSlice cs(NoVm(), info.cell_);
    auto child_merkle_depth = cs.child_merkle_depth(merkle_depth);
    for (int i = 0, size = cs.size_refs(); i < size; i++) {
      mark_A(cs.fetch_ref(), child_merkle_depth, A_usage_tree_->create_child(node_id, i));
    }
  }

  Ref<Cell> create_D(Ref<Cell> cell, int merkle_depth, int d_merkle_depth) {
    merkle_depth = cell->get_level_mask().apply(merkle_depth).get_level();
    auto key = Key(cell->get_hash(merkle_depth), d_merkle_depth);
    auto it = create_D_res_.find(key);
    if (it != create_D_res_.end()) {
      return it->second;
    }

    auto res = do_create_D(std::move(cell), merkle_depth, d_merkle_depth);
    if (res.is_null()) {
      return {};
    }
    create_D_res_.emplace(key, res);
    return res;
  }

  Ref<Cell> do_create_D(Ref<Cell> cell, int merkle_depth, int d_merkle_depth) {
    auto &info = cells_[cell->get_hash(merkle_depth)];
    if (info.A_node_id != 0) {
      A_usage_tree_->mark_path(info.A_node_id);
      Ref<Cell> res = info.get_prunned_cell(d_merkle_depth);
      if (res.is_null()) {
        res = CellBuilder::create_pruned_branch(info.get_any_cell(), d_merkle_depth + 1, merkle_depth);
      }
      return res;
    }

    if (info.cell_.is_null()) {
      return {};
    }

    CellSlice cs(NoVm(), info.cell_);

    if (cs.size_refs() == 0) {
      return info.cell_;
    }

    auto child_merkle_depth = cs.child_merkle_depth(merkle_depth);
    auto child_d_merkle_depth = cs.child_merkle_depth(d_merkle_depth);

    CellBuilder cb;
    cb.store_bits(cs.fetch_bits(cs.size()));
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      auto ref = create_D(cs.prefetch_ref(i), child_merkle_depth, child_d_merkle_depth);
      if (ref.is_null()) {
        return {};
      }
      cb.store_ref(std::move(ref));
    }
    return cb.finalize(cs.is_special());
  }

  Ref<Cell> create_A(Ref<Cell> cell, int merkle_depth, int a_merkle_depth) {
    merkle_depth = cell->get_level_mask().apply(merkle_depth).get_level();
    auto key = Key(cell->get_hash(merkle_depth), a_merkle_depth);
    auto it = create_A_res_.find(key);
    if (it != create_A_res_.end()) {
      return it->second;
    }

    auto res = do_create_A(std::move(cell), merkle_depth, a_merkle_depth);
    create_A_res_.emplace(key, res);
    return res;
  }

  Ref<Cell> do_create_A(Ref<Cell> cell, int merkle_depth, int a_merkle_depth) {
    auto &info = cells_[cell->get_hash(merkle_depth)];

    CHECK(info.A_node_id != 0);
    if (!A_usage_tree_->has_mark(info.A_node_id)) {
      Ref<Cell> res = info.get_prunned_cell(a_merkle_depth);
      if (res.is_null()) {
        res = CellBuilder::create_pruned_branch(info.get_any_cell(), a_merkle_depth + 1, merkle_depth);
      }
      return res;
    }

    CHECK(info.cell_.not_null());
    CellSlice cs(NoVm(), info.cell_);

    CHECK(cs.size_refs() != 0);
    if (cs.size_refs() == 0) {
      return info.cell_;
    }

    auto child_merkle_depth = cs.child_merkle_depth(merkle_depth);
    auto child_a_merkle_depth = cs.child_merkle_depth(a_merkle_depth);

    CellBuilder cb;
    cb.store_bits(cs.fetch_bits(cs.size()));
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      cb.store_ref(create_A(cs.prefetch_ref(i), child_merkle_depth, child_a_merkle_depth));
    }
    return cb.finalize(cs.is_special());
  }

  td::Result<std::pair<Ref<Cell>, Ref<Cell>>> unpack_update(Ref<Cell> update) const {
    if (update->get_level() != 0) {
      return td::Status::Error("level is not zero");
    }
    CellSlice cs(NoVm(), std::move(update));
    if (cs.special_type() != Cell::SpecialType::MerkleUpdate) {
      return td::Status::Error("Not a Merkle Update cell");
    }
    auto update_from = cs.fetch_ref();
    auto update_to = cs.fetch_ref();
    return std::make_pair(std::move(update_from), std::move(update_to));
  }
};
}  // namespace detail

Ref<Cell> MerkleUpdate::combine(Ref<Cell> ab, Ref<Cell> bc) {
  detail::MerkleCombine combine(ab, bc);
  auto res = combine.run();
  if (res.is_error()) {
    return {};
  }
  return res.move_as_ok();
}

}  // namespace vm
