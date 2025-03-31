//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <string_view>

namespace tde2e_api {

enum class ErrorCode : int {
  UnknownError = 1,
  Any,
  InvalidInput,
  InvalidKeyId,
  InvalidId,
  InvalidBlock,
  InvalidBlock_InvalidSignature,
  InvalidBlock_HashMismatch,
  InvalidBlock_HeightMismatch,
  InvalidBlock_InvalidStateProof_Group,
  InvalidBlock_InvalidStateProof_Secret,
  InvalidBlock_NoPermissions,
  InvalidBlock_InvalidGroupState,
  Decrypt_UnknownEpoch,
  Encrypt_UnknownEpoch,
};
inline std::string_view error_string(ErrorCode error_code) {
  switch (error_code) {
    case ErrorCode::Any:
      return "";
    case ErrorCode::UnknownError:
      return "UNKNOWN_ERROR";
    case ErrorCode::InvalidInput:
      return "INVALID_INPUT";
    case ErrorCode::InvalidKeyId:
      return "INVALID_KEY_ID";
    case ErrorCode::InvalidId:
      return "INVALID_ID";
    case ErrorCode::InvalidBlock:
      return "INVALID_BLOCK";
    case ErrorCode::InvalidBlock_InvalidSignature:
      return "INVALID_BLOCK__INVALID_SIGNATURE";
    case ErrorCode::InvalidBlock_HashMismatch:
      return "INVALID_BLOCK__HASH_MISMATCH";
    case ErrorCode::InvalidBlock_HeightMismatch:
      return "INVALID_BLOCK__HEIGHT_MISMATCH";
    case ErrorCode::InvalidBlock_InvalidStateProof_Group:
      return "INVALID_BLOCK__INVALID_STATE_PROOF__GROUP";
    case ErrorCode::InvalidBlock_InvalidStateProof_Secret:
      return "INVALID_BLOCK__INVALID_STATE_PROOF__SECRET";
    case ErrorCode::InvalidBlock_InvalidGroupState:
      return "INVALID_BLOCK__INVALID_GROUP_STATE";
    case ErrorCode::InvalidBlock_NoPermissions:
      return "INVALID_BLOCK__NO_PERMISSIONS";
    case ErrorCode::Decrypt_UnknownEpoch:
      return "DECRYPT__UNKNOWN_EPOCH";
    case ErrorCode::Encrypt_UnknownEpoch:
      return "ENCRYPT__UNKNOWN_EPOCH";
  }
  return "UNKNOWN_ERROR";
}

}  // namespace tde2e_api
