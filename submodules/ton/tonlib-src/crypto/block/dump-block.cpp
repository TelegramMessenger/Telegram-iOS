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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "block/block.h"
#include "vm/boc.h"
#include <iostream>
#include "block-db.h"
#include "block-auto.h"
#include "block-parse.h"
#include "mc-config.h"
#include "vm/cp0.h"
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

void throw_err(td::Status err) {
  if (err.is_error()) {
    throw IntError{err.to_string()};
  }
}

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

std::vector<Ref<vm::Cell>> loaded_boc;

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
    std::cout << "ShardIdent.validate() = " << block::tlb::t_ShardIdent.validate_upto(1024, csl) << std::endl;
    csl.print_rec(std::cerr);
    csl.dump(std::cerr, 7);
    std::cout << "ShardIdent.unpack() = " << block::tlb::t_ShardIdent.unpack(csl, shard_id) << std::endl;
    if (shard_id.is_valid()) {
      std::cout << "shard_pfx_bits:" << shard_id.shard_pfx_bits << " workchain_id:" << shard_id.workchain_id
                << " shard_prefix:" << shard_id.shard_prefix << std::endl;
    }
  }
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip_upto(1024, csl) << std::endl;
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip_upto(1024, csl) << std::endl;
  std::cout << "ShardIdent.skip_validate() = " << block::tlb::t_ShardIdent.validate_skip_upto(1024, csl) << std::endl;
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
  std::cout << "Grams.validate(cs) = " << block::tlb::t_Grams.validate_upto(1024, *cs) << std::endl;
  std::cout << "Grams.validate(cs2) = " << block::tlb::t_Grams.validate_upto(1024, *cs2) << std::endl;
  //
  block::gen::SplitMergeInfo::Record data;
  block::gen::Grams::Record data2;
  std::cout << "block::gen::Grams.validate(cs) = " << block::gen::t_Grams.validate_upto(1024, *cs) << std::endl;
  std::cout << "block::gen::Grams.validate(cs2) = " << block::gen::t_Grams.validate_upto(1024, *cs2) << std::endl;
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
  std::cout << "Bool.validate() = " << block::tlb::t_Bool.validate_upto(1024, cs) << std::endl;
  std::cout << "UInt16.validate() = " << block::tlb::t_uint16.validate_upto(1024, cs) << std::endl;
  std::cout << "HashmapE(32,UInt16).validate() = "
            << block::tlb::HashmapE(32, block::tlb::t_uint16).validate_upto(1024, cs) << std::endl;
  std::cout << "block::gen::HashmapE(32,UInt16).validate() = "
            << block::gen::HashmapE{32, block::gen::t_uint16}.validate_upto(1024, cs) << std::endl;
}

td::Status test_vset() {
  if (loaded_boc.size() != 2) {
    return td::Status::Error(
        "must have exactly two boc files (with a masterchain Block and with ConfigParams) for vset compute test");
  }
  std::cerr << "running test_vset()\n";
  TRY_RESULT(config, block::Config::unpack_config(vm::load_cell_slice_ref(loaded_boc[1])));
  std::cerr << "config unpacked\n";
  auto cv_root = config->get_config_param(34);
  if (cv_root.is_null()) {
    return td::Status::Error("no config parameter 34");
  }
  std::cerr << "config param #34 obtained\n";
  TRY_RESULT(cur_validators, block::Config::unpack_validator_set(std::move(cv_root)));
  // auto vconf = config->get_catchain_validators_config();
  std::cerr << "validator set unpacked\n";
  std::cerr << "unpacking ShardHashes\n";
  block::ShardConfig shards;
  if (!shards.unpack(vm::load_cell_slice_ref(loaded_boc[0]))) {
    return td::Status::Error("cannot unpack ShardConfig");
  }
  std::cerr << "ShardHashes initialized\n";
  ton::ShardIdFull shard{0, 0x6e80000000000000};
  ton::CatchainSeqno cc_seqno = std::max(48763, 48763) + 1 + 1;
  ton::UnixTime now = 1586169666;
  cc_seqno = shards.get_shard_cc_seqno(shard);
  std::cerr << "shard=" << shard.to_str() << " cc_seqno=" << cc_seqno << " time=" << now << std::endl;
  if (cc_seqno == ~0U) {
    return td::Status::Error("cannot compute cc_seqno for shard "s + shard.to_str());
  }
  auto nodes = config->compute_validator_set(shard, *cur_validators, now, cc_seqno);
  if (nodes.empty()) {
    return td::Status::Error(PSTRING() << "compute_validator_set() for " << shard.to_str() << "," << now << ","
                                       << cc_seqno << " returned empty list");
  }
  for (auto& x : nodes) {
    std::cout << "weight=" << x.weight << " key=" << x.key.as_bits256().to_hex() << " addr=" << x.addr.to_hex()
              << std::endl;
  }
  // ...
  return td::Status::OK();
}

void usage() {
  std::cout << "usage: dump-block [-t<typename>][-S][<boc-file>]\n\tor dump-block -h\n\tDumps specified blockchain "
               "block or state "
               "from <boc-file>, or runs some tests\n\t-S\tDump a blockchain state instead of a block\n";
  std::exit(2);
}

int main(int argc, char* const argv[]) {
  int i;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  const char* tname = nullptr;
  const tlb::TLB* type = &block::gen::t_Block;
  bool vset_compute_test = false;
  bool store_loaded = false;
  int dump = 3;
  auto zerostate = std::make_unique<block::ZerostateInfo>();
  while ((i = getopt(argc, argv, "CSt:hqv:")) != -1) {
    switch (i) {
      case 'C':
        type = &block::gen::t_VmCont;
        break;
      case 'S':
        type = &block::gen::t_ShardStateUnsplit;
        break;
      case 't':
        tname = optarg;
        type = nullptr;
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + (verbosity = td::to_integer<int>(td::Slice(optarg)));
        break;
      case 'q':
        type = &block::gen::t_ShardHashes;
        vset_compute_test = true;
        store_loaded = true;
        dump = 0;
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
    int loaded = 0;
    while (optind < argc) {
      auto boc = load_boc(argv[optind++]);
      if (boc.is_null()) {
        std::cerr << "(invalid boc in file" << argv[optind - 1] << ")" << std::endl;
        std::exit(2);
      } else {
        if (store_loaded) {
          loaded_boc.push_back(boc);
        }
        ++loaded;
        if (dump & 1) {
          vm::CellSlice cs{vm::NoVm(), boc};
          cs.print_rec(std::cout);
          std::cout << std::endl;
        }
        if (!type) {
          tlb::TypenameLookup dict(block::gen::register_simple_types);
          type = dict.lookup(tname);
          if (!type) {
            std::cerr << "unknown TL-B type " << tname << std::endl;
            std::exit(3);
          }
        }
        if (dump & 2) {
          type->print_ref(std::cout, boc);
          std::cout << std::endl;
        }
        bool ok = type->validate_ref(1048576, boc);
        std::cout << "(" << (ok ? "" : "in") << "valid " << *type << ")" << std::endl;
        if (vset_compute_test) {
          if (!ok || loaded > 2) {
            std::cerr << "fatal: validity check failed\n";
            exit(3);
          }
          type = &block::gen::t_ConfigParams;
        }
      }
    }
    if (vset_compute_test) {
      throw_err(test_vset());
    } else if (!loaded) {
      test1();
    }
  } catch (IntError& err) {
    std::cerr << "internal error: " << err.err_msg << std::endl;
    return 1;
  } catch (vm::VmError& err) {
    std::cerr << "vm error: " << err.get_msg() << std::endl;
    return 1;
  }
  return 0;
}
