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

#include <ostream>
#include "common/refcnt.hpp"
#include "common/bitstring.h"
#include "common/bigint.hpp"
#include "common/refint.h"

#include "vm/cells/Cell.h"
#include "vm/cells/CellBuilder.h"
#include "vm/cells/DataCell.h"
#include "vm/cells/UsageCell.h"
#include "vm/cells/VirtualCell.h"

#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "openssl/digest.h"

// H_i(cell) = H(cell_i)
// cell.hash = sha256(
//   d1, d2,
//   (level == 0 || special_type == PrunnedBranch) ? data : cell_(level - 1).hash,
//   for child in refs:
//     child.depth, child.hash
// )
// lower hashes of Prunned branch are calculated from its data
// cell_i.ref[j] = (special_type == MerkleProof || special_type == MerkleUpdate) ? cell.ref[j]_(i+1) : cell.ref[j]_i
//
// Ordinary cell:
// cell_i.data = cell.data
// cell_i.level_mask = cell.level_mask & ((1<<i) - 1)
// (cell_i.level_mask = == BinaryOr(cell_i.ref[j].level_mask))
// cell_i.level = 32 - count_leading_zeroes32(cell_i.level_mask)
// cell_i.depth = if cell_i.has_ref then max(cell_i.ref[j].depth) + 1 else 0
// cell_i.ref[j] = cell.ref[j]
//
//
// Prunned branch
// cell.level_mask = prunned_cell.level_mask + (1 << (cell.level + 1))
// cell.level = <default> == cell.level + 1
// cell_i = if i < cell.level then prunned_cell_i
// prunned_cell.data = EXCEPTION
// prunned_cell_i.hash = <from cell.data>
// prunned_cell.level_mask = cell.level_mask ^ (1 << cell.level)
// prunned_cell.level = <default>
// prunned_cell_i.depth = <from cell.data>
//
// Merkle proof
// cell.level_mask = proof_cell.level_mask >> 1
// cell.level = <default> == max(0, proof.cell.level - 1)
// cell_i.data = <default>
// cell_i.level_mask = <default>
// cell_i.ref[j] = cell.ref[j]_(i+1)
// cell_i.depth = max_j(1 + cell_i.ref[j].depth)

