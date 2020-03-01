/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "block/block.h"
#include "vm/boc.h"
#include <iostream>
#include "block-db.h"
#include "block-auto.h"
#include "block-parse.h"
#include "vm/cp0.h"
#include "td/utils/crypto.h"
#include <getopt.h>

using td::Ref;
using namespace std::literals::string_literals;

int verbosity;

struct IntError {
  std::string err_msg;
  IntError(std::string _msg) : err_msg(_msg) {
  }
  IntError(const char* _msg) : err_msg(_msg) {
  }
};

int fatal(std::string str) {
  std::cerr << "fatal error: " << str << std::endl;
  std::exit(2);
  return 2;
}

static inline void fail_unless(td::Status res) {
  if (res.is_error()) {
    throw IntError{res.to_string()};
  }
}

td::Ref<vm::Cell> load_block(std::string filename, ton::BlockIdExt& id) {
  std::cerr << "loading block from bag-of-cell file " << filename << std::endl;
  auto bytes_res = block::load_binary_file(filename);
  if (bytes_res.is_error()) {
    throw IntError{PSTRING() << "cannot load file `" << filename << "` : " << bytes_res.move_as_error()};
  }
  ton::FileHash fhash;
  td::sha256(bytes_res.ok(), fhash.as_slice());
  vm::BagOfCells boc;
  auto res = boc.deserialize(bytes_res.move_as_ok());
  if (res.is_error()) {
    throw IntError{PSTRING() << "cannot deserialize bag-of-cells " << res.move_as_error()};
  }
  if (res.move_as_ok() <= 0 || boc.get_root_cell().is_null()) {
    throw IntError{"cannot deserialize bag-of-cells"};
  }
  auto root = boc.get_root_cell();
  std::vector<ton::BlockIdExt> prev;
  ton::BlockIdExt mc_blkid;
  bool after_split;
  fail_unless(block::unpack_block_prev_blk_try(root, id, prev, mc_blkid, after_split, &id));
  id.file_hash = fhash;
  std::cerr << "loaded block " << id.to_str() << std::endl;
  return root;
}

bool save_block(std::string filename, Ref<vm::Cell> root, ton::BlockIdExt& id) {
  std::cerr << "saving block into bag-of-cell file " << filename << std::endl;
  if (root.is_null()) {
    throw IntError{"new block has no root"};
  }
  id.root_hash = root->get_hash().bits();
  auto res = vm::std_boc_serialize(std::move(root), 31);
  if (res.is_error()) {
    throw IntError{PSTRING() << "cannot serialize modified block as a bag-of-cells: "
                             << res.move_as_error().to_string()};
  }
  auto data = res.move_as_ok();
  td::sha256(data, id.file_hash.as_slice());
  auto res1 = block::save_binary_file(filename, std::move(data));
  if (res1.is_error()) {
    throw IntError{PSTRING() << "cannot save file `" << filename << "` : " << res1};
  }
  return true;
}

Ref<vm::Cell> adjust_block(Ref<vm::Cell> root, int vseqno_incr, const ton::BlockIdExt& id) {
  std::vector<ton::BlockIdExt> prev;
  ton::BlockIdExt mc_blkid;
  bool after_split;
  fail_unless(block::unpack_block_prev_blk_try(root, id, prev, mc_blkid, after_split));
  std::cerr << "unpacked header of block " << id.to_str() << std::endl;
  if (!id.is_masterchain()) {
    throw IntError{"can modify only masterchain blocks"};
  }
  block::gen::Block::Record blk;
  block::gen::BlockInfo::Record info;
  if (!(tlb::unpack_cell(root, blk) && tlb::unpack_cell(blk.info, info))) {
    throw IntError{"cannot unpack block header"};
  }
  if (!info.key_block) {
    throw IntError{"can modify only key blocks"};
  }
  info.vert_seqno_incr = true;
  info.vert_seq_no += vseqno_incr;
  if (!block::tlb::t_ExtBlkRef.pack_to(info.prev_vert_ref, id, info.end_lt)) {
    throw IntError{"cannot pack prev_vert_ref"};
  }
  if (!(tlb::pack_cell(blk.info, info) && tlb::pack_cell(root, blk))) {
    throw IntError{"cannot pack block header"};
  }
  return root;
}

void usage() {
  std::cout << "usage: adjust-block [-i<vs-incr>] <in-boc-file> <out-boc-file>\n\tor adjust-block -h\n\tAdjusts block "
               "loaded from <in-boc-file> by incrementing vert_seqno by <vs-incr> (1 by default)\n";
  std::exit(3);
}

int main(int argc, char* const argv[]) {
  int i, vseqno_incr = 1;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  std::string in_fname, out_fname;
  while ((i = getopt(argc, argv, "hi:v:")) != -1) {
    switch (i) {
      case 'h':
        usage();
        break;
      case 'i':
        vseqno_incr = td::to_integer<int>(td::Slice(optarg));
        CHECK(vseqno_incr > 0 && vseqno_incr < 1000);
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + (verbosity = td::to_integer<int>(td::Slice(optarg)));
        break;
      default:
        usage();
        break;
    }
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);
  if (argc != optind + 2) {
    usage();
    return 2;
  }
  in_fname = argv[optind];
  out_fname = argv[optind + 1];
  try {
    ton::BlockIdExt old_id, new_id;
    auto root = load_block(in_fname, old_id);
    if (root.is_null()) {
      return fatal("cannot load BoC from file "s + in_fname);
    }
    bool ok = block::gen::t_Block.validate_ref(root);
    if (!ok) {
      return fatal("file `"s + in_fname + " does not contain a valid block");
    }
    auto adjusted = adjust_block(root, vseqno_incr, old_id);
    if (adjusted.is_null()) {
      return fatal("cannot adjust block");
    }
    ok = block::gen::t_Block.validate_ref(root);
    if (!ok) {
      return fatal("modified block is not valid");
    }
    new_id = old_id;
    if (!save_block(out_fname, adjusted, new_id)) {
      return fatal("cannot save modified block to file `"s + out_fname + "`");
    }
    std::cout << "old block id: " << old_id.to_str() << std::endl;
    std::cout << "new block id: " << new_id.to_str() << std::endl;
  } catch (IntError& err) {
    std::cerr << "internal error: " << err.err_msg << std::endl;
    return 1;
  } catch (vm::VmError& err) {
    std::cerr << "vm error: " << err.get_msg() << std::endl;
    return 1;
  }
  return 0;
}
