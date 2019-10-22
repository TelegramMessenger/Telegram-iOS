#include "auto/tl/ton_api_json.h"

#include "auto/tl/ton_api.h"
#include "auto/tl/ton_api.hpp"

#include "tl/tl_json.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <unordered_map>

namespace ton {
namespace ton_api{
  using namespace td;
Result<int32> tl_constructor_from_string(ton_api::Hashable *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"hashable.bool", -815709156},
    {"hashable.int32", -743074986},
    {"hashable.int64", -405107134},
    {"hashable.int256", 975377359},
    {"hashable.bytes", 118742546},
    {"hashable.pair", -941266795},
    {"hashable.vector", -550190227},
    {"hashable.validatorSessionOldRound", 1200318377},
    {"hashable.validatorSessionRoundAttempt", 1276247981},
    {"hashable.validatorSessionRound", 897011683},
    {"hashable.blockSignature", 937530018},
    {"hashable.sentBlock", -1111911125},
    {"hashable.sentBlockEmpty", -1628289361},
    {"hashable.vote", -1363203131},
    {"hashable.blockCandidate", 195670285},
    {"hashable.blockVoteCandidate", -821202971},
    {"hashable.blockCandidateAttempt", 1063025931},
    {"hashable.cntVector", 187199288},
    {"hashable.cntSortedVector", 2073445977},
    {"hashable.validatorSession", 1746035669}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::PrivateKey *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"pk.unenc", -1311007952},
    {"pk.ed25519", 1231561495},
    {"pk.aes", -1511501513},
    {"pk.overlay", 933623387}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::PublicKey *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"pub.unenc", -1239464694},
    {"pub.ed25519", 1209251014},
    {"pub.aes", 767339988},
    {"pub.overlay", 884622795}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::TestObject *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"testObject", -1521006198},
    {"testString", -934972983},
    {"testInt", 731271633},
    {"testVectorBytes", 1267407827}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::adnl_Address *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"adnl.address.udp", 1728947943},
    {"adnl.address.udp6", -484613126}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::adnl_Message *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"adnl.message.createChannel", -428620869},
    {"adnl.message.confirmChannel", 1625103721},
    {"adnl.message.custom", 541595893},
    {"adnl.message.nop", 402186202},
    {"adnl.message.reinit", 281150752},
    {"adnl.message.query", -1265895046},
    {"adnl.message.answer", 262964246},
    {"adnl.message.part", -45798087}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::adnl_Proxy *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"adnl.proxy.none", -90551726},
    {"adnl.proxy.fast", 554536094}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::catchain_BlockResult *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"catchain.blockNotFound", -1240397692},
    {"catchain.blockResult", -1658179513}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::catchain_Difference *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"catchain.difference", 336974282},
    {"catchain.differenceFork", 1227341935}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::catchain_block_inner_Data *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"catchain.block.data.badBlock", -1241359786},
    {"catchain.block.data.fork", 1685731922},
    {"catchain.block.data.nop", 1417852112},
    {"catchain.block.data.vector", 1688809258}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_block_Info *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.block.info", 1254549287},
    {"db.block.packedInfo", 1186697618},
    {"db.block.archivedInfo", 543128145}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_blockdb_Key *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.blockdb.key.lru", 1354536506},
    {"db.blockdb.key.value", 2136461683}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_filedb_Key *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.filedb.key.empty", 2080319307},
    {"db.filedb.key.blockFile", -1326783375},
    {"db.filedb.key.zeroStateFile", 307398205},
    {"db.filedb.key.persistentStateFile", -1346996660},
    {"db.filedb.key.proof", -627749396},
    {"db.filedb.key.proofLink", -1728330290},
    {"db.filedb.key.signatures", -685175541},
    {"db.filedb.key.candidate", -494269767}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_lt_Key *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.lt.el.key", -1523442974},
    {"db.lt.desc.key", -236722287},
    {"db.lt.shard.key", 1353120015},
    {"db.lt.status.key", 2003591255}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_root_Key *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.root.key.cellDb", 1928966974},
    {"db.root.key.blockDb", 806534976},
    {"db.root.key.config", 331559556}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::db_state_Key *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"db.state.key.destroyedSessions", -386404007},
    {"db.state.key.initBlockId", 1971484899},
    {"db.state.key.gcBlockId", -1015417890},
    {"db.state.key.shardClient", -912576121},
    {"db.state.key.asyncSerializer", 699304479},
    {"db.state.key.hardforks", -420206662}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::dht_UpdateRule *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"dht.updateRule.signature", -861982217},
    {"dht.updateRule.anybody", 1633127956},
    {"dht.updateRule.overlayNodes", 645370755}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::dht_ValueResult *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"dht.valueNotFound", -1570634392},
    {"dht.valueFound", -468912268}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::dht_config_Local *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"dht.config.local", 1981827695},
    {"dht.config.random.local", -1679088265}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::engine_Addr *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"engine.addr", -281993236},
    {"engine.addrProxy", -1965071031}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::fec_Type *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"fec.raptorQ", -1953257504},
    {"fec.roundRobin", 854927588},
    {"fec.online", 19359244}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::liteserver_config_Local *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"liteserver.config.local", 1182002063},
    {"liteserver.config.random.local", 2093565243}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::overlay_Broadcast *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"overlay.fec.received", -715385620},
    {"overlay.fec.completed", 165112084},
    {"overlay.unicast", 861097508},
    {"overlay.broadcast", -1319490709},
    {"overlay.broadcastFec", -1160264854},
    {"overlay.broadcastFecShort", -242740414},
    {"overlay.broadcastNotFound", -1786366428}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::overlay_Certificate *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"overlay.certificate", -526461135},
    {"overlay.emptyCertificate", 853195983}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::rldp_Message *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"rldp.message", 2098973982},
    {"rldp.query", -1971761815},
    {"rldp.answer", -1543742461}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::rldp_MessagePart *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"rldp.messagePart", 408691404},
    {"rldp.confirm", -175973288},
    {"rldp.complete", -1140018497}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tcp_Message *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tcp.authentificate", 1146858258},
    {"tcp.authentificationNonce", -480425290},
    {"tcp.authentificationComplete", -139616602}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::ton_BlockId *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"ton.blockId", -989106576},
    {"ton.blockIdApprove", 768887369}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_BlockDescription *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.blockDescriptionEmpty", -2088456555},
    {"tonNode.blockDescription", 1185009800}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_Broadcast *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.blockBroadcast", -1372712699},
    {"tonNode.ihrMessageBroadcast", 1381868723},
    {"tonNode.externalMessageBroadcast", 1025185895},
    {"tonNode.newShardBlockBroadcast", 183696060}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_DataFull *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.dataFull", -1101488237},
    {"tonNode.dataFullEmpty", 1466861002}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_Prepared *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.prepared", -356205619},
    {"tonNode.notFound", -490521178}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_PreparedProof *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.preparedProofEmpty", -949370502},
    {"tonNode.preparedProof", -1986028981},
    {"tonNode.preparedProofLink", 1040134797}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::tonNode_PreparedState *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"tonNode.preparedState", 928762733},
    {"tonNode.notFoundState", 842598993}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::validator_Group *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"validator.group", -120029535},
    {"validator.groupEx", 479350270}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::validator_config_Local *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"validator.config.local", 1716256616},
    {"validator.config.random.local", 1501795426}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::validatorSession_Message *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"validatorSession.message.startSession", -1767807279},
    {"validatorSession.message.finishSession", -879025437}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::validatorSession_round_Message *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"validatorSession.message.submittedBlock", 309732534},
    {"validatorSession.message.approvedBlock", 77968769},
    {"validatorSession.message.rejectedBlock", -1786229141},
    {"validatorSession.message.commit", -1408065803},
    {"validatorSession.message.vote", -1707978297},
    {"validatorSession.message.voteFor", 1643183663},
    {"validatorSession.message.precommit", -1470843566},
    {"validatorSession.message.empty", 1243619241}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::Object *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"hashable.bool", -815709156},
    {"hashable.int32", -743074986},
    {"hashable.int64", -405107134},
    {"hashable.int256", 975377359},
    {"hashable.bytes", 118742546},
    {"hashable.pair", -941266795},
    {"hashable.vector", -550190227},
    {"hashable.validatorSessionOldRound", 1200318377},
    {"hashable.validatorSessionRoundAttempt", 1276247981},
    {"hashable.validatorSessionRound", 897011683},
    {"hashable.blockSignature", 937530018},
    {"hashable.sentBlock", -1111911125},
    {"hashable.sentBlockEmpty", -1628289361},
    {"hashable.vote", -1363203131},
    {"hashable.blockCandidate", 195670285},
    {"hashable.blockVoteCandidate", -821202971},
    {"hashable.blockCandidateAttempt", 1063025931},
    {"hashable.cntVector", 187199288},
    {"hashable.cntSortedVector", 2073445977},
    {"hashable.validatorSession", 1746035669},
    {"pk.unenc", -1311007952},
    {"pk.ed25519", 1231561495},
    {"pk.aes", -1511501513},
    {"pk.overlay", 933623387},
    {"pub.unenc", -1239464694},
    {"pub.ed25519", 1209251014},
    {"pub.aes", 767339988},
    {"pub.overlay", 884622795},
    {"testObject", -1521006198},
    {"testString", -934972983},
    {"testInt", 731271633},
    {"testVectorBytes", 1267407827},
    {"adnl.address.udp", 1728947943},
    {"adnl.address.udp6", -484613126},
    {"adnl.addressList", 573040216},
    {"adnl.message.createChannel", -428620869},
    {"adnl.message.confirmChannel", 1625103721},
    {"adnl.message.custom", 541595893},
    {"adnl.message.nop", 402186202},
    {"adnl.message.reinit", 281150752},
    {"adnl.message.query", -1265895046},
    {"adnl.message.answer", 262964246},
    {"adnl.message.part", -45798087},
    {"adnl.node", 1800802949},
    {"adnl.nodes", -1576412330},
    {"adnl.packetContents", -784151159},
    {"adnl.pong", 544504846},
    {"adnl.proxy.none", -90551726},
    {"adnl.proxy.fast", 554536094},
    {"adnl.proxyToFastHash", -574752674},
    {"adnl.proxyToFast", -1259462186},
    {"adnl.config.global", -1099988784},
    {"adnl.db.node.key", -979114962},
    {"adnl.db.node.value", 1415390983},
    {"adnl.id.short", 1044342095},
    {"catchain.block", -699055756},
    {"catchain.blockNotFound", -1240397692},
    {"catchain.blockResult", -1658179513},
    {"catchain.blocks", 1357697473},
    {"catchain.difference", 336974282},
    {"catchain.differenceFork", 1227341935},
    {"catchain.firstblock", 281609467},
    {"catchain.sent", -84454993},
    {"catchain.blockUpdate", 593975492},
    {"catchain.block.data", -122903008},
    {"catchain.block.dep", 1511706959},
    {"catchain.block.id", 620665018},
    {"catchain.block.data.badBlock", -1241359786},
    {"catchain.block.data.fork", 1685731922},
    {"catchain.block.data.nop", 1417852112},
    {"catchain.block.data.vector", 1688809258},
    {"catchain.config.global", 1757918801},
    {"config.global", -198795310},
    {"config.local", 2023657820},
    {"control.config.local", 1964895469},
    {"db.candidate", 1708747482},
    {"db.block.info", 1254549287},
    {"db.block.packedInfo", 1186697618},
    {"db.block.archivedInfo", 543128145},
    {"db.blockdb.key.lru", 1354536506},
    {"db.blockdb.key.value", 2136461683},
    {"db.blockdb.lru", -1055500877},
    {"db.blockdb.value", -1299266515},
    {"db.candidate.id", 935375495},
    {"db.celldb.value", -435153856},
    {"db.celldb.key.value", 1538341155},
    {"db.filedb.key.empty", 2080319307},
    {"db.filedb.key.blockFile", -1326783375},
    {"db.filedb.key.zeroStateFile", 307398205},
    {"db.filedb.key.persistentStateFile", -1346996660},
    {"db.filedb.key.proof", -627749396},
    {"db.filedb.key.proofLink", -1728330290},
    {"db.filedb.key.signatures", -685175541},
    {"db.filedb.key.candidate", -494269767},
    {"db.filedb.value", -220390867},
    {"db.lt.el.key", -1523442974},
    {"db.lt.desc.key", -236722287},
    {"db.lt.shard.key", 1353120015},
    {"db.lt.status.key", 2003591255},
    {"db.lt.desc.value", 1907315124},
    {"db.lt.el.value", -1780064412},
    {"db.lt.shard.value", 1014209147},
    {"db.lt.status.value", -88150727},
    {"db.root.config", -703495519},
    {"db.root.dbDescription", -1273465869},
    {"db.root.key.cellDb", 1928966974},
    {"db.root.key.blockDb", 806534976},
    {"db.root.key.config", 331559556},
    {"db.state.asyncSerializer", -751883871},
    {"db.state.destroyedSessions", -1381443196},
    {"db.state.gcBlockId", -550453937},
    {"db.state.hardforks", -2047668988},
    {"db.state.initBlockId", 1932303605},
    {"db.state.key.destroyedSessions", -386404007},
    {"db.state.key.initBlockId", 1971484899},
    {"db.state.key.gcBlockId", -1015417890},
    {"db.state.key.shardClient", -912576121},
    {"db.state.key.asyncSerializer", 699304479},
    {"db.state.key.hardforks", -420206662},
    {"db.state.shardClient", 186033821},
    {"dht.key", -160964977},
    {"dht.keyDescription", 673009157},
    {"dht.message", -1140008050},
    {"dht.node", -2074922424},
    {"dht.nodes", 2037686462},
    {"dht.pong", 1519054721},
    {"dht.stored", 1881602824},
    {"dht.updateRule.signature", -861982217},
    {"dht.updateRule.anybody", 1633127956},
    {"dht.updateRule.overlayNodes", 645370755},
    {"dht.value", -1867700277},
    {"dht.valueNotFound", -1570634392},
    {"dht.valueFound", -468912268},
    {"dht.config.global", -2066822649},
    {"dht.config.local", 1981827695},
    {"dht.config.random.local", -1679088265},
    {"dht.db.bucket", -1281557908},
    {"dht.db.key.bucket", -1553420724},
    {"dummyworkchain0.config.global", -631148845},
    {"engine.addr", -281993236},
    {"engine.addrProxy", -1965071031},
    {"engine.adnl", 1658283344},
    {"engine.controlInterface", 830566315},
    {"engine.controlProcess", 1790986263},
    {"engine.dht", 1575613178},
    {"engine.gc", -1078093701},
    {"engine.liteServer", -1150251266},
    {"engine.validator", -2006980055},
    {"engine.validatorAdnlAddress", -750434882},
    {"engine.validatorTempKey", 1581962974},
    {"engine.adnlProxy.config", 1848000769},
    {"engine.adnlProxy.port", -117344950},
    {"engine.dht.config", -197295930},
    {"engine.validator.config", -826140252},
    {"engine.validator.controlQueryError", 1999018527},
    {"engine.validator.dhtServerStatus", -1323440290},
    {"engine.validator.dhtServersStatus", 725155112},
    {"engine.validator.electionBid", 598899261},
    {"engine.validator.fullNodeMaster", -2071595416},
    {"engine.validator.fullNodeSlave", -2010813575},
    {"validator.groupMember", -1953208860},
    {"engine.validator.jsonConfig", 321753611},
    {"engine.validator.keyHash", -1027168946},
    {"engine.validator.oneStat", -1533527315},
    {"engine.validator.signature", -76791000},
    {"engine.validator.stats", 1565119343},
    {"engine.validator.success", -1276860789},
    {"engine.validator.time", -547380738},
    {"fec.raptorQ", -1953257504},
    {"fec.roundRobin", 854927588},
    {"fec.online", 19359244},
    {"id.config.local", -1834367090},
    {"liteclient.config.global", 143507704},
    {"liteserver.desc", -1001806732},
    {"liteserver.config.local", 1182002063},
    {"liteserver.config.random.local", 2093565243},
    {"overlay.fec.received", -715385620},
    {"overlay.fec.completed", 165112084},
    {"overlay.unicast", 861097508},
    {"overlay.broadcast", -1319490709},
    {"overlay.broadcastFec", -1160264854},
    {"overlay.broadcastFecShort", -242740414},
    {"overlay.broadcastNotFound", -1786366428},
    {"overlay.broadcastList", 416407263},
    {"overlay.certificate", -526461135},
    {"overlay.emptyCertificate", 853195983},
    {"overlay.certificateId", -1884397383},
    {"overlay.message", 1965368352},
    {"overlay.node", -1200911741},
    {"overlay.nodes", -460904178},
    {"overlay.broadcast.id", 1375565978},
    {"overlay.broadcast.toSign", -97038724},
    {"overlay.broadcastFec.id", -80652890},
    {"overlay.broadcastFec.partId", -1536597296},
    {"overlay.db.key.nodes", -992972010},
    {"overlay.db.nodes", -712454630},
    {"overlay.node.toSign", 64530657},
    {"rldp.message", 2098973982},
    {"rldp.query", -1971761815},
    {"rldp.answer", -1543742461},
    {"rldp.messagePart", 408691404},
    {"rldp.confirm", -175973288},
    {"rldp.complete", -1140018497},
    {"tcp.authentificate", 1146858258},
    {"tcp.authentificationNonce", -480425290},
    {"tcp.authentificationComplete", -139616602},
    {"tcp.pong", -597034237},
    {"ton.blockId", -989106576},
    {"ton.blockIdApprove", 768887369},
    {"tonNode.blockDescriptionEmpty", -2088456555},
    {"tonNode.blockDescription", 1185009800},
    {"tonNode.blockId", -1211256473},
    {"tonNode.blockIdExt", 1733487480},
    {"tonNode.blockSignature", 1357921331},
    {"tonNode.blocksDescription", -701865684},
    {"tonNode.blockBroadcast", -1372712699},
    {"tonNode.ihrMessageBroadcast", 1381868723},
    {"tonNode.externalMessageBroadcast", 1025185895},
    {"tonNode.newShardBlockBroadcast", 183696060},
    {"tonNode.capabilities", -172007232},
    {"tonNode.data", 1443505284},
    {"tonNode.dataFull", -1101488237},
    {"tonNode.dataFullEmpty", 1466861002},
    {"tonNode.dataList", 351548179},
    {"tonNode.externalMessage", -596270583},
    {"tonNode.ihrMessage", 1161085703},
    {"tonNode.keyBlocks", 124144985},
    {"tonNode.newShardBlock", -1533165015},
    {"tonNode.prepared", -356205619},
    {"tonNode.notFound", -490521178},
    {"tonNode.preparedProofEmpty", -949370502},
    {"tonNode.preparedProof", -1986028981},
    {"tonNode.preparedProofLink", 1040134797},
    {"tonNode.preparedState", 928762733},
    {"tonNode.notFoundState", 842598993},
    {"tonNode.sessionId", 2056402618},
    {"tonNode.shardPublicOverlayId", 1302254377},
    {"tonNode.success", -1063902129},
    {"tonNode.zeroStateIdExt", 494024110},
    {"validator.group", -120029535},
    {"validator.groupEx", 479350270},
    {"validator.config.global", -2038562966},
    {"validator.config.local", 1716256616},
    {"validator.config.random.local", 1501795426},
    {"validatorSession.blockUpdate", -1836855753},
    {"validatorSession.candidate", 2100525125},
    {"validatorSession.candidateId", 436135276},
    {"validatorSession.config", -1235092029},
    {"validatorSession.message.startSession", -1767807279},
    {"validatorSession.message.finishSession", -879025437},
    {"validatorSession.pong", -590989459},
    {"validatorSession.round.id", 2477989},
    {"validatorSession.message.submittedBlock", 309732534},
    {"validatorSession.message.approvedBlock", 77968769},
    {"validatorSession.message.rejectedBlock", -1786229141},
    {"validatorSession.message.commit", -1408065803},
    {"validatorSession.message.vote", -1707978297},
    {"validatorSession.message.voteFor", 1643183663},
    {"validatorSession.message.precommit", -1470843566},
    {"validatorSession.message.empty", 1243619241},
    {"validatorSession.candidate.id", -1126743751}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Result<int32> tl_constructor_from_string(ton_api::Function *object, const std::string &str) {
  static const std::unordered_map<Slice, int32, SliceHash> m = {
    {"adnl.ping", 531276223},
    {"catchain.getBlock", 155049336},
    {"catchain.getBlockHistory", -1470730762},
    {"catchain.getBlocks", 53062594},
    {"catchain.getDifference", -798175528},
    {"dht.findNode", 1826803307},
    {"dht.findValue", -1370791919},
    {"dht.getSignedAddressList", -1451669267},
    {"dht.ping", -873775336},
    {"dht.query", 2102593385},
    {"dht.store", 882065938},
    {"engine.validator.addAdnlId", -310029141},
    {"engine.validator.addControlInterface", 881587196},
    {"engine.validator.addControlProcess", 1524692816},
    {"engine.validator.addDhtId", -183755124},
    {"engine.validator.addListeningPort", -362051147},
    {"engine.validator.addLiteserver", -259387577},
    {"engine.validator.addProxy", -151178251},
    {"engine.validator.addValidatorAdnlAddress", -624187774},
    {"engine.validator.addValidatorPermanentKey", -1844116104},
    {"engine.validator.addValidatorTempKey", -1926009038},
    {"engine.validator.changeFullNodeAdnlAddress", -1094268539},
    {"engine.validator.checkDhtServers", -773578550},
    {"engine.validator.controlQuery", -1535722048},
    {"engine.validator.createElectionBid", -451038907},
    {"engine.validator.delAdnlId", 691696882},
    {"engine.validator.delDhtId", -2063770818},
    {"engine.validator.delListeningPort", 828094543},
    {"engine.validator.delProxy", 1970850941},
    {"engine.validator.delValidatorAdnlAddress", -150453414},
    {"engine.validator.delValidatorPermanentKey", 390777082},
    {"engine.validator.delValidatorTempKey", -1595481903},
    {"engine.validator.exportPrivateKey", -864911288},
    {"engine.validator.exportPublicKey", 1647618233},
    {"engine.validator.generateKeyPair", -349872005},
    {"engine.validator.getConfig", 1504518693},
    {"engine.validator.getStats", 1389740817},
    {"engine.validator.getTime", -515850543},
    {"engine.validator.importPrivateKey", 360741575},
    {"engine.validator.setVerbosity", -1316856190},
    {"engine.validator.sign", 451549736},
    {"getTestObject", 197109379},
    {"overlay.getBroadcast", 758510240},
    {"overlay.getBroadcastList", 1109141562},
    {"overlay.getRandomPeers", 1223582891},
    {"overlay.query", -855800765},
    {"tcp.ping", 1292381082},
    {"tonNode.downloadBlock", -495814205},
    {"tonNode.downloadBlockFull", 1780991133},
    {"tonNode.downloadBlockProof", 1272334218},
    {"tonNode.downloadBlockProofLink", 632488134},
    {"tonNode.downloadBlockProofLinks", 684796771},
    {"tonNode.downloadBlockProofs", -1515170827},
    {"tonNode.downloadBlocks", 1985594749},
    {"tonNode.downloadNextBlockFull", 1855993674},
    {"tonNode.downloadPersistentState", 2140791736},
    {"tonNode.downloadPersistentStateSlice", -169220381},
    {"tonNode.downloadZeroState", -1379131814},
    {"tonNode.getCapabilities", -555345672},
    {"tonNode.getNextBlockDescription", 341160179},
    {"tonNode.getNextBlocksDescription", 1059590852},
    {"tonNode.getNextKeyBlockIds", -219689029},
    {"tonNode.getPrevBlocksDescription", 1550675145},
    {"tonNode.prepareBlock", 1973649230},
    {"tonNode.prepareBlockProof", -2024000760},
    {"tonNode.prepareBlockProofs", -310791496},
    {"tonNode.prepareBlocks", 1795140604},
    {"tonNode.preparePersistentState", -18209122},
    {"tonNode.prepareZeroState", 1104021541},
    {"tonNode.query", 1777542355},
    {"tonNode.slave.sendExtMessage", 58127017},
    {"validatorSession.downloadCandidate", -520274443},
    {"validatorSession.ping", 1745111469}
  };
  auto it = m.find(str);
  if (it == m.end()) {
    return Status::Error(str + "Unknown class");
  }
  return it->second;
}
Status from_json(ton_api::hashable_bool &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_int32 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_int64 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_int256 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_bytes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_pair &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "left", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.left_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "right", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.right_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_vector &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_validatorSessionOldRound &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signatures", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.signatures_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "approve_signatures", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.approve_signatures_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_validatorSessionRoundAttempt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "votes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.votes_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "precommitted", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.precommitted_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "vote_for_inited", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.vote_for_inited_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "vote_for", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.vote_for_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_validatorSessionRound &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "locked_round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.locked_round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "locked_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.locked_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "precommitted", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.precommitted_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "first_attempt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.first_attempt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "approved_blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.approved_blocks_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signatures", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.signatures_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "attempts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.attempts_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_blockSignature &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_sentBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data_file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.collated_data_file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_sentBlockEmpty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::hashable_vote &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "node", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.node_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_blockCandidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "approved", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.approved_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_blockVoteCandidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "approved", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.approved_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_blockCandidateAttempt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "votes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.votes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_cntVector &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_cntSortedVector &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::hashable_validatorSession &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ts_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "old_rounds", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.old_rounds_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "cur_round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cur_round_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pk_unenc &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pk_ed25519 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pk_aes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pk_overlay &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "name", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.name_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pub_unenc &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pub_ed25519 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pub_aes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::pub_overlay &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "name", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.name_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::testObject &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "o", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.o_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "f", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.f_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::testString &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::testInt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::testVectorBytes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_vector_bytes(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_address_udp &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_address_udp6 &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_addressList &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "addrs", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addrs_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "reinit_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.reinit_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_createChannel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_confirmChannel &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "peer_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.peer_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_custom &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_nop &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::adnl_message_reinit &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_query &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "query_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.query_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "query", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.query_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_answer &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "query_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.query_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "answer", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.answer_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_message_part &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "total_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.total_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "offset", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.offset_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_node &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "addr_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addr_list_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_nodes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_packetContents &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "rand1", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.rand1_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "from", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.from_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "from_short", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.from_short_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "messages", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.messages_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.address_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_address", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_address_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "confirm_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.confirm_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "recv_addr_list_version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.recv_addr_list_version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "recv_priority_addr_list_version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.recv_priority_addr_list_version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "reinit_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.reinit_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dst_reinit_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dst_reinit_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "rand2", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.rand2_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_pong &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_proxy_none &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::adnl_proxy_fast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "shared_secret", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.shared_secret_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_proxyToFastHash &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shared_secret", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shared_secret_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_proxyToFast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "static_nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.static_nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_db_node_key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.local_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "peer_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.peer_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_db_node_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "addr_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addr_list_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_addr_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_addr_list_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_id_short &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "incarnation", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.incarnation_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "height", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.height_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_blockNotFound &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::catchain_blockResult &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_blocks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_difference &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "sent_upto", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sent_upto_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_differenceFork &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "left", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.left_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "right", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.right_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_firstblock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "unique_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.unique_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_sent &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "cnt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cnt_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_blockUpdate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_data &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "prev", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "deps", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.deps_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_dep &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "height", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.height_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "incarnation", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.incarnation_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "height", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.height_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_data_badBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_data_fork &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "left", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.left_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "right", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.right_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_block_data_nop &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::catchain_block_data_vector &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "msgs", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_vector_bytes(to.msgs_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "tag", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.tag_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dht", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dht_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "validator", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.validator_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_ids", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.local_ids_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dht", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dht_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "validators", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.validators_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "liteservers", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.liteservers_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "control", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.control_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::control_config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "priv", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priv_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "pub", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.pub_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_candidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "source", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.source_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.collated_data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_block_info &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_left", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_left_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_right", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_right_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next_left", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_left_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next_right", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_right_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "lt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.lt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ts_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.state_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_block_packedInfo &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "unixtime", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.unixtime_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "offset", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.offset_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_block_archivedInfo &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_blockdb_key_lru &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_blockdb_key_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_blockdb_lru &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_blockdb_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "next", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_candidate_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "source", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.source_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data_file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.collated_data_file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_celldb_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_celldb_key_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_empty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_blockFile &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_zeroStateFile &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_persistentStateFile &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "masterchain_block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.masterchain_block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_proof &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_proofLink &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_signatures &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_key_candidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_filedb_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_el_key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "idx", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.idx_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_desc_key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_shard_key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "idx", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.idx_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_status_key &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_lt_desc_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "first_idx", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.first_idx_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_idx", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_idx_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_lt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_lt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_ts_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_el_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "lt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.lt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ts_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_shard_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_lt_status_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "total_shards", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.total_shards_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_root_config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "celldb_version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.celldb_version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "blockdb_version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blockdb_version_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_root_dbDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "first_masterchain_block_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.first_masterchain_block_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_root_key_cellDb &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_root_key_blockDb &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_root_key_config &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_asyncSerializer &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "last_ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.last_ts_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_state_destroyedSessions &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "sessions", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.sessions_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_state_gcBlockId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_state_hardforks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_state_initBlockId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::db_state_key_destroyedSessions &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_key_initBlockId &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_key_gcBlockId &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_key_shardClient &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_key_asyncSerializer &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_key_hardforks &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::db_state_shardClient &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_key &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "name", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.name_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "idx", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.idx_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_keyDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "update_rule", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.update_rule_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_message &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "node", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.node_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_node &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "addr_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addr_list_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_nodes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_pong &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "random_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.random_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_stored &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::dht_updateRule_signature &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::dht_updateRule_anybody &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::dht_updateRule_overlayNodes &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::dht_value &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.value_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ttl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ttl_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_valueNotFound &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_valueFound &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "static_nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.static_nodes_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "k", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.k_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "a", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.a_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_config_random_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "cnt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cnt_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_db_bucket &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_db_key_bucket &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dummyworkchain0_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "zero_state_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.zero_state_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_addr &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_addrProxy &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "in_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "in_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "proxy_type", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.proxy_type_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_adnl &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "category", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.category_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_controlInterface &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "allowed", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.allowed_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_controlProcess &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "permissions", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permissions_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_dht &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_gc &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ids", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ids_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_liteServer &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "temp_keys", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.temp_keys_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl_addrs", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_addrs_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "election_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.election_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validatorAdnlAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validatorTempKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_adnlProxy_config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ports", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ports_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_adnlProxy_port &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "in_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dst_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dst_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dst_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dst_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "proxy_type", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.proxy_type_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_dht_config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "dht", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dht_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "gc", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.gc_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "out_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "addrs", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addrs_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "dht", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.dht_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "validators", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.validators_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fullnode", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fullnode_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fullnodeslaves", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fullnodeslaves_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fullnodemasters", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fullnodemasters_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "liteservers", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.liteservers_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "control", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.control_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "gc", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.gc_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_controlQueryError &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "code", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.code_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_dhtServerStatus &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "status", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.status_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_dhtServersStatus &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "servers", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.servers_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_electionBid &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "election_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.election_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "perm_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.perm_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl_addr", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_addr_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "to_send_payload", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.to_send_payload_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_fullNodeMaster &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_fullNodeSlave &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_groupMember &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "public_key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.public_key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "weight", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.weight_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_jsonConfig &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_keyHash &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_oneStat &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_signature &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_stats &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "stats", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.stats_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_success &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::engine_validator_time &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "time", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.time_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::fec_raptorQ &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbol_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbol_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbols_count", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbols_count_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::fec_roundRobin &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbol_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbol_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbols_count", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbols_count_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::fec_online &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbol_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbol_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "symbols_count", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.symbols_count_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::id_config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::liteclient_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "liteservers", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.liteservers_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "validator", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.validator_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::liteserver_desc &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::liteserver_config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::liteserver_config_random_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_fec_received &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_fec_completed &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_unicast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "certificate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.certificate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastFec &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "certificate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.certificate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fec", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fec_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastFecShort &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "certificate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.certificate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "broadcast_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.broadcast_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "part_data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.part_data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastNotFound &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastList &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hashes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hashes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_certificate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "issued_by", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.issued_by_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_emptyCertificate &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::overlay_certificateId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "node", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.node_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "expire_at", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.expire_at_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_size_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_message &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_node &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_nodes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcast_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcast_toSign &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.date_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastFec_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "type", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.type_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "flags", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.flags_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_broadcastFec_partId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "broadcast_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.broadcast_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.data_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_db_key_nodes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "local_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.local_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_db_nodes &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nodes", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.nodes_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_node_toSign &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_message &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_query &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "query_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.query_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_answer_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_answer_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "timeout", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.timeout_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_answer &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "query_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.query_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_messagePart &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "transfer_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.transfer_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "fec_type", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.fec_type_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "part", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.part_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "total_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.total_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_confirm &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "transfer_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.transfer_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "part", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.part_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::rldp_complete &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "transfer_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.transfer_id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "part", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.part_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tcp_authentificate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nonce", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.nonce_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tcp_authentificationNonce &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "nonce", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.nonce_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tcp_authentificationComplete &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tcp_pong &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "random_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.random_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::ton_blockId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "root_cell_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_cell_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::ton_blockIdApprove &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "root_cell_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_cell_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockDescriptionEmpty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockIdExt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockSignature &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "who", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.who_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blocksDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ids", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ids_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "incomplete", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.incomplete_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_blockBroadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "catchain_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.catchain_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "validator_set_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.validator_set_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signatures", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.signatures_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "proof", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.proof_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_ihrMessageBroadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_externalMessageBroadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_newShardBlockBroadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_capabilities &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "version", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.version_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "capabilities", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.capabilities_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_data &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_dataFull &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "proof", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.proof_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "is_link", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.is_link_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_dataFullEmpty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_dataList &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_vector_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_externalMessage &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_ihrMessage &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_keyBlocks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "incomplete", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.incomplete_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "error", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.error_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_newShardBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "cc_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cc_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepared &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_notFound &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_preparedProofEmpty &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_preparedProof &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_preparedProofLink &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_preparedState &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_notFoundState &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_sessionId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "cc_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cc_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "opts_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.opts_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_shardPublicOverlayId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "zero_state_file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.zero_state_file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_success &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_zeroStateIdExt &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_group &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "catchain_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.catchain_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "config_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.config_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "members", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.members_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_groupEx &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "workchain", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.workchain_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "shard", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.shard_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "vertical_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.vertical_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "catchain_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.catchain_seqno_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "config_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.config_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "members", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.members_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_config_global &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "zero_state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.zero_state_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "init_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.init_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "hardforks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hardforks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_config_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validator_config_random_local &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "addr_list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.addr_list_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_blockUpdate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ts_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "actions", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.actions_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "state", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.state_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_candidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.collated_data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_candidateId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "src", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.src_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data_file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.collated_data_file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_config &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "catchain_idle_timeout", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.catchain_idle_timeout_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "catchain_max_deps", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.catchain_max_deps_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "round_candidates", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_candidates_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "next_candidate_delay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_candidate_delay_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "round_attempt_duration", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_attempt_duration_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_round_attempts", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_round_attempts_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_block_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_block_size_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_collated_data_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_collated_data_size_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_startSession &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_finishSession &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::validatorSession_pong &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_round_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "session", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.session_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "height", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.height_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.seqno_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_submittedBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "root_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.root_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.file_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "collated_data_file_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.collated_data_file_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_approvedBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_rejectedBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "reason", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.reason_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_commit &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "signature", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.signature_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_vote &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "attempt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.attempt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_voteFor &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "attempt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.attempt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_precommit &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "attempt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.attempt_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "candidate", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.candidate_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_message_empty &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "attempt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.attempt_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_candidate_id &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "block_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::adnl_ping &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_getBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_getBlockHistory &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "height", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.height_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "stop_if", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.stop_if_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_getBlocks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::catchain_getDifference &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "rt", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.rt_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_findNode &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "k", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.k_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_findValue &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "k", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.k_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_getSignedAddressList &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::dht_ping &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "random_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.random_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_query &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "node", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.node_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::dht_store &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "value", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.value_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addAdnlId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "category", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.category_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addControlInterface &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addControlProcess &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "peer_key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.peer_key_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "permissions", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permissions_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addDhtId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addListeningPort &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addLiteserver &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addProxy &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "in_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "in_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.in_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "proxy", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.proxy_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addValidatorAdnlAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "permanent_key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permanent_key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ttl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ttl_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addValidatorPermanentKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "election_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.election_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ttl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ttl_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_addValidatorTempKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "permanent_key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permanent_key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "ttl", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ttl_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_changeFullNodeAdnlAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "adnl_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.adnl_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_checkDhtServers &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_controlQuery &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_createElectionBid &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "election_date", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.election_date_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "election_addr", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.election_addr_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "wallet", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.wallet_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delAdnlId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delDhtId &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delListeningPort &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delProxy &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "out_ip", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_ip_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "out_port", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.out_port_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.categories_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "priority_categories", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.priority_categories_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delValidatorAdnlAddress &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "permanent_key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permanent_key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delValidatorPermanentKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_delValidatorTempKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "permanent_key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.permanent_key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_exportPrivateKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_exportPublicKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_generateKeyPair &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::engine_validator_getConfig &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::engine_validator_getStats &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::engine_validator_getTime &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::engine_validator_importPrivateKey &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_setVerbosity &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "verbosity", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.verbosity_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::engine_validator_sign &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "key_hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.key_hash_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "data", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json_bytes(to.data_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::getTestObject &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::overlay_getBroadcast &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_getBroadcastList &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "list", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.list_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_getRandomPeers &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "peers", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.peers_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::overlay_query &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "overlay", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.overlay_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tcp_ping &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "random_id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.random_id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlockFull &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlockProof &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlockProofLink &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlockProofLinks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlockProofs &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadBlocks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadNextBlockFull &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadPersistentState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "masterchain_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.masterchain_block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadPersistentStateSlice &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "masterchain_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.masterchain_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "offset", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.offset_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_size_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_downloadZeroState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_getCapabilities &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_getNextBlockDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_getNextBlocksDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "prev_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.prev_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "limit", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.limit_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_getNextKeyBlockIds &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "max_size", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.max_size_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_getPrevBlocksDescription &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "next_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.next_block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "limit", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.limit_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "cutoff_seqno", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.cutoff_seqno_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepareBlock &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepareBlockProof &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "allow_partial", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.allow_partial_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepareBlockProofs &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "allow_partial", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.allow_partial_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepareBlocks &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "blocks", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.blocks_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_preparePersistentState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "masterchain_block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.masterchain_block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_prepareZeroState &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "block", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.block_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::tonNode_query &to, JsonObject &from) {
  return Status::OK();
}
Status from_json(ton_api::tonNode_slave_sendExtMessage &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "message", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.message_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_downloadCandidate &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "round", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.round_, value));
    }
  }
  {
    TRY_RESULT(value, get_json_object_field(from, "id", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.id_, value));
    }
  }
  return Status::OK();
}
Status from_json(ton_api::validatorSession_ping &to, JsonObject &from) {
  {
    TRY_RESULT(value, get_json_object_field(from, "hash", JsonValue::Type::Null, true));
    if (value.type() != JsonValue::Type::Null) {
      TRY_STATUS(from_json(to.hash_, value));
    }
  }
  return Status::OK();
}
void to_json(JsonValueScope &jv, const ton_api::Hashable &object) {
  ton_api::downcast_call(const_cast<ton_api::Hashable &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::hashable_bool &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.bool");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_int32 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.int32");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_int64 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.int64");
  jo << ctie("value", ToJson(JsonInt64{object.value_}));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_int256 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.int256");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_bytes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.bytes");
  jo << ctie("value", ToJson(JsonBytes{object.value_}));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_pair &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.pair");
  jo << ctie("left", ToJson(object.left_));
  jo << ctie("right", ToJson(object.right_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_vector &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.vector");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_validatorSessionOldRound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.validatorSessionOldRound");
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("signatures", ToJson(object.signatures_));
  jo << ctie("approve_signatures", ToJson(object.approve_signatures_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_validatorSessionRoundAttempt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.validatorSessionRoundAttempt");
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("votes", ToJson(object.votes_));
  jo << ctie("precommitted", ToJson(object.precommitted_));
  jo << ctie("vote_for_inited", ToJson(object.vote_for_inited_));
  jo << ctie("vote_for", ToJson(object.vote_for_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_validatorSessionRound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.validatorSessionRound");
  jo << ctie("locked_round", ToJson(object.locked_round_));
  jo << ctie("locked_block", ToJson(object.locked_block_));
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("precommitted", ToJson(object.precommitted_));
  jo << ctie("first_attempt", ToJson(object.first_attempt_));
  jo << ctie("approved_blocks", ToJson(object.approved_blocks_));
  jo << ctie("signatures", ToJson(object.signatures_));
  jo << ctie("attempts", ToJson(object.attempts_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_blockSignature &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.blockSignature");
  jo << ctie("signature", ToJson(object.signature_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_sentBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.sentBlock");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
  jo << ctie("collated_data_file_hash", ToJson(object.collated_data_file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_sentBlockEmpty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.sentBlockEmpty");
}
void to_json(JsonValueScope &jv, const ton_api::hashable_vote &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.vote");
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("node", ToJson(object.node_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_blockCandidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.blockCandidate");
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("approved", ToJson(object.approved_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_blockVoteCandidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.blockVoteCandidate");
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("approved", ToJson(object.approved_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_blockCandidateAttempt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.blockCandidateAttempt");
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("votes", ToJson(object.votes_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_cntVector &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.cntVector");
  jo << ctie("data", ToJson(object.data_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_cntSortedVector &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.cntSortedVector");
  jo << ctie("data", ToJson(object.data_));
}
void to_json(JsonValueScope &jv, const ton_api::hashable_validatorSession &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "hashable.validatorSession");
  jo << ctie("ts", ToJson(object.ts_));
  jo << ctie("old_rounds", ToJson(object.old_rounds_));
  jo << ctie("cur_round", ToJson(object.cur_round_));
}
void to_json(JsonValueScope &jv, const ton_api::PrivateKey &object) {
  ton_api::downcast_call(const_cast<ton_api::PrivateKey &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::pk_unenc &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pk.unenc");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::pk_ed25519 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pk.ed25519");
  jo << ctie("key", ToJson(object.key_));
}
void to_json(JsonValueScope &jv, const ton_api::pk_aes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pk.aes");
  jo << ctie("key", ToJson(object.key_));
}
void to_json(JsonValueScope &jv, const ton_api::pk_overlay &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pk.overlay");
  jo << ctie("name", ToJson(JsonBytes{object.name_}));
}
void to_json(JsonValueScope &jv, const ton_api::PublicKey &object) {
  ton_api::downcast_call(const_cast<ton_api::PublicKey &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::pub_unenc &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pub.unenc");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::pub_ed25519 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pub.ed25519");
  jo << ctie("key", ToJson(object.key_));
}
void to_json(JsonValueScope &jv, const ton_api::pub_aes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pub.aes");
  jo << ctie("key", ToJson(object.key_));
}
void to_json(JsonValueScope &jv, const ton_api::pub_overlay &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "pub.overlay");
  jo << ctie("name", ToJson(JsonBytes{object.name_}));
}
void to_json(JsonValueScope &jv, const ton_api::TestObject &object) {
  ton_api::downcast_call(const_cast<ton_api::TestObject &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::testObject &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testObject");
  jo << ctie("value", ToJson(object.value_));
  jo << ctie("o", ToJson(object.o_));
  jo << ctie("f", ToJson(object.f_));
}
void to_json(JsonValueScope &jv, const ton_api::testString &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testString");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::testInt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testInt");
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::testVectorBytes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "testVectorBytes");
  jo << ctie("value", ToJson(JsonVectorBytes(object.value_)));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_Address &object) {
  ton_api::downcast_call(const_cast<ton_api::adnl_Address &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::adnl_address_udp &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.address.udp");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_address_udp6 &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.address.udp6");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_addressList &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.addressList");
  jo << ctie("addrs", ToJson(object.addrs_));
  jo << ctie("version", ToJson(object.version_));
  jo << ctie("reinit_date", ToJson(object.reinit_date_));
  jo << ctie("priority", ToJson(object.priority_));
  jo << ctie("expire_at", ToJson(object.expire_at_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_Message &object) {
  ton_api::downcast_call(const_cast<ton_api::adnl_Message &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_createChannel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.createChannel");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("date", ToJson(object.date_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_confirmChannel &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.confirmChannel");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("peer_key", ToJson(object.peer_key_));
  jo << ctie("date", ToJson(object.date_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_custom &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.custom");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_nop &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.nop");
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_reinit &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.reinit");
  jo << ctie("date", ToJson(object.date_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_query &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.query");
  jo << ctie("query_id", ToJson(object.query_id_));
  jo << ctie("query", ToJson(JsonBytes{object.query_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_answer &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.answer");
  jo << ctie("query_id", ToJson(object.query_id_));
  jo << ctie("answer", ToJson(JsonBytes{object.answer_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_message_part &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.message.part");
  jo << ctie("hash", ToJson(object.hash_));
  jo << ctie("total_size", ToJson(object.total_size_));
  jo << ctie("offset", ToJson(object.offset_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_node &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.node");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.addr_list_) {
    jo << ctie("addr_list", ToJson(object.addr_list_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::adnl_nodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.nodes");
  jo << ctie("nodes", ToJson(object.nodes_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_packetContents &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.packetContents");
  jo << ctie("rand1", ToJson(JsonBytes{object.rand1_}));
  if (object.flags_) {
    jo << ctie("flags", ToJson(object.flags_));
  }
  if (object.from_) {
    jo << ctie("from", ToJson(object.from_));
  }
  if (object.from_short_) {
    jo << ctie("from_short", ToJson(object.from_short_));
  }
  if (object.message_) {
    jo << ctie("message", ToJson(object.message_));
  }
  jo << ctie("messages", ToJson(object.messages_));
  if (object.address_) {
    jo << ctie("address", ToJson(object.address_));
  }
  if (object.priority_address_) {
    jo << ctie("priority_address", ToJson(object.priority_address_));
  }
  jo << ctie("seqno", ToJson(JsonInt64{object.seqno_}));
  jo << ctie("confirm_seqno", ToJson(JsonInt64{object.confirm_seqno_}));
  jo << ctie("recv_addr_list_version", ToJson(object.recv_addr_list_version_));
  jo << ctie("recv_priority_addr_list_version", ToJson(object.recv_priority_addr_list_version_));
  jo << ctie("reinit_date", ToJson(object.reinit_date_));
  jo << ctie("dst_reinit_date", ToJson(object.dst_reinit_date_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
  jo << ctie("rand2", ToJson(JsonBytes{object.rand2_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_pong &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.pong");
  jo << ctie("value", ToJson(JsonInt64{object.value_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_Proxy &object) {
  ton_api::downcast_call(const_cast<ton_api::adnl_Proxy &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::adnl_proxy_none &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.proxy.none");
}
void to_json(JsonValueScope &jv, const ton_api::adnl_proxy_fast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.proxy.fast");
  jo << ctie("shared_secret", ToJson(JsonBytes{object.shared_secret_}));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_proxyToFastHash &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.proxyToFastHash");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("date", ToJson(object.date_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("shared_secret", ToJson(object.shared_secret_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_proxyToFast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.proxyToFast");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("date", ToJson(object.date_));
  jo << ctie("signature", ToJson(object.signature_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.config.global");
  if (object.static_nodes_) {
    jo << ctie("static_nodes", ToJson(object.static_nodes_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::adnl_db_node_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.db.node.key");
  jo << ctie("local_id", ToJson(object.local_id_));
  jo << ctie("peer_id", ToJson(object.peer_id_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_db_node_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.db.node.value");
  jo << ctie("date", ToJson(object.date_));
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.addr_list_) {
    jo << ctie("addr_list", ToJson(object.addr_list_));
  }
  if (object.priority_addr_list_) {
    jo << ctie("priority_addr_list", ToJson(object.priority_addr_list_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::adnl_id_short &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.id.short");
  jo << ctie("id", ToJson(object.id_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block");
  jo << ctie("incarnation", ToJson(object.incarnation_));
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("height", ToJson(object.height_));
  if (object.data_) {
    jo << ctie("data", ToJson(object.data_));
  }
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_BlockResult &object) {
  ton_api::downcast_call(const_cast<ton_api::catchain_BlockResult &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::catchain_blockNotFound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.blockNotFound");
}
void to_json(JsonValueScope &jv, const ton_api::catchain_blockResult &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.blockResult");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::catchain_blocks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.blocks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_Difference &object) {
  ton_api::downcast_call(const_cast<ton_api::catchain_Difference &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::catchain_difference &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.difference");
  jo << ctie("sent_upto", ToJson(object.sent_upto_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_differenceFork &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.differenceFork");
  if (object.left_) {
    jo << ctie("left", ToJson(object.left_));
  }
  if (object.right_) {
    jo << ctie("right", ToJson(object.right_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::catchain_firstblock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.firstblock");
  jo << ctie("unique_hash", ToJson(object.unique_hash_));
  jo << ctie("nodes", ToJson(object.nodes_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_sent &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.sent");
  jo << ctie("cnt", ToJson(object.cnt_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_blockUpdate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.blockUpdate");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_data &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.data");
  if (object.prev_) {
    jo << ctie("prev", ToJson(object.prev_));
  }
  jo << ctie("deps", ToJson(object.deps_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_dep &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.dep");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("height", ToJson(object.height_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.id");
  jo << ctie("incarnation", ToJson(object.incarnation_));
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("height", ToJson(object.height_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_inner_Data &object) {
  ton_api::downcast_call(const_cast<ton_api::catchain_block_inner_Data &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_data_badBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.data.badBlock");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_data_fork &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.data.fork");
  if (object.left_) {
    jo << ctie("left", ToJson(object.left_));
  }
  if (object.right_) {
    jo << ctie("right", ToJson(object.right_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_data_nop &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.data.nop");
}
void to_json(JsonValueScope &jv, const ton_api::catchain_block_data_vector &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.block.data.vector");
  jo << ctie("msgs", ToJson(JsonVectorBytes(object.msgs_)));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.config.global");
  jo << ctie("tag", ToJson(object.tag_));
  jo << ctie("nodes", ToJson(object.nodes_));
}
void to_json(JsonValueScope &jv, const ton_api::config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "config.global");
  if (object.adnl_) {
    jo << ctie("adnl", ToJson(object.adnl_));
  }
  if (object.dht_) {
    jo << ctie("dht", ToJson(object.dht_));
  }
  if (object.validator_) {
    jo << ctie("validator", ToJson(object.validator_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "config.local");
  jo << ctie("local_ids", ToJson(object.local_ids_));
  jo << ctie("dht", ToJson(object.dht_));
  jo << ctie("validators", ToJson(object.validators_));
  jo << ctie("liteservers", ToJson(object.liteservers_));
  jo << ctie("control", ToJson(object.control_));
}
void to_json(JsonValueScope &jv, const ton_api::control_config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "control.config.local");
  if (object.priv_) {
    jo << ctie("priv", ToJson(object.priv_));
  }
  jo << ctie("pub", ToJson(object.pub_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::db_candidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.candidate");
  if (object.source_) {
    jo << ctie("source", ToJson(object.source_));
  }
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  jo << ctie("collated_data", ToJson(JsonBytes{object.collated_data_}));
}
void to_json(JsonValueScope &jv, const ton_api::db_block_Info &object) {
  ton_api::downcast_call(const_cast<ton_api::db_block_Info &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_block_info &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.block.info");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.flags_) {
    jo << ctie("flags", ToJson(object.flags_));
  }
  if (object.prev_left_) {
    jo << ctie("prev_left", ToJson(object.prev_left_));
  }
  if (object.prev_right_) {
    jo << ctie("prev_right", ToJson(object.prev_right_));
  }
  if (object.next_left_) {
    jo << ctie("next_left", ToJson(object.next_left_));
  }
  if (object.next_right_) {
    jo << ctie("next_right", ToJson(object.next_right_));
  }
  jo << ctie("lt", ToJson(JsonInt64{object.lt_}));
  jo << ctie("ts", ToJson(object.ts_));
  jo << ctie("state", ToJson(object.state_));
}
void to_json(JsonValueScope &jv, const ton_api::db_block_packedInfo &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.block.packedInfo");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("unixtime", ToJson(object.unixtime_));
  jo << ctie("offset", ToJson(JsonInt64{object.offset_}));
}
void to_json(JsonValueScope &jv, const ton_api::db_block_archivedInfo &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.block.archivedInfo");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.flags_) {
    jo << ctie("flags", ToJson(object.flags_));
  }
  if (object.next_) {
    jo << ctie("next", ToJson(object.next_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_blockdb_Key &object) {
  ton_api::downcast_call(const_cast<ton_api::db_blockdb_Key &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_blockdb_key_lru &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.blockdb.key.lru");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_blockdb_key_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.blockdb.key.value");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_blockdb_lru &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.blockdb.lru");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("prev", ToJson(object.prev_));
  jo << ctie("next", ToJson(object.next_));
}
void to_json(JsonValueScope &jv, const ton_api::db_blockdb_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.blockdb.value");
  if (object.next_) {
    jo << ctie("next", ToJson(object.next_));
  }
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::db_candidate_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.candidate.id");
  if (object.source_) {
    jo << ctie("source", ToJson(object.source_));
  }
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("collated_data_file_hash", ToJson(object.collated_data_file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::db_celldb_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.celldb.value");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
  jo << ctie("prev", ToJson(object.prev_));
  jo << ctie("next", ToJson(object.next_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::db_celldb_key_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.celldb.key.value");
  jo << ctie("hash", ToJson(object.hash_));
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_Key &object) {
  ton_api::downcast_call(const_cast<ton_api::db_filedb_Key &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_empty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.empty");
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_blockFile &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.blockFile");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_zeroStateFile &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.zeroStateFile");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_persistentStateFile &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.persistentStateFile");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
  if (object.masterchain_block_id_) {
    jo << ctie("masterchain_block_id", ToJson(object.masterchain_block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_proof &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.proof");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_proofLink &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.proofLink");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_signatures &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.signatures");
  if (object.block_id_) {
    jo << ctie("block_id", ToJson(object.block_id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_key_candidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.key.candidate");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_filedb_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.filedb.value");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
  jo << ctie("prev", ToJson(object.prev_));
  jo << ctie("next", ToJson(object.next_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_Key &object) {
  ton_api::downcast_call(const_cast<ton_api::db_lt_Key &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_el_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.el.key");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("idx", ToJson(object.idx_));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_desc_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.desc.key");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_shard_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.shard.key");
  jo << ctie("idx", ToJson(object.idx_));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_status_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.status.key");
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_desc_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.desc.value");
  jo << ctie("first_idx", ToJson(object.first_idx_));
  jo << ctie("last_idx", ToJson(object.last_idx_));
  jo << ctie("last_seqno", ToJson(object.last_seqno_));
  jo << ctie("last_lt", ToJson(JsonInt64{object.last_lt_}));
  jo << ctie("last_ts", ToJson(object.last_ts_));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_el_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.el.value");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("lt", ToJson(JsonInt64{object.lt_}));
  jo << ctie("ts", ToJson(object.ts_));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_shard_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.shard.value");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
}
void to_json(JsonValueScope &jv, const ton_api::db_lt_status_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.lt.status.value");
  jo << ctie("total_shards", ToJson(object.total_shards_));
}
void to_json(JsonValueScope &jv, const ton_api::db_root_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.root.config");
  jo << ctie("celldb_version", ToJson(object.celldb_version_));
  jo << ctie("blockdb_version", ToJson(object.blockdb_version_));
}
void to_json(JsonValueScope &jv, const ton_api::db_root_dbDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.root.dbDescription");
  jo << ctie("version", ToJson(object.version_));
  if (object.first_masterchain_block_id_) {
    jo << ctie("first_masterchain_block_id", ToJson(object.first_masterchain_block_id_));
  }
  jo << ctie("flags", ToJson(object.flags_));
}
void to_json(JsonValueScope &jv, const ton_api::db_root_Key &object) {
  ton_api::downcast_call(const_cast<ton_api::db_root_Key &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_root_key_cellDb &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.root.key.cellDb");
  jo << ctie("version", ToJson(object.version_));
}
void to_json(JsonValueScope &jv, const ton_api::db_root_key_blockDb &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.root.key.blockDb");
  jo << ctie("version", ToJson(object.version_));
}
void to_json(JsonValueScope &jv, const ton_api::db_root_key_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.root.key.config");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_asyncSerializer &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.asyncSerializer");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  if (object.last_) {
    jo << ctie("last", ToJson(object.last_));
  }
  jo << ctie("last_ts", ToJson(object.last_ts_));
}
void to_json(JsonValueScope &jv, const ton_api::db_state_destroyedSessions &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.destroyedSessions");
  jo << ctie("sessions", ToJson(object.sessions_));
}
void to_json(JsonValueScope &jv, const ton_api::db_state_gcBlockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.gcBlockId");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_state_hardforks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.hardforks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::db_state_initBlockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.initBlockId");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::db_state_Key &object) {
  ton_api::downcast_call(const_cast<ton_api::db_state_Key &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_destroyedSessions &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.destroyedSessions");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_initBlockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.initBlockId");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_gcBlockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.gcBlockId");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_shardClient &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.shardClient");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_asyncSerializer &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.asyncSerializer");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_key_hardforks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.key.hardforks");
}
void to_json(JsonValueScope &jv, const ton_api::db_state_shardClient &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "db.state.shardClient");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_key &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.key");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("name", ToJson(JsonBytes{object.name_}));
  jo << ctie("idx", ToJson(object.idx_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_keyDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.keyDescription");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.update_rule_) {
    jo << ctie("update_rule", ToJson(object.update_rule_));
  }
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::dht_message &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.message");
  if (object.node_) {
    jo << ctie("node", ToJson(object.node_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_node &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.node");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  if (object.addr_list_) {
    jo << ctie("addr_list", ToJson(object.addr_list_));
  }
  jo << ctie("version", ToJson(object.version_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::dht_nodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.nodes");
  jo << ctie("nodes", ToJson(object.nodes_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_pong &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.pong");
  jo << ctie("random_id", ToJson(JsonInt64{object.random_id_}));
}
void to_json(JsonValueScope &jv, const ton_api::dht_stored &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.stored");
}
void to_json(JsonValueScope &jv, const ton_api::dht_UpdateRule &object) {
  ton_api::downcast_call(const_cast<ton_api::dht_UpdateRule &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::dht_updateRule_signature &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.updateRule.signature");
}
void to_json(JsonValueScope &jv, const ton_api::dht_updateRule_anybody &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.updateRule.anybody");
}
void to_json(JsonValueScope &jv, const ton_api::dht_updateRule_overlayNodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.updateRule.overlayNodes");
}
void to_json(JsonValueScope &jv, const ton_api::dht_value &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.value");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
  jo << ctie("value", ToJson(JsonBytes{object.value_}));
  jo << ctie("ttl", ToJson(object.ttl_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::dht_ValueResult &object) {
  ton_api::downcast_call(const_cast<ton_api::dht_ValueResult &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::dht_valueNotFound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.valueNotFound");
  if (object.nodes_) {
    jo << ctie("nodes", ToJson(object.nodes_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_valueFound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.valueFound");
  if (object.value_) {
    jo << ctie("value", ToJson(object.value_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.config.global");
  if (object.static_nodes_) {
    jo << ctie("static_nodes", ToJson(object.static_nodes_));
  }
  jo << ctie("k", ToJson(object.k_));
  jo << ctie("a", ToJson(object.a_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_config_Local &object) {
  ton_api::downcast_call(const_cast<ton_api::dht_config_Local &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::dht_config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.config.local");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_config_random_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.config.random.local");
  jo << ctie("cnt", ToJson(object.cnt_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_db_bucket &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.db.bucket");
  if (object.nodes_) {
    jo << ctie("nodes", ToJson(object.nodes_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_db_key_bucket &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.db.key.bucket");
  jo << ctie("id", ToJson(object.id_));
}
void to_json(JsonValueScope &jv, const ton_api::dummyworkchain0_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dummyworkchain0.config.global");
  jo << ctie("zero_state_hash", ToJson(object.zero_state_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_Addr &object) {
  ton_api::downcast_call(const_cast<ton_api::engine_Addr &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::engine_addr &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.addr");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_addrProxy &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.addrProxy");
  jo << ctie("in_ip", ToJson(object.in_ip_));
  jo << ctie("in_port", ToJson(object.in_port_));
  jo << ctie("out_ip", ToJson(object.out_ip_));
  jo << ctie("out_port", ToJson(object.out_port_));
  if (object.proxy_type_) {
    jo << ctie("proxy_type", ToJson(object.proxy_type_));
  }
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_adnl &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.adnl");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("category", ToJson(object.category_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_controlInterface &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.controlInterface");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("allowed", ToJson(object.allowed_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_controlProcess &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.controlProcess");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("permissions", ToJson(object.permissions_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_dht &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.dht");
  jo << ctie("id", ToJson(object.id_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_gc &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.gc");
  jo << ctie("ids", ToJson(object.ids_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_liteServer &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.liteServer");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("temp_keys", ToJson(object.temp_keys_));
  jo << ctie("adnl_addrs", ToJson(object.adnl_addrs_));
  jo << ctie("election_date", ToJson(object.election_date_));
  jo << ctie("expire_at", ToJson(object.expire_at_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validatorAdnlAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validatorAdnlAddress");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("expire_at", ToJson(object.expire_at_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validatorTempKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validatorTempKey");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("expire_at", ToJson(object.expire_at_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_adnlProxy_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.adnlProxy.config");
  jo << ctie("ports", ToJson(object.ports_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_adnlProxy_port &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.adnlProxy.port");
  jo << ctie("in_port", ToJson(object.in_port_));
  jo << ctie("out_port", ToJson(object.out_port_));
  jo << ctie("dst_ip", ToJson(object.dst_ip_));
  jo << ctie("dst_port", ToJson(object.dst_port_));
  if (object.proxy_type_) {
    jo << ctie("proxy_type", ToJson(object.proxy_type_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::engine_dht_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.dht.config");
  jo << ctie("dht", ToJson(object.dht_));
  if (object.gc_) {
    jo << ctie("gc", ToJson(object.gc_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.config");
  jo << ctie("out_port", ToJson(object.out_port_));
  jo << ctie("addrs", ToJson(object.addrs_));
  jo << ctie("adnl", ToJson(object.adnl_));
  jo << ctie("dht", ToJson(object.dht_));
  jo << ctie("validators", ToJson(object.validators_));
  jo << ctie("fullnode", ToJson(object.fullnode_));
  jo << ctie("fullnodeslaves", ToJson(object.fullnodeslaves_));
  jo << ctie("fullnodemasters", ToJson(object.fullnodemasters_));
  jo << ctie("liteservers", ToJson(object.liteservers_));
  jo << ctie("control", ToJson(object.control_));
  if (object.gc_) {
    jo << ctie("gc", ToJson(object.gc_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_controlQueryError &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.controlQueryError");
  jo << ctie("code", ToJson(object.code_));
  jo << ctie("message", ToJson(object.message_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_dhtServerStatus &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.dhtServerStatus");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("status", ToJson(object.status_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_dhtServersStatus &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.dhtServersStatus");
  jo << ctie("servers", ToJson(object.servers_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_electionBid &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.electionBid");
  jo << ctie("election_date", ToJson(object.election_date_));
  jo << ctie("perm_key", ToJson(object.perm_key_));
  jo << ctie("adnl_addr", ToJson(object.adnl_addr_));
  jo << ctie("to_send_payload", ToJson(JsonBytes{object.to_send_payload_}));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_fullNodeMaster &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.fullNodeMaster");
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("adnl", ToJson(object.adnl_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_fullNodeSlave &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.fullNodeSlave");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  if (object.adnl_) {
    jo << ctie("adnl", ToJson(object.adnl_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::validator_groupMember &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.groupMember");
  jo << ctie("public_key_hash", ToJson(object.public_key_hash_));
  jo << ctie("adnl", ToJson(object.adnl_));
  jo << ctie("weight", ToJson(JsonInt64{object.weight_}));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_jsonConfig &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.jsonConfig");
  jo << ctie("data", ToJson(object.data_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_keyHash &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.keyHash");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_oneStat &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.oneStat");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("value", ToJson(object.value_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_signature &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.signature");
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_stats &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.stats");
  jo << ctie("stats", ToJson(object.stats_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_success &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.success");
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_time &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.time");
  jo << ctie("time", ToJson(object.time_));
}
void to_json(JsonValueScope &jv, const ton_api::fec_Type &object) {
  ton_api::downcast_call(const_cast<ton_api::fec_Type &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::fec_raptorQ &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "fec.raptorQ");
  jo << ctie("data_size", ToJson(object.data_size_));
  jo << ctie("symbol_size", ToJson(object.symbol_size_));
  jo << ctie("symbols_count", ToJson(object.symbols_count_));
}
void to_json(JsonValueScope &jv, const ton_api::fec_roundRobin &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "fec.roundRobin");
  jo << ctie("data_size", ToJson(object.data_size_));
  jo << ctie("symbol_size", ToJson(object.symbol_size_));
  jo << ctie("symbols_count", ToJson(object.symbols_count_));
}
void to_json(JsonValueScope &jv, const ton_api::fec_online &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "fec.online");
  jo << ctie("data_size", ToJson(object.data_size_));
  jo << ctie("symbol_size", ToJson(object.symbol_size_));
  jo << ctie("symbols_count", ToJson(object.symbols_count_));
}
void to_json(JsonValueScope &jv, const ton_api::id_config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "id.config.local");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::liteclient_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "liteclient.config.global");
  jo << ctie("liteservers", ToJson(object.liteservers_));
  if (object.validator_) {
    jo << ctie("validator", ToJson(object.validator_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::liteserver_desc &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "liteserver.desc");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::liteserver_config_Local &object) {
  ton_api::downcast_call(const_cast<ton_api::liteserver_config_Local &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::liteserver_config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "liteserver.config.local");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::liteserver_config_random_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "liteserver.config.random.local");
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_Broadcast &object) {
  ton_api::downcast_call(const_cast<ton_api::overlay_Broadcast &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::overlay_fec_received &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.fec.received");
  jo << ctie("hash", ToJson(object.hash_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_fec_completed &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.fec.completed");
  jo << ctie("hash", ToJson(object.hash_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_unicast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.unicast");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcast");
  if (object.src_) {
    jo << ctie("src", ToJson(object.src_));
  }
  if (object.certificate_) {
    jo << ctie("certificate", ToJson(object.certificate_));
  }
  jo << ctie("flags", ToJson(object.flags_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  jo << ctie("date", ToJson(object.date_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastFec &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastFec");
  if (object.src_) {
    jo << ctie("src", ToJson(object.src_));
  }
  if (object.certificate_) {
    jo << ctie("certificate", ToJson(object.certificate_));
  }
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("data_size", ToJson(object.data_size_));
  jo << ctie("flags", ToJson(object.flags_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  if (object.fec_) {
    jo << ctie("fec", ToJson(object.fec_));
  }
  jo << ctie("date", ToJson(object.date_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastFecShort &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastFecShort");
  if (object.src_) {
    jo << ctie("src", ToJson(object.src_));
  }
  if (object.certificate_) {
    jo << ctie("certificate", ToJson(object.certificate_));
  }
  jo << ctie("broadcast_hash", ToJson(object.broadcast_hash_));
  jo << ctie("part_data_hash", ToJson(object.part_data_hash_));
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastNotFound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastNotFound");
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastList &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastList");
  jo << ctie("hashes", ToJson(object.hashes_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_Certificate &object) {
  ton_api::downcast_call(const_cast<ton_api::overlay_Certificate &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::overlay_certificate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.certificate");
  if (object.issued_by_) {
    jo << ctie("issued_by", ToJson(object.issued_by_));
  }
  jo << ctie("expire_at", ToJson(object.expire_at_));
  jo << ctie("max_size", ToJson(object.max_size_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_emptyCertificate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.emptyCertificate");
}
void to_json(JsonValueScope &jv, const ton_api::overlay_certificateId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.certificateId");
  jo << ctie("overlay_id", ToJson(object.overlay_id_));
  jo << ctie("node", ToJson(object.node_));
  jo << ctie("expire_at", ToJson(object.expire_at_));
  jo << ctie("max_size", ToJson(object.max_size_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_message &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.message");
  jo << ctie("overlay", ToJson(object.overlay_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_node &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.node");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("overlay", ToJson(object.overlay_));
  jo << ctie("version", ToJson(object.version_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_nodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.nodes");
  jo << ctie("nodes", ToJson(object.nodes_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcast_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcast.id");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("flags", ToJson(object.flags_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcast_toSign &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcast.toSign");
  jo << ctie("hash", ToJson(object.hash_));
  jo << ctie("date", ToJson(object.date_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastFec_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastFec.id");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("type", ToJson(object.type_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("size", ToJson(object.size_));
  jo << ctie("flags", ToJson(object.flags_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_broadcastFec_partId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.broadcastFec.partId");
  jo << ctie("broadcast_hash", ToJson(object.broadcast_hash_));
  jo << ctie("data_hash", ToJson(object.data_hash_));
  jo << ctie("seqno", ToJson(object.seqno_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_db_key_nodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.db.key.nodes");
  jo << ctie("local_id", ToJson(object.local_id_));
  jo << ctie("overlay", ToJson(object.overlay_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_db_nodes &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.db.nodes");
  if (object.nodes_) {
    jo << ctie("nodes", ToJson(object.nodes_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::overlay_node_toSign &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.node.toSign");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("overlay", ToJson(object.overlay_));
  jo << ctie("version", ToJson(object.version_));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_Message &object) {
  ton_api::downcast_call(const_cast<ton_api::rldp_Message &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::rldp_message &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.message");
  jo << ctie("id", ToJson(object.id_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_query &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.query");
  jo << ctie("query_id", ToJson(object.query_id_));
  jo << ctie("max_answer_size", ToJson(JsonInt64{object.max_answer_size_}));
  jo << ctie("timeout", ToJson(object.timeout_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_answer &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.answer");
  jo << ctie("query_id", ToJson(object.query_id_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_MessagePart &object) {
  ton_api::downcast_call(const_cast<ton_api::rldp_MessagePart &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::rldp_messagePart &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.messagePart");
  jo << ctie("transfer_id", ToJson(object.transfer_id_));
  if (object.fec_type_) {
    jo << ctie("fec_type", ToJson(object.fec_type_));
  }
  jo << ctie("part", ToJson(object.part_));
  jo << ctie("total_size", ToJson(JsonInt64{object.total_size_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_confirm &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.confirm");
  jo << ctie("transfer_id", ToJson(object.transfer_id_));
  jo << ctie("part", ToJson(object.part_));
  jo << ctie("seqno", ToJson(object.seqno_));
}
void to_json(JsonValueScope &jv, const ton_api::rldp_complete &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "rldp.complete");
  jo << ctie("transfer_id", ToJson(object.transfer_id_));
  jo << ctie("part", ToJson(object.part_));
}
void to_json(JsonValueScope &jv, const ton_api::tcp_Message &object) {
  ton_api::downcast_call(const_cast<ton_api::tcp_Message &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tcp_authentificate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tcp.authentificate");
  jo << ctie("nonce", ToJson(JsonBytes{object.nonce_}));
}
void to_json(JsonValueScope &jv, const ton_api::tcp_authentificationNonce &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tcp.authentificationNonce");
  jo << ctie("nonce", ToJson(JsonBytes{object.nonce_}));
}
void to_json(JsonValueScope &jv, const ton_api::tcp_authentificationComplete &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tcp.authentificationComplete");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::tcp_pong &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tcp.pong");
  jo << ctie("random_id", ToJson(JsonInt64{object.random_id_}));
}
void to_json(JsonValueScope &jv, const ton_api::ton_BlockId &object) {
  ton_api::downcast_call(const_cast<ton_api::ton_BlockId &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::ton_blockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "ton.blockId");
  jo << ctie("root_cell_hash", ToJson(object.root_cell_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::ton_blockIdApprove &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "ton.blockIdApprove");
  jo << ctie("root_cell_hash", ToJson(object.root_cell_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_BlockDescription &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_BlockDescription &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockDescriptionEmpty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockDescriptionEmpty");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockDescription");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockId");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("seqno", ToJson(object.seqno_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockIdExt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockIdExt");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("seqno", ToJson(object.seqno_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockSignature &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockSignature");
  jo << ctie("who", ToJson(object.who_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blocksDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blocksDescription");
  jo << ctie("ids", ToJson(object.ids_));
  jo << ctie("incomplete", ToJson(object.incomplete_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_Broadcast &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_Broadcast &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_blockBroadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.blockBroadcast");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("catchain_seqno", ToJson(object.catchain_seqno_));
  jo << ctie("validator_set_hash", ToJson(object.validator_set_hash_));
  jo << ctie("signatures", ToJson(object.signatures_));
  jo << ctie("proof", ToJson(JsonBytes{object.proof_}));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_ihrMessageBroadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.ihrMessageBroadcast");
  if (object.message_) {
    jo << ctie("message", ToJson(object.message_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_externalMessageBroadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.externalMessageBroadcast");
  if (object.message_) {
    jo << ctie("message", ToJson(object.message_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_newShardBlockBroadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.newShardBlockBroadcast");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_capabilities &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.capabilities");
  jo << ctie("version", ToJson(object.version_));
  jo << ctie("capabilities", ToJson(JsonInt64{object.capabilities_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_data &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.data");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_DataFull &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_DataFull &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_dataFull &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.dataFull");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
  jo << ctie("proof", ToJson(JsonBytes{object.proof_}));
  jo << ctie("block", ToJson(JsonBytes{object.block_}));
  jo << ctie("is_link", ToJson(object.is_link_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_dataFullEmpty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.dataFullEmpty");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_dataList &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.dataList");
  jo << ctie("data", ToJson(JsonVectorBytes(object.data_)));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_externalMessage &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.externalMessage");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_ihrMessage &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.ihrMessage");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_keyBlocks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.keyBlocks");
  jo << ctie("blocks", ToJson(object.blocks_));
  jo << ctie("incomplete", ToJson(object.incomplete_));
  jo << ctie("error", ToJson(object.error_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_newShardBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.newShardBlock");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  jo << ctie("cc_seqno", ToJson(object.cc_seqno_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_Prepared &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_Prepared &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepared &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepared");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_notFound &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.notFound");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_PreparedProof &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_PreparedProof &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_preparedProofEmpty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.preparedProofEmpty");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_preparedProof &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.preparedProof");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_preparedProofLink &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.preparedProofLink");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_PreparedState &object) {
  ton_api::downcast_call(const_cast<ton_api::tonNode_PreparedState &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_preparedState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.preparedState");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_notFoundState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.notFoundState");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_sessionId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.sessionId");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("cc_seqno", ToJson(object.cc_seqno_));
  jo << ctie("opts_hash", ToJson(object.opts_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_shardPublicOverlayId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.shardPublicOverlayId");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("zero_state_file_hash", ToJson(object.zero_state_file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_success &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.success");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_zeroStateIdExt &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.zeroStateIdExt");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::validator_Group &object) {
  ton_api::downcast_call(const_cast<ton_api::validator_Group &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::validator_group &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.group");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("catchain_seqno", ToJson(object.catchain_seqno_));
  jo << ctie("config_hash", ToJson(object.config_hash_));
  jo << ctie("members", ToJson(object.members_));
}
void to_json(JsonValueScope &jv, const ton_api::validator_groupEx &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.groupEx");
  jo << ctie("workchain", ToJson(object.workchain_));
  jo << ctie("shard", ToJson(JsonInt64{object.shard_}));
  jo << ctie("vertical_seqno", ToJson(object.vertical_seqno_));
  jo << ctie("catchain_seqno", ToJson(object.catchain_seqno_));
  jo << ctie("config_hash", ToJson(object.config_hash_));
  jo << ctie("members", ToJson(object.members_));
}
void to_json(JsonValueScope &jv, const ton_api::validator_config_global &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.config.global");
  if (object.zero_state_) {
    jo << ctie("zero_state", ToJson(object.zero_state_));
  }
  if (object.init_block_) {
    jo << ctie("init_block", ToJson(object.init_block_));
  }
  jo << ctie("hardforks", ToJson(object.hardforks_));
}
void to_json(JsonValueScope &jv, const ton_api::validator_config_Local &object) {
  ton_api::downcast_call(const_cast<ton_api::validator_config_Local &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::validator_config_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.config.local");
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::validator_config_random_local &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validator.config.random.local");
  if (object.addr_list_) {
    jo << ctie("addr_list", ToJson(object.addr_list_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_blockUpdate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.blockUpdate");
  jo << ctie("ts", ToJson(JsonInt64{object.ts_}));
  jo << ctie("actions", ToJson(object.actions_));
  jo << ctie("state", ToJson(object.state_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_candidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.candidate");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
  jo << ctie("collated_data", ToJson(JsonBytes{object.collated_data_}));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_candidateId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.candidateId");
  jo << ctie("src", ToJson(object.src_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
  jo << ctie("collated_data_file_hash", ToJson(object.collated_data_file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_config &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.config");
  jo << ctie("catchain_idle_timeout", ToJson(object.catchain_idle_timeout_));
  jo << ctie("catchain_max_deps", ToJson(object.catchain_max_deps_));
  jo << ctie("round_candidates", ToJson(object.round_candidates_));
  jo << ctie("next_candidate_delay", ToJson(object.next_candidate_delay_));
  jo << ctie("round_attempt_duration", ToJson(object.round_attempt_duration_));
  jo << ctie("max_round_attempts", ToJson(object.max_round_attempts_));
  jo << ctie("max_block_size", ToJson(object.max_block_size_));
  jo << ctie("max_collated_data_size", ToJson(object.max_collated_data_size_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_Message &object) {
  ton_api::downcast_call(const_cast<ton_api::validatorSession_Message &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_startSession &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.startSession");
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_finishSession &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.finishSession");
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_pong &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.pong");
  jo << ctie("hash", ToJson(JsonInt64{object.hash_}));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_round_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.round.id");
  jo << ctie("session", ToJson(object.session_));
  jo << ctie("height", ToJson(JsonInt64{object.height_}));
  jo << ctie("prev_block", ToJson(object.prev_block_));
  jo << ctie("seqno", ToJson(object.seqno_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_round_Message &object) {
  ton_api::downcast_call(const_cast<ton_api::validatorSession_round_Message &>(object), [&jv](const auto &object) { to_json(jv, object); });
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_submittedBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.submittedBlock");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("root_hash", ToJson(object.root_hash_));
  jo << ctie("file_hash", ToJson(object.file_hash_));
  jo << ctie("collated_data_file_hash", ToJson(object.collated_data_file_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_approvedBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.approvedBlock");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("candidate", ToJson(object.candidate_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_rejectedBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.rejectedBlock");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("candidate", ToJson(object.candidate_));
  jo << ctie("reason", ToJson(JsonBytes{object.reason_}));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_commit &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.commit");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("candidate", ToJson(object.candidate_));
  jo << ctie("signature", ToJson(JsonBytes{object.signature_}));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_vote &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.vote");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("attempt", ToJson(object.attempt_));
  jo << ctie("candidate", ToJson(object.candidate_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_voteFor &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.voteFor");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("attempt", ToJson(object.attempt_));
  jo << ctie("candidate", ToJson(object.candidate_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_precommit &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.precommit");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("attempt", ToJson(object.attempt_));
  jo << ctie("candidate", ToJson(object.candidate_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_message_empty &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.message.empty");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("attempt", ToJson(object.attempt_));
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_candidate_id &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.candidate.id");
  jo << ctie("round", ToJson(object.round_));
  jo << ctie("block_hash", ToJson(object.block_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::adnl_ping &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "adnl.ping");
  jo << ctie("value", ToJson(JsonInt64{object.value_}));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_getBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.getBlock");
  jo << ctie("block", ToJson(object.block_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_getBlockHistory &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.getBlockHistory");
  jo << ctie("block", ToJson(object.block_));
  jo << ctie("height", ToJson(JsonInt64{object.height_}));
  jo << ctie("stop_if", ToJson(object.stop_if_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_getBlocks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.getBlocks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::catchain_getDifference &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "catchain.getDifference");
  jo << ctie("rt", ToJson(object.rt_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_findNode &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.findNode");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("k", ToJson(object.k_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_findValue &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.findValue");
  jo << ctie("key", ToJson(object.key_));
  jo << ctie("k", ToJson(object.k_));
}
void to_json(JsonValueScope &jv, const ton_api::dht_getSignedAddressList &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.getSignedAddressList");
}
void to_json(JsonValueScope &jv, const ton_api::dht_ping &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.ping");
  jo << ctie("random_id", ToJson(JsonInt64{object.random_id_}));
}
void to_json(JsonValueScope &jv, const ton_api::dht_query &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.query");
  if (object.node_) {
    jo << ctie("node", ToJson(object.node_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::dht_store &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "dht.store");
  if (object.value_) {
    jo << ctie("value", ToJson(object.value_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addAdnlId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addAdnlId");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("category", ToJson(object.category_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addControlInterface &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addControlInterface");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addControlProcess &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addControlProcess");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("peer_key", ToJson(object.peer_key_));
  jo << ctie("permissions", ToJson(object.permissions_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addDhtId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addDhtId");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addListeningPort &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addListeningPort");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addLiteserver &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addLiteserver");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("port", ToJson(object.port_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addProxy &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addProxy");
  jo << ctie("in_ip", ToJson(object.in_ip_));
  jo << ctie("in_port", ToJson(object.in_port_));
  jo << ctie("out_ip", ToJson(object.out_ip_));
  jo << ctie("out_port", ToJson(object.out_port_));
  if (object.proxy_) {
    jo << ctie("proxy", ToJson(object.proxy_));
  }
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addValidatorAdnlAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addValidatorAdnlAddress");
  jo << ctie("permanent_key_hash", ToJson(object.permanent_key_hash_));
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("ttl", ToJson(object.ttl_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addValidatorPermanentKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addValidatorPermanentKey");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("election_date", ToJson(object.election_date_));
  jo << ctie("ttl", ToJson(object.ttl_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_addValidatorTempKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.addValidatorTempKey");
  jo << ctie("permanent_key_hash", ToJson(object.permanent_key_hash_));
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("ttl", ToJson(object.ttl_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_changeFullNodeAdnlAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.changeFullNodeAdnlAddress");
  jo << ctie("adnl_id", ToJson(object.adnl_id_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_checkDhtServers &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.checkDhtServers");
  jo << ctie("id", ToJson(object.id_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_controlQuery &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.controlQuery");
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_createElectionBid &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.createElectionBid");
  jo << ctie("election_date", ToJson(object.election_date_));
  jo << ctie("election_addr", ToJson(object.election_addr_));
  jo << ctie("wallet", ToJson(object.wallet_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delAdnlId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delAdnlId");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delDhtId &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delDhtId");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delListeningPort &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delListeningPort");
  jo << ctie("ip", ToJson(object.ip_));
  jo << ctie("port", ToJson(object.port_));
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delProxy &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delProxy");
  jo << ctie("out_ip", ToJson(object.out_ip_));
  jo << ctie("out_port", ToJson(object.out_port_));
  jo << ctie("categories", ToJson(object.categories_));
  jo << ctie("priority_categories", ToJson(object.priority_categories_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delValidatorAdnlAddress &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delValidatorAdnlAddress");
  jo << ctie("permanent_key_hash", ToJson(object.permanent_key_hash_));
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delValidatorPermanentKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delValidatorPermanentKey");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_delValidatorTempKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.delValidatorTempKey");
  jo << ctie("permanent_key_hash", ToJson(object.permanent_key_hash_));
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_exportPrivateKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.exportPrivateKey");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_exportPublicKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.exportPublicKey");
  jo << ctie("key_hash", ToJson(object.key_hash_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_generateKeyPair &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.generateKeyPair");
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_getConfig &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.getConfig");
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_getStats &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.getStats");
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_getTime &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.getTime");
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_importPrivateKey &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.importPrivateKey");
  if (object.key_) {
    jo << ctie("key", ToJson(object.key_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_setVerbosity &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.setVerbosity");
  jo << ctie("verbosity", ToJson(object.verbosity_));
}
void to_json(JsonValueScope &jv, const ton_api::engine_validator_sign &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "engine.validator.sign");
  jo << ctie("key_hash", ToJson(object.key_hash_));
  jo << ctie("data", ToJson(JsonBytes{object.data_}));
}
void to_json(JsonValueScope &jv, const ton_api::getTestObject &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "getTestObject");
}
void to_json(JsonValueScope &jv, const ton_api::overlay_getBroadcast &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.getBroadcast");
  jo << ctie("hash", ToJson(object.hash_));
}
void to_json(JsonValueScope &jv, const ton_api::overlay_getBroadcastList &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.getBroadcastList");
  if (object.list_) {
    jo << ctie("list", ToJson(object.list_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::overlay_getRandomPeers &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.getRandomPeers");
  if (object.peers_) {
    jo << ctie("peers", ToJson(object.peers_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::overlay_query &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "overlay.query");
  jo << ctie("overlay", ToJson(object.overlay_));
}
void to_json(JsonValueScope &jv, const ton_api::tcp_ping &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tcp.ping");
  jo << ctie("random_id", ToJson(JsonInt64{object.random_id_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlock");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlockFull &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlockFull");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlockProof &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlockProof");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlockProofLink &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlockProofLink");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlockProofLinks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlockProofLinks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlockProofs &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlockProofs");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadBlocks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadBlocks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadNextBlockFull &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadNextBlockFull");
  if (object.prev_block_) {
    jo << ctie("prev_block", ToJson(object.prev_block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadPersistentState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadPersistentState");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  if (object.masterchain_block_) {
    jo << ctie("masterchain_block", ToJson(object.masterchain_block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadPersistentStateSlice &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadPersistentStateSlice");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  if (object.masterchain_block_) {
    jo << ctie("masterchain_block", ToJson(object.masterchain_block_));
  }
  jo << ctie("offset", ToJson(JsonInt64{object.offset_}));
  jo << ctie("max_size", ToJson(JsonInt64{object.max_size_}));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_downloadZeroState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.downloadZeroState");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_getCapabilities &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.getCapabilities");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_getNextBlockDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.getNextBlockDescription");
  if (object.prev_block_) {
    jo << ctie("prev_block", ToJson(object.prev_block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_getNextBlocksDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.getNextBlocksDescription");
  if (object.prev_block_) {
    jo << ctie("prev_block", ToJson(object.prev_block_));
  }
  jo << ctie("limit", ToJson(object.limit_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_getNextKeyBlockIds &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.getNextKeyBlockIds");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  jo << ctie("max_size", ToJson(object.max_size_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_getPrevBlocksDescription &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.getPrevBlocksDescription");
  if (object.next_block_) {
    jo << ctie("next_block", ToJson(object.next_block_));
  }
  jo << ctie("limit", ToJson(object.limit_));
  jo << ctie("cutoff_seqno", ToJson(object.cutoff_seqno_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepareBlock &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepareBlock");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepareBlockProof &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepareBlockProof");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  jo << ctie("allow_partial", ToJson(object.allow_partial_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepareBlockProofs &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepareBlockProofs");
  jo << ctie("blocks", ToJson(object.blocks_));
  jo << ctie("allow_partial", ToJson(object.allow_partial_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepareBlocks &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepareBlocks");
  jo << ctie("blocks", ToJson(object.blocks_));
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_preparePersistentState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.preparePersistentState");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
  if (object.masterchain_block_) {
    jo << ctie("masterchain_block", ToJson(object.masterchain_block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_prepareZeroState &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.prepareZeroState");
  if (object.block_) {
    jo << ctie("block", ToJson(object.block_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_query &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.query");
}
void to_json(JsonValueScope &jv, const ton_api::tonNode_slave_sendExtMessage &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "tonNode.slave.sendExtMessage");
  if (object.message_) {
    jo << ctie("message", ToJson(object.message_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_downloadCandidate &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.downloadCandidate");
  jo << ctie("round", ToJson(object.round_));
  if (object.id_) {
    jo << ctie("id", ToJson(object.id_));
  }
}
void to_json(JsonValueScope &jv, const ton_api::validatorSession_ping &object) {
  auto jo = jv.enter_object();
  jo << ctie("@type", "validatorSession.ping");
  jo << ctie("hash", ToJson(JsonInt64{object.hash_}));
}
}  // namespace ton_api
}  // namespace ton
