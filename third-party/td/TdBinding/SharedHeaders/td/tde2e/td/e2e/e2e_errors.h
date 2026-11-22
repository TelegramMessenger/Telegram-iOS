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
  UnknownError = 100,
  Any = 101,
  InvalidInput = 102,
  InvalidKeyId = 103,
  InvalidId = 104,
  InvalidBlock = 200,
  InvalidBlock_NoChanges = 201,
  InvalidBlock_InvalidSignature = 202,
  InvalidBlock_HashMismatch = 203,
  InvalidBlock_HeightMismatch = 204,
  InvalidBlock_InvalidStateProof_Group = 205,
  InvalidBlock_InvalidStateProof_Secret = 206,
  InvalidBlock_NoPermissions = 207,
  InvalidBlock_InvalidGroupState = 208,
  InvalidBlock_InvalidSharedSecret = 209,
  InvalidCallGroupState_NotParticipant = 300,
  InvalidCallGroupState_WrongUserId = 301,
  Decrypt_UnknownEpoch = 400,
  Encrypt_UnknownEpoch = 401,
  InvalidBroadcast_InFuture = 500,
  InvalidBroadcast_NotInCommit = 501,
  InvalidBroadcast_NotInReveal = 502,
  InvalidBroadcast_UnknownUserId = 503,
  InvalidBroadcast_AlreadyApplied = 504,
  InvalidBroadcast_InvalidReveal = 505,
  InvalidBroadcast_InvalidBlockHash = 506,
  InvalidCallChannelId = 600,
  CallFailed = 601,
  CallKeyAlreadyUsed = 602
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
    case ErrorCode::InvalidBlock_NoChanges:
      return "INVALID_BLOCK__NO_CHANGES";
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
    case ErrorCode::InvalidBlock_InvalidSharedSecret:
      return "INVALID_BLOCK__INVALID_SHARED_SECRET";
    case ErrorCode::InvalidBlock_NoPermissions:
      return "INVALID_BLOCK__NO_PERMISSIONS";
    case ErrorCode::InvalidCallGroupState_NotParticipant:
      return "INVALID_CALL_GROUP_STATE__NOT_PARTICIPANT";
    case ErrorCode::InvalidCallGroupState_WrongUserId:
      return "INVALID_CALL_GROUP_STATE__WRONG_USER_ID";
    case ErrorCode::Decrypt_UnknownEpoch:
      return "DECRYPT__UNKNOWN_EPOCH";
    case ErrorCode::Encrypt_UnknownEpoch:
      return "ENCRYPT__UNKNOWN_EPOCH";
    case ErrorCode::InvalidBroadcast_InFuture:
      return "INVALID_BROADCAST__IN_FUTURE";
    case ErrorCode::InvalidBroadcast_NotInCommit:
      return "INVALID_BROADCAST__NOT_IN_COMMIT";
    case ErrorCode::InvalidBroadcast_NotInReveal:
      return "INVALID_BROADCAST__NOT_IN_REVEAL";
    case ErrorCode::InvalidBroadcast_UnknownUserId:
      return "INVALID_BROADCAST__UNKNOWN_USER_ID";
    case ErrorCode::InvalidBroadcast_AlreadyApplied:
      return "INVALID_BROADCAST__ALREADY_APPLIED";
    case ErrorCode::InvalidBroadcast_InvalidReveal:
      return "INVALID_BROADCAST__INVALID_REVEAL";
    case ErrorCode::InvalidBroadcast_InvalidBlockHash:
      return "INVALID_BROADCAST__INVALID_BLOCK_HASH";
    case ErrorCode::CallFailed:
      return "CALL_FAILED";
    case ErrorCode::CallKeyAlreadyUsed:
      return "CALL_KEY_ALREADY_USED";
    case ErrorCode::InvalidCallChannelId:
      return "INVALID_CALL_CHANNEL_ID";
  }
  return "UNKNOWN_ERROR";
}

}  // namespace tde2e_api
