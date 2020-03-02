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
#include "vm/cells.h"

#include "td/utils/Span.h"

namespace ton {
class SmartContractCode {
 public:
  static td::Result<td::Ref<vm::Cell>> load(td::Slice name);

  enum Type { WalletV1 = 1, WalletV1Ext, WalletV2, WalletV3, HighloadWalletV1, HighloadWalletV2, ManualDns, Multisig };
  static td::Span<int> get_revisions(Type type);
  static td::Result<int> validate_revision(Type type, int revision);
  static td::Ref<vm::Cell> get_code(Type type, int revision = 0);
};
}  // namespace ton
