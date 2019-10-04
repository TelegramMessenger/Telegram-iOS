#pragma once

#include "lite_api.h"

namespace ton {
namespace lite_api {

/**
 * Calls specified function object with the specified object downcasted to the most-derived type.
 * \param[in] obj Object to pass as an argument to the function object.
 * \param[in] func Function object to which the object will be passed.
 * \returns whether function object call has happened. Should always return true for correct parameters.
 */
template <class T>
bool downcast_call(Object &obj, const T &func) {
  switch (obj.get_id()) {
    case adnl_message_query::ID:
      func(static_cast<adnl_message_query &>(obj));
      return true;
    case adnl_message_answer::ID:
      func(static_cast<adnl_message_answer &>(obj));
      return true;
    case liteServer_accountId::ID:
      func(static_cast<liteServer_accountId &>(obj));
      return true;
    case liteServer_accountState::ID:
      func(static_cast<liteServer_accountState &>(obj));
      return true;
    case liteServer_allShardsInfo::ID:
      func(static_cast<liteServer_allShardsInfo &>(obj));
      return true;
    case liteServer_blockData::ID:
      func(static_cast<liteServer_blockData &>(obj));
      return true;
    case liteServer_blockHeader::ID:
      func(static_cast<liteServer_blockHeader &>(obj));
      return true;
    case liteServer_blockLinkBack::ID:
      func(static_cast<liteServer_blockLinkBack &>(obj));
      return true;
    case liteServer_blockLinkForward::ID:
      func(static_cast<liteServer_blockLinkForward &>(obj));
      return true;
    case liteServer_blockState::ID:
      func(static_cast<liteServer_blockState &>(obj));
      return true;
    case liteServer_blockTransactions::ID:
      func(static_cast<liteServer_blockTransactions &>(obj));
      return true;
    case liteServer_configInfo::ID:
      func(static_cast<liteServer_configInfo &>(obj));
      return true;
    case liteServer_currentTime::ID:
      func(static_cast<liteServer_currentTime &>(obj));
      return true;
    case liteServer_error::ID:
      func(static_cast<liteServer_error &>(obj));
      return true;
    case liteServer_masterchainInfo::ID:
      func(static_cast<liteServer_masterchainInfo &>(obj));
      return true;
    case liteServer_masterchainInfoExt::ID:
      func(static_cast<liteServer_masterchainInfoExt &>(obj));
      return true;
    case liteServer_partialBlockProof::ID:
      func(static_cast<liteServer_partialBlockProof &>(obj));
      return true;
    case liteServer_sendMsgStatus::ID:
      func(static_cast<liteServer_sendMsgStatus &>(obj));
      return true;
    case liteServer_shardInfo::ID:
      func(static_cast<liteServer_shardInfo &>(obj));
      return true;
    case liteServer_signature::ID:
      func(static_cast<liteServer_signature &>(obj));
      return true;
    case liteServer_signatureSet::ID:
      func(static_cast<liteServer_signatureSet &>(obj));
      return true;
    case liteServer_transactionId::ID:
      func(static_cast<liteServer_transactionId &>(obj));
      return true;
    case liteServer_transactionId3::ID:
      func(static_cast<liteServer_transactionId3 &>(obj));
      return true;
    case liteServer_transactionInfo::ID:
      func(static_cast<liteServer_transactionInfo &>(obj));
      return true;
    case liteServer_transactionList::ID:
      func(static_cast<liteServer_transactionList &>(obj));
      return true;
    case liteServer_version::ID:
      func(static_cast<liteServer_version &>(obj));
      return true;
    case liteServer_debug_verbosity::ID:
      func(static_cast<liteServer_debug_verbosity &>(obj));
      return true;
    case tonNode_blockId::ID:
      func(static_cast<tonNode_blockId &>(obj));
      return true;
    case tonNode_blockIdExt::ID:
      func(static_cast<tonNode_blockIdExt &>(obj));
      return true;
    case tonNode_zeroStateIdExt::ID:
      func(static_cast<tonNode_zeroStateIdExt &>(obj));
      return true;
    default:
      return false;
  }
}

/**
 * Calls specified function object with the specified object downcasted to the most-derived type.
 * \param[in] obj Object to pass as an argument to the function object.
 * \param[in] func Function object to which the object will be passed.
 * \returns whether function object call has happened. Should always return true for correct parameters.
 */
template <class T>
bool downcast_call(Function &obj, const T &func) {
  switch (obj.get_id()) {
    case liteServer_getAccountState::ID:
      func(static_cast<liteServer_getAccountState &>(obj));
      return true;
    case liteServer_getAllShardsInfo::ID:
      func(static_cast<liteServer_getAllShardsInfo &>(obj));
      return true;
    case liteServer_getBlock::ID:
      func(static_cast<liteServer_getBlock &>(obj));
      return true;
    case liteServer_getBlockHeader::ID:
      func(static_cast<liteServer_getBlockHeader &>(obj));
      return true;
    case liteServer_getBlockProof::ID:
      func(static_cast<liteServer_getBlockProof &>(obj));
      return true;
    case liteServer_getConfigAll::ID:
      func(static_cast<liteServer_getConfigAll &>(obj));
      return true;
    case liteServer_getConfigParams::ID:
      func(static_cast<liteServer_getConfigParams &>(obj));
      return true;
    case liteServer_getMasterchainInfo::ID:
      func(static_cast<liteServer_getMasterchainInfo &>(obj));
      return true;
    case liteServer_getMasterchainInfoExt::ID:
      func(static_cast<liteServer_getMasterchainInfoExt &>(obj));
      return true;
    case liteServer_getOneTransaction::ID:
      func(static_cast<liteServer_getOneTransaction &>(obj));
      return true;
    case liteServer_getShardInfo::ID:
      func(static_cast<liteServer_getShardInfo &>(obj));
      return true;
    case liteServer_getState::ID:
      func(static_cast<liteServer_getState &>(obj));
      return true;
    case liteServer_getTime::ID:
      func(static_cast<liteServer_getTime &>(obj));
      return true;
    case liteServer_getTransactions::ID:
      func(static_cast<liteServer_getTransactions &>(obj));
      return true;
    case liteServer_getVersion::ID:
      func(static_cast<liteServer_getVersion &>(obj));
      return true;
    case liteServer_listBlockTransactions::ID:
      func(static_cast<liteServer_listBlockTransactions &>(obj));
      return true;
    case liteServer_lookupBlock::ID:
      func(static_cast<liteServer_lookupBlock &>(obj));
      return true;
    case liteServer_query::ID:
      func(static_cast<liteServer_query &>(obj));
      return true;
    case liteServer_queryPrefix::ID:
      func(static_cast<liteServer_queryPrefix &>(obj));
      return true;
    case liteServer_sendMessage::ID:
      func(static_cast<liteServer_sendMessage &>(obj));
      return true;
    case liteServer_waitMasterchainSeqno::ID:
      func(static_cast<liteServer_waitMasterchainSeqno &>(obj));
      return true;
    default:
      return false;
  }
}

/**
 * Calls specified function object with the specified object downcasted to the most-derived type.
 * \param[in] obj Object to pass as an argument to the function object.
 * \param[in] func Function object to which the object will be passed.
 * \returns whether function object call has happened. Should always return true for correct parameters.
 */
template <class T>
bool downcast_call(adnl_Message &obj, const T &func) {
  switch (obj.get_id()) {
    case adnl_message_query::ID:
      func(static_cast<adnl_message_query &>(obj));
      return true;
    case adnl_message_answer::ID:
      func(static_cast<adnl_message_answer &>(obj));
      return true;
    default:
      return false;
  }
}

/**
 * Calls specified function object with the specified object downcasted to the most-derived type.
 * \param[in] obj Object to pass as an argument to the function object.
 * \param[in] func Function object to which the object will be passed.
 * \returns whether function object call has happened. Should always return true for correct parameters.
 */
template <class T>
bool downcast_call(liteServer_BlockLink &obj, const T &func) {
  switch (obj.get_id()) {
    case liteServer_blockLinkBack::ID:
      func(static_cast<liteServer_blockLinkBack &>(obj));
      return true;
    case liteServer_blockLinkForward::ID:
      func(static_cast<liteServer_blockLinkForward &>(obj));
      return true;
    default:
      return false;
  }
}

}  // namespace lite_api
}  // namespace ton 
