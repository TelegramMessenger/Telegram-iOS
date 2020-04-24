#include "ton_api.h"

#include "tl/tl_object_parse.h"
#include "tl/tl_object_store.h"
#include "td/utils/int_types.h"
#include "crypto/common/bitstring.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

namespace ton {
namespace ton_api {

std::string to_string(const BaseObject &value) {
  td::TlStorerToString storer;
  value.store(storer, "");
  return storer.str();
}

object_ptr<Object> Object::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case hashable_bool::ID:
      return hashable_bool::fetch(p);
    case hashable_int32::ID:
      return hashable_int32::fetch(p);
    case hashable_int64::ID:
      return hashable_int64::fetch(p);
    case hashable_int256::ID:
      return hashable_int256::fetch(p);
    case hashable_bytes::ID:
      return hashable_bytes::fetch(p);
    case hashable_pair::ID:
      return hashable_pair::fetch(p);
    case hashable_vector::ID:
      return hashable_vector::fetch(p);
    case hashable_validatorSessionOldRound::ID:
      return hashable_validatorSessionOldRound::fetch(p);
    case hashable_validatorSessionRoundAttempt::ID:
      return hashable_validatorSessionRoundAttempt::fetch(p);
    case hashable_validatorSessionRound::ID:
      return hashable_validatorSessionRound::fetch(p);
    case hashable_blockSignature::ID:
      return hashable_blockSignature::fetch(p);
    case hashable_sentBlock::ID:
      return hashable_sentBlock::fetch(p);
    case hashable_sentBlockEmpty::ID:
      return hashable_sentBlockEmpty::fetch(p);
    case hashable_vote::ID:
      return hashable_vote::fetch(p);
    case hashable_blockCandidate::ID:
      return hashable_blockCandidate::fetch(p);
    case hashable_blockVoteCandidate::ID:
      return hashable_blockVoteCandidate::fetch(p);
    case hashable_blockCandidateAttempt::ID:
      return hashable_blockCandidateAttempt::fetch(p);
    case hashable_cntVector::ID:
      return hashable_cntVector::fetch(p);
    case hashable_cntSortedVector::ID:
      return hashable_cntSortedVector::fetch(p);
    case hashable_validatorSession::ID:
      return hashable_validatorSession::fetch(p);
    case pk_unenc::ID:
      return pk_unenc::fetch(p);
    case pk_ed25519::ID:
      return pk_ed25519::fetch(p);
    case pk_aes::ID:
      return pk_aes::fetch(p);
    case pk_overlay::ID:
      return pk_overlay::fetch(p);
    case pub_unenc::ID:
      return pub_unenc::fetch(p);
    case pub_ed25519::ID:
      return pub_ed25519::fetch(p);
    case pub_aes::ID:
      return pub_aes::fetch(p);
    case pub_overlay::ID:
      return pub_overlay::fetch(p);
    case testObject::ID:
      return testObject::fetch(p);
    case testString::ID:
      return testString::fetch(p);
    case testInt::ID:
      return testInt::fetch(p);
    case testVectorBytes::ID:
      return testVectorBytes::fetch(p);
    case adnl_address_udp::ID:
      return adnl_address_udp::fetch(p);
    case adnl_address_udp6::ID:
      return adnl_address_udp6::fetch(p);
    case adnl_address_tunnel::ID:
      return adnl_address_tunnel::fetch(p);
    case adnl_addressList::ID:
      return adnl_addressList::fetch(p);
    case adnl_message_createChannel::ID:
      return adnl_message_createChannel::fetch(p);
    case adnl_message_confirmChannel::ID:
      return adnl_message_confirmChannel::fetch(p);
    case adnl_message_custom::ID:
      return adnl_message_custom::fetch(p);
    case adnl_message_nop::ID:
      return adnl_message_nop::fetch(p);
    case adnl_message_reinit::ID:
      return adnl_message_reinit::fetch(p);
    case adnl_message_query::ID:
      return adnl_message_query::fetch(p);
    case adnl_message_answer::ID:
      return adnl_message_answer::fetch(p);
    case adnl_message_part::ID:
      return adnl_message_part::fetch(p);
    case adnl_node::ID:
      return adnl_node::fetch(p);
    case adnl_nodes::ID:
      return adnl_nodes::fetch(p);
    case adnl_packetContents::ID:
      return adnl_packetContents::fetch(p);
    case adnl_pong::ID:
      return adnl_pong::fetch(p);
    case adnl_proxy_none::ID:
      return adnl_proxy_none::fetch(p);
    case adnl_proxy_fast::ID:
      return adnl_proxy_fast::fetch(p);
    case adnl_proxyControlPacketPing::ID:
      return adnl_proxyControlPacketPing::fetch(p);
    case adnl_proxyControlPacketPong::ID:
      return adnl_proxyControlPacketPong::fetch(p);
    case adnl_proxyControlPacketRegister::ID:
      return adnl_proxyControlPacketRegister::fetch(p);
    case adnl_proxyPacketHeader::ID:
      return adnl_proxyPacketHeader::fetch(p);
    case adnl_proxyToFastHash::ID:
      return adnl_proxyToFastHash::fetch(p);
    case adnl_proxyToFast::ID:
      return adnl_proxyToFast::fetch(p);
    case adnl_tunnelPacketContents::ID:
      return adnl_tunnelPacketContents::fetch(p);
    case adnl_config_global::ID:
      return adnl_config_global::fetch(p);
    case adnl_db_node_key::ID:
      return adnl_db_node_key::fetch(p);
    case adnl_db_node_value::ID:
      return adnl_db_node_value::fetch(p);
    case adnl_id_short::ID:
      return adnl_id_short::fetch(p);
    case catchain_block::ID:
      return catchain_block::fetch(p);
    case catchain_blockNotFound::ID:
      return catchain_blockNotFound::fetch(p);
    case catchain_blockResult::ID:
      return catchain_blockResult::fetch(p);
    case catchain_blocks::ID:
      return catchain_blocks::fetch(p);
    case catchain_difference::ID:
      return catchain_difference::fetch(p);
    case catchain_differenceFork::ID:
      return catchain_differenceFork::fetch(p);
    case catchain_firstblock::ID:
      return catchain_firstblock::fetch(p);
    case catchain_sent::ID:
      return catchain_sent::fetch(p);
    case catchain_blockUpdate::ID:
      return catchain_blockUpdate::fetch(p);
    case catchain_block_data::ID:
      return catchain_block_data::fetch(p);
    case catchain_block_dep::ID:
      return catchain_block_dep::fetch(p);
    case catchain_block_id::ID:
      return catchain_block_id::fetch(p);
    case catchain_block_data_badBlock::ID:
      return catchain_block_data_badBlock::fetch(p);
    case catchain_block_data_fork::ID:
      return catchain_block_data_fork::fetch(p);
    case catchain_block_data_nop::ID:
      return catchain_block_data_nop::fetch(p);
    case catchain_block_data_vector::ID:
      return catchain_block_data_vector::fetch(p);
    case catchain_config_global::ID:
      return catchain_config_global::fetch(p);
    case config_global::ID:
      return config_global::fetch(p);
    case config_local::ID:
      return config_local::fetch(p);
    case control_config_local::ID:
      return control_config_local::fetch(p);
    case db_candidate::ID:
      return db_candidate::fetch(p);
    case db_block_info::ID:
      return db_block_info::fetch(p);
    case db_block_packedInfo::ID:
      return db_block_packedInfo::fetch(p);
    case db_block_archivedInfo::ID:
      return db_block_archivedInfo::fetch(p);
    case db_blockdb_key_lru::ID:
      return db_blockdb_key_lru::fetch(p);
    case db_blockdb_key_value::ID:
      return db_blockdb_key_value::fetch(p);
    case db_blockdb_lru::ID:
      return db_blockdb_lru::fetch(p);
    case db_blockdb_value::ID:
      return db_blockdb_value::fetch(p);
    case db_candidate_id::ID:
      return db_candidate_id::fetch(p);
    case db_celldb_value::ID:
      return db_celldb_value::fetch(p);
    case db_celldb_key_value::ID:
      return db_celldb_key_value::fetch(p);
    case db_filedb_key_empty::ID:
      return db_filedb_key_empty::fetch(p);
    case db_filedb_key_blockFile::ID:
      return db_filedb_key_blockFile::fetch(p);
    case db_filedb_key_zeroStateFile::ID:
      return db_filedb_key_zeroStateFile::fetch(p);
    case db_filedb_key_persistentStateFile::ID:
      return db_filedb_key_persistentStateFile::fetch(p);
    case db_filedb_key_proof::ID:
      return db_filedb_key_proof::fetch(p);
    case db_filedb_key_proofLink::ID:
      return db_filedb_key_proofLink::fetch(p);
    case db_filedb_key_signatures::ID:
      return db_filedb_key_signatures::fetch(p);
    case db_filedb_key_candidate::ID:
      return db_filedb_key_candidate::fetch(p);
    case db_filedb_key_blockInfo::ID:
      return db_filedb_key_blockInfo::fetch(p);
    case db_filedb_value::ID:
      return db_filedb_value::fetch(p);
    case db_files_index_key::ID:
      return db_files_index_key::fetch(p);
    case db_files_package_key::ID:
      return db_files_package_key::fetch(p);
    case db_files_index_value::ID:
      return db_files_index_value::fetch(p);
    case db_files_package_firstBlock::ID:
      return db_files_package_firstBlock::fetch(p);
    case db_files_package_value::ID:
      return db_files_package_value::fetch(p);
    case db_lt_el_key::ID:
      return db_lt_el_key::fetch(p);
    case db_lt_desc_key::ID:
      return db_lt_desc_key::fetch(p);
    case db_lt_shard_key::ID:
      return db_lt_shard_key::fetch(p);
    case db_lt_status_key::ID:
      return db_lt_status_key::fetch(p);
    case db_lt_desc_value::ID:
      return db_lt_desc_value::fetch(p);
    case db_lt_el_value::ID:
      return db_lt_el_value::fetch(p);
    case db_lt_shard_value::ID:
      return db_lt_shard_value::fetch(p);
    case db_lt_status_value::ID:
      return db_lt_status_value::fetch(p);
    case db_root_config::ID:
      return db_root_config::fetch(p);
    case db_root_dbDescription::ID:
      return db_root_dbDescription::fetch(p);
    case db_root_key_cellDb::ID:
      return db_root_key_cellDb::fetch(p);
    case db_root_key_blockDb::ID:
      return db_root_key_blockDb::fetch(p);
    case db_root_key_config::ID:
      return db_root_key_config::fetch(p);
    case db_state_asyncSerializer::ID:
      return db_state_asyncSerializer::fetch(p);
    case db_state_dbVersion::ID:
      return db_state_dbVersion::fetch(p);
    case db_state_destroyedSessions::ID:
      return db_state_destroyedSessions::fetch(p);
    case db_state_gcBlockId::ID:
      return db_state_gcBlockId::fetch(p);
    case db_state_hardforks::ID:
      return db_state_hardforks::fetch(p);
    case db_state_initBlockId::ID:
      return db_state_initBlockId::fetch(p);
    case db_state_key_destroyedSessions::ID:
      return db_state_key_destroyedSessions::fetch(p);
    case db_state_key_initBlockId::ID:
      return db_state_key_initBlockId::fetch(p);
    case db_state_key_gcBlockId::ID:
      return db_state_key_gcBlockId::fetch(p);
    case db_state_key_shardClient::ID:
      return db_state_key_shardClient::fetch(p);
    case db_state_key_asyncSerializer::ID:
      return db_state_key_asyncSerializer::fetch(p);
    case db_state_key_hardforks::ID:
      return db_state_key_hardforks::fetch(p);
    case db_state_key_dbVersion::ID:
      return db_state_key_dbVersion::fetch(p);
    case db_state_shardClient::ID:
      return db_state_shardClient::fetch(p);
    case dht_key::ID:
      return dht_key::fetch(p);
    case dht_keyDescription::ID:
      return dht_keyDescription::fetch(p);
    case dht_message::ID:
      return dht_message::fetch(p);
    case dht_node::ID:
      return dht_node::fetch(p);
    case dht_nodes::ID:
      return dht_nodes::fetch(p);
    case dht_pong::ID:
      return dht_pong::fetch(p);
    case dht_stored::ID:
      return dht_stored::fetch(p);
    case dht_updateRule_signature::ID:
      return dht_updateRule_signature::fetch(p);
    case dht_updateRule_anybody::ID:
      return dht_updateRule_anybody::fetch(p);
    case dht_updateRule_overlayNodes::ID:
      return dht_updateRule_overlayNodes::fetch(p);
    case dht_value::ID:
      return dht_value::fetch(p);
    case dht_valueNotFound::ID:
      return dht_valueNotFound::fetch(p);
    case dht_valueFound::ID:
      return dht_valueFound::fetch(p);
    case dht_config_global::ID:
      return dht_config_global::fetch(p);
    case dht_config_local::ID:
      return dht_config_local::fetch(p);
    case dht_config_random_local::ID:
      return dht_config_random_local::fetch(p);
    case dht_db_bucket::ID:
      return dht_db_bucket::fetch(p);
    case dht_db_key_bucket::ID:
      return dht_db_key_bucket::fetch(p);
    case dummyworkchain0_config_global::ID:
      return dummyworkchain0_config_global::fetch(p);
    case engine_addr::ID:
      return engine_addr::fetch(p);
    case engine_addrProxy::ID:
      return engine_addrProxy::fetch(p);
    case engine_adnl::ID:
      return engine_adnl::fetch(p);
    case engine_controlInterface::ID:
      return engine_controlInterface::fetch(p);
    case engine_controlProcess::ID:
      return engine_controlProcess::fetch(p);
    case engine_dht::ID:
      return engine_dht::fetch(p);
    case engine_gc::ID:
      return engine_gc::fetch(p);
    case engine_liteServer::ID:
      return engine_liteServer::fetch(p);
    case engine_validator::ID:
      return engine_validator::fetch(p);
    case engine_validatorAdnlAddress::ID:
      return engine_validatorAdnlAddress::fetch(p);
    case engine_validatorTempKey::ID:
      return engine_validatorTempKey::fetch(p);
    case engine_adnlProxy_config::ID:
      return engine_adnlProxy_config::fetch(p);
    case engine_adnlProxy_port::ID:
      return engine_adnlProxy_port::fetch(p);
    case engine_dht_config::ID:
      return engine_dht_config::fetch(p);
    case engine_validator_config::ID:
      return engine_validator_config::fetch(p);
    case engine_validator_controlQueryError::ID:
      return engine_validator_controlQueryError::fetch(p);
    case engine_validator_dhtServerStatus::ID:
      return engine_validator_dhtServerStatus::fetch(p);
    case engine_validator_dhtServersStatus::ID:
      return engine_validator_dhtServersStatus::fetch(p);
    case engine_validator_electionBid::ID:
      return engine_validator_electionBid::fetch(p);
    case engine_validator_fullNodeMaster::ID:
      return engine_validator_fullNodeMaster::fetch(p);
    case engine_validator_fullNodeSlave::ID:
      return engine_validator_fullNodeSlave::fetch(p);
    case validator_groupMember::ID:
      return validator_groupMember::fetch(p);
    case engine_validator_jsonConfig::ID:
      return engine_validator_jsonConfig::fetch(p);
    case engine_validator_keyHash::ID:
      return engine_validator_keyHash::fetch(p);
    case engine_validator_oneStat::ID:
      return engine_validator_oneStat::fetch(p);
    case engine_validator_proposalVote::ID:
      return engine_validator_proposalVote::fetch(p);
    case engine_validator_signature::ID:
      return engine_validator_signature::fetch(p);
    case engine_validator_stats::ID:
      return engine_validator_stats::fetch(p);
    case engine_validator_success::ID:
      return engine_validator_success::fetch(p);
    case engine_validator_time::ID:
      return engine_validator_time::fetch(p);
    case fec_raptorQ::ID:
      return fec_raptorQ::fetch(p);
    case fec_roundRobin::ID:
      return fec_roundRobin::fetch(p);
    case fec_online::ID:
      return fec_online::fetch(p);
    case http_header::ID:
      return http_header::fetch(p);
    case http_payloadPart::ID:
      return http_payloadPart::fetch(p);
    case http_response::ID:
      return http_response::fetch(p);
    case http_server_config::ID:
      return http_server_config::fetch(p);
    case http_server_dnsEntry::ID:
      return http_server_dnsEntry::fetch(p);
    case http_server_host::ID:
      return http_server_host::fetch(p);
    case id_config_local::ID:
      return id_config_local::fetch(p);
    case liteclient_config_global::ID:
      return liteclient_config_global::fetch(p);
    case liteserver_desc::ID:
      return liteserver_desc::fetch(p);
    case liteserver_config_local::ID:
      return liteserver_config_local::fetch(p);
    case liteserver_config_random_local::ID:
      return liteserver_config_random_local::fetch(p);
    case overlay_fec_received::ID:
      return overlay_fec_received::fetch(p);
    case overlay_fec_completed::ID:
      return overlay_fec_completed::fetch(p);
    case overlay_unicast::ID:
      return overlay_unicast::fetch(p);
    case overlay_broadcast::ID:
      return overlay_broadcast::fetch(p);
    case overlay_broadcastFec::ID:
      return overlay_broadcastFec::fetch(p);
    case overlay_broadcastFecShort::ID:
      return overlay_broadcastFecShort::fetch(p);
    case overlay_broadcastNotFound::ID:
      return overlay_broadcastNotFound::fetch(p);
    case overlay_broadcastList::ID:
      return overlay_broadcastList::fetch(p);
    case overlay_certificate::ID:
      return overlay_certificate::fetch(p);
    case overlay_emptyCertificate::ID:
      return overlay_emptyCertificate::fetch(p);
    case overlay_certificateId::ID:
      return overlay_certificateId::fetch(p);
    case overlay_message::ID:
      return overlay_message::fetch(p);
    case overlay_node::ID:
      return overlay_node::fetch(p);
    case overlay_nodes::ID:
      return overlay_nodes::fetch(p);
    case overlay_broadcast_id::ID:
      return overlay_broadcast_id::fetch(p);
    case overlay_broadcast_toSign::ID:
      return overlay_broadcast_toSign::fetch(p);
    case overlay_broadcastFec_id::ID:
      return overlay_broadcastFec_id::fetch(p);
    case overlay_broadcastFec_partId::ID:
      return overlay_broadcastFec_partId::fetch(p);
    case overlay_db_key_nodes::ID:
      return overlay_db_key_nodes::fetch(p);
    case overlay_db_nodes::ID:
      return overlay_db_nodes::fetch(p);
    case overlay_node_toSign::ID:
      return overlay_node_toSign::fetch(p);
    case rldp_message::ID:
      return rldp_message::fetch(p);
    case rldp_query::ID:
      return rldp_query::fetch(p);
    case rldp_answer::ID:
      return rldp_answer::fetch(p);
    case rldp_messagePart::ID:
      return rldp_messagePart::fetch(p);
    case rldp_confirm::ID:
      return rldp_confirm::fetch(p);
    case rldp_complete::ID:
      return rldp_complete::fetch(p);
    case tcp_authentificate::ID:
      return tcp_authentificate::fetch(p);
    case tcp_authentificationNonce::ID:
      return tcp_authentificationNonce::fetch(p);
    case tcp_authentificationComplete::ID:
      return tcp_authentificationComplete::fetch(p);
    case tcp_pong::ID:
      return tcp_pong::fetch(p);
    case ton_blockId::ID:
      return ton_blockId::fetch(p);
    case ton_blockIdApprove::ID:
      return ton_blockIdApprove::fetch(p);
    case tonNode_archiveNotFound::ID:
      return tonNode_archiveNotFound::fetch(p);
    case tonNode_archiveInfo::ID:
      return tonNode_archiveInfo::fetch(p);
    case tonNode_blockDescriptionEmpty::ID:
      return tonNode_blockDescriptionEmpty::fetch(p);
    case tonNode_blockDescription::ID:
      return tonNode_blockDescription::fetch(p);
    case tonNode_blockId::ID:
      return tonNode_blockId::fetch(p);
    case tonNode_blockIdExt::ID:
      return tonNode_blockIdExt::fetch(p);
    case tonNode_blockSignature::ID:
      return tonNode_blockSignature::fetch(p);
    case tonNode_blocksDescription::ID:
      return tonNode_blocksDescription::fetch(p);
    case tonNode_blockBroadcast::ID:
      return tonNode_blockBroadcast::fetch(p);
    case tonNode_ihrMessageBroadcast::ID:
      return tonNode_ihrMessageBroadcast::fetch(p);
    case tonNode_externalMessageBroadcast::ID:
      return tonNode_externalMessageBroadcast::fetch(p);
    case tonNode_newShardBlockBroadcast::ID:
      return tonNode_newShardBlockBroadcast::fetch(p);
    case tonNode_capabilities::ID:
      return tonNode_capabilities::fetch(p);
    case tonNode_data::ID:
      return tonNode_data::fetch(p);
    case tonNode_dataFull::ID:
      return tonNode_dataFull::fetch(p);
    case tonNode_dataFullEmpty::ID:
      return tonNode_dataFullEmpty::fetch(p);
    case tonNode_dataList::ID:
      return tonNode_dataList::fetch(p);
    case tonNode_externalMessage::ID:
      return tonNode_externalMessage::fetch(p);
    case tonNode_ihrMessage::ID:
      return tonNode_ihrMessage::fetch(p);
    case tonNode_keyBlocks::ID:
      return tonNode_keyBlocks::fetch(p);
    case tonNode_newShardBlock::ID:
      return tonNode_newShardBlock::fetch(p);
    case tonNode_prepared::ID:
      return tonNode_prepared::fetch(p);
    case tonNode_notFound::ID:
      return tonNode_notFound::fetch(p);
    case tonNode_preparedProofEmpty::ID:
      return tonNode_preparedProofEmpty::fetch(p);
    case tonNode_preparedProof::ID:
      return tonNode_preparedProof::fetch(p);
    case tonNode_preparedProofLink::ID:
      return tonNode_preparedProofLink::fetch(p);
    case tonNode_preparedState::ID:
      return tonNode_preparedState::fetch(p);
    case tonNode_notFoundState::ID:
      return tonNode_notFoundState::fetch(p);
    case tonNode_sessionId::ID:
      return tonNode_sessionId::fetch(p);
    case tonNode_shardPublicOverlayId::ID:
      return tonNode_shardPublicOverlayId::fetch(p);
    case tonNode_success::ID:
      return tonNode_success::fetch(p);
    case tonNode_zeroStateIdExt::ID:
      return tonNode_zeroStateIdExt::fetch(p);
    case validator_group::ID:
      return validator_group::fetch(p);
    case validator_groupEx::ID:
      return validator_groupEx::fetch(p);
    case validator_groupNew::ID:
      return validator_groupNew::fetch(p);
    case validator_config_global::ID:
      return validator_config_global::fetch(p);
    case validator_config_local::ID:
      return validator_config_local::fetch(p);
    case validator_config_random_local::ID:
      return validator_config_random_local::fetch(p);
    case validatorSession_blockUpdate::ID:
      return validatorSession_blockUpdate::fetch(p);
    case validatorSession_candidate::ID:
      return validatorSession_candidate::fetch(p);
    case validatorSession_candidateId::ID:
      return validatorSession_candidateId::fetch(p);
    case validatorSession_config::ID:
      return validatorSession_config::fetch(p);
    case validatorSession_configNew::ID:
      return validatorSession_configNew::fetch(p);
    case validatorSession_message_startSession::ID:
      return validatorSession_message_startSession::fetch(p);
    case validatorSession_message_finishSession::ID:
      return validatorSession_message_finishSession::fetch(p);
    case validatorSession_pong::ID:
      return validatorSession_pong::fetch(p);
    case validatorSession_round_id::ID:
      return validatorSession_round_id::fetch(p);
    case validatorSession_message_submittedBlock::ID:
      return validatorSession_message_submittedBlock::fetch(p);
    case validatorSession_message_approvedBlock::ID:
      return validatorSession_message_approvedBlock::fetch(p);
    case validatorSession_message_rejectedBlock::ID:
      return validatorSession_message_rejectedBlock::fetch(p);
    case validatorSession_message_commit::ID:
      return validatorSession_message_commit::fetch(p);
    case validatorSession_message_vote::ID:
      return validatorSession_message_vote::fetch(p);
    case validatorSession_message_voteFor::ID:
      return validatorSession_message_voteFor::fetch(p);
    case validatorSession_message_precommit::ID:
      return validatorSession_message_precommit::fetch(p);
    case validatorSession_message_empty::ID:
      return validatorSession_message_empty::fetch(p);
    case validatorSession_candidate_id::ID:
      return validatorSession_candidate_id::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

object_ptr<Function> Function::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case adnl_ping::ID:
      return adnl_ping::fetch(p);
    case catchain_getBlock::ID:
      return catchain_getBlock::fetch(p);
    case catchain_getBlockHistory::ID:
      return catchain_getBlockHistory::fetch(p);
    case catchain_getBlocks::ID:
      return catchain_getBlocks::fetch(p);
    case catchain_getDifference::ID:
      return catchain_getDifference::fetch(p);
    case dht_findNode::ID:
      return dht_findNode::fetch(p);
    case dht_findValue::ID:
      return dht_findValue::fetch(p);
    case dht_getSignedAddressList::ID:
      return dht_getSignedAddressList::fetch(p);
    case dht_ping::ID:
      return dht_ping::fetch(p);
    case dht_query::ID:
      return dht_query::fetch(p);
    case dht_store::ID:
      return dht_store::fetch(p);
    case engine_validator_addAdnlId::ID:
      return engine_validator_addAdnlId::fetch(p);
    case engine_validator_addControlInterface::ID:
      return engine_validator_addControlInterface::fetch(p);
    case engine_validator_addControlProcess::ID:
      return engine_validator_addControlProcess::fetch(p);
    case engine_validator_addDhtId::ID:
      return engine_validator_addDhtId::fetch(p);
    case engine_validator_addListeningPort::ID:
      return engine_validator_addListeningPort::fetch(p);
    case engine_validator_addLiteserver::ID:
      return engine_validator_addLiteserver::fetch(p);
    case engine_validator_addProxy::ID:
      return engine_validator_addProxy::fetch(p);
    case engine_validator_addValidatorAdnlAddress::ID:
      return engine_validator_addValidatorAdnlAddress::fetch(p);
    case engine_validator_addValidatorPermanentKey::ID:
      return engine_validator_addValidatorPermanentKey::fetch(p);
    case engine_validator_addValidatorTempKey::ID:
      return engine_validator_addValidatorTempKey::fetch(p);
    case engine_validator_changeFullNodeAdnlAddress::ID:
      return engine_validator_changeFullNodeAdnlAddress::fetch(p);
    case engine_validator_checkDhtServers::ID:
      return engine_validator_checkDhtServers::fetch(p);
    case engine_validator_controlQuery::ID:
      return engine_validator_controlQuery::fetch(p);
    case engine_validator_createElectionBid::ID:
      return engine_validator_createElectionBid::fetch(p);
    case engine_validator_createProposalVote::ID:
      return engine_validator_createProposalVote::fetch(p);
    case engine_validator_delAdnlId::ID:
      return engine_validator_delAdnlId::fetch(p);
    case engine_validator_delDhtId::ID:
      return engine_validator_delDhtId::fetch(p);
    case engine_validator_delListeningPort::ID:
      return engine_validator_delListeningPort::fetch(p);
    case engine_validator_delProxy::ID:
      return engine_validator_delProxy::fetch(p);
    case engine_validator_delValidatorAdnlAddress::ID:
      return engine_validator_delValidatorAdnlAddress::fetch(p);
    case engine_validator_delValidatorPermanentKey::ID:
      return engine_validator_delValidatorPermanentKey::fetch(p);
    case engine_validator_delValidatorTempKey::ID:
      return engine_validator_delValidatorTempKey::fetch(p);
    case engine_validator_exportPrivateKey::ID:
      return engine_validator_exportPrivateKey::fetch(p);
    case engine_validator_exportPublicKey::ID:
      return engine_validator_exportPublicKey::fetch(p);
    case engine_validator_generateKeyPair::ID:
      return engine_validator_generateKeyPair::fetch(p);
    case engine_validator_getConfig::ID:
      return engine_validator_getConfig::fetch(p);
    case engine_validator_getStats::ID:
      return engine_validator_getStats::fetch(p);
    case engine_validator_getTime::ID:
      return engine_validator_getTime::fetch(p);
    case engine_validator_importPrivateKey::ID:
      return engine_validator_importPrivateKey::fetch(p);
    case engine_validator_setVerbosity::ID:
      return engine_validator_setVerbosity::fetch(p);
    case engine_validator_sign::ID:
      return engine_validator_sign::fetch(p);
    case getTestObject::ID:
      return getTestObject::fetch(p);
    case http_getNextPayloadPart::ID:
      return http_getNextPayloadPart::fetch(p);
    case http_request::ID:
      return http_request::fetch(p);
    case overlay_getBroadcast::ID:
      return overlay_getBroadcast::fetch(p);
    case overlay_getBroadcastList::ID:
      return overlay_getBroadcastList::fetch(p);
    case overlay_getRandomPeers::ID:
      return overlay_getRandomPeers::fetch(p);
    case overlay_query::ID:
      return overlay_query::fetch(p);
    case tcp_ping::ID:
      return tcp_ping::fetch(p);
    case tonNode_downloadBlock::ID:
      return tonNode_downloadBlock::fetch(p);
    case tonNode_downloadBlockFull::ID:
      return tonNode_downloadBlockFull::fetch(p);
    case tonNode_downloadBlockProof::ID:
      return tonNode_downloadBlockProof::fetch(p);
    case tonNode_downloadBlockProofLink::ID:
      return tonNode_downloadBlockProofLink::fetch(p);
    case tonNode_downloadBlockProofLinks::ID:
      return tonNode_downloadBlockProofLinks::fetch(p);
    case tonNode_downloadBlockProofs::ID:
      return tonNode_downloadBlockProofs::fetch(p);
    case tonNode_downloadBlocks::ID:
      return tonNode_downloadBlocks::fetch(p);
    case tonNode_downloadKeyBlockProof::ID:
      return tonNode_downloadKeyBlockProof::fetch(p);
    case tonNode_downloadKeyBlockProofLink::ID:
      return tonNode_downloadKeyBlockProofLink::fetch(p);
    case tonNode_downloadKeyBlockProofLinks::ID:
      return tonNode_downloadKeyBlockProofLinks::fetch(p);
    case tonNode_downloadKeyBlockProofs::ID:
      return tonNode_downloadKeyBlockProofs::fetch(p);
    case tonNode_downloadNextBlockFull::ID:
      return tonNode_downloadNextBlockFull::fetch(p);
    case tonNode_downloadPersistentState::ID:
      return tonNode_downloadPersistentState::fetch(p);
    case tonNode_downloadPersistentStateSlice::ID:
      return tonNode_downloadPersistentStateSlice::fetch(p);
    case tonNode_downloadZeroState::ID:
      return tonNode_downloadZeroState::fetch(p);
    case tonNode_getArchiveInfo::ID:
      return tonNode_getArchiveInfo::fetch(p);
    case tonNode_getArchiveSlice::ID:
      return tonNode_getArchiveSlice::fetch(p);
    case tonNode_getCapabilities::ID:
      return tonNode_getCapabilities::fetch(p);
    case tonNode_getNextBlockDescription::ID:
      return tonNode_getNextBlockDescription::fetch(p);
    case tonNode_getNextBlocksDescription::ID:
      return tonNode_getNextBlocksDescription::fetch(p);
    case tonNode_getNextKeyBlockIds::ID:
      return tonNode_getNextKeyBlockIds::fetch(p);
    case tonNode_getPrevBlocksDescription::ID:
      return tonNode_getPrevBlocksDescription::fetch(p);
    case tonNode_prepareBlock::ID:
      return tonNode_prepareBlock::fetch(p);
    case tonNode_prepareBlockProof::ID:
      return tonNode_prepareBlockProof::fetch(p);
    case tonNode_prepareBlockProofs::ID:
      return tonNode_prepareBlockProofs::fetch(p);
    case tonNode_prepareBlocks::ID:
      return tonNode_prepareBlocks::fetch(p);
    case tonNode_prepareKeyBlockProof::ID:
      return tonNode_prepareKeyBlockProof::fetch(p);
    case tonNode_prepareKeyBlockProofs::ID:
      return tonNode_prepareKeyBlockProofs::fetch(p);
    case tonNode_preparePersistentState::ID:
      return tonNode_preparePersistentState::fetch(p);
    case tonNode_prepareZeroState::ID:
      return tonNode_prepareZeroState::fetch(p);
    case tonNode_query::ID:
      return tonNode_query::fetch(p);
    case tonNode_slave_sendExtMessage::ID:
      return tonNode_slave_sendExtMessage::fetch(p);
    case validatorSession_downloadCandidate::ID:
      return validatorSession_downloadCandidate::fetch(p);
    case validatorSession_ping::ID:
      return validatorSession_ping::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

object_ptr<Hashable> Hashable::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case hashable_bool::ID:
      return hashable_bool::fetch(p);
    case hashable_int32::ID:
      return hashable_int32::fetch(p);
    case hashable_int64::ID:
      return hashable_int64::fetch(p);
    case hashable_int256::ID:
      return hashable_int256::fetch(p);
    case hashable_bytes::ID:
      return hashable_bytes::fetch(p);
    case hashable_pair::ID:
      return hashable_pair::fetch(p);
    case hashable_vector::ID:
      return hashable_vector::fetch(p);
    case hashable_validatorSessionOldRound::ID:
      return hashable_validatorSessionOldRound::fetch(p);
    case hashable_validatorSessionRoundAttempt::ID:
      return hashable_validatorSessionRoundAttempt::fetch(p);
    case hashable_validatorSessionRound::ID:
      return hashable_validatorSessionRound::fetch(p);
    case hashable_blockSignature::ID:
      return hashable_blockSignature::fetch(p);
    case hashable_sentBlock::ID:
      return hashable_sentBlock::fetch(p);
    case hashable_sentBlockEmpty::ID:
      return hashable_sentBlockEmpty::fetch(p);
    case hashable_vote::ID:
      return hashable_vote::fetch(p);
    case hashable_blockCandidate::ID:
      return hashable_blockCandidate::fetch(p);
    case hashable_blockVoteCandidate::ID:
      return hashable_blockVoteCandidate::fetch(p);
    case hashable_blockCandidateAttempt::ID:
      return hashable_blockCandidateAttempt::fetch(p);
    case hashable_cntVector::ID:
      return hashable_cntVector::fetch(p);
    case hashable_cntSortedVector::ID:
      return hashable_cntSortedVector::fetch(p);
    case hashable_validatorSession::ID:
      return hashable_validatorSession::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

hashable_bool::hashable_bool()
  : value_()
{}

hashable_bool::hashable_bool(bool value_)
  : value_(value_)
{}

const std::int32_t hashable_bool::ID;

object_ptr<Hashable> hashable_bool::fetch(td::TlParser &p) {
  return make_object<hashable_bool>(p);
}

hashable_bool::hashable_bool(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchBool::parse(p))
#undef FAIL
{}

void hashable_bool::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBool::store(value_, s);
}

void hashable_bool::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBool::store(value_, s);
}

void hashable_bool::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_bool");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

hashable_int32::hashable_int32()
  : value_()
{}

hashable_int32::hashable_int32(std::int32_t value_)
  : value_(value_)
{}

const std::int32_t hashable_int32::ID;

object_ptr<Hashable> hashable_int32::fetch(td::TlParser &p) {
  return make_object<hashable_int32>(p);
}

hashable_int32::hashable_int32(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_int32::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int32::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int32::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_int32");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

hashable_int64::hashable_int64()
  : value_()
{}

hashable_int64::hashable_int64(std::int64_t value_)
  : value_(value_)
{}

const std::int32_t hashable_int64::ID;

object_ptr<Hashable> hashable_int64::fetch(td::TlParser &p) {
  return make_object<hashable_int64>(p);
}

hashable_int64::hashable_int64(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchLong::parse(p))
#undef FAIL
{}

void hashable_int64::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int64::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int64::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_int64");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

hashable_int256::hashable_int256()
  : value_()
{}

hashable_int256::hashable_int256(td::Bits256 const &value_)
  : value_(value_)
{}

const std::int32_t hashable_int256::ID;

object_ptr<Hashable> hashable_int256::fetch(td::TlParser &p) {
  return make_object<hashable_int256>(p);
}

hashable_int256::hashable_int256(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchInt256::parse(p))
#undef FAIL
{}

void hashable_int256::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int256::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void hashable_int256::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_int256");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

hashable_bytes::hashable_bytes()
  : value_()
{}

hashable_bytes::hashable_bytes(td::BufferSlice &&value_)
  : value_(std::move(value_))
{}

const std::int32_t hashable_bytes::ID;

object_ptr<Hashable> hashable_bytes::fetch(td::TlParser &p) {
  return make_object<hashable_bytes>(p);
}

hashable_bytes::hashable_bytes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void hashable_bytes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(value_, s);
}

void hashable_bytes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(value_, s);
}

void hashable_bytes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_bytes");
    s.store_bytes_field("value", value_);
    s.store_class_end();
  }
}

hashable_pair::hashable_pair()
  : left_()
  , right_()
{}

hashable_pair::hashable_pair(std::int32_t left_, std::int32_t right_)
  : left_(left_)
  , right_(right_)
{}

const std::int32_t hashable_pair::ID;

object_ptr<Hashable> hashable_pair::fetch(td::TlParser &p) {
  return make_object<hashable_pair>(p);
}

hashable_pair::hashable_pair(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : left_(TlFetchInt::parse(p))
  , right_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_pair::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(left_, s);
  TlStoreBinary::store(right_, s);
}

void hashable_pair::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(left_, s);
  TlStoreBinary::store(right_, s);
}

void hashable_pair::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_pair");
    s.store_field("left", left_);
    s.store_field("right", right_);
    s.store_class_end();
  }
}

hashable_vector::hashable_vector()
  : value_()
{}

hashable_vector::hashable_vector(std::vector<std::int32_t> &&value_)
  : value_(std::move(value_))
{}

const std::int32_t hashable_vector::ID;

object_ptr<Hashable> hashable_vector::fetch(td::TlParser &p) {
  return make_object<hashable_vector>(p);
}

hashable_vector::hashable_vector(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void hashable_vector::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(value_, s);
}

void hashable_vector::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(value_, s);
}

void hashable_vector::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_vector");
    { const std::vector<std::int32_t> &v = value_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("value", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

hashable_validatorSessionOldRound::hashable_validatorSessionOldRound()
  : seqno_()
  , block_()
  , signatures_()
  , approve_signatures_()
{}

hashable_validatorSessionOldRound::hashable_validatorSessionOldRound(std::int32_t seqno_, std::int32_t block_, std::int32_t signatures_, std::int32_t approve_signatures_)
  : seqno_(seqno_)
  , block_(block_)
  , signatures_(signatures_)
  , approve_signatures_(approve_signatures_)
{}

const std::int32_t hashable_validatorSessionOldRound::ID;

object_ptr<Hashable> hashable_validatorSessionOldRound::fetch(td::TlParser &p) {
  return make_object<hashable_validatorSessionOldRound>(p);
}

hashable_validatorSessionOldRound::hashable_validatorSessionOldRound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : seqno_(TlFetchInt::parse(p))
  , block_(TlFetchInt::parse(p))
  , signatures_(TlFetchInt::parse(p))
  , approve_signatures_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_validatorSessionOldRound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(signatures_, s);
  TlStoreBinary::store(approve_signatures_, s);
}

void hashable_validatorSessionOldRound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(signatures_, s);
  TlStoreBinary::store(approve_signatures_, s);
}

void hashable_validatorSessionOldRound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_validatorSessionOldRound");
    s.store_field("seqno", seqno_);
    s.store_field("block", block_);
    s.store_field("signatures", signatures_);
    s.store_field("approve_signatures", approve_signatures_);
    s.store_class_end();
  }
}

hashable_validatorSessionRoundAttempt::hashable_validatorSessionRoundAttempt()
  : seqno_()
  , votes_()
  , precommitted_()
  , vote_for_inited_()
  , vote_for_()
{}

hashable_validatorSessionRoundAttempt::hashable_validatorSessionRoundAttempt(std::int32_t seqno_, std::int32_t votes_, std::int32_t precommitted_, std::int32_t vote_for_inited_, std::int32_t vote_for_)
  : seqno_(seqno_)
  , votes_(votes_)
  , precommitted_(precommitted_)
  , vote_for_inited_(vote_for_inited_)
  , vote_for_(vote_for_)
{}

const std::int32_t hashable_validatorSessionRoundAttempt::ID;

object_ptr<Hashable> hashable_validatorSessionRoundAttempt::fetch(td::TlParser &p) {
  return make_object<hashable_validatorSessionRoundAttempt>(p);
}

hashable_validatorSessionRoundAttempt::hashable_validatorSessionRoundAttempt(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : seqno_(TlFetchInt::parse(p))
  , votes_(TlFetchInt::parse(p))
  , precommitted_(TlFetchInt::parse(p))
  , vote_for_inited_(TlFetchInt::parse(p))
  , vote_for_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_validatorSessionRoundAttempt::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(votes_, s);
  TlStoreBinary::store(precommitted_, s);
  TlStoreBinary::store(vote_for_inited_, s);
  TlStoreBinary::store(vote_for_, s);
}

void hashable_validatorSessionRoundAttempt::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(votes_, s);
  TlStoreBinary::store(precommitted_, s);
  TlStoreBinary::store(vote_for_inited_, s);
  TlStoreBinary::store(vote_for_, s);
}

void hashable_validatorSessionRoundAttempt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_validatorSessionRoundAttempt");
    s.store_field("seqno", seqno_);
    s.store_field("votes", votes_);
    s.store_field("precommitted", precommitted_);
    s.store_field("vote_for_inited", vote_for_inited_);
    s.store_field("vote_for", vote_for_);
    s.store_class_end();
  }
}

hashable_validatorSessionRound::hashable_validatorSessionRound()
  : locked_round_()
  , locked_block_()
  , seqno_()
  , precommitted_()
  , first_attempt_()
  , approved_blocks_()
  , signatures_()
  , attempts_()
{}

hashable_validatorSessionRound::hashable_validatorSessionRound(std::int32_t locked_round_, std::int32_t locked_block_, std::int32_t seqno_, bool precommitted_, std::int32_t first_attempt_, std::int32_t approved_blocks_, std::int32_t signatures_, std::int32_t attempts_)
  : locked_round_(locked_round_)
  , locked_block_(locked_block_)
  , seqno_(seqno_)
  , precommitted_(precommitted_)
  , first_attempt_(first_attempt_)
  , approved_blocks_(approved_blocks_)
  , signatures_(signatures_)
  , attempts_(attempts_)
{}

const std::int32_t hashable_validatorSessionRound::ID;

object_ptr<Hashable> hashable_validatorSessionRound::fetch(td::TlParser &p) {
  return make_object<hashable_validatorSessionRound>(p);
}

hashable_validatorSessionRound::hashable_validatorSessionRound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : locked_round_(TlFetchInt::parse(p))
  , locked_block_(TlFetchInt::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , precommitted_(TlFetchBool::parse(p))
  , first_attempt_(TlFetchInt::parse(p))
  , approved_blocks_(TlFetchInt::parse(p))
  , signatures_(TlFetchInt::parse(p))
  , attempts_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_validatorSessionRound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(locked_round_, s);
  TlStoreBinary::store(locked_block_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBool::store(precommitted_, s);
  TlStoreBinary::store(first_attempt_, s);
  TlStoreBinary::store(approved_blocks_, s);
  TlStoreBinary::store(signatures_, s);
  TlStoreBinary::store(attempts_, s);
}

void hashable_validatorSessionRound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(locked_round_, s);
  TlStoreBinary::store(locked_block_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBool::store(precommitted_, s);
  TlStoreBinary::store(first_attempt_, s);
  TlStoreBinary::store(approved_blocks_, s);
  TlStoreBinary::store(signatures_, s);
  TlStoreBinary::store(attempts_, s);
}

void hashable_validatorSessionRound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_validatorSessionRound");
    s.store_field("locked_round", locked_round_);
    s.store_field("locked_block", locked_block_);
    s.store_field("seqno", seqno_);
    s.store_field("precommitted", precommitted_);
    s.store_field("first_attempt", first_attempt_);
    s.store_field("approved_blocks", approved_blocks_);
    s.store_field("signatures", signatures_);
    s.store_field("attempts", attempts_);
    s.store_class_end();
  }
}

hashable_blockSignature::hashable_blockSignature()
  : signature_()
{}

hashable_blockSignature::hashable_blockSignature(std::int32_t signature_)
  : signature_(signature_)
{}

const std::int32_t hashable_blockSignature::ID;

object_ptr<Hashable> hashable_blockSignature::fetch(td::TlParser &p) {
  return make_object<hashable_blockSignature>(p);
}

hashable_blockSignature::hashable_blockSignature(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : signature_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_blockSignature::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(signature_, s);
}

void hashable_blockSignature::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(signature_, s);
}

void hashable_blockSignature::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_blockSignature");
    s.store_field("signature", signature_);
    s.store_class_end();
  }
}

hashable_sentBlock::hashable_sentBlock()
  : src_()
  , root_hash_()
  , file_hash_()
  , collated_data_file_hash_()
{}

hashable_sentBlock::hashable_sentBlock(std::int32_t src_, std::int32_t root_hash_, std::int32_t file_hash_, std::int32_t collated_data_file_hash_)
  : src_(src_)
  , root_hash_(root_hash_)
  , file_hash_(file_hash_)
  , collated_data_file_hash_(collated_data_file_hash_)
{}

const std::int32_t hashable_sentBlock::ID;

object_ptr<Hashable> hashable_sentBlock::fetch(td::TlParser &p) {
  return make_object<hashable_sentBlock>(p);
}

hashable_sentBlock::hashable_sentBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt::parse(p))
  , root_hash_(TlFetchInt::parse(p))
  , file_hash_(TlFetchInt::parse(p))
  , collated_data_file_hash_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_sentBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void hashable_sentBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void hashable_sentBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_sentBlock");
    s.store_field("src", src_);
    s.store_field("root_hash", root_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_field("collated_data_file_hash", collated_data_file_hash_);
    s.store_class_end();
  }
}

hashable_sentBlockEmpty::hashable_sentBlockEmpty() {
}

const std::int32_t hashable_sentBlockEmpty::ID;

object_ptr<Hashable> hashable_sentBlockEmpty::fetch(td::TlParser &p) {
  return make_object<hashable_sentBlockEmpty>(p);
}

hashable_sentBlockEmpty::hashable_sentBlockEmpty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void hashable_sentBlockEmpty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void hashable_sentBlockEmpty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void hashable_sentBlockEmpty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_sentBlockEmpty");
    s.store_class_end();
  }
}

hashable_vote::hashable_vote()
  : block_()
  , node_()
{}

hashable_vote::hashable_vote(std::int32_t block_, std::int32_t node_)
  : block_(block_)
  , node_(node_)
{}

const std::int32_t hashable_vote::ID;

object_ptr<Hashable> hashable_vote::fetch(td::TlParser &p) {
  return make_object<hashable_vote>(p);
}

hashable_vote::hashable_vote(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt::parse(p))
  , node_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_vote::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(node_, s);
}

void hashable_vote::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(node_, s);
}

void hashable_vote::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_vote");
    s.store_field("block", block_);
    s.store_field("node", node_);
    s.store_class_end();
  }
}

hashable_blockCandidate::hashable_blockCandidate()
  : block_()
  , approved_()
{}

hashable_blockCandidate::hashable_blockCandidate(std::int32_t block_, std::int32_t approved_)
  : block_(block_)
  , approved_(approved_)
{}

const std::int32_t hashable_blockCandidate::ID;

object_ptr<Hashable> hashable_blockCandidate::fetch(td::TlParser &p) {
  return make_object<hashable_blockCandidate>(p);
}

hashable_blockCandidate::hashable_blockCandidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt::parse(p))
  , approved_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_blockCandidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(approved_, s);
}

void hashable_blockCandidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(approved_, s);
}

void hashable_blockCandidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_blockCandidate");
    s.store_field("block", block_);
    s.store_field("approved", approved_);
    s.store_class_end();
  }
}

hashable_blockVoteCandidate::hashable_blockVoteCandidate()
  : block_()
  , approved_()
{}

hashable_blockVoteCandidate::hashable_blockVoteCandidate(std::int32_t block_, std::int32_t approved_)
  : block_(block_)
  , approved_(approved_)
{}

const std::int32_t hashable_blockVoteCandidate::ID;

object_ptr<Hashable> hashable_blockVoteCandidate::fetch(td::TlParser &p) {
  return make_object<hashable_blockVoteCandidate>(p);
}

hashable_blockVoteCandidate::hashable_blockVoteCandidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt::parse(p))
  , approved_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_blockVoteCandidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(approved_, s);
}

void hashable_blockVoteCandidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(approved_, s);
}

void hashable_blockVoteCandidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_blockVoteCandidate");
    s.store_field("block", block_);
    s.store_field("approved", approved_);
    s.store_class_end();
  }
}

hashable_blockCandidateAttempt::hashable_blockCandidateAttempt()
  : block_()
  , votes_()
{}

hashable_blockCandidateAttempt::hashable_blockCandidateAttempt(std::int32_t block_, std::int32_t votes_)
  : block_(block_)
  , votes_(votes_)
{}

const std::int32_t hashable_blockCandidateAttempt::ID;

object_ptr<Hashable> hashable_blockCandidateAttempt::fetch(td::TlParser &p) {
  return make_object<hashable_blockCandidateAttempt>(p);
}

hashable_blockCandidateAttempt::hashable_blockCandidateAttempt(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt::parse(p))
  , votes_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_blockCandidateAttempt::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(votes_, s);
}

void hashable_blockCandidateAttempt::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(votes_, s);
}

void hashable_blockCandidateAttempt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_blockCandidateAttempt");
    s.store_field("block", block_);
    s.store_field("votes", votes_);
    s.store_class_end();
  }
}

hashable_cntVector::hashable_cntVector()
  : data_()
{}

hashable_cntVector::hashable_cntVector(std::int32_t data_)
  : data_(data_)
{}

const std::int32_t hashable_cntVector::ID;

object_ptr<Hashable> hashable_cntVector::fetch(td::TlParser &p) {
  return make_object<hashable_cntVector>(p);
}

hashable_cntVector::hashable_cntVector(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_cntVector::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_, s);
}

void hashable_cntVector::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_, s);
}

void hashable_cntVector::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_cntVector");
    s.store_field("data", data_);
    s.store_class_end();
  }
}

hashable_cntSortedVector::hashable_cntSortedVector()
  : data_()
{}

hashable_cntSortedVector::hashable_cntSortedVector(std::int32_t data_)
  : data_(data_)
{}

const std::int32_t hashable_cntSortedVector::ID;

object_ptr<Hashable> hashable_cntSortedVector::fetch(td::TlParser &p) {
  return make_object<hashable_cntSortedVector>(p);
}

hashable_cntSortedVector::hashable_cntSortedVector(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_cntSortedVector::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_, s);
}

void hashable_cntSortedVector::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_, s);
}

void hashable_cntSortedVector::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_cntSortedVector");
    s.store_field("data", data_);
    s.store_class_end();
  }
}

hashable_validatorSession::hashable_validatorSession()
  : ts_()
  , old_rounds_()
  , cur_round_()
{}

hashable_validatorSession::hashable_validatorSession(std::int32_t ts_, std::int32_t old_rounds_, std::int32_t cur_round_)
  : ts_(ts_)
  , old_rounds_(old_rounds_)
  , cur_round_(cur_round_)
{}

const std::int32_t hashable_validatorSession::ID;

object_ptr<Hashable> hashable_validatorSession::fetch(td::TlParser &p) {
  return make_object<hashable_validatorSession>(p);
}

hashable_validatorSession::hashable_validatorSession(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ts_(TlFetchInt::parse(p))
  , old_rounds_(TlFetchInt::parse(p))
  , cur_round_(TlFetchInt::parse(p))
#undef FAIL
{}

void hashable_validatorSession::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ts_, s);
  TlStoreBinary::store(old_rounds_, s);
  TlStoreBinary::store(cur_round_, s);
}

void hashable_validatorSession::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ts_, s);
  TlStoreBinary::store(old_rounds_, s);
  TlStoreBinary::store(cur_round_, s);
}

void hashable_validatorSession::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "hashable_validatorSession");
    s.store_field("ts", ts_);
    s.store_field("old_rounds", old_rounds_);
    s.store_field("cur_round", cur_round_);
    s.store_class_end();
  }
}

object_ptr<PrivateKey> PrivateKey::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case pk_unenc::ID:
      return pk_unenc::fetch(p);
    case pk_ed25519::ID:
      return pk_ed25519::fetch(p);
    case pk_aes::ID:
      return pk_aes::fetch(p);
    case pk_overlay::ID:
      return pk_overlay::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

pk_unenc::pk_unenc()
  : data_()
{}

pk_unenc::pk_unenc(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t pk_unenc::ID;

object_ptr<PrivateKey> pk_unenc::fetch(td::TlParser &p) {
  return make_object<pk_unenc>(p);
}

pk_unenc::pk_unenc(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void pk_unenc::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void pk_unenc::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void pk_unenc::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pk_unenc");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

pk_ed25519::pk_ed25519()
  : key_()
{}

pk_ed25519::pk_ed25519(td::Bits256 const &key_)
  : key_(key_)
{}

const std::int32_t pk_ed25519::ID;

object_ptr<PrivateKey> pk_ed25519::fetch(td::TlParser &p) {
  return make_object<pk_ed25519>(p);
}

pk_ed25519::pk_ed25519(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
#undef FAIL
{}

void pk_ed25519::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pk_ed25519::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pk_ed25519::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pk_ed25519");
    s.store_field("key", key_);
    s.store_class_end();
  }
}

pk_aes::pk_aes()
  : key_()
{}

pk_aes::pk_aes(td::Bits256 const &key_)
  : key_(key_)
{}

const std::int32_t pk_aes::ID;

object_ptr<PrivateKey> pk_aes::fetch(td::TlParser &p) {
  return make_object<pk_aes>(p);
}

pk_aes::pk_aes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
#undef FAIL
{}

void pk_aes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pk_aes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pk_aes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pk_aes");
    s.store_field("key", key_);
    s.store_class_end();
  }
}

pk_overlay::pk_overlay()
  : name_()
{}

pk_overlay::pk_overlay(td::BufferSlice &&name_)
  : name_(std::move(name_))
{}

const std::int32_t pk_overlay::ID;

object_ptr<PrivateKey> pk_overlay::fetch(td::TlParser &p) {
  return make_object<pk_overlay>(p);
}

pk_overlay::pk_overlay(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : name_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void pk_overlay::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
}

void pk_overlay::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
}

void pk_overlay::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pk_overlay");
    s.store_bytes_field("name", name_);
    s.store_class_end();
  }
}

object_ptr<PublicKey> PublicKey::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case pub_unenc::ID:
      return pub_unenc::fetch(p);
    case pub_ed25519::ID:
      return pub_ed25519::fetch(p);
    case pub_aes::ID:
      return pub_aes::fetch(p);
    case pub_overlay::ID:
      return pub_overlay::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

pub_unenc::pub_unenc()
  : data_()
{}

pub_unenc::pub_unenc(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t pub_unenc::ID;

object_ptr<PublicKey> pub_unenc::fetch(td::TlParser &p) {
  return make_object<pub_unenc>(p);
}

pub_unenc::pub_unenc(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void pub_unenc::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void pub_unenc::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void pub_unenc::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pub_unenc");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

pub_ed25519::pub_ed25519()
  : key_()
{}

pub_ed25519::pub_ed25519(td::Bits256 const &key_)
  : key_(key_)
{}

const std::int32_t pub_ed25519::ID;

object_ptr<PublicKey> pub_ed25519::fetch(td::TlParser &p) {
  return make_object<pub_ed25519>(p);
}

pub_ed25519::pub_ed25519(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
#undef FAIL
{}

void pub_ed25519::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pub_ed25519::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pub_ed25519::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pub_ed25519");
    s.store_field("key", key_);
    s.store_class_end();
  }
}

pub_aes::pub_aes()
  : key_()
{}

pub_aes::pub_aes(td::Bits256 const &key_)
  : key_(key_)
{}

const std::int32_t pub_aes::ID;

object_ptr<PublicKey> pub_aes::fetch(td::TlParser &p) {
  return make_object<pub_aes>(p);
}

pub_aes::pub_aes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
#undef FAIL
{}

void pub_aes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pub_aes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
}

void pub_aes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pub_aes");
    s.store_field("key", key_);
    s.store_class_end();
  }
}

pub_overlay::pub_overlay()
  : name_()
{}

pub_overlay::pub_overlay(td::BufferSlice &&name_)
  : name_(std::move(name_))
{}

const std::int32_t pub_overlay::ID;

object_ptr<PublicKey> pub_overlay::fetch(td::TlParser &p) {
  return make_object<pub_overlay>(p);
}

pub_overlay::pub_overlay(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : name_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void pub_overlay::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
}

void pub_overlay::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
}

void pub_overlay::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "pub_overlay");
    s.store_bytes_field("name", name_);
    s.store_class_end();
  }
}

object_ptr<TestObject> TestObject::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case testObject::ID:
      return testObject::fetch(p);
    case testString::ID:
      return testString::fetch(p);
    case testInt::ID:
      return testInt::fetch(p);
    case testVectorBytes::ID:
      return testVectorBytes::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

testObject::testObject()
  : value_()
  , o_()
  , f_()
{}

testObject::testObject(std::int32_t value_, object_ptr<Object> &&o_, object_ptr<Function> &&f_)
  : value_(value_)
  , o_(std::move(o_))
  , f_(std::move(f_))
{}

const std::int32_t testObject::ID;

object_ptr<TestObject> testObject::fetch(td::TlParser &p) {
  return make_object<testObject>(p);
}

testObject::testObject(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchInt::parse(p))
  , o_(TlFetchObject<Object>::parse(p))
  , f_(TlFetchObject<Function>::parse(p))
#undef FAIL
{}

void testObject::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
  TlStoreObject::store(o_, s);
  TlStoreObject::store(f_, s);
}

void testObject::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
  TlStoreObject::store(o_, s);
  TlStoreObject::store(f_, s);
}

void testObject::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testObject");
    s.store_field("value", value_);
    if (o_ == nullptr) { s.store_field("o", "null"); } else { o_->store(s, "o"); }
    if (f_ == nullptr) { s.store_field("f", "null"); } else { f_->store(s, "f"); }
    s.store_class_end();
  }
}

testString::testString()
  : value_()
{}

testString::testString(std::string const &value_)
  : value_(std::move(value_))
{}

const std::int32_t testString::ID;

object_ptr<TestObject> testString::fetch(td::TlParser &p) {
  return make_object<testString>(p);
}

testString::testString(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void testString::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(value_, s);
}

void testString::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(value_, s);
}

void testString::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testString");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

testInt::testInt()
  : value_()
{}

testInt::testInt(std::int32_t value_)
  : value_(value_)
{}

const std::int32_t testInt::ID;

object_ptr<TestObject> testInt::fetch(td::TlParser &p) {
  return make_object<testInt>(p);
}

testInt::testInt(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchInt::parse(p))
#undef FAIL
{}

void testInt::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void testInt::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void testInt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testInt");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

testVectorBytes::testVectorBytes()
  : value_()
{}

testVectorBytes::testVectorBytes(std::vector<td::BufferSlice> &&value_)
  : value_(std::move(value_))
{}

const std::int32_t testVectorBytes::ID;

object_ptr<TestObject> testVectorBytes::fetch(td::TlParser &p) {
  return make_object<testVectorBytes>(p);
}

testVectorBytes::testVectorBytes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchVector<TlFetchBytes<td::BufferSlice>>::parse(p))
#undef FAIL
{}

void testVectorBytes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(value_, s);
}

void testVectorBytes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(value_, s);
}

void testVectorBytes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testVectorBytes");
    { const std::vector<td::BufferSlice> &v = value_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("value", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_bytes_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

object_ptr<adnl_Address> adnl_Address::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case adnl_address_udp::ID:
      return adnl_address_udp::fetch(p);
    case adnl_address_udp6::ID:
      return adnl_address_udp6::fetch(p);
    case adnl_address_tunnel::ID:
      return adnl_address_tunnel::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

adnl_address_udp::adnl_address_udp()
  : ip_()
  , port_()
{}

adnl_address_udp::adnl_address_udp(std::int32_t ip_, std::int32_t port_)
  : ip_(ip_)
  , port_(port_)
{}

const std::int32_t adnl_address_udp::ID;

object_ptr<adnl_Address> adnl_address_udp::fetch(td::TlParser &p) {
  return make_object<adnl_address_udp>(p);
}

adnl_address_udp::adnl_address_udp(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_address_udp::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_address_udp::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_address_udp::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_address_udp");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

adnl_address_udp6::adnl_address_udp6()
  : ip_()
  , port_()
{}

adnl_address_udp6::adnl_address_udp6(td::Bits128 const &ip_, std::int32_t port_)
  : ip_(ip_)
  , port_(port_)
{}

const std::int32_t adnl_address_udp6::ID;

object_ptr<adnl_Address> adnl_address_udp6::fetch(td::TlParser &p) {
  return make_object<adnl_address_udp6>(p);
}

adnl_address_udp6::adnl_address_udp6(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt128::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_address_udp6::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_address_udp6::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_address_udp6::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_address_udp6");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

adnl_address_tunnel::adnl_address_tunnel()
  : to_()
  , pubkey_()
{}

adnl_address_tunnel::adnl_address_tunnel(td::Bits256 const &to_, object_ptr<PublicKey> &&pubkey_)
  : to_(to_)
  , pubkey_(std::move(pubkey_))
{}

const std::int32_t adnl_address_tunnel::ID;

object_ptr<adnl_Address> adnl_address_tunnel::fetch(td::TlParser &p) {
  return make_object<adnl_address_tunnel>(p);
}

adnl_address_tunnel::adnl_address_tunnel(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : to_(TlFetchInt256::parse(p))
  , pubkey_(TlFetchObject<PublicKey>::parse(p))
#undef FAIL
{}

void adnl_address_tunnel::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(to_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(pubkey_, s);
}

void adnl_address_tunnel::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(to_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(pubkey_, s);
}

void adnl_address_tunnel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_address_tunnel");
    s.store_field("to", to_);
    if (pubkey_ == nullptr) { s.store_field("pubkey", "null"); } else { pubkey_->store(s, "pubkey"); }
    s.store_class_end();
  }
}

adnl_addressList::adnl_addressList()
  : addrs_()
  , version_()
  , reinit_date_()
  , priority_()
  , expire_at_()
{}

adnl_addressList::adnl_addressList(std::vector<object_ptr<adnl_Address>> &&addrs_, std::int32_t version_, std::int32_t reinit_date_, std::int32_t priority_, std::int32_t expire_at_)
  : addrs_(std::move(addrs_))
  , version_(version_)
  , reinit_date_(reinit_date_)
  , priority_(priority_)
  , expire_at_(expire_at_)
{}

const std::int32_t adnl_addressList::ID;

object_ptr<adnl_addressList> adnl_addressList::fetch(td::TlParser &p) {
  return make_object<adnl_addressList>(p);
}

adnl_addressList::adnl_addressList(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : addrs_(TlFetchVector<TlFetchObject<adnl_Address>>::parse(p))
  , version_(TlFetchInt::parse(p))
  , reinit_date_(TlFetchInt::parse(p))
  , priority_(TlFetchInt::parse(p))
  , expire_at_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_addressList::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(addrs_, s);
  TlStoreBinary::store(version_, s);
  TlStoreBinary::store(reinit_date_, s);
  TlStoreBinary::store(priority_, s);
  TlStoreBinary::store(expire_at_, s);
}

void adnl_addressList::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(addrs_, s);
  TlStoreBinary::store(version_, s);
  TlStoreBinary::store(reinit_date_, s);
  TlStoreBinary::store(priority_, s);
  TlStoreBinary::store(expire_at_, s);
}

void adnl_addressList::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_addressList");
    { const std::vector<object_ptr<adnl_Address>> &v = addrs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("addrs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("version", version_);
    s.store_field("reinit_date", reinit_date_);
    s.store_field("priority", priority_);
    s.store_field("expire_at", expire_at_);
    s.store_class_end();
  }
}

object_ptr<adnl_Message> adnl_Message::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case adnl_message_createChannel::ID:
      return adnl_message_createChannel::fetch(p);
    case adnl_message_confirmChannel::ID:
      return adnl_message_confirmChannel::fetch(p);
    case adnl_message_custom::ID:
      return adnl_message_custom::fetch(p);
    case adnl_message_nop::ID:
      return adnl_message_nop::fetch(p);
    case adnl_message_reinit::ID:
      return adnl_message_reinit::fetch(p);
    case adnl_message_query::ID:
      return adnl_message_query::fetch(p);
    case adnl_message_answer::ID:
      return adnl_message_answer::fetch(p);
    case adnl_message_part::ID:
      return adnl_message_part::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

adnl_message_createChannel::adnl_message_createChannel()
  : key_()
  , date_()
{}

adnl_message_createChannel::adnl_message_createChannel(td::Bits256 const &key_, std::int32_t date_)
  : key_(key_)
  , date_(date_)
{}

const std::int32_t adnl_message_createChannel::ID;

object_ptr<adnl_Message> adnl_message_createChannel::fetch(td::TlParser &p) {
  return make_object<adnl_message_createChannel>(p);
}

adnl_message_createChannel::adnl_message_createChannel(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
  , date_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_message_createChannel::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_createChannel::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_createChannel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_createChannel");
    s.store_field("key", key_);
    s.store_field("date", date_);
    s.store_class_end();
  }
}

adnl_message_confirmChannel::adnl_message_confirmChannel()
  : key_()
  , peer_key_()
  , date_()
{}

adnl_message_confirmChannel::adnl_message_confirmChannel(td::Bits256 const &key_, td::Bits256 const &peer_key_, std::int32_t date_)
  : key_(key_)
  , peer_key_(peer_key_)
  , date_(date_)
{}

const std::int32_t adnl_message_confirmChannel::ID;

object_ptr<adnl_Message> adnl_message_confirmChannel::fetch(td::TlParser &p) {
  return make_object<adnl_message_confirmChannel>(p);
}

adnl_message_confirmChannel::adnl_message_confirmChannel(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
  , peer_key_(TlFetchInt256::parse(p))
  , date_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_message_confirmChannel::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(peer_key_, s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_confirmChannel::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(peer_key_, s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_confirmChannel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_confirmChannel");
    s.store_field("key", key_);
    s.store_field("peer_key", peer_key_);
    s.store_field("date", date_);
    s.store_class_end();
  }
}

adnl_message_custom::adnl_message_custom()
  : data_()
{}

adnl_message_custom::adnl_message_custom(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t adnl_message_custom::ID;

object_ptr<adnl_Message> adnl_message_custom::fetch(td::TlParser &p) {
  return make_object<adnl_message_custom>(p);
}

adnl_message_custom::adnl_message_custom(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void adnl_message_custom::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void adnl_message_custom::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void adnl_message_custom::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_custom");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

adnl_message_nop::adnl_message_nop() {
}

const std::int32_t adnl_message_nop::ID;

object_ptr<adnl_Message> adnl_message_nop::fetch(td::TlParser &p) {
  return make_object<adnl_message_nop>(p);
}

adnl_message_nop::adnl_message_nop(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void adnl_message_nop::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void adnl_message_nop::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void adnl_message_nop::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_nop");
    s.store_class_end();
  }
}

adnl_message_reinit::adnl_message_reinit()
  : date_()
{}

adnl_message_reinit::adnl_message_reinit(std::int32_t date_)
  : date_(date_)
{}

const std::int32_t adnl_message_reinit::ID;

object_ptr<adnl_Message> adnl_message_reinit::fetch(td::TlParser &p) {
  return make_object<adnl_message_reinit>(p);
}

adnl_message_reinit::adnl_message_reinit(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : date_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_message_reinit::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_reinit::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(date_, s);
}

void adnl_message_reinit::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_reinit");
    s.store_field("date", date_);
    s.store_class_end();
  }
}

adnl_message_query::adnl_message_query()
  : query_id_()
  , query_()
{}

adnl_message_query::adnl_message_query(td::Bits256 const &query_id_, td::BufferSlice &&query_)
  : query_id_(query_id_)
  , query_(std::move(query_))
{}

const std::int32_t adnl_message_query::ID;

object_ptr<adnl_Message> adnl_message_query::fetch(td::TlParser &p) {
  return make_object<adnl_message_query>(p);
}

adnl_message_query::adnl_message_query(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : query_id_(TlFetchInt256::parse(p))
  , query_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void adnl_message_query::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(query_, s);
}

void adnl_message_query::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(query_, s);
}

void adnl_message_query::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_query");
    s.store_field("query_id", query_id_);
    s.store_bytes_field("query", query_);
    s.store_class_end();
  }
}

adnl_message_answer::adnl_message_answer()
  : query_id_()
  , answer_()
{}

adnl_message_answer::adnl_message_answer(td::Bits256 const &query_id_, td::BufferSlice &&answer_)
  : query_id_(query_id_)
  , answer_(std::move(answer_))
{}

const std::int32_t adnl_message_answer::ID;

object_ptr<adnl_Message> adnl_message_answer::fetch(td::TlParser &p) {
  return make_object<adnl_message_answer>(p);
}

adnl_message_answer::adnl_message_answer(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : query_id_(TlFetchInt256::parse(p))
  , answer_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void adnl_message_answer::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(answer_, s);
}

void adnl_message_answer::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(answer_, s);
}

void adnl_message_answer::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_answer");
    s.store_field("query_id", query_id_);
    s.store_bytes_field("answer", answer_);
    s.store_class_end();
  }
}

adnl_message_part::adnl_message_part()
  : hash_()
  , total_size_()
  , offset_()
  , data_()
{}

adnl_message_part::adnl_message_part(td::Bits256 const &hash_, std::int32_t total_size_, std::int32_t offset_, td::BufferSlice &&data_)
  : hash_(hash_)
  , total_size_(total_size_)
  , offset_(offset_)
  , data_(std::move(data_))
{}

const std::int32_t adnl_message_part::ID;

object_ptr<adnl_Message> adnl_message_part::fetch(td::TlParser &p) {
  return make_object<adnl_message_part>(p);
}

adnl_message_part::adnl_message_part(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
  , total_size_(TlFetchInt::parse(p))
  , offset_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void adnl_message_part::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
  TlStoreBinary::store(total_size_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreString::store(data_, s);
}

void adnl_message_part::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
  TlStoreBinary::store(total_size_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreString::store(data_, s);
}

void adnl_message_part::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_message_part");
    s.store_field("hash", hash_);
    s.store_field("total_size", total_size_);
    s.store_field("offset", offset_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

adnl_node::adnl_node()
  : id_()
  , addr_list_()
{}

adnl_node::adnl_node(object_ptr<PublicKey> &&id_, object_ptr<adnl_addressList> &&addr_list_)
  : id_(std::move(id_))
  , addr_list_(std::move(addr_list_))
{}

const std::int32_t adnl_node::ID;

object_ptr<adnl_node> adnl_node::fetch(td::TlParser &p) {
  return make_object<adnl_node>(p);
}

adnl_node::adnl_node(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PublicKey>::parse(p))
  , addr_list_(TlFetchObject<adnl_addressList>::parse(p))
#undef FAIL
{}

void adnl_node::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
}

void adnl_node::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
}

void adnl_node::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_node");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    if (addr_list_ == nullptr) { s.store_field("addr_list", "null"); } else { addr_list_->store(s, "addr_list"); }
    s.store_class_end();
  }
}

adnl_nodes::adnl_nodes()
  : nodes_()
{}

adnl_nodes::adnl_nodes(std::vector<object_ptr<adnl_node>> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t adnl_nodes::ID;

object_ptr<adnl_nodes> adnl_nodes::fetch(td::TlParser &p) {
  return make_object<adnl_nodes>(p);
}

adnl_nodes::adnl_nodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchVector<TlFetchObject<adnl_node>>::parse(p))
#undef FAIL
{}

void adnl_nodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void adnl_nodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void adnl_nodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_nodes");
    { const std::vector<object_ptr<adnl_node>> &v = nodes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("nodes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

adnl_packetContents::adnl_packetContents()
  : rand1_()
  , flags_()
  , from_()
  , from_short_()
  , message_()
  , messages_()
  , address_()
  , priority_address_()
  , seqno_()
  , confirm_seqno_()
  , recv_addr_list_version_()
  , recv_priority_addr_list_version_()
  , reinit_date_()
  , dst_reinit_date_()
  , signature_()
  , rand2_()
{}

adnl_packetContents::adnl_packetContents(td::BufferSlice &&rand1_, std::int32_t flags_, object_ptr<PublicKey> &&from_, object_ptr<adnl_id_short> &&from_short_, object_ptr<adnl_Message> &&message_, std::vector<object_ptr<adnl_Message>> &&messages_, object_ptr<adnl_addressList> &&address_, object_ptr<adnl_addressList> &&priority_address_, std::int64_t seqno_, std::int64_t confirm_seqno_, std::int32_t recv_addr_list_version_, std::int32_t recv_priority_addr_list_version_, std::int32_t reinit_date_, std::int32_t dst_reinit_date_, td::BufferSlice &&signature_, td::BufferSlice &&rand2_)
  : rand1_(std::move(rand1_))
  , flags_(flags_)
  , from_(std::move(from_))
  , from_short_(std::move(from_short_))
  , message_(std::move(message_))
  , messages_(std::move(messages_))
  , address_(std::move(address_))
  , priority_address_(std::move(priority_address_))
  , seqno_(seqno_)
  , confirm_seqno_(confirm_seqno_)
  , recv_addr_list_version_(recv_addr_list_version_)
  , recv_priority_addr_list_version_(recv_priority_addr_list_version_)
  , reinit_date_(reinit_date_)
  , dst_reinit_date_(dst_reinit_date_)
  , signature_(std::move(signature_))
  , rand2_(std::move(rand2_))
{}

const std::int32_t adnl_packetContents::ID;

object_ptr<adnl_packetContents> adnl_packetContents::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  object_ptr<adnl_packetContents> res = make_object<adnl_packetContents>();
  std::int32_t var0;
  res->rand1_ = TlFetchBytes<td::BufferSlice>::parse(p);
  if ((var0 = res->flags_ = TlFetchInt::parse(p)) < 0) { FAIL("Variable of type # can't be negative"); }
  if (var0 & 1) { res->from_ = TlFetchObject<PublicKey>::parse(p); }
  if (var0 & 2) { res->from_short_ = TlFetchObject<adnl_id_short>::parse(p); }
  if (var0 & 4) { res->message_ = TlFetchObject<adnl_Message>::parse(p); }
  if (var0 & 8) { res->messages_ = TlFetchVector<TlFetchObject<adnl_Message>>::parse(p); }
  if (var0 & 16) { res->address_ = TlFetchObject<adnl_addressList>::parse(p); }
  if (var0 & 32) { res->priority_address_ = TlFetchObject<adnl_addressList>::parse(p); }
  if (var0 & 64) { res->seqno_ = TlFetchLong::parse(p); }
  if (var0 & 128) { res->confirm_seqno_ = TlFetchLong::parse(p); }
  if (var0 & 256) { res->recv_addr_list_version_ = TlFetchInt::parse(p); }
  if (var0 & 512) { res->recv_priority_addr_list_version_ = TlFetchInt::parse(p); }
  if (var0 & 1024) { res->reinit_date_ = TlFetchInt::parse(p); }
  if (var0 & 1024) { res->dst_reinit_date_ = TlFetchInt::parse(p); }
  if (var0 & 2048) { res->signature_ = TlFetchBytes<td::BufferSlice>::parse(p); }
  res->rand2_ = TlFetchBytes<td::BufferSlice>::parse(p);
  if (p.get_error()) { FAIL(""); }
  return res;
#undef FAIL
}

void adnl_packetContents::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreString::store(rand1_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBoxedUnknown<TlStoreObject>::store(from_, s); }
  if (var0 & 2) { TlStoreObject::store(from_short_, s); }
  if (var0 & 4) { TlStoreBoxedUnknown<TlStoreObject>::store(message_, s); }
  if (var0 & 8) { TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(messages_, s); }
  if (var0 & 16) { TlStoreObject::store(address_, s); }
  if (var0 & 32) { TlStoreObject::store(priority_address_, s); }
  if (var0 & 64) { TlStoreBinary::store(seqno_, s); }
  if (var0 & 128) { TlStoreBinary::store(confirm_seqno_, s); }
  if (var0 & 256) { TlStoreBinary::store(recv_addr_list_version_, s); }
  if (var0 & 512) { TlStoreBinary::store(recv_priority_addr_list_version_, s); }
  if (var0 & 1024) { TlStoreBinary::store(reinit_date_, s); }
  if (var0 & 1024) { TlStoreBinary::store(dst_reinit_date_, s); }
  if (var0 & 2048) { TlStoreString::store(signature_, s); }
  TlStoreString::store(rand2_, s);
}

void adnl_packetContents::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreString::store(rand1_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBoxedUnknown<TlStoreObject>::store(from_, s); }
  if (var0 & 2) { TlStoreObject::store(from_short_, s); }
  if (var0 & 4) { TlStoreBoxedUnknown<TlStoreObject>::store(message_, s); }
  if (var0 & 8) { TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(messages_, s); }
  if (var0 & 16) { TlStoreObject::store(address_, s); }
  if (var0 & 32) { TlStoreObject::store(priority_address_, s); }
  if (var0 & 64) { TlStoreBinary::store(seqno_, s); }
  if (var0 & 128) { TlStoreBinary::store(confirm_seqno_, s); }
  if (var0 & 256) { TlStoreBinary::store(recv_addr_list_version_, s); }
  if (var0 & 512) { TlStoreBinary::store(recv_priority_addr_list_version_, s); }
  if (var0 & 1024) { TlStoreBinary::store(reinit_date_, s); }
  if (var0 & 1024) { TlStoreBinary::store(dst_reinit_date_, s); }
  if (var0 & 2048) { TlStoreString::store(signature_, s); }
  TlStoreString::store(rand2_, s);
}

void adnl_packetContents::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_packetContents");
  std::int32_t var0;
    s.store_bytes_field("rand1", rand1_);
    s.store_field("flags", (var0 = flags_));
    if (var0 & 1) { if (from_ == nullptr) { s.store_field("from", "null"); } else { from_->store(s, "from"); } }
    if (var0 & 2) { if (from_short_ == nullptr) { s.store_field("from_short", "null"); } else { from_short_->store(s, "from_short"); } }
    if (var0 & 4) { if (message_ == nullptr) { s.store_field("message", "null"); } else { message_->store(s, "message"); } }
    if (var0 & 8) { { const std::vector<object_ptr<adnl_Message>> &v = messages_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("messages", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); } }
    if (var0 & 16) { if (address_ == nullptr) { s.store_field("address", "null"); } else { address_->store(s, "address"); } }
    if (var0 & 32) { if (priority_address_ == nullptr) { s.store_field("priority_address", "null"); } else { priority_address_->store(s, "priority_address"); } }
    if (var0 & 64) { s.store_field("seqno", seqno_); }
    if (var0 & 128) { s.store_field("confirm_seqno", confirm_seqno_); }
    if (var0 & 256) { s.store_field("recv_addr_list_version", recv_addr_list_version_); }
    if (var0 & 512) { s.store_field("recv_priority_addr_list_version", recv_priority_addr_list_version_); }
    if (var0 & 1024) { s.store_field("reinit_date", reinit_date_); }
    if (var0 & 1024) { s.store_field("dst_reinit_date", dst_reinit_date_); }
    if (var0 & 2048) { s.store_bytes_field("signature", signature_); }
    s.store_bytes_field("rand2", rand2_);
    s.store_class_end();
  }
}

adnl_pong::adnl_pong()
  : value_()
{}

adnl_pong::adnl_pong(std::int64_t value_)
  : value_(value_)
{}

const std::int32_t adnl_pong::ID;

object_ptr<adnl_pong> adnl_pong::fetch(td::TlParser &p) {
  return make_object<adnl_pong>(p);
}

adnl_pong::adnl_pong(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchLong::parse(p))
#undef FAIL
{}

void adnl_pong::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void adnl_pong::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(value_, s);
}

void adnl_pong::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_pong");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

object_ptr<adnl_Proxy> adnl_Proxy::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case adnl_proxy_none::ID:
      return adnl_proxy_none::fetch(p);
    case adnl_proxy_fast::ID:
      return adnl_proxy_fast::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

adnl_proxy_none::adnl_proxy_none()
  : id_()
{}

adnl_proxy_none::adnl_proxy_none(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t adnl_proxy_none::ID;

object_ptr<adnl_Proxy> adnl_proxy_none::fetch(td::TlParser &p) {
  return make_object<adnl_proxy_none>(p);
}

adnl_proxy_none::adnl_proxy_none(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_proxy_none::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxy_none::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxy_none::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxy_none");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

adnl_proxy_fast::adnl_proxy_fast()
  : id_()
  , shared_secret_()
{}

adnl_proxy_fast::adnl_proxy_fast(td::Bits256 const &id_, td::BufferSlice &&shared_secret_)
  : id_(id_)
  , shared_secret_(std::move(shared_secret_))
{}

const std::int32_t adnl_proxy_fast::ID;

object_ptr<adnl_Proxy> adnl_proxy_fast::fetch(td::TlParser &p) {
  return make_object<adnl_proxy_fast>(p);
}

adnl_proxy_fast::adnl_proxy_fast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , shared_secret_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void adnl_proxy_fast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(shared_secret_, s);
}

void adnl_proxy_fast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(shared_secret_, s);
}

void adnl_proxy_fast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxy_fast");
    s.store_field("id", id_);
    s.store_bytes_field("shared_secret", shared_secret_);
    s.store_class_end();
  }
}

object_ptr<adnl_ProxyControlPacket> adnl_ProxyControlPacket::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case adnl_proxyControlPacketPing::ID:
      return adnl_proxyControlPacketPing::fetch(p);
    case adnl_proxyControlPacketPong::ID:
      return adnl_proxyControlPacketPong::fetch(p);
    case adnl_proxyControlPacketRegister::ID:
      return adnl_proxyControlPacketRegister::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

adnl_proxyControlPacketPing::adnl_proxyControlPacketPing()
  : id_()
{}

adnl_proxyControlPacketPing::adnl_proxyControlPacketPing(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t adnl_proxyControlPacketPing::ID;

object_ptr<adnl_ProxyControlPacket> adnl_proxyControlPacketPing::fetch(td::TlParser &p) {
  return make_object<adnl_proxyControlPacketPing>(p);
}

adnl_proxyControlPacketPing::adnl_proxyControlPacketPing(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_proxyControlPacketPing::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxyControlPacketPing::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxyControlPacketPing::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyControlPacketPing");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

adnl_proxyControlPacketPong::adnl_proxyControlPacketPong()
  : id_()
{}

adnl_proxyControlPacketPong::adnl_proxyControlPacketPong(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t adnl_proxyControlPacketPong::ID;

object_ptr<adnl_ProxyControlPacket> adnl_proxyControlPacketPong::fetch(td::TlParser &p) {
  return make_object<adnl_proxyControlPacketPong>(p);
}

adnl_proxyControlPacketPong::adnl_proxyControlPacketPong(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_proxyControlPacketPong::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxyControlPacketPong::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_proxyControlPacketPong::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyControlPacketPong");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

adnl_proxyControlPacketRegister::adnl_proxyControlPacketRegister()
  : ip_()
  , port_()
{}

adnl_proxyControlPacketRegister::adnl_proxyControlPacketRegister(std::int32_t ip_, std::int32_t port_)
  : ip_(ip_)
  , port_(port_)
{}

const std::int32_t adnl_proxyControlPacketRegister::ID;

object_ptr<adnl_ProxyControlPacket> adnl_proxyControlPacketRegister::fetch(td::TlParser &p) {
  return make_object<adnl_proxyControlPacketRegister>(p);
}

adnl_proxyControlPacketRegister::adnl_proxyControlPacketRegister(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void adnl_proxyControlPacketRegister::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_proxyControlPacketRegister::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void adnl_proxyControlPacketRegister::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyControlPacketRegister");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

adnl_proxyPacketHeader::adnl_proxyPacketHeader()
  : proxy_id_()
  , flags_()
  , ip_()
  , port_()
  , adnl_start_time_()
  , seqno_()
  , date_()
  , signature_()
{}

adnl_proxyPacketHeader::adnl_proxyPacketHeader(td::Bits256 const &proxy_id_, std::int32_t flags_, std::int32_t ip_, std::int32_t port_, std::int32_t adnl_start_time_, std::int64_t seqno_, std::int32_t date_, td::Bits256 const &signature_)
  : proxy_id_(proxy_id_)
  , flags_(flags_)
  , ip_(ip_)
  , port_(port_)
  , adnl_start_time_(adnl_start_time_)
  , seqno_(seqno_)
  , date_(date_)
  , signature_(signature_)
{}

const std::int32_t adnl_proxyPacketHeader::ID;

object_ptr<adnl_proxyPacketHeader> adnl_proxyPacketHeader::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  object_ptr<adnl_proxyPacketHeader> res = make_object<adnl_proxyPacketHeader>();
  std::int32_t var0;
  res->proxy_id_ = TlFetchInt256::parse(p);
  if ((var0 = res->flags_ = TlFetchInt::parse(p)) < 0) { FAIL("Variable of type # can't be negative"); }
  if (var0 & 1) { res->ip_ = TlFetchInt::parse(p); }
  if (var0 & 1) { res->port_ = TlFetchInt::parse(p); }
  if (var0 & 2) { res->adnl_start_time_ = TlFetchInt::parse(p); }
  if (var0 & 4) { res->seqno_ = TlFetchLong::parse(p); }
  if (var0 & 8) { res->date_ = TlFetchInt::parse(p); }
  res->signature_ = TlFetchInt256::parse(p);
  if (p.get_error()) { FAIL(""); }
  return res;
#undef FAIL
}

void adnl_proxyPacketHeader::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreBinary::store(proxy_id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBinary::store(ip_, s); }
  if (var0 & 1) { TlStoreBinary::store(port_, s); }
  if (var0 & 2) { TlStoreBinary::store(adnl_start_time_, s); }
  if (var0 & 4) { TlStoreBinary::store(seqno_, s); }
  if (var0 & 8) { TlStoreBinary::store(date_, s); }
  TlStoreBinary::store(signature_, s);
}

void adnl_proxyPacketHeader::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreBinary::store(proxy_id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBinary::store(ip_, s); }
  if (var0 & 1) { TlStoreBinary::store(port_, s); }
  if (var0 & 2) { TlStoreBinary::store(adnl_start_time_, s); }
  if (var0 & 4) { TlStoreBinary::store(seqno_, s); }
  if (var0 & 8) { TlStoreBinary::store(date_, s); }
  TlStoreBinary::store(signature_, s);
}

void adnl_proxyPacketHeader::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyPacketHeader");
  std::int32_t var0;
    s.store_field("proxy_id", proxy_id_);
    s.store_field("flags", (var0 = flags_));
    if (var0 & 1) { s.store_field("ip", ip_); }
    if (var0 & 1) { s.store_field("port", port_); }
    if (var0 & 2) { s.store_field("adnl_start_time", adnl_start_time_); }
    if (var0 & 4) { s.store_field("seqno", seqno_); }
    if (var0 & 8) { s.store_field("date", date_); }
    s.store_field("signature", signature_);
    s.store_class_end();
  }
}

adnl_proxyToFastHash::adnl_proxyToFastHash()
  : ip_()
  , port_()
  , date_()
  , data_hash_()
  , shared_secret_()
{}

adnl_proxyToFastHash::adnl_proxyToFastHash(std::int32_t ip_, std::int32_t port_, std::int32_t date_, td::Bits256 const &data_hash_, td::Bits256 const &shared_secret_)
  : ip_(ip_)
  , port_(port_)
  , date_(date_)
  , data_hash_(data_hash_)
  , shared_secret_(shared_secret_)
{}

const std::int32_t adnl_proxyToFastHash::ID;

object_ptr<adnl_proxyToFastHash> adnl_proxyToFastHash::fetch(td::TlParser &p) {
  return make_object<adnl_proxyToFastHash>(p);
}

adnl_proxyToFastHash::adnl_proxyToFastHash(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , date_(TlFetchInt::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , shared_secret_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_proxyToFastHash::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(date_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(shared_secret_, s);
}

void adnl_proxyToFastHash::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(date_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(shared_secret_, s);
}

void adnl_proxyToFastHash::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyToFastHash");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_field("date", date_);
    s.store_field("data_hash", data_hash_);
    s.store_field("shared_secret", shared_secret_);
    s.store_class_end();
  }
}

adnl_proxyToFast::adnl_proxyToFast()
  : ip_()
  , port_()
  , date_()
  , signature_()
{}

adnl_proxyToFast::adnl_proxyToFast(std::int32_t ip_, std::int32_t port_, std::int32_t date_, td::Bits256 const &signature_)
  : ip_(ip_)
  , port_(port_)
  , date_(date_)
  , signature_(signature_)
{}

const std::int32_t adnl_proxyToFast::ID;

object_ptr<adnl_proxyToFast> adnl_proxyToFast::fetch(td::TlParser &p) {
  return make_object<adnl_proxyToFast>(p);
}

adnl_proxyToFast::adnl_proxyToFast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , date_(TlFetchInt::parse(p))
  , signature_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_proxyToFast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(date_, s);
  TlStoreBinary::store(signature_, s);
}

void adnl_proxyToFast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(date_, s);
  TlStoreBinary::store(signature_, s);
}

void adnl_proxyToFast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_proxyToFast");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_field("date", date_);
    s.store_field("signature", signature_);
    s.store_class_end();
  }
}

adnl_tunnelPacketContents::adnl_tunnelPacketContents()
  : rand1_()
  , flags_()
  , from_ip_()
  , from_port_()
  , message_()
  , statistics_()
  , payment_()
  , rand2_()
{}

adnl_tunnelPacketContents::adnl_tunnelPacketContents(td::BufferSlice &&rand1_, std::int32_t flags_, std::int32_t from_ip_, std::int32_t from_port_, td::BufferSlice &&message_, td::BufferSlice &&statistics_, td::BufferSlice &&payment_, td::BufferSlice &&rand2_)
  : rand1_(std::move(rand1_))
  , flags_(flags_)
  , from_ip_(from_ip_)
  , from_port_(from_port_)
  , message_(std::move(message_))
  , statistics_(std::move(statistics_))
  , payment_(std::move(payment_))
  , rand2_(std::move(rand2_))
{}

const std::int32_t adnl_tunnelPacketContents::ID;

object_ptr<adnl_tunnelPacketContents> adnl_tunnelPacketContents::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  object_ptr<adnl_tunnelPacketContents> res = make_object<adnl_tunnelPacketContents>();
  std::int32_t var0;
  res->rand1_ = TlFetchBytes<td::BufferSlice>::parse(p);
  if ((var0 = res->flags_ = TlFetchInt::parse(p)) < 0) { FAIL("Variable of type # can't be negative"); }
  if (var0 & 1) { res->from_ip_ = TlFetchInt::parse(p); }
  if (var0 & 1) { res->from_port_ = TlFetchInt::parse(p); }
  if (var0 & 2) { res->message_ = TlFetchBytes<td::BufferSlice>::parse(p); }
  if (var0 & 4) { res->statistics_ = TlFetchBytes<td::BufferSlice>::parse(p); }
  if (var0 & 8) { res->payment_ = TlFetchBytes<td::BufferSlice>::parse(p); }
  res->rand2_ = TlFetchBytes<td::BufferSlice>::parse(p);
  if (p.get_error()) { FAIL(""); }
  return res;
#undef FAIL
}

void adnl_tunnelPacketContents::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreString::store(rand1_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBinary::store(from_ip_, s); }
  if (var0 & 1) { TlStoreBinary::store(from_port_, s); }
  if (var0 & 2) { TlStoreString::store(message_, s); }
  if (var0 & 4) { TlStoreString::store(statistics_, s); }
  if (var0 & 8) { TlStoreString::store(payment_, s); }
  TlStoreString::store(rand2_, s);
}

void adnl_tunnelPacketContents::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreString::store(rand1_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreBinary::store(from_ip_, s); }
  if (var0 & 1) { TlStoreBinary::store(from_port_, s); }
  if (var0 & 2) { TlStoreString::store(message_, s); }
  if (var0 & 4) { TlStoreString::store(statistics_, s); }
  if (var0 & 8) { TlStoreString::store(payment_, s); }
  TlStoreString::store(rand2_, s);
}

void adnl_tunnelPacketContents::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_tunnelPacketContents");
  std::int32_t var0;
    s.store_bytes_field("rand1", rand1_);
    s.store_field("flags", (var0 = flags_));
    if (var0 & 1) { s.store_field("from_ip", from_ip_); }
    if (var0 & 1) { s.store_field("from_port", from_port_); }
    if (var0 & 2) { s.store_bytes_field("message", message_); }
    if (var0 & 4) { s.store_bytes_field("statistics", statistics_); }
    if (var0 & 8) { s.store_bytes_field("payment", payment_); }
    s.store_bytes_field("rand2", rand2_);
    s.store_class_end();
  }
}

adnl_config_global::adnl_config_global()
  : static_nodes_()
{}

adnl_config_global::adnl_config_global(object_ptr<adnl_nodes> &&static_nodes_)
  : static_nodes_(std::move(static_nodes_))
{}

const std::int32_t adnl_config_global::ID;

object_ptr<adnl_config_global> adnl_config_global::fetch(td::TlParser &p) {
  return make_object<adnl_config_global>(p);
}

adnl_config_global::adnl_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : static_nodes_(TlFetchObject<adnl_nodes>::parse(p))
#undef FAIL
{}

void adnl_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(static_nodes_, s);
}

void adnl_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(static_nodes_, s);
}

void adnl_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_config_global");
    if (static_nodes_ == nullptr) { s.store_field("static_nodes", "null"); } else { static_nodes_->store(s, "static_nodes"); }
    s.store_class_end();
  }
}

adnl_db_node_key::adnl_db_node_key()
  : local_id_()
  , peer_id_()
{}

adnl_db_node_key::adnl_db_node_key(td::Bits256 const &local_id_, td::Bits256 const &peer_id_)
  : local_id_(local_id_)
  , peer_id_(peer_id_)
{}

const std::int32_t adnl_db_node_key::ID;

object_ptr<adnl_db_node_key> adnl_db_node_key::fetch(td::TlParser &p) {
  return make_object<adnl_db_node_key>(p);
}

adnl_db_node_key::adnl_db_node_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : local_id_(TlFetchInt256::parse(p))
  , peer_id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_db_node_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(local_id_, s);
  TlStoreBinary::store(peer_id_, s);
}

void adnl_db_node_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(local_id_, s);
  TlStoreBinary::store(peer_id_, s);
}

void adnl_db_node_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_db_node_key");
    s.store_field("local_id", local_id_);
    s.store_field("peer_id", peer_id_);
    s.store_class_end();
  }
}

adnl_db_node_value::adnl_db_node_value()
  : date_()
  , id_()
  , addr_list_()
  , priority_addr_list_()
{}

adnl_db_node_value::adnl_db_node_value(std::int32_t date_, object_ptr<PublicKey> &&id_, object_ptr<adnl_addressList> &&addr_list_, object_ptr<adnl_addressList> &&priority_addr_list_)
  : date_(date_)
  , id_(std::move(id_))
  , addr_list_(std::move(addr_list_))
  , priority_addr_list_(std::move(priority_addr_list_))
{}

const std::int32_t adnl_db_node_value::ID;

object_ptr<adnl_db_node_value> adnl_db_node_value::fetch(td::TlParser &p) {
  return make_object<adnl_db_node_value>(p);
}

adnl_db_node_value::adnl_db_node_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : date_(TlFetchInt::parse(p))
  , id_(TlFetchObject<PublicKey>::parse(p))
  , addr_list_(TlFetchObject<adnl_addressList>::parse(p))
  , priority_addr_list_(TlFetchObject<adnl_addressList>::parse(p))
#undef FAIL
{}

void adnl_db_node_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(date_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
  TlStoreObject::store(priority_addr_list_, s);
}

void adnl_db_node_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(date_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
  TlStoreObject::store(priority_addr_list_, s);
}

void adnl_db_node_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_db_node_value");
    s.store_field("date", date_);
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    if (addr_list_ == nullptr) { s.store_field("addr_list", "null"); } else { addr_list_->store(s, "addr_list"); }
    if (priority_addr_list_ == nullptr) { s.store_field("priority_addr_list", "null"); } else { priority_addr_list_->store(s, "priority_addr_list"); }
    s.store_class_end();
  }
}

adnl_id_short::adnl_id_short()
  : id_()
{}

adnl_id_short::adnl_id_short(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t adnl_id_short::ID;

object_ptr<adnl_id_short> adnl_id_short::fetch(td::TlParser &p) {
  return make_object<adnl_id_short>(p);
}

adnl_id_short::adnl_id_short(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void adnl_id_short::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_id_short::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void adnl_id_short::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_id_short");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

catchain_block::catchain_block()
  : incarnation_()
  , src_()
  , height_()
  , data_()
  , signature_()
{}

catchain_block::catchain_block(td::Bits256 const &incarnation_, std::int32_t src_, std::int32_t height_, object_ptr<catchain_block_data> &&data_, td::BufferSlice &&signature_)
  : incarnation_(incarnation_)
  , src_(src_)
  , height_(height_)
  , data_(std::move(data_))
  , signature_(std::move(signature_))
{}

const std::int32_t catchain_block::ID;

object_ptr<catchain_block> catchain_block::fetch(td::TlParser &p) {
  return make_object<catchain_block>(p);
}

catchain_block::catchain_block(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : incarnation_(TlFetchInt256::parse(p))
  , src_(TlFetchInt::parse(p))
  , height_(TlFetchInt::parse(p))
  , data_(TlFetchObject<catchain_block_data>::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void catchain_block::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(incarnation_, s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreObject::store(data_, s);
  TlStoreString::store(signature_, s);
}

void catchain_block::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(incarnation_, s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreObject::store(data_, s);
  TlStoreString::store(signature_, s);
}

void catchain_block::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block");
    s.store_field("incarnation", incarnation_);
    s.store_field("src", src_);
    s.store_field("height", height_);
    if (data_ == nullptr) { s.store_field("data", "null"); } else { data_->store(s, "data"); }
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

object_ptr<catchain_BlockResult> catchain_BlockResult::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case catchain_blockNotFound::ID:
      return catchain_blockNotFound::fetch(p);
    case catchain_blockResult::ID:
      return catchain_blockResult::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

catchain_blockNotFound::catchain_blockNotFound() {
}

const std::int32_t catchain_blockNotFound::ID;

object_ptr<catchain_BlockResult> catchain_blockNotFound::fetch(td::TlParser &p) {
  return make_object<catchain_blockNotFound>(p);
}

catchain_blockNotFound::catchain_blockNotFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void catchain_blockNotFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void catchain_blockNotFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void catchain_blockNotFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_blockNotFound");
    s.store_class_end();
  }
}

catchain_blockResult::catchain_blockResult()
  : block_()
{}

catchain_blockResult::catchain_blockResult(object_ptr<catchain_block> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t catchain_blockResult::ID;

object_ptr<catchain_BlockResult> catchain_blockResult::fetch(td::TlParser &p) {
  return make_object<catchain_blockResult>(p);
}

catchain_blockResult::catchain_blockResult(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<catchain_block>::parse(p))
#undef FAIL
{}

void catchain_blockResult::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_blockResult::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_blockResult::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_blockResult");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

catchain_blocks::catchain_blocks()
  : blocks_()
{}

catchain_blocks::catchain_blocks(std::vector<object_ptr<catchain_block>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t catchain_blocks::ID;

object_ptr<catchain_blocks> catchain_blocks::fetch(td::TlParser &p) {
  return make_object<catchain_blocks>(p);
}

catchain_blocks::catchain_blocks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<catchain_block>>::parse(p))
#undef FAIL
{}

void catchain_blocks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void catchain_blocks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void catchain_blocks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_blocks");
    { const std::vector<object_ptr<catchain_block>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

object_ptr<catchain_Difference> catchain_Difference::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case catchain_difference::ID:
      return catchain_difference::fetch(p);
    case catchain_differenceFork::ID:
      return catchain_differenceFork::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

catchain_difference::catchain_difference()
  : sent_upto_()
{}

catchain_difference::catchain_difference(std::vector<std::int32_t> &&sent_upto_)
  : sent_upto_(std::move(sent_upto_))
{}

const std::int32_t catchain_difference::ID;

object_ptr<catchain_Difference> catchain_difference::fetch(td::TlParser &p) {
  return make_object<catchain_difference>(p);
}

catchain_difference::catchain_difference(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : sent_upto_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void catchain_difference::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(sent_upto_, s);
}

void catchain_difference::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(sent_upto_, s);
}

void catchain_difference::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_difference");
    { const std::vector<std::int32_t> &v = sent_upto_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("sent_upto", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_differenceFork::catchain_differenceFork()
  : left_()
  , right_()
{}

catchain_differenceFork::catchain_differenceFork(object_ptr<catchain_block_dep> &&left_, object_ptr<catchain_block_dep> &&right_)
  : left_(std::move(left_))
  , right_(std::move(right_))
{}

const std::int32_t catchain_differenceFork::ID;

object_ptr<catchain_Difference> catchain_differenceFork::fetch(td::TlParser &p) {
  return make_object<catchain_differenceFork>(p);
}

catchain_differenceFork::catchain_differenceFork(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : left_(TlFetchObject<catchain_block_dep>::parse(p))
  , right_(TlFetchObject<catchain_block_dep>::parse(p))
#undef FAIL
{}

void catchain_differenceFork::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(left_, s);
  TlStoreObject::store(right_, s);
}

void catchain_differenceFork::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(left_, s);
  TlStoreObject::store(right_, s);
}

void catchain_differenceFork::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_differenceFork");
    if (left_ == nullptr) { s.store_field("left", "null"); } else { left_->store(s, "left"); }
    if (right_ == nullptr) { s.store_field("right", "null"); } else { right_->store(s, "right"); }
    s.store_class_end();
  }
}

catchain_firstblock::catchain_firstblock()
  : unique_hash_()
  , nodes_()
{}

catchain_firstblock::catchain_firstblock(td::Bits256 const &unique_hash_, std::vector<td::Bits256> &&nodes_)
  : unique_hash_(unique_hash_)
  , nodes_(std::move(nodes_))
{}

const std::int32_t catchain_firstblock::ID;

object_ptr<catchain_firstblock> catchain_firstblock::fetch(td::TlParser &p) {
  return make_object<catchain_firstblock>(p);
}

catchain_firstblock::catchain_firstblock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : unique_hash_(TlFetchInt256::parse(p))
  , nodes_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void catchain_firstblock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(unique_hash_, s);
  TlStoreVector<TlStoreBinary>::store(nodes_, s);
}

void catchain_firstblock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(unique_hash_, s);
  TlStoreVector<TlStoreBinary>::store(nodes_, s);
}

void catchain_firstblock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_firstblock");
    s.store_field("unique_hash", unique_hash_);
    { const std::vector<td::Bits256> &v = nodes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("nodes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_sent::catchain_sent()
  : cnt_()
{}

catchain_sent::catchain_sent(std::int32_t cnt_)
  : cnt_(cnt_)
{}

const std::int32_t catchain_sent::ID;

object_ptr<catchain_sent> catchain_sent::fetch(td::TlParser &p) {
  return make_object<catchain_sent>(p);
}

catchain_sent::catchain_sent(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : cnt_(TlFetchInt::parse(p))
#undef FAIL
{}

void catchain_sent::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(cnt_, s);
}

void catchain_sent::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(cnt_, s);
}

void catchain_sent::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_sent");
    s.store_field("cnt", cnt_);
    s.store_class_end();
  }
}

catchain_blockUpdate::catchain_blockUpdate()
  : block_()
{}

catchain_blockUpdate::catchain_blockUpdate(object_ptr<catchain_block> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t catchain_blockUpdate::ID;

object_ptr<catchain_blockUpdate> catchain_blockUpdate::fetch(td::TlParser &p) {
  return make_object<catchain_blockUpdate>(p);
}

catchain_blockUpdate::catchain_blockUpdate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<catchain_block>::parse(p))
#undef FAIL
{}

void catchain_blockUpdate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_blockUpdate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_blockUpdate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_blockUpdate");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

catchain_block_data::catchain_block_data()
  : prev_()
  , deps_()
{}

catchain_block_data::catchain_block_data(object_ptr<catchain_block_dep> &&prev_, std::vector<object_ptr<catchain_block_dep>> &&deps_)
  : prev_(std::move(prev_))
  , deps_(std::move(deps_))
{}

const std::int32_t catchain_block_data::ID;

object_ptr<catchain_block_data> catchain_block_data::fetch(td::TlParser &p) {
  return make_object<catchain_block_data>(p);
}

catchain_block_data::catchain_block_data(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : prev_(TlFetchObject<catchain_block_dep>::parse(p))
  , deps_(TlFetchVector<TlFetchObject<catchain_block_dep>>::parse(p))
#undef FAIL
{}

void catchain_block_data::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(prev_, s);
  TlStoreVector<TlStoreObject>::store(deps_, s);
}

void catchain_block_data::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(prev_, s);
  TlStoreVector<TlStoreObject>::store(deps_, s);
}

void catchain_block_data::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_data");
    if (prev_ == nullptr) { s.store_field("prev", "null"); } else { prev_->store(s, "prev"); }
    { const std::vector<object_ptr<catchain_block_dep>> &v = deps_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("deps", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_block_dep::catchain_block_dep()
  : src_()
  , height_()
  , data_hash_()
  , signature_()
{}

catchain_block_dep::catchain_block_dep(std::int32_t src_, std::int32_t height_, td::Bits256 const &data_hash_, td::BufferSlice &&signature_)
  : src_(src_)
  , height_(height_)
  , data_hash_(data_hash_)
  , signature_(std::move(signature_))
{}

const std::int32_t catchain_block_dep::ID;

object_ptr<catchain_block_dep> catchain_block_dep::fetch(td::TlParser &p) {
  return make_object<catchain_block_dep>(p);
}

catchain_block_dep::catchain_block_dep(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt::parse(p))
  , height_(TlFetchInt::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void catchain_block_dep::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreString::store(signature_, s);
}

void catchain_block_dep::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreString::store(signature_, s);
}

void catchain_block_dep::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_dep");
    s.store_field("src", src_);
    s.store_field("height", height_);
    s.store_field("data_hash", data_hash_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

catchain_block_id::catchain_block_id()
  : incarnation_()
  , src_()
  , height_()
  , data_hash_()
{}

catchain_block_id::catchain_block_id(td::Bits256 const &incarnation_, td::Bits256 const &src_, std::int32_t height_, td::Bits256 const &data_hash_)
  : incarnation_(incarnation_)
  , src_(src_)
  , height_(height_)
  , data_hash_(data_hash_)
{}

const std::int32_t catchain_block_id::ID;

object_ptr<catchain_block_id> catchain_block_id::fetch(td::TlParser &p) {
  return make_object<catchain_block_id>(p);
}

catchain_block_id::catchain_block_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : incarnation_(TlFetchInt256::parse(p))
  , src_(TlFetchInt256::parse(p))
  , height_(TlFetchInt::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void catchain_block_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(incarnation_, s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(data_hash_, s);
}

void catchain_block_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(incarnation_, s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(data_hash_, s);
}

void catchain_block_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_id");
    s.store_field("incarnation", incarnation_);
    s.store_field("src", src_);
    s.store_field("height", height_);
    s.store_field("data_hash", data_hash_);
    s.store_class_end();
  }
}

object_ptr<catchain_block_inner_Data> catchain_block_inner_Data::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case catchain_block_data_badBlock::ID:
      return catchain_block_data_badBlock::fetch(p);
    case catchain_block_data_fork::ID:
      return catchain_block_data_fork::fetch(p);
    case catchain_block_data_nop::ID:
      return catchain_block_data_nop::fetch(p);
    case catchain_block_data_vector::ID:
      return catchain_block_data_vector::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

catchain_block_data_badBlock::catchain_block_data_badBlock()
  : block_()
{}

catchain_block_data_badBlock::catchain_block_data_badBlock(object_ptr<catchain_block> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t catchain_block_data_badBlock::ID;

object_ptr<catchain_block_inner_Data> catchain_block_data_badBlock::fetch(td::TlParser &p) {
  return make_object<catchain_block_data_badBlock>(p);
}

catchain_block_data_badBlock::catchain_block_data_badBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<catchain_block>::parse(p))
#undef FAIL
{}

void catchain_block_data_badBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_block_data_badBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void catchain_block_data_badBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_data_badBlock");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

catchain_block_data_fork::catchain_block_data_fork()
  : left_()
  , right_()
{}

catchain_block_data_fork::catchain_block_data_fork(object_ptr<catchain_block_dep> &&left_, object_ptr<catchain_block_dep> &&right_)
  : left_(std::move(left_))
  , right_(std::move(right_))
{}

const std::int32_t catchain_block_data_fork::ID;

object_ptr<catchain_block_inner_Data> catchain_block_data_fork::fetch(td::TlParser &p) {
  return make_object<catchain_block_data_fork>(p);
}

catchain_block_data_fork::catchain_block_data_fork(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : left_(TlFetchBoxed<TlFetchObject<catchain_block_dep>, 1511706959>::parse(p))
  , right_(TlFetchBoxed<TlFetchObject<catchain_block_dep>, 1511706959>::parse(p))
#undef FAIL
{}

void catchain_block_data_fork::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxed<TlStoreObject, 1511706959>::store(left_, s);
  TlStoreBoxed<TlStoreObject, 1511706959>::store(right_, s);
}

void catchain_block_data_fork::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxed<TlStoreObject, 1511706959>::store(left_, s);
  TlStoreBoxed<TlStoreObject, 1511706959>::store(right_, s);
}

void catchain_block_data_fork::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_data_fork");
    if (left_ == nullptr) { s.store_field("left", "null"); } else { left_->store(s, "left"); }
    if (right_ == nullptr) { s.store_field("right", "null"); } else { right_->store(s, "right"); }
    s.store_class_end();
  }
}

catchain_block_data_nop::catchain_block_data_nop() {
}

const std::int32_t catchain_block_data_nop::ID;

object_ptr<catchain_block_inner_Data> catchain_block_data_nop::fetch(td::TlParser &p) {
  return make_object<catchain_block_data_nop>(p);
}

catchain_block_data_nop::catchain_block_data_nop(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void catchain_block_data_nop::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void catchain_block_data_nop::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void catchain_block_data_nop::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_data_nop");
    s.store_class_end();
  }
}

catchain_block_data_vector::catchain_block_data_vector()
  : msgs_()
{}

catchain_block_data_vector::catchain_block_data_vector(std::vector<td::BufferSlice> &&msgs_)
  : msgs_(std::move(msgs_))
{}

const std::int32_t catchain_block_data_vector::ID;

object_ptr<catchain_block_inner_Data> catchain_block_data_vector::fetch(td::TlParser &p) {
  return make_object<catchain_block_data_vector>(p);
}

catchain_block_data_vector::catchain_block_data_vector(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : msgs_(TlFetchVector<TlFetchBytes<td::BufferSlice>>::parse(p))
#undef FAIL
{}

void catchain_block_data_vector::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(msgs_, s);
}

void catchain_block_data_vector::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(msgs_, s);
}

void catchain_block_data_vector::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_block_data_vector");
    { const std::vector<td::BufferSlice> &v = msgs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("msgs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_bytes_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_config_global::catchain_config_global()
  : tag_()
  , nodes_()
{}

catchain_config_global::catchain_config_global(td::Bits256 const &tag_, std::vector<object_ptr<PublicKey>> &&nodes_)
  : tag_(tag_)
  , nodes_(std::move(nodes_))
{}

const std::int32_t catchain_config_global::ID;

object_ptr<catchain_config_global> catchain_config_global::fetch(td::TlParser &p) {
  return make_object<catchain_config_global>(p);
}

catchain_config_global::catchain_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : tag_(TlFetchInt256::parse(p))
  , nodes_(TlFetchVector<TlFetchObject<PublicKey>>::parse(p))
#undef FAIL
{}

void catchain_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(tag_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(nodes_, s);
}

void catchain_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(tag_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(nodes_, s);
}

void catchain_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_config_global");
    s.store_field("tag", tag_);
    { const std::vector<object_ptr<PublicKey>> &v = nodes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("nodes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

config_global::config_global()
  : adnl_()
  , dht_()
  , validator_()
{}

config_global::config_global(object_ptr<adnl_config_global> &&adnl_, object_ptr<dht_config_global> &&dht_, object_ptr<validator_config_global> &&validator_)
  : adnl_(std::move(adnl_))
  , dht_(std::move(dht_))
  , validator_(std::move(validator_))
{}

const std::int32_t config_global::ID;

object_ptr<config_global> config_global::fetch(td::TlParser &p) {
  return make_object<config_global>(p);
}

config_global::config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : adnl_(TlFetchObject<adnl_config_global>::parse(p))
  , dht_(TlFetchObject<dht_config_global>::parse(p))
  , validator_(TlFetchObject<validator_config_global>::parse(p))
#undef FAIL
{}

void config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(adnl_, s);
  TlStoreObject::store(dht_, s);
  TlStoreObject::store(validator_, s);
}

void config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(adnl_, s);
  TlStoreObject::store(dht_, s);
  TlStoreObject::store(validator_, s);
}

void config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "config_global");
    if (adnl_ == nullptr) { s.store_field("adnl", "null"); } else { adnl_->store(s, "adnl"); }
    if (dht_ == nullptr) { s.store_field("dht", "null"); } else { dht_->store(s, "dht"); }
    if (validator_ == nullptr) { s.store_field("validator", "null"); } else { validator_->store(s, "validator"); }
    s.store_class_end();
  }
}

config_local::config_local()
  : local_ids_()
  , dht_()
  , validators_()
  , liteservers_()
  , control_()
{}

config_local::config_local(std::vector<object_ptr<id_config_local>> &&local_ids_, std::vector<object_ptr<dht_config_Local>> &&dht_, std::vector<object_ptr<validator_config_Local>> &&validators_, std::vector<object_ptr<liteserver_config_Local>> &&liteservers_, std::vector<object_ptr<control_config_local>> &&control_)
  : local_ids_(std::move(local_ids_))
  , dht_(std::move(dht_))
  , validators_(std::move(validators_))
  , liteservers_(std::move(liteservers_))
  , control_(std::move(control_))
{}

const std::int32_t config_local::ID;

object_ptr<config_local> config_local::fetch(td::TlParser &p) {
  return make_object<config_local>(p);
}

config_local::config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : local_ids_(TlFetchVector<TlFetchObject<id_config_local>>::parse(p))
  , dht_(TlFetchVector<TlFetchObject<dht_config_Local>>::parse(p))
  , validators_(TlFetchVector<TlFetchObject<validator_config_Local>>::parse(p))
  , liteservers_(TlFetchVector<TlFetchObject<liteserver_config_Local>>::parse(p))
  , control_(TlFetchVector<TlFetchObject<control_config_local>>::parse(p))
#undef FAIL
{}

void config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(local_ids_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(dht_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(validators_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(liteservers_, s);
  TlStoreVector<TlStoreObject>::store(control_, s);
}

void config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(local_ids_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(dht_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(validators_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(liteservers_, s);
  TlStoreVector<TlStoreObject>::store(control_, s);
}

void config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "config_local");
    { const std::vector<object_ptr<id_config_local>> &v = local_ids_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("local_ids", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<dht_config_Local>> &v = dht_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("dht", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<validator_config_Local>> &v = validators_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("validators", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<liteserver_config_Local>> &v = liteservers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("liteservers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<control_config_local>> &v = control_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("control", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

control_config_local::control_config_local()
  : priv_()
  , pub_()
  , port_()
{}

control_config_local::control_config_local(object_ptr<PrivateKey> &&priv_, td::Bits256 const &pub_, std::int32_t port_)
  : priv_(std::move(priv_))
  , pub_(pub_)
  , port_(port_)
{}

const std::int32_t control_config_local::ID;

object_ptr<control_config_local> control_config_local::fetch(td::TlParser &p) {
  return make_object<control_config_local>(p);
}

control_config_local::control_config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : priv_(TlFetchObject<PrivateKey>::parse(p))
  , pub_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void control_config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(priv_, s);
  TlStoreBinary::store(pub_, s);
  TlStoreBinary::store(port_, s);
}

void control_config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(priv_, s);
  TlStoreBinary::store(pub_, s);
  TlStoreBinary::store(port_, s);
}

void control_config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "control_config_local");
    if (priv_ == nullptr) { s.store_field("priv", "null"); } else { priv_->store(s, "priv"); }
    s.store_field("pub", pub_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

db_candidate::db_candidate()
  : source_()
  , id_()
  , data_()
  , collated_data_()
{}

db_candidate::db_candidate(object_ptr<PublicKey> &&source_, object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&data_, td::BufferSlice &&collated_data_)
  : source_(std::move(source_))
  , id_(std::move(id_))
  , data_(std::move(data_))
  , collated_data_(std::move(collated_data_))
{}

const std::int32_t db_candidate::ID;

object_ptr<db_candidate> db_candidate::fetch(td::TlParser &p) {
  return make_object<db_candidate>(p);
}

db_candidate::db_candidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : source_(TlFetchObject<PublicKey>::parse(p))
  , id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
  , collated_data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void db_candidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(source_, s);
  TlStoreObject::store(id_, s);
  TlStoreString::store(data_, s);
  TlStoreString::store(collated_data_, s);
}

void db_candidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(source_, s);
  TlStoreObject::store(id_, s);
  TlStoreString::store(data_, s);
  TlStoreString::store(collated_data_, s);
}

void db_candidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_candidate");
    if (source_ == nullptr) { s.store_field("source", "null"); } else { source_->store(s, "source"); }
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_bytes_field("data", data_);
    s.store_bytes_field("collated_data", collated_data_);
    s.store_class_end();
  }
}

object_ptr<db_block_Info> db_block_Info::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_block_info::ID:
      return db_block_info::fetch(p);
    case db_block_packedInfo::ID:
      return db_block_packedInfo::fetch(p);
    case db_block_archivedInfo::ID:
      return db_block_archivedInfo::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_block_info::db_block_info()
  : id_()
  , flags_()
  , prev_left_()
  , prev_right_()
  , next_left_()
  , next_right_()
  , lt_()
  , ts_()
  , state_()
  , masterchain_ref_seqno_()
{}

db_block_info::db_block_info(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t flags_, object_ptr<tonNode_blockIdExt> &&prev_left_, object_ptr<tonNode_blockIdExt> &&prev_right_, object_ptr<tonNode_blockIdExt> &&next_left_, object_ptr<tonNode_blockIdExt> &&next_right_, std::int64_t lt_, std::int32_t ts_, td::Bits256 const &state_, std::int32_t masterchain_ref_seqno_)
  : id_(std::move(id_))
  , flags_(flags_)
  , prev_left_(std::move(prev_left_))
  , prev_right_(std::move(prev_right_))
  , next_left_(std::move(next_left_))
  , next_right_(std::move(next_right_))
  , lt_(lt_)
  , ts_(ts_)
  , state_(state_)
  , masterchain_ref_seqno_(masterchain_ref_seqno_)
{}

const std::int32_t db_block_info::ID;

object_ptr<db_block_Info> db_block_info::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  object_ptr<db_block_info> res = make_object<db_block_info>();
  std::int32_t var0;
  res->id_ = TlFetchObject<tonNode_blockIdExt>::parse(p);
  if ((var0 = res->flags_ = TlFetchInt::parse(p)) < 0) { FAIL("Variable of type # can't be negative"); }
  if (var0 & 2) { res->prev_left_ = TlFetchObject<tonNode_blockIdExt>::parse(p); }
  if (var0 & 4) { res->prev_right_ = TlFetchObject<tonNode_blockIdExt>::parse(p); }
  if (var0 & 8) { res->next_left_ = TlFetchObject<tonNode_blockIdExt>::parse(p); }
  if (var0 & 16) { res->next_right_ = TlFetchObject<tonNode_blockIdExt>::parse(p); }
  if (var0 & 8192) { res->lt_ = TlFetchLong::parse(p); }
  if (var0 & 16384) { res->ts_ = TlFetchInt::parse(p); }
  if (var0 & 131072) { res->state_ = TlFetchInt256::parse(p); }
  if (var0 & 8388608) { res->masterchain_ref_seqno_ = TlFetchInt::parse(p); }
  if (p.get_error()) { FAIL(""); }
  return std::move(res);
#undef FAIL
}

void db_block_info::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreObject::store(id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 2) { TlStoreObject::store(prev_left_, s); }
  if (var0 & 4) { TlStoreObject::store(prev_right_, s); }
  if (var0 & 8) { TlStoreObject::store(next_left_, s); }
  if (var0 & 16) { TlStoreObject::store(next_right_, s); }
  if (var0 & 8192) { TlStoreBinary::store(lt_, s); }
  if (var0 & 16384) { TlStoreBinary::store(ts_, s); }
  if (var0 & 131072) { TlStoreBinary::store(state_, s); }
  if (var0 & 8388608) { TlStoreBinary::store(masterchain_ref_seqno_, s); }
}

void db_block_info::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreObject::store(id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 2) { TlStoreObject::store(prev_left_, s); }
  if (var0 & 4) { TlStoreObject::store(prev_right_, s); }
  if (var0 & 8) { TlStoreObject::store(next_left_, s); }
  if (var0 & 16) { TlStoreObject::store(next_right_, s); }
  if (var0 & 8192) { TlStoreBinary::store(lt_, s); }
  if (var0 & 16384) { TlStoreBinary::store(ts_, s); }
  if (var0 & 131072) { TlStoreBinary::store(state_, s); }
  if (var0 & 8388608) { TlStoreBinary::store(masterchain_ref_seqno_, s); }
}

void db_block_info::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_block_info");
  std::int32_t var0;
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("flags", (var0 = flags_));
    if (var0 & 2) { if (prev_left_ == nullptr) { s.store_field("prev_left", "null"); } else { prev_left_->store(s, "prev_left"); } }
    if (var0 & 4) { if (prev_right_ == nullptr) { s.store_field("prev_right", "null"); } else { prev_right_->store(s, "prev_right"); } }
    if (var0 & 8) { if (next_left_ == nullptr) { s.store_field("next_left", "null"); } else { next_left_->store(s, "next_left"); } }
    if (var0 & 16) { if (next_right_ == nullptr) { s.store_field("next_right", "null"); } else { next_right_->store(s, "next_right"); } }
    if (var0 & 8192) { s.store_field("lt", lt_); }
    if (var0 & 16384) { s.store_field("ts", ts_); }
    if (var0 & 131072) { s.store_field("state", state_); }
    if (var0 & 8388608) { s.store_field("masterchain_ref_seqno", masterchain_ref_seqno_); }
    s.store_class_end();
  }
}

db_block_packedInfo::db_block_packedInfo()
  : id_()
  , unixtime_()
  , offset_()
{}

db_block_packedInfo::db_block_packedInfo(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t unixtime_, std::int64_t offset_)
  : id_(std::move(id_))
  , unixtime_(unixtime_)
  , offset_(offset_)
{}

const std::int32_t db_block_packedInfo::ID;

object_ptr<db_block_Info> db_block_packedInfo::fetch(td::TlParser &p) {
  return make_object<db_block_packedInfo>(p);
}

db_block_packedInfo::db_block_packedInfo(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , unixtime_(TlFetchInt::parse(p))
  , offset_(TlFetchLong::parse(p))
#undef FAIL
{}

void db_block_packedInfo::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(unixtime_, s);
  TlStoreBinary::store(offset_, s);
}

void db_block_packedInfo::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(unixtime_, s);
  TlStoreBinary::store(offset_, s);
}

void db_block_packedInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_block_packedInfo");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("unixtime", unixtime_);
    s.store_field("offset", offset_);
    s.store_class_end();
  }
}

db_block_archivedInfo::db_block_archivedInfo()
  : id_()
  , flags_()
  , next_()
{}

db_block_archivedInfo::db_block_archivedInfo(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t flags_, object_ptr<tonNode_blockIdExt> &&next_)
  : id_(std::move(id_))
  , flags_(flags_)
  , next_(std::move(next_))
{}

const std::int32_t db_block_archivedInfo::ID;

object_ptr<db_block_Info> db_block_archivedInfo::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  object_ptr<db_block_archivedInfo> res = make_object<db_block_archivedInfo>();
  std::int32_t var0;
  res->id_ = TlFetchObject<tonNode_blockIdExt>::parse(p);
  if ((var0 = res->flags_ = TlFetchInt::parse(p)) < 0) { FAIL("Variable of type # can't be negative"); }
  if (var0 & 1) { res->next_ = TlFetchObject<tonNode_blockIdExt>::parse(p); }
  if (p.get_error()) { FAIL(""); }
  return std::move(res);
#undef FAIL
}

void db_block_archivedInfo::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreObject::store(id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreObject::store(next_, s); }
}

void db_block_archivedInfo::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  std::int32_t var0;
  TlStoreObject::store(id_, s);
  TlStoreBinary::store((var0 = flags_), s);
  if (var0 & 1) { TlStoreObject::store(next_, s); }
}

void db_block_archivedInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_block_archivedInfo");
  std::int32_t var0;
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("flags", (var0 = flags_));
    if (var0 & 1) { if (next_ == nullptr) { s.store_field("next", "null"); } else { next_->store(s, "next"); } }
    s.store_class_end();
  }
}

object_ptr<db_blockdb_Key> db_blockdb_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_blockdb_key_lru::ID:
      return db_blockdb_key_lru::fetch(p);
    case db_blockdb_key_value::ID:
      return db_blockdb_key_value::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_blockdb_key_lru::db_blockdb_key_lru()
  : id_()
{}

db_blockdb_key_lru::db_blockdb_key_lru(object_ptr<tonNode_blockIdExt> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t db_blockdb_key_lru::ID;

object_ptr<db_blockdb_Key> db_blockdb_key_lru::fetch(td::TlParser &p) {
  return make_object<db_blockdb_key_lru>(p);
}

db_blockdb_key_lru::db_blockdb_key_lru(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_blockdb_key_lru::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_blockdb_key_lru::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_blockdb_key_lru::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_blockdb_key_lru");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

db_blockdb_key_value::db_blockdb_key_value()
  : id_()
{}

db_blockdb_key_value::db_blockdb_key_value(object_ptr<tonNode_blockIdExt> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t db_blockdb_key_value::ID;

object_ptr<db_blockdb_Key> db_blockdb_key_value::fetch(td::TlParser &p) {
  return make_object<db_blockdb_key_value>(p);
}

db_blockdb_key_value::db_blockdb_key_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_blockdb_key_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_blockdb_key_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_blockdb_key_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_blockdb_key_value");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

db_blockdb_lru::db_blockdb_lru()
  : id_()
  , prev_()
  , next_()
{}

db_blockdb_lru::db_blockdb_lru(object_ptr<tonNode_blockIdExt> &&id_, td::Bits256 const &prev_, td::Bits256 const &next_)
  : id_(std::move(id_))
  , prev_(prev_)
  , next_(next_)
{}

const std::int32_t db_blockdb_lru::ID;

object_ptr<db_blockdb_lru> db_blockdb_lru::fetch(td::TlParser &p) {
  return make_object<db_blockdb_lru>(p);
}

db_blockdb_lru::db_blockdb_lru(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , prev_(TlFetchInt256::parse(p))
  , next_(TlFetchInt256::parse(p))
#undef FAIL
{}

void db_blockdb_lru::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
}

void db_blockdb_lru::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
}

void db_blockdb_lru::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_blockdb_lru");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("prev", prev_);
    s.store_field("next", next_);
    s.store_class_end();
  }
}

db_blockdb_value::db_blockdb_value()
  : next_()
  , data_()
{}

db_blockdb_value::db_blockdb_value(object_ptr<tonNode_blockIdExt> &&next_, td::BufferSlice &&data_)
  : next_(std::move(next_))
  , data_(std::move(data_))
{}

const std::int32_t db_blockdb_value::ID;

object_ptr<db_blockdb_value> db_blockdb_value::fetch(td::TlParser &p) {
  return make_object<db_blockdb_value>(p);
}

db_blockdb_value::db_blockdb_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : next_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void db_blockdb_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(next_, s);
  TlStoreString::store(data_, s);
}

void db_blockdb_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(next_, s);
  TlStoreString::store(data_, s);
}

void db_blockdb_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_blockdb_value");
    if (next_ == nullptr) { s.store_field("next", "null"); } else { next_->store(s, "next"); }
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

db_candidate_id::db_candidate_id()
  : source_()
  , id_()
  , collated_data_file_hash_()
{}

db_candidate_id::db_candidate_id(object_ptr<PublicKey> &&source_, object_ptr<tonNode_blockIdExt> &&id_, td::Bits256 const &collated_data_file_hash_)
  : source_(std::move(source_))
  , id_(std::move(id_))
  , collated_data_file_hash_(collated_data_file_hash_)
{}

const std::int32_t db_candidate_id::ID;

object_ptr<db_candidate_id> db_candidate_id::fetch(td::TlParser &p) {
  return make_object<db_candidate_id>(p);
}

db_candidate_id::db_candidate_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : source_(TlFetchObject<PublicKey>::parse(p))
  , id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , collated_data_file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void db_candidate_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(source_, s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void db_candidate_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(source_, s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void db_candidate_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_candidate_id");
    if (source_ == nullptr) { s.store_field("source", "null"); } else { source_->store(s, "source"); }
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("collated_data_file_hash", collated_data_file_hash_);
    s.store_class_end();
  }
}

db_celldb_value::db_celldb_value()
  : block_id_()
  , prev_()
  , next_()
  , root_hash_()
{}

db_celldb_value::db_celldb_value(object_ptr<tonNode_blockIdExt> &&block_id_, td::Bits256 const &prev_, td::Bits256 const &next_, td::Bits256 const &root_hash_)
  : block_id_(std::move(block_id_))
  , prev_(prev_)
  , next_(next_)
  , root_hash_(root_hash_)
{}

const std::int32_t db_celldb_value::ID;

object_ptr<db_celldb_value> db_celldb_value::fetch(td::TlParser &p) {
  return make_object<db_celldb_value>(p);
}

db_celldb_value::db_celldb_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , prev_(TlFetchInt256::parse(p))
  , next_(TlFetchInt256::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void db_celldb_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
  TlStoreBinary::store(root_hash_, s);
}

void db_celldb_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
  TlStoreBinary::store(root_hash_, s);
}

void db_celldb_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_celldb_value");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_field("prev", prev_);
    s.store_field("next", next_);
    s.store_field("root_hash", root_hash_);
    s.store_class_end();
  }
}

db_celldb_key_value::db_celldb_key_value()
  : hash_()
{}

db_celldb_key_value::db_celldb_key_value(td::Bits256 const &hash_)
  : hash_(hash_)
{}

const std::int32_t db_celldb_key_value::ID;

object_ptr<db_celldb_key_value> db_celldb_key_value::fetch(td::TlParser &p) {
  return make_object<db_celldb_key_value>(p);
}

db_celldb_key_value::db_celldb_key_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void db_celldb_key_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void db_celldb_key_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void db_celldb_key_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_celldb_key_value");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

object_ptr<db_filedb_Key> db_filedb_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_filedb_key_empty::ID:
      return db_filedb_key_empty::fetch(p);
    case db_filedb_key_blockFile::ID:
      return db_filedb_key_blockFile::fetch(p);
    case db_filedb_key_zeroStateFile::ID:
      return db_filedb_key_zeroStateFile::fetch(p);
    case db_filedb_key_persistentStateFile::ID:
      return db_filedb_key_persistentStateFile::fetch(p);
    case db_filedb_key_proof::ID:
      return db_filedb_key_proof::fetch(p);
    case db_filedb_key_proofLink::ID:
      return db_filedb_key_proofLink::fetch(p);
    case db_filedb_key_signatures::ID:
      return db_filedb_key_signatures::fetch(p);
    case db_filedb_key_candidate::ID:
      return db_filedb_key_candidate::fetch(p);
    case db_filedb_key_blockInfo::ID:
      return db_filedb_key_blockInfo::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_filedb_key_empty::db_filedb_key_empty() {
}

const std::int32_t db_filedb_key_empty::ID;

object_ptr<db_filedb_Key> db_filedb_key_empty::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_empty>(p);
}

db_filedb_key_empty::db_filedb_key_empty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_filedb_key_empty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_filedb_key_empty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_filedb_key_empty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_empty");
    s.store_class_end();
  }
}

db_filedb_key_blockFile::db_filedb_key_blockFile()
  : block_id_()
{}

db_filedb_key_blockFile::db_filedb_key_blockFile(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_blockFile::ID;

object_ptr<db_filedb_Key> db_filedb_key_blockFile::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_blockFile>(p);
}

db_filedb_key_blockFile::db_filedb_key_blockFile(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_blockFile::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_blockFile::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_blockFile::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_blockFile");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_zeroStateFile::db_filedb_key_zeroStateFile()
  : block_id_()
{}

db_filedb_key_zeroStateFile::db_filedb_key_zeroStateFile(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_zeroStateFile::ID;

object_ptr<db_filedb_Key> db_filedb_key_zeroStateFile::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_zeroStateFile>(p);
}

db_filedb_key_zeroStateFile::db_filedb_key_zeroStateFile(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_zeroStateFile::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_zeroStateFile::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_zeroStateFile::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_zeroStateFile");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_persistentStateFile::db_filedb_key_persistentStateFile()
  : block_id_()
  , masterchain_block_id_()
{}

db_filedb_key_persistentStateFile::db_filedb_key_persistentStateFile(object_ptr<tonNode_blockIdExt> &&block_id_, object_ptr<tonNode_blockIdExt> &&masterchain_block_id_)
  : block_id_(std::move(block_id_))
  , masterchain_block_id_(std::move(masterchain_block_id_))
{}

const std::int32_t db_filedb_key_persistentStateFile::ID;

object_ptr<db_filedb_Key> db_filedb_key_persistentStateFile::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_persistentStateFile>(p);
}

db_filedb_key_persistentStateFile::db_filedb_key_persistentStateFile(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , masterchain_block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_persistentStateFile::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
  TlStoreObject::store(masterchain_block_id_, s);
}

void db_filedb_key_persistentStateFile::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
  TlStoreObject::store(masterchain_block_id_, s);
}

void db_filedb_key_persistentStateFile::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_persistentStateFile");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    if (masterchain_block_id_ == nullptr) { s.store_field("masterchain_block_id", "null"); } else { masterchain_block_id_->store(s, "masterchain_block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_proof::db_filedb_key_proof()
  : block_id_()
{}

db_filedb_key_proof::db_filedb_key_proof(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_proof::ID;

object_ptr<db_filedb_Key> db_filedb_key_proof::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_proof>(p);
}

db_filedb_key_proof::db_filedb_key_proof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_proof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_proof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_proof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_proof");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_proofLink::db_filedb_key_proofLink()
  : block_id_()
{}

db_filedb_key_proofLink::db_filedb_key_proofLink(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_proofLink::ID;

object_ptr<db_filedb_Key> db_filedb_key_proofLink::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_proofLink>(p);
}

db_filedb_key_proofLink::db_filedb_key_proofLink(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_proofLink::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_proofLink::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_proofLink::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_proofLink");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_signatures::db_filedb_key_signatures()
  : block_id_()
{}

db_filedb_key_signatures::db_filedb_key_signatures(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_signatures::ID;

object_ptr<db_filedb_Key> db_filedb_key_signatures::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_signatures>(p);
}

db_filedb_key_signatures::db_filedb_key_signatures(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_signatures::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_signatures::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_signatures::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_signatures");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_key_candidate::db_filedb_key_candidate()
  : id_()
{}

db_filedb_key_candidate::db_filedb_key_candidate(object_ptr<db_candidate_id> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t db_filedb_key_candidate::ID;

object_ptr<db_filedb_Key> db_filedb_key_candidate::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_candidate>(p);
}

db_filedb_key_candidate::db_filedb_key_candidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<db_candidate_id>::parse(p))
#undef FAIL
{}

void db_filedb_key_candidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_filedb_key_candidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void db_filedb_key_candidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_candidate");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

db_filedb_key_blockInfo::db_filedb_key_blockInfo()
  : block_id_()
{}

db_filedb_key_blockInfo::db_filedb_key_blockInfo(object_ptr<tonNode_blockIdExt> &&block_id_)
  : block_id_(std::move(block_id_))
{}

const std::int32_t db_filedb_key_blockInfo::ID;

object_ptr<db_filedb_Key> db_filedb_key_blockInfo::fetch(td::TlParser &p) {
  return make_object<db_filedb_key_blockInfo>(p);
}

db_filedb_key_blockInfo::db_filedb_key_blockInfo(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_filedb_key_blockInfo::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_blockInfo::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_id_, s);
}

void db_filedb_key_blockInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_key_blockInfo");
    if (block_id_ == nullptr) { s.store_field("block_id", "null"); } else { block_id_->store(s, "block_id"); }
    s.store_class_end();
  }
}

db_filedb_value::db_filedb_value()
  : key_()
  , prev_()
  , next_()
  , file_hash_()
{}

db_filedb_value::db_filedb_value(object_ptr<db_filedb_Key> &&key_, td::Bits256 const &prev_, td::Bits256 const &next_, td::Bits256 const &file_hash_)
  : key_(std::move(key_))
  , prev_(prev_)
  , next_(next_)
  , file_hash_(file_hash_)
{}

const std::int32_t db_filedb_value::ID;

object_ptr<db_filedb_value> db_filedb_value::fetch(td::TlParser &p) {
  return make_object<db_filedb_value>(p);
}

db_filedb_value::db_filedb_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchObject<db_filedb_Key>::parse(p))
  , prev_(TlFetchInt256::parse(p))
  , next_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void db_filedb_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
  TlStoreBinary::store(file_hash_, s);
}

void db_filedb_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
  TlStoreBinary::store(prev_, s);
  TlStoreBinary::store(next_, s);
  TlStoreBinary::store(file_hash_, s);
}

void db_filedb_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_filedb_value");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_field("prev", prev_);
    s.store_field("next", next_);
    s.store_field("file_hash", file_hash_);
    s.store_class_end();
  }
}

object_ptr<db_files_Key> db_files_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_files_index_key::ID:
      return db_files_index_key::fetch(p);
    case db_files_package_key::ID:
      return db_files_package_key::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_files_index_key::db_files_index_key() {
}

const std::int32_t db_files_index_key::ID;

object_ptr<db_files_Key> db_files_index_key::fetch(td::TlParser &p) {
  return make_object<db_files_index_key>(p);
}

db_files_index_key::db_files_index_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_files_index_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_files_index_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_files_index_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_files_index_key");
    s.store_class_end();
  }
}

db_files_package_key::db_files_package_key()
  : package_id_()
  , key_()
  , temp_()
{}

db_files_package_key::db_files_package_key(std::int32_t package_id_, bool key_, bool temp_)
  : package_id_(package_id_)
  , key_(key_)
  , temp_(temp_)
{}

const std::int32_t db_files_package_key::ID;

object_ptr<db_files_Key> db_files_package_key::fetch(td::TlParser &p) {
  return make_object<db_files_package_key>(p);
}

db_files_package_key::db_files_package_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : package_id_(TlFetchInt::parse(p))
  , key_(TlFetchBool::parse(p))
  , temp_(TlFetchBool::parse(p))
#undef FAIL
{}

void db_files_package_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(package_id_, s);
  TlStoreBool::store(key_, s);
  TlStoreBool::store(temp_, s);
}

void db_files_package_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(package_id_, s);
  TlStoreBool::store(key_, s);
  TlStoreBool::store(temp_, s);
}

void db_files_package_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_files_package_key");
    s.store_field("package_id", package_id_);
    s.store_field("key", key_);
    s.store_field("temp", temp_);
    s.store_class_end();
  }
}

db_files_index_value::db_files_index_value()
  : packages_()
  , key_packages_()
  , temp_packages_()
{}

db_files_index_value::db_files_index_value(std::vector<std::int32_t> &&packages_, std::vector<std::int32_t> &&key_packages_, std::vector<std::int32_t> &&temp_packages_)
  : packages_(std::move(packages_))
  , key_packages_(std::move(key_packages_))
  , temp_packages_(std::move(temp_packages_))
{}

const std::int32_t db_files_index_value::ID;

object_ptr<db_files_index_value> db_files_index_value::fetch(td::TlParser &p) {
  return make_object<db_files_index_value>(p);
}

db_files_index_value::db_files_index_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : packages_(TlFetchVector<TlFetchInt>::parse(p))
  , key_packages_(TlFetchVector<TlFetchInt>::parse(p))
  , temp_packages_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void db_files_index_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(packages_, s);
  TlStoreVector<TlStoreBinary>::store(key_packages_, s);
  TlStoreVector<TlStoreBinary>::store(temp_packages_, s);
}

void db_files_index_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(packages_, s);
  TlStoreVector<TlStoreBinary>::store(key_packages_, s);
  TlStoreVector<TlStoreBinary>::store(temp_packages_, s);
}

void db_files_index_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_files_index_value");
    { const std::vector<std::int32_t> &v = packages_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("packages", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = key_packages_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("key_packages", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = temp_packages_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("temp_packages", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

db_files_package_firstBlock::db_files_package_firstBlock()
  : workchain_()
  , shard_()
  , seqno_()
  , unixtime_()
  , lt_()
{}

db_files_package_firstBlock::db_files_package_firstBlock(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_, std::int32_t unixtime_, std::int64_t lt_)
  : workchain_(workchain_)
  , shard_(shard_)
  , seqno_(seqno_)
  , unixtime_(unixtime_)
  , lt_(lt_)
{}

const std::int32_t db_files_package_firstBlock::ID;

object_ptr<db_files_package_firstBlock> db_files_package_firstBlock::fetch(td::TlParser &p) {
  return make_object<db_files_package_firstBlock>(p);
}

db_files_package_firstBlock::db_files_package_firstBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , unixtime_(TlFetchInt::parse(p))
  , lt_(TlFetchLong::parse(p))
#undef FAIL
{}

void db_files_package_firstBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(unixtime_, s);
  TlStoreBinary::store(lt_, s);
}

void db_files_package_firstBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(unixtime_, s);
  TlStoreBinary::store(lt_, s);
}

void db_files_package_firstBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_files_package_firstBlock");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("seqno", seqno_);
    s.store_field("unixtime", unixtime_);
    s.store_field("lt", lt_);
    s.store_class_end();
  }
}

db_files_package_value::db_files_package_value()
  : package_id_()
  , key_()
  , temp_()
  , firstblocks_()
  , deleted_()
{}

db_files_package_value::db_files_package_value(std::int32_t package_id_, bool key_, bool temp_, std::vector<object_ptr<db_files_package_firstBlock>> &&firstblocks_, bool deleted_)
  : package_id_(package_id_)
  , key_(key_)
  , temp_(temp_)
  , firstblocks_(std::move(firstblocks_))
  , deleted_(deleted_)
{}

const std::int32_t db_files_package_value::ID;

object_ptr<db_files_package_value> db_files_package_value::fetch(td::TlParser &p) {
  return make_object<db_files_package_value>(p);
}

db_files_package_value::db_files_package_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : package_id_(TlFetchInt::parse(p))
  , key_(TlFetchBool::parse(p))
  , temp_(TlFetchBool::parse(p))
  , firstblocks_(TlFetchVector<TlFetchObject<db_files_package_firstBlock>>::parse(p))
  , deleted_(TlFetchBool::parse(p))
#undef FAIL
{}

void db_files_package_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(package_id_, s);
  TlStoreBool::store(key_, s);
  TlStoreBool::store(temp_, s);
  TlStoreVector<TlStoreObject>::store(firstblocks_, s);
  TlStoreBool::store(deleted_, s);
}

void db_files_package_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(package_id_, s);
  TlStoreBool::store(key_, s);
  TlStoreBool::store(temp_, s);
  TlStoreVector<TlStoreObject>::store(firstblocks_, s);
  TlStoreBool::store(deleted_, s);
}

void db_files_package_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_files_package_value");
    s.store_field("package_id", package_id_);
    s.store_field("key", key_);
    s.store_field("temp", temp_);
    { const std::vector<object_ptr<db_files_package_firstBlock>> &v = firstblocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("firstblocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("deleted", deleted_);
    s.store_class_end();
  }
}

object_ptr<db_lt_Key> db_lt_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_lt_el_key::ID:
      return db_lt_el_key::fetch(p);
    case db_lt_desc_key::ID:
      return db_lt_desc_key::fetch(p);
    case db_lt_shard_key::ID:
      return db_lt_shard_key::fetch(p);
    case db_lt_status_key::ID:
      return db_lt_status_key::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_lt_el_key::db_lt_el_key()
  : workchain_()
  , shard_()
  , idx_()
{}

db_lt_el_key::db_lt_el_key(std::int32_t workchain_, std::int64_t shard_, std::int32_t idx_)
  : workchain_(workchain_)
  , shard_(shard_)
  , idx_(idx_)
{}

const std::int32_t db_lt_el_key::ID;

object_ptr<db_lt_Key> db_lt_el_key::fetch(td::TlParser &p) {
  return make_object<db_lt_el_key>(p);
}

db_lt_el_key::db_lt_el_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , idx_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_lt_el_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(idx_, s);
}

void db_lt_el_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(idx_, s);
}

void db_lt_el_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_el_key");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("idx", idx_);
    s.store_class_end();
  }
}

db_lt_desc_key::db_lt_desc_key()
  : workchain_()
  , shard_()
{}

db_lt_desc_key::db_lt_desc_key(std::int32_t workchain_, std::int64_t shard_)
  : workchain_(workchain_)
  , shard_(shard_)
{}

const std::int32_t db_lt_desc_key::ID;

object_ptr<db_lt_Key> db_lt_desc_key::fetch(td::TlParser &p) {
  return make_object<db_lt_desc_key>(p);
}

db_lt_desc_key::db_lt_desc_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
#undef FAIL
{}

void db_lt_desc_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
}

void db_lt_desc_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
}

void db_lt_desc_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_desc_key");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_class_end();
  }
}

db_lt_shard_key::db_lt_shard_key()
  : idx_()
{}

db_lt_shard_key::db_lt_shard_key(std::int32_t idx_)
  : idx_(idx_)
{}

const std::int32_t db_lt_shard_key::ID;

object_ptr<db_lt_Key> db_lt_shard_key::fetch(td::TlParser &p) {
  return make_object<db_lt_shard_key>(p);
}

db_lt_shard_key::db_lt_shard_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : idx_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_lt_shard_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(idx_, s);
}

void db_lt_shard_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(idx_, s);
}

void db_lt_shard_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_shard_key");
    s.store_field("idx", idx_);
    s.store_class_end();
  }
}

db_lt_status_key::db_lt_status_key() {
}

const std::int32_t db_lt_status_key::ID;

object_ptr<db_lt_Key> db_lt_status_key::fetch(td::TlParser &p) {
  return make_object<db_lt_status_key>(p);
}

db_lt_status_key::db_lt_status_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_lt_status_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_lt_status_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_lt_status_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_status_key");
    s.store_class_end();
  }
}

db_lt_desc_value::db_lt_desc_value()
  : first_idx_()
  , last_idx_()
  , last_seqno_()
  , last_lt_()
  , last_ts_()
{}

db_lt_desc_value::db_lt_desc_value(std::int32_t first_idx_, std::int32_t last_idx_, std::int32_t last_seqno_, std::int64_t last_lt_, std::int32_t last_ts_)
  : first_idx_(first_idx_)
  , last_idx_(last_idx_)
  , last_seqno_(last_seqno_)
  , last_lt_(last_lt_)
  , last_ts_(last_ts_)
{}

const std::int32_t db_lt_desc_value::ID;

object_ptr<db_lt_desc_value> db_lt_desc_value::fetch(td::TlParser &p) {
  return make_object<db_lt_desc_value>(p);
}

db_lt_desc_value::db_lt_desc_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : first_idx_(TlFetchInt::parse(p))
  , last_idx_(TlFetchInt::parse(p))
  , last_seqno_(TlFetchInt::parse(p))
  , last_lt_(TlFetchLong::parse(p))
  , last_ts_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_lt_desc_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(first_idx_, s);
  TlStoreBinary::store(last_idx_, s);
  TlStoreBinary::store(last_seqno_, s);
  TlStoreBinary::store(last_lt_, s);
  TlStoreBinary::store(last_ts_, s);
}

void db_lt_desc_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(first_idx_, s);
  TlStoreBinary::store(last_idx_, s);
  TlStoreBinary::store(last_seqno_, s);
  TlStoreBinary::store(last_lt_, s);
  TlStoreBinary::store(last_ts_, s);
}

void db_lt_desc_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_desc_value");
    s.store_field("first_idx", first_idx_);
    s.store_field("last_idx", last_idx_);
    s.store_field("last_seqno", last_seqno_);
    s.store_field("last_lt", last_lt_);
    s.store_field("last_ts", last_ts_);
    s.store_class_end();
  }
}

db_lt_el_value::db_lt_el_value()
  : id_()
  , lt_()
  , ts_()
{}

db_lt_el_value::db_lt_el_value(object_ptr<tonNode_blockIdExt> &&id_, std::int64_t lt_, std::int32_t ts_)
  : id_(std::move(id_))
  , lt_(lt_)
  , ts_(ts_)
{}

const std::int32_t db_lt_el_value::ID;

object_ptr<db_lt_el_value> db_lt_el_value::fetch(td::TlParser &p) {
  return make_object<db_lt_el_value>(p);
}

db_lt_el_value::db_lt_el_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , lt_(TlFetchLong::parse(p))
  , ts_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_lt_el_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(lt_, s);
  TlStoreBinary::store(ts_, s);
}

void db_lt_el_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(lt_, s);
  TlStoreBinary::store(ts_, s);
}

void db_lt_el_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_el_value");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("lt", lt_);
    s.store_field("ts", ts_);
    s.store_class_end();
  }
}

db_lt_shard_value::db_lt_shard_value()
  : workchain_()
  , shard_()
{}

db_lt_shard_value::db_lt_shard_value(std::int32_t workchain_, std::int64_t shard_)
  : workchain_(workchain_)
  , shard_(shard_)
{}

const std::int32_t db_lt_shard_value::ID;

object_ptr<db_lt_shard_value> db_lt_shard_value::fetch(td::TlParser &p) {
  return make_object<db_lt_shard_value>(p);
}

db_lt_shard_value::db_lt_shard_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
#undef FAIL
{}

void db_lt_shard_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
}

void db_lt_shard_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
}

void db_lt_shard_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_shard_value");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_class_end();
  }
}

db_lt_status_value::db_lt_status_value()
  : total_shards_()
{}

db_lt_status_value::db_lt_status_value(std::int32_t total_shards_)
  : total_shards_(total_shards_)
{}

const std::int32_t db_lt_status_value::ID;

object_ptr<db_lt_status_value> db_lt_status_value::fetch(td::TlParser &p) {
  return make_object<db_lt_status_value>(p);
}

db_lt_status_value::db_lt_status_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : total_shards_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_lt_status_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(total_shards_, s);
}

void db_lt_status_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(total_shards_, s);
}

void db_lt_status_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_lt_status_value");
    s.store_field("total_shards", total_shards_);
    s.store_class_end();
  }
}

db_root_config::db_root_config()
  : celldb_version_()
  , blockdb_version_()
{}

db_root_config::db_root_config(std::int32_t celldb_version_, std::int32_t blockdb_version_)
  : celldb_version_(celldb_version_)
  , blockdb_version_(blockdb_version_)
{}

const std::int32_t db_root_config::ID;

object_ptr<db_root_config> db_root_config::fetch(td::TlParser &p) {
  return make_object<db_root_config>(p);
}

db_root_config::db_root_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : celldb_version_(TlFetchInt::parse(p))
  , blockdb_version_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_root_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(celldb_version_, s);
  TlStoreBinary::store(blockdb_version_, s);
}

void db_root_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(celldb_version_, s);
  TlStoreBinary::store(blockdb_version_, s);
}

void db_root_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_root_config");
    s.store_field("celldb_version", celldb_version_);
    s.store_field("blockdb_version", blockdb_version_);
    s.store_class_end();
  }
}

db_root_dbDescription::db_root_dbDescription()
  : version_()
  , first_masterchain_block_id_()
  , flags_()
{}

db_root_dbDescription::db_root_dbDescription(std::int32_t version_, object_ptr<tonNode_blockIdExt> &&first_masterchain_block_id_, std::int32_t flags_)
  : version_(version_)
  , first_masterchain_block_id_(std::move(first_masterchain_block_id_))
  , flags_(flags_)
{}

const std::int32_t db_root_dbDescription::ID;

object_ptr<db_root_dbDescription> db_root_dbDescription::fetch(td::TlParser &p) {
  return make_object<db_root_dbDescription>(p);
}

db_root_dbDescription::db_root_dbDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : version_(TlFetchInt::parse(p))
  , first_masterchain_block_id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , flags_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_root_dbDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
  TlStoreObject::store(first_masterchain_block_id_, s);
  TlStoreBinary::store(flags_, s);
}

void db_root_dbDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
  TlStoreObject::store(first_masterchain_block_id_, s);
  TlStoreBinary::store(flags_, s);
}

void db_root_dbDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_root_dbDescription");
    s.store_field("version", version_);
    if (first_masterchain_block_id_ == nullptr) { s.store_field("first_masterchain_block_id", "null"); } else { first_masterchain_block_id_->store(s, "first_masterchain_block_id"); }
    s.store_field("flags", flags_);
    s.store_class_end();
  }
}

object_ptr<db_root_Key> db_root_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_root_key_cellDb::ID:
      return db_root_key_cellDb::fetch(p);
    case db_root_key_blockDb::ID:
      return db_root_key_blockDb::fetch(p);
    case db_root_key_config::ID:
      return db_root_key_config::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_root_key_cellDb::db_root_key_cellDb()
  : version_()
{}

db_root_key_cellDb::db_root_key_cellDb(std::int32_t version_)
  : version_(version_)
{}

const std::int32_t db_root_key_cellDb::ID;

object_ptr<db_root_Key> db_root_key_cellDb::fetch(td::TlParser &p) {
  return make_object<db_root_key_cellDb>(p);
}

db_root_key_cellDb::db_root_key_cellDb(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : version_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_root_key_cellDb::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_root_key_cellDb::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_root_key_cellDb::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_root_key_cellDb");
    s.store_field("version", version_);
    s.store_class_end();
  }
}

db_root_key_blockDb::db_root_key_blockDb()
  : version_()
{}

db_root_key_blockDb::db_root_key_blockDb(std::int32_t version_)
  : version_(version_)
{}

const std::int32_t db_root_key_blockDb::ID;

object_ptr<db_root_Key> db_root_key_blockDb::fetch(td::TlParser &p) {
  return make_object<db_root_key_blockDb>(p);
}

db_root_key_blockDb::db_root_key_blockDb(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : version_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_root_key_blockDb::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_root_key_blockDb::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_root_key_blockDb::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_root_key_blockDb");
    s.store_field("version", version_);
    s.store_class_end();
  }
}

db_root_key_config::db_root_key_config() {
}

const std::int32_t db_root_key_config::ID;

object_ptr<db_root_Key> db_root_key_config::fetch(td::TlParser &p) {
  return make_object<db_root_key_config>(p);
}

db_root_key_config::db_root_key_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_root_key_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_root_key_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_root_key_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_root_key_config");
    s.store_class_end();
  }
}

db_state_asyncSerializer::db_state_asyncSerializer()
  : block_()
  , last_()
  , last_ts_()
{}

db_state_asyncSerializer::db_state_asyncSerializer(object_ptr<tonNode_blockIdExt> &&block_, object_ptr<tonNode_blockIdExt> &&last_, std::int32_t last_ts_)
  : block_(std::move(block_))
  , last_(std::move(last_))
  , last_ts_(last_ts_)
{}

const std::int32_t db_state_asyncSerializer::ID;

object_ptr<db_state_asyncSerializer> db_state_asyncSerializer::fetch(td::TlParser &p) {
  return make_object<db_state_asyncSerializer>(p);
}

db_state_asyncSerializer::db_state_asyncSerializer(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , last_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , last_ts_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_state_asyncSerializer::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(last_, s);
  TlStoreBinary::store(last_ts_, s);
}

void db_state_asyncSerializer::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(last_, s);
  TlStoreBinary::store(last_ts_, s);
}

void db_state_asyncSerializer::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_asyncSerializer");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    if (last_ == nullptr) { s.store_field("last", "null"); } else { last_->store(s, "last"); }
    s.store_field("last_ts", last_ts_);
    s.store_class_end();
  }
}

db_state_dbVersion::db_state_dbVersion()
  : version_()
{}

db_state_dbVersion::db_state_dbVersion(std::int32_t version_)
  : version_(version_)
{}

const std::int32_t db_state_dbVersion::ID;

object_ptr<db_state_dbVersion> db_state_dbVersion::fetch(td::TlParser &p) {
  return make_object<db_state_dbVersion>(p);
}

db_state_dbVersion::db_state_dbVersion(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : version_(TlFetchInt::parse(p))
#undef FAIL
{}

void db_state_dbVersion::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_state_dbVersion::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
}

void db_state_dbVersion::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_dbVersion");
    s.store_field("version", version_);
    s.store_class_end();
  }
}

db_state_destroyedSessions::db_state_destroyedSessions()
  : sessions_()
{}

db_state_destroyedSessions::db_state_destroyedSessions(std::vector<td::Bits256> &&sessions_)
  : sessions_(std::move(sessions_))
{}

const std::int32_t db_state_destroyedSessions::ID;

object_ptr<db_state_destroyedSessions> db_state_destroyedSessions::fetch(td::TlParser &p) {
  return make_object<db_state_destroyedSessions>(p);
}

db_state_destroyedSessions::db_state_destroyedSessions(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : sessions_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void db_state_destroyedSessions::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(sessions_, s);
}

void db_state_destroyedSessions::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(sessions_, s);
}

void db_state_destroyedSessions::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_destroyedSessions");
    { const std::vector<td::Bits256> &v = sessions_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("sessions", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

db_state_gcBlockId::db_state_gcBlockId()
  : block_()
{}

db_state_gcBlockId::db_state_gcBlockId(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t db_state_gcBlockId::ID;

object_ptr<db_state_gcBlockId> db_state_gcBlockId::fetch(td::TlParser &p) {
  return make_object<db_state_gcBlockId>(p);
}

db_state_gcBlockId::db_state_gcBlockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_state_gcBlockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_gcBlockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_gcBlockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_gcBlockId");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

db_state_hardforks::db_state_hardforks()
  : blocks_()
{}

db_state_hardforks::db_state_hardforks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t db_state_hardforks::ID;

object_ptr<db_state_hardforks> db_state_hardforks::fetch(td::TlParser &p) {
  return make_object<db_state_hardforks>(p);
}

db_state_hardforks::db_state_hardforks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void db_state_hardforks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void db_state_hardforks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void db_state_hardforks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_hardforks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

db_state_initBlockId::db_state_initBlockId()
  : block_()
{}

db_state_initBlockId::db_state_initBlockId(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t db_state_initBlockId::ID;

object_ptr<db_state_initBlockId> db_state_initBlockId::fetch(td::TlParser &p) {
  return make_object<db_state_initBlockId>(p);
}

db_state_initBlockId::db_state_initBlockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_state_initBlockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_initBlockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_initBlockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_initBlockId");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

object_ptr<db_state_Key> db_state_Key::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case db_state_key_destroyedSessions::ID:
      return db_state_key_destroyedSessions::fetch(p);
    case db_state_key_initBlockId::ID:
      return db_state_key_initBlockId::fetch(p);
    case db_state_key_gcBlockId::ID:
      return db_state_key_gcBlockId::fetch(p);
    case db_state_key_shardClient::ID:
      return db_state_key_shardClient::fetch(p);
    case db_state_key_asyncSerializer::ID:
      return db_state_key_asyncSerializer::fetch(p);
    case db_state_key_hardforks::ID:
      return db_state_key_hardforks::fetch(p);
    case db_state_key_dbVersion::ID:
      return db_state_key_dbVersion::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

db_state_key_destroyedSessions::db_state_key_destroyedSessions() {
}

const std::int32_t db_state_key_destroyedSessions::ID;

object_ptr<db_state_Key> db_state_key_destroyedSessions::fetch(td::TlParser &p) {
  return make_object<db_state_key_destroyedSessions>(p);
}

db_state_key_destroyedSessions::db_state_key_destroyedSessions(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_destroyedSessions::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_destroyedSessions::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_destroyedSessions::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_destroyedSessions");
    s.store_class_end();
  }
}

db_state_key_initBlockId::db_state_key_initBlockId() {
}

const std::int32_t db_state_key_initBlockId::ID;

object_ptr<db_state_Key> db_state_key_initBlockId::fetch(td::TlParser &p) {
  return make_object<db_state_key_initBlockId>(p);
}

db_state_key_initBlockId::db_state_key_initBlockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_initBlockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_initBlockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_initBlockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_initBlockId");
    s.store_class_end();
  }
}

db_state_key_gcBlockId::db_state_key_gcBlockId() {
}

const std::int32_t db_state_key_gcBlockId::ID;

object_ptr<db_state_Key> db_state_key_gcBlockId::fetch(td::TlParser &p) {
  return make_object<db_state_key_gcBlockId>(p);
}

db_state_key_gcBlockId::db_state_key_gcBlockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_gcBlockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_gcBlockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_gcBlockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_gcBlockId");
    s.store_class_end();
  }
}

db_state_key_shardClient::db_state_key_shardClient() {
}

const std::int32_t db_state_key_shardClient::ID;

object_ptr<db_state_Key> db_state_key_shardClient::fetch(td::TlParser &p) {
  return make_object<db_state_key_shardClient>(p);
}

db_state_key_shardClient::db_state_key_shardClient(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_shardClient::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_shardClient::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_shardClient::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_shardClient");
    s.store_class_end();
  }
}

db_state_key_asyncSerializer::db_state_key_asyncSerializer() {
}

const std::int32_t db_state_key_asyncSerializer::ID;

object_ptr<db_state_Key> db_state_key_asyncSerializer::fetch(td::TlParser &p) {
  return make_object<db_state_key_asyncSerializer>(p);
}

db_state_key_asyncSerializer::db_state_key_asyncSerializer(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_asyncSerializer::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_asyncSerializer::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_asyncSerializer::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_asyncSerializer");
    s.store_class_end();
  }
}

db_state_key_hardforks::db_state_key_hardforks() {
}

const std::int32_t db_state_key_hardforks::ID;

object_ptr<db_state_Key> db_state_key_hardforks::fetch(td::TlParser &p) {
  return make_object<db_state_key_hardforks>(p);
}

db_state_key_hardforks::db_state_key_hardforks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_hardforks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_hardforks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_hardforks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_hardforks");
    s.store_class_end();
  }
}

db_state_key_dbVersion::db_state_key_dbVersion() {
}

const std::int32_t db_state_key_dbVersion::ID;

object_ptr<db_state_Key> db_state_key_dbVersion::fetch(td::TlParser &p) {
  return make_object<db_state_key_dbVersion>(p);
}

db_state_key_dbVersion::db_state_key_dbVersion(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void db_state_key_dbVersion::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void db_state_key_dbVersion::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void db_state_key_dbVersion::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_key_dbVersion");
    s.store_class_end();
  }
}

db_state_shardClient::db_state_shardClient()
  : block_()
{}

db_state_shardClient::db_state_shardClient(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t db_state_shardClient::ID;

object_ptr<db_state_shardClient> db_state_shardClient::fetch(td::TlParser &p) {
  return make_object<db_state_shardClient>(p);
}

db_state_shardClient::db_state_shardClient(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void db_state_shardClient::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_shardClient::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void db_state_shardClient::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "db_state_shardClient");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

dht_key::dht_key()
  : id_()
  , name_()
  , idx_()
{}

dht_key::dht_key(td::Bits256 const &id_, td::BufferSlice &&name_, std::int32_t idx_)
  : id_(id_)
  , name_(std::move(name_))
  , idx_(idx_)
{}

const std::int32_t dht_key::ID;

object_ptr<dht_key> dht_key::fetch(td::TlParser &p) {
  return make_object<dht_key>(p);
}

dht_key::dht_key(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , name_(TlFetchBytes<td::BufferSlice>::parse(p))
  , idx_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_key::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(name_, s);
  TlStoreBinary::store(idx_, s);
}

void dht_key::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(name_, s);
  TlStoreBinary::store(idx_, s);
}

void dht_key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_key");
    s.store_field("id", id_);
    s.store_bytes_field("name", name_);
    s.store_field("idx", idx_);
    s.store_class_end();
  }
}

dht_keyDescription::dht_keyDescription()
  : key_()
  , id_()
  , update_rule_()
  , signature_()
{}

dht_keyDescription::dht_keyDescription(object_ptr<dht_key> &&key_, object_ptr<PublicKey> &&id_, object_ptr<dht_UpdateRule> &&update_rule_, td::BufferSlice &&signature_)
  : key_(std::move(key_))
  , id_(std::move(id_))
  , update_rule_(std::move(update_rule_))
  , signature_(std::move(signature_))
{}

const std::int32_t dht_keyDescription::ID;

object_ptr<dht_keyDescription> dht_keyDescription::fetch(td::TlParser &p) {
  return make_object<dht_keyDescription>(p);
}

dht_keyDescription::dht_keyDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchObject<dht_key>::parse(p))
  , id_(TlFetchObject<PublicKey>::parse(p))
  , update_rule_(TlFetchObject<dht_UpdateRule>::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void dht_keyDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(key_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(update_rule_, s);
  TlStoreString::store(signature_, s);
}

void dht_keyDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(key_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(update_rule_, s);
  TlStoreString::store(signature_, s);
}

void dht_keyDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_keyDescription");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    if (update_rule_ == nullptr) { s.store_field("update_rule", "null"); } else { update_rule_->store(s, "update_rule"); }
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

dht_message::dht_message()
  : node_()
{}

dht_message::dht_message(object_ptr<dht_node> &&node_)
  : node_(std::move(node_))
{}

const std::int32_t dht_message::ID;

object_ptr<dht_message> dht_message::fetch(td::TlParser &p) {
  return make_object<dht_message>(p);
}

dht_message::dht_message(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : node_(TlFetchObject<dht_node>::parse(p))
#undef FAIL
{}

void dht_message::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(node_, s);
}

void dht_message::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(node_, s);
}

void dht_message::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_message");
    if (node_ == nullptr) { s.store_field("node", "null"); } else { node_->store(s, "node"); }
    s.store_class_end();
  }
}

dht_node::dht_node()
  : id_()
  , addr_list_()
  , version_()
  , signature_()
{}

dht_node::dht_node(object_ptr<PublicKey> &&id_, object_ptr<adnl_addressList> &&addr_list_, std::int32_t version_, td::BufferSlice &&signature_)
  : id_(std::move(id_))
  , addr_list_(std::move(addr_list_))
  , version_(version_)
  , signature_(std::move(signature_))
{}

const std::int32_t dht_node::ID;

object_ptr<dht_node> dht_node::fetch(td::TlParser &p) {
  return make_object<dht_node>(p);
}

dht_node::dht_node(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PublicKey>::parse(p))
  , addr_list_(TlFetchObject<adnl_addressList>::parse(p))
  , version_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void dht_node::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
  TlStoreBinary::store(version_, s);
  TlStoreString::store(signature_, s);
}

void dht_node::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreObject::store(addr_list_, s);
  TlStoreBinary::store(version_, s);
  TlStoreString::store(signature_, s);
}

void dht_node::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_node");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    if (addr_list_ == nullptr) { s.store_field("addr_list", "null"); } else { addr_list_->store(s, "addr_list"); }
    s.store_field("version", version_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

dht_nodes::dht_nodes()
  : nodes_()
{}

dht_nodes::dht_nodes(std::vector<object_ptr<dht_node>> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t dht_nodes::ID;

object_ptr<dht_nodes> dht_nodes::fetch(td::TlParser &p) {
  return make_object<dht_nodes>(p);
}

dht_nodes::dht_nodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchVector<TlFetchObject<dht_node>>::parse(p))
#undef FAIL
{}

void dht_nodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void dht_nodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void dht_nodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_nodes");
    { const std::vector<object_ptr<dht_node>> &v = nodes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("nodes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

dht_pong::dht_pong()
  : random_id_()
{}

dht_pong::dht_pong(std::int64_t random_id_)
  : random_id_(random_id_)
{}

const std::int32_t dht_pong::ID;

object_ptr<dht_pong> dht_pong::fetch(td::TlParser &p) {
  return make_object<dht_pong>(p);
}

dht_pong::dht_pong(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : random_id_(TlFetchLong::parse(p))
#undef FAIL
{}

void dht_pong::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(random_id_, s);
}

void dht_pong::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(random_id_, s);
}

void dht_pong::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_pong");
    s.store_field("random_id", random_id_);
    s.store_class_end();
  }
}

dht_stored::dht_stored() {
}

const std::int32_t dht_stored::ID;

object_ptr<dht_stored> dht_stored::fetch(td::TlParser &p) {
  return make_object<dht_stored>(p);
}

dht_stored::dht_stored(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void dht_stored::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void dht_stored::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void dht_stored::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_stored");
    s.store_class_end();
  }
}

object_ptr<dht_UpdateRule> dht_UpdateRule::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case dht_updateRule_signature::ID:
      return dht_updateRule_signature::fetch(p);
    case dht_updateRule_anybody::ID:
      return dht_updateRule_anybody::fetch(p);
    case dht_updateRule_overlayNodes::ID:
      return dht_updateRule_overlayNodes::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

dht_updateRule_signature::dht_updateRule_signature() {
}

const std::int32_t dht_updateRule_signature::ID;

object_ptr<dht_UpdateRule> dht_updateRule_signature::fetch(td::TlParser &p) {
  return make_object<dht_updateRule_signature>(p);
}

dht_updateRule_signature::dht_updateRule_signature(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void dht_updateRule_signature::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void dht_updateRule_signature::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void dht_updateRule_signature::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_updateRule_signature");
    s.store_class_end();
  }
}

dht_updateRule_anybody::dht_updateRule_anybody() {
}

const std::int32_t dht_updateRule_anybody::ID;

object_ptr<dht_UpdateRule> dht_updateRule_anybody::fetch(td::TlParser &p) {
  return make_object<dht_updateRule_anybody>(p);
}

dht_updateRule_anybody::dht_updateRule_anybody(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void dht_updateRule_anybody::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void dht_updateRule_anybody::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void dht_updateRule_anybody::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_updateRule_anybody");
    s.store_class_end();
  }
}

dht_updateRule_overlayNodes::dht_updateRule_overlayNodes() {
}

const std::int32_t dht_updateRule_overlayNodes::ID;

object_ptr<dht_UpdateRule> dht_updateRule_overlayNodes::fetch(td::TlParser &p) {
  return make_object<dht_updateRule_overlayNodes>(p);
}

dht_updateRule_overlayNodes::dht_updateRule_overlayNodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void dht_updateRule_overlayNodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void dht_updateRule_overlayNodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void dht_updateRule_overlayNodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_updateRule_overlayNodes");
    s.store_class_end();
  }
}

dht_value::dht_value()
  : key_()
  , value_()
  , ttl_()
  , signature_()
{}

dht_value::dht_value(object_ptr<dht_keyDescription> &&key_, td::BufferSlice &&value_, std::int32_t ttl_, td::BufferSlice &&signature_)
  : key_(std::move(key_))
  , value_(std::move(value_))
  , ttl_(ttl_)
  , signature_(std::move(signature_))
{}

const std::int32_t dht_value::ID;

object_ptr<dht_value> dht_value::fetch(td::TlParser &p) {
  return make_object<dht_value>(p);
}

dht_value::dht_value(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchObject<dht_keyDescription>::parse(p))
  , value_(TlFetchBytes<td::BufferSlice>::parse(p))
  , ttl_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void dht_value::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(key_, s);
  TlStoreString::store(value_, s);
  TlStoreBinary::store(ttl_, s);
  TlStoreString::store(signature_, s);
}

void dht_value::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(key_, s);
  TlStoreString::store(value_, s);
  TlStoreBinary::store(ttl_, s);
  TlStoreString::store(signature_, s);
}

void dht_value::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_value");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_bytes_field("value", value_);
    s.store_field("ttl", ttl_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

object_ptr<dht_ValueResult> dht_ValueResult::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case dht_valueNotFound::ID:
      return dht_valueNotFound::fetch(p);
    case dht_valueFound::ID:
      return dht_valueFound::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

dht_valueNotFound::dht_valueNotFound()
  : nodes_()
{}

dht_valueNotFound::dht_valueNotFound(object_ptr<dht_nodes> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t dht_valueNotFound::ID;

object_ptr<dht_ValueResult> dht_valueNotFound::fetch(td::TlParser &p) {
  return make_object<dht_valueNotFound>(p);
}

dht_valueNotFound::dht_valueNotFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchObject<dht_nodes>::parse(p))
#undef FAIL
{}

void dht_valueNotFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void dht_valueNotFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void dht_valueNotFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_valueNotFound");
    if (nodes_ == nullptr) { s.store_field("nodes", "null"); } else { nodes_->store(s, "nodes"); }
    s.store_class_end();
  }
}

dht_valueFound::dht_valueFound()
  : value_()
{}

dht_valueFound::dht_valueFound(object_ptr<dht_value> &&value_)
  : value_(std::move(value_))
{}

const std::int32_t dht_valueFound::ID;

object_ptr<dht_ValueResult> dht_valueFound::fetch(td::TlParser &p) {
  return make_object<dht_valueFound>(p);
}

dht_valueFound::dht_valueFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchBoxed<TlFetchObject<dht_value>, -1867700277>::parse(p))
#undef FAIL
{}

void dht_valueFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxed<TlStoreObject, -1867700277>::store(value_, s);
}

void dht_valueFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxed<TlStoreObject, -1867700277>::store(value_, s);
}

void dht_valueFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_valueFound");
    if (value_ == nullptr) { s.store_field("value", "null"); } else { value_->store(s, "value"); }
    s.store_class_end();
  }
}

dht_config_global::dht_config_global()
  : static_nodes_()
  , k_()
  , a_()
{}

dht_config_global::dht_config_global(object_ptr<dht_nodes> &&static_nodes_, std::int32_t k_, std::int32_t a_)
  : static_nodes_(std::move(static_nodes_))
  , k_(k_)
  , a_(a_)
{}

const std::int32_t dht_config_global::ID;

object_ptr<dht_config_global> dht_config_global::fetch(td::TlParser &p) {
  return make_object<dht_config_global>(p);
}

dht_config_global::dht_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : static_nodes_(TlFetchObject<dht_nodes>::parse(p))
  , k_(TlFetchInt::parse(p))
  , a_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(static_nodes_, s);
  TlStoreBinary::store(k_, s);
  TlStoreBinary::store(a_, s);
}

void dht_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(static_nodes_, s);
  TlStoreBinary::store(k_, s);
  TlStoreBinary::store(a_, s);
}

void dht_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_config_global");
    if (static_nodes_ == nullptr) { s.store_field("static_nodes", "null"); } else { static_nodes_->store(s, "static_nodes"); }
    s.store_field("k", k_);
    s.store_field("a", a_);
    s.store_class_end();
  }
}

object_ptr<dht_config_Local> dht_config_Local::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case dht_config_local::ID:
      return dht_config_local::fetch(p);
    case dht_config_random_local::ID:
      return dht_config_random_local::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

dht_config_local::dht_config_local()
  : id_()
{}

dht_config_local::dht_config_local(object_ptr<adnl_id_short> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t dht_config_local::ID;

object_ptr<dht_config_Local> dht_config_local::fetch(td::TlParser &p) {
  return make_object<dht_config_local>(p);
}

dht_config_local::dht_config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<adnl_id_short>::parse(p))
#undef FAIL
{}

void dht_config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void dht_config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void dht_config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_config_local");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

dht_config_random_local::dht_config_random_local()
  : cnt_()
{}

dht_config_random_local::dht_config_random_local(std::int32_t cnt_)
  : cnt_(cnt_)
{}

const std::int32_t dht_config_random_local::ID;

object_ptr<dht_config_Local> dht_config_random_local::fetch(td::TlParser &p) {
  return make_object<dht_config_random_local>(p);
}

dht_config_random_local::dht_config_random_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : cnt_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_config_random_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(cnt_, s);
}

void dht_config_random_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(cnt_, s);
}

void dht_config_random_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_config_random_local");
    s.store_field("cnt", cnt_);
    s.store_class_end();
  }
}

dht_db_bucket::dht_db_bucket()
  : nodes_()
{}

dht_db_bucket::dht_db_bucket(object_ptr<dht_nodes> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t dht_db_bucket::ID;

object_ptr<dht_db_bucket> dht_db_bucket::fetch(td::TlParser &p) {
  return make_object<dht_db_bucket>(p);
}

dht_db_bucket::dht_db_bucket(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchObject<dht_nodes>::parse(p))
#undef FAIL
{}

void dht_db_bucket::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void dht_db_bucket::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void dht_db_bucket::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_db_bucket");
    if (nodes_ == nullptr) { s.store_field("nodes", "null"); } else { nodes_->store(s, "nodes"); }
    s.store_class_end();
  }
}

dht_db_key_bucket::dht_db_key_bucket()
  : id_()
{}

dht_db_key_bucket::dht_db_key_bucket(std::int32_t id_)
  : id_(id_)
{}

const std::int32_t dht_db_key_bucket::ID;

object_ptr<dht_db_key_bucket> dht_db_key_bucket::fetch(td::TlParser &p) {
  return make_object<dht_db_key_bucket>(p);
}

dht_db_key_bucket::dht_db_key_bucket(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_db_key_bucket::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void dht_db_key_bucket::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void dht_db_key_bucket::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_db_key_bucket");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

dummyworkchain0_config_global::dummyworkchain0_config_global()
  : zero_state_hash_()
{}

dummyworkchain0_config_global::dummyworkchain0_config_global(td::Bits256 const &zero_state_hash_)
  : zero_state_hash_(zero_state_hash_)
{}

const std::int32_t dummyworkchain0_config_global::ID;

object_ptr<dummyworkchain0_config_global> dummyworkchain0_config_global::fetch(td::TlParser &p) {
  return make_object<dummyworkchain0_config_global>(p);
}

dummyworkchain0_config_global::dummyworkchain0_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : zero_state_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void dummyworkchain0_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(zero_state_hash_, s);
}

void dummyworkchain0_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(zero_state_hash_, s);
}

void dummyworkchain0_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dummyworkchain0_config_global");
    s.store_field("zero_state_hash", zero_state_hash_);
    s.store_class_end();
  }
}

object_ptr<engine_Addr> engine_Addr::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case engine_addr::ID:
      return engine_addr::fetch(p);
    case engine_addrProxy::ID:
      return engine_addrProxy::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

engine_addr::engine_addr()
  : ip_()
  , port_()
  , categories_()
  , priority_categories_()
{}

engine_addr::engine_addr(std::int32_t ip_, std::int32_t port_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : ip_(ip_)
  , port_(port_)
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_addr::ID;

object_ptr<engine_Addr> engine_addr::fetch(td::TlParser &p) {
  return make_object<engine_addr>(p);
}

engine_addr::engine_addr(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_addr::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_addr::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_addr::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_addr");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_addrProxy::engine_addrProxy()
  : in_ip_()
  , in_port_()
  , out_ip_()
  , out_port_()
  , proxy_type_()
  , categories_()
  , priority_categories_()
{}

engine_addrProxy::engine_addrProxy(std::int32_t in_ip_, std::int32_t in_port_, std::int32_t out_ip_, std::int32_t out_port_, object_ptr<adnl_Proxy> &&proxy_type_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : in_ip_(in_ip_)
  , in_port_(in_port_)
  , out_ip_(out_ip_)
  , out_port_(out_port_)
  , proxy_type_(std::move(proxy_type_))
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_addrProxy::ID;

object_ptr<engine_Addr> engine_addrProxy::fetch(td::TlParser &p) {
  return make_object<engine_addrProxy>(p);
}

engine_addrProxy::engine_addrProxy(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : in_ip_(TlFetchInt::parse(p))
  , in_port_(TlFetchInt::parse(p))
  , out_ip_(TlFetchInt::parse(p))
  , out_port_(TlFetchInt::parse(p))
  , proxy_type_(TlFetchObject<adnl_Proxy>::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_addrProxy::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(in_ip_, s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_type_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_addrProxy::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(in_ip_, s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_type_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_addrProxy::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_addrProxy");
    s.store_field("in_ip", in_ip_);
    s.store_field("in_port", in_port_);
    s.store_field("out_ip", out_ip_);
    s.store_field("out_port", out_port_);
    if (proxy_type_ == nullptr) { s.store_field("proxy_type", "null"); } else { proxy_type_->store(s, "proxy_type"); }
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_adnl::engine_adnl()
  : id_()
  , category_()
{}

engine_adnl::engine_adnl(td::Bits256 const &id_, std::int32_t category_)
  : id_(id_)
  , category_(category_)
{}

const std::int32_t engine_adnl::ID;

object_ptr<engine_adnl> engine_adnl::fetch(td::TlParser &p) {
  return make_object<engine_adnl>(p);
}

engine_adnl::engine_adnl(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , category_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_adnl::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(category_, s);
}

void engine_adnl::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(category_, s);
}

void engine_adnl::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_adnl");
    s.store_field("id", id_);
    s.store_field("category", category_);
    s.store_class_end();
  }
}

engine_controlInterface::engine_controlInterface()
  : id_()
  , port_()
  , allowed_()
{}

engine_controlInterface::engine_controlInterface(td::Bits256 const &id_, std::int32_t port_, std::vector<object_ptr<engine_controlProcess>> &&allowed_)
  : id_(id_)
  , port_(port_)
  , allowed_(std::move(allowed_))
{}

const std::int32_t engine_controlInterface::ID;

object_ptr<engine_controlInterface> engine_controlInterface::fetch(td::TlParser &p) {
  return make_object<engine_controlInterface>(p);
}

engine_controlInterface::engine_controlInterface(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
  , allowed_(TlFetchVector<TlFetchObject<engine_controlProcess>>::parse(p))
#undef FAIL
{}

void engine_controlInterface::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreObject>::store(allowed_, s);
}

void engine_controlInterface::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreObject>::store(allowed_, s);
}

void engine_controlInterface::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_controlInterface");
    s.store_field("id", id_);
    s.store_field("port", port_);
    { const std::vector<object_ptr<engine_controlProcess>> &v = allowed_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("allowed", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_controlProcess::engine_controlProcess()
  : id_()
  , permissions_()
{}

engine_controlProcess::engine_controlProcess(td::Bits256 const &id_, std::int32_t permissions_)
  : id_(id_)
  , permissions_(permissions_)
{}

const std::int32_t engine_controlProcess::ID;

object_ptr<engine_controlProcess> engine_controlProcess::fetch(td::TlParser &p) {
  return make_object<engine_controlProcess>(p);
}

engine_controlProcess::engine_controlProcess(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , permissions_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_controlProcess::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(permissions_, s);
}

void engine_controlProcess::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(permissions_, s);
}

void engine_controlProcess::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_controlProcess");
    s.store_field("id", id_);
    s.store_field("permissions", permissions_);
    s.store_class_end();
  }
}

engine_dht::engine_dht()
  : id_()
{}

engine_dht::engine_dht(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t engine_dht::ID;

object_ptr<engine_dht> engine_dht::fetch(td::TlParser &p) {
  return make_object<engine_dht>(p);
}

engine_dht::engine_dht(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_dht::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void engine_dht::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void engine_dht::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_dht");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

engine_gc::engine_gc()
  : ids_()
{}

engine_gc::engine_gc(std::vector<td::Bits256> &&ids_)
  : ids_(std::move(ids_))
{}

const std::int32_t engine_gc::ID;

object_ptr<engine_gc> engine_gc::fetch(td::TlParser &p) {
  return make_object<engine_gc>(p);
}

engine_gc::engine_gc(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ids_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void engine_gc::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(ids_, s);
}

void engine_gc::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(ids_, s);
}

void engine_gc::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_gc");
    { const std::vector<td::Bits256> &v = ids_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("ids", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_liteServer::engine_liteServer()
  : id_()
  , port_()
{}

engine_liteServer::engine_liteServer(td::Bits256 const &id_, std::int32_t port_)
  : id_(id_)
  , port_(port_)
{}

const std::int32_t engine_liteServer::ID;

object_ptr<engine_liteServer> engine_liteServer::fetch(td::TlParser &p) {
  return make_object<engine_liteServer>(p);
}

engine_liteServer::engine_liteServer(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_liteServer::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(port_, s);
}

void engine_liteServer::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(port_, s);
}

void engine_liteServer::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_liteServer");
    s.store_field("id", id_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

engine_validator::engine_validator()
  : id_()
  , temp_keys_()
  , adnl_addrs_()
  , election_date_()
  , expire_at_()
{}

engine_validator::engine_validator(td::Bits256 const &id_, std::vector<object_ptr<engine_validatorTempKey>> &&temp_keys_, std::vector<object_ptr<engine_validatorAdnlAddress>> &&adnl_addrs_, std::int32_t election_date_, std::int32_t expire_at_)
  : id_(id_)
  , temp_keys_(std::move(temp_keys_))
  , adnl_addrs_(std::move(adnl_addrs_))
  , election_date_(election_date_)
  , expire_at_(expire_at_)
{}

const std::int32_t engine_validator::ID;

object_ptr<engine_validator> engine_validator::fetch(td::TlParser &p) {
  return make_object<engine_validator>(p);
}

engine_validator::engine_validator(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , temp_keys_(TlFetchVector<TlFetchObject<engine_validatorTempKey>>::parse(p))
  , adnl_addrs_(TlFetchVector<TlFetchObject<engine_validatorAdnlAddress>>::parse(p))
  , election_date_(TlFetchInt::parse(p))
  , expire_at_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreVector<TlStoreObject>::store(temp_keys_, s);
  TlStoreVector<TlStoreObject>::store(adnl_addrs_, s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validator::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreVector<TlStoreObject>::store(temp_keys_, s);
  TlStoreVector<TlStoreObject>::store(adnl_addrs_, s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validator::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator");
    s.store_field("id", id_);
    { const std::vector<object_ptr<engine_validatorTempKey>> &v = temp_keys_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("temp_keys", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_validatorAdnlAddress>> &v = adnl_addrs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("adnl_addrs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("election_date", election_date_);
    s.store_field("expire_at", expire_at_);
    s.store_class_end();
  }
}

engine_validatorAdnlAddress::engine_validatorAdnlAddress()
  : id_()
  , expire_at_()
{}

engine_validatorAdnlAddress::engine_validatorAdnlAddress(td::Bits256 const &id_, std::int32_t expire_at_)
  : id_(id_)
  , expire_at_(expire_at_)
{}

const std::int32_t engine_validatorAdnlAddress::ID;

object_ptr<engine_validatorAdnlAddress> engine_validatorAdnlAddress::fetch(td::TlParser &p) {
  return make_object<engine_validatorAdnlAddress>(p);
}

engine_validatorAdnlAddress::engine_validatorAdnlAddress(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , expire_at_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validatorAdnlAddress::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validatorAdnlAddress::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validatorAdnlAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validatorAdnlAddress");
    s.store_field("id", id_);
    s.store_field("expire_at", expire_at_);
    s.store_class_end();
  }
}

engine_validatorTempKey::engine_validatorTempKey()
  : key_()
  , expire_at_()
{}

engine_validatorTempKey::engine_validatorTempKey(td::Bits256 const &key_, std::int32_t expire_at_)
  : key_(key_)
  , expire_at_(expire_at_)
{}

const std::int32_t engine_validatorTempKey::ID;

object_ptr<engine_validatorTempKey> engine_validatorTempKey::fetch(td::TlParser &p) {
  return make_object<engine_validatorTempKey>(p);
}

engine_validatorTempKey::engine_validatorTempKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
  , expire_at_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validatorTempKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validatorTempKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(expire_at_, s);
}

void engine_validatorTempKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validatorTempKey");
    s.store_field("key", key_);
    s.store_field("expire_at", expire_at_);
    s.store_class_end();
  }
}

engine_adnlProxy_config::engine_adnlProxy_config()
  : ports_()
{}

engine_adnlProxy_config::engine_adnlProxy_config(std::vector<object_ptr<engine_adnlProxy_port>> &&ports_)
  : ports_(std::move(ports_))
{}

const std::int32_t engine_adnlProxy_config::ID;

object_ptr<engine_adnlProxy_config> engine_adnlProxy_config::fetch(td::TlParser &p) {
  return make_object<engine_adnlProxy_config>(p);
}

engine_adnlProxy_config::engine_adnlProxy_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ports_(TlFetchVector<TlFetchObject<engine_adnlProxy_port>>::parse(p))
#undef FAIL
{}

void engine_adnlProxy_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(ports_, s);
}

void engine_adnlProxy_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(ports_, s);
}

void engine_adnlProxy_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_adnlProxy_config");
    { const std::vector<object_ptr<engine_adnlProxy_port>> &v = ports_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("ports", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_adnlProxy_port::engine_adnlProxy_port()
  : in_port_()
  , out_port_()
  , dst_ip_()
  , dst_port_()
  , proxy_type_()
{}

engine_adnlProxy_port::engine_adnlProxy_port(std::int32_t in_port_, std::int32_t out_port_, std::int32_t dst_ip_, std::int32_t dst_port_, object_ptr<adnl_Proxy> &&proxy_type_)
  : in_port_(in_port_)
  , out_port_(out_port_)
  , dst_ip_(dst_ip_)
  , dst_port_(dst_port_)
  , proxy_type_(std::move(proxy_type_))
{}

const std::int32_t engine_adnlProxy_port::ID;

object_ptr<engine_adnlProxy_port> engine_adnlProxy_port::fetch(td::TlParser &p) {
  return make_object<engine_adnlProxy_port>(p);
}

engine_adnlProxy_port::engine_adnlProxy_port(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : in_port_(TlFetchInt::parse(p))
  , out_port_(TlFetchInt::parse(p))
  , dst_ip_(TlFetchInt::parse(p))
  , dst_port_(TlFetchInt::parse(p))
  , proxy_type_(TlFetchObject<adnl_Proxy>::parse(p))
#undef FAIL
{}

void engine_adnlProxy_port::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBinary::store(dst_ip_, s);
  TlStoreBinary::store(dst_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_type_, s);
}

void engine_adnlProxy_port::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBinary::store(dst_ip_, s);
  TlStoreBinary::store(dst_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_type_, s);
}

void engine_adnlProxy_port::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_adnlProxy_port");
    s.store_field("in_port", in_port_);
    s.store_field("out_port", out_port_);
    s.store_field("dst_ip", dst_ip_);
    s.store_field("dst_port", dst_port_);
    if (proxy_type_ == nullptr) { s.store_field("proxy_type", "null"); } else { proxy_type_->store(s, "proxy_type"); }
    s.store_class_end();
  }
}

engine_dht_config::engine_dht_config()
  : dht_()
  , gc_()
{}

engine_dht_config::engine_dht_config(std::vector<object_ptr<engine_dht>> &&dht_, object_ptr<engine_gc> &&gc_)
  : dht_(std::move(dht_))
  , gc_(std::move(gc_))
{}

const std::int32_t engine_dht_config::ID;

object_ptr<engine_dht_config> engine_dht_config::fetch(td::TlParser &p) {
  return make_object<engine_dht_config>(p);
}

engine_dht_config::engine_dht_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : dht_(TlFetchVector<TlFetchObject<engine_dht>>::parse(p))
  , gc_(TlFetchObject<engine_gc>::parse(p))
#undef FAIL
{}

void engine_dht_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(dht_, s);
  TlStoreObject::store(gc_, s);
}

void engine_dht_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(dht_, s);
  TlStoreObject::store(gc_, s);
}

void engine_dht_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_dht_config");
    { const std::vector<object_ptr<engine_dht>> &v = dht_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("dht", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    if (gc_ == nullptr) { s.store_field("gc", "null"); } else { gc_->store(s, "gc"); }
    s.store_class_end();
  }
}

engine_validator_config::engine_validator_config()
  : out_port_()
  , addrs_()
  , adnl_()
  , dht_()
  , validators_()
  , fullnode_()
  , fullnodeslaves_()
  , fullnodemasters_()
  , liteservers_()
  , control_()
  , gc_()
{}

engine_validator_config::engine_validator_config(std::int32_t out_port_, std::vector<object_ptr<engine_Addr>> &&addrs_, std::vector<object_ptr<engine_adnl>> &&adnl_, std::vector<object_ptr<engine_dht>> &&dht_, std::vector<object_ptr<engine_validator>> &&validators_, td::Bits256 const &fullnode_, std::vector<object_ptr<engine_validator_fullNodeSlave>> &&fullnodeslaves_, std::vector<object_ptr<engine_validator_fullNodeMaster>> &&fullnodemasters_, std::vector<object_ptr<engine_liteServer>> &&liteservers_, std::vector<object_ptr<engine_controlInterface>> &&control_, object_ptr<engine_gc> &&gc_)
  : out_port_(out_port_)
  , addrs_(std::move(addrs_))
  , adnl_(std::move(adnl_))
  , dht_(std::move(dht_))
  , validators_(std::move(validators_))
  , fullnode_(fullnode_)
  , fullnodeslaves_(std::move(fullnodeslaves_))
  , fullnodemasters_(std::move(fullnodemasters_))
  , liteservers_(std::move(liteservers_))
  , control_(std::move(control_))
  , gc_(std::move(gc_))
{}

const std::int32_t engine_validator_config::ID;

object_ptr<engine_validator_config> engine_validator_config::fetch(td::TlParser &p) {
  return make_object<engine_validator_config>(p);
}

engine_validator_config::engine_validator_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : out_port_(TlFetchInt::parse(p))
  , addrs_(TlFetchVector<TlFetchObject<engine_Addr>>::parse(p))
  , adnl_(TlFetchVector<TlFetchObject<engine_adnl>>::parse(p))
  , dht_(TlFetchVector<TlFetchObject<engine_dht>>::parse(p))
  , validators_(TlFetchVector<TlFetchObject<engine_validator>>::parse(p))
  , fullnode_(TlFetchInt256::parse(p))
  , fullnodeslaves_(TlFetchVector<TlFetchObject<engine_validator_fullNodeSlave>>::parse(p))
  , fullnodemasters_(TlFetchVector<TlFetchObject<engine_validator_fullNodeMaster>>::parse(p))
  , liteservers_(TlFetchVector<TlFetchObject<engine_liteServer>>::parse(p))
  , control_(TlFetchVector<TlFetchObject<engine_controlInterface>>::parse(p))
  , gc_(TlFetchObject<engine_gc>::parse(p))
#undef FAIL
{}

void engine_validator_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(out_port_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(addrs_, s);
  TlStoreVector<TlStoreObject>::store(adnl_, s);
  TlStoreVector<TlStoreObject>::store(dht_, s);
  TlStoreVector<TlStoreObject>::store(validators_, s);
  TlStoreBinary::store(fullnode_, s);
  TlStoreVector<TlStoreObject>::store(fullnodeslaves_, s);
  TlStoreVector<TlStoreObject>::store(fullnodemasters_, s);
  TlStoreVector<TlStoreObject>::store(liteservers_, s);
  TlStoreVector<TlStoreObject>::store(control_, s);
  TlStoreObject::store(gc_, s);
}

void engine_validator_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(out_port_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(addrs_, s);
  TlStoreVector<TlStoreObject>::store(adnl_, s);
  TlStoreVector<TlStoreObject>::store(dht_, s);
  TlStoreVector<TlStoreObject>::store(validators_, s);
  TlStoreBinary::store(fullnode_, s);
  TlStoreVector<TlStoreObject>::store(fullnodeslaves_, s);
  TlStoreVector<TlStoreObject>::store(fullnodemasters_, s);
  TlStoreVector<TlStoreObject>::store(liteservers_, s);
  TlStoreVector<TlStoreObject>::store(control_, s);
  TlStoreObject::store(gc_, s);
}

void engine_validator_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_config");
    s.store_field("out_port", out_port_);
    { const std::vector<object_ptr<engine_Addr>> &v = addrs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("addrs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_adnl>> &v = adnl_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("adnl", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_dht>> &v = dht_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("dht", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_validator>> &v = validators_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("validators", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("fullnode", fullnode_);
    { const std::vector<object_ptr<engine_validator_fullNodeSlave>> &v = fullnodeslaves_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("fullnodeslaves", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_validator_fullNodeMaster>> &v = fullnodemasters_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("fullnodemasters", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_liteServer>> &v = liteservers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("liteservers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<engine_controlInterface>> &v = control_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("control", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    if (gc_ == nullptr) { s.store_field("gc", "null"); } else { gc_->store(s, "gc"); }
    s.store_class_end();
  }
}

engine_validator_controlQueryError::engine_validator_controlQueryError()
  : code_()
  , message_()
{}

engine_validator_controlQueryError::engine_validator_controlQueryError(std::int32_t code_, std::string const &message_)
  : code_(code_)
  , message_(std::move(message_))
{}

const std::int32_t engine_validator_controlQueryError::ID;

object_ptr<engine_validator_controlQueryError> engine_validator_controlQueryError::fetch(td::TlParser &p) {
  return make_object<engine_validator_controlQueryError>(p);
}

engine_validator_controlQueryError::engine_validator_controlQueryError(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : code_(TlFetchInt::parse(p))
  , message_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void engine_validator_controlQueryError::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(code_, s);
  TlStoreString::store(message_, s);
}

void engine_validator_controlQueryError::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(code_, s);
  TlStoreString::store(message_, s);
}

void engine_validator_controlQueryError::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_controlQueryError");
    s.store_field("code", code_);
    s.store_field("message", message_);
    s.store_class_end();
  }
}

engine_validator_dhtServerStatus::engine_validator_dhtServerStatus()
  : id_()
  , status_()
{}

engine_validator_dhtServerStatus::engine_validator_dhtServerStatus(td::Bits256 const &id_, std::int32_t status_)
  : id_(id_)
  , status_(status_)
{}

const std::int32_t engine_validator_dhtServerStatus::ID;

object_ptr<engine_validator_dhtServerStatus> engine_validator_dhtServerStatus::fetch(td::TlParser &p) {
  return make_object<engine_validator_dhtServerStatus>(p);
}

engine_validator_dhtServerStatus::engine_validator_dhtServerStatus(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , status_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_dhtServerStatus::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(status_, s);
}

void engine_validator_dhtServerStatus::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(status_, s);
}

void engine_validator_dhtServerStatus::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_dhtServerStatus");
    s.store_field("id", id_);
    s.store_field("status", status_);
    s.store_class_end();
  }
}

engine_validator_dhtServersStatus::engine_validator_dhtServersStatus()
  : servers_()
{}

engine_validator_dhtServersStatus::engine_validator_dhtServersStatus(std::vector<object_ptr<engine_validator_dhtServerStatus>> &&servers_)
  : servers_(std::move(servers_))
{}

const std::int32_t engine_validator_dhtServersStatus::ID;

object_ptr<engine_validator_dhtServersStatus> engine_validator_dhtServersStatus::fetch(td::TlParser &p) {
  return make_object<engine_validator_dhtServersStatus>(p);
}

engine_validator_dhtServersStatus::engine_validator_dhtServersStatus(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : servers_(TlFetchVector<TlFetchObject<engine_validator_dhtServerStatus>>::parse(p))
#undef FAIL
{}

void engine_validator_dhtServersStatus::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(servers_, s);
}

void engine_validator_dhtServersStatus::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(servers_, s);
}

void engine_validator_dhtServersStatus::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_dhtServersStatus");
    { const std::vector<object_ptr<engine_validator_dhtServerStatus>> &v = servers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("servers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_electionBid::engine_validator_electionBid()
  : election_date_()
  , perm_key_()
  , adnl_addr_()
  , to_send_payload_()
{}

engine_validator_electionBid::engine_validator_electionBid(std::int32_t election_date_, td::Bits256 const &perm_key_, td::Bits256 const &adnl_addr_, td::BufferSlice &&to_send_payload_)
  : election_date_(election_date_)
  , perm_key_(perm_key_)
  , adnl_addr_(adnl_addr_)
  , to_send_payload_(std::move(to_send_payload_))
{}

const std::int32_t engine_validator_electionBid::ID;

object_ptr<engine_validator_electionBid> engine_validator_electionBid::fetch(td::TlParser &p) {
  return make_object<engine_validator_electionBid>(p);
}

engine_validator_electionBid::engine_validator_electionBid(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : election_date_(TlFetchInt::parse(p))
  , perm_key_(TlFetchInt256::parse(p))
  , adnl_addr_(TlFetchInt256::parse(p))
  , to_send_payload_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_electionBid::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(perm_key_, s);
  TlStoreBinary::store(adnl_addr_, s);
  TlStoreString::store(to_send_payload_, s);
}

void engine_validator_electionBid::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(perm_key_, s);
  TlStoreBinary::store(adnl_addr_, s);
  TlStoreString::store(to_send_payload_, s);
}

void engine_validator_electionBid::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_electionBid");
    s.store_field("election_date", election_date_);
    s.store_field("perm_key", perm_key_);
    s.store_field("adnl_addr", adnl_addr_);
    s.store_bytes_field("to_send_payload", to_send_payload_);
    s.store_class_end();
  }
}

engine_validator_fullNodeMaster::engine_validator_fullNodeMaster()
  : port_()
  , adnl_()
{}

engine_validator_fullNodeMaster::engine_validator_fullNodeMaster(std::int32_t port_, td::Bits256 const &adnl_)
  : port_(port_)
  , adnl_(adnl_)
{}

const std::int32_t engine_validator_fullNodeMaster::ID;

object_ptr<engine_validator_fullNodeMaster> engine_validator_fullNodeMaster::fetch(td::TlParser &p) {
  return make_object<engine_validator_fullNodeMaster>(p);
}

engine_validator_fullNodeMaster::engine_validator_fullNodeMaster(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : port_(TlFetchInt::parse(p))
  , adnl_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_fullNodeMaster::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(adnl_, s);
}

void engine_validator_fullNodeMaster::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(adnl_, s);
}

void engine_validator_fullNodeMaster::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_fullNodeMaster");
    s.store_field("port", port_);
    s.store_field("adnl", adnl_);
    s.store_class_end();
  }
}

engine_validator_fullNodeSlave::engine_validator_fullNodeSlave()
  : ip_()
  , port_()
  , adnl_()
{}

engine_validator_fullNodeSlave::engine_validator_fullNodeSlave(std::int32_t ip_, std::int32_t port_, object_ptr<PublicKey> &&adnl_)
  : ip_(ip_)
  , port_(port_)
  , adnl_(std::move(adnl_))
{}

const std::int32_t engine_validator_fullNodeSlave::ID;

object_ptr<engine_validator_fullNodeSlave> engine_validator_fullNodeSlave::fetch(td::TlParser &p) {
  return make_object<engine_validator_fullNodeSlave>(p);
}

engine_validator_fullNodeSlave::engine_validator_fullNodeSlave(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , adnl_(TlFetchObject<PublicKey>::parse(p))
#undef FAIL
{}

void engine_validator_fullNodeSlave::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(adnl_, s);
}

void engine_validator_fullNodeSlave::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(adnl_, s);
}

void engine_validator_fullNodeSlave::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_fullNodeSlave");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    if (adnl_ == nullptr) { s.store_field("adnl", "null"); } else { adnl_->store(s, "adnl"); }
    s.store_class_end();
  }
}

validator_groupMember::validator_groupMember()
  : public_key_hash_()
  , adnl_()
  , weight_()
{}

validator_groupMember::validator_groupMember(td::Bits256 const &public_key_hash_, td::Bits256 const &adnl_, std::int64_t weight_)
  : public_key_hash_(public_key_hash_)
  , adnl_(adnl_)
  , weight_(weight_)
{}

const std::int32_t validator_groupMember::ID;

object_ptr<validator_groupMember> validator_groupMember::fetch(td::TlParser &p) {
  return make_object<validator_groupMember>(p);
}

validator_groupMember::validator_groupMember(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : public_key_hash_(TlFetchInt256::parse(p))
  , adnl_(TlFetchInt256::parse(p))
  , weight_(TlFetchLong::parse(p))
#undef FAIL
{}

void validator_groupMember::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(public_key_hash_, s);
  TlStoreBinary::store(adnl_, s);
  TlStoreBinary::store(weight_, s);
}

void validator_groupMember::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(public_key_hash_, s);
  TlStoreBinary::store(adnl_, s);
  TlStoreBinary::store(weight_, s);
}

void validator_groupMember::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_groupMember");
    s.store_field("public_key_hash", public_key_hash_);
    s.store_field("adnl", adnl_);
    s.store_field("weight", weight_);
    s.store_class_end();
  }
}

engine_validator_jsonConfig::engine_validator_jsonConfig()
  : data_()
{}

engine_validator_jsonConfig::engine_validator_jsonConfig(std::string const &data_)
  : data_(std::move(data_))
{}

const std::int32_t engine_validator_jsonConfig::ID;

object_ptr<engine_validator_jsonConfig> engine_validator_jsonConfig::fetch(td::TlParser &p) {
  return make_object<engine_validator_jsonConfig>(p);
}

engine_validator_jsonConfig::engine_validator_jsonConfig(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void engine_validator_jsonConfig::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void engine_validator_jsonConfig::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void engine_validator_jsonConfig::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_jsonConfig");
    s.store_field("data", data_);
    s.store_class_end();
  }
}

engine_validator_keyHash::engine_validator_keyHash()
  : key_hash_()
{}

engine_validator_keyHash::engine_validator_keyHash(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_keyHash::ID;

object_ptr<engine_validator_keyHash> engine_validator_keyHash::fetch(td::TlParser &p) {
  return make_object<engine_validator_keyHash>(p);
}

engine_validator_keyHash::engine_validator_keyHash(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_keyHash::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_keyHash::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_keyHash::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_keyHash");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_oneStat::engine_validator_oneStat()
  : key_()
  , value_()
{}

engine_validator_oneStat::engine_validator_oneStat(std::string const &key_, std::string const &value_)
  : key_(std::move(key_))
  , value_(std::move(value_))
{}

const std::int32_t engine_validator_oneStat::ID;

object_ptr<engine_validator_oneStat> engine_validator_oneStat::fetch(td::TlParser &p) {
  return make_object<engine_validator_oneStat>(p);
}

engine_validator_oneStat::engine_validator_oneStat(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchString<std::string>::parse(p))
  , value_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void engine_validator_oneStat::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(key_, s);
  TlStoreString::store(value_, s);
}

void engine_validator_oneStat::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(key_, s);
  TlStoreString::store(value_, s);
}

void engine_validator_oneStat::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_oneStat");
    s.store_field("key", key_);
    s.store_field("value", value_);
    s.store_class_end();
  }
}

engine_validator_proposalVote::engine_validator_proposalVote()
  : perm_key_()
  , to_send_()
{}

engine_validator_proposalVote::engine_validator_proposalVote(td::Bits256 const &perm_key_, td::BufferSlice &&to_send_)
  : perm_key_(perm_key_)
  , to_send_(std::move(to_send_))
{}

const std::int32_t engine_validator_proposalVote::ID;

object_ptr<engine_validator_proposalVote> engine_validator_proposalVote::fetch(td::TlParser &p) {
  return make_object<engine_validator_proposalVote>(p);
}

engine_validator_proposalVote::engine_validator_proposalVote(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : perm_key_(TlFetchInt256::parse(p))
  , to_send_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_proposalVote::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(perm_key_, s);
  TlStoreString::store(to_send_, s);
}

void engine_validator_proposalVote::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(perm_key_, s);
  TlStoreString::store(to_send_, s);
}

void engine_validator_proposalVote::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_proposalVote");
    s.store_field("perm_key", perm_key_);
    s.store_bytes_field("to_send", to_send_);
    s.store_class_end();
  }
}

engine_validator_signature::engine_validator_signature()
  : signature_()
{}

engine_validator_signature::engine_validator_signature(td::BufferSlice &&signature_)
  : signature_(std::move(signature_))
{}

const std::int32_t engine_validator_signature::ID;

object_ptr<engine_validator_signature> engine_validator_signature::fetch(td::TlParser &p) {
  return make_object<engine_validator_signature>(p);
}

engine_validator_signature::engine_validator_signature(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_signature::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(signature_, s);
}

void engine_validator_signature::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(signature_, s);
}

void engine_validator_signature::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_signature");
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

engine_validator_stats::engine_validator_stats()
  : stats_()
{}

engine_validator_stats::engine_validator_stats(std::vector<object_ptr<engine_validator_oneStat>> &&stats_)
  : stats_(std::move(stats_))
{}

const std::int32_t engine_validator_stats::ID;

object_ptr<engine_validator_stats> engine_validator_stats::fetch(td::TlParser &p) {
  return make_object<engine_validator_stats>(p);
}

engine_validator_stats::engine_validator_stats(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : stats_(TlFetchVector<TlFetchObject<engine_validator_oneStat>>::parse(p))
#undef FAIL
{}

void engine_validator_stats::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(stats_, s);
}

void engine_validator_stats::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(stats_, s);
}

void engine_validator_stats::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_stats");
    { const std::vector<object_ptr<engine_validator_oneStat>> &v = stats_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("stats", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_success::engine_validator_success() {
}

const std::int32_t engine_validator_success::ID;

object_ptr<engine_validator_success> engine_validator_success::fetch(td::TlParser &p) {
  return make_object<engine_validator_success>(p);
}

engine_validator_success::engine_validator_success(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void engine_validator_success::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void engine_validator_success::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void engine_validator_success::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_success");
    s.store_class_end();
  }
}

engine_validator_time::engine_validator_time()
  : time_()
{}

engine_validator_time::engine_validator_time(std::int32_t time_)
  : time_(time_)
{}

const std::int32_t engine_validator_time::ID;

object_ptr<engine_validator_time> engine_validator_time::fetch(td::TlParser &p) {
  return make_object<engine_validator_time>(p);
}

engine_validator_time::engine_validator_time(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : time_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_time::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(time_, s);
}

void engine_validator_time::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(time_, s);
}

void engine_validator_time::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_time");
    s.store_field("time", time_);
    s.store_class_end();
  }
}

object_ptr<fec_Type> fec_Type::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case fec_raptorQ::ID:
      return fec_raptorQ::fetch(p);
    case fec_roundRobin::ID:
      return fec_roundRobin::fetch(p);
    case fec_online::ID:
      return fec_online::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

fec_raptorQ::fec_raptorQ()
  : data_size_()
  , symbol_size_()
  , symbols_count_()
{}

fec_raptorQ::fec_raptorQ(std::int32_t data_size_, std::int32_t symbol_size_, std::int32_t symbols_count_)
  : data_size_(data_size_)
  , symbol_size_(symbol_size_)
  , symbols_count_(symbols_count_)
{}

const std::int32_t fec_raptorQ::ID;

object_ptr<fec_Type> fec_raptorQ::fetch(td::TlParser &p) {
  return make_object<fec_raptorQ>(p);
}

fec_raptorQ::fec_raptorQ(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_size_(TlFetchInt::parse(p))
  , symbol_size_(TlFetchInt::parse(p))
  , symbols_count_(TlFetchInt::parse(p))
#undef FAIL
{}

void fec_raptorQ::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_raptorQ::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_raptorQ::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "fec_raptorQ");
    s.store_field("data_size", data_size_);
    s.store_field("symbol_size", symbol_size_);
    s.store_field("symbols_count", symbols_count_);
    s.store_class_end();
  }
}

fec_roundRobin::fec_roundRobin()
  : data_size_()
  , symbol_size_()
  , symbols_count_()
{}

fec_roundRobin::fec_roundRobin(std::int32_t data_size_, std::int32_t symbol_size_, std::int32_t symbols_count_)
  : data_size_(data_size_)
  , symbol_size_(symbol_size_)
  , symbols_count_(symbols_count_)
{}

const std::int32_t fec_roundRobin::ID;

object_ptr<fec_Type> fec_roundRobin::fetch(td::TlParser &p) {
  return make_object<fec_roundRobin>(p);
}

fec_roundRobin::fec_roundRobin(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_size_(TlFetchInt::parse(p))
  , symbol_size_(TlFetchInt::parse(p))
  , symbols_count_(TlFetchInt::parse(p))
#undef FAIL
{}

void fec_roundRobin::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_roundRobin::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_roundRobin::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "fec_roundRobin");
    s.store_field("data_size", data_size_);
    s.store_field("symbol_size", symbol_size_);
    s.store_field("symbols_count", symbols_count_);
    s.store_class_end();
  }
}

fec_online::fec_online()
  : data_size_()
  , symbol_size_()
  , symbols_count_()
{}

fec_online::fec_online(std::int32_t data_size_, std::int32_t symbol_size_, std::int32_t symbols_count_)
  : data_size_(data_size_)
  , symbol_size_(symbol_size_)
  , symbols_count_(symbols_count_)
{}

const std::int32_t fec_online::ID;

object_ptr<fec_Type> fec_online::fetch(td::TlParser &p) {
  return make_object<fec_online>(p);
}

fec_online::fec_online(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_size_(TlFetchInt::parse(p))
  , symbol_size_(TlFetchInt::parse(p))
  , symbols_count_(TlFetchInt::parse(p))
#undef FAIL
{}

void fec_online::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_online::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(symbol_size_, s);
  TlStoreBinary::store(symbols_count_, s);
}

void fec_online::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "fec_online");
    s.store_field("data_size", data_size_);
    s.store_field("symbol_size", symbol_size_);
    s.store_field("symbols_count", symbols_count_);
    s.store_class_end();
  }
}

http_header::http_header()
  : name_()
  , value_()
{}

http_header::http_header(std::string const &name_, std::string const &value_)
  : name_(std::move(name_))
  , value_(std::move(value_))
{}

const std::int32_t http_header::ID;

object_ptr<http_header> http_header::fetch(td::TlParser &p) {
  return make_object<http_header>(p);
}

http_header::http_header(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : name_(TlFetchString<std::string>::parse(p))
  , value_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void http_header::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
  TlStoreString::store(value_, s);
}

void http_header::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(name_, s);
  TlStoreString::store(value_, s);
}

void http_header::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_header");
    s.store_field("name", name_);
    s.store_field("value", value_);
    s.store_class_end();
  }
}

http_payloadPart::http_payloadPart()
  : data_()
  , trailer_()
  , last_()
{}

http_payloadPart::http_payloadPart(td::BufferSlice &&data_, std::vector<object_ptr<http_header>> &&trailer_, bool last_)
  : data_(std::move(data_))
  , trailer_(std::move(trailer_))
  , last_(last_)
{}

const std::int32_t http_payloadPart::ID;

object_ptr<http_payloadPart> http_payloadPart::fetch(td::TlParser &p) {
  return make_object<http_payloadPart>(p);
}

http_payloadPart::http_payloadPart(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
  , trailer_(TlFetchVector<TlFetchObject<http_header>>::parse(p))
  , last_(TlFetchBool::parse(p))
#undef FAIL
{}

void http_payloadPart::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
  TlStoreVector<TlStoreObject>::store(trailer_, s);
  TlStoreBool::store(last_, s);
}

void http_payloadPart::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
  TlStoreVector<TlStoreObject>::store(trailer_, s);
  TlStoreBool::store(last_, s);
}

void http_payloadPart::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_payloadPart");
    s.store_bytes_field("data", data_);
    { const std::vector<object_ptr<http_header>> &v = trailer_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("trailer", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("last", last_);
    s.store_class_end();
  }
}

http_response::http_response()
  : http_version_()
  , status_code_()
  , reason_()
  , headers_()
{}

http_response::http_response(std::string const &http_version_, std::int32_t status_code_, std::string const &reason_, std::vector<object_ptr<http_header>> &&headers_)
  : http_version_(std::move(http_version_))
  , status_code_(status_code_)
  , reason_(std::move(reason_))
  , headers_(std::move(headers_))
{}

const std::int32_t http_response::ID;

object_ptr<http_response> http_response::fetch(td::TlParser &p) {
  return make_object<http_response>(p);
}

http_response::http_response(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : http_version_(TlFetchString<std::string>::parse(p))
  , status_code_(TlFetchInt::parse(p))
  , reason_(TlFetchString<std::string>::parse(p))
  , headers_(TlFetchVector<TlFetchObject<http_header>>::parse(p))
#undef FAIL
{}

void http_response::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(http_version_, s);
  TlStoreBinary::store(status_code_, s);
  TlStoreString::store(reason_, s);
  TlStoreVector<TlStoreObject>::store(headers_, s);
}

void http_response::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(http_version_, s);
  TlStoreBinary::store(status_code_, s);
  TlStoreString::store(reason_, s);
  TlStoreVector<TlStoreObject>::store(headers_, s);
}

void http_response::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_response");
    s.store_field("http_version", http_version_);
    s.store_field("status_code", status_code_);
    s.store_field("reason", reason_);
    { const std::vector<object_ptr<http_header>> &v = headers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("headers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

http_server_config::http_server_config()
  : dhs_()
  , local_hosts_()
{}

http_server_config::http_server_config(std::vector<object_ptr<http_server_dnsEntry>> &&dhs_, std::vector<object_ptr<http_server_host>> &&local_hosts_)
  : dhs_(std::move(dhs_))
  , local_hosts_(std::move(local_hosts_))
{}

const std::int32_t http_server_config::ID;

object_ptr<http_server_config> http_server_config::fetch(td::TlParser &p) {
  return make_object<http_server_config>(p);
}

http_server_config::http_server_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : dhs_(TlFetchVector<TlFetchObject<http_server_dnsEntry>>::parse(p))
  , local_hosts_(TlFetchVector<TlFetchObject<http_server_host>>::parse(p))
#undef FAIL
{}

void http_server_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(dhs_, s);
  TlStoreVector<TlStoreObject>::store(local_hosts_, s);
}

void http_server_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(dhs_, s);
  TlStoreVector<TlStoreObject>::store(local_hosts_, s);
}

void http_server_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_server_config");
    { const std::vector<object_ptr<http_server_dnsEntry>> &v = dhs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("dhs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    { const std::vector<object_ptr<http_server_host>> &v = local_hosts_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("local_hosts", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

http_server_dnsEntry::http_server_dnsEntry()
  : domain_()
  , addr_()
{}

http_server_dnsEntry::http_server_dnsEntry(std::string const &domain_, object_ptr<adnl_id_short> &&addr_)
  : domain_(std::move(domain_))
  , addr_(std::move(addr_))
{}

const std::int32_t http_server_dnsEntry::ID;

object_ptr<http_server_dnsEntry> http_server_dnsEntry::fetch(td::TlParser &p) {
  return make_object<http_server_dnsEntry>(p);
}

http_server_dnsEntry::http_server_dnsEntry(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : domain_(TlFetchString<std::string>::parse(p))
  , addr_(TlFetchObject<adnl_id_short>::parse(p))
#undef FAIL
{}

void http_server_dnsEntry::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(domain_, s);
  TlStoreObject::store(addr_, s);
}

void http_server_dnsEntry::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(domain_, s);
  TlStoreObject::store(addr_, s);
}

void http_server_dnsEntry::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_server_dnsEntry");
    s.store_field("domain", domain_);
    if (addr_ == nullptr) { s.store_field("addr", "null"); } else { addr_->store(s, "addr"); }
    s.store_class_end();
  }
}

http_server_host::http_server_host()
  : domains_()
  , ip_()
  , port_()
  , adnl_id_()
{}

http_server_host::http_server_host(std::vector<std::string> &&domains_, std::int32_t ip_, std::int32_t port_, object_ptr<adnl_id_short> &&adnl_id_)
  : domains_(std::move(domains_))
  , ip_(ip_)
  , port_(port_)
  , adnl_id_(std::move(adnl_id_))
{}

const std::int32_t http_server_host::ID;

object_ptr<http_server_host> http_server_host::fetch(td::TlParser &p) {
  return make_object<http_server_host>(p);
}

http_server_host::http_server_host(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : domains_(TlFetchVector<TlFetchString<std::string>>::parse(p))
  , ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , adnl_id_(TlFetchObject<adnl_id_short>::parse(p))
#undef FAIL
{}

void http_server_host::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(domains_, s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreObject::store(adnl_id_, s);
}

void http_server_host::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(domains_, s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreObject::store(adnl_id_, s);
}

void http_server_host::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_server_host");
    { const std::vector<std::string> &v = domains_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("domains", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    if (adnl_id_ == nullptr) { s.store_field("adnl_id", "null"); } else { adnl_id_->store(s, "adnl_id"); }
    s.store_class_end();
  }
}

id_config_local::id_config_local()
  : id_()
{}

id_config_local::id_config_local(object_ptr<PrivateKey> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t id_config_local::ID;

object_ptr<id_config_local> id_config_local::fetch(td::TlParser &p) {
  return make_object<id_config_local>(p);
}

id_config_local::id_config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PrivateKey>::parse(p))
#undef FAIL
{}

void id_config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
}

void id_config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
}

void id_config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "id_config_local");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

liteclient_config_global::liteclient_config_global()
  : liteservers_()
  , validator_()
{}

liteclient_config_global::liteclient_config_global(std::vector<object_ptr<liteserver_desc>> &&liteservers_, object_ptr<validator_config_global> &&validator_)
  : liteservers_(std::move(liteservers_))
  , validator_(std::move(validator_))
{}

const std::int32_t liteclient_config_global::ID;

object_ptr<liteclient_config_global> liteclient_config_global::fetch(td::TlParser &p) {
  return make_object<liteclient_config_global>(p);
}

liteclient_config_global::liteclient_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : liteservers_(TlFetchVector<TlFetchObject<liteserver_desc>>::parse(p))
  , validator_(TlFetchObject<validator_config_global>::parse(p))
#undef FAIL
{}

void liteclient_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(liteservers_, s);
  TlStoreObject::store(validator_, s);
}

void liteclient_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(liteservers_, s);
  TlStoreObject::store(validator_, s);
}

void liteclient_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteclient_config_global");
    { const std::vector<object_ptr<liteserver_desc>> &v = liteservers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("liteservers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    if (validator_ == nullptr) { s.store_field("validator", "null"); } else { validator_->store(s, "validator"); }
    s.store_class_end();
  }
}

liteserver_desc::liteserver_desc()
  : id_()
  , ip_()
  , port_()
{}

liteserver_desc::liteserver_desc(object_ptr<PublicKey> &&id_, std::int32_t ip_, std::int32_t port_)
  : id_(std::move(id_))
  , ip_(ip_)
  , port_(port_)
{}

const std::int32_t liteserver_desc::ID;

object_ptr<liteserver_desc> liteserver_desc::fetch(td::TlParser &p) {
  return make_object<liteserver_desc>(p);
}

liteserver_desc::liteserver_desc(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PublicKey>::parse(p))
  , ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void liteserver_desc::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void liteserver_desc::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
}

void liteserver_desc::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteserver_desc");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

object_ptr<liteserver_config_Local> liteserver_config_Local::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case liteserver_config_local::ID:
      return liteserver_config_local::fetch(p);
    case liteserver_config_random_local::ID:
      return liteserver_config_random_local::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

liteserver_config_local::liteserver_config_local()
  : id_()
  , port_()
{}

liteserver_config_local::liteserver_config_local(object_ptr<PrivateKey> &&id_, std::int32_t port_)
  : id_(std::move(id_))
  , port_(port_)
{}

const std::int32_t liteserver_config_local::ID;

object_ptr<liteserver_config_Local> liteserver_config_local::fetch(td::TlParser &p) {
  return make_object<liteserver_config_local>(p);
}

liteserver_config_local::liteserver_config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PrivateKey>::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void liteserver_config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(port_, s);
}

void liteserver_config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(port_, s);
}

void liteserver_config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteserver_config_local");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("port", port_);
    s.store_class_end();
  }
}

liteserver_config_random_local::liteserver_config_random_local()
  : port_()
{}

liteserver_config_random_local::liteserver_config_random_local(std::int32_t port_)
  : port_(port_)
{}

const std::int32_t liteserver_config_random_local::ID;

object_ptr<liteserver_config_Local> liteserver_config_random_local::fetch(td::TlParser &p) {
  return make_object<liteserver_config_random_local>(p);
}

liteserver_config_random_local::liteserver_config_random_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : port_(TlFetchInt::parse(p))
#undef FAIL
{}

void liteserver_config_random_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(port_, s);
}

void liteserver_config_random_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(port_, s);
}

void liteserver_config_random_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteserver_config_random_local");
    s.store_field("port", port_);
    s.store_class_end();
  }
}

object_ptr<overlay_Broadcast> overlay_Broadcast::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case overlay_fec_received::ID:
      return overlay_fec_received::fetch(p);
    case overlay_fec_completed::ID:
      return overlay_fec_completed::fetch(p);
    case overlay_unicast::ID:
      return overlay_unicast::fetch(p);
    case overlay_broadcast::ID:
      return overlay_broadcast::fetch(p);
    case overlay_broadcastFec::ID:
      return overlay_broadcastFec::fetch(p);
    case overlay_broadcastFecShort::ID:
      return overlay_broadcastFecShort::fetch(p);
    case overlay_broadcastNotFound::ID:
      return overlay_broadcastNotFound::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

overlay_fec_received::overlay_fec_received()
  : hash_()
{}

overlay_fec_received::overlay_fec_received(td::Bits256 const &hash_)
  : hash_(hash_)
{}

const std::int32_t overlay_fec_received::ID;

object_ptr<overlay_Broadcast> overlay_fec_received::fetch(td::TlParser &p) {
  return make_object<overlay_fec_received>(p);
}

overlay_fec_received::overlay_fec_received(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_fec_received::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void overlay_fec_received::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void overlay_fec_received::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_fec_received");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

overlay_fec_completed::overlay_fec_completed()
  : hash_()
{}

overlay_fec_completed::overlay_fec_completed(td::Bits256 const &hash_)
  : hash_(hash_)
{}

const std::int32_t overlay_fec_completed::ID;

object_ptr<overlay_Broadcast> overlay_fec_completed::fetch(td::TlParser &p) {
  return make_object<overlay_fec_completed>(p);
}

overlay_fec_completed::overlay_fec_completed(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_fec_completed::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void overlay_fec_completed::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void overlay_fec_completed::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_fec_completed");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

overlay_unicast::overlay_unicast()
  : data_()
{}

overlay_unicast::overlay_unicast(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t overlay_unicast::ID;

object_ptr<overlay_Broadcast> overlay_unicast::fetch(td::TlParser &p) {
  return make_object<overlay_unicast>(p);
}

overlay_unicast::overlay_unicast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_unicast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void overlay_unicast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void overlay_unicast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_unicast");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

overlay_broadcast::overlay_broadcast()
  : src_()
  , certificate_()
  , flags_()
  , data_()
  , date_()
  , signature_()
{}

overlay_broadcast::overlay_broadcast(object_ptr<PublicKey> &&src_, object_ptr<overlay_Certificate> &&certificate_, std::int32_t flags_, td::BufferSlice &&data_, std::int32_t date_, td::BufferSlice &&signature_)
  : src_(std::move(src_))
  , certificate_(std::move(certificate_))
  , flags_(flags_)
  , data_(std::move(data_))
  , date_(date_)
  , signature_(std::move(signature_))
{}

const std::int32_t overlay_broadcast::ID;

object_ptr<overlay_Broadcast> overlay_broadcast::fetch(td::TlParser &p) {
  return make_object<overlay_broadcast>(p);
}

overlay_broadcast::overlay_broadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchObject<PublicKey>::parse(p))
  , certificate_(TlFetchObject<overlay_Certificate>::parse(p))
  , flags_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
  , date_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_broadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(flags_, s);
  TlStoreString::store(data_, s);
  TlStoreBinary::store(date_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(flags_, s);
  TlStoreString::store(data_, s);
  TlStoreBinary::store(date_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcast");
    if (src_ == nullptr) { s.store_field("src", "null"); } else { src_->store(s, "src"); }
    if (certificate_ == nullptr) { s.store_field("certificate", "null"); } else { certificate_->store(s, "certificate"); }
    s.store_field("flags", flags_);
    s.store_bytes_field("data", data_);
    s.store_field("date", date_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

overlay_broadcastFec::overlay_broadcastFec()
  : src_()
  , certificate_()
  , data_hash_()
  , data_size_()
  , flags_()
  , data_()
  , seqno_()
  , fec_()
  , date_()
  , signature_()
{}

overlay_broadcastFec::overlay_broadcastFec(object_ptr<PublicKey> &&src_, object_ptr<overlay_Certificate> &&certificate_, td::Bits256 const &data_hash_, std::int32_t data_size_, std::int32_t flags_, td::BufferSlice &&data_, std::int32_t seqno_, object_ptr<fec_Type> &&fec_, std::int32_t date_, td::BufferSlice &&signature_)
  : src_(std::move(src_))
  , certificate_(std::move(certificate_))
  , data_hash_(data_hash_)
  , data_size_(data_size_)
  , flags_(flags_)
  , data_(std::move(data_))
  , seqno_(seqno_)
  , fec_(std::move(fec_))
  , date_(date_)
  , signature_(std::move(signature_))
{}

const std::int32_t overlay_broadcastFec::ID;

object_ptr<overlay_Broadcast> overlay_broadcastFec::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastFec>(p);
}

overlay_broadcastFec::overlay_broadcastFec(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchObject<PublicKey>::parse(p))
  , certificate_(TlFetchObject<overlay_Certificate>::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , data_size_(TlFetchInt::parse(p))
  , flags_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , fec_(TlFetchObject<fec_Type>::parse(p))
  , date_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_broadcastFec::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(flags_, s);
  TlStoreString::store(data_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(fec_, s);
  TlStoreBinary::store(date_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcastFec::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(data_size_, s);
  TlStoreBinary::store(flags_, s);
  TlStoreString::store(data_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(fec_, s);
  TlStoreBinary::store(date_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcastFec::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastFec");
    if (src_ == nullptr) { s.store_field("src", "null"); } else { src_->store(s, "src"); }
    if (certificate_ == nullptr) { s.store_field("certificate", "null"); } else { certificate_->store(s, "certificate"); }
    s.store_field("data_hash", data_hash_);
    s.store_field("data_size", data_size_);
    s.store_field("flags", flags_);
    s.store_bytes_field("data", data_);
    s.store_field("seqno", seqno_);
    if (fec_ == nullptr) { s.store_field("fec", "null"); } else { fec_->store(s, "fec"); }
    s.store_field("date", date_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

overlay_broadcastFecShort::overlay_broadcastFecShort()
  : src_()
  , certificate_()
  , broadcast_hash_()
  , part_data_hash_()
  , seqno_()
  , signature_()
{}

overlay_broadcastFecShort::overlay_broadcastFecShort(object_ptr<PublicKey> &&src_, object_ptr<overlay_Certificate> &&certificate_, td::Bits256 const &broadcast_hash_, td::Bits256 const &part_data_hash_, std::int32_t seqno_, td::BufferSlice &&signature_)
  : src_(std::move(src_))
  , certificate_(std::move(certificate_))
  , broadcast_hash_(broadcast_hash_)
  , part_data_hash_(part_data_hash_)
  , seqno_(seqno_)
  , signature_(std::move(signature_))
{}

const std::int32_t overlay_broadcastFecShort::ID;

object_ptr<overlay_Broadcast> overlay_broadcastFecShort::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastFecShort>(p);
}

overlay_broadcastFecShort::overlay_broadcastFecShort(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchObject<PublicKey>::parse(p))
  , certificate_(TlFetchObject<overlay_Certificate>::parse(p))
  , broadcast_hash_(TlFetchInt256::parse(p))
  , part_data_hash_(TlFetchInt256::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_broadcastFecShort::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(broadcast_hash_, s);
  TlStoreBinary::store(part_data_hash_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcastFecShort::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(src_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(certificate_, s);
  TlStoreBinary::store(broadcast_hash_, s);
  TlStoreBinary::store(part_data_hash_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreString::store(signature_, s);
}

void overlay_broadcastFecShort::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastFecShort");
    if (src_ == nullptr) { s.store_field("src", "null"); } else { src_->store(s, "src"); }
    if (certificate_ == nullptr) { s.store_field("certificate", "null"); } else { certificate_->store(s, "certificate"); }
    s.store_field("broadcast_hash", broadcast_hash_);
    s.store_field("part_data_hash", part_data_hash_);
    s.store_field("seqno", seqno_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

overlay_broadcastNotFound::overlay_broadcastNotFound() {
}

const std::int32_t overlay_broadcastNotFound::ID;

object_ptr<overlay_Broadcast> overlay_broadcastNotFound::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastNotFound>(p);
}

overlay_broadcastNotFound::overlay_broadcastNotFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void overlay_broadcastNotFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void overlay_broadcastNotFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void overlay_broadcastNotFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastNotFound");
    s.store_class_end();
  }
}

overlay_broadcastList::overlay_broadcastList()
  : hashes_()
{}

overlay_broadcastList::overlay_broadcastList(std::vector<td::Bits256> &&hashes_)
  : hashes_(std::move(hashes_))
{}

const std::int32_t overlay_broadcastList::ID;

object_ptr<overlay_broadcastList> overlay_broadcastList::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastList>(p);
}

overlay_broadcastList::overlay_broadcastList(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hashes_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void overlay_broadcastList::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(hashes_, s);
}

void overlay_broadcastList::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreBinary>::store(hashes_, s);
}

void overlay_broadcastList::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastList");
    { const std::vector<td::Bits256> &v = hashes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("hashes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

object_ptr<overlay_Certificate> overlay_Certificate::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case overlay_certificate::ID:
      return overlay_certificate::fetch(p);
    case overlay_emptyCertificate::ID:
      return overlay_emptyCertificate::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

overlay_certificate::overlay_certificate()
  : issued_by_()
  , expire_at_()
  , max_size_()
  , signature_()
{}

overlay_certificate::overlay_certificate(object_ptr<PublicKey> &&issued_by_, std::int32_t expire_at_, std::int32_t max_size_, td::BufferSlice &&signature_)
  : issued_by_(std::move(issued_by_))
  , expire_at_(expire_at_)
  , max_size_(max_size_)
  , signature_(std::move(signature_))
{}

const std::int32_t overlay_certificate::ID;

object_ptr<overlay_Certificate> overlay_certificate::fetch(td::TlParser &p) {
  return make_object<overlay_certificate>(p);
}

overlay_certificate::overlay_certificate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : issued_by_(TlFetchObject<PublicKey>::parse(p))
  , expire_at_(TlFetchInt::parse(p))
  , max_size_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_certificate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(issued_by_, s);
  TlStoreBinary::store(expire_at_, s);
  TlStoreBinary::store(max_size_, s);
  TlStoreString::store(signature_, s);
}

void overlay_certificate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(issued_by_, s);
  TlStoreBinary::store(expire_at_, s);
  TlStoreBinary::store(max_size_, s);
  TlStoreString::store(signature_, s);
}

void overlay_certificate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_certificate");
    if (issued_by_ == nullptr) { s.store_field("issued_by", "null"); } else { issued_by_->store(s, "issued_by"); }
    s.store_field("expire_at", expire_at_);
    s.store_field("max_size", max_size_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

overlay_emptyCertificate::overlay_emptyCertificate() {
}

const std::int32_t overlay_emptyCertificate::ID;

object_ptr<overlay_Certificate> overlay_emptyCertificate::fetch(td::TlParser &p) {
  return make_object<overlay_emptyCertificate>(p);
}

overlay_emptyCertificate::overlay_emptyCertificate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void overlay_emptyCertificate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void overlay_emptyCertificate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void overlay_emptyCertificate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_emptyCertificate");
    s.store_class_end();
  }
}

overlay_certificateId::overlay_certificateId()
  : overlay_id_()
  , node_()
  , expire_at_()
  , max_size_()
{}

overlay_certificateId::overlay_certificateId(td::Bits256 const &overlay_id_, td::Bits256 const &node_, std::int32_t expire_at_, std::int32_t max_size_)
  : overlay_id_(overlay_id_)
  , node_(node_)
  , expire_at_(expire_at_)
  , max_size_(max_size_)
{}

const std::int32_t overlay_certificateId::ID;

object_ptr<overlay_certificateId> overlay_certificateId::fetch(td::TlParser &p) {
  return make_object<overlay_certificateId>(p);
}

overlay_certificateId::overlay_certificateId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : overlay_id_(TlFetchInt256::parse(p))
  , node_(TlFetchInt256::parse(p))
  , expire_at_(TlFetchInt::parse(p))
  , max_size_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_certificateId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(overlay_id_, s);
  TlStoreBinary::store(node_, s);
  TlStoreBinary::store(expire_at_, s);
  TlStoreBinary::store(max_size_, s);
}

void overlay_certificateId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(overlay_id_, s);
  TlStoreBinary::store(node_, s);
  TlStoreBinary::store(expire_at_, s);
  TlStoreBinary::store(max_size_, s);
}

void overlay_certificateId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_certificateId");
    s.store_field("overlay_id", overlay_id_);
    s.store_field("node", node_);
    s.store_field("expire_at", expire_at_);
    s.store_field("max_size", max_size_);
    s.store_class_end();
  }
}

overlay_message::overlay_message()
  : overlay_()
{}

overlay_message::overlay_message(td::Bits256 const &overlay_)
  : overlay_(overlay_)
{}

const std::int32_t overlay_message::ID;

object_ptr<overlay_message> overlay_message::fetch(td::TlParser &p) {
  return make_object<overlay_message>(p);
}

overlay_message::overlay_message(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : overlay_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_message::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(overlay_, s);
}

void overlay_message::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(overlay_, s);
}

void overlay_message::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_message");
    s.store_field("overlay", overlay_);
    s.store_class_end();
  }
}

overlay_node::overlay_node()
  : id_()
  , overlay_()
  , version_()
  , signature_()
{}

overlay_node::overlay_node(object_ptr<PublicKey> &&id_, td::Bits256 const &overlay_, std::int32_t version_, td::BufferSlice &&signature_)
  : id_(std::move(id_))
  , overlay_(overlay_)
  , version_(version_)
  , signature_(std::move(signature_))
{}

const std::int32_t overlay_node::ID;

object_ptr<overlay_node> overlay_node::fetch(td::TlParser &p) {
  return make_object<overlay_node>(p);
}

overlay_node::overlay_node(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<PublicKey>::parse(p))
  , overlay_(TlFetchInt256::parse(p))
  , version_(TlFetchInt::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void overlay_node::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(overlay_, s);
  TlStoreBinary::store(version_, s);
  TlStoreString::store(signature_, s);
}

void overlay_node::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(id_, s);
  TlStoreBinary::store(overlay_, s);
  TlStoreBinary::store(version_, s);
  TlStoreString::store(signature_, s);
}

void overlay_node::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_node");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("overlay", overlay_);
    s.store_field("version", version_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

overlay_nodes::overlay_nodes()
  : nodes_()
{}

overlay_nodes::overlay_nodes(std::vector<object_ptr<overlay_node>> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t overlay_nodes::ID;

object_ptr<overlay_nodes> overlay_nodes::fetch(td::TlParser &p) {
  return make_object<overlay_nodes>(p);
}

overlay_nodes::overlay_nodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchVector<TlFetchObject<overlay_node>>::parse(p))
#undef FAIL
{}

void overlay_nodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void overlay_nodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(nodes_, s);
}

void overlay_nodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_nodes");
    { const std::vector<object_ptr<overlay_node>> &v = nodes_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("nodes", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

overlay_broadcast_id::overlay_broadcast_id()
  : src_()
  , data_hash_()
  , flags_()
{}

overlay_broadcast_id::overlay_broadcast_id(td::Bits256 const &src_, td::Bits256 const &data_hash_, std::int32_t flags_)
  : src_(src_)
  , data_hash_(data_hash_)
  , flags_(flags_)
{}

const std::int32_t overlay_broadcast_id::ID;

object_ptr<overlay_broadcast_id> overlay_broadcast_id::fetch(td::TlParser &p) {
  return make_object<overlay_broadcast_id>(p);
}

overlay_broadcast_id::overlay_broadcast_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt256::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , flags_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_broadcast_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(flags_, s);
}

void overlay_broadcast_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(flags_, s);
}

void overlay_broadcast_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcast_id");
    s.store_field("src", src_);
    s.store_field("data_hash", data_hash_);
    s.store_field("flags", flags_);
    s.store_class_end();
  }
}

overlay_broadcast_toSign::overlay_broadcast_toSign()
  : hash_()
  , date_()
{}

overlay_broadcast_toSign::overlay_broadcast_toSign(td::Bits256 const &hash_, std::int32_t date_)
  : hash_(hash_)
  , date_(date_)
{}

const std::int32_t overlay_broadcast_toSign::ID;

object_ptr<overlay_broadcast_toSign> overlay_broadcast_toSign::fetch(td::TlParser &p) {
  return make_object<overlay_broadcast_toSign>(p);
}

overlay_broadcast_toSign::overlay_broadcast_toSign(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
  , date_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_broadcast_toSign::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
  TlStoreBinary::store(date_, s);
}

void overlay_broadcast_toSign::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
  TlStoreBinary::store(date_, s);
}

void overlay_broadcast_toSign::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcast_toSign");
    s.store_field("hash", hash_);
    s.store_field("date", date_);
    s.store_class_end();
  }
}

overlay_broadcastFec_id::overlay_broadcastFec_id()
  : src_()
  , type_()
  , data_hash_()
  , size_()
  , flags_()
{}

overlay_broadcastFec_id::overlay_broadcastFec_id(td::Bits256 const &src_, td::Bits256 const &type_, td::Bits256 const &data_hash_, std::int32_t size_, std::int32_t flags_)
  : src_(src_)
  , type_(type_)
  , data_hash_(data_hash_)
  , size_(size_)
  , flags_(flags_)
{}

const std::int32_t overlay_broadcastFec_id::ID;

object_ptr<overlay_broadcastFec_id> overlay_broadcastFec_id::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastFec_id>(p);
}

overlay_broadcastFec_id::overlay_broadcastFec_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt256::parse(p))
  , type_(TlFetchInt256::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , size_(TlFetchInt::parse(p))
  , flags_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_broadcastFec_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(type_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(size_, s);
  TlStoreBinary::store(flags_, s);
}

void overlay_broadcastFec_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(type_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(size_, s);
  TlStoreBinary::store(flags_, s);
}

void overlay_broadcastFec_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastFec_id");
    s.store_field("src", src_);
    s.store_field("type", type_);
    s.store_field("data_hash", data_hash_);
    s.store_field("size", size_);
    s.store_field("flags", flags_);
    s.store_class_end();
  }
}

overlay_broadcastFec_partId::overlay_broadcastFec_partId()
  : broadcast_hash_()
  , data_hash_()
  , seqno_()
{}

overlay_broadcastFec_partId::overlay_broadcastFec_partId(td::Bits256 const &broadcast_hash_, td::Bits256 const &data_hash_, std::int32_t seqno_)
  : broadcast_hash_(broadcast_hash_)
  , data_hash_(data_hash_)
  , seqno_(seqno_)
{}

const std::int32_t overlay_broadcastFec_partId::ID;

object_ptr<overlay_broadcastFec_partId> overlay_broadcastFec_partId::fetch(td::TlParser &p) {
  return make_object<overlay_broadcastFec_partId>(p);
}

overlay_broadcastFec_partId::overlay_broadcastFec_partId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : broadcast_hash_(TlFetchInt256::parse(p))
  , data_hash_(TlFetchInt256::parse(p))
  , seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_broadcastFec_partId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(broadcast_hash_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(seqno_, s);
}

void overlay_broadcastFec_partId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(broadcast_hash_, s);
  TlStoreBinary::store(data_hash_, s);
  TlStoreBinary::store(seqno_, s);
}

void overlay_broadcastFec_partId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_broadcastFec_partId");
    s.store_field("broadcast_hash", broadcast_hash_);
    s.store_field("data_hash", data_hash_);
    s.store_field("seqno", seqno_);
    s.store_class_end();
  }
}

overlay_db_key_nodes::overlay_db_key_nodes()
  : local_id_()
  , overlay_()
{}

overlay_db_key_nodes::overlay_db_key_nodes(td::Bits256 const &local_id_, td::Bits256 const &overlay_)
  : local_id_(local_id_)
  , overlay_(overlay_)
{}

const std::int32_t overlay_db_key_nodes::ID;

object_ptr<overlay_db_key_nodes> overlay_db_key_nodes::fetch(td::TlParser &p) {
  return make_object<overlay_db_key_nodes>(p);
}

overlay_db_key_nodes::overlay_db_key_nodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : local_id_(TlFetchInt256::parse(p))
  , overlay_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_db_key_nodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(local_id_, s);
  TlStoreBinary::store(overlay_, s);
}

void overlay_db_key_nodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(local_id_, s);
  TlStoreBinary::store(overlay_, s);
}

void overlay_db_key_nodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_db_key_nodes");
    s.store_field("local_id", local_id_);
    s.store_field("overlay", overlay_);
    s.store_class_end();
  }
}

overlay_db_nodes::overlay_db_nodes()
  : nodes_()
{}

overlay_db_nodes::overlay_db_nodes(object_ptr<overlay_nodes> &&nodes_)
  : nodes_(std::move(nodes_))
{}

const std::int32_t overlay_db_nodes::ID;

object_ptr<overlay_db_nodes> overlay_db_nodes::fetch(td::TlParser &p) {
  return make_object<overlay_db_nodes>(p);
}

overlay_db_nodes::overlay_db_nodes(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nodes_(TlFetchObject<overlay_nodes>::parse(p))
#undef FAIL
{}

void overlay_db_nodes::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void overlay_db_nodes::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(nodes_, s);
}

void overlay_db_nodes::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_db_nodes");
    if (nodes_ == nullptr) { s.store_field("nodes", "null"); } else { nodes_->store(s, "nodes"); }
    s.store_class_end();
  }
}

overlay_node_toSign::overlay_node_toSign()
  : id_()
  , overlay_()
  , version_()
{}

overlay_node_toSign::overlay_node_toSign(object_ptr<adnl_id_short> &&id_, td::Bits256 const &overlay_, std::int32_t version_)
  : id_(std::move(id_))
  , overlay_(overlay_)
  , version_(version_)
{}

const std::int32_t overlay_node_toSign::ID;

object_ptr<overlay_node_toSign> overlay_node_toSign::fetch(td::TlParser &p) {
  return make_object<overlay_node_toSign>(p);
}

overlay_node_toSign::overlay_node_toSign(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<adnl_id_short>::parse(p))
  , overlay_(TlFetchInt256::parse(p))
  , version_(TlFetchInt::parse(p))
#undef FAIL
{}

void overlay_node_toSign::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(overlay_, s);
  TlStoreBinary::store(version_, s);
}

void overlay_node_toSign::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(overlay_, s);
  TlStoreBinary::store(version_, s);
}

void overlay_node_toSign::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_node_toSign");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("overlay", overlay_);
    s.store_field("version", version_);
    s.store_class_end();
  }
}

object_ptr<rldp_Message> rldp_Message::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case rldp_message::ID:
      return rldp_message::fetch(p);
    case rldp_query::ID:
      return rldp_query::fetch(p);
    case rldp_answer::ID:
      return rldp_answer::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

rldp_message::rldp_message()
  : id_()
  , data_()
{}

rldp_message::rldp_message(td::Bits256 const &id_, td::BufferSlice &&data_)
  : id_(id_)
  , data_(std::move(data_))
{}

const std::int32_t rldp_message::ID;

object_ptr<rldp_Message> rldp_message::fetch(td::TlParser &p) {
  return make_object<rldp_message>(p);
}

rldp_message::rldp_message(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void rldp_message::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(data_, s);
}

void rldp_message::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(data_, s);
}

void rldp_message::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_message");
    s.store_field("id", id_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

rldp_query::rldp_query()
  : query_id_()
  , max_answer_size_()
  , timeout_()
  , data_()
{}

rldp_query::rldp_query(td::Bits256 const &query_id_, std::int64_t max_answer_size_, std::int32_t timeout_, td::BufferSlice &&data_)
  : query_id_(query_id_)
  , max_answer_size_(max_answer_size_)
  , timeout_(timeout_)
  , data_(std::move(data_))
{}

const std::int32_t rldp_query::ID;

object_ptr<rldp_Message> rldp_query::fetch(td::TlParser &p) {
  return make_object<rldp_query>(p);
}

rldp_query::rldp_query(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : query_id_(TlFetchInt256::parse(p))
  , max_answer_size_(TlFetchLong::parse(p))
  , timeout_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void rldp_query::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreBinary::store(max_answer_size_, s);
  TlStoreBinary::store(timeout_, s);
  TlStoreString::store(data_, s);
}

void rldp_query::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreBinary::store(max_answer_size_, s);
  TlStoreBinary::store(timeout_, s);
  TlStoreString::store(data_, s);
}

void rldp_query::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_query");
    s.store_field("query_id", query_id_);
    s.store_field("max_answer_size", max_answer_size_);
    s.store_field("timeout", timeout_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

rldp_answer::rldp_answer()
  : query_id_()
  , data_()
{}

rldp_answer::rldp_answer(td::Bits256 const &query_id_, td::BufferSlice &&data_)
  : query_id_(query_id_)
  , data_(std::move(data_))
{}

const std::int32_t rldp_answer::ID;

object_ptr<rldp_Message> rldp_answer::fetch(td::TlParser &p) {
  return make_object<rldp_answer>(p);
}

rldp_answer::rldp_answer(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : query_id_(TlFetchInt256::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void rldp_answer::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(data_, s);
}

void rldp_answer::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(query_id_, s);
  TlStoreString::store(data_, s);
}

void rldp_answer::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_answer");
    s.store_field("query_id", query_id_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

object_ptr<rldp_MessagePart> rldp_MessagePart::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case rldp_messagePart::ID:
      return rldp_messagePart::fetch(p);
    case rldp_confirm::ID:
      return rldp_confirm::fetch(p);
    case rldp_complete::ID:
      return rldp_complete::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

rldp_messagePart::rldp_messagePart()
  : transfer_id_()
  , fec_type_()
  , part_()
  , total_size_()
  , seqno_()
  , data_()
{}

rldp_messagePart::rldp_messagePart(td::Bits256 const &transfer_id_, object_ptr<fec_Type> &&fec_type_, std::int32_t part_, std::int64_t total_size_, std::int32_t seqno_, td::BufferSlice &&data_)
  : transfer_id_(transfer_id_)
  , fec_type_(std::move(fec_type_))
  , part_(part_)
  , total_size_(total_size_)
  , seqno_(seqno_)
  , data_(std::move(data_))
{}

const std::int32_t rldp_messagePart::ID;

object_ptr<rldp_MessagePart> rldp_messagePart::fetch(td::TlParser &p) {
  return make_object<rldp_messagePart>(p);
}

rldp_messagePart::rldp_messagePart(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : transfer_id_(TlFetchInt256::parse(p))
  , fec_type_(TlFetchObject<fec_Type>::parse(p))
  , part_(TlFetchInt::parse(p))
  , total_size_(TlFetchLong::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void rldp_messagePart::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(fec_type_, s);
  TlStoreBinary::store(part_, s);
  TlStoreBinary::store(total_size_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreString::store(data_, s);
}

void rldp_messagePart::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(fec_type_, s);
  TlStoreBinary::store(part_, s);
  TlStoreBinary::store(total_size_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreString::store(data_, s);
}

void rldp_messagePart::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_messagePart");
    s.store_field("transfer_id", transfer_id_);
    if (fec_type_ == nullptr) { s.store_field("fec_type", "null"); } else { fec_type_->store(s, "fec_type"); }
    s.store_field("part", part_);
    s.store_field("total_size", total_size_);
    s.store_field("seqno", seqno_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

rldp_confirm::rldp_confirm()
  : transfer_id_()
  , part_()
  , seqno_()
{}

rldp_confirm::rldp_confirm(td::Bits256 const &transfer_id_, std::int32_t part_, std::int32_t seqno_)
  : transfer_id_(transfer_id_)
  , part_(part_)
  , seqno_(seqno_)
{}

const std::int32_t rldp_confirm::ID;

object_ptr<rldp_MessagePart> rldp_confirm::fetch(td::TlParser &p) {
  return make_object<rldp_confirm>(p);
}

rldp_confirm::rldp_confirm(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : transfer_id_(TlFetchInt256::parse(p))
  , part_(TlFetchInt::parse(p))
  , seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void rldp_confirm::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBinary::store(part_, s);
  TlStoreBinary::store(seqno_, s);
}

void rldp_confirm::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBinary::store(part_, s);
  TlStoreBinary::store(seqno_, s);
}

void rldp_confirm::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_confirm");
    s.store_field("transfer_id", transfer_id_);
    s.store_field("part", part_);
    s.store_field("seqno", seqno_);
    s.store_class_end();
  }
}

rldp_complete::rldp_complete()
  : transfer_id_()
  , part_()
{}

rldp_complete::rldp_complete(td::Bits256 const &transfer_id_, std::int32_t part_)
  : transfer_id_(transfer_id_)
  , part_(part_)
{}

const std::int32_t rldp_complete::ID;

object_ptr<rldp_MessagePart> rldp_complete::fetch(td::TlParser &p) {
  return make_object<rldp_complete>(p);
}

rldp_complete::rldp_complete(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : transfer_id_(TlFetchInt256::parse(p))
  , part_(TlFetchInt::parse(p))
#undef FAIL
{}

void rldp_complete::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBinary::store(part_, s);
}

void rldp_complete::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(transfer_id_, s);
  TlStoreBinary::store(part_, s);
}

void rldp_complete::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "rldp_complete");
    s.store_field("transfer_id", transfer_id_);
    s.store_field("part", part_);
    s.store_class_end();
  }
}

object_ptr<tcp_Message> tcp_Message::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tcp_authentificate::ID:
      return tcp_authentificate::fetch(p);
    case tcp_authentificationNonce::ID:
      return tcp_authentificationNonce::fetch(p);
    case tcp_authentificationComplete::ID:
      return tcp_authentificationComplete::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tcp_authentificate::tcp_authentificate()
  : nonce_()
{}

tcp_authentificate::tcp_authentificate(td::BufferSlice &&nonce_)
  : nonce_(std::move(nonce_))
{}

const std::int32_t tcp_authentificate::ID;

object_ptr<tcp_Message> tcp_authentificate::fetch(td::TlParser &p) {
  return make_object<tcp_authentificate>(p);
}

tcp_authentificate::tcp_authentificate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nonce_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tcp_authentificate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(nonce_, s);
}

void tcp_authentificate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(nonce_, s);
}

void tcp_authentificate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tcp_authentificate");
    s.store_bytes_field("nonce", nonce_);
    s.store_class_end();
  }
}

tcp_authentificationNonce::tcp_authentificationNonce()
  : nonce_()
{}

tcp_authentificationNonce::tcp_authentificationNonce(td::BufferSlice &&nonce_)
  : nonce_(std::move(nonce_))
{}

const std::int32_t tcp_authentificationNonce::ID;

object_ptr<tcp_Message> tcp_authentificationNonce::fetch(td::TlParser &p) {
  return make_object<tcp_authentificationNonce>(p);
}

tcp_authentificationNonce::tcp_authentificationNonce(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : nonce_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tcp_authentificationNonce::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(nonce_, s);
}

void tcp_authentificationNonce::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(nonce_, s);
}

void tcp_authentificationNonce::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tcp_authentificationNonce");
    s.store_bytes_field("nonce", nonce_);
    s.store_class_end();
  }
}

tcp_authentificationComplete::tcp_authentificationComplete()
  : key_()
  , signature_()
{}

tcp_authentificationComplete::tcp_authentificationComplete(object_ptr<PublicKey> &&key_, td::BufferSlice &&signature_)
  : key_(std::move(key_))
  , signature_(std::move(signature_))
{}

const std::int32_t tcp_authentificationComplete::ID;

object_ptr<tcp_Message> tcp_authentificationComplete::fetch(td::TlParser &p) {
  return make_object<tcp_authentificationComplete>(p);
}

tcp_authentificationComplete::tcp_authentificationComplete(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchObject<PublicKey>::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tcp_authentificationComplete::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
  TlStoreString::store(signature_, s);
}

void tcp_authentificationComplete::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
  TlStoreString::store(signature_, s);
}

void tcp_authentificationComplete::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tcp_authentificationComplete");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

tcp_pong::tcp_pong()
  : random_id_()
{}

tcp_pong::tcp_pong(std::int64_t random_id_)
  : random_id_(random_id_)
{}

const std::int32_t tcp_pong::ID;

object_ptr<tcp_pong> tcp_pong::fetch(td::TlParser &p) {
  return make_object<tcp_pong>(p);
}

tcp_pong::tcp_pong(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : random_id_(TlFetchLong::parse(p))
#undef FAIL
{}

void tcp_pong::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(random_id_, s);
}

void tcp_pong::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(random_id_, s);
}

void tcp_pong::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tcp_pong");
    s.store_field("random_id", random_id_);
    s.store_class_end();
  }
}

object_ptr<ton_BlockId> ton_BlockId::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case ton_blockId::ID:
      return ton_blockId::fetch(p);
    case ton_blockIdApprove::ID:
      return ton_blockIdApprove::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

ton_blockId::ton_blockId()
  : root_cell_hash_()
  , file_hash_()
{}

ton_blockId::ton_blockId(td::Bits256 const &root_cell_hash_, td::Bits256 const &file_hash_)
  : root_cell_hash_(root_cell_hash_)
  , file_hash_(file_hash_)
{}

const std::int32_t ton_blockId::ID;

object_ptr<ton_BlockId> ton_blockId::fetch(td::TlParser &p) {
  return make_object<ton_blockId>(p);
}

ton_blockId::ton_blockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : root_cell_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void ton_blockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(root_cell_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void ton_blockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(root_cell_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void ton_blockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "ton_blockId");
    s.store_field("root_cell_hash", root_cell_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_class_end();
  }
}

ton_blockIdApprove::ton_blockIdApprove()
  : root_cell_hash_()
  , file_hash_()
{}

ton_blockIdApprove::ton_blockIdApprove(td::Bits256 const &root_cell_hash_, td::Bits256 const &file_hash_)
  : root_cell_hash_(root_cell_hash_)
  , file_hash_(file_hash_)
{}

const std::int32_t ton_blockIdApprove::ID;

object_ptr<ton_BlockId> ton_blockIdApprove::fetch(td::TlParser &p) {
  return make_object<ton_blockIdApprove>(p);
}

ton_blockIdApprove::ton_blockIdApprove(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : root_cell_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void ton_blockIdApprove::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(root_cell_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void ton_blockIdApprove::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(root_cell_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void ton_blockIdApprove::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "ton_blockIdApprove");
    s.store_field("root_cell_hash", root_cell_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_class_end();
  }
}

object_ptr<tonNode_ArchiveInfo> tonNode_ArchiveInfo::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_archiveNotFound::ID:
      return tonNode_archiveNotFound::fetch(p);
    case tonNode_archiveInfo::ID:
      return tonNode_archiveInfo::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_archiveNotFound::tonNode_archiveNotFound() {
}

const std::int32_t tonNode_archiveNotFound::ID;

object_ptr<tonNode_ArchiveInfo> tonNode_archiveNotFound::fetch(td::TlParser &p) {
  return make_object<tonNode_archiveNotFound>(p);
}

tonNode_archiveNotFound::tonNode_archiveNotFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_archiveNotFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_archiveNotFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_archiveNotFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_archiveNotFound");
    s.store_class_end();
  }
}

tonNode_archiveInfo::tonNode_archiveInfo()
  : id_()
{}

tonNode_archiveInfo::tonNode_archiveInfo(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t tonNode_archiveInfo::ID;

object_ptr<tonNode_ArchiveInfo> tonNode_archiveInfo::fetch(td::TlParser &p) {
  return make_object<tonNode_archiveInfo>(p);
}

tonNode_archiveInfo::tonNode_archiveInfo(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchLong::parse(p))
#undef FAIL
{}

void tonNode_archiveInfo::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void tonNode_archiveInfo::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(id_, s);
}

void tonNode_archiveInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_archiveInfo");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

object_ptr<tonNode_BlockDescription> tonNode_BlockDescription::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_blockDescriptionEmpty::ID:
      return tonNode_blockDescriptionEmpty::fetch(p);
    case tonNode_blockDescription::ID:
      return tonNode_blockDescription::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_blockDescriptionEmpty::tonNode_blockDescriptionEmpty() {
}

const std::int32_t tonNode_blockDescriptionEmpty::ID;

object_ptr<tonNode_BlockDescription> tonNode_blockDescriptionEmpty::fetch(td::TlParser &p) {
  return make_object<tonNode_blockDescriptionEmpty>(p);
}

tonNode_blockDescriptionEmpty::tonNode_blockDescriptionEmpty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_blockDescriptionEmpty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_blockDescriptionEmpty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_blockDescriptionEmpty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockDescriptionEmpty");
    s.store_class_end();
  }
}

tonNode_blockDescription::tonNode_blockDescription()
  : id_()
{}

tonNode_blockDescription::tonNode_blockDescription(object_ptr<tonNode_blockIdExt> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t tonNode_blockDescription::ID;

object_ptr<tonNode_BlockDescription> tonNode_blockDescription::fetch(td::TlParser &p) {
  return make_object<tonNode_blockDescription>(p);
}

tonNode_blockDescription::tonNode_blockDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_blockDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void tonNode_blockDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void tonNode_blockDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockDescription");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

tonNode_blockId::tonNode_blockId()
  : workchain_()
  , shard_()
  , seqno_()
{}

tonNode_blockId::tonNode_blockId(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_)
  : workchain_(workchain_)
  , shard_(shard_)
  , seqno_(seqno_)
{}

const std::int32_t tonNode_blockId::ID;

object_ptr<tonNode_blockId> tonNode_blockId::fetch(td::TlParser &p) {
  return make_object<tonNode_blockId>(p);
}

tonNode_blockId::tonNode_blockId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_blockId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
}

void tonNode_blockId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
}

void tonNode_blockId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockId");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("seqno", seqno_);
    s.store_class_end();
  }
}

tonNode_blockIdExt::tonNode_blockIdExt()
  : workchain_()
  , shard_()
  , seqno_()
  , root_hash_()
  , file_hash_()
{}

tonNode_blockIdExt::tonNode_blockIdExt(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_)
  : workchain_(workchain_)
  , shard_(shard_)
  , seqno_(seqno_)
  , root_hash_(root_hash_)
  , file_hash_(file_hash_)
{}

const std::int32_t tonNode_blockIdExt::ID;

object_ptr<tonNode_blockIdExt> tonNode_blockIdExt::fetch(td::TlParser &p) {
  return make_object<tonNode_blockIdExt>(p);
}

tonNode_blockIdExt::tonNode_blockIdExt(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void tonNode_blockIdExt::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void tonNode_blockIdExt::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void tonNode_blockIdExt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockIdExt");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("seqno", seqno_);
    s.store_field("root_hash", root_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_class_end();
  }
}

tonNode_blockSignature::tonNode_blockSignature()
  : who_()
  , signature_()
{}

tonNode_blockSignature::tonNode_blockSignature(td::Bits256 const &who_, td::BufferSlice &&signature_)
  : who_(who_)
  , signature_(std::move(signature_))
{}

const std::int32_t tonNode_blockSignature::ID;

object_ptr<tonNode_blockSignature> tonNode_blockSignature::fetch(td::TlParser &p) {
  return make_object<tonNode_blockSignature>(p);
}

tonNode_blockSignature::tonNode_blockSignature(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : who_(TlFetchInt256::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_blockSignature::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(who_, s);
  TlStoreString::store(signature_, s);
}

void tonNode_blockSignature::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(who_, s);
  TlStoreString::store(signature_, s);
}

void tonNode_blockSignature::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockSignature");
    s.store_field("who", who_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

tonNode_blocksDescription::tonNode_blocksDescription()
  : ids_()
  , incomplete_()
{}

tonNode_blocksDescription::tonNode_blocksDescription(std::vector<object_ptr<tonNode_blockIdExt>> &&ids_, bool incomplete_)
  : ids_(std::move(ids_))
  , incomplete_(incomplete_)
{}

const std::int32_t tonNode_blocksDescription::ID;

object_ptr<tonNode_blocksDescription> tonNode_blocksDescription::fetch(td::TlParser &p) {
  return make_object<tonNode_blocksDescription>(p);
}

tonNode_blocksDescription::tonNode_blocksDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ids_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
  , incomplete_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_blocksDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(ids_, s);
  TlStoreBool::store(incomplete_, s);
}

void tonNode_blocksDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(ids_, s);
  TlStoreBool::store(incomplete_, s);
}

void tonNode_blocksDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blocksDescription");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = ids_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("ids", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("incomplete", incomplete_);
    s.store_class_end();
  }
}

object_ptr<tonNode_Broadcast> tonNode_Broadcast::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_blockBroadcast::ID:
      return tonNode_blockBroadcast::fetch(p);
    case tonNode_ihrMessageBroadcast::ID:
      return tonNode_ihrMessageBroadcast::fetch(p);
    case tonNode_externalMessageBroadcast::ID:
      return tonNode_externalMessageBroadcast::fetch(p);
    case tonNode_newShardBlockBroadcast::ID:
      return tonNode_newShardBlockBroadcast::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_blockBroadcast::tonNode_blockBroadcast()
  : id_()
  , catchain_seqno_()
  , validator_set_hash_()
  , signatures_()
  , proof_()
  , data_()
{}

tonNode_blockBroadcast::tonNode_blockBroadcast(object_ptr<tonNode_blockIdExt> &&id_, std::int32_t catchain_seqno_, std::int32_t validator_set_hash_, std::vector<object_ptr<tonNode_blockSignature>> &&signatures_, td::BufferSlice &&proof_, td::BufferSlice &&data_)
  : id_(std::move(id_))
  , catchain_seqno_(catchain_seqno_)
  , validator_set_hash_(validator_set_hash_)
  , signatures_(std::move(signatures_))
  , proof_(std::move(proof_))
  , data_(std::move(data_))
{}

const std::int32_t tonNode_blockBroadcast::ID;

object_ptr<tonNode_Broadcast> tonNode_blockBroadcast::fetch(td::TlParser &p) {
  return make_object<tonNode_blockBroadcast>(p);
}

tonNode_blockBroadcast::tonNode_blockBroadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , catchain_seqno_(TlFetchInt::parse(p))
  , validator_set_hash_(TlFetchInt::parse(p))
  , signatures_(TlFetchVector<TlFetchObject<tonNode_blockSignature>>::parse(p))
  , proof_(TlFetchBytes<td::BufferSlice>::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_blockBroadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(validator_set_hash_, s);
  TlStoreVector<TlStoreObject>::store(signatures_, s);
  TlStoreString::store(proof_, s);
  TlStoreString::store(data_, s);
}

void tonNode_blockBroadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(validator_set_hash_, s);
  TlStoreVector<TlStoreObject>::store(signatures_, s);
  TlStoreString::store(proof_, s);
  TlStoreString::store(data_, s);
}

void tonNode_blockBroadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_blockBroadcast");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_field("catchain_seqno", catchain_seqno_);
    s.store_field("validator_set_hash", validator_set_hash_);
    { const std::vector<object_ptr<tonNode_blockSignature>> &v = signatures_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("signatures", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_bytes_field("proof", proof_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

tonNode_ihrMessageBroadcast::tonNode_ihrMessageBroadcast()
  : message_()
{}

tonNode_ihrMessageBroadcast::tonNode_ihrMessageBroadcast(object_ptr<tonNode_ihrMessage> &&message_)
  : message_(std::move(message_))
{}

const std::int32_t tonNode_ihrMessageBroadcast::ID;

object_ptr<tonNode_Broadcast> tonNode_ihrMessageBroadcast::fetch(td::TlParser &p) {
  return make_object<tonNode_ihrMessageBroadcast>(p);
}

tonNode_ihrMessageBroadcast::tonNode_ihrMessageBroadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : message_(TlFetchObject<tonNode_ihrMessage>::parse(p))
#undef FAIL
{}

void tonNode_ihrMessageBroadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(message_, s);
}

void tonNode_ihrMessageBroadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(message_, s);
}

void tonNode_ihrMessageBroadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_ihrMessageBroadcast");
    if (message_ == nullptr) { s.store_field("message", "null"); } else { message_->store(s, "message"); }
    s.store_class_end();
  }
}

tonNode_externalMessageBroadcast::tonNode_externalMessageBroadcast()
  : message_()
{}

tonNode_externalMessageBroadcast::tonNode_externalMessageBroadcast(object_ptr<tonNode_externalMessage> &&message_)
  : message_(std::move(message_))
{}

const std::int32_t tonNode_externalMessageBroadcast::ID;

object_ptr<tonNode_Broadcast> tonNode_externalMessageBroadcast::fetch(td::TlParser &p) {
  return make_object<tonNode_externalMessageBroadcast>(p);
}

tonNode_externalMessageBroadcast::tonNode_externalMessageBroadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : message_(TlFetchObject<tonNode_externalMessage>::parse(p))
#undef FAIL
{}

void tonNode_externalMessageBroadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(message_, s);
}

void tonNode_externalMessageBroadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(message_, s);
}

void tonNode_externalMessageBroadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_externalMessageBroadcast");
    if (message_ == nullptr) { s.store_field("message", "null"); } else { message_->store(s, "message"); }
    s.store_class_end();
  }
}

tonNode_newShardBlockBroadcast::tonNode_newShardBlockBroadcast()
  : block_()
{}

tonNode_newShardBlockBroadcast::tonNode_newShardBlockBroadcast(object_ptr<tonNode_newShardBlock> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_newShardBlockBroadcast::ID;

object_ptr<tonNode_Broadcast> tonNode_newShardBlockBroadcast::fetch(td::TlParser &p) {
  return make_object<tonNode_newShardBlockBroadcast>(p);
}

tonNode_newShardBlockBroadcast::tonNode_newShardBlockBroadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_newShardBlock>::parse(p))
#undef FAIL
{}

void tonNode_newShardBlockBroadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void tonNode_newShardBlockBroadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
}

void tonNode_newShardBlockBroadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_newShardBlockBroadcast");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_capabilities::tonNode_capabilities()
  : version_()
  , capabilities_()
{}

tonNode_capabilities::tonNode_capabilities(std::int32_t version_, std::int64_t capabilities_)
  : version_(version_)
  , capabilities_(capabilities_)
{}

const std::int32_t tonNode_capabilities::ID;

object_ptr<tonNode_capabilities> tonNode_capabilities::fetch(td::TlParser &p) {
  return make_object<tonNode_capabilities>(p);
}

tonNode_capabilities::tonNode_capabilities(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : version_(TlFetchInt::parse(p))
  , capabilities_(TlFetchLong::parse(p))
#undef FAIL
{}

void tonNode_capabilities::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
  TlStoreBinary::store(capabilities_, s);
}

void tonNode_capabilities::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(version_, s);
  TlStoreBinary::store(capabilities_, s);
}

void tonNode_capabilities::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_capabilities");
    s.store_field("version", version_);
    s.store_field("capabilities", capabilities_);
    s.store_class_end();
  }
}

tonNode_data::tonNode_data()
  : data_()
{}

tonNode_data::tonNode_data(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t tonNode_data::ID;

object_ptr<tonNode_data> tonNode_data::fetch(td::TlParser &p) {
  return make_object<tonNode_data>(p);
}

tonNode_data::tonNode_data(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_data::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_data::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_data::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_data");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

object_ptr<tonNode_DataFull> tonNode_DataFull::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_dataFull::ID:
      return tonNode_dataFull::fetch(p);
    case tonNode_dataFullEmpty::ID:
      return tonNode_dataFullEmpty::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_dataFull::tonNode_dataFull()
  : id_()
  , proof_()
  , block_()
  , is_link_()
{}

tonNode_dataFull::tonNode_dataFull(object_ptr<tonNode_blockIdExt> &&id_, td::BufferSlice &&proof_, td::BufferSlice &&block_, bool is_link_)
  : id_(std::move(id_))
  , proof_(std::move(proof_))
  , block_(std::move(block_))
  , is_link_(is_link_)
{}

const std::int32_t tonNode_dataFull::ID;

object_ptr<tonNode_DataFull> tonNode_dataFull::fetch(td::TlParser &p) {
  return make_object<tonNode_dataFull>(p);
}

tonNode_dataFull::tonNode_dataFull(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , proof_(TlFetchBytes<td::BufferSlice>::parse(p))
  , block_(TlFetchBytes<td::BufferSlice>::parse(p))
  , is_link_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_dataFull::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreString::store(proof_, s);
  TlStoreString::store(block_, s);
  TlStoreBool::store(is_link_, s);
}

void tonNode_dataFull::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
  TlStoreString::store(proof_, s);
  TlStoreString::store(block_, s);
  TlStoreBool::store(is_link_, s);
}

void tonNode_dataFull::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_dataFull");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_bytes_field("proof", proof_);
    s.store_bytes_field("block", block_);
    s.store_field("is_link", is_link_);
    s.store_class_end();
  }
}

tonNode_dataFullEmpty::tonNode_dataFullEmpty() {
}

const std::int32_t tonNode_dataFullEmpty::ID;

object_ptr<tonNode_DataFull> tonNode_dataFullEmpty::fetch(td::TlParser &p) {
  return make_object<tonNode_dataFullEmpty>(p);
}

tonNode_dataFullEmpty::tonNode_dataFullEmpty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_dataFullEmpty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_dataFullEmpty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_dataFullEmpty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_dataFullEmpty");
    s.store_class_end();
  }
}

tonNode_dataList::tonNode_dataList()
  : data_()
{}

tonNode_dataList::tonNode_dataList(std::vector<td::BufferSlice> &&data_)
  : data_(std::move(data_))
{}

const std::int32_t tonNode_dataList::ID;

object_ptr<tonNode_dataList> tonNode_dataList::fetch(td::TlParser &p) {
  return make_object<tonNode_dataList>(p);
}

tonNode_dataList::tonNode_dataList(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchVector<TlFetchBytes<td::BufferSlice>>::parse(p))
#undef FAIL
{}

void tonNode_dataList::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(data_, s);
}

void tonNode_dataList::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreString>::store(data_, s);
}

void tonNode_dataList::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_dataList");
    { const std::vector<td::BufferSlice> &v = data_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("data", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_bytes_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_externalMessage::tonNode_externalMessage()
  : data_()
{}

tonNode_externalMessage::tonNode_externalMessage(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t tonNode_externalMessage::ID;

object_ptr<tonNode_externalMessage> tonNode_externalMessage::fetch(td::TlParser &p) {
  return make_object<tonNode_externalMessage>(p);
}

tonNode_externalMessage::tonNode_externalMessage(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_externalMessage::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_externalMessage::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_externalMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_externalMessage");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

tonNode_ihrMessage::tonNode_ihrMessage()
  : data_()
{}

tonNode_ihrMessage::tonNode_ihrMessage(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t tonNode_ihrMessage::ID;

object_ptr<tonNode_ihrMessage> tonNode_ihrMessage::fetch(td::TlParser &p) {
  return make_object<tonNode_ihrMessage>(p);
}

tonNode_ihrMessage::tonNode_ihrMessage(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_ihrMessage::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_ihrMessage::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreString::store(data_, s);
}

void tonNode_ihrMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_ihrMessage");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

tonNode_keyBlocks::tonNode_keyBlocks()
  : blocks_()
  , incomplete_()
  , error_()
{}

tonNode_keyBlocks::tonNode_keyBlocks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_, bool incomplete_, bool error_)
  : blocks_(std::move(blocks_))
  , incomplete_(incomplete_)
  , error_(error_)
{}

const std::int32_t tonNode_keyBlocks::ID;

object_ptr<tonNode_keyBlocks> tonNode_keyBlocks::fetch(td::TlParser &p) {
  return make_object<tonNode_keyBlocks>(p);
}

tonNode_keyBlocks::tonNode_keyBlocks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
  , incomplete_(TlFetchBool::parse(p))
  , error_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_keyBlocks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(incomplete_, s);
  TlStoreBool::store(error_, s);
}

void tonNode_keyBlocks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(incomplete_, s);
  TlStoreBool::store(error_, s);
}

void tonNode_keyBlocks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_keyBlocks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("incomplete", incomplete_);
    s.store_field("error", error_);
    s.store_class_end();
  }
}

tonNode_newShardBlock::tonNode_newShardBlock()
  : block_()
  , cc_seqno_()
  , data_()
{}

tonNode_newShardBlock::tonNode_newShardBlock(object_ptr<tonNode_blockIdExt> &&block_, std::int32_t cc_seqno_, td::BufferSlice &&data_)
  : block_(std::move(block_))
  , cc_seqno_(cc_seqno_)
  , data_(std::move(data_))
{}

const std::int32_t tonNode_newShardBlock::ID;

object_ptr<tonNode_newShardBlock> tonNode_newShardBlock::fetch(td::TlParser &p) {
  return make_object<tonNode_newShardBlock>(p);
}

tonNode_newShardBlock::tonNode_newShardBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , cc_seqno_(TlFetchInt::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void tonNode_newShardBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
  TlStoreBinary::store(cc_seqno_, s);
  TlStoreString::store(data_, s);
}

void tonNode_newShardBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(block_, s);
  TlStoreBinary::store(cc_seqno_, s);
  TlStoreString::store(data_, s);
}

void tonNode_newShardBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_newShardBlock");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_field("cc_seqno", cc_seqno_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

object_ptr<tonNode_Prepared> tonNode_Prepared::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_prepared::ID:
      return tonNode_prepared::fetch(p);
    case tonNode_notFound::ID:
      return tonNode_notFound::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_prepared::tonNode_prepared() {
}

const std::int32_t tonNode_prepared::ID;

object_ptr<tonNode_Prepared> tonNode_prepared::fetch(td::TlParser &p) {
  return make_object<tonNode_prepared>(p);
}

tonNode_prepared::tonNode_prepared(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_prepared::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_prepared::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_prepared::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepared");
    s.store_class_end();
  }
}

tonNode_notFound::tonNode_notFound() {
}

const std::int32_t tonNode_notFound::ID;

object_ptr<tonNode_Prepared> tonNode_notFound::fetch(td::TlParser &p) {
  return make_object<tonNode_notFound>(p);
}

tonNode_notFound::tonNode_notFound(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_notFound::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_notFound::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_notFound::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_notFound");
    s.store_class_end();
  }
}

object_ptr<tonNode_PreparedProof> tonNode_PreparedProof::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_preparedProofEmpty::ID:
      return tonNode_preparedProofEmpty::fetch(p);
    case tonNode_preparedProof::ID:
      return tonNode_preparedProof::fetch(p);
    case tonNode_preparedProofLink::ID:
      return tonNode_preparedProofLink::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_preparedProofEmpty::tonNode_preparedProofEmpty() {
}

const std::int32_t tonNode_preparedProofEmpty::ID;

object_ptr<tonNode_PreparedProof> tonNode_preparedProofEmpty::fetch(td::TlParser &p) {
  return make_object<tonNode_preparedProofEmpty>(p);
}

tonNode_preparedProofEmpty::tonNode_preparedProofEmpty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_preparedProofEmpty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProofEmpty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProofEmpty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_preparedProofEmpty");
    s.store_class_end();
  }
}

tonNode_preparedProof::tonNode_preparedProof() {
}

const std::int32_t tonNode_preparedProof::ID;

object_ptr<tonNode_PreparedProof> tonNode_preparedProof::fetch(td::TlParser &p) {
  return make_object<tonNode_preparedProof>(p);
}

tonNode_preparedProof::tonNode_preparedProof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_preparedProof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_preparedProof");
    s.store_class_end();
  }
}

tonNode_preparedProofLink::tonNode_preparedProofLink() {
}

const std::int32_t tonNode_preparedProofLink::ID;

object_ptr<tonNode_PreparedProof> tonNode_preparedProofLink::fetch(td::TlParser &p) {
  return make_object<tonNode_preparedProofLink>(p);
}

tonNode_preparedProofLink::tonNode_preparedProofLink(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_preparedProofLink::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProofLink::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_preparedProofLink::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_preparedProofLink");
    s.store_class_end();
  }
}

object_ptr<tonNode_PreparedState> tonNode_PreparedState::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case tonNode_preparedState::ID:
      return tonNode_preparedState::fetch(p);
    case tonNode_notFoundState::ID:
      return tonNode_notFoundState::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

tonNode_preparedState::tonNode_preparedState() {
}

const std::int32_t tonNode_preparedState::ID;

object_ptr<tonNode_PreparedState> tonNode_preparedState::fetch(td::TlParser &p) {
  return make_object<tonNode_preparedState>(p);
}

tonNode_preparedState::tonNode_preparedState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_preparedState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_preparedState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_preparedState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_preparedState");
    s.store_class_end();
  }
}

tonNode_notFoundState::tonNode_notFoundState() {
}

const std::int32_t tonNode_notFoundState::ID;

object_ptr<tonNode_PreparedState> tonNode_notFoundState::fetch(td::TlParser &p) {
  return make_object<tonNode_notFoundState>(p);
}

tonNode_notFoundState::tonNode_notFoundState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_notFoundState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_notFoundState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_notFoundState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_notFoundState");
    s.store_class_end();
  }
}

tonNode_sessionId::tonNode_sessionId()
  : workchain_()
  , shard_()
  , cc_seqno_()
  , opts_hash_()
{}

tonNode_sessionId::tonNode_sessionId(std::int32_t workchain_, std::int64_t shard_, std::int32_t cc_seqno_, td::Bits256 const &opts_hash_)
  : workchain_(workchain_)
  , shard_(shard_)
  , cc_seqno_(cc_seqno_)
  , opts_hash_(opts_hash_)
{}

const std::int32_t tonNode_sessionId::ID;

object_ptr<tonNode_sessionId> tonNode_sessionId::fetch(td::TlParser &p) {
  return make_object<tonNode_sessionId>(p);
}

tonNode_sessionId::tonNode_sessionId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , cc_seqno_(TlFetchInt::parse(p))
  , opts_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void tonNode_sessionId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(cc_seqno_, s);
  TlStoreBinary::store(opts_hash_, s);
}

void tonNode_sessionId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(cc_seqno_, s);
  TlStoreBinary::store(opts_hash_, s);
}

void tonNode_sessionId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_sessionId");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("cc_seqno", cc_seqno_);
    s.store_field("opts_hash", opts_hash_);
    s.store_class_end();
  }
}

tonNode_shardPublicOverlayId::tonNode_shardPublicOverlayId()
  : workchain_()
  , shard_()
  , zero_state_file_hash_()
{}

tonNode_shardPublicOverlayId::tonNode_shardPublicOverlayId(std::int32_t workchain_, std::int64_t shard_, td::Bits256 const &zero_state_file_hash_)
  : workchain_(workchain_)
  , shard_(shard_)
  , zero_state_file_hash_(zero_state_file_hash_)
{}

const std::int32_t tonNode_shardPublicOverlayId::ID;

object_ptr<tonNode_shardPublicOverlayId> tonNode_shardPublicOverlayId::fetch(td::TlParser &p) {
  return make_object<tonNode_shardPublicOverlayId>(p);
}

tonNode_shardPublicOverlayId::tonNode_shardPublicOverlayId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , zero_state_file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void tonNode_shardPublicOverlayId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(zero_state_file_hash_, s);
}

void tonNode_shardPublicOverlayId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(zero_state_file_hash_, s);
}

void tonNode_shardPublicOverlayId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_shardPublicOverlayId");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("zero_state_file_hash", zero_state_file_hash_);
    s.store_class_end();
  }
}

tonNode_success::tonNode_success() {
}

const std::int32_t tonNode_success::ID;

object_ptr<tonNode_success> tonNode_success::fetch(td::TlParser &p) {
  return make_object<tonNode_success>(p);
}

tonNode_success::tonNode_success(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_success::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void tonNode_success::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void tonNode_success::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_success");
    s.store_class_end();
  }
}

tonNode_zeroStateIdExt::tonNode_zeroStateIdExt()
  : workchain_()
  , root_hash_()
  , file_hash_()
{}

tonNode_zeroStateIdExt::tonNode_zeroStateIdExt(std::int32_t workchain_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_)
  : workchain_(workchain_)
  , root_hash_(root_hash_)
  , file_hash_(file_hash_)
{}

const std::int32_t tonNode_zeroStateIdExt::ID;

object_ptr<tonNode_zeroStateIdExt> tonNode_zeroStateIdExt::fetch(td::TlParser &p) {
  return make_object<tonNode_zeroStateIdExt>(p);
}

tonNode_zeroStateIdExt::tonNode_zeroStateIdExt(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void tonNode_zeroStateIdExt::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void tonNode_zeroStateIdExt::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
}

void tonNode_zeroStateIdExt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_zeroStateIdExt");
    s.store_field("workchain", workchain_);
    s.store_field("root_hash", root_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_class_end();
  }
}

object_ptr<validator_Group> validator_Group::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case validator_group::ID:
      return validator_group::fetch(p);
    case validator_groupEx::ID:
      return validator_groupEx::fetch(p);
    case validator_groupNew::ID:
      return validator_groupNew::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

validator_group::validator_group()
  : workchain_()
  , shard_()
  , catchain_seqno_()
  , config_hash_()
  , members_()
{}

validator_group::validator_group(std::int32_t workchain_, std::int64_t shard_, std::int32_t catchain_seqno_, td::Bits256 const &config_hash_, std::vector<object_ptr<validator_groupMember>> &&members_)
  : workchain_(workchain_)
  , shard_(shard_)
  , catchain_seqno_(catchain_seqno_)
  , config_hash_(config_hash_)
  , members_(std::move(members_))
{}

const std::int32_t validator_group::ID;

object_ptr<validator_Group> validator_group::fetch(td::TlParser &p) {
  return make_object<validator_group>(p);
}

validator_group::validator_group(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , catchain_seqno_(TlFetchInt::parse(p))
  , config_hash_(TlFetchInt256::parse(p))
  , members_(TlFetchVector<TlFetchObject<validator_groupMember>>::parse(p))
#undef FAIL
{}

void validator_group::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_group::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_group::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_group");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("catchain_seqno", catchain_seqno_);
    s.store_field("config_hash", config_hash_);
    { const std::vector<object_ptr<validator_groupMember>> &v = members_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("members", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

validator_groupEx::validator_groupEx()
  : workchain_()
  , shard_()
  , vertical_seqno_()
  , catchain_seqno_()
  , config_hash_()
  , members_()
{}

validator_groupEx::validator_groupEx(std::int32_t workchain_, std::int64_t shard_, std::int32_t vertical_seqno_, std::int32_t catchain_seqno_, td::Bits256 const &config_hash_, std::vector<object_ptr<validator_groupMember>> &&members_)
  : workchain_(workchain_)
  , shard_(shard_)
  , vertical_seqno_(vertical_seqno_)
  , catchain_seqno_(catchain_seqno_)
  , config_hash_(config_hash_)
  , members_(std::move(members_))
{}

const std::int32_t validator_groupEx::ID;

object_ptr<validator_Group> validator_groupEx::fetch(td::TlParser &p) {
  return make_object<validator_groupEx>(p);
}

validator_groupEx::validator_groupEx(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , vertical_seqno_(TlFetchInt::parse(p))
  , catchain_seqno_(TlFetchInt::parse(p))
  , config_hash_(TlFetchInt256::parse(p))
  , members_(TlFetchVector<TlFetchObject<validator_groupMember>>::parse(p))
#undef FAIL
{}

void validator_groupEx::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(vertical_seqno_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_groupEx::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(vertical_seqno_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_groupEx::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_groupEx");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("vertical_seqno", vertical_seqno_);
    s.store_field("catchain_seqno", catchain_seqno_);
    s.store_field("config_hash", config_hash_);
    { const std::vector<object_ptr<validator_groupMember>> &v = members_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("members", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

validator_groupNew::validator_groupNew()
  : workchain_()
  , shard_()
  , vertical_seqno_()
  , last_key_block_seqno_()
  , catchain_seqno_()
  , config_hash_()
  , members_()
{}

validator_groupNew::validator_groupNew(std::int32_t workchain_, std::int64_t shard_, std::int32_t vertical_seqno_, std::int32_t last_key_block_seqno_, std::int32_t catchain_seqno_, td::Bits256 const &config_hash_, std::vector<object_ptr<validator_groupMember>> &&members_)
  : workchain_(workchain_)
  , shard_(shard_)
  , vertical_seqno_(vertical_seqno_)
  , last_key_block_seqno_(last_key_block_seqno_)
  , catchain_seqno_(catchain_seqno_)
  , config_hash_(config_hash_)
  , members_(std::move(members_))
{}

const std::int32_t validator_groupNew::ID;

object_ptr<validator_Group> validator_groupNew::fetch(td::TlParser &p) {
  return make_object<validator_groupNew>(p);
}

validator_groupNew::validator_groupNew(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : workchain_(TlFetchInt::parse(p))
  , shard_(TlFetchLong::parse(p))
  , vertical_seqno_(TlFetchInt::parse(p))
  , last_key_block_seqno_(TlFetchInt::parse(p))
  , catchain_seqno_(TlFetchInt::parse(p))
  , config_hash_(TlFetchInt256::parse(p))
  , members_(TlFetchVector<TlFetchObject<validator_groupMember>>::parse(p))
#undef FAIL
{}

void validator_groupNew::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(vertical_seqno_, s);
  TlStoreBinary::store(last_key_block_seqno_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_groupNew::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(workchain_, s);
  TlStoreBinary::store(shard_, s);
  TlStoreBinary::store(vertical_seqno_, s);
  TlStoreBinary::store(last_key_block_seqno_, s);
  TlStoreBinary::store(catchain_seqno_, s);
  TlStoreBinary::store(config_hash_, s);
  TlStoreVector<TlStoreObject>::store(members_, s);
}

void validator_groupNew::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_groupNew");
    s.store_field("workchain", workchain_);
    s.store_field("shard", shard_);
    s.store_field("vertical_seqno", vertical_seqno_);
    s.store_field("last_key_block_seqno", last_key_block_seqno_);
    s.store_field("catchain_seqno", catchain_seqno_);
    s.store_field("config_hash", config_hash_);
    { const std::vector<object_ptr<validator_groupMember>> &v = members_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("members", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

validator_config_global::validator_config_global()
  : zero_state_()
  , init_block_()
  , hardforks_()
{}

validator_config_global::validator_config_global(object_ptr<tonNode_blockIdExt> &&zero_state_, object_ptr<tonNode_blockIdExt> &&init_block_, std::vector<object_ptr<tonNode_blockIdExt>> &&hardforks_)
  : zero_state_(std::move(zero_state_))
  , init_block_(std::move(init_block_))
  , hardforks_(std::move(hardforks_))
{}

const std::int32_t validator_config_global::ID;

object_ptr<validator_config_global> validator_config_global::fetch(td::TlParser &p) {
  return make_object<validator_config_global>(p);
}

validator_config_global::validator_config_global(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : zero_state_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , init_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , hardforks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void validator_config_global::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(zero_state_, s);
  TlStoreObject::store(init_block_, s);
  TlStoreVector<TlStoreObject>::store(hardforks_, s);
}

void validator_config_global::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(zero_state_, s);
  TlStoreObject::store(init_block_, s);
  TlStoreVector<TlStoreObject>::store(hardforks_, s);
}

void validator_config_global::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_config_global");
    if (zero_state_ == nullptr) { s.store_field("zero_state", "null"); } else { zero_state_->store(s, "zero_state"); }
    if (init_block_ == nullptr) { s.store_field("init_block", "null"); } else { init_block_->store(s, "init_block"); }
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = hardforks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("hardforks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

object_ptr<validator_config_Local> validator_config_Local::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case validator_config_local::ID:
      return validator_config_local::fetch(p);
    case validator_config_random_local::ID:
      return validator_config_random_local::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

validator_config_local::validator_config_local()
  : id_()
{}

validator_config_local::validator_config_local(object_ptr<adnl_id_short> &&id_)
  : id_(std::move(id_))
{}

const std::int32_t validator_config_local::ID;

object_ptr<validator_config_Local> validator_config_local::fetch(td::TlParser &p) {
  return make_object<validator_config_local>(p);
}

validator_config_local::validator_config_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchObject<adnl_id_short>::parse(p))
#undef FAIL
{}

void validator_config_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void validator_config_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(id_, s);
}

void validator_config_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_config_local");
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

validator_config_random_local::validator_config_random_local()
  : addr_list_()
{}

validator_config_random_local::validator_config_random_local(object_ptr<adnl_addressList> &&addr_list_)
  : addr_list_(std::move(addr_list_))
{}

const std::int32_t validator_config_random_local::ID;

object_ptr<validator_config_Local> validator_config_random_local::fetch(td::TlParser &p) {
  return make_object<validator_config_random_local>(p);
}

validator_config_random_local::validator_config_random_local(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : addr_list_(TlFetchObject<adnl_addressList>::parse(p))
#undef FAIL
{}

void validator_config_random_local::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreObject::store(addr_list_, s);
}

void validator_config_random_local::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreObject::store(addr_list_, s);
}

void validator_config_random_local::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validator_config_random_local");
    if (addr_list_ == nullptr) { s.store_field("addr_list", "null"); } else { addr_list_->store(s, "addr_list"); }
    s.store_class_end();
  }
}

validatorSession_blockUpdate::validatorSession_blockUpdate()
  : ts_()
  , actions_()
  , state_()
{}

validatorSession_blockUpdate::validatorSession_blockUpdate(std::int64_t ts_, std::vector<object_ptr<validatorSession_round_Message>> &&actions_, std::int32_t state_)
  : ts_(ts_)
  , actions_(std::move(actions_))
  , state_(state_)
{}

const std::int32_t validatorSession_blockUpdate::ID;

object_ptr<validatorSession_blockUpdate> validatorSession_blockUpdate::fetch(td::TlParser &p) {
  return make_object<validatorSession_blockUpdate>(p);
}

validatorSession_blockUpdate::validatorSession_blockUpdate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ts_(TlFetchLong::parse(p))
  , actions_(TlFetchVector<TlFetchObject<validatorSession_round_Message>>::parse(p))
  , state_(TlFetchInt::parse(p))
#undef FAIL
{}

void validatorSession_blockUpdate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ts_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(actions_, s);
  TlStoreBinary::store(state_, s);
}

void validatorSession_blockUpdate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(ts_, s);
  TlStoreVector<TlStoreBoxedUnknown<TlStoreObject>>::store(actions_, s);
  TlStoreBinary::store(state_, s);
}

void validatorSession_blockUpdate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_blockUpdate");
    s.store_field("ts", ts_);
    { const std::vector<object_ptr<validatorSession_round_Message>> &v = actions_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("actions", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("state", state_);
    s.store_class_end();
  }
}

validatorSession_candidate::validatorSession_candidate()
  : src_()
  , round_()
  , root_hash_()
  , data_()
  , collated_data_()
{}

validatorSession_candidate::validatorSession_candidate(td::Bits256 const &src_, std::int32_t round_, td::Bits256 const &root_hash_, td::BufferSlice &&data_, td::BufferSlice &&collated_data_)
  : src_(src_)
  , round_(round_)
  , root_hash_(root_hash_)
  , data_(std::move(data_))
  , collated_data_(std::move(collated_data_))
{}

const std::int32_t validatorSession_candidate::ID;

object_ptr<validatorSession_candidate> validatorSession_candidate::fetch(td::TlParser &p) {
  return make_object<validatorSession_candidate>(p);
}

validatorSession_candidate::validatorSession_candidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt256::parse(p))
  , round_(TlFetchInt::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
  , collated_data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void validatorSession_candidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreString::store(data_, s);
  TlStoreString::store(collated_data_, s);
}

void validatorSession_candidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreString::store(data_, s);
  TlStoreString::store(collated_data_, s);
}

void validatorSession_candidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_candidate");
    s.store_field("src", src_);
    s.store_field("round", round_);
    s.store_field("root_hash", root_hash_);
    s.store_bytes_field("data", data_);
    s.store_bytes_field("collated_data", collated_data_);
    s.store_class_end();
  }
}

validatorSession_candidateId::validatorSession_candidateId()
  : src_()
  , root_hash_()
  , file_hash_()
  , collated_data_file_hash_()
{}

validatorSession_candidateId::validatorSession_candidateId(td::Bits256 const &src_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_, td::Bits256 const &collated_data_file_hash_)
  : src_(src_)
  , root_hash_(root_hash_)
  , file_hash_(file_hash_)
  , collated_data_file_hash_(collated_data_file_hash_)
{}

const std::int32_t validatorSession_candidateId::ID;

object_ptr<validatorSession_candidateId> validatorSession_candidateId::fetch(td::TlParser &p) {
  return make_object<validatorSession_candidateId>(p);
}

validatorSession_candidateId::validatorSession_candidateId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : src_(TlFetchInt256::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
  , collated_data_file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_candidateId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void validatorSession_candidateId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(src_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void validatorSession_candidateId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_candidateId");
    s.store_field("src", src_);
    s.store_field("root_hash", root_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_field("collated_data_file_hash", collated_data_file_hash_);
    s.store_class_end();
  }
}

object_ptr<validatorSession_Config> validatorSession_Config::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case validatorSession_config::ID:
      return validatorSession_config::fetch(p);
    case validatorSession_configNew::ID:
      return validatorSession_configNew::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

validatorSession_config::validatorSession_config()
  : catchain_idle_timeout_()
  , catchain_max_deps_()
  , round_candidates_()
  , next_candidate_delay_()
  , round_attempt_duration_()
  , max_round_attempts_()
  , max_block_size_()
  , max_collated_data_size_()
{}

validatorSession_config::validatorSession_config(double catchain_idle_timeout_, std::int32_t catchain_max_deps_, std::int32_t round_candidates_, double next_candidate_delay_, std::int32_t round_attempt_duration_, std::int32_t max_round_attempts_, std::int32_t max_block_size_, std::int32_t max_collated_data_size_)
  : catchain_idle_timeout_(catchain_idle_timeout_)
  , catchain_max_deps_(catchain_max_deps_)
  , round_candidates_(round_candidates_)
  , next_candidate_delay_(next_candidate_delay_)
  , round_attempt_duration_(round_attempt_duration_)
  , max_round_attempts_(max_round_attempts_)
  , max_block_size_(max_block_size_)
  , max_collated_data_size_(max_collated_data_size_)
{}

const std::int32_t validatorSession_config::ID;

object_ptr<validatorSession_Config> validatorSession_config::fetch(td::TlParser &p) {
  return make_object<validatorSession_config>(p);
}

validatorSession_config::validatorSession_config(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : catchain_idle_timeout_(TlFetchDouble::parse(p))
  , catchain_max_deps_(TlFetchInt::parse(p))
  , round_candidates_(TlFetchInt::parse(p))
  , next_candidate_delay_(TlFetchDouble::parse(p))
  , round_attempt_duration_(TlFetchInt::parse(p))
  , max_round_attempts_(TlFetchInt::parse(p))
  , max_block_size_(TlFetchInt::parse(p))
  , max_collated_data_size_(TlFetchInt::parse(p))
#undef FAIL
{}

void validatorSession_config::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(catchain_idle_timeout_, s);
  TlStoreBinary::store(catchain_max_deps_, s);
  TlStoreBinary::store(round_candidates_, s);
  TlStoreBinary::store(next_candidate_delay_, s);
  TlStoreBinary::store(round_attempt_duration_, s);
  TlStoreBinary::store(max_round_attempts_, s);
  TlStoreBinary::store(max_block_size_, s);
  TlStoreBinary::store(max_collated_data_size_, s);
}

void validatorSession_config::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(catchain_idle_timeout_, s);
  TlStoreBinary::store(catchain_max_deps_, s);
  TlStoreBinary::store(round_candidates_, s);
  TlStoreBinary::store(next_candidate_delay_, s);
  TlStoreBinary::store(round_attempt_duration_, s);
  TlStoreBinary::store(max_round_attempts_, s);
  TlStoreBinary::store(max_block_size_, s);
  TlStoreBinary::store(max_collated_data_size_, s);
}

void validatorSession_config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_config");
    s.store_field("catchain_idle_timeout", catchain_idle_timeout_);
    s.store_field("catchain_max_deps", catchain_max_deps_);
    s.store_field("round_candidates", round_candidates_);
    s.store_field("next_candidate_delay", next_candidate_delay_);
    s.store_field("round_attempt_duration", round_attempt_duration_);
    s.store_field("max_round_attempts", max_round_attempts_);
    s.store_field("max_block_size", max_block_size_);
    s.store_field("max_collated_data_size", max_collated_data_size_);
    s.store_class_end();
  }
}

validatorSession_configNew::validatorSession_configNew()
  : catchain_idle_timeout_()
  , catchain_max_deps_()
  , round_candidates_()
  , next_candidate_delay_()
  , round_attempt_duration_()
  , max_round_attempts_()
  , max_block_size_()
  , max_collated_data_size_()
  , new_catchain_ids_()
{}

validatorSession_configNew::validatorSession_configNew(double catchain_idle_timeout_, std::int32_t catchain_max_deps_, std::int32_t round_candidates_, double next_candidate_delay_, std::int32_t round_attempt_duration_, std::int32_t max_round_attempts_, std::int32_t max_block_size_, std::int32_t max_collated_data_size_, bool new_catchain_ids_)
  : catchain_idle_timeout_(catchain_idle_timeout_)
  , catchain_max_deps_(catchain_max_deps_)
  , round_candidates_(round_candidates_)
  , next_candidate_delay_(next_candidate_delay_)
  , round_attempt_duration_(round_attempt_duration_)
  , max_round_attempts_(max_round_attempts_)
  , max_block_size_(max_block_size_)
  , max_collated_data_size_(max_collated_data_size_)
  , new_catchain_ids_(new_catchain_ids_)
{}

const std::int32_t validatorSession_configNew::ID;

object_ptr<validatorSession_Config> validatorSession_configNew::fetch(td::TlParser &p) {
  return make_object<validatorSession_configNew>(p);
}

validatorSession_configNew::validatorSession_configNew(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : catchain_idle_timeout_(TlFetchDouble::parse(p))
  , catchain_max_deps_(TlFetchInt::parse(p))
  , round_candidates_(TlFetchInt::parse(p))
  , next_candidate_delay_(TlFetchDouble::parse(p))
  , round_attempt_duration_(TlFetchInt::parse(p))
  , max_round_attempts_(TlFetchInt::parse(p))
  , max_block_size_(TlFetchInt::parse(p))
  , max_collated_data_size_(TlFetchInt::parse(p))
  , new_catchain_ids_(TlFetchBool::parse(p))
#undef FAIL
{}

void validatorSession_configNew::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(catchain_idle_timeout_, s);
  TlStoreBinary::store(catchain_max_deps_, s);
  TlStoreBinary::store(round_candidates_, s);
  TlStoreBinary::store(next_candidate_delay_, s);
  TlStoreBinary::store(round_attempt_duration_, s);
  TlStoreBinary::store(max_round_attempts_, s);
  TlStoreBinary::store(max_block_size_, s);
  TlStoreBinary::store(max_collated_data_size_, s);
  TlStoreBool::store(new_catchain_ids_, s);
}

void validatorSession_configNew::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(catchain_idle_timeout_, s);
  TlStoreBinary::store(catchain_max_deps_, s);
  TlStoreBinary::store(round_candidates_, s);
  TlStoreBinary::store(next_candidate_delay_, s);
  TlStoreBinary::store(round_attempt_duration_, s);
  TlStoreBinary::store(max_round_attempts_, s);
  TlStoreBinary::store(max_block_size_, s);
  TlStoreBinary::store(max_collated_data_size_, s);
  TlStoreBool::store(new_catchain_ids_, s);
}

void validatorSession_configNew::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_configNew");
    s.store_field("catchain_idle_timeout", catchain_idle_timeout_);
    s.store_field("catchain_max_deps", catchain_max_deps_);
    s.store_field("round_candidates", round_candidates_);
    s.store_field("next_candidate_delay", next_candidate_delay_);
    s.store_field("round_attempt_duration", round_attempt_duration_);
    s.store_field("max_round_attempts", max_round_attempts_);
    s.store_field("max_block_size", max_block_size_);
    s.store_field("max_collated_data_size", max_collated_data_size_);
    s.store_field("new_catchain_ids", new_catchain_ids_);
    s.store_class_end();
  }
}

object_ptr<validatorSession_Message> validatorSession_Message::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case validatorSession_message_startSession::ID:
      return validatorSession_message_startSession::fetch(p);
    case validatorSession_message_finishSession::ID:
      return validatorSession_message_finishSession::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

validatorSession_message_startSession::validatorSession_message_startSession() {
}

const std::int32_t validatorSession_message_startSession::ID;

object_ptr<validatorSession_Message> validatorSession_message_startSession::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_startSession>(p);
}

validatorSession_message_startSession::validatorSession_message_startSession(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void validatorSession_message_startSession::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void validatorSession_message_startSession::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void validatorSession_message_startSession::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_startSession");
    s.store_class_end();
  }
}

validatorSession_message_finishSession::validatorSession_message_finishSession() {
}

const std::int32_t validatorSession_message_finishSession::ID;

object_ptr<validatorSession_Message> validatorSession_message_finishSession::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_finishSession>(p);
}

validatorSession_message_finishSession::validatorSession_message_finishSession(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void validatorSession_message_finishSession::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
}

void validatorSession_message_finishSession::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
}

void validatorSession_message_finishSession::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_finishSession");
    s.store_class_end();
  }
}

validatorSession_pong::validatorSession_pong()
  : hash_()
{}

validatorSession_pong::validatorSession_pong(std::int64_t hash_)
  : hash_(hash_)
{}

const std::int32_t validatorSession_pong::ID;

object_ptr<validatorSession_pong> validatorSession_pong::fetch(td::TlParser &p) {
  return make_object<validatorSession_pong>(p);
}

validatorSession_pong::validatorSession_pong(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchLong::parse(p))
#undef FAIL
{}

void validatorSession_pong::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void validatorSession_pong::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(hash_, s);
}

void validatorSession_pong::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_pong");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

validatorSession_round_id::validatorSession_round_id()
  : session_()
  , height_()
  , prev_block_()
  , seqno_()
{}

validatorSession_round_id::validatorSession_round_id(td::Bits256 const &session_, std::int64_t height_, td::Bits256 const &prev_block_, std::int32_t seqno_)
  : session_(session_)
  , height_(height_)
  , prev_block_(prev_block_)
  , seqno_(seqno_)
{}

const std::int32_t validatorSession_round_id::ID;

object_ptr<validatorSession_round_id> validatorSession_round_id::fetch(td::TlParser &p) {
  return make_object<validatorSession_round_id>(p);
}

validatorSession_round_id::validatorSession_round_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : session_(TlFetchInt256::parse(p))
  , height_(TlFetchLong::parse(p))
  , prev_block_(TlFetchInt256::parse(p))
  , seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void validatorSession_round_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(session_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(prev_block_, s);
  TlStoreBinary::store(seqno_, s);
}

void validatorSession_round_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(session_, s);
  TlStoreBinary::store(height_, s);
  TlStoreBinary::store(prev_block_, s);
  TlStoreBinary::store(seqno_, s);
}

void validatorSession_round_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_round_id");
    s.store_field("session", session_);
    s.store_field("height", height_);
    s.store_field("prev_block", prev_block_);
    s.store_field("seqno", seqno_);
    s.store_class_end();
  }
}

object_ptr<validatorSession_round_Message> validatorSession_round_Message::fetch(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return nullptr;
  int constructor = p.fetch_int();
  switch (constructor) {
    case validatorSession_message_submittedBlock::ID:
      return validatorSession_message_submittedBlock::fetch(p);
    case validatorSession_message_approvedBlock::ID:
      return validatorSession_message_approvedBlock::fetch(p);
    case validatorSession_message_rejectedBlock::ID:
      return validatorSession_message_rejectedBlock::fetch(p);
    case validatorSession_message_commit::ID:
      return validatorSession_message_commit::fetch(p);
    case validatorSession_message_vote::ID:
      return validatorSession_message_vote::fetch(p);
    case validatorSession_message_voteFor::ID:
      return validatorSession_message_voteFor::fetch(p);
    case validatorSession_message_precommit::ID:
      return validatorSession_message_precommit::fetch(p);
    case validatorSession_message_empty::ID:
      return validatorSession_message_empty::fetch(p);
    default:
      FAIL(PSTRING() << "Unknown constructor found " << td::format::as_hex(constructor));
  }
#undef FAIL
}

validatorSession_message_submittedBlock::validatorSession_message_submittedBlock()
  : round_()
  , root_hash_()
  , file_hash_()
  , collated_data_file_hash_()
{}

validatorSession_message_submittedBlock::validatorSession_message_submittedBlock(std::int32_t round_, td::Bits256 const &root_hash_, td::Bits256 const &file_hash_, td::Bits256 const &collated_data_file_hash_)
  : round_(round_)
  , root_hash_(root_hash_)
  , file_hash_(file_hash_)
  , collated_data_file_hash_(collated_data_file_hash_)
{}

const std::int32_t validatorSession_message_submittedBlock::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_submittedBlock::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_submittedBlock>(p);
}

validatorSession_message_submittedBlock::validatorSession_message_submittedBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , root_hash_(TlFetchInt256::parse(p))
  , file_hash_(TlFetchInt256::parse(p))
  , collated_data_file_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_message_submittedBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void validatorSession_message_submittedBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(root_hash_, s);
  TlStoreBinary::store(file_hash_, s);
  TlStoreBinary::store(collated_data_file_hash_, s);
}

void validatorSession_message_submittedBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_submittedBlock");
    s.store_field("round", round_);
    s.store_field("root_hash", root_hash_);
    s.store_field("file_hash", file_hash_);
    s.store_field("collated_data_file_hash", collated_data_file_hash_);
    s.store_class_end();
  }
}

validatorSession_message_approvedBlock::validatorSession_message_approvedBlock()
  : round_()
  , candidate_()
  , signature_()
{}

validatorSession_message_approvedBlock::validatorSession_message_approvedBlock(std::int32_t round_, td::Bits256 const &candidate_, td::BufferSlice &&signature_)
  : round_(round_)
  , candidate_(candidate_)
  , signature_(std::move(signature_))
{}

const std::int32_t validatorSession_message_approvedBlock::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_approvedBlock::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_approvedBlock>(p);
}

validatorSession_message_approvedBlock::validatorSession_message_approvedBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void validatorSession_message_approvedBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(signature_, s);
}

void validatorSession_message_approvedBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(signature_, s);
}

void validatorSession_message_approvedBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_approvedBlock");
    s.store_field("round", round_);
    s.store_field("candidate", candidate_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

validatorSession_message_rejectedBlock::validatorSession_message_rejectedBlock()
  : round_()
  , candidate_()
  , reason_()
{}

validatorSession_message_rejectedBlock::validatorSession_message_rejectedBlock(std::int32_t round_, td::Bits256 const &candidate_, td::BufferSlice &&reason_)
  : round_(round_)
  , candidate_(candidate_)
  , reason_(std::move(reason_))
{}

const std::int32_t validatorSession_message_rejectedBlock::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_rejectedBlock::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_rejectedBlock>(p);
}

validatorSession_message_rejectedBlock::validatorSession_message_rejectedBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
  , reason_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void validatorSession_message_rejectedBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(reason_, s);
}

void validatorSession_message_rejectedBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(reason_, s);
}

void validatorSession_message_rejectedBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_rejectedBlock");
    s.store_field("round", round_);
    s.store_field("candidate", candidate_);
    s.store_bytes_field("reason", reason_);
    s.store_class_end();
  }
}

validatorSession_message_commit::validatorSession_message_commit()
  : round_()
  , candidate_()
  , signature_()
{}

validatorSession_message_commit::validatorSession_message_commit(std::int32_t round_, td::Bits256 const &candidate_, td::BufferSlice &&signature_)
  : round_(round_)
  , candidate_(candidate_)
  , signature_(std::move(signature_))
{}

const std::int32_t validatorSession_message_commit::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_commit::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_commit>(p);
}

validatorSession_message_commit::validatorSession_message_commit(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
  , signature_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void validatorSession_message_commit::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(signature_, s);
}

void validatorSession_message_commit::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(candidate_, s);
  TlStoreString::store(signature_, s);
}

void validatorSession_message_commit::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_commit");
    s.store_field("round", round_);
    s.store_field("candidate", candidate_);
    s.store_bytes_field("signature", signature_);
    s.store_class_end();
  }
}

validatorSession_message_vote::validatorSession_message_vote()
  : round_()
  , attempt_()
  , candidate_()
{}

validatorSession_message_vote::validatorSession_message_vote(std::int32_t round_, std::int32_t attempt_, td::Bits256 const &candidate_)
  : round_(round_)
  , attempt_(attempt_)
  , candidate_(candidate_)
{}

const std::int32_t validatorSession_message_vote::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_vote::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_vote>(p);
}

validatorSession_message_vote::validatorSession_message_vote(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , attempt_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_message_vote::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_vote::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_vote::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_vote");
    s.store_field("round", round_);
    s.store_field("attempt", attempt_);
    s.store_field("candidate", candidate_);
    s.store_class_end();
  }
}

validatorSession_message_voteFor::validatorSession_message_voteFor()
  : round_()
  , attempt_()
  , candidate_()
{}

validatorSession_message_voteFor::validatorSession_message_voteFor(std::int32_t round_, std::int32_t attempt_, td::Bits256 const &candidate_)
  : round_(round_)
  , attempt_(attempt_)
  , candidate_(candidate_)
{}

const std::int32_t validatorSession_message_voteFor::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_voteFor::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_voteFor>(p);
}

validatorSession_message_voteFor::validatorSession_message_voteFor(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , attempt_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_message_voteFor::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_voteFor::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_voteFor::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_voteFor");
    s.store_field("round", round_);
    s.store_field("attempt", attempt_);
    s.store_field("candidate", candidate_);
    s.store_class_end();
  }
}

validatorSession_message_precommit::validatorSession_message_precommit()
  : round_()
  , attempt_()
  , candidate_()
{}

validatorSession_message_precommit::validatorSession_message_precommit(std::int32_t round_, std::int32_t attempt_, td::Bits256 const &candidate_)
  : round_(round_)
  , attempt_(attempt_)
  , candidate_(candidate_)
{}

const std::int32_t validatorSession_message_precommit::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_precommit::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_precommit>(p);
}

validatorSession_message_precommit::validatorSession_message_precommit(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , attempt_(TlFetchInt::parse(p))
  , candidate_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_message_precommit::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_precommit::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
  TlStoreBinary::store(candidate_, s);
}

void validatorSession_message_precommit::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_precommit");
    s.store_field("round", round_);
    s.store_field("attempt", attempt_);
    s.store_field("candidate", candidate_);
    s.store_class_end();
  }
}

validatorSession_message_empty::validatorSession_message_empty()
  : round_()
  , attempt_()
{}

validatorSession_message_empty::validatorSession_message_empty(std::int32_t round_, std::int32_t attempt_)
  : round_(round_)
  , attempt_(attempt_)
{}

const std::int32_t validatorSession_message_empty::ID;

object_ptr<validatorSession_round_Message> validatorSession_message_empty::fetch(td::TlParser &p) {
  return make_object<validatorSession_message_empty>(p);
}

validatorSession_message_empty::validatorSession_message_empty(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , attempt_(TlFetchInt::parse(p))
#undef FAIL
{}

void validatorSession_message_empty::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
}

void validatorSession_message_empty::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(attempt_, s);
}

void validatorSession_message_empty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_message_empty");
    s.store_field("round", round_);
    s.store_field("attempt", attempt_);
    s.store_class_end();
  }
}

validatorSession_candidate_id::validatorSession_candidate_id()
  : round_()
  , block_hash_()
{}

validatorSession_candidate_id::validatorSession_candidate_id(td::Bits256 const &round_, td::Bits256 const &block_hash_)
  : round_(round_)
  , block_hash_(block_hash_)
{}

const std::int32_t validatorSession_candidate_id::ID;

object_ptr<validatorSession_candidate_id> validatorSession_candidate_id::fetch(td::TlParser &p) {
  return make_object<validatorSession_candidate_id>(p);
}

validatorSession_candidate_id::validatorSession_candidate_id(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt256::parse(p))
  , block_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void validatorSession_candidate_id::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(block_hash_, s);
}

void validatorSession_candidate_id::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  TlStoreBinary::store(round_, s);
  TlStoreBinary::store(block_hash_, s);
}

void validatorSession_candidate_id::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_candidate_id");
    s.store_field("round", round_);
    s.store_field("block_hash", block_hash_);
    s.store_class_end();
  }
}

adnl_ping::adnl_ping()
  : value_()
{}

adnl_ping::adnl_ping(std::int64_t value_)
  : value_(value_)
{}

const std::int32_t adnl_ping::ID;

object_ptr<adnl_ping> adnl_ping::fetch(td::TlParser &p) {
  return make_object<adnl_ping>(p);
}

adnl_ping::adnl_ping(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchLong::parse(p))
#undef FAIL
{}

void adnl_ping::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(531276223);
  TlStoreBinary::store(value_, s);
}

void adnl_ping::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(531276223);
  TlStoreBinary::store(value_, s);
}

void adnl_ping::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "adnl_ping");
    s.store_field("value", value_);
    s.store_class_end();
  }
}

adnl_ping::ReturnType adnl_ping::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<adnl_pong>, 544504846>::parse(p);
#undef FAIL
}

catchain_getBlock::catchain_getBlock()
  : block_()
{}

catchain_getBlock::catchain_getBlock(td::Bits256 const &block_)
  : block_(block_)
{}

const std::int32_t catchain_getBlock::ID;

object_ptr<catchain_getBlock> catchain_getBlock::fetch(td::TlParser &p) {
  return make_object<catchain_getBlock>(p);
}

catchain_getBlock::catchain_getBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt256::parse(p))
#undef FAIL
{}

void catchain_getBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(155049336);
  TlStoreBinary::store(block_, s);
}

void catchain_getBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(155049336);
  TlStoreBinary::store(block_, s);
}

void catchain_getBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_getBlock");
    s.store_field("block", block_);
    s.store_class_end();
  }
}

catchain_getBlock::ReturnType catchain_getBlock::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<catchain_BlockResult>::parse(p);
#undef FAIL
}

catchain_getBlockHistory::catchain_getBlockHistory()
  : block_()
  , height_()
  , stop_if_()
{}

catchain_getBlockHistory::catchain_getBlockHistory(td::Bits256 const &block_, std::int64_t height_, std::vector<td::Bits256> &&stop_if_)
  : block_(block_)
  , height_(height_)
  , stop_if_(std::move(stop_if_))
{}

const std::int32_t catchain_getBlockHistory::ID;

object_ptr<catchain_getBlockHistory> catchain_getBlockHistory::fetch(td::TlParser &p) {
  return make_object<catchain_getBlockHistory>(p);
}

catchain_getBlockHistory::catchain_getBlockHistory(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchInt256::parse(p))
  , height_(TlFetchLong::parse(p))
  , stop_if_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void catchain_getBlockHistory::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1470730762);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(height_, s);
  TlStoreVector<TlStoreBinary>::store(stop_if_, s);
}

void catchain_getBlockHistory::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1470730762);
  TlStoreBinary::store(block_, s);
  TlStoreBinary::store(height_, s);
  TlStoreVector<TlStoreBinary>::store(stop_if_, s);
}

void catchain_getBlockHistory::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_getBlockHistory");
    s.store_field("block", block_);
    s.store_field("height", height_);
    { const std::vector<td::Bits256> &v = stop_if_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("stop_if", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_getBlockHistory::ReturnType catchain_getBlockHistory::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<catchain_sent>, -84454993>::parse(p);
#undef FAIL
}

catchain_getBlocks::catchain_getBlocks()
  : blocks_()
{}

catchain_getBlocks::catchain_getBlocks(std::vector<td::Bits256> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t catchain_getBlocks::ID;

object_ptr<catchain_getBlocks> catchain_getBlocks::fetch(td::TlParser &p) {
  return make_object<catchain_getBlocks>(p);
}

catchain_getBlocks::catchain_getBlocks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchInt256>::parse(p))
#undef FAIL
{}

void catchain_getBlocks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(53062594);
  TlStoreVector<TlStoreBinary>::store(blocks_, s);
}

void catchain_getBlocks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(53062594);
  TlStoreVector<TlStoreBinary>::store(blocks_, s);
}

void catchain_getBlocks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_getBlocks");
    { const std::vector<td::Bits256> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_getBlocks::ReturnType catchain_getBlocks::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<catchain_sent>, -84454993>::parse(p);
#undef FAIL
}

catchain_getDifference::catchain_getDifference()
  : rt_()
{}

catchain_getDifference::catchain_getDifference(std::vector<std::int32_t> &&rt_)
  : rt_(std::move(rt_))
{}

const std::int32_t catchain_getDifference::ID;

object_ptr<catchain_getDifference> catchain_getDifference::fetch(td::TlParser &p) {
  return make_object<catchain_getDifference>(p);
}

catchain_getDifference::catchain_getDifference(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : rt_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void catchain_getDifference::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-798175528);
  TlStoreVector<TlStoreBinary>::store(rt_, s);
}

void catchain_getDifference::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-798175528);
  TlStoreVector<TlStoreBinary>::store(rt_, s);
}

void catchain_getDifference::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "catchain_getDifference");
    { const std::vector<std::int32_t> &v = rt_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("rt", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

catchain_getDifference::ReturnType catchain_getDifference::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<catchain_Difference>::parse(p);
#undef FAIL
}

dht_findNode::dht_findNode()
  : key_()
  , k_()
{}

dht_findNode::dht_findNode(td::Bits256 const &key_, std::int32_t k_)
  : key_(key_)
  , k_(k_)
{}

const std::int32_t dht_findNode::ID;

object_ptr<dht_findNode> dht_findNode::fetch(td::TlParser &p) {
  return make_object<dht_findNode>(p);
}

dht_findNode::dht_findNode(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
  , k_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_findNode::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1826803307);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(k_, s);
}

void dht_findNode::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1826803307);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(k_, s);
}

void dht_findNode::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_findNode");
    s.store_field("key", key_);
    s.store_field("k", k_);
    s.store_class_end();
  }
}

dht_findNode::ReturnType dht_findNode::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<dht_nodes>, 2037686462>::parse(p);
#undef FAIL
}

dht_findValue::dht_findValue()
  : key_()
  , k_()
{}

dht_findValue::dht_findValue(td::Bits256 const &key_, std::int32_t k_)
  : key_(key_)
  , k_(k_)
{}

const std::int32_t dht_findValue::ID;

object_ptr<dht_findValue> dht_findValue::fetch(td::TlParser &p) {
  return make_object<dht_findValue>(p);
}

dht_findValue::dht_findValue(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchInt256::parse(p))
  , k_(TlFetchInt::parse(p))
#undef FAIL
{}

void dht_findValue::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1370791919);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(k_, s);
}

void dht_findValue::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1370791919);
  TlStoreBinary::store(key_, s);
  TlStoreBinary::store(k_, s);
}

void dht_findValue::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_findValue");
    s.store_field("key", key_);
    s.store_field("k", k_);
    s.store_class_end();
  }
}

dht_findValue::ReturnType dht_findValue::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<dht_ValueResult>::parse(p);
#undef FAIL
}

dht_getSignedAddressList::dht_getSignedAddressList() {
}

const std::int32_t dht_getSignedAddressList::ID;

object_ptr<dht_getSignedAddressList> dht_getSignedAddressList::fetch(td::TlParser &p) {
  return make_object<dht_getSignedAddressList>(p);
}

dht_getSignedAddressList::dht_getSignedAddressList(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void dht_getSignedAddressList::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1451669267);
}

void dht_getSignedAddressList::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1451669267);
}

void dht_getSignedAddressList::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_getSignedAddressList");
    s.store_class_end();
  }
}

dht_getSignedAddressList::ReturnType dht_getSignedAddressList::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<dht_node>, -2074922424>::parse(p);
#undef FAIL
}

dht_ping::dht_ping()
  : random_id_()
{}

dht_ping::dht_ping(std::int64_t random_id_)
  : random_id_(random_id_)
{}

const std::int32_t dht_ping::ID;

object_ptr<dht_ping> dht_ping::fetch(td::TlParser &p) {
  return make_object<dht_ping>(p);
}

dht_ping::dht_ping(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : random_id_(TlFetchLong::parse(p))
#undef FAIL
{}

void dht_ping::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-873775336);
  TlStoreBinary::store(random_id_, s);
}

void dht_ping::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-873775336);
  TlStoreBinary::store(random_id_, s);
}

void dht_ping::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_ping");
    s.store_field("random_id", random_id_);
    s.store_class_end();
  }
}

dht_ping::ReturnType dht_ping::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<dht_pong>, 1519054721>::parse(p);
#undef FAIL
}

dht_query::dht_query()
  : node_()
{}

dht_query::dht_query(object_ptr<dht_node> &&node_)
  : node_(std::move(node_))
{}

const std::int32_t dht_query::ID;

object_ptr<dht_query> dht_query::fetch(td::TlParser &p) {
  return make_object<dht_query>(p);
}

dht_query::dht_query(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : node_(TlFetchObject<dht_node>::parse(p))
#undef FAIL
{}

void dht_query::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(2102593385);
  TlStoreObject::store(node_, s);
}

void dht_query::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(2102593385);
  TlStoreObject::store(node_, s);
}

void dht_query::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_query");
    if (node_ == nullptr) { s.store_field("node", "null"); } else { node_->store(s, "node"); }
    s.store_class_end();
  }
}

dht_query::ReturnType dht_query::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchTrue, 1072550713>::parse(p);
#undef FAIL
}

dht_store::dht_store()
  : value_()
{}

dht_store::dht_store(object_ptr<dht_value> &&value_)
  : value_(std::move(value_))
{}

const std::int32_t dht_store::ID;

object_ptr<dht_store> dht_store::fetch(td::TlParser &p) {
  return make_object<dht_store>(p);
}

dht_store::dht_store(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : value_(TlFetchObject<dht_value>::parse(p))
#undef FAIL
{}

void dht_store::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(882065938);
  TlStoreObject::store(value_, s);
}

void dht_store::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(882065938);
  TlStoreObject::store(value_, s);
}

void dht_store::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "dht_store");
    if (value_ == nullptr) { s.store_field("value", "null"); } else { value_->store(s, "value"); }
    s.store_class_end();
  }
}

dht_store::ReturnType dht_store::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<dht_stored>, 1881602824>::parse(p);
#undef FAIL
}

engine_validator_addAdnlId::engine_validator_addAdnlId()
  : key_hash_()
  , category_()
{}

engine_validator_addAdnlId::engine_validator_addAdnlId(td::Bits256 const &key_hash_, std::int32_t category_)
  : key_hash_(key_hash_)
  , category_(category_)
{}

const std::int32_t engine_validator_addAdnlId::ID;

object_ptr<engine_validator_addAdnlId> engine_validator_addAdnlId::fetch(td::TlParser &p) {
  return make_object<engine_validator_addAdnlId>(p);
}

engine_validator_addAdnlId::engine_validator_addAdnlId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , category_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addAdnlId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-310029141);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(category_, s);
}

void engine_validator_addAdnlId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-310029141);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(category_, s);
}

void engine_validator_addAdnlId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addAdnlId");
    s.store_field("key_hash", key_hash_);
    s.store_field("category", category_);
    s.store_class_end();
  }
}

engine_validator_addAdnlId::ReturnType engine_validator_addAdnlId::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addControlInterface::engine_validator_addControlInterface()
  : key_hash_()
  , port_()
{}

engine_validator_addControlInterface::engine_validator_addControlInterface(td::Bits256 const &key_hash_, std::int32_t port_)
  : key_hash_(key_hash_)
  , port_(port_)
{}

const std::int32_t engine_validator_addControlInterface::ID;

object_ptr<engine_validator_addControlInterface> engine_validator_addControlInterface::fetch(td::TlParser &p) {
  return make_object<engine_validator_addControlInterface>(p);
}

engine_validator_addControlInterface::engine_validator_addControlInterface(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addControlInterface::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(881587196);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
}

void engine_validator_addControlInterface::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(881587196);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
}

void engine_validator_addControlInterface::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addControlInterface");
    s.store_field("key_hash", key_hash_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

engine_validator_addControlInterface::ReturnType engine_validator_addControlInterface::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addControlProcess::engine_validator_addControlProcess()
  : key_hash_()
  , port_()
  , peer_key_()
  , permissions_()
{}

engine_validator_addControlProcess::engine_validator_addControlProcess(td::Bits256 const &key_hash_, std::int32_t port_, td::Bits256 const &peer_key_, std::int32_t permissions_)
  : key_hash_(key_hash_)
  , port_(port_)
  , peer_key_(peer_key_)
  , permissions_(permissions_)
{}

const std::int32_t engine_validator_addControlProcess::ID;

object_ptr<engine_validator_addControlProcess> engine_validator_addControlProcess::fetch(td::TlParser &p) {
  return make_object<engine_validator_addControlProcess>(p);
}

engine_validator_addControlProcess::engine_validator_addControlProcess(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
  , peer_key_(TlFetchInt256::parse(p))
  , permissions_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addControlProcess::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1524692816);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(peer_key_, s);
  TlStoreBinary::store(permissions_, s);
}

void engine_validator_addControlProcess::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1524692816);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
  TlStoreBinary::store(peer_key_, s);
  TlStoreBinary::store(permissions_, s);
}

void engine_validator_addControlProcess::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addControlProcess");
    s.store_field("key_hash", key_hash_);
    s.store_field("port", port_);
    s.store_field("peer_key", peer_key_);
    s.store_field("permissions", permissions_);
    s.store_class_end();
  }
}

engine_validator_addControlProcess::ReturnType engine_validator_addControlProcess::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addDhtId::engine_validator_addDhtId()
  : key_hash_()
{}

engine_validator_addDhtId::engine_validator_addDhtId(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_addDhtId::ID;

object_ptr<engine_validator_addDhtId> engine_validator_addDhtId::fetch(td::TlParser &p) {
  return make_object<engine_validator_addDhtId>(p);
}

engine_validator_addDhtId::engine_validator_addDhtId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_addDhtId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-183755124);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_addDhtId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-183755124);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_addDhtId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addDhtId");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_addDhtId::ReturnType engine_validator_addDhtId::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addListeningPort::engine_validator_addListeningPort()
  : ip_()
  , port_()
  , categories_()
  , priority_categories_()
{}

engine_validator_addListeningPort::engine_validator_addListeningPort(std::int32_t ip_, std::int32_t port_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : ip_(ip_)
  , port_(port_)
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_validator_addListeningPort::ID;

object_ptr<engine_validator_addListeningPort> engine_validator_addListeningPort::fetch(td::TlParser &p) {
  return make_object<engine_validator_addListeningPort>(p);
}

engine_validator_addListeningPort::engine_validator_addListeningPort(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_validator_addListeningPort::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-362051147);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_addListeningPort::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-362051147);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_addListeningPort::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addListeningPort");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_addListeningPort::ReturnType engine_validator_addListeningPort::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addLiteserver::engine_validator_addLiteserver()
  : key_hash_()
  , port_()
{}

engine_validator_addLiteserver::engine_validator_addLiteserver(td::Bits256 const &key_hash_, std::int32_t port_)
  : key_hash_(key_hash_)
  , port_(port_)
{}

const std::int32_t engine_validator_addLiteserver::ID;

object_ptr<engine_validator_addLiteserver> engine_validator_addLiteserver::fetch(td::TlParser &p) {
  return make_object<engine_validator_addLiteserver>(p);
}

engine_validator_addLiteserver::engine_validator_addLiteserver(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , port_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addLiteserver::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-259387577);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
}

void engine_validator_addLiteserver::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-259387577);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(port_, s);
}

void engine_validator_addLiteserver::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addLiteserver");
    s.store_field("key_hash", key_hash_);
    s.store_field("port", port_);
    s.store_class_end();
  }
}

engine_validator_addLiteserver::ReturnType engine_validator_addLiteserver::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addProxy::engine_validator_addProxy()
  : in_ip_()
  , in_port_()
  , out_ip_()
  , out_port_()
  , proxy_()
  , categories_()
  , priority_categories_()
{}

engine_validator_addProxy::engine_validator_addProxy(std::int32_t in_ip_, std::int32_t in_port_, std::int32_t out_ip_, std::int32_t out_port_, object_ptr<adnl_Proxy> &&proxy_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : in_ip_(in_ip_)
  , in_port_(in_port_)
  , out_ip_(out_ip_)
  , out_port_(out_port_)
  , proxy_(std::move(proxy_))
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_validator_addProxy::ID;

object_ptr<engine_validator_addProxy> engine_validator_addProxy::fetch(td::TlParser &p) {
  return make_object<engine_validator_addProxy>(p);
}

engine_validator_addProxy::engine_validator_addProxy(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : in_ip_(TlFetchInt::parse(p))
  , in_port_(TlFetchInt::parse(p))
  , out_ip_(TlFetchInt::parse(p))
  , out_port_(TlFetchInt::parse(p))
  , proxy_(TlFetchObject<adnl_Proxy>::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_validator_addProxy::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-151178251);
  TlStoreBinary::store(in_ip_, s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_addProxy::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-151178251);
  TlStoreBinary::store(in_ip_, s);
  TlStoreBinary::store(in_port_, s);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreBoxedUnknown<TlStoreObject>::store(proxy_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_addProxy::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addProxy");
    s.store_field("in_ip", in_ip_);
    s.store_field("in_port", in_port_);
    s.store_field("out_ip", out_ip_);
    s.store_field("out_port", out_port_);
    if (proxy_ == nullptr) { s.store_field("proxy", "null"); } else { proxy_->store(s, "proxy"); }
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_addProxy::ReturnType engine_validator_addProxy::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addValidatorAdnlAddress::engine_validator_addValidatorAdnlAddress()
  : permanent_key_hash_()
  , key_hash_()
  , ttl_()
{}

engine_validator_addValidatorAdnlAddress::engine_validator_addValidatorAdnlAddress(td::Bits256 const &permanent_key_hash_, td::Bits256 const &key_hash_, std::int32_t ttl_)
  : permanent_key_hash_(permanent_key_hash_)
  , key_hash_(key_hash_)
  , ttl_(ttl_)
{}

const std::int32_t engine_validator_addValidatorAdnlAddress::ID;

object_ptr<engine_validator_addValidatorAdnlAddress> engine_validator_addValidatorAdnlAddress::fetch(td::TlParser &p) {
  return make_object<engine_validator_addValidatorAdnlAddress>(p);
}

engine_validator_addValidatorAdnlAddress::engine_validator_addValidatorAdnlAddress(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : permanent_key_hash_(TlFetchInt256::parse(p))
  , key_hash_(TlFetchInt256::parse(p))
  , ttl_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addValidatorAdnlAddress::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-624187774);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorAdnlAddress::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-624187774);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorAdnlAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addValidatorAdnlAddress");
    s.store_field("permanent_key_hash", permanent_key_hash_);
    s.store_field("key_hash", key_hash_);
    s.store_field("ttl", ttl_);
    s.store_class_end();
  }
}

engine_validator_addValidatorAdnlAddress::ReturnType engine_validator_addValidatorAdnlAddress::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addValidatorPermanentKey::engine_validator_addValidatorPermanentKey()
  : key_hash_()
  , election_date_()
  , ttl_()
{}

engine_validator_addValidatorPermanentKey::engine_validator_addValidatorPermanentKey(td::Bits256 const &key_hash_, std::int32_t election_date_, std::int32_t ttl_)
  : key_hash_(key_hash_)
  , election_date_(election_date_)
  , ttl_(ttl_)
{}

const std::int32_t engine_validator_addValidatorPermanentKey::ID;

object_ptr<engine_validator_addValidatorPermanentKey> engine_validator_addValidatorPermanentKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_addValidatorPermanentKey>(p);
}

engine_validator_addValidatorPermanentKey::engine_validator_addValidatorPermanentKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , election_date_(TlFetchInt::parse(p))
  , ttl_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addValidatorPermanentKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1844116104);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorPermanentKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1844116104);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(election_date_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorPermanentKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addValidatorPermanentKey");
    s.store_field("key_hash", key_hash_);
    s.store_field("election_date", election_date_);
    s.store_field("ttl", ttl_);
    s.store_class_end();
  }
}

engine_validator_addValidatorPermanentKey::ReturnType engine_validator_addValidatorPermanentKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_addValidatorTempKey::engine_validator_addValidatorTempKey()
  : permanent_key_hash_()
  , key_hash_()
  , ttl_()
{}

engine_validator_addValidatorTempKey::engine_validator_addValidatorTempKey(td::Bits256 const &permanent_key_hash_, td::Bits256 const &key_hash_, std::int32_t ttl_)
  : permanent_key_hash_(permanent_key_hash_)
  , key_hash_(key_hash_)
  , ttl_(ttl_)
{}

const std::int32_t engine_validator_addValidatorTempKey::ID;

object_ptr<engine_validator_addValidatorTempKey> engine_validator_addValidatorTempKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_addValidatorTempKey>(p);
}

engine_validator_addValidatorTempKey::engine_validator_addValidatorTempKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : permanent_key_hash_(TlFetchInt256::parse(p))
  , key_hash_(TlFetchInt256::parse(p))
  , ttl_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_addValidatorTempKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1926009038);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorTempKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1926009038);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
  TlStoreBinary::store(ttl_, s);
}

void engine_validator_addValidatorTempKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_addValidatorTempKey");
    s.store_field("permanent_key_hash", permanent_key_hash_);
    s.store_field("key_hash", key_hash_);
    s.store_field("ttl", ttl_);
    s.store_class_end();
  }
}

engine_validator_addValidatorTempKey::ReturnType engine_validator_addValidatorTempKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_changeFullNodeAdnlAddress::engine_validator_changeFullNodeAdnlAddress()
  : adnl_id_()
{}

engine_validator_changeFullNodeAdnlAddress::engine_validator_changeFullNodeAdnlAddress(td::Bits256 const &adnl_id_)
  : adnl_id_(adnl_id_)
{}

const std::int32_t engine_validator_changeFullNodeAdnlAddress::ID;

object_ptr<engine_validator_changeFullNodeAdnlAddress> engine_validator_changeFullNodeAdnlAddress::fetch(td::TlParser &p) {
  return make_object<engine_validator_changeFullNodeAdnlAddress>(p);
}

engine_validator_changeFullNodeAdnlAddress::engine_validator_changeFullNodeAdnlAddress(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : adnl_id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_changeFullNodeAdnlAddress::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1094268539);
  TlStoreBinary::store(adnl_id_, s);
}

void engine_validator_changeFullNodeAdnlAddress::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1094268539);
  TlStoreBinary::store(adnl_id_, s);
}

void engine_validator_changeFullNodeAdnlAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_changeFullNodeAdnlAddress");
    s.store_field("adnl_id", adnl_id_);
    s.store_class_end();
  }
}

engine_validator_changeFullNodeAdnlAddress::ReturnType engine_validator_changeFullNodeAdnlAddress::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_checkDhtServers::engine_validator_checkDhtServers()
  : id_()
{}

engine_validator_checkDhtServers::engine_validator_checkDhtServers(td::Bits256 const &id_)
  : id_(id_)
{}

const std::int32_t engine_validator_checkDhtServers::ID;

object_ptr<engine_validator_checkDhtServers> engine_validator_checkDhtServers::fetch(td::TlParser &p) {
  return make_object<engine_validator_checkDhtServers>(p);
}

engine_validator_checkDhtServers::engine_validator_checkDhtServers(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_checkDhtServers::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-773578550);
  TlStoreBinary::store(id_, s);
}

void engine_validator_checkDhtServers::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-773578550);
  TlStoreBinary::store(id_, s);
}

void engine_validator_checkDhtServers::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_checkDhtServers");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

engine_validator_checkDhtServers::ReturnType engine_validator_checkDhtServers::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_dhtServersStatus>, 725155112>::parse(p);
#undef FAIL
}

engine_validator_controlQuery::engine_validator_controlQuery()
  : data_()
{}

engine_validator_controlQuery::engine_validator_controlQuery(td::BufferSlice &&data_)
  : data_(std::move(data_))
{}

const std::int32_t engine_validator_controlQuery::ID;

object_ptr<engine_validator_controlQuery> engine_validator_controlQuery::fetch(td::TlParser &p) {
  return make_object<engine_validator_controlQuery>(p);
}

engine_validator_controlQuery::engine_validator_controlQuery(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_controlQuery::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1535722048);
  TlStoreString::store(data_, s);
}

void engine_validator_controlQuery::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1535722048);
  TlStoreString::store(data_, s);
}

void engine_validator_controlQuery::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_controlQuery");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

engine_validator_controlQuery::ReturnType engine_validator_controlQuery::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<Object>, 695225504>::parse(p);
#undef FAIL
}

engine_validator_createElectionBid::engine_validator_createElectionBid()
  : election_date_()
  , election_addr_()
  , wallet_()
{}

engine_validator_createElectionBid::engine_validator_createElectionBid(std::int32_t election_date_, std::string const &election_addr_, std::string const &wallet_)
  : election_date_(election_date_)
  , election_addr_(std::move(election_addr_))
  , wallet_(std::move(wallet_))
{}

const std::int32_t engine_validator_createElectionBid::ID;

object_ptr<engine_validator_createElectionBid> engine_validator_createElectionBid::fetch(td::TlParser &p) {
  return make_object<engine_validator_createElectionBid>(p);
}

engine_validator_createElectionBid::engine_validator_createElectionBid(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : election_date_(TlFetchInt::parse(p))
  , election_addr_(TlFetchString<std::string>::parse(p))
  , wallet_(TlFetchString<std::string>::parse(p))
#undef FAIL
{}

void engine_validator_createElectionBid::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-451038907);
  TlStoreBinary::store(election_date_, s);
  TlStoreString::store(election_addr_, s);
  TlStoreString::store(wallet_, s);
}

void engine_validator_createElectionBid::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-451038907);
  TlStoreBinary::store(election_date_, s);
  TlStoreString::store(election_addr_, s);
  TlStoreString::store(wallet_, s);
}

void engine_validator_createElectionBid::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_createElectionBid");
    s.store_field("election_date", election_date_);
    s.store_field("election_addr", election_addr_);
    s.store_field("wallet", wallet_);
    s.store_class_end();
  }
}

engine_validator_createElectionBid::ReturnType engine_validator_createElectionBid::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_electionBid>, 598899261>::parse(p);
#undef FAIL
}

engine_validator_createProposalVote::engine_validator_createProposalVote()
  : vote_()
{}

engine_validator_createProposalVote::engine_validator_createProposalVote(td::BufferSlice &&vote_)
  : vote_(std::move(vote_))
{}

const std::int32_t engine_validator_createProposalVote::ID;

object_ptr<engine_validator_createProposalVote> engine_validator_createProposalVote::fetch(td::TlParser &p) {
  return make_object<engine_validator_createProposalVote>(p);
}

engine_validator_createProposalVote::engine_validator_createProposalVote(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : vote_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_createProposalVote::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(498278765);
  TlStoreString::store(vote_, s);
}

void engine_validator_createProposalVote::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(498278765);
  TlStoreString::store(vote_, s);
}

void engine_validator_createProposalVote::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_createProposalVote");
    s.store_bytes_field("vote", vote_);
    s.store_class_end();
  }
}

engine_validator_createProposalVote::ReturnType engine_validator_createProposalVote::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_proposalVote>, 2137401069>::parse(p);
#undef FAIL
}

engine_validator_delAdnlId::engine_validator_delAdnlId()
  : key_hash_()
{}

engine_validator_delAdnlId::engine_validator_delAdnlId(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_delAdnlId::ID;

object_ptr<engine_validator_delAdnlId> engine_validator_delAdnlId::fetch(td::TlParser &p) {
  return make_object<engine_validator_delAdnlId>(p);
}

engine_validator_delAdnlId::engine_validator_delAdnlId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_delAdnlId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(691696882);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delAdnlId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(691696882);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delAdnlId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delAdnlId");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_delAdnlId::ReturnType engine_validator_delAdnlId::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delDhtId::engine_validator_delDhtId()
  : key_hash_()
{}

engine_validator_delDhtId::engine_validator_delDhtId(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_delDhtId::ID;

object_ptr<engine_validator_delDhtId> engine_validator_delDhtId::fetch(td::TlParser &p) {
  return make_object<engine_validator_delDhtId>(p);
}

engine_validator_delDhtId::engine_validator_delDhtId(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_delDhtId::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-2063770818);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delDhtId::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-2063770818);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delDhtId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delDhtId");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_delDhtId::ReturnType engine_validator_delDhtId::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delListeningPort::engine_validator_delListeningPort()
  : ip_()
  , port_()
  , categories_()
  , priority_categories_()
{}

engine_validator_delListeningPort::engine_validator_delListeningPort(std::int32_t ip_, std::int32_t port_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : ip_(ip_)
  , port_(port_)
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_validator_delListeningPort::ID;

object_ptr<engine_validator_delListeningPort> engine_validator_delListeningPort::fetch(td::TlParser &p) {
  return make_object<engine_validator_delListeningPort>(p);
}

engine_validator_delListeningPort::engine_validator_delListeningPort(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : ip_(TlFetchInt::parse(p))
  , port_(TlFetchInt::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_validator_delListeningPort::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(828094543);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_delListeningPort::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(828094543);
  TlStoreBinary::store(ip_, s);
  TlStoreBinary::store(port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_delListeningPort::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delListeningPort");
    s.store_field("ip", ip_);
    s.store_field("port", port_);
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_delListeningPort::ReturnType engine_validator_delListeningPort::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delProxy::engine_validator_delProxy()
  : out_ip_()
  , out_port_()
  , categories_()
  , priority_categories_()
{}

engine_validator_delProxy::engine_validator_delProxy(std::int32_t out_ip_, std::int32_t out_port_, std::vector<std::int32_t> &&categories_, std::vector<std::int32_t> &&priority_categories_)
  : out_ip_(out_ip_)
  , out_port_(out_port_)
  , categories_(std::move(categories_))
  , priority_categories_(std::move(priority_categories_))
{}

const std::int32_t engine_validator_delProxy::ID;

object_ptr<engine_validator_delProxy> engine_validator_delProxy::fetch(td::TlParser &p) {
  return make_object<engine_validator_delProxy>(p);
}

engine_validator_delProxy::engine_validator_delProxy(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : out_ip_(TlFetchInt::parse(p))
  , out_port_(TlFetchInt::parse(p))
  , categories_(TlFetchVector<TlFetchInt>::parse(p))
  , priority_categories_(TlFetchVector<TlFetchInt>::parse(p))
#undef FAIL
{}

void engine_validator_delProxy::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1970850941);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_delProxy::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1970850941);
  TlStoreBinary::store(out_ip_, s);
  TlStoreBinary::store(out_port_, s);
  TlStoreVector<TlStoreBinary>::store(categories_, s);
  TlStoreVector<TlStoreBinary>::store(priority_categories_, s);
}

void engine_validator_delProxy::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delProxy");
    s.store_field("out_ip", out_ip_);
    s.store_field("out_port", out_port_);
    { const std::vector<std::int32_t> &v = categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    { const std::vector<std::int32_t> &v = priority_categories_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("priority_categories", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

engine_validator_delProxy::ReturnType engine_validator_delProxy::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delValidatorAdnlAddress::engine_validator_delValidatorAdnlAddress()
  : permanent_key_hash_()
  , key_hash_()
{}

engine_validator_delValidatorAdnlAddress::engine_validator_delValidatorAdnlAddress(td::Bits256 const &permanent_key_hash_, td::Bits256 const &key_hash_)
  : permanent_key_hash_(permanent_key_hash_)
  , key_hash_(key_hash_)
{}

const std::int32_t engine_validator_delValidatorAdnlAddress::ID;

object_ptr<engine_validator_delValidatorAdnlAddress> engine_validator_delValidatorAdnlAddress::fetch(td::TlParser &p) {
  return make_object<engine_validator_delValidatorAdnlAddress>(p);
}

engine_validator_delValidatorAdnlAddress::engine_validator_delValidatorAdnlAddress(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : permanent_key_hash_(TlFetchInt256::parse(p))
  , key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_delValidatorAdnlAddress::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-150453414);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorAdnlAddress::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-150453414);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorAdnlAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delValidatorAdnlAddress");
    s.store_field("permanent_key_hash", permanent_key_hash_);
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_delValidatorAdnlAddress::ReturnType engine_validator_delValidatorAdnlAddress::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delValidatorPermanentKey::engine_validator_delValidatorPermanentKey()
  : key_hash_()
{}

engine_validator_delValidatorPermanentKey::engine_validator_delValidatorPermanentKey(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_delValidatorPermanentKey::ID;

object_ptr<engine_validator_delValidatorPermanentKey> engine_validator_delValidatorPermanentKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_delValidatorPermanentKey>(p);
}

engine_validator_delValidatorPermanentKey::engine_validator_delValidatorPermanentKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_delValidatorPermanentKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(390777082);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorPermanentKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(390777082);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorPermanentKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delValidatorPermanentKey");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_delValidatorPermanentKey::ReturnType engine_validator_delValidatorPermanentKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_delValidatorTempKey::engine_validator_delValidatorTempKey()
  : permanent_key_hash_()
  , key_hash_()
{}

engine_validator_delValidatorTempKey::engine_validator_delValidatorTempKey(td::Bits256 const &permanent_key_hash_, td::Bits256 const &key_hash_)
  : permanent_key_hash_(permanent_key_hash_)
  , key_hash_(key_hash_)
{}

const std::int32_t engine_validator_delValidatorTempKey::ID;

object_ptr<engine_validator_delValidatorTempKey> engine_validator_delValidatorTempKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_delValidatorTempKey>(p);
}

engine_validator_delValidatorTempKey::engine_validator_delValidatorTempKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : permanent_key_hash_(TlFetchInt256::parse(p))
  , key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_delValidatorTempKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1595481903);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorTempKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1595481903);
  TlStoreBinary::store(permanent_key_hash_, s);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_delValidatorTempKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_delValidatorTempKey");
    s.store_field("permanent_key_hash", permanent_key_hash_);
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_delValidatorTempKey::ReturnType engine_validator_delValidatorTempKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_exportPrivateKey::engine_validator_exportPrivateKey()
  : key_hash_()
{}

engine_validator_exportPrivateKey::engine_validator_exportPrivateKey(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_exportPrivateKey::ID;

object_ptr<engine_validator_exportPrivateKey> engine_validator_exportPrivateKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_exportPrivateKey>(p);
}

engine_validator_exportPrivateKey::engine_validator_exportPrivateKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_exportPrivateKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-864911288);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_exportPrivateKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-864911288);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_exportPrivateKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_exportPrivateKey");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_exportPrivateKey::ReturnType engine_validator_exportPrivateKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<PrivateKey>::parse(p);
#undef FAIL
}

engine_validator_exportPublicKey::engine_validator_exportPublicKey()
  : key_hash_()
{}

engine_validator_exportPublicKey::engine_validator_exportPublicKey(td::Bits256 const &key_hash_)
  : key_hash_(key_hash_)
{}

const std::int32_t engine_validator_exportPublicKey::ID;

object_ptr<engine_validator_exportPublicKey> engine_validator_exportPublicKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_exportPublicKey>(p);
}

engine_validator_exportPublicKey::engine_validator_exportPublicKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void engine_validator_exportPublicKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1647618233);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_exportPublicKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1647618233);
  TlStoreBinary::store(key_hash_, s);
}

void engine_validator_exportPublicKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_exportPublicKey");
    s.store_field("key_hash", key_hash_);
    s.store_class_end();
  }
}

engine_validator_exportPublicKey::ReturnType engine_validator_exportPublicKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<PublicKey>::parse(p);
#undef FAIL
}

engine_validator_generateKeyPair::engine_validator_generateKeyPair() {
}

const std::int32_t engine_validator_generateKeyPair::ID;

object_ptr<engine_validator_generateKeyPair> engine_validator_generateKeyPair::fetch(td::TlParser &p) {
  return make_object<engine_validator_generateKeyPair>(p);
}

engine_validator_generateKeyPair::engine_validator_generateKeyPair(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void engine_validator_generateKeyPair::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-349872005);
}

void engine_validator_generateKeyPair::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-349872005);
}

void engine_validator_generateKeyPair::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_generateKeyPair");
    s.store_class_end();
  }
}

engine_validator_generateKeyPair::ReturnType engine_validator_generateKeyPair::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_keyHash>, -1027168946>::parse(p);
#undef FAIL
}

engine_validator_getConfig::engine_validator_getConfig() {
}

const std::int32_t engine_validator_getConfig::ID;

object_ptr<engine_validator_getConfig> engine_validator_getConfig::fetch(td::TlParser &p) {
  return make_object<engine_validator_getConfig>(p);
}

engine_validator_getConfig::engine_validator_getConfig(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void engine_validator_getConfig::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1504518693);
}

void engine_validator_getConfig::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1504518693);
}

void engine_validator_getConfig::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_getConfig");
    s.store_class_end();
  }
}

engine_validator_getConfig::ReturnType engine_validator_getConfig::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_jsonConfig>, 321753611>::parse(p);
#undef FAIL
}

engine_validator_getStats::engine_validator_getStats() {
}

const std::int32_t engine_validator_getStats::ID;

object_ptr<engine_validator_getStats> engine_validator_getStats::fetch(td::TlParser &p) {
  return make_object<engine_validator_getStats>(p);
}

engine_validator_getStats::engine_validator_getStats(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void engine_validator_getStats::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1389740817);
}

void engine_validator_getStats::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1389740817);
}

void engine_validator_getStats::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_getStats");
    s.store_class_end();
  }
}

engine_validator_getStats::ReturnType engine_validator_getStats::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_stats>, 1565119343>::parse(p);
#undef FAIL
}

engine_validator_getTime::engine_validator_getTime() {
}

const std::int32_t engine_validator_getTime::ID;

object_ptr<engine_validator_getTime> engine_validator_getTime::fetch(td::TlParser &p) {
  return make_object<engine_validator_getTime>(p);
}

engine_validator_getTime::engine_validator_getTime(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void engine_validator_getTime::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-515850543);
}

void engine_validator_getTime::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-515850543);
}

void engine_validator_getTime::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_getTime");
    s.store_class_end();
  }
}

engine_validator_getTime::ReturnType engine_validator_getTime::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_time>, -547380738>::parse(p);
#undef FAIL
}

engine_validator_importPrivateKey::engine_validator_importPrivateKey()
  : key_()
{}

engine_validator_importPrivateKey::engine_validator_importPrivateKey(object_ptr<PrivateKey> &&key_)
  : key_(std::move(key_))
{}

const std::int32_t engine_validator_importPrivateKey::ID;

object_ptr<engine_validator_importPrivateKey> engine_validator_importPrivateKey::fetch(td::TlParser &p) {
  return make_object<engine_validator_importPrivateKey>(p);
}

engine_validator_importPrivateKey::engine_validator_importPrivateKey(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_(TlFetchObject<PrivateKey>::parse(p))
#undef FAIL
{}

void engine_validator_importPrivateKey::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(360741575);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
}

void engine_validator_importPrivateKey::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(360741575);
  TlStoreBoxedUnknown<TlStoreObject>::store(key_, s);
}

void engine_validator_importPrivateKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_importPrivateKey");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_class_end();
  }
}

engine_validator_importPrivateKey::ReturnType engine_validator_importPrivateKey::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_keyHash>, -1027168946>::parse(p);
#undef FAIL
}

engine_validator_setVerbosity::engine_validator_setVerbosity()
  : verbosity_()
{}

engine_validator_setVerbosity::engine_validator_setVerbosity(std::int32_t verbosity_)
  : verbosity_(verbosity_)
{}

const std::int32_t engine_validator_setVerbosity::ID;

object_ptr<engine_validator_setVerbosity> engine_validator_setVerbosity::fetch(td::TlParser &p) {
  return make_object<engine_validator_setVerbosity>(p);
}

engine_validator_setVerbosity::engine_validator_setVerbosity(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : verbosity_(TlFetchInt::parse(p))
#undef FAIL
{}

void engine_validator_setVerbosity::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1316856190);
  TlStoreBinary::store(verbosity_, s);
}

void engine_validator_setVerbosity::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1316856190);
  TlStoreBinary::store(verbosity_, s);
}

void engine_validator_setVerbosity::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_setVerbosity");
    s.store_field("verbosity", verbosity_);
    s.store_class_end();
  }
}

engine_validator_setVerbosity::ReturnType engine_validator_setVerbosity::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_success>, -1276860789>::parse(p);
#undef FAIL
}

engine_validator_sign::engine_validator_sign()
  : key_hash_()
  , data_()
{}

engine_validator_sign::engine_validator_sign(td::Bits256 const &key_hash_, td::BufferSlice &&data_)
  : key_hash_(key_hash_)
  , data_(std::move(data_))
{}

const std::int32_t engine_validator_sign::ID;

object_ptr<engine_validator_sign> engine_validator_sign::fetch(td::TlParser &p) {
  return make_object<engine_validator_sign>(p);
}

engine_validator_sign::engine_validator_sign(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : key_hash_(TlFetchInt256::parse(p))
  , data_(TlFetchBytes<td::BufferSlice>::parse(p))
#undef FAIL
{}

void engine_validator_sign::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(451549736);
  TlStoreBinary::store(key_hash_, s);
  TlStoreString::store(data_, s);
}

void engine_validator_sign::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(451549736);
  TlStoreBinary::store(key_hash_, s);
  TlStoreString::store(data_, s);
}

void engine_validator_sign::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "engine_validator_sign");
    s.store_field("key_hash", key_hash_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

engine_validator_sign::ReturnType engine_validator_sign::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<engine_validator_signature>, -76791000>::parse(p);
#undef FAIL
}

getTestObject::getTestObject() {
}

const std::int32_t getTestObject::ID;

object_ptr<getTestObject> getTestObject::fetch(td::TlParser &p) {
  return make_object<getTestObject>(p);
}

getTestObject::getTestObject(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void getTestObject::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(197109379);
}

void getTestObject::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(197109379);
}

void getTestObject::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getTestObject");
    s.store_class_end();
  }
}

getTestObject::ReturnType getTestObject::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<TestObject>::parse(p);
#undef FAIL
}

http_getNextPayloadPart::http_getNextPayloadPart()
  : id_()
  , seqno_()
  , max_chunk_size_()
{}

http_getNextPayloadPart::http_getNextPayloadPart(td::Bits256 const &id_, std::int32_t seqno_, std::int32_t max_chunk_size_)
  : id_(id_)
  , seqno_(seqno_)
  , max_chunk_size_(max_chunk_size_)
{}

const std::int32_t http_getNextPayloadPart::ID;

object_ptr<http_getNextPayloadPart> http_getNextPayloadPart::fetch(td::TlParser &p) {
  return make_object<http_getNextPayloadPart>(p);
}

http_getNextPayloadPart::http_getNextPayloadPart(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , seqno_(TlFetchInt::parse(p))
  , max_chunk_size_(TlFetchInt::parse(p))
#undef FAIL
{}

void http_getNextPayloadPart::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1871422196);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(max_chunk_size_, s);
}

void http_getNextPayloadPart::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1871422196);
  TlStoreBinary::store(id_, s);
  TlStoreBinary::store(seqno_, s);
  TlStoreBinary::store(max_chunk_size_, s);
}

void http_getNextPayloadPart::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_getNextPayloadPart");
    s.store_field("id", id_);
    s.store_field("seqno", seqno_);
    s.store_field("max_chunk_size", max_chunk_size_);
    s.store_class_end();
  }
}

http_getNextPayloadPart::ReturnType http_getNextPayloadPart::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<http_payloadPart>, 693819236>::parse(p);
#undef FAIL
}

http_request::http_request()
  : id_()
  , method_()
  , url_()
  , http_version_()
  , headers_()
{}

http_request::http_request(td::Bits256 const &id_, std::string const &method_, std::string const &url_, std::string const &http_version_, std::vector<object_ptr<http_header>> &&headers_)
  : id_(id_)
  , method_(std::move(method_))
  , url_(std::move(url_))
  , http_version_(std::move(http_version_))
  , headers_(std::move(headers_))
{}

const std::int32_t http_request::ID;

object_ptr<http_request> http_request::fetch(td::TlParser &p) {
  return make_object<http_request>(p);
}

http_request::http_request(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : id_(TlFetchInt256::parse(p))
  , method_(TlFetchString<std::string>::parse(p))
  , url_(TlFetchString<std::string>::parse(p))
  , http_version_(TlFetchString<std::string>::parse(p))
  , headers_(TlFetchVector<TlFetchObject<http_header>>::parse(p))
#undef FAIL
{}

void http_request::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1639027169);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(method_, s);
  TlStoreString::store(url_, s);
  TlStoreString::store(http_version_, s);
  TlStoreVector<TlStoreObject>::store(headers_, s);
}

void http_request::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1639027169);
  TlStoreBinary::store(id_, s);
  TlStoreString::store(method_, s);
  TlStoreString::store(url_, s);
  TlStoreString::store(http_version_, s);
  TlStoreVector<TlStoreObject>::store(headers_, s);
}

void http_request::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "http_request");
    s.store_field("id", id_);
    s.store_field("method", method_);
    s.store_field("url", url_);
    s.store_field("http_version", http_version_);
    { const std::vector<object_ptr<http_header>> &v = headers_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("headers", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

http_request::ReturnType http_request::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<http_response>, -273307789>::parse(p);
#undef FAIL
}

overlay_getBroadcast::overlay_getBroadcast()
  : hash_()
{}

overlay_getBroadcast::overlay_getBroadcast(td::Bits256 const &hash_)
  : hash_(hash_)
{}

const std::int32_t overlay_getBroadcast::ID;

object_ptr<overlay_getBroadcast> overlay_getBroadcast::fetch(td::TlParser &p) {
  return make_object<overlay_getBroadcast>(p);
}

overlay_getBroadcast::overlay_getBroadcast(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_getBroadcast::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(758510240);
  TlStoreBinary::store(hash_, s);
}

void overlay_getBroadcast::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(758510240);
  TlStoreBinary::store(hash_, s);
}

void overlay_getBroadcast::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_getBroadcast");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

overlay_getBroadcast::ReturnType overlay_getBroadcast::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<overlay_Broadcast>::parse(p);
#undef FAIL
}

overlay_getBroadcastList::overlay_getBroadcastList()
  : list_()
{}

overlay_getBroadcastList::overlay_getBroadcastList(object_ptr<overlay_broadcastList> &&list_)
  : list_(std::move(list_))
{}

const std::int32_t overlay_getBroadcastList::ID;

object_ptr<overlay_getBroadcastList> overlay_getBroadcastList::fetch(td::TlParser &p) {
  return make_object<overlay_getBroadcastList>(p);
}

overlay_getBroadcastList::overlay_getBroadcastList(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : list_(TlFetchObject<overlay_broadcastList>::parse(p))
#undef FAIL
{}

void overlay_getBroadcastList::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1109141562);
  TlStoreObject::store(list_, s);
}

void overlay_getBroadcastList::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1109141562);
  TlStoreObject::store(list_, s);
}

void overlay_getBroadcastList::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_getBroadcastList");
    if (list_ == nullptr) { s.store_field("list", "null"); } else { list_->store(s, "list"); }
    s.store_class_end();
  }
}

overlay_getBroadcastList::ReturnType overlay_getBroadcastList::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<overlay_broadcastList>, 416407263>::parse(p);
#undef FAIL
}

overlay_getRandomPeers::overlay_getRandomPeers()
  : peers_()
{}

overlay_getRandomPeers::overlay_getRandomPeers(object_ptr<overlay_nodes> &&peers_)
  : peers_(std::move(peers_))
{}

const std::int32_t overlay_getRandomPeers::ID;

object_ptr<overlay_getRandomPeers> overlay_getRandomPeers::fetch(td::TlParser &p) {
  return make_object<overlay_getRandomPeers>(p);
}

overlay_getRandomPeers::overlay_getRandomPeers(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : peers_(TlFetchObject<overlay_nodes>::parse(p))
#undef FAIL
{}

void overlay_getRandomPeers::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1223582891);
  TlStoreObject::store(peers_, s);
}

void overlay_getRandomPeers::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1223582891);
  TlStoreObject::store(peers_, s);
}

void overlay_getRandomPeers::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_getRandomPeers");
    if (peers_ == nullptr) { s.store_field("peers", "null"); } else { peers_->store(s, "peers"); }
    s.store_class_end();
  }
}

overlay_getRandomPeers::ReturnType overlay_getRandomPeers::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<overlay_nodes>, -460904178>::parse(p);
#undef FAIL
}

overlay_query::overlay_query()
  : overlay_()
{}

overlay_query::overlay_query(td::Bits256 const &overlay_)
  : overlay_(overlay_)
{}

const std::int32_t overlay_query::ID;

object_ptr<overlay_query> overlay_query::fetch(td::TlParser &p) {
  return make_object<overlay_query>(p);
}

overlay_query::overlay_query(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : overlay_(TlFetchInt256::parse(p))
#undef FAIL
{}

void overlay_query::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-855800765);
  TlStoreBinary::store(overlay_, s);
}

void overlay_query::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-855800765);
  TlStoreBinary::store(overlay_, s);
}

void overlay_query::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "overlay_query");
    s.store_field("overlay", overlay_);
    s.store_class_end();
  }
}

overlay_query::ReturnType overlay_query::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchTrue, 1072550713>::parse(p);
#undef FAIL
}

tcp_ping::tcp_ping()
  : random_id_()
{}

tcp_ping::tcp_ping(std::int64_t random_id_)
  : random_id_(random_id_)
{}

const std::int32_t tcp_ping::ID;

object_ptr<tcp_ping> tcp_ping::fetch(td::TlParser &p) {
  return make_object<tcp_ping>(p);
}

tcp_ping::tcp_ping(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : random_id_(TlFetchLong::parse(p))
#undef FAIL
{}

void tcp_ping::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1292381082);
  TlStoreBinary::store(random_id_, s);
}

void tcp_ping::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1292381082);
  TlStoreBinary::store(random_id_, s);
}

void tcp_ping::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tcp_ping");
    s.store_field("random_id", random_id_);
    s.store_class_end();
  }
}

tcp_ping::ReturnType tcp_ping::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tcp_pong>, -597034237>::parse(p);
#undef FAIL
}

tonNode_downloadBlock::tonNode_downloadBlock()
  : block_()
{}

tonNode_downloadBlock::tonNode_downloadBlock(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadBlock::ID;

object_ptr<tonNode_downloadBlock> tonNode_downloadBlock::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlock>(p);
}

tonNode_downloadBlock::tonNode_downloadBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-495814205);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-495814205);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlock");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadBlock::ReturnType tonNode_downloadBlock::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadBlockFull::tonNode_downloadBlockFull()
  : block_()
{}

tonNode_downloadBlockFull::tonNode_downloadBlockFull(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadBlockFull::ID;

object_ptr<tonNode_downloadBlockFull> tonNode_downloadBlockFull::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlockFull>(p);
}

tonNode_downloadBlockFull::tonNode_downloadBlockFull(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlockFull::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1780991133);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockFull::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1780991133);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockFull::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlockFull");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadBlockFull::ReturnType tonNode_downloadBlockFull::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_DataFull>::parse(p);
#undef FAIL
}

tonNode_downloadBlockProof::tonNode_downloadBlockProof()
  : block_()
{}

tonNode_downloadBlockProof::tonNode_downloadBlockProof(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadBlockProof::ID;

object_ptr<tonNode_downloadBlockProof> tonNode_downloadBlockProof::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlockProof>(p);
}

tonNode_downloadBlockProof::tonNode_downloadBlockProof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlockProof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1272334218);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockProof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1272334218);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockProof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlockProof");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadBlockProof::ReturnType tonNode_downloadBlockProof::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadBlockProofLink::tonNode_downloadBlockProofLink()
  : block_()
{}

tonNode_downloadBlockProofLink::tonNode_downloadBlockProofLink(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadBlockProofLink::ID;

object_ptr<tonNode_downloadBlockProofLink> tonNode_downloadBlockProofLink::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlockProofLink>(p);
}

tonNode_downloadBlockProofLink::tonNode_downloadBlockProofLink(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlockProofLink::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(632488134);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockProofLink::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(632488134);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadBlockProofLink::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlockProofLink");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadBlockProofLink::ReturnType tonNode_downloadBlockProofLink::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadBlockProofLinks::tonNode_downloadBlockProofLinks()
  : blocks_()
{}

tonNode_downloadBlockProofLinks::tonNode_downloadBlockProofLinks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_downloadBlockProofLinks::ID;

object_ptr<tonNode_downloadBlockProofLinks> tonNode_downloadBlockProofLinks::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlockProofLinks>(p);
}

tonNode_downloadBlockProofLinks::tonNode_downloadBlockProofLinks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlockProofLinks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(684796771);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlockProofLinks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(684796771);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlockProofLinks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlockProofLinks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_downloadBlockProofLinks::ReturnType tonNode_downloadBlockProofLinks::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_dataList>, 351548179>::parse(p);
#undef FAIL
}

tonNode_downloadBlockProofs::tonNode_downloadBlockProofs()
  : blocks_()
{}

tonNode_downloadBlockProofs::tonNode_downloadBlockProofs(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_downloadBlockProofs::ID;

object_ptr<tonNode_downloadBlockProofs> tonNode_downloadBlockProofs::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlockProofs>(p);
}

tonNode_downloadBlockProofs::tonNode_downloadBlockProofs(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlockProofs::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1515170827);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlockProofs::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1515170827);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlockProofs::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlockProofs");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_downloadBlockProofs::ReturnType tonNode_downloadBlockProofs::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_dataList>, 351548179>::parse(p);
#undef FAIL
}

tonNode_downloadBlocks::tonNode_downloadBlocks()
  : blocks_()
{}

tonNode_downloadBlocks::tonNode_downloadBlocks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_downloadBlocks::ID;

object_ptr<tonNode_downloadBlocks> tonNode_downloadBlocks::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadBlocks>(p);
}

tonNode_downloadBlocks::tonNode_downloadBlocks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_downloadBlocks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1985594749);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlocks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1985594749);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadBlocks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadBlocks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_downloadBlocks::ReturnType tonNode_downloadBlocks::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_dataList>, 351548179>::parse(p);
#undef FAIL
}

tonNode_downloadKeyBlockProof::tonNode_downloadKeyBlockProof()
  : block_()
{}

tonNode_downloadKeyBlockProof::tonNode_downloadKeyBlockProof(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadKeyBlockProof::ID;

object_ptr<tonNode_downloadKeyBlockProof> tonNode_downloadKeyBlockProof::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadKeyBlockProof>(p);
}

tonNode_downloadKeyBlockProof::tonNode_downloadKeyBlockProof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadKeyBlockProof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-333232070);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadKeyBlockProof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-333232070);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadKeyBlockProof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadKeyBlockProof");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadKeyBlockProof::ReturnType tonNode_downloadKeyBlockProof::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadKeyBlockProofLink::tonNode_downloadKeyBlockProofLink()
  : block_()
{}

tonNode_downloadKeyBlockProofLink::tonNode_downloadKeyBlockProofLink(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadKeyBlockProofLink::ID;

object_ptr<tonNode_downloadKeyBlockProofLink> tonNode_downloadKeyBlockProofLink::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadKeyBlockProofLink>(p);
}

tonNode_downloadKeyBlockProofLink::tonNode_downloadKeyBlockProofLink(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadKeyBlockProofLink::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(316943058);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadKeyBlockProofLink::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(316943058);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadKeyBlockProofLink::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadKeyBlockProofLink");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadKeyBlockProofLink::ReturnType tonNode_downloadKeyBlockProofLink::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadKeyBlockProofLinks::tonNode_downloadKeyBlockProofLinks()
  : blocks_()
{}

tonNode_downloadKeyBlockProofLinks::tonNode_downloadKeyBlockProofLinks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_downloadKeyBlockProofLinks::ID;

object_ptr<tonNode_downloadKeyBlockProofLinks> tonNode_downloadKeyBlockProofLinks::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadKeyBlockProofLinks>(p);
}

tonNode_downloadKeyBlockProofLinks::tonNode_downloadKeyBlockProofLinks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_downloadKeyBlockProofLinks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1975747920);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadKeyBlockProofLinks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1975747920);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadKeyBlockProofLinks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadKeyBlockProofLinks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_downloadKeyBlockProofLinks::ReturnType tonNode_downloadKeyBlockProofLinks::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_dataList>, 351548179>::parse(p);
#undef FAIL
}

tonNode_downloadKeyBlockProofs::tonNode_downloadKeyBlockProofs()
  : blocks_()
{}

tonNode_downloadKeyBlockProofs::tonNode_downloadKeyBlockProofs(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_downloadKeyBlockProofs::ID;

object_ptr<tonNode_downloadKeyBlockProofs> tonNode_downloadKeyBlockProofs::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadKeyBlockProofs>(p);
}

tonNode_downloadKeyBlockProofs::tonNode_downloadKeyBlockProofs(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_downloadKeyBlockProofs::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1020797382);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadKeyBlockProofs::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1020797382);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_downloadKeyBlockProofs::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadKeyBlockProofs");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_downloadKeyBlockProofs::ReturnType tonNode_downloadKeyBlockProofs::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_dataList>, 351548179>::parse(p);
#undef FAIL
}

tonNode_downloadNextBlockFull::tonNode_downloadNextBlockFull()
  : prev_block_()
{}

tonNode_downloadNextBlockFull::tonNode_downloadNextBlockFull(object_ptr<tonNode_blockIdExt> &&prev_block_)
  : prev_block_(std::move(prev_block_))
{}

const std::int32_t tonNode_downloadNextBlockFull::ID;

object_ptr<tonNode_downloadNextBlockFull> tonNode_downloadNextBlockFull::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadNextBlockFull>(p);
}

tonNode_downloadNextBlockFull::tonNode_downloadNextBlockFull(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : prev_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadNextBlockFull::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1855993674);
  TlStoreObject::store(prev_block_, s);
}

void tonNode_downloadNextBlockFull::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1855993674);
  TlStoreObject::store(prev_block_, s);
}

void tonNode_downloadNextBlockFull::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadNextBlockFull");
    if (prev_block_ == nullptr) { s.store_field("prev_block", "null"); } else { prev_block_->store(s, "prev_block"); }
    s.store_class_end();
  }
}

tonNode_downloadNextBlockFull::ReturnType tonNode_downloadNextBlockFull::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_DataFull>::parse(p);
#undef FAIL
}

tonNode_downloadPersistentState::tonNode_downloadPersistentState()
  : block_()
  , masterchain_block_()
{}

tonNode_downloadPersistentState::tonNode_downloadPersistentState(object_ptr<tonNode_blockIdExt> &&block_, object_ptr<tonNode_blockIdExt> &&masterchain_block_)
  : block_(std::move(block_))
  , masterchain_block_(std::move(masterchain_block_))
{}

const std::int32_t tonNode_downloadPersistentState::ID;

object_ptr<tonNode_downloadPersistentState> tonNode_downloadPersistentState::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadPersistentState>(p);
}

tonNode_downloadPersistentState::tonNode_downloadPersistentState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , masterchain_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadPersistentState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(2140791736);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
}

void tonNode_downloadPersistentState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(2140791736);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
}

void tonNode_downloadPersistentState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadPersistentState");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    if (masterchain_block_ == nullptr) { s.store_field("masterchain_block", "null"); } else { masterchain_block_->store(s, "masterchain_block"); }
    s.store_class_end();
  }
}

tonNode_downloadPersistentState::ReturnType tonNode_downloadPersistentState::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadPersistentStateSlice::tonNode_downloadPersistentStateSlice()
  : block_()
  , masterchain_block_()
  , offset_()
  , max_size_()
{}

tonNode_downloadPersistentStateSlice::tonNode_downloadPersistentStateSlice(object_ptr<tonNode_blockIdExt> &&block_, object_ptr<tonNode_blockIdExt> &&masterchain_block_, std::int64_t offset_, std::int64_t max_size_)
  : block_(std::move(block_))
  , masterchain_block_(std::move(masterchain_block_))
  , offset_(offset_)
  , max_size_(max_size_)
{}

const std::int32_t tonNode_downloadPersistentStateSlice::ID;

object_ptr<tonNode_downloadPersistentStateSlice> tonNode_downloadPersistentStateSlice::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadPersistentStateSlice>(p);
}

tonNode_downloadPersistentStateSlice::tonNode_downloadPersistentStateSlice(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , masterchain_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , offset_(TlFetchLong::parse(p))
  , max_size_(TlFetchLong::parse(p))
#undef FAIL
{}

void tonNode_downloadPersistentStateSlice::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-169220381);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_downloadPersistentStateSlice::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-169220381);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_downloadPersistentStateSlice::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadPersistentStateSlice");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    if (masterchain_block_ == nullptr) { s.store_field("masterchain_block", "null"); } else { masterchain_block_->store(s, "masterchain_block"); }
    s.store_field("offset", offset_);
    s.store_field("max_size", max_size_);
    s.store_class_end();
  }
}

tonNode_downloadPersistentStateSlice::ReturnType tonNode_downloadPersistentStateSlice::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_downloadZeroState::tonNode_downloadZeroState()
  : block_()
{}

tonNode_downloadZeroState::tonNode_downloadZeroState(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_downloadZeroState::ID;

object_ptr<tonNode_downloadZeroState> tonNode_downloadZeroState::fetch(td::TlParser &p) {
  return make_object<tonNode_downloadZeroState>(p);
}

tonNode_downloadZeroState::tonNode_downloadZeroState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_downloadZeroState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1379131814);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadZeroState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1379131814);
  TlStoreObject::store(block_, s);
}

void tonNode_downloadZeroState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_downloadZeroState");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_downloadZeroState::ReturnType tonNode_downloadZeroState::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_getArchiveInfo::tonNode_getArchiveInfo()
  : masterchain_seqno_()
{}

tonNode_getArchiveInfo::tonNode_getArchiveInfo(std::int32_t masterchain_seqno_)
  : masterchain_seqno_(masterchain_seqno_)
{}

const std::int32_t tonNode_getArchiveInfo::ID;

object_ptr<tonNode_getArchiveInfo> tonNode_getArchiveInfo::fetch(td::TlParser &p) {
  return make_object<tonNode_getArchiveInfo>(p);
}

tonNode_getArchiveInfo::tonNode_getArchiveInfo(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : masterchain_seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_getArchiveInfo::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(2066602305);
  TlStoreBinary::store(masterchain_seqno_, s);
}

void tonNode_getArchiveInfo::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(2066602305);
  TlStoreBinary::store(masterchain_seqno_, s);
}

void tonNode_getArchiveInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getArchiveInfo");
    s.store_field("masterchain_seqno", masterchain_seqno_);
    s.store_class_end();
  }
}

tonNode_getArchiveInfo::ReturnType tonNode_getArchiveInfo::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_ArchiveInfo>::parse(p);
#undef FAIL
}

tonNode_getArchiveSlice::tonNode_getArchiveSlice()
  : archive_id_()
  , offset_()
  , max_size_()
{}

tonNode_getArchiveSlice::tonNode_getArchiveSlice(std::int64_t archive_id_, std::int64_t offset_, std::int32_t max_size_)
  : archive_id_(archive_id_)
  , offset_(offset_)
  , max_size_(max_size_)
{}

const std::int32_t tonNode_getArchiveSlice::ID;

object_ptr<tonNode_getArchiveSlice> tonNode_getArchiveSlice::fetch(td::TlParser &p) {
  return make_object<tonNode_getArchiveSlice>(p);
}

tonNode_getArchiveSlice::tonNode_getArchiveSlice(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : archive_id_(TlFetchLong::parse(p))
  , offset_(TlFetchLong::parse(p))
  , max_size_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_getArchiveSlice::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(540758376);
  TlStoreBinary::store(archive_id_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_getArchiveSlice::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(540758376);
  TlStoreBinary::store(archive_id_, s);
  TlStoreBinary::store(offset_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_getArchiveSlice::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getArchiveSlice");
    s.store_field("archive_id", archive_id_);
    s.store_field("offset", offset_);
    s.store_field("max_size", max_size_);
    s.store_class_end();
  }
}

tonNode_getArchiveSlice::ReturnType tonNode_getArchiveSlice::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_data>, 1443505284>::parse(p);
#undef FAIL
}

tonNode_getCapabilities::tonNode_getCapabilities() {
}

const std::int32_t tonNode_getCapabilities::ID;

object_ptr<tonNode_getCapabilities> tonNode_getCapabilities::fetch(td::TlParser &p) {
  return make_object<tonNode_getCapabilities>(p);
}

tonNode_getCapabilities::tonNode_getCapabilities(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_getCapabilities::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-555345672);
}

void tonNode_getCapabilities::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-555345672);
}

void tonNode_getCapabilities::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getCapabilities");
    s.store_class_end();
  }
}

tonNode_getCapabilities::ReturnType tonNode_getCapabilities::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_capabilities>, -172007232>::parse(p);
#undef FAIL
}

tonNode_getNextBlockDescription::tonNode_getNextBlockDescription()
  : prev_block_()
{}

tonNode_getNextBlockDescription::tonNode_getNextBlockDescription(object_ptr<tonNode_blockIdExt> &&prev_block_)
  : prev_block_(std::move(prev_block_))
{}

const std::int32_t tonNode_getNextBlockDescription::ID;

object_ptr<tonNode_getNextBlockDescription> tonNode_getNextBlockDescription::fetch(td::TlParser &p) {
  return make_object<tonNode_getNextBlockDescription>(p);
}

tonNode_getNextBlockDescription::tonNode_getNextBlockDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : prev_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_getNextBlockDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(341160179);
  TlStoreObject::store(prev_block_, s);
}

void tonNode_getNextBlockDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(341160179);
  TlStoreObject::store(prev_block_, s);
}

void tonNode_getNextBlockDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getNextBlockDescription");
    if (prev_block_ == nullptr) { s.store_field("prev_block", "null"); } else { prev_block_->store(s, "prev_block"); }
    s.store_class_end();
  }
}

tonNode_getNextBlockDescription::ReturnType tonNode_getNextBlockDescription::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_BlockDescription>::parse(p);
#undef FAIL
}

tonNode_getNextBlocksDescription::tonNode_getNextBlocksDescription()
  : prev_block_()
  , limit_()
{}

tonNode_getNextBlocksDescription::tonNode_getNextBlocksDescription(object_ptr<tonNode_blockIdExt> &&prev_block_, std::int32_t limit_)
  : prev_block_(std::move(prev_block_))
  , limit_(limit_)
{}

const std::int32_t tonNode_getNextBlocksDescription::ID;

object_ptr<tonNode_getNextBlocksDescription> tonNode_getNextBlocksDescription::fetch(td::TlParser &p) {
  return make_object<tonNode_getNextBlocksDescription>(p);
}

tonNode_getNextBlocksDescription::tonNode_getNextBlocksDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : prev_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , limit_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_getNextBlocksDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1059590852);
  TlStoreObject::store(prev_block_, s);
  TlStoreBinary::store(limit_, s);
}

void tonNode_getNextBlocksDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1059590852);
  TlStoreObject::store(prev_block_, s);
  TlStoreBinary::store(limit_, s);
}

void tonNode_getNextBlocksDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getNextBlocksDescription");
    if (prev_block_ == nullptr) { s.store_field("prev_block", "null"); } else { prev_block_->store(s, "prev_block"); }
    s.store_field("limit", limit_);
    s.store_class_end();
  }
}

tonNode_getNextBlocksDescription::ReturnType tonNode_getNextBlocksDescription::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_blocksDescription>, -701865684>::parse(p);
#undef FAIL
}

tonNode_getNextKeyBlockIds::tonNode_getNextKeyBlockIds()
  : block_()
  , max_size_()
{}

tonNode_getNextKeyBlockIds::tonNode_getNextKeyBlockIds(object_ptr<tonNode_blockIdExt> &&block_, std::int32_t max_size_)
  : block_(std::move(block_))
  , max_size_(max_size_)
{}

const std::int32_t tonNode_getNextKeyBlockIds::ID;

object_ptr<tonNode_getNextKeyBlockIds> tonNode_getNextKeyBlockIds::fetch(td::TlParser &p) {
  return make_object<tonNode_getNextKeyBlockIds>(p);
}

tonNode_getNextKeyBlockIds::tonNode_getNextKeyBlockIds(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , max_size_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_getNextKeyBlockIds::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-219689029);
  TlStoreObject::store(block_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_getNextKeyBlockIds::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-219689029);
  TlStoreObject::store(block_, s);
  TlStoreBinary::store(max_size_, s);
}

void tonNode_getNextKeyBlockIds::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getNextKeyBlockIds");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_field("max_size", max_size_);
    s.store_class_end();
  }
}

tonNode_getNextKeyBlockIds::ReturnType tonNode_getNextKeyBlockIds::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_keyBlocks>, 124144985>::parse(p);
#undef FAIL
}

tonNode_getPrevBlocksDescription::tonNode_getPrevBlocksDescription()
  : next_block_()
  , limit_()
  , cutoff_seqno_()
{}

tonNode_getPrevBlocksDescription::tonNode_getPrevBlocksDescription(object_ptr<tonNode_blockIdExt> &&next_block_, std::int32_t limit_, std::int32_t cutoff_seqno_)
  : next_block_(std::move(next_block_))
  , limit_(limit_)
  , cutoff_seqno_(cutoff_seqno_)
{}

const std::int32_t tonNode_getPrevBlocksDescription::ID;

object_ptr<tonNode_getPrevBlocksDescription> tonNode_getPrevBlocksDescription::fetch(td::TlParser &p) {
  return make_object<tonNode_getPrevBlocksDescription>(p);
}

tonNode_getPrevBlocksDescription::tonNode_getPrevBlocksDescription(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : next_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , limit_(TlFetchInt::parse(p))
  , cutoff_seqno_(TlFetchInt::parse(p))
#undef FAIL
{}

void tonNode_getPrevBlocksDescription::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1550675145);
  TlStoreObject::store(next_block_, s);
  TlStoreBinary::store(limit_, s);
  TlStoreBinary::store(cutoff_seqno_, s);
}

void tonNode_getPrevBlocksDescription::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1550675145);
  TlStoreObject::store(next_block_, s);
  TlStoreBinary::store(limit_, s);
  TlStoreBinary::store(cutoff_seqno_, s);
}

void tonNode_getPrevBlocksDescription::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_getPrevBlocksDescription");
    if (next_block_ == nullptr) { s.store_field("next_block", "null"); } else { next_block_->store(s, "next_block"); }
    s.store_field("limit", limit_);
    s.store_field("cutoff_seqno", cutoff_seqno_);
    s.store_class_end();
  }
}

tonNode_getPrevBlocksDescription::ReturnType tonNode_getPrevBlocksDescription::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_blocksDescription>, -701865684>::parse(p);
#undef FAIL
}

tonNode_prepareBlock::tonNode_prepareBlock()
  : block_()
{}

tonNode_prepareBlock::tonNode_prepareBlock(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_prepareBlock::ID;

object_ptr<tonNode_prepareBlock> tonNode_prepareBlock::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareBlock>(p);
}

tonNode_prepareBlock::tonNode_prepareBlock(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_prepareBlock::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1973649230);
  TlStoreObject::store(block_, s);
}

void tonNode_prepareBlock::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1973649230);
  TlStoreObject::store(block_, s);
}

void tonNode_prepareBlock::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareBlock");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_prepareBlock::ReturnType tonNode_prepareBlock::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_Prepared>::parse(p);
#undef FAIL
}

tonNode_prepareBlockProof::tonNode_prepareBlockProof()
  : block_()
  , allow_partial_()
{}

tonNode_prepareBlockProof::tonNode_prepareBlockProof(object_ptr<tonNode_blockIdExt> &&block_, bool allow_partial_)
  : block_(std::move(block_))
  , allow_partial_(allow_partial_)
{}

const std::int32_t tonNode_prepareBlockProof::ID;

object_ptr<tonNode_prepareBlockProof> tonNode_prepareBlockProof::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareBlockProof>(p);
}

tonNode_prepareBlockProof::tonNode_prepareBlockProof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , allow_partial_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_prepareBlockProof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-2024000760);
  TlStoreObject::store(block_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareBlockProof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-2024000760);
  TlStoreObject::store(block_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareBlockProof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareBlockProof");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_field("allow_partial", allow_partial_);
    s.store_class_end();
  }
}

tonNode_prepareBlockProof::ReturnType tonNode_prepareBlockProof::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedProof>::parse(p);
#undef FAIL
}

tonNode_prepareBlockProofs::tonNode_prepareBlockProofs()
  : blocks_()
  , allow_partial_()
{}

tonNode_prepareBlockProofs::tonNode_prepareBlockProofs(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_, bool allow_partial_)
  : blocks_(std::move(blocks_))
  , allow_partial_(allow_partial_)
{}

const std::int32_t tonNode_prepareBlockProofs::ID;

object_ptr<tonNode_prepareBlockProofs> tonNode_prepareBlockProofs::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareBlockProofs>(p);
}

tonNode_prepareBlockProofs::tonNode_prepareBlockProofs(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
  , allow_partial_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_prepareBlockProofs::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-310791496);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareBlockProofs::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-310791496);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareBlockProofs::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareBlockProofs");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("allow_partial", allow_partial_);
    s.store_class_end();
  }
}

tonNode_prepareBlockProofs::ReturnType tonNode_prepareBlockProofs::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedProof>::parse(p);
#undef FAIL
}

tonNode_prepareBlocks::tonNode_prepareBlocks()
  : blocks_()
{}

tonNode_prepareBlocks::tonNode_prepareBlocks(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_)
  : blocks_(std::move(blocks_))
{}

const std::int32_t tonNode_prepareBlocks::ID;

object_ptr<tonNode_prepareBlocks> tonNode_prepareBlocks::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareBlocks>(p);
}

tonNode_prepareBlocks::tonNode_prepareBlocks(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
#undef FAIL
{}

void tonNode_prepareBlocks::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1795140604);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_prepareBlocks::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1795140604);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
}

void tonNode_prepareBlocks::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareBlocks");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

tonNode_prepareBlocks::ReturnType tonNode_prepareBlocks::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_Prepared>::parse(p);
#undef FAIL
}

tonNode_prepareKeyBlockProof::tonNode_prepareKeyBlockProof()
  : block_()
  , allow_partial_()
{}

tonNode_prepareKeyBlockProof::tonNode_prepareKeyBlockProof(object_ptr<tonNode_blockIdExt> &&block_, bool allow_partial_)
  : block_(std::move(block_))
  , allow_partial_(allow_partial_)
{}

const std::int32_t tonNode_prepareKeyBlockProof::ID;

object_ptr<tonNode_prepareKeyBlockProof> tonNode_prepareKeyBlockProof::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareKeyBlockProof>(p);
}

tonNode_prepareKeyBlockProof::tonNode_prepareKeyBlockProof(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , allow_partial_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_prepareKeyBlockProof::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(2000047160);
  TlStoreObject::store(block_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareKeyBlockProof::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(2000047160);
  TlStoreObject::store(block_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareKeyBlockProof::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareKeyBlockProof");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_field("allow_partial", allow_partial_);
    s.store_class_end();
  }
}

tonNode_prepareKeyBlockProof::ReturnType tonNode_prepareKeyBlockProof::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedProof>::parse(p);
#undef FAIL
}

tonNode_prepareKeyBlockProofs::tonNode_prepareKeyBlockProofs()
  : blocks_()
  , allow_partial_()
{}

tonNode_prepareKeyBlockProofs::tonNode_prepareKeyBlockProofs(std::vector<object_ptr<tonNode_blockIdExt>> &&blocks_, bool allow_partial_)
  : blocks_(std::move(blocks_))
  , allow_partial_(allow_partial_)
{}

const std::int32_t tonNode_prepareKeyBlockProofs::ID;

object_ptr<tonNode_prepareKeyBlockProofs> tonNode_prepareKeyBlockProofs::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareKeyBlockProofs>(p);
}

tonNode_prepareKeyBlockProofs::tonNode_prepareKeyBlockProofs(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : blocks_(TlFetchVector<TlFetchObject<tonNode_blockIdExt>>::parse(p))
  , allow_partial_(TlFetchBool::parse(p))
#undef FAIL
{}

void tonNode_prepareKeyBlockProofs::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-1939014684);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareKeyBlockProofs::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-1939014684);
  TlStoreVector<TlStoreObject>::store(blocks_, s);
  TlStoreBool::store(allow_partial_, s);
}

void tonNode_prepareKeyBlockProofs::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareKeyBlockProofs");
    { const std::vector<object_ptr<tonNode_blockIdExt>> &v = blocks_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("blocks", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("allow_partial", allow_partial_);
    s.store_class_end();
  }
}

tonNode_prepareKeyBlockProofs::ReturnType tonNode_prepareKeyBlockProofs::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedProof>::parse(p);
#undef FAIL
}

tonNode_preparePersistentState::tonNode_preparePersistentState()
  : block_()
  , masterchain_block_()
{}

tonNode_preparePersistentState::tonNode_preparePersistentState(object_ptr<tonNode_blockIdExt> &&block_, object_ptr<tonNode_blockIdExt> &&masterchain_block_)
  : block_(std::move(block_))
  , masterchain_block_(std::move(masterchain_block_))
{}

const std::int32_t tonNode_preparePersistentState::ID;

object_ptr<tonNode_preparePersistentState> tonNode_preparePersistentState::fetch(td::TlParser &p) {
  return make_object<tonNode_preparePersistentState>(p);
}

tonNode_preparePersistentState::tonNode_preparePersistentState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
  , masterchain_block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_preparePersistentState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-18209122);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
}

void tonNode_preparePersistentState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-18209122);
  TlStoreObject::store(block_, s);
  TlStoreObject::store(masterchain_block_, s);
}

void tonNode_preparePersistentState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_preparePersistentState");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    if (masterchain_block_ == nullptr) { s.store_field("masterchain_block", "null"); } else { masterchain_block_->store(s, "masterchain_block"); }
    s.store_class_end();
  }
}

tonNode_preparePersistentState::ReturnType tonNode_preparePersistentState::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedState>::parse(p);
#undef FAIL
}

tonNode_prepareZeroState::tonNode_prepareZeroState()
  : block_()
{}

tonNode_prepareZeroState::tonNode_prepareZeroState(object_ptr<tonNode_blockIdExt> &&block_)
  : block_(std::move(block_))
{}

const std::int32_t tonNode_prepareZeroState::ID;

object_ptr<tonNode_prepareZeroState> tonNode_prepareZeroState::fetch(td::TlParser &p) {
  return make_object<tonNode_prepareZeroState>(p);
}

tonNode_prepareZeroState::tonNode_prepareZeroState(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : block_(TlFetchObject<tonNode_blockIdExt>::parse(p))
#undef FAIL
{}

void tonNode_prepareZeroState::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1104021541);
  TlStoreObject::store(block_, s);
}

void tonNode_prepareZeroState::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1104021541);
  TlStoreObject::store(block_, s);
}

void tonNode_prepareZeroState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_prepareZeroState");
    if (block_ == nullptr) { s.store_field("block", "null"); } else { block_->store(s, "block"); }
    s.store_class_end();
  }
}

tonNode_prepareZeroState::ReturnType tonNode_prepareZeroState::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchObject<tonNode_PreparedState>::parse(p);
#undef FAIL
}

tonNode_query::tonNode_query() {
}

const std::int32_t tonNode_query::ID;

object_ptr<tonNode_query> tonNode_query::fetch(td::TlParser &p) {
  return make_object<tonNode_query>(p);
}

tonNode_query::tonNode_query(td::TlParser &p)
#define FAIL(error) p.set_error(error)
#undef FAIL
{
  (void)p;
}

void tonNode_query::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1777542355);
}

void tonNode_query::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1777542355);
}

void tonNode_query::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_query");
    s.store_class_end();
  }
}

tonNode_query::ReturnType tonNode_query::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<Object>, 695225504>::parse(p);
#undef FAIL
}

tonNode_slave_sendExtMessage::tonNode_slave_sendExtMessage()
  : message_()
{}

tonNode_slave_sendExtMessage::tonNode_slave_sendExtMessage(object_ptr<tonNode_externalMessage> &&message_)
  : message_(std::move(message_))
{}

const std::int32_t tonNode_slave_sendExtMessage::ID;

object_ptr<tonNode_slave_sendExtMessage> tonNode_slave_sendExtMessage::fetch(td::TlParser &p) {
  return make_object<tonNode_slave_sendExtMessage>(p);
}

tonNode_slave_sendExtMessage::tonNode_slave_sendExtMessage(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : message_(TlFetchObject<tonNode_externalMessage>::parse(p))
#undef FAIL
{}

void tonNode_slave_sendExtMessage::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(58127017);
  TlStoreObject::store(message_, s);
}

void tonNode_slave_sendExtMessage::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(58127017);
  TlStoreObject::store(message_, s);
}

void tonNode_slave_sendExtMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tonNode_slave_sendExtMessage");
    if (message_ == nullptr) { s.store_field("message", "null"); } else { message_->store(s, "message"); }
    s.store_class_end();
  }
}

tonNode_slave_sendExtMessage::ReturnType tonNode_slave_sendExtMessage::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<tonNode_success>, -1063902129>::parse(p);
#undef FAIL
}

validatorSession_downloadCandidate::validatorSession_downloadCandidate()
  : round_()
  , id_()
{}

validatorSession_downloadCandidate::validatorSession_downloadCandidate(std::int32_t round_, object_ptr<validatorSession_candidateId> &&id_)
  : round_(round_)
  , id_(std::move(id_))
{}

const std::int32_t validatorSession_downloadCandidate::ID;

object_ptr<validatorSession_downloadCandidate> validatorSession_downloadCandidate::fetch(td::TlParser &p) {
  return make_object<validatorSession_downloadCandidate>(p);
}

validatorSession_downloadCandidate::validatorSession_downloadCandidate(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : round_(TlFetchInt::parse(p))
  , id_(TlFetchObject<validatorSession_candidateId>::parse(p))
#undef FAIL
{}

void validatorSession_downloadCandidate::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(-520274443);
  TlStoreBinary::store(round_, s);
  TlStoreObject::store(id_, s);
}

void validatorSession_downloadCandidate::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(-520274443);
  TlStoreBinary::store(round_, s);
  TlStoreObject::store(id_, s);
}

void validatorSession_downloadCandidate::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_downloadCandidate");
    s.store_field("round", round_);
    if (id_ == nullptr) { s.store_field("id", "null"); } else { id_->store(s, "id"); }
    s.store_class_end();
  }
}

validatorSession_downloadCandidate::ReturnType validatorSession_downloadCandidate::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<validatorSession_candidate>, 2100525125>::parse(p);
#undef FAIL
}

validatorSession_ping::validatorSession_ping()
  : hash_()
{}

validatorSession_ping::validatorSession_ping(std::int64_t hash_)
  : hash_(hash_)
{}

const std::int32_t validatorSession_ping::ID;

object_ptr<validatorSession_ping> validatorSession_ping::fetch(td::TlParser &p) {
  return make_object<validatorSession_ping>(p);
}

validatorSession_ping::validatorSession_ping(td::TlParser &p)
#define FAIL(error) p.set_error(error)
  : hash_(TlFetchLong::parse(p))
#undef FAIL
{}

void validatorSession_ping::store(td::TlStorerCalcLength &s) const {
  (void)sizeof(s);
  s.store_binary(1745111469);
  TlStoreBinary::store(hash_, s);
}

void validatorSession_ping::store(td::TlStorerUnsafe &s) const {
  (void)sizeof(s);
  s.store_binary(1745111469);
  TlStoreBinary::store(hash_, s);
}

void validatorSession_ping::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "validatorSession_ping");
    s.store_field("hash", hash_);
    s.store_class_end();
  }
}

validatorSession_ping::ReturnType validatorSession_ping::fetch_result(td::TlParser &p) {
#define FAIL(error) p.set_error(error); return ReturnType()
  return TlFetchBoxed<TlFetchObject<validatorSession_pong>, -590989459>::parse(p);
#undef FAIL
}
}  // namespace ton_api
}  // namespace ton
