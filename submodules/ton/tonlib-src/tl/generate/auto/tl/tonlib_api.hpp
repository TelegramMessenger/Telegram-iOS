#pragma once

#include "tonlib_api.h"

namespace ton {
namespace tonlib_api {

/**
 * Calls specified function object with the specified object downcasted to the most-derived type.
 * \param[in] obj Object to pass as an argument to the function object.
 * \param[in] func Function object to which the object will be passed.
 * \returns whether function object call has happened. Should always return true for correct parameters.
 */
template <class T>
bool downcast_call(Object &obj, const T &func) {
  switch (obj.get_id()) {
    case accountAddress::ID:
      func(static_cast<accountAddress &>(obj));
      return true;
    case accountRevisionList::ID:
      func(static_cast<accountRevisionList &>(obj));
      return true;
    case raw_accountState::ID:
      func(static_cast<raw_accountState &>(obj));
      return true;
    case testWallet_accountState::ID:
      func(static_cast<testWallet_accountState &>(obj));
      return true;
    case wallet_accountState::ID:
      func(static_cast<wallet_accountState &>(obj));
      return true;
    case wallet_v3_accountState::ID:
      func(static_cast<wallet_v3_accountState &>(obj));
      return true;
    case wallet_highload_v1_accountState::ID:
      func(static_cast<wallet_highload_v1_accountState &>(obj));
      return true;
    case wallet_highload_v2_accountState::ID:
      func(static_cast<wallet_highload_v2_accountState &>(obj));
      return true;
    case testGiver_accountState::ID:
      func(static_cast<testGiver_accountState &>(obj));
      return true;
    case dns_accountState::ID:
      func(static_cast<dns_accountState &>(obj));
      return true;
    case rwallet_accountState::ID:
      func(static_cast<rwallet_accountState &>(obj));
      return true;
    case pchan_accountState::ID:
      func(static_cast<pchan_accountState &>(obj));
      return true;
    case uninited_accountState::ID:
      func(static_cast<uninited_accountState &>(obj));
      return true;
    case actionNoop::ID:
      func(static_cast<actionNoop &>(obj));
      return true;
    case actionMsg::ID:
      func(static_cast<actionMsg &>(obj));
      return true;
    case actionDns::ID:
      func(static_cast<actionDns &>(obj));
      return true;
    case actionPchan::ID:
      func(static_cast<actionPchan &>(obj));
      return true;
    case actionRwallet::ID:
      func(static_cast<actionRwallet &>(obj));
      return true;
    case adnlAddress::ID:
      func(static_cast<adnlAddress &>(obj));
      return true;
    case bip39Hints::ID:
      func(static_cast<bip39Hints &>(obj));
      return true;
    case config::ID:
      func(static_cast<config &>(obj));
      return true;
    case data::ID:
      func(static_cast<data &>(obj));
      return true;
    case error::ID:
      func(static_cast<error &>(obj));
      return true;
    case exportedEncryptedKey::ID:
      func(static_cast<exportedEncryptedKey &>(obj));
      return true;
    case exportedKey::ID:
      func(static_cast<exportedKey &>(obj));
      return true;
    case exportedPemKey::ID:
      func(static_cast<exportedPemKey &>(obj));
      return true;
    case exportedUnencryptedKey::ID:
      func(static_cast<exportedUnencryptedKey &>(obj));
      return true;
    case fees::ID:
      func(static_cast<fees &>(obj));
      return true;
    case fullAccountState::ID:
      func(static_cast<fullAccountState &>(obj));
      return true;
    case raw_initialAccountState::ID:
      func(static_cast<raw_initialAccountState &>(obj));
      return true;
    case testGiver_initialAccountState::ID:
      func(static_cast<testGiver_initialAccountState &>(obj));
      return true;
    case testWallet_initialAccountState::ID:
      func(static_cast<testWallet_initialAccountState &>(obj));
      return true;
    case wallet_initialAccountState::ID:
      func(static_cast<wallet_initialAccountState &>(obj));
      return true;
    case wallet_v3_initialAccountState::ID:
      func(static_cast<wallet_v3_initialAccountState &>(obj));
      return true;
    case wallet_highload_v1_initialAccountState::ID:
      func(static_cast<wallet_highload_v1_initialAccountState &>(obj));
      return true;
    case wallet_highload_v2_initialAccountState::ID:
      func(static_cast<wallet_highload_v2_initialAccountState &>(obj));
      return true;
    case rwallet_initialAccountState::ID:
      func(static_cast<rwallet_initialAccountState &>(obj));
      return true;
    case dns_initialAccountState::ID:
      func(static_cast<dns_initialAccountState &>(obj));
      return true;
    case pchan_initialAccountState::ID:
      func(static_cast<pchan_initialAccountState &>(obj));
      return true;
    case inputKeyRegular::ID:
      func(static_cast<inputKeyRegular &>(obj));
      return true;
    case inputKeyFake::ID:
      func(static_cast<inputKeyFake &>(obj));
      return true;
    case key::ID:
      func(static_cast<key &>(obj));
      return true;
    case keyStoreTypeDirectory::ID:
      func(static_cast<keyStoreTypeDirectory &>(obj));
      return true;
    case keyStoreTypeInMemory::ID:
      func(static_cast<keyStoreTypeInMemory &>(obj));
      return true;
    case logStreamDefault::ID:
      func(static_cast<logStreamDefault &>(obj));
      return true;
    case logStreamFile::ID:
      func(static_cast<logStreamFile &>(obj));
      return true;
    case logStreamEmpty::ID:
      func(static_cast<logStreamEmpty &>(obj));
      return true;
    case logTags::ID:
      func(static_cast<logTags &>(obj));
      return true;
    case logVerbosityLevel::ID:
      func(static_cast<logVerbosityLevel &>(obj));
      return true;
    case ok::ID:
      func(static_cast<ok &>(obj));
      return true;
    case options::ID:
      func(static_cast<options &>(obj));
      return true;
    case syncStateDone::ID:
      func(static_cast<syncStateDone &>(obj));
      return true;
    case syncStateInProgress::ID:
      func(static_cast<syncStateInProgress &>(obj));
      return true;
    case unpackedAccountAddress::ID:
      func(static_cast<unpackedAccountAddress &>(obj));
      return true;
    case updateSendLiteServerQuery::ID:
      func(static_cast<updateSendLiteServerQuery &>(obj));
      return true;
    case updateSyncState::ID:
      func(static_cast<updateSyncState &>(obj));
      return true;
    case dns_actionDeleteAll::ID:
      func(static_cast<dns_actionDeleteAll &>(obj));
      return true;
    case dns_actionDelete::ID:
      func(static_cast<dns_actionDelete &>(obj));
      return true;
    case dns_actionSet::ID:
      func(static_cast<dns_actionSet &>(obj));
      return true;
    case dns_entry::ID:
      func(static_cast<dns_entry &>(obj));
      return true;
    case dns_entryDataUnknown::ID:
      func(static_cast<dns_entryDataUnknown &>(obj));
      return true;
    case dns_entryDataText::ID:
      func(static_cast<dns_entryDataText &>(obj));
      return true;
    case dns_entryDataNextResolver::ID:
      func(static_cast<dns_entryDataNextResolver &>(obj));
      return true;
    case dns_entryDataSmcAddress::ID:
      func(static_cast<dns_entryDataSmcAddress &>(obj));
      return true;
    case dns_entryDataAdnlAddress::ID:
      func(static_cast<dns_entryDataAdnlAddress &>(obj));
      return true;
    case dns_resolved::ID:
      func(static_cast<dns_resolved &>(obj));
      return true;
    case ton_blockId::ID:
      func(static_cast<ton_blockId &>(obj));
      return true;
    case internal_transactionId::ID:
      func(static_cast<internal_transactionId &>(obj));
      return true;
    case liteServer_info::ID:
      func(static_cast<liteServer_info &>(obj));
      return true;
    case msg_dataRaw::ID:
      func(static_cast<msg_dataRaw &>(obj));
      return true;
    case msg_dataText::ID:
      func(static_cast<msg_dataText &>(obj));
      return true;
    case msg_dataDecryptedText::ID:
      func(static_cast<msg_dataDecryptedText &>(obj));
      return true;
    case msg_dataEncryptedText::ID:
      func(static_cast<msg_dataEncryptedText &>(obj));
      return true;
    case msg_dataDecrypted::ID:
      func(static_cast<msg_dataDecrypted &>(obj));
      return true;
    case msg_dataDecryptedArray::ID:
      func(static_cast<msg_dataDecryptedArray &>(obj));
      return true;
    case msg_dataEncrypted::ID:
      func(static_cast<msg_dataEncrypted &>(obj));
      return true;
    case msg_dataEncryptedArray::ID:
      func(static_cast<msg_dataEncryptedArray &>(obj));
      return true;
    case msg_message::ID:
      func(static_cast<msg_message &>(obj));
      return true;
    case options_configInfo::ID:
      func(static_cast<options_configInfo &>(obj));
      return true;
    case options_info::ID:
      func(static_cast<options_info &>(obj));
      return true;
    case pchan_actionInit::ID:
      func(static_cast<pchan_actionInit &>(obj));
      return true;
    case pchan_actionClose::ID:
      func(static_cast<pchan_actionClose &>(obj));
      return true;
    case pchan_actionTimeout::ID:
      func(static_cast<pchan_actionTimeout &>(obj));
      return true;
    case pchan_config::ID:
      func(static_cast<pchan_config &>(obj));
      return true;
    case pchan_promise::ID:
      func(static_cast<pchan_promise &>(obj));
      return true;
    case pchan_stateInit::ID:
      func(static_cast<pchan_stateInit &>(obj));
      return true;
    case pchan_stateClose::ID:
      func(static_cast<pchan_stateClose &>(obj));
      return true;
    case pchan_statePayout::ID:
      func(static_cast<pchan_statePayout &>(obj));
      return true;
    case query_fees::ID:
      func(static_cast<query_fees &>(obj));
      return true;
    case query_info::ID:
      func(static_cast<query_info &>(obj));
      return true;
    case raw_fullAccountState::ID:
      func(static_cast<raw_fullAccountState &>(obj));
      return true;
    case raw_message::ID:
      func(static_cast<raw_message &>(obj));
      return true;
    case raw_transaction::ID:
      func(static_cast<raw_transaction &>(obj));
      return true;
    case raw_transactions::ID:
      func(static_cast<raw_transactions &>(obj));
      return true;
    case rwallet_actionInit::ID:
      func(static_cast<rwallet_actionInit &>(obj));
      return true;
    case rwallet_config::ID:
      func(static_cast<rwallet_config &>(obj));
      return true;
    case rwallet_limit::ID:
      func(static_cast<rwallet_limit &>(obj));
      return true;
    case smc_info::ID:
      func(static_cast<smc_info &>(obj));
      return true;
    case smc_methodIdNumber::ID:
      func(static_cast<smc_methodIdNumber &>(obj));
      return true;
    case smc_methodIdName::ID:
      func(static_cast<smc_methodIdName &>(obj));
      return true;
    case smc_runResult::ID:
      func(static_cast<smc_runResult &>(obj));
      return true;
    case ton_blockIdExt::ID:
      func(static_cast<ton_blockIdExt &>(obj));
      return true;
    case tvm_cell::ID:
      func(static_cast<tvm_cell &>(obj));
      return true;
    case tvm_list::ID:
      func(static_cast<tvm_list &>(obj));
      return true;
    case tvm_numberDecimal::ID:
      func(static_cast<tvm_numberDecimal &>(obj));
      return true;
    case tvm_slice::ID:
      func(static_cast<tvm_slice &>(obj));
      return true;
    case tvm_stackEntrySlice::ID:
      func(static_cast<tvm_stackEntrySlice &>(obj));
      return true;
    case tvm_stackEntryCell::ID:
      func(static_cast<tvm_stackEntryCell &>(obj));
      return true;
    case tvm_stackEntryNumber::ID:
      func(static_cast<tvm_stackEntryNumber &>(obj));
      return true;
    case tvm_stackEntryTuple::ID:
      func(static_cast<tvm_stackEntryTuple &>(obj));
      return true;
    case tvm_stackEntryList::ID:
      func(static_cast<tvm_stackEntryList &>(obj));
      return true;
    case tvm_stackEntryUnsupported::ID:
      func(static_cast<tvm_stackEntryUnsupported &>(obj));
      return true;
    case tvm_tuple::ID:
      func(static_cast<tvm_tuple &>(obj));
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
    case addLogMessage::ID:
      func(static_cast<addLogMessage &>(obj));
      return true;
    case changeLocalPassword::ID:
      func(static_cast<changeLocalPassword &>(obj));
      return true;
    case close::ID:
      func(static_cast<close &>(obj));
      return true;
    case createNewKey::ID:
      func(static_cast<createNewKey &>(obj));
      return true;
    case createQuery::ID:
      func(static_cast<createQuery &>(obj));
      return true;
    case decrypt::ID:
      func(static_cast<decrypt &>(obj));
      return true;
    case deleteAllKeys::ID:
      func(static_cast<deleteAllKeys &>(obj));
      return true;
    case deleteKey::ID:
      func(static_cast<deleteKey &>(obj));
      return true;
    case dns_resolve::ID:
      func(static_cast<dns_resolve &>(obj));
      return true;
    case encrypt::ID:
      func(static_cast<encrypt &>(obj));
      return true;
    case exportEncryptedKey::ID:
      func(static_cast<exportEncryptedKey &>(obj));
      return true;
    case exportKey::ID:
      func(static_cast<exportKey &>(obj));
      return true;
    case exportPemKey::ID:
      func(static_cast<exportPemKey &>(obj));
      return true;
    case exportUnencryptedKey::ID:
      func(static_cast<exportUnencryptedKey &>(obj));
      return true;
    case getAccountAddress::ID:
      func(static_cast<getAccountAddress &>(obj));
      return true;
    case getAccountState::ID:
      func(static_cast<getAccountState &>(obj));
      return true;
    case getBip39Hints::ID:
      func(static_cast<getBip39Hints &>(obj));
      return true;
    case getLogStream::ID:
      func(static_cast<getLogStream &>(obj));
      return true;
    case getLogTagVerbosityLevel::ID:
      func(static_cast<getLogTagVerbosityLevel &>(obj));
      return true;
    case getLogTags::ID:
      func(static_cast<getLogTags &>(obj));
      return true;
    case getLogVerbosityLevel::ID:
      func(static_cast<getLogVerbosityLevel &>(obj));
      return true;
    case guessAccountRevision::ID:
      func(static_cast<guessAccountRevision &>(obj));
      return true;
    case importEncryptedKey::ID:
      func(static_cast<importEncryptedKey &>(obj));
      return true;
    case importKey::ID:
      func(static_cast<importKey &>(obj));
      return true;
    case importPemKey::ID:
      func(static_cast<importPemKey &>(obj));
      return true;
    case importUnencryptedKey::ID:
      func(static_cast<importUnencryptedKey &>(obj));
      return true;
    case init::ID:
      func(static_cast<init &>(obj));
      return true;
    case kdf::ID:
      func(static_cast<kdf &>(obj));
      return true;
    case liteServer_getInfo::ID:
      func(static_cast<liteServer_getInfo &>(obj));
      return true;
    case msg_decrypt::ID:
      func(static_cast<msg_decrypt &>(obj));
      return true;
    case msg_decryptWithProof::ID:
      func(static_cast<msg_decryptWithProof &>(obj));
      return true;
    case onLiteServerQueryError::ID:
      func(static_cast<onLiteServerQueryError &>(obj));
      return true;
    case onLiteServerQueryResult::ID:
      func(static_cast<onLiteServerQueryResult &>(obj));
      return true;
    case options_setConfig::ID:
      func(static_cast<options_setConfig &>(obj));
      return true;
    case options_validateConfig::ID:
      func(static_cast<options_validateConfig &>(obj));
      return true;
    case packAccountAddress::ID:
      func(static_cast<packAccountAddress &>(obj));
      return true;
    case pchan_packPromise::ID:
      func(static_cast<pchan_packPromise &>(obj));
      return true;
    case pchan_signPromise::ID:
      func(static_cast<pchan_signPromise &>(obj));
      return true;
    case pchan_unpackPromise::ID:
      func(static_cast<pchan_unpackPromise &>(obj));
      return true;
    case pchan_validatePromise::ID:
      func(static_cast<pchan_validatePromise &>(obj));
      return true;
    case query_estimateFees::ID:
      func(static_cast<query_estimateFees &>(obj));
      return true;
    case query_forget::ID:
      func(static_cast<query_forget &>(obj));
      return true;
    case query_getInfo::ID:
      func(static_cast<query_getInfo &>(obj));
      return true;
    case query_send::ID:
      func(static_cast<query_send &>(obj));
      return true;
    case raw_createAndSendMessage::ID:
      func(static_cast<raw_createAndSendMessage &>(obj));
      return true;
    case raw_createQuery::ID:
      func(static_cast<raw_createQuery &>(obj));
      return true;
    case raw_getAccountState::ID:
      func(static_cast<raw_getAccountState &>(obj));
      return true;
    case raw_getTransactions::ID:
      func(static_cast<raw_getTransactions &>(obj));
      return true;
    case raw_sendMessage::ID:
      func(static_cast<raw_sendMessage &>(obj));
      return true;
    case runTests::ID:
      func(static_cast<runTests &>(obj));
      return true;
    case setLogStream::ID:
      func(static_cast<setLogStream &>(obj));
      return true;
    case setLogTagVerbosityLevel::ID:
      func(static_cast<setLogTagVerbosityLevel &>(obj));
      return true;
    case setLogVerbosityLevel::ID:
      func(static_cast<setLogVerbosityLevel &>(obj));
      return true;
    case smc_getCode::ID:
      func(static_cast<smc_getCode &>(obj));
      return true;
    case smc_getData::ID:
      func(static_cast<smc_getData &>(obj));
      return true;
    case smc_getState::ID:
      func(static_cast<smc_getState &>(obj));
      return true;
    case smc_load::ID:
      func(static_cast<smc_load &>(obj));
      return true;
    case smc_runGetMethod::ID:
      func(static_cast<smc_runGetMethod &>(obj));
      return true;
    case sync::ID:
      func(static_cast<sync &>(obj));
      return true;
    case unpackAccountAddress::ID:
      func(static_cast<unpackAccountAddress &>(obj));
      return true;
    case withBlock::ID:
      func(static_cast<withBlock &>(obj));
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
bool downcast_call(AccountState &obj, const T &func) {
  switch (obj.get_id()) {
    case raw_accountState::ID:
      func(static_cast<raw_accountState &>(obj));
      return true;
    case testWallet_accountState::ID:
      func(static_cast<testWallet_accountState &>(obj));
      return true;
    case wallet_accountState::ID:
      func(static_cast<wallet_accountState &>(obj));
      return true;
    case wallet_v3_accountState::ID:
      func(static_cast<wallet_v3_accountState &>(obj));
      return true;
    case wallet_highload_v1_accountState::ID:
      func(static_cast<wallet_highload_v1_accountState &>(obj));
      return true;
    case wallet_highload_v2_accountState::ID:
      func(static_cast<wallet_highload_v2_accountState &>(obj));
      return true;
    case testGiver_accountState::ID:
      func(static_cast<testGiver_accountState &>(obj));
      return true;
    case dns_accountState::ID:
      func(static_cast<dns_accountState &>(obj));
      return true;
    case rwallet_accountState::ID:
      func(static_cast<rwallet_accountState &>(obj));
      return true;
    case pchan_accountState::ID:
      func(static_cast<pchan_accountState &>(obj));
      return true;
    case uninited_accountState::ID:
      func(static_cast<uninited_accountState &>(obj));
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
bool downcast_call(Action &obj, const T &func) {
  switch (obj.get_id()) {
    case actionNoop::ID:
      func(static_cast<actionNoop &>(obj));
      return true;
    case actionMsg::ID:
      func(static_cast<actionMsg &>(obj));
      return true;
    case actionDns::ID:
      func(static_cast<actionDns &>(obj));
      return true;
    case actionPchan::ID:
      func(static_cast<actionPchan &>(obj));
      return true;
    case actionRwallet::ID:
      func(static_cast<actionRwallet &>(obj));
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
bool downcast_call(InitialAccountState &obj, const T &func) {
  switch (obj.get_id()) {
    case raw_initialAccountState::ID:
      func(static_cast<raw_initialAccountState &>(obj));
      return true;
    case testGiver_initialAccountState::ID:
      func(static_cast<testGiver_initialAccountState &>(obj));
      return true;
    case testWallet_initialAccountState::ID:
      func(static_cast<testWallet_initialAccountState &>(obj));
      return true;
    case wallet_initialAccountState::ID:
      func(static_cast<wallet_initialAccountState &>(obj));
      return true;
    case wallet_v3_initialAccountState::ID:
      func(static_cast<wallet_v3_initialAccountState &>(obj));
      return true;
    case wallet_highload_v1_initialAccountState::ID:
      func(static_cast<wallet_highload_v1_initialAccountState &>(obj));
      return true;
    case wallet_highload_v2_initialAccountState::ID:
      func(static_cast<wallet_highload_v2_initialAccountState &>(obj));
      return true;
    case rwallet_initialAccountState::ID:
      func(static_cast<rwallet_initialAccountState &>(obj));
      return true;
    case dns_initialAccountState::ID:
      func(static_cast<dns_initialAccountState &>(obj));
      return true;
    case pchan_initialAccountState::ID:
      func(static_cast<pchan_initialAccountState &>(obj));
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
bool downcast_call(InputKey &obj, const T &func) {
  switch (obj.get_id()) {
    case inputKeyRegular::ID:
      func(static_cast<inputKeyRegular &>(obj));
      return true;
    case inputKeyFake::ID:
      func(static_cast<inputKeyFake &>(obj));
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
bool downcast_call(KeyStoreType &obj, const T &func) {
  switch (obj.get_id()) {
    case keyStoreTypeDirectory::ID:
      func(static_cast<keyStoreTypeDirectory &>(obj));
      return true;
    case keyStoreTypeInMemory::ID:
      func(static_cast<keyStoreTypeInMemory &>(obj));
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
bool downcast_call(LogStream &obj, const T &func) {
  switch (obj.get_id()) {
    case logStreamDefault::ID:
      func(static_cast<logStreamDefault &>(obj));
      return true;
    case logStreamFile::ID:
      func(static_cast<logStreamFile &>(obj));
      return true;
    case logStreamEmpty::ID:
      func(static_cast<logStreamEmpty &>(obj));
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
bool downcast_call(SyncState &obj, const T &func) {
  switch (obj.get_id()) {
    case syncStateDone::ID:
      func(static_cast<syncStateDone &>(obj));
      return true;
    case syncStateInProgress::ID:
      func(static_cast<syncStateInProgress &>(obj));
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
bool downcast_call(Update &obj, const T &func) {
  switch (obj.get_id()) {
    case updateSendLiteServerQuery::ID:
      func(static_cast<updateSendLiteServerQuery &>(obj));
      return true;
    case updateSyncState::ID:
      func(static_cast<updateSyncState &>(obj));
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
bool downcast_call(dns_Action &obj, const T &func) {
  switch (obj.get_id()) {
    case dns_actionDeleteAll::ID:
      func(static_cast<dns_actionDeleteAll &>(obj));
      return true;
    case dns_actionDelete::ID:
      func(static_cast<dns_actionDelete &>(obj));
      return true;
    case dns_actionSet::ID:
      func(static_cast<dns_actionSet &>(obj));
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
bool downcast_call(dns_EntryData &obj, const T &func) {
  switch (obj.get_id()) {
    case dns_entryDataUnknown::ID:
      func(static_cast<dns_entryDataUnknown &>(obj));
      return true;
    case dns_entryDataText::ID:
      func(static_cast<dns_entryDataText &>(obj));
      return true;
    case dns_entryDataNextResolver::ID:
      func(static_cast<dns_entryDataNextResolver &>(obj));
      return true;
    case dns_entryDataSmcAddress::ID:
      func(static_cast<dns_entryDataSmcAddress &>(obj));
      return true;
    case dns_entryDataAdnlAddress::ID:
      func(static_cast<dns_entryDataAdnlAddress &>(obj));
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
bool downcast_call(msg_Data &obj, const T &func) {
  switch (obj.get_id()) {
    case msg_dataRaw::ID:
      func(static_cast<msg_dataRaw &>(obj));
      return true;
    case msg_dataText::ID:
      func(static_cast<msg_dataText &>(obj));
      return true;
    case msg_dataDecryptedText::ID:
      func(static_cast<msg_dataDecryptedText &>(obj));
      return true;
    case msg_dataEncryptedText::ID:
      func(static_cast<msg_dataEncryptedText &>(obj));
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
bool downcast_call(pchan_Action &obj, const T &func) {
  switch (obj.get_id()) {
    case pchan_actionInit::ID:
      func(static_cast<pchan_actionInit &>(obj));
      return true;
    case pchan_actionClose::ID:
      func(static_cast<pchan_actionClose &>(obj));
      return true;
    case pchan_actionTimeout::ID:
      func(static_cast<pchan_actionTimeout &>(obj));
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
bool downcast_call(pchan_State &obj, const T &func) {
  switch (obj.get_id()) {
    case pchan_stateInit::ID:
      func(static_cast<pchan_stateInit &>(obj));
      return true;
    case pchan_stateClose::ID:
      func(static_cast<pchan_stateClose &>(obj));
      return true;
    case pchan_statePayout::ID:
      func(static_cast<pchan_statePayout &>(obj));
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
bool downcast_call(smc_MethodId &obj, const T &func) {
  switch (obj.get_id()) {
    case smc_methodIdNumber::ID:
      func(static_cast<smc_methodIdNumber &>(obj));
      return true;
    case smc_methodIdName::ID:
      func(static_cast<smc_methodIdName &>(obj));
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
bool downcast_call(tvm_StackEntry &obj, const T &func) {
  switch (obj.get_id()) {
    case tvm_stackEntrySlice::ID:
      func(static_cast<tvm_stackEntrySlice &>(obj));
      return true;
    case tvm_stackEntryCell::ID:
      func(static_cast<tvm_stackEntryCell &>(obj));
      return true;
    case tvm_stackEntryNumber::ID:
      func(static_cast<tvm_stackEntryNumber &>(obj));
      return true;
    case tvm_stackEntryTuple::ID:
      func(static_cast<tvm_stackEntryTuple &>(obj));
      return true;
    case tvm_stackEntryList::ID:
      func(static_cast<tvm_stackEntryList &>(obj));
      return true;
    case tvm_stackEntryUnsupported::ID:
      func(static_cast<tvm_stackEntryUnsupported &>(obj));
      return true;
    default:
      return false;
  }
}

}  // namespace tonlib_api
}  // namespace ton 
