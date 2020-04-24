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

#pragma once

#include "td/utils/Status.h"
#include "common/errorcode.h"
// NEED_MNEMONIC_PASSWORD
// KEY_UNKNOWN
// KEY_DECRYPT
// INVALID_MNEMONIC
// INVALID_BAG_OF_CELLS
// INVALID_PUBLIC_KEY
// INVALID_QUERY_ID
// INVALID_SMC_ID
// INVALID_ACCOUNT_ADDRESS
// INVALID_CONFIG
// INVALID_PEM_KEY
// INVALID_SIGNATURE
// MESSAGE_TOO_LONG
// EMPTY_FIELD
// INVALID_FIELD
// DANGEROUS_TRANSACTION
// ACCOUNT_NOT_INITED
// ACCOUNT_TYPE_UNKNOWN
// ACCOUNT_TYPE_UNEXPECTED
// ACCOUNT_ACTION_UNSUPPORTED
// VALIDATE_ACCOUNT_STATE
// VALIDATE_TRANSACTION
// VALIDATE_ZERO_STATE
// VALIDATE_BLOCK_PROOF
// NO_LITE_SERVERS
// LITE_SERVER_NETWORK
// CANCELLED
// NOT_ENOUGH_FUNDS
// LITE_SERVER
// INTERNAL

namespace tonlib {
struct TonlibError {
  static td::Status NeedMnemonicPassword() {
    return td::Status::Error(400, "NEED_MNEMONIC_PASSWORD");
  }
  static td::Status InvalidMnemonic() {
    return td::Status::Error(400, "INVALID_MNEMONIC: Invalid mnemonic words or password (invalid checksum)");
  }
  static td::Status InvalidBagOfCells(td::Slice comment) {
    return td::Status::Error(400, PSLICE() << "INVALID_BAG_OF_CELLS: " << comment);
  }
  static td::Status InvalidPublicKey() {
    return td::Status::Error(400, "INVALID_PUBLIC_KEY");
  }
  static td::Status InvalidAccountAddress() {
    return td::Status::Error(400, "INVALID_ACCOUNT_ADDRESS");
  }
  static td::Status InvalidQueryId() {
    return td::Status::Error(400, "INVALID_QUERY_ID");
  }
  static td::Status InvalidSmcId() {
    return td::Status::Error(400, "INVALID_SMC_ID");
  }
  static td::Status InvalidConfig(td::Slice reason) {
    return td::Status::Error(400, PSLICE() << "INVALID_CONFIG: " << reason);
  }
  static td::Status InvalidPemKey() {
    return td::Status::Error(400, "INVALID_PEM_KEY");
  }
  static td::Status InvalidRevision() {
    return td::Status::Error(400, "INVALID_REVISION");
  }
  static td::Status InvalidSignature() {
    return td::Status::Error(400, "INVALID_SIGNATURE");
  }
  static td::Status NeedConfig() {
    return td::Status::Error(400, "NeedConfig");
  }
  static td::Status MessageTooLong() {
    return td::Status::Error(400, "MESSAGE_TOO_LONG");
  }
  static td::Status EmptyField(td::Slice field_name) {
    return td::Status::Error(400, PSLICE() << "EMPTY_FIELD: Field " << field_name << " must not be empty");
  }
  static td::Status InvalidField(td::Slice field_name, td::Slice reason) {
    return td::Status::Error(400, PSLICE() << "INVALID_FIELD: Field " << field_name << " has invalid value " << reason);
  }
  static td::Status DangerousTransaction(td::Slice reason) {
    return td::Status::Error(400, PSLICE() << "DANGEROUS_TRANSACTION: " << reason);
  }
  static td::Status MessageEncryption(td::Slice reason) {
    return td::Status::Error(400, PSLICE() << "MESSAGE_ENCRYPTION: " << reason);
  }
  static td::Status AccountNotInited() {
    return td::Status::Error(400, "ACCOUNT_NOT_INITED");
  }
  static td::Status AccountTypeUnknown() {
    return td::Status::Error(400, "ACCOUNT_TYPE_UNKNOWN");
  }
  static td::Status AccountTypeUnexpected(td::Slice expected) {
    return td::Status::Error(400, PSLICE() << "ACCOUNT_TYPE_UNEXPECTED: not a " << expected);
  }
  static td::Status AccountActionUnsupported(td::Slice action) {
    return td::Status::Error(400, PSLICE() << "ACCOUNT_ACTION_UNSUPPORTED: " << action);
  }
  static td::Status Internal() {
    return td::Status::Error(500, "INTERNAL");
  }
  static td::Status Internal(td::Slice message) {
    return td::Status::Error(500, PSLICE() << "INTERNAL: " << message);
  }
  static td::Status KeyUnknown() {
    return td::Status::Error(500, "KEY_UNKNOWN");
  }
  static td::Status KeyDecrypt() {
    return td::Status::Error(500, "KEY_DECRYPT");
  }
  static td::Status ValidateAccountState() {
    return td::Status::Error(500, "VALIDATE_ACCOUNT_STATE");
  }
  static td::Status ValidateTransactions() {
    return td::Status::Error(500, "VALIDATE_TRANSACTION");
  }
  static td::Status ValidateConfig() {
    return td::Status::Error(500, "VALIDATE_CONFIG");
  }
  static td::Status ValidateZeroState(td::Slice message) {
    return td::Status::Error(500, PSLICE() << "VALIDATE_ZERO_STATE: " << message);
  }
  static td::Status ValidateBlockProof() {
    return td::Status::Error(500, "VALIDATE_BLOCK_PROOF");
  }
  static td::Status NoLiteServers() {
    return td::Status::Error(500, "NO_LITE_SERVERS");
  }
  static td::Status LiteServerNetwork() {
    return td::Status::Error(500, "LITE_SERVER_NETWORK");
  }
  static td::Status Cancelled() {
    return td::Status::Error(500, "CANCELLED");
  }
  static td::Status NotEnoughFunds() {
    return td::Status::Error(500, "NOT_ENOUGH_FUNDS");
  }
  static td::Status TransferToFrozen() {
    return td::Status::Error(500, "TRANSFER_TO_FROZEN");
  }

  static td::Status LiteServer(td::int32 code, td::Slice message) {
    auto f = [&](td::Slice code_description) { return LiteServer(code, code_description, message); };
    switch (ton::ErrorCode(code)) {
      case ton::ErrorCode::cancelled:
        return f("CANCELLED");
      case ton::ErrorCode::failure:
        return f("FAILURE");
      case ton::ErrorCode::error:
        return f("ERROR");
      case ton::ErrorCode::warning:
        return f("WARNING");
      case ton::ErrorCode::protoviolation:
        return f("PROTOVIOLATION");
      case ton::ErrorCode::timeout:
        return f("TIMEOUT");
      case ton::ErrorCode::notready:
        return f("NOTREADY");
    }
    return f("UNKNOWN");
  }

  static td::Status LiteServer(td::int32 code, td::Slice code_description, td::Slice message) {
    return td::Status::Error(500, PSLICE() << "LITE_SERVER_" << code_description << ": " << message);
  }
};
}  // namespace tonlib
