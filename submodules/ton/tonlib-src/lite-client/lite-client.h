/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once
#include "adnl/adnl-ext-client.h"
#include "tl-utils/tl-utils.hpp"
#include "ton/ton-types.h"
#include "terminal/terminal.h"
#include "vm/cells.h"
#include "vm/stack.hpp"
#include "block/block.h"
#include "td/utils/filesystem.h"

using td::Ref;

class TestNode : public td::actor::Actor {
 private:
  std::string global_config_ = "ton-global.config";
  enum {
    min_ls_version = 0x101,
    min_ls_capabilities = 1
  };  // server version >= 1.1, capabilities at least +1 = build proof chains
  td::actor::ActorOwn<ton::adnl::AdnlExtClient> client_;
  td::actor::ActorOwn<td::TerminalIO> io_;

  bool readline_enabled_ = true;
  bool server_ok_ = false;
  td::int32 liteserver_idx_ = -1;
  int print_limit_ = 1024;

  bool ready_ = false;
  bool inited_ = false;
  std::string db_root_;

  int server_time_ = 0;
  int server_time_got_at_ = 0;
  int server_version_ = 0;
  long long server_capabilities_ = 0;

  ton::ZeroStateIdExt zstate_id_;
  ton::BlockIdExt mc_last_id_;

  ton::BlockIdExt last_block_id_, last_state_id_;
  td::BufferSlice last_block_data_, last_state_data_;

  ton::StdSmcAddress dns_root_;
  bool dns_root_queried_{false};

  std::string line_;
  const char *parse_ptr_, *parse_end_;
  td::Status error_;

  td::IPAddress remote_addr_;
  ton::PublicKey remote_public_key_;

  std::vector<ton::BlockIdExt> known_blk_ids_;
  std::size_t shown_blk_ids_ = 0;

  td::Timestamp fail_timeout_;
  td::uint32 running_queries_ = 0;
  bool ex_mode_ = false;
  std::vector<td::BufferSlice> ex_queries_;

  std::map<td::Bits256, Ref<vm::Cell>> cell_cache_;

  std::unique_ptr<ton::adnl::AdnlExtClient::Callback> make_callback();

  struct TransId {
    ton::Bits256 acc_addr;
    ton::LogicalTime trans_lt;
    ton::Bits256 trans_hash;
    TransId(const ton::Bits256& addr_, ton::LogicalTime lt_, const ton::Bits256& hash_)
        : acc_addr(addr_), trans_lt(lt_), trans_hash(hash_) {
    }
  };

