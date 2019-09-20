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
#include <getopt.h>

using td::Ref;

int verbosity;

struct IntError {
  std::string err_msg;
  IntError(std::string _msg) : err_msg(_msg) {
  }
  IntError(const char* _msg) : err_msg(_msg) {
  }
};

td::Ref<vm::Cell> load_boc(std::string filename) {
  std::cerr << "loading bag-of-cell file " << filename << std::endl;
  auto bytes_res = block::load_binary_file(filename);
  if (bytes_res.is_error()) {
    throw IntError{PSTRING() << "cannot load file `" << filename << "` : " << bytes_res.move_as_error()};
  }
  vm::BagOfCells boc;
  auto res = boc.deserialize(bytes_res.move_as_ok());
  if (res.is_error()) {
    throw IntError{PSTRING() << "cannot deserialize bag-of-cells " << res.move_as_error()};
  }
  if (res.move_as_ok() <= 0 || boc.get_root_cell().is_null()) {
    throw IntError{"cannot deserialize bag-of-cells "};
  }
  return boc.get_root_cell();
}

void test1() {
  block::ShardId id{ton::masterchainId}, id2{ton::basechainId, 0x11efULL << 48};
  std::cout << '[' << id << "][" << id2 << ']' << std::endl;
  vm::CellBuilder cb;
  cb << id << id2;
  std::cout << "ShardIdent.pack() = " << block::tlb::t_ShardIdent.pack(cb, {12, 3, 0x3aeULL << 52}) << std::endl;
  std::cout << cb << std::endl;
  auto cref = cb.finalize();
  td::Ref<vm::CellSlice> cs{true, cref}, cs2;
  block::ShardId id3{cs.write()}, id4, id5;
  cs >> id4 >> id5;
  std::cout << '[' << id3 << "][" << id4 << "][" << id5 << ']' << std::endl;
  vm::CellSlice csl{std::move(cref)};
  std::cout << "ShardIdent.get_size() = " << block::tlb::t_ShardIdent.get_size(csl) << std::endl;
  std::cout << "MsgAddress.get_size() = " << block::tlb::t_MsgAddress.get_size(csl) << std::endl;
  std::cout << "Grams.get_size() = " << block::tlb::t_Grams.get_size(csl) << std::endl;
  std::cout << "Grams.as_integer() = " << block::tlb::t_Grams.as_integer(csl) << std::endl;
  (csl + 8).print_rec(std::cout);
  std::cout << "Grams.get_size() = " << block::tlb::t_Grams.get_size(csl + 8) << std::endl;
  std::cout << "Grams.as_integer() = " << block::tlb::t_Grams.as_integer(csl + 8) << std::endl;

  vm::CellSlice csl2{csl};
  block::gen::ShardIdent::Record sh_id;
  for (int i = 0; i < 3; i++) {
    std::cout << csl2 << std::endl;
    bool ok = tlb::unpack(csl2, sh_id);
    std::cout << "block::gen::ShardIdent.unpack() = " << ok << std::endl;
    if (ok) {
      std::cout << "  (shard_ident shard_pfx_bits:" << sh_id.shard_pfx_bits << " workchain_id:" << sh_id.workchain_id
                << " shard_prefix:" << std::hex << sh_id.shard_prefix << std::dec << ")" << std::endl;
    }
  }

  block::tlb::ShardIdent::Record shard_id;
  for (int i = 0; i < 3; i++) {
    std::cout << "ShardIdent.validate() = " << block::tlb::t_ShardIdent.validate(csl) << std::endl;
    csl.print_rec(std::cerr);
    csl.dump(std::cerr, 7);
    std::cout << "ShardIdent.unpack() = " << block::tlb::t_ShardIdent.unpack(csl, shard_id) << std::endl;
    if (shard_id.is_valid()) {
      std::cout << "shard_pfx_bits:" << shard_id.shard_pfx_bits << " workchain_id:" << shard_id.workchain_id
                << " shard_prefix:" << shard_id.shard_prefix << std::endl;
    }
  }
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip(csl) << std::endl;
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip(csl) << std::endl;
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip(csl) << std::endl;
  using namespace td::literals;
  std::cout << "Grams.store_intval(239) = " << block::tlb::t_Grams.store_integer_value(cb, "239"_i256) << std::endl;
  std::cout << "Grams.store_intval(17239) = " << block::tlb::t_Grams.store_integer_value(cb, "17239"_i256) << std::endl;
  std::cout << "Grams.store_intval(-17) = " << block::tlb::t_Grams.store_integer_value(cb, "-17"_i256) << std::endl;
  std::cout << "Grams.store_intval(0) = " << block::tlb::t_Grams.store_integer_value(cb, "0"_i256) << std::endl;
  std::cout << cb << std::endl;
  cs = td::Ref<vm::CellSlice>{true, cb.finalize()};
  std::cout << "Grams.store_intval(666) = " << block::tlb::t_Grams.store_integer_value(cb, "666"_i256) << std::endl;
  std::cout << cb << std::endl;
  cs2 = td::Ref<vm::CellSlice>{true, cb.finalize()};
  std::cout << "Grams.validate(cs) = " << block::tlb::t_Grams.validate(*cs) << std::endl;
  std::cout << "Grams.validate(cs2) = " << block::tlb::t_Grams.validate(*cs2) << std::endl;
  //
  block::gen::SplitMergeInfo::Record data;
  block::gen::Grams::Record data2;
  std::cout << "block::gen::Grams.validate(cs) = " << block::gen::t_Grams.validate(*cs) << std::endl;
  std::cout << "block::gen::Grams.validate(cs2) = " << block::gen::t_Grams.validate(*cs2) << std::endl;
  std::cout << "[cs = " << cs << "]" << std::endl;
  bool ok = tlb::csr_unpack_inexact(cs, data);
  std::cout << "block::gen::SplitMergeInfo.unpack(cs, data) = " << ok << std::endl;
  if (ok) {
    std::cout << "  cur_shard_pfx_len = " << data.cur_shard_pfx_len << "; acc_split_depth = " << data.acc_split_depth
              << "; this_addr = " << data.this_addr << "; sibling_addr = " << data.sibling_addr << std::endl;
  }
  ok = tlb::csr_unpack_inexact(cs, data2);
  std::cout << "block::gen::Grams.unpack(cs, data2) = " << ok << std::endl;
  if (ok) {
    std::cout << "  amount = " << data2.amount << std::endl;
    block::gen::VarUInteger::Record data3;
    ok = tlb::csr_type_unpack(data2.amount, block::gen::t_VarUInteger_16, data3);
    std::cout << "  block::gen::VarUInteger16.unpack(amount, data3) = " << ok << std::endl;
    if (ok) {
      std::cout << "    len = " << data3.len << "; value = " << data3.value << std::endl;
      vm::CellBuilder cb;
      std::cout << "    block::gen::VarUInteger16.pack(cb, data3) = "
                << tlb::type_pack(cb, block::gen::t_VarUInteger_16, data3) << std::endl;
      std::cout << "    cb = " << cb.finalize() << std::endl;
    }
  }
  /* 
  {
    vm::CellBuilder cb;
    td::BitArray<256> hash;
    std::memset(hash.data(), 0x69, 32);
    bool ok = tlb::pack(
        cb, block::gen::Test::Record{1000000000000, {170239, -888, {239017, "1000000000000000000"_ri256}, hash}, 17});
    std::cout << "  block::gen::Test::pack(cb, {1000000000000, ...}) = " << ok << std::endl;
    std::cout << "  cb = " << cb << std::endl;
    auto cell = cb.finalize();
    vm::CellSlice cs{cell};
    cs.print_rec(std::cout);
    block::gen::Test::Record data;
    std::cout << "  block::gen::Test::validate_ref(cell) = " << block::gen::t_Test.validate_ref(cell) << std::endl;
    ok = tlb::unpack(cs, data);
    std::cout << "  block::gen::Test::unpack(cs, data) = " << ok << std::endl;
    if (ok) {
      std::cout << "a:" << data.a << " b:" << data.r1.b << " c:" << data.r1.c << " d:" << data.r1.r1.d
                << " e:" << data.r1.r1.e << " f:" << data.r1.f << " g:" << data.g << std::endl;
    }
    std::cout << "  block::gen::Test::print_ref(cell) = ";
    block::gen::t_Test.print_ref(std::cout, cell, 2);
    block::gen::t_CurrencyCollection.print_ref(std::cout, cell, 2);
    std::cout << std::endl;
  }
  */
  std::cout << "Grams.add_values() = " << block::tlb::t_Grams.add_values(cb, cs.write(), cs2.write()) << std::endl;
  std::cout << cb << std::endl;
  std::cout << "block::gen::t_HashmapAug_64_...print_type() = "
            << block::gen::t_HashmapAug_64_Ref_Transaction_CurrencyCollection << std::endl;
}

