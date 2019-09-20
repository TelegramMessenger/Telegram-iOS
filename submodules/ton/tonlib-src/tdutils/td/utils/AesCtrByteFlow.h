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

#include "td/utils/ByteFlow.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

namespace td {

#if TD_HAVE_OPENSSL
class AesCtrByteFlow : public ByteFlowInplaceBase {
 public:
  void init(const UInt256 &key, const UInt128 &iv) {
    state_.init(key, iv);
  }
  void init(AesCtrState &&state) {
    state_ = std::move(state);
  }
  AesCtrState move_aes_ctr_state() {
    return std::move(state_);
  }
  void loop() override {
    bool was_updated = false;
    while (true) {
      auto ready = input_->prepare_read();
      if (ready.empty()) {
        break;
      }
      state_.encrypt(ready, MutableSlice(const_cast<char *>(ready.data()), ready.size()));
      input_->confirm_read(ready.size());
      output_.advance_end(ready.size());
      was_updated = true;
    }
    if (was_updated) {
      on_output_updated();
    }
    if (!is_input_active_) {
      finish(Status::OK());  // End of input stream.
    }
    set_need_size(1);
  }

 private:
  AesCtrState state_;
};
#endif

}  // namespace td