  void run_init_queries();
  char cur() const {
    return *parse_ptr_;
  }
  bool get_server_time();
  bool get_server_version(int mode = 0);
  void got_server_version(td::Result<td::BufferSlice> res, int mode);
  bool get_server_mc_block_id();
  void got_server_mc_block_id(ton::BlockIdExt blkid, ton::ZeroStateIdExt zstateid, int created_at);
  void got_server_mc_block_id_ext(ton::BlockIdExt blkid, ton::ZeroStateIdExt zstateid, int mode, int version,
                                  long long capabilities, int last_utime, int server_now);
  void set_server_version(td::int32 version, td::int64 capabilities);
  void set_server_time(int server_utime);
  bool request_block(ton::BlockIdExt blkid);
  bool request_state(ton::BlockIdExt blkid);
  void got_mc_block(ton::BlockIdExt blkid, td::BufferSlice data);
  void got_mc_state(ton::BlockIdExt blkid, ton::RootHash root_hash, ton::FileHash file_hash, td::BufferSlice data);
  td::Status send_ext_msg_from_filename(std::string filename);
  td::Status save_db_file(ton::FileHash file_hash, td::BufferSlice data);
  bool get_account_state(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt ref_blkid,
                         std::string filename = "", int mode = -1);
  void got_account_state(ton::BlockIdExt ref_blk, ton::BlockIdExt blk, ton::BlockIdExt shard_blk,
                         td::BufferSlice shard_proof, td::BufferSlice proof, td::BufferSlice state,
                         ton::WorkchainId workchain, ton::StdSmcAddress addr, std::string filename, int mode);
  bool parse_run_method(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt ref_blkid,
                        std::string method_name, bool ext_mode);
  bool start_run_method(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt ref_blkid,
                        std::string method_name, std::vector<vm::StackEntry> params, int mode,
                        td::Promise<std::vector<vm::StackEntry>> promise);
  void run_smc_method(int mode, ton::BlockIdExt ref_blk, ton::BlockIdExt blk, ton::BlockIdExt shard_blk,
                      td::BufferSlice shard_proof, td::BufferSlice proof, td::BufferSlice state,
                      ton::WorkchainId workchain, ton::StdSmcAddress addr, std::string method,
                      std::vector<vm::StackEntry> params, td::BufferSlice remote_c7, td::BufferSlice remote_libs,
                      td::BufferSlice remote_result, int remote_exit_code,
                      td::Promise<std::vector<vm::StackEntry>> promise);
  bool register_config_param4(Ref<vm::Cell> value);
  bool dns_resolve_start(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt blkid, std::string domain,
                         int cat, int mode);
  bool dns_resolve_send(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt blkid, std::string domain,
                        std::string qdomain, int cat, int mode);
  void dns_resolve_finish(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::BlockIdExt blkid,
                          std::string domain, std::string qdomain, int cat, int mode, int used_bits,
                          Ref<vm::Cell> value);
  bool show_dns_record(std::ostream& os, int cat, Ref<vm::Cell> value, bool raw_dump);
  bool get_all_shards(bool use_last = true, ton::BlockIdExt blkid = {});
  void got_all_shards(ton::BlockIdExt blk, td::BufferSlice proof, td::BufferSlice data);
  bool get_config_params(ton::BlockIdExt blkid, td::Promise<td::Unit> do_after, int mode = 0, std::string filename = "",
                         std::vector<int> params = {});
  void got_config_params(ton::BlockIdExt req_blkid, ton::BlockIdExt blkid, td::BufferSlice state_proof,
                         td::BufferSlice cfg_proof, int mode, std::string filename, std::vector<int> params,
                         td::Promise<td::Unit> do_after);
  bool get_block(ton::BlockIdExt blk, bool dump = false);
  void got_block(ton::BlockIdExt blkid, td::BufferSlice data, bool dump);
  bool get_state(ton::BlockIdExt blk, bool dump = false);
  void got_state(ton::BlockIdExt blkid, ton::RootHash root_hash, ton::FileHash file_hash, td::BufferSlice data,
                 bool dump);
  bool get_block_header(ton::BlockIdExt blk, int mode);
  bool lookup_block(ton::ShardIdFull shard, int mode, td::uint64 arg);
  void got_block_header(ton::BlockIdExt blkid, td::BufferSlice data, int mode);
  bool show_block_header(ton::BlockIdExt blkid, Ref<vm::Cell> root, int mode);
  bool show_state_header(ton::BlockIdExt blkid, Ref<vm::Cell> root, int mode);
  bool get_one_transaction(ton::BlockIdExt blkid, ton::WorkchainId workchain, ton::StdSmcAddress addr,
                           ton::LogicalTime lt, bool dump = false);
  void got_one_transaction(ton::BlockIdExt req_blkid, ton::BlockIdExt blkid, td::BufferSlice proof,
                           td::BufferSlice transaction, ton::WorkchainId workchain, ton::StdSmcAddress addr,
                           ton::LogicalTime trans_lt, bool dump);
  bool get_last_transactions(ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::LogicalTime lt,
                             ton::Bits256 hash, unsigned count, bool dump);
  void got_last_transactions(std::vector<ton::BlockIdExt> blkids, td::BufferSlice transactions_boc,
                             ton::WorkchainId workchain, ton::StdSmcAddress addr, ton::LogicalTime lt,
                             ton::Bits256 hash, unsigned count, bool dump);
  bool get_block_transactions(ton::BlockIdExt blkid, int mode, unsigned count, ton::Bits256 acc_addr,
                              ton::LogicalTime lt);
  void got_block_transactions(ton::BlockIdExt blkid, int mode, unsigned req_count, bool incomplete,
                              std::vector<TransId> trans, td::BufferSlice proof);
  bool get_block_proof(ton::BlockIdExt from, ton::BlockIdExt to, int mode);
  void got_block_proof(ton::BlockIdExt from, ton::BlockIdExt to, int mode, td::BufferSlice res);
  bool get_creator_stats(ton::BlockIdExt blkid, int mode, unsigned req_count, ton::Bits256 start_after,
                         ton::UnixTime min_utime);
  void got_creator_stats(ton::BlockIdExt req_blkid, ton::BlockIdExt blkid, int req_mode, int mode,
                         td::Bits256 start_after, ton::UnixTime min_utime, td::BufferSlice state_proof,
                         td::BufferSlice data_proof, int count, int req_count, bool complete);
  bool cache_cell(Ref<vm::Cell> cell);
  bool list_cached_cells() const;
  bool dump_cached_cell(td::Slice hash_pfx, td::Slice type_name = {});
  // parser
  bool do_parse_line();
  bool show_help(std::string command);
  td::Slice get_word(char delim = ' ');
  td::Slice get_word_ext(const char* delims, const char* specials = nullptr);
  bool get_word_to(std::string& str, char delim = ' ');
  bool get_word_to(td::Slice& str, char delim = ' ');
  int skipspc();
  std::string get_line_tail(bool remove_spaces = true) const;
  bool eoln() const;
  bool seekeoln();
  bool set_error(td::Status error);
  bool set_error(std::string err_msg);
  void show_context() const;
  bool parse_account_addr(ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool allow_none = false);
  static int parse_hex_digit(int c);
  static bool parse_hash(const char* str, ton::Bits256& hash);
  static bool parse_hash(td::Slice str, ton::Bits256& hash);
  static bool convert_uint64(td::Slice word, td::uint64& val);
  static bool convert_int64(td::Slice word, td::int64& val);
  static bool convert_uint32(td::Slice word, td::uint32& val);
  static bool convert_int32(td::Slice word, td::int32& val);
  static bool convert_shard_id(td::Slice str, ton::ShardIdFull& shard);
  static td::int64 compute_method_id(std::string method);
  bool parse_hash(ton::Bits256& hash);
  bool parse_lt(ton::LogicalTime& lt);
  bool parse_uint32(td::uint32& val);
  bool parse_int32(td::int32& val);
  bool parse_int16(int& val);
  bool parse_shard_id(ton::ShardIdFull& shard);
  bool parse_block_id_ext(ton::BlockIdExt& blkid, bool allow_incomplete = false);
  bool parse_block_id_ext(std::string blk_id_string, ton::BlockIdExt& blkid, bool allow_incomplete = false) const;
  bool parse_stack_value(td::Slice str, vm::StackEntry& value);
  bool parse_stack_value(vm::StackEntry& value);
  bool parse_stack_values(std::vector<vm::StackEntry>& values);
  bool register_blkid(const ton::BlockIdExt& blkid);
  bool show_new_blkids(bool all = false);
  bool complete_blkid(ton::BlockId partial_blkid, ton::BlockIdExt& complete_blkid) const;
  td::Promise<td::Unit> trivial_promise();
  static const tlb::TypenameLookup& get_tlb_dict();