void test2(vm::CellSlice& cs) {
  std::cout << "Bool.validate() = " << block::tlb::t_Bool.validate(cs) << std::endl;
  std::cout << "UInt16.validate() = " << block::tlb::t_uint16.validate(cs) << std::endl;
  std::cout << "HashmapE(32,UInt16).validate() = " << block::tlb::HashmapE(32, block::tlb::t_uint16).validate(cs)
            << std::endl;
  std::cout << "block::gen::HashmapE(32,UInt16).validate() = "
            << block::gen::HashmapE{32, block::gen::t_uint16}.validate(cs) << std::endl;
}

void usage() {
  std::cout << "usage: test-block [-S][<boc-file>]\n\tor test-block -h\n\tDumps specified blockchain block or state "
               "from <boc-file>, or runs some tests\n\t-S\tDump a blockchain state\n";
  std::exit(2);
}

int main(int argc, char* const argv[]) {
  int i;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  bool dump_state = false;
  auto zerostate = std::make_unique<block::ZerostateInfo>();
  while ((i = getopt(argc, argv, "Shv:")) != -1) {
    switch (i) {
      case 'S':
        dump_state = true;
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + (verbosity = td::to_integer<int>(td::Slice(optarg)));
        break;
      case 'h':
        usage();
        std::exit(2);
      default:
        usage();
        std::exit(2);
    }
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);
  try {
    bool done = false;
    while (optind < argc) {
      auto boc = load_boc(argv[optind++]);
      if (boc.is_null()) {
        std::cerr << "(invalid boc)" << std::endl;
        std::exit(2);
      } else {
        done = true;
        vm::CellSlice cs{vm::NoVm(), boc};
        cs.print_rec(std::cout);
        std::cout << std::endl;
        auto& type = dump_state ? (const tlb::TLB&)block::gen::t_ShardStateUnsplit : block::gen::t_Block;
        std::string type_name = dump_state ? "ShardState" : "Block";
        type.print_ref(std::cout, boc);
        std::cout << std::endl;
        bool ok = type.validate_ref(boc);
        std::cout << "(" << (ok ? "" : "in") << "valid " << type_name << ")" << std::endl;
      }
    }
    if (!done) {
      test1();
    }
  } catch (IntError& err) {
    std::cerr << "caught internal error " << err.err_msg << std::endl;
    return 1;
  } catch (vm::VmError& err) {
    std::cerr << "caught vm error " << err.get_msg() << std::endl;
    return 1;
  }
  return 0;
}
