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
#include "tonlib/GenericAccount.h"
#include "tonlib/utils.h"
#include "block/block-auto.h"
namespace tonlib {
td::Ref<vm::Cell> GenericAccount::get_init_state(td::Ref<vm::Cell> code, td::Ref<vm::Cell> data) {
  return vm::CellBuilder()
      .append_cellslice(binary_bitstring_to_cellslice("b{00110}").move_as_ok())
      .store_ref(std::move(code))
      .store_ref(std::move(data))
      .finalize();
}
block::StdAddress GenericAccount::get_address(ton::WorkchainId workchain_id, const td::Ref<vm::Cell>& init_state) {
  return block::StdAddress(workchain_id, init_state->get_hash().bits(), false);
}
td::Ref<vm::Cell> GenericAccount::create_ext_message(const block::StdAddress& address, td::Ref<vm::Cell> new_state,
                                                     td::Ref<vm::Cell> body) {
  block::gen::Message::Record message;
  /*info*/ {
    block::gen::CommonMsgInfo::Record_ext_in_msg_info info;
    /* src */
    tlb::csr_pack(info.src, block::gen::MsgAddressExt::Record_addr_none{});
    /* dest */ {
      block::gen::MsgAddressInt::Record_addr_std dest;
      dest.anycast = vm::CellBuilder().store_zeroes(1).as_cellslice_ref();
      dest.workchain_id = address.workchain;
      dest.address = address.addr;

      tlb::csr_pack(info.dest, dest);
    }
    /* import_fee */ {
      vm::CellBuilder cb;
      block::tlb::t_Grams.store_integer_value(cb, td::BigInt256(0));
      info.import_fee = cb.as_cellslice_ref();
    }

    tlb::csr_pack(message.info, info);
  }
  /* init */ {
    if (new_state.not_null()) {
      // Just(Left(new_state))
      message.init = vm::CellBuilder()
                         .store_ones(1)
                         .store_zeroes(1)
                         .append_cellslice(vm::load_cell_slice(new_state))
                         .as_cellslice_ref();
    } else {
      message.init = vm::CellBuilder().store_zeroes(1).as_cellslice_ref();
      CHECK(message.init.not_null());
    }
  }
  /* body */ {
    message.body = vm::CellBuilder().store_zeroes(1).append_cellslice(vm::load_cell_slice_ref(body)).as_cellslice_ref();
  }

  td::Ref<vm::Cell> res;
  tlb::type_pack_cell(res, block::gen::t_Message_Any, message);
  CHECK(res.not_null());

  return res;
}
}  // namespace tonlib