 public:
  void conn_ready() {
    LOG(ERROR) << "conn ready";
    ready_ = true;
    if (!inited_) {
      run_init_queries();
    }
  }
  void conn_closed() {
    ready_ = false;
  }
  void set_global_config(std::string str) {
    global_config_ = str;
  }
  void set_db_root(std::string db_root) {
    db_root_ = db_root;
  }
  void set_readline_enabled(bool value) {
    readline_enabled_ = value;
  }
  void set_liteserver_idx(td::int32 idx) {
    liteserver_idx_ = idx;
  }
  void set_remote_addr(td::IPAddress addr) {
    remote_addr_ = addr;
  }
  void set_public_key(td::BufferSlice file_name) {
    auto R = [&]() -> td::Result<ton::PublicKey> {
      TRY_RESULT_PREFIX(conf_data, td::read_file(file_name.as_slice().str()), "failed to read: ");
      return ton::PublicKey::import(conf_data.as_slice());
    }();

    if (R.is_error()) {
      LOG(FATAL) << "bad server public key: " << R.move_as_error();
    }
    remote_public_key_ = R.move_as_ok();
  }
  void set_fail_timeout(td::Timestamp ts) {
    fail_timeout_ = ts;
    alarm_timestamp().relax(fail_timeout_);
  }
  void set_print_limit(int plimit) {
    if (plimit >= 0) {
      print_limit_ = plimit;
    }
  }
  void add_cmd(td::BufferSlice data) {
    ex_mode_ = true;
    ex_queries_.push_back(std::move(data));
    readline_enabled_ = false;
  }
  void alarm() override {
    if (fail_timeout_.is_in_past()) {
      std::_Exit(7);
    }
    if (ex_mode_ && !running_queries_ && ex_queries_.size() == 0) {
      std::_Exit(0);
    }
    alarm_timestamp().relax(fail_timeout_);
  }

  void start_up() override {
  }
  void tear_down() override {
    // FIXME: do not work in windows
    //td::actor::SchedulerContext::get()->stop();
  }

  void got_result();
  bool envelope_send_query(td::BufferSlice query, td::Promise<td::BufferSlice> promise);
  void parse_line(td::BufferSlice data);

  TestNode() {
  }

  void run();
};
