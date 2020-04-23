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

    Copyright 2019-2020 Telegram Systems LLP
*/
#include "td/actor/actor.h"

#include "td/utils/filesystem.h"
#include "td/utils/OptionsParser.h"
#include "td/utils/overloaded.h"
#include "td/utils/Parser.h"
#include "td/utils/port/signals.h"
#include "td/utils/port/path.h"
#include "td/utils/Random.h"
#include "td/utils/as.h"

#include "terminal/terminal.h"

#include "tonlib/TonlibClient.h"
#include "tonlib/TonlibCallback.h"

#include "tonlib/ExtClientLazy.h"

#include "smc-envelope/ManualDns.h"
#include "smc-envelope/PaymentChannel.h"

#include "auto/tl/tonlib_api.hpp"

#include <cinttypes>
#include <iostream>
#include <map>

using tonlib_api::make_object;

// GR$<amount>
struct Grams {
  td::uint64 nano;
};

td::StringBuilder& operator<<(td::StringBuilder& sb, const Grams& grams) {
  auto b = grams.nano % 1000000000;
  auto a = grams.nano / 1000000000;
  sb << "GR$" << a;
  if (b != 0) {
    size_t sz = 9;
    while (b % 10 == 0) {
      sz--;
      b /= 10;
    }
    sb << '.';
    [&](auto b_str) {
      for (size_t i = b_str.size(); i < sz; i++) {
        sb << '0';
      }
      sb << b_str;
    }(PSLICE() << b);
  }
  return sb;
}

td::Result<Grams> parse_grams(td::Slice grams) {
  td::ConstParser parser(grams);
  if (parser.skip_start_with("GR$")) {
    TRY_RESULT(a, td::to_integer_safe<td::uint32>(parser.read_till_nofail('.')));
    td::uint64 res = a;
    if (parser.try_skip('.')) {
      for (int i = 0; i < 9; i++) {
        res *= 10;
        if (parser.peek_char() >= '0' && parser.peek_char() <= '9') {
          res += parser.peek_char() - '0';
          parser.advance(1);
        }
      }
    } else {
      res *= 1000000000;
    }
    if (!parser.empty()) {
      return td::Status::Error(PSLICE() << "Failed to parse grams \"" << grams << "\", left \"" << parser.read_all()
                                        << "\"");
    }
    return Grams{res};
  }
  TRY_RESULT(value, td::to_integer_safe<td::uint64>(grams));
  return Grams{value};
}

class TonlibCli : public td::actor::Actor {
 public:
  struct Options {
    bool enable_readline{true};
    std::string config;
    std::string name;
    std::string key_dir{"."};
    bool in_memory{false};
    bool use_callbacks_for_network{false};
    td::int32 wallet_version = 2;
    td::int32 wallet_revision = 0;
    td::optional<td::uint32> wallet_id;
    bool ignore_cache{false};

    bool one_shot{false};
    std::string cmd;
  };
  TonlibCli(Options options) : options_(std::move(options)) {
  }

 private:
  Options options_;
  td::actor::ActorOwn<td::TerminalIO> io_;
  td::actor::ActorOwn<tonlib::TonlibClient> client_;
  std::uint64_t next_query_id_{1};
  td::Promise<td::Slice> cont_;
  td::uint32 wallet_id_;
  ton::tonlib_api::object_ptr<tonlib_api::ton_blockIdExt> current_block_;
  enum class BlockMode { Auto, Manual } block_mode_ = BlockMode::Auto;

  struct KeyInfo {
    std::string public_key;
    td::SecureString secret;
  };
  std::vector<KeyInfo> keys_;

  struct Address {
    tonlib_api::object_ptr<tonlib_api::accountAddress> address;
    std::string public_key;
    td::SecureString secret;
    auto input_key(td::Slice password = "") const {
      return !secret.empty() ? make_object<tonlib_api::inputKeyRegular>(
                                   make_object<tonlib_api::key>(public_key, secret.copy()), td::SecureString(password))
                             : nullptr;
    }
  };

  std::map<std::uint64_t, td::Promise<tonlib_api::object_ptr<tonlib_api::Object>>> query_handlers_;

  td::actor::ActorOwn<ton::adnl::AdnlExtClient> raw_client_;

  bool is_closing_{false};
  td::uint32 ref_cnt_{1};

  td::int64 snd_bytes_{0};
  td::int64 rcv_bytes_{0};

  void start_up() override {
    class Cb : public td::TerminalIO::Callback {
     public:
      void line_cb(td::BufferSlice line) override {
        td::actor::send_closure(id_, &TonlibCli::parse_line, std::move(line));
      }
      Cb(td::actor::ActorShared<TonlibCli> id) : id_(std::move(id)) {
      }

     private:
      td::actor::ActorShared<TonlibCli> id_;
    };
    ref_cnt_++;
    if (!options_.one_shot) {
      io_ = td::TerminalIO::create("> ", options_.enable_readline, std::make_unique<Cb>(actor_shared(this)));
      td::actor::send_closure(io_, &td::TerminalIO::set_log_interface);
    }

    class TonlibCb : public tonlib::TonlibCallback {
     public:
      TonlibCb(td::actor::ActorShared<TonlibCli> id) : id_(std::move(id)) {
      }
      void on_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) override {
        send_closure(id_, &TonlibCli::on_tonlib_result, id, std::move(result));
      }
      void on_error(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::error> error) override {
        send_closure(id_, &TonlibCli::on_tonlib_error, id, std::move(error));
      }

     private:
      td::actor::ActorShared<TonlibCli> id_;
    };
    ref_cnt_++;
    client_ = td::actor::create_actor<tonlib::TonlibClient>("Tonlib", td::make_unique<TonlibCb>(actor_shared(this, 1)));

    td::mkdir(options_.key_dir).ignore();

    load_keys();

    if (options_.use_callbacks_for_network) {
      auto config = tonlib::Config::parse(options_.config).move_as_ok();
      auto lite_clients_size = config.lite_clients.size();
      CHECK(lite_clients_size != 0);
      auto lite_client_id = td::Random::fast(0, td::narrow_cast<int>(lite_clients_size) - 1);
      auto& lite_client = config.lite_clients[lite_client_id];
      class Callback : public tonlib::ExtClientLazy::Callback {
       public:
        explicit Callback(td::actor::ActorShared<> parent) : parent_(std::move(parent)) {
        }

       private:
        td::actor::ActorShared<> parent_;
      };
      ref_cnt_++;
      raw_client_ = tonlib::ExtClientLazy::create(lite_client.adnl_id, lite_client.address,
                                                  td::make_unique<Callback>(td::actor::actor_shared()));
    }

    auto config = !options_.config.empty()
                      ? make_object<tonlib_api::config>(options_.config, options_.name,
                                                        options_.use_callbacks_for_network, options_.ignore_cache)
                      : nullptr;

    tonlib_api::object_ptr<tonlib_api::KeyStoreType> ks_type;
    if (options_.in_memory) {
      ks_type = make_object<tonlib_api::keyStoreTypeInMemory>();
    } else {
      ks_type = make_object<tonlib_api::keyStoreTypeDirectory>(options_.key_dir);
    }
    send_query(make_object<tonlib_api::init>(make_object<tonlib_api::options>(std::move(config), std::move(ks_type))),
               [&](auto r_ok) {
                 LOG_IF(ERROR, r_ok.is_error()) << r_ok.error();
                 if (r_ok.is_ok()) {
                   if (r_ok.ok()->config_info_) {
                     if (options_.wallet_id) {
                       wallet_id_ = options_.wallet_id.value();
                     } else {
                       wallet_id_ = static_cast<td::uint32>(r_ok.ok()->config_info_->default_wallet_id_);
                     }
                   }
                   load_channnels();
                   td::TerminalIO::out() << "Tonlib is inited\n";
                   if (options_.one_shot) {
                     td::actor::send_closure(actor_id(this), &TonlibCli::parse_line, td::BufferSlice(options_.cmd));
                   }
                 }
               });
  }

  void hangup_shared() override {
    CHECK(ref_cnt_ > 0);
    ref_cnt_--;
    if (get_link_token() == 1) {
      io_.reset();
    }
    try_stop();
  }
  void try_stop() {
    if (is_closing_ && ref_cnt_ == 0) {
      stop();
    }
  }
  void tear_down() override {
    td::actor::SchedulerContext::get()->stop();
  }

  void on_wait() {
    if (options_.one_shot) {
      LOG(ERROR) << "FAILED (not enough data)";
      std::_Exit(2);
    }
  }
  void dns_help() {
    td::TerminalIO::out() << "dns help\n";
    td::TerminalIO::out() << "dns resolve (<addr> | root) <name> <category>\n";
    td::TerminalIO::out() << "dns cmd <key_id> <dns_cmd>\n";
    //td::TerminalIO::out() << "dns cmdlist <key_id> {<dns_cmd>\\n} end\n";
    td::TerminalIO::out() << "dns cmdfile <key_id> <file>\n";
    td::TerminalIO::out() << "\t<dns_cmd> = set <name> <category> <data> | delete.name <name> | delete.all\n";
    td::TerminalIO::out() << "\t<data> = DELETED | EMPTY | TEXT:<text> | NEXT:<smc-address> | SMC:<smc-address> | "
                             "ADNL:<adnl-address>\n";
  }

  void pchan_help() {
    td::TerminalIO::out() << "pchan help\n";
    td::TerminalIO::out() << "pchan create <alice_public_key> <alice_address> <bob_public_key> <bob_address> "
                             "<init_timeout> <close_timeout> [<channel_id>]\n";
    td::TerminalIO::out() << "pchan list\n";
    td::TerminalIO::out() << "pchan delete <pchan_id>\n";

    td::TerminalIO::out() << "pchan getstate <pchan_id>\n";
    td::TerminalIO::out() << "pchan promise make <pchan_id> <key_id> (A|B) <promise_A> <promise_B>\n";
    td::TerminalIO::out() << "pchan promise check <pchan id> (A|B) <promise_A> <promise_B> <signature>\n";
    td::TerminalIO::out() << "pchan promise pack <channel_id> <promise_A> <promise_B> <signature>\n";
    td::TerminalIO::out() << "pchan promise unpack <packed_promise>\n";
    td::TerminalIO::out() << "pchan cmd <pchan_id> <pchan_cmd>\n";
    td::TerminalIO::out() << "\tfor simplicity we assume that alice_key is same as wallet key alice uses\n";
    td::TerminalIO::out() << "\t<pchan_cmd> = init <key_id> <A> <B> <min_A> <min_B>\n";
    td::TerminalIO::out() << "\t            | close <key_id> promise [<extra_A>]\n";
    td::TerminalIO::out() << "\t            | timeout <key_id>\n";
  }

  void rwallet_help() {
    td::TerminalIO::out() << "rwallet help\n";
    td::TerminalIO::out() << "rwallet address <key_id> <public_key>\n";
    td::TerminalIO::out() << "rwallet init <key_id> <public_key> <start_at> [<seconds>:<value> ...]\n";
  }

  void parse_line(td::BufferSlice line) {
    if (is_closing_) {
      return;
    }
    if (cont_) {
      auto cont = std::move(cont_);
      cont.set_value(line.as_slice());
      return;
    }
    td::ConstParser parser(line.as_slice());
    auto cmd = parser.read_word();
    if (cmd.empty()) {
      return;
    }
    auto to_bool = [](td::Slice word, bool def = false) {
      if (word.empty()) {
        return def;
      }
      if (word == "0" || word == "FALSE" || word == "false") {
        return false;
      }
      return true;
    };

    td::Promise<td::Unit> cmd_promise = [line = line.clone(), one_shot = options_.one_shot](td::Result<td::Unit> res) {
      if (res.is_ok()) {
        if (one_shot) {
          LOG(DEBUG) << "OK";
          std::_Exit(0);
        }
      } else {
        td::TerminalIO::out() << "Query {" << line.as_slice() << "} FAILED: \n\t" << res.error() << "\n";
        if (one_shot) {
          LOG(ERROR) << "FAILED";
          std::_Exit(1);
        }
      }
    };

    if (cmd == "help") {
      td::TerminalIO::out() << "help\tThis help\n";
      td::TerminalIO::out() << "time\tGet server time\n";
      td::TerminalIO::out() << "remote-version\tShows server time, version and capabilities\n";
      td::TerminalIO::out() << "sendfile <filename>\tLoad a serialized message from <filename> and send it to server\n";
      td::TerminalIO::out() << "setconfig|validateconfig <path> [<name>] [<use_callback>] [<force>] - set or validate "
                               "lite server config\n";
      td::TerminalIO::out() << "runmethod <addr> <method-id> <params>...\tRuns GET method <method-id> of account "
                               "<addr> with specified parameters\n";
      td::TerminalIO::out() << "getstate <key_id>\tget state of wallet with requested key\n";
      td::TerminalIO::out() << "guessrevision <key_id>\tsearch of existing accounts corresponding to the given key\n";
      td::TerminalIO::out() << "getaddress <key_id>\tget address of wallet with requested key\n";

      dns_help();
      pchan_help();
      rwallet_help();

      td::TerminalIO::out()
          << "blockmode auto|manual\tWith auto mode, all queries will be executed with respect to the latest block. "
             "With manual mode, user must update current block explicitly: with last or setblock\n";
      td::TerminalIO::out() << "last\tUpdate current block to the most recent one\n";
      td::TerminalIO::out() << "setblock <block>\tSet current block\n";

      td::TerminalIO::out() << "exit\tExit\n";
      td::TerminalIO::out() << "quit\tExit\n";
      td::TerminalIO::out()
          << "saveaccount[code|data] <filename> <addr>\tSaves into specified file the most recent state\n";

      td::TerminalIO::out() << "genkey - generate new secret key\n";
      td::TerminalIO::out() << "keys - show all stored keys\n";
      td::TerminalIO::out() << "unpackaddress <address> - validate and parse address\n";
      td::TerminalIO::out() << "setbounceble <address> [<bounceble>] - change bounceble flag in address\n";
      td::TerminalIO::out() << "importkey - import key\n";
      td::TerminalIO::out() << "importkeypem <filename> - import key\n";
      td::TerminalIO::out() << "importkeyraw <filename> - import key\n";
      td::TerminalIO::out() << "deletekeys - delete ALL PRIVATE KEYS\n";
      td::TerminalIO::out() << "exportkey [<key_id>] - export key\n";
      td::TerminalIO::out() << "exportkeypem [<key_id>] - export key\n";
      td::TerminalIO::out()
          << "gethistory <key_id> - get history fo simple wallet with requested key (last 10 transactions)\n";
      td::TerminalIO::out() << "init <key_id> - init simple wallet with requested key\n";
      td::TerminalIO::out() << "transfer[f][F][e][k][c] <from_key_id> (<to_key_id> <value> <message>|<file_name>) - "
                               "make transfer from <from_key_id>\n"
                            << "\t 'f' modifier - allow send to uninited account\n"
                            << "\t 'F' modifier - read list of messages from <file_name> (in same format <to_key_id> "
                               "<value> <message>, one per line)\n"
                            << "\t 'e' modifier - encrypt all messages\n"
                            << "\t 'k' modifier - use fake key\n"
                            << "\t 'c' modifier - just esmitate fees\n";
    } else if (cmd == "genkey") {
      generate_key();
    } else if (cmd == "exit" || cmd == "quit") {
      is_closing_ = true;
      client_.reset();
      ref_cnt_--;
      try_stop();
    } else if (cmd == "keys") {
      dump_keys();
    } else if (cmd == "deletekey") {
      //delete_key(parser.read_word());
    } else if (cmd == "deletekeys") {
      delete_all_keys();
    } else if (cmd == "exportkey" || cmd == "exportkeypem") {
      export_key(cmd.str(), parser.read_word());
    } else if (cmd == "importkey") {
      import_key(parser.read_all());
    } else if (cmd == "hint") {
      get_hints(parser.read_word());
    } else if (cmd == "unpackaddress") {
      unpack_address(parser.read_word());
    } else if (cmd == "setbounceable") {
      auto addr = parser.read_word();
      auto bounceable = parser.read_word();
      set_bounceable(addr, to_bool(bounceable, true));
    } else if (cmd == "netstats") {
      dump_netstats();
      // reviewed from here
    } else if (cmd == "blockmode") {
      set_block_mode(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "sync" || cmd == "last") {
      sync(std::move(cmd_promise), cmd == "last");
    } else if (cmd == "time") {
      remote_time(std::move(cmd_promise));
    } else if (cmd == "remote-version") {
      remote_version(std::move(cmd_promise));
    } else if (cmd == "sendfile") {
      send_file(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "saveaccount" || cmd == "saveaccountdata" || cmd == "saveaccountcode") {
      auto path = parser.read_word();
      auto address = parser.read_word();
      save_account(cmd, path, address, std::move(cmd_promise));
    } else if (cmd == "runmethod") {
      run_method(parser, std::move(cmd_promise));
    } else if (cmd == "setconfig" || cmd == "validateconfig") {
      auto config = parser.read_word();
      auto name = parser.read_word();
      auto use_callback = parser.read_word();
      auto force = parser.read_word();
      set_validate_config(cmd, config, name, to_bool(use_callback), to_bool(force), std::move(cmd_promise));
    } else if (td::begins_with(cmd, "transfer") || cmd == "init") {
      // transfer[f][F]
      // f - force
      // F from file - SEND <address> <amount> <message>
      // use @empty for empty message
      transfer(parser, cmd, std::move(cmd_promise));
    } else if (cmd == "getstate") {
      get_state(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "getaddress") {
      get_address(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "importkeypem") {
      import_key_pem(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "importkeyraw") {
      import_key_raw(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "dns") {
      run_dns_cmd(parser, std::move(cmd_promise));
    } else if (cmd == "pchan") {
      run_pchan_cmd(parser, std::move(cmd_promise));
    } else if (cmd == "rwallet") {
      run_rwallet_cmd(parser, std::move(cmd_promise));
    } else if (cmd == "gethistory") {
      get_history(parser.read_word(), std::move(cmd_promise));
    } else if (cmd == "guessrevision") {
      guess_revision(parser.read_word(), std::move(cmd_promise));
    } else {
      cmd_promise.set_error(td::Status::Error(PSLICE() << "Unkwnown query `" << cmd << "`"));
    }
    if (cmd_promise) {
      cmd_promise.set_value(td::Unit());
    }
  }

  void rwallet_address(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, address, to_account_address(parser.read_word(), false));
    auto public_key = parser.read_word().str();
    TRY_RESULT_PROMISE(
        promise, addr,
        sync_send_query(make_object<tonlib_api::getAccountAddress>(
            make_object<tonlib_api::rwallet_initialAccountState>(address.public_key, public_key, wallet_id_), -1)));
    td::TerminalIO::out() << addr->account_address_ << "\n";
    promise.set_value(td::Unit());
  }

  void rwallet_init(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, address, to_account_address(parser.read_word(), false));
    auto public_key = parser.read_word().str();
    auto initial_state =
        make_object<tonlib_api::rwallet_initialAccountState>(address.public_key, public_key, wallet_id_);
    TRY_RESULT_PROMISE(
        promise, addr,
        sync_send_query(make_object<tonlib_api::getAccountAddress>(
            make_object<tonlib_api::rwallet_initialAccountState>(address.public_key, public_key, wallet_id_), -1)));

    TRY_RESULT_PROMISE(promise, start_at, td::to_integer_safe<td::int32>(parser.read_word()));
    std::vector<std::pair<td::int32, td::uint64>> limits;
    while (true) {
      auto word = parser.read_word();
      if (word.empty()) {
        break;
      }
      auto column_at = word.find(':');
      TRY_RESULT_PROMISE(promise, value, parse_grams(word.substr(column_at + 1)));
      TRY_RESULT_PROMISE(promise, seconds, td::to_integer_safe<td::int32>(word.substr(0, column_at)));
      limits.emplace_back(seconds, value.nano);
    }
    auto config = make_object<tonlib_api::rwallet_config>();
    config->start_at_ = start_at;
    for (auto limit : limits) {
      config->limits_.push_back(make_object<tonlib_api::rwallet_limit>(limit.first, limit.second));
    }
    auto action =
        make_object<tonlib_api::actionRwallet>(make_object<tonlib_api::rwallet_actionInit>(std::move(config)));
    send_query(make_object<tonlib_api::createQuery>(address.input_key(), std::move(addr), 60, std::move(action),
                                                    std::move(initial_state)),
               promise.send_closure(actor_id(this), &TonlibCli::transfer2, false));
  }

  void run_rwallet_cmd(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto cmd = parser.read_word();
    if (cmd == "help") {
      rwallet_help();
      return promise.set_value(td::Unit());
    }
    if (cmd == "address") {
      return rwallet_address(parser, std::move(promise));
    }
    if (cmd == "init") {
      return rwallet_init(parser, std::move(promise));
    }

    promise.set_error(td::Status::Error("Unknown command"));
  }

  void run_pchan_cmd(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto cmd = parser.read_word();
    if (cmd == "help") {
      pchan_help();
      return promise.set_value(td::Unit());
    }
    if (cmd == "create") {
      return pchan_create(parser, std::move(promise));
    }
    if (cmd == "list") {
      return pchan_list(std::move(promise));
    }
    if (cmd == "delete") {
      return pchan_delete(parser, std::move(promise));
    }
    if (cmd == "promise") {
      return pchan_promise(parser, std::move(promise));
    }
    if (cmd == "getstate") {
      return pchan_getstate(parser, std::move(promise));
    }
    if (cmd == "cmd") {
      TRY_RESULT_PROMISE(promise, pchan_id, to_pchan_id(parser.read_word()));
      auto subcmd = parser.read_word();
      if (subcmd == "init") {
        return pchan_init(pchan_id, parser, std::move(promise));
      }
      if (subcmd == "close") {
        return pchan_close(pchan_id, parser, std::move(promise));
      }
      if (subcmd == "timeout") {
        return pchan_timeout(pchan_id, parser, std::move(promise));
      }
    }

    promise.set_error(td::Status::Error("Unknown command"));
  }

  struct Channel {
    std::string alice_public_key;
    std::string alice_address;
    td::optional<int> alice_id;

    std::string bob_public_key;
    std::string bob_address;
    td::optional<int> bob_id;
    td::int32 init_timeout{0};
    td::int32 close_timeout{0};
    td::int64 channel_id;

    std::string address;

    td::Status parse(td::ConstParser& parser, bool gen_channel_id = false) {
      alice_public_key = parser.read_word().str();
      alice_address = parser.read_word().str();
      bob_public_key = parser.read_word().str();
      bob_address = parser.read_word().str();
      TRY_RESULT_ASSIGN(init_timeout, td::to_integer_safe<td::int32>(parser.read_word()));
      TRY_RESULT_ASSIGN(close_timeout, td::to_integer_safe<td::int32>(parser.read_word()));
      if (parser.status().is_error()) {
        return parser.status().clone();
      }

      auto channel_id_str = parser.read_word();
      if (channel_id_str.empty()) {
        if (gen_channel_id) {
          channel_id = static_cast<td::int64>(td::Random::secure_uint64());
        } else {
          return td::Status::Error("Empty channel id");
        }
      } else {
        TRY_RESULT_ASSIGN(channel_id, td::to_integer_safe<td::int64>(channel_id_str));
      }
      return td::Status::OK();
    }
    void store(td::StringBuilder& sb) {
      sb << alice_public_key << " " << alice_address << " " << bob_public_key << " " << bob_address << " "
         << init_timeout << " " << close_timeout << " " << channel_id;
    }

    friend td::StringBuilder& operator<<(td::StringBuilder& sb, const Channel& channel) {
      sb << "\n\t" << td::tag("a_key", channel.alice_public_key) << td::tag("a_addr", channel.alice_address);
      sb << "\n\t" << td::tag("b_key", channel.bob_public_key) << td::tag("b_addr", channel.bob_address);
      if (channel.alice_id) {
        sb << "\n\t" << td::tag("alice_id", channel.alice_id.value());
      }
      if (channel.bob_id) {
        sb << "\n\t" << td::tag("b_id", channel.bob_id.value());
      }
      sb << "\n\t" << td::tag("init timeout", channel.init_timeout) << td::tag("close timeout", channel.close_timeout);
      sb << "\n\t" << td::tag("channel id", channel.channel_id);
      sb << "\n\t" << td::tag("addr", channel.address);
      return sb;
    }

    auto to_address() {
      return make_object<tonlib_api::accountAddress>(address);
    }
    auto to_init_state() {
      return make_object<tonlib_api::pchan_initialAccountState>(make_object<tonlib_api::pchan_config>(
          alice_public_key, make_object<tonlib_api::accountAddress>(alice_address), bob_public_key,
          make_object<tonlib_api::accountAddress>(bob_address), init_timeout, close_timeout, channel_id));
    }
  };
  void store_channels() {
    td::SecureString buf(10000);
    td::StringBuilder sb(buf.as_mutable_slice());
    for (auto& it : channels_) {
      it.second.store(sb);
      sb << "\n";
    }
    LOG_IF(FATAL, sb.is_error()) << "StringBuilder overflow";
    td::atomic_write_file(channel_db_path(), sb.as_cslice());
  }

  void load_channnels() {
    auto r_db = td::read_file_secure(channel_db_path());
    if (r_db.is_error()) {
      return;
    }
    auto db = r_db.move_as_ok();
    td::ConstParser parser(db.as_slice());
    while (true) {
      auto line = td::trim(parser.read_till_nofail('\n'));
      parser.skip_nofail('\n');
      if (line.empty()) {
        break;
      }
      td::ConstParser line_parser(line);
      do_pchan_create(line_parser, false).ensure();
    }
  }

  std::map<td::int32, Channel> channels_;
  td::int32 next_channel_id_{0};

  td::Result<td::int32> to_pchan_id(td::Slice pchan_id_str) {
    TRY_RESULT(pchan_id, td::to_integer_safe<td::int32>(pchan_id_str));
    auto it = channels_.find(pchan_id);
    if (it == channels_.end()) {
      return td::Status::Error("Unknown channle id");
    }
    return pchan_id;
  }

  td::Status do_pchan_create(td::ConstParser& parser, bool gen_channel_id) {
    Channel channel;
    TRY_STATUS(channel.parse(parser, gen_channel_id));
    TRY_RESULT(addr, sync_send_query(make_object<tonlib_api::getAccountAddress>(channel.to_init_state(), -1)));
    channel.address = addr->account_address_;

    auto find_id = [&](td::Slice public_key, td::Slice address) -> td::optional<td::int32> {
      auto r_addr = to_account_address(public_key);
      if (r_addr.is_error()) {
        return {};
      }
      auto addr = r_addr.move_as_ok().address->account_address_;
      if (address != addr) {
        return {};
      }
      for (td::int32 i = 0; i < static_cast<td::int32>(keys_.size()); i++) {
        if (keys_[i].public_key == public_key) {
          return i;
        }
      }
      return {};
    };
    channel.alice_id = find_id(channel.alice_public_key, channel.alice_address);
    channel.bob_id = find_id(channel.bob_public_key, channel.bob_address);
    channels_[next_channel_id_++] = std::move(channel);
    return td::Status::OK();
  }
  void pchan_getstate(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, pchan_id, to_pchan_id(parser.read_word()), "pchan_id");
    auto& chan = channels_[pchan_id];
    get_state(chan.address, std::move(promise));
  }
  void pchan_promise(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto cmd = parser.read_word();
    if (cmd == "make") {
      return pchan_promise_make(parser, std::move(promise));
    }
    if (cmd == "check") {
      return pchan_promise_check(parser, std::move(promise));
    }
    if (cmd == "pack") {
      return pchan_promise_pack(parser, std::move(promise));
    }
    if (cmd == "unpack") {
      return pchan_promise_unpack(parser, std::move(promise));
    }
    promise.set_error(td::Status::Error("Unknown command"));
  }

  void pchan_promise_make2(tonlib_api::object_ptr<tonlib_api::pchan_promise> ans, td::Promise<td::Unit> promise) {
    td::TerminalIO::out() << "Signature (base64url):" << td::base64url_encode(ans->signature_) << "\n";
    send_query(make_object<tonlib_api::pchan_packPromise>(std::move(ans)), promise.wrap([](auto&& ans) {
      td::TerminalIO::out() << "Promise (base64url): " << td::base64url_encode(ans->bytes_) << "\n";
      return td::Unit();
    }));
  }

  void pchan_promise_make(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, pchan_id, to_pchan_id(parser.read_word()), "pchan_id");
    td::Slice a_or_b = parser.read_word();
    bool is_a;
    if (a_or_b == "A") {
      is_a = true;
    } else if (a_or_b == "B") {
      is_a = false;
    } else {
      TRY_STATUS_PROMISE(promise, td::Status::Error("(A|B) expected"));
    }
    TRY_RESULT_PROMISE_PREFIX(promise, promise_A, parse_grams(parser.read_word()), "A");
    TRY_RESULT_PROMISE_PREFIX(promise, promise_B, parse_grams(parser.read_word()), "B");

    auto& chan = channels_[pchan_id];
    Address addr;
    if (is_a) {
      TRY_RESULT_PROMISE_PREFIX_ASSIGN(promise, addr, to_account_address(chan.alice_public_key, true),
                                       "Don't have Alice's key");
    } else {
      TRY_RESULT_PROMISE_PREFIX_ASSIGN(promise, addr, to_account_address(chan.bob_public_key, true),
                                       "Don't have Bob's key");
    }

    send_query(make_object<tonlib_api::pchan_signPromise>(
                   addr.input_key(),
                   make_object<tonlib_api::pchan_promise>("", promise_A.nano, promise_B.nano, chan.channel_id)),
               promise.send_closure(actor_id(this), &TonlibCli::pchan_promise_make2));
  }
  void pchan_promise_check(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, pchan_id, to_pchan_id(parser.read_word()), "pchan_id");
    td::Slice a_or_b = parser.read_word();
    bool is_a;
    if (a_or_b == "A") {
      is_a = true;
    } else if (a_or_b == "B") {
      is_a = false;
    } else {
      TRY_STATUS_PROMISE(promise, td::Status::Error("(A|B) expected"));
    }
    TRY_RESULT_PROMISE_PREFIX(promise, promise_A, parse_grams(parser.read_word()), "promise_A");
    TRY_RESULT_PROMISE_PREFIX(promise, promise_B, parse_grams(parser.read_word()), "promise_B");

    auto& chan = channels_[pchan_id];
    std::string public_key = is_a ? chan.alice_public_key : chan.bob_public_key;

    TRY_RESULT_PROMISE_PREFIX(promise, signature, td::base64url_decode(parser.read_word()), "signature");
    send_query(make_object<tonlib_api::pchan_validatePromise>(
                   public_key, make_object<tonlib_api::pchan_promise>(std::move(signature), promise_A.nano,
                                                                      promise_B.nano, chan.channel_id)),
               promise.wrap([](auto&& ans) {
                 td::TerminalIO::out() << "signature is OK\n";
                 return td::Unit();
               }));
  }
  void pchan_promise_pack(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, channel_id, td::to_integer_safe<td::int64>(parser.read_word()), "pchan_id");
    TRY_RESULT_PROMISE_PREFIX(promise, promise_A, parse_grams(parser.read_word()), "promise_A");
    TRY_RESULT_PROMISE_PREFIX(promise, promise_B, parse_grams(parser.read_word()), "promise_B");
    TRY_RESULT_PROMISE_PREFIX(promise, signature, base64url_decode(parser.read_word()), "signature");
    send_query(make_object<tonlib_api::pchan_packPromise>(make_object<tonlib_api::pchan_promise>(
                   std::move(signature), promise_A.nano, promise_B.nano, channel_id)),
               promise.wrap([](auto packed) {
                 td::TerminalIO::out() << "packed promise: " << base64url_encode(packed->bytes_.as_slice()) << "\n";
                 return td::Unit();
               }));
  }
  void pchan_promise_unpack(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, packed_promise, base64url_decode(parser.read_word()), "promise");
    send_query(make_object<tonlib_api::pchan_unpackPromise>(td::SecureString(packed_promise)),
               promise.wrap([](auto unpacked) {
                 td::TerminalIO::out() << "unpacked promise:\n"
                                       << "promise_A: " << Grams{static_cast<td::uint64>(unpacked->promise_A_)} << "\n"
                                       << "promise_B: " << Grams{static_cast<td::uint64>(unpacked->promise_B_)} << "\n"
                                       << "channel_id: " << unpacked->channel_id_ << "\n"
                                       << "signature: " << td::base64url_encode(unpacked->signature_) << "\n";
                 return td::Unit();
               }));
  }

  void pchan_create(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_STATUS_PROMISE(promise, do_pchan_create(parser, true));
    td::TerminalIO::out() << "Channel #" << next_channel_id_ - 1 << channels_[next_channel_id_ - 1] << "\n";
    store_channels();
    promise.set_value(td::Unit());
  }
  void pchan_list(td::Promise<td::Unit> promise) {
    for (auto& it : channels_) {
      td::TerminalIO::out() << "Channel #" << it.first << it.second << "\n";
    }
    promise.set_value(td::Unit());
  }
  void pchan_delete(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    promise.set_error(td::Status::Error("TODO"));
  }

  void pchan_init_2(Address addr, td::int32 pchan_id, td::int64 value,
                    tonlib_api::object_ptr<tonlib_api::query_info> query, td::Promise<td::Unit> promise) {
    std::vector<tonlib_api::object_ptr<tonlib_api::msg_message>> messages;
    messages.push_back(
        make_object<tonlib_api::msg_message>(channels_[pchan_id].to_address(), "", value,
                                             make_object<tonlib_api::msg_dataRaw>(query->body_, query->init_state_)));
    auto action = make_object<tonlib_api::actionMsg>(std::move(messages), true);
    send_query(
        make_object<tonlib_api::createQuery>(addr.input_key(), std::move(addr.address), 60, std::move(action), nullptr),
        promise.send_closure(actor_id(this), &TonlibCli::transfer2, false));
  }

  void pchan_init(td::int32 pchan_id, td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, addr, to_account_address(parser.read_word(), true), "key_id");
    TRY_RESULT_PROMISE_PREFIX(promise, A, parse_grams(parser.read_word()), "A");
    TRY_RESULT_PROMISE_PREFIX(promise, B, parse_grams(parser.read_word()), "B");
    TRY_RESULT_PROMISE_PREFIX(promise, min_A, parse_grams(parser.read_word()), "min_A");
    TRY_RESULT_PROMISE_PREFIX(promise, min_B, parse_grams(parser.read_word()), "min_B");

    auto action = make_object<tonlib_api::actionPchan>(
        make_object<tonlib_api::pchan_actionInit>(A.nano, B.nano, min_A.nano, min_B.nano));

    auto value = A.nano + B.nano;
    send_query(make_object<tonlib_api::createQuery>(addr.input_key(), channels_[pchan_id].to_address(), 60,
                                                    std::move(action), channels_[pchan_id].to_init_state()),
               promise.send_closure(actor_id(this), &TonlibCli::pchan_init_2, std::move(addr), pchan_id, value));
    return;
  }

  void pchan_close2(td::int32 pchan_id, Address addr, tonlib_api::object_ptr<tonlib_api::pchan_promise> pchan_promise,
                    td::Promise<td::Unit> promise) {
    auto action = make_object<tonlib_api::actionPchan>(
        make_object<tonlib_api::pchan_actionClose>(0, 0, std::move(pchan_promise)));
    //send_query(make_object<tonlib_api::createQuery>(addr.input_key(), channels_[pchan_id].to_address(), 60,
    //std::move(action), channels_[pchan_id].to_init_state()),
    //promise.send_closure(actor_id(this), &TonlibCli::pchan_init_2, std::move(addr), pchan_id, 1000000000));
    send_query(make_object<tonlib_api::createQuery>(addr.input_key(), channels_[pchan_id].to_address(), 60,
                                                    std::move(action), channels_[pchan_id].to_init_state()),
               promise.send_closure(actor_id(this), &TonlibCli::transfer2, false));
  }

  void pchan_close(td::int32 pchan_id, td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, addr, to_account_address(parser.read_word(), true), "key_id");
    TRY_RESULT_PROMISE_PREFIX(promise, packed_promise, base64url_decode(parser.read_word()), "promise");
    send_query(make_object<tonlib_api::pchan_unpackPromise>(td::SecureString(packed_promise)),
               promise.send_closure(actor_id(this), &TonlibCli::pchan_close2, pchan_id, std::move(addr)));
  }

  void pchan_timeout(td::int32 pchan_id, td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE_PREFIX(promise, addr, to_account_address(parser.read_word(), true), "key_id");
    auto action = make_object<tonlib_api::actionPchan>(make_object<tonlib_api::pchan_actionTimeout>());
    send_query(make_object<tonlib_api::createQuery>(addr.input_key(), channels_[pchan_id].to_address(), 60,
                                                    std::move(action), channels_[pchan_id].to_init_state()),
               promise.send_closure(actor_id(this), &TonlibCli::pchan_init_2, std::move(addr), pchan_id, 1000000000));
  }

  void run_dns_cmd(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto cmd = parser.read_word();
    if (cmd == "help") {
      dns_help();
      return promise.set_value(td::Unit());
    }
    if (cmd == "cmd" || cmd == "cmdlist" || cmd == "cmdfile") {
      return dns_cmd(cmd, parser, std::move(promise));
    }
    if (cmd == "resolve") {
      return dns_resolve(parser, std::move(promise));
    }
    promise.set_error(td::Status::Error("Unknown command"));
  }

  void do_dns_resolve(std::string name, td::int16 category, td::int32 ttl,
                      tonlib_api::object_ptr<tonlib_api::dns_resolved> resolved, td::Promise<td::Unit> promise) {
    if (resolved->entries_.empty()) {
      td::TerminalIO::out() << "No dns entries found\n";
      promise.set_value(td::Unit());
      return;
    }
    if (resolved->entries_[0]->entry_->get_id() == tonlib_api::dns_entryDataNextResolver::ID && ttl != 0) {
      td::TerminalIO::out() << "Redirect resolver\n";
      auto entry = tonlib_api::move_object_as<tonlib_api::dns_entryDataNextResolver>(resolved->entries_[0]->entry_);
      send_query(make_object<tonlib_api::dns_resolve>(std::move(entry->resolver_), name, category, ttl),
                 promise.send_closure(actor_id(this), &TonlibCli::do_dns_resolve, name, category, 0));
      return;
    }
    td::TerminalIO::out() << "Done\n";
    for (auto& entry : resolved->entries_) {
      td::TerminalIO::out() << "  " << entry->name_ << " " << entry->category_ << " "
                            << tonlib::to_dns_entry_data(*entry->entry_).move_as_ok() << "\n";
    }
    promise.set_value(td::Unit());
  }

  void dns_resolve(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto key_id = parser.read_word();
    if (key_id == "root") {
      key_id = "none";
    }
    TRY_RESULT_PROMISE(promise, address, to_account_address(key_id, false));
    auto name = parser.read_word();
    auto category_str = parser.read_word();
    TRY_RESULT_PROMISE(promise, category, td::to_integer_safe<td::int16>(category_str));

    std::vector<tonlib_api::object_ptr<tonlib_api::dns_entry>> entries;
    entries.push_back(make_object<tonlib_api::dns_entry>(
        "", -1, make_object<tonlib_api::dns_entryDataNextResolver>(std::move(address.address))));
    do_dns_resolve(name.str(), category, 10, make_object<tonlib_api::dns_resolved>(std::move(entries)),
                   std::move(promise));
  }
  void dns_cmd(td::Slice cmd, td::ConstParser& parser, td::Promise<td::Unit> promise) {
    auto key_id = parser.read_word();
    TRY_RESULT_PROMISE(promise, address, to_account_address(key_id, true));

    std::vector<ton::ManualDns::ActionExt> actions_ext;
    if (cmd == "cmd") {
      TRY_RESULT_PROMISE_ASSIGN(promise, actions_ext, ton::ManualDns::parse(parser.read_all()));
    } else if (cmd == "cmdfile") {
      TRY_RESULT_PROMISE(promise, file_data, td::read_file(parser.read_word().str()));
      TRY_RESULT_PROMISE_ASSIGN(promise, actions_ext, ton::ManualDns::parse(file_data));
    }

    std::vector<tonlib_api::object_ptr<tonlib_api::dns_Action>> actions;
    for (auto& action : actions_ext) {
      if (action.name.empty()) {
        actions.push_back(make_object<tonlib_api::dns_actionDeleteAll>());
        td::TerminalIO::out() << "Delete all dns entries\n";
      } else if (action.category == 0) {
        actions.push_back(make_object<tonlib_api::dns_actionDelete>(action.name, 0));
        td::TerminalIO::out() << "Delete all dns enties with name: " << action.name << "\n";
      } else if (!action.data) {
        actions.push_back(make_object<tonlib_api::dns_actionDelete>(action.name, action.category));
        td::TerminalIO::out() << "Delete all dns enties with name and category: " << action.name << ":"
                              << action.category << "\n";
      } else {
        td::StringBuilder sb;

        td::Status error;
        if (action.data.value().data.empty()) {
          TRY_STATUS_PROMISE(promise, td::Status::Error("Empty entry data is not supported"));
        }
        TRY_RESULT_PROMISE(promise, data, tonlib::to_tonlib_api(action.data.value()));
        sb << action.data.value();
        TRY_STATUS_PROMISE(promise, std::move(error));
        td::TerminalIO::out() << "Set dns entry: " << action.name << ":" << action.category << " " << sb.as_cslice()
                              << "\n";
        actions.push_back(make_object<tonlib_api::dns_actionSet>(
            make_object<tonlib_api::dns_entry>(action.name, action.category, std::move(data))));
      }
    }

    auto action = make_object<tonlib_api::actionDns>(std::move(actions));

    td::Slice password;  // empty by default

    auto key = !address.secret.empty() ? make_object<tonlib_api::inputKeyRegular>(
                                             make_object<tonlib_api::key>(address.public_key, address.secret.copy()),
                                             td::SecureString(password))
                                       : nullptr;
    send_query(make_object<tonlib_api::createQuery>(std::move(key), std::move(address.address), 60, std::move(action),
                                                    nullptr),
               promise.send_closure(actor_id(this), &TonlibCli::transfer2, false));
  }

  void remote_time(td::Promise<td::Unit> promise) {
    send_query(make_object<tonlib_api::liteServer_getInfo>(), promise.wrap([](auto&& info) {
      td::TerminalIO::out() << "Lite server time is: " << info->now_ << "\n";
      return td::Unit();
    }));
  }

  void remote_version(td::Promise<td::Unit> promise) {
    send_query(make_object<tonlib_api::liteServer_getInfo>(), promise.wrap([](auto&& info) {
      td::TerminalIO::out() << "Lite server time is: " << info->now_ << "\n";
      td::TerminalIO::out() << "Lite server version is: " << info->version_ << "\n";
      td::TerminalIO::out() << "Lite server capabilities are: " << info->capabilities_ << "\n";
      return td::Unit();
    }));
  }

  void send_file(td::Slice name, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, data, td::read_file_str(name.str()));
    send_query(make_object<tonlib_api::raw_sendMessage>(std::move(data)), promise.wrap([](auto&& info) {
      td::TerminalIO::out() << "Query was sent\n";
      return td::Unit();
    }));
  }

  void save_account(td::Slice cmd, td::Slice path, td::Slice address, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, addr, to_account_address(address, false));
    send_query(make_object<tonlib_api::smc_load>(std::move(addr.address)),
               promise.send_closure(actor_id(this), &TonlibCli::save_account_2, cmd.str(), path.str(), address.str()));
  }

  void save_account_2(std::string cmd, std::string path, std::string address,
                      tonlib_api::object_ptr<tonlib_api::smc_info> info, td::Promise<td::Unit> promise) {
    auto with_query = [&, self = this](auto query, auto log) {
      send_query(std::move(query),
                 promise.send_closure(actor_id(self), &TonlibCli::save_account_3, std::move(path), std::move(log)));
    };
    if (cmd == "saveaccount") {
      with_query(make_object<tonlib_api::smc_getState>(info->id_), PSTRING() << "StateInit of account " << address);
    } else if (cmd == "saveaccountcode") {
      with_query(make_object<tonlib_api::smc_getCode>(info->id_), PSTRING() << "Code of account " << address);
    } else if (cmd == "saveaccountdata") {
      with_query(make_object<tonlib_api::smc_getData>(info->id_), PSTRING() << "Data of account " << address);
    } else {
      promise.set_error(td::Status::Error("Unknown query"));
    }
  }

  void save_account_3(std::string path, std::string log, tonlib_api::object_ptr<tonlib_api::tvm_cell> cell,
                      td::Promise<td::Unit> promise) {
    TRY_STATUS_PROMISE(promise, td::write_file(path, cell->bytes_));
    td::TerminalIO::out() << log << " was successfully written to the disk(" << td::format::as_size(cell->bytes_.size())
                          << ")\n";
    promise.set_value(td::Unit());
  }

  void sync(td::Promise<td::Unit> promise, bool update_last) {
    send_query(make_object<tonlib_api::sync>(), promise.wrap([&, update_last](auto&& block) {
      td::TerminalIO::out() << "synchronized\n";
      td::TerminalIO::out() << to_string(block) << "\n";
      if (update_last) {
        current_block_ = std::move(block);
        td::TerminalIO::out() << "Update current block\n";
      }
      return td::Unit();
    }));
  }
  void set_block_mode(td::Slice mode, td::Promise<td::Unit> promise) {
    if (mode == "auto") {
      block_mode_ = BlockMode::Auto;
      promise.set_value(td::Unit());
    } else if (mode == "manual") {
      block_mode_ = BlockMode::Manual;
      promise.set_value(td::Unit());
    } else {
      promise.set_error(td::Status::Error("Invalid block mode"));
    }
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::tvm_StackEntry>> parse_stack_entry(td::Slice str) {
    if (str.empty() || str.size() > 65535) {
      return td::Status::Error("String is or empty or too big");
    }
    int l = (int)str.size();
    if (str[0] == '"') {
      vm::CellBuilder cb;
      if (l == 1 || str.back() != '"' || l >= 127 + 2 || !cb.store_bytes_bool(str.data() + 1, l - 2)) {
        return td::Status::Error("Failed to parse slice");
      }
      return make_object<tonlib_api::tvm_stackEntrySlice>(
          make_object<tonlib_api::tvm_slice>(vm::std_boc_serialize(cb.finalize()).ok().as_slice().str()));
    }
    if (l >= 3 && (str[0] == 'x' || str[0] == 'b') && str[1] == '{' && str.back() == '}') {
      unsigned char buff[128];
      int bits =
          (str[0] == 'x')
              ? (int)td::bitstring::parse_bitstring_hex_literal(buff, sizeof(buff), str.begin() + 2, str.end() - 1)
              : (int)td::bitstring::parse_bitstring_binary_literal(buff, sizeof(buff), str.begin() + 2, str.end() - 1);
      if (bits < 0) {
        return td::Status::Error("Failed to parse slice");
      }
      return make_object<tonlib_api::tvm_stackEntrySlice>(make_object<tonlib_api::tvm_slice>(
          vm::std_boc_serialize(vm::CellBuilder().store_bits(td::ConstBitPtr{buff}, bits).finalize())
              .ok()
              .as_slice()
              .str()));
    }
    auto num = td::RefInt256{true};
    auto& x = num.unique_write();
    if (l >= 3 && str[0] == '0' && str[1] == 'x') {
      if (x.parse_hex(str.data() + 2, l - 2) != l - 2) {
        return td::Status::Error("Failed to parse a number");
      }
    } else if (l >= 4 && str[0] == '-' && str[1] == '0' && str[2] == 'x') {
      if (x.parse_hex(str.data() + 3, l - 3) != l - 3) {
        return td::Status::Error("Failed to parse a number");
      }
      x.negate().normalize();
    } else if (!l || x.parse_dec(str.data(), l) != l) {
      return td::Status::Error("Failed to parse a number");
    }
    return make_object<tonlib_api::tvm_stackEntryNumber>(make_object<tonlib_api::tvm_numberDecimal>(dec_string(num)));
  }

  td::Result<std::vector<tonlib_api::object_ptr<tonlib_api::tvm_StackEntry>>> parse_stack(td::ConstParser& parser,
                                                                                          td::Slice end_token) {
    std::vector<tonlib_api::object_ptr<tonlib_api::tvm_StackEntry>> stack;
    while (true) {
      auto word = parser.read_word();
      LOG(ERROR) << word << " vs " << end_token;
      if (word == end_token) {
        break;
      }
      if (word == "[") {
        TRY_RESULT(elements, parse_stack(parser, "]"));
        stack.push_back(
            make_object<tonlib_api::tvm_stackEntryTuple>(make_object<tonlib_api::tvm_tuple>(std::move(elements))));
      } else if (word == "(") {
        TRY_RESULT(elements, parse_stack(parser, ")"));
        stack.push_back(
            make_object<tonlib_api::tvm_stackEntryList>(make_object<tonlib_api::tvm_list>(std::move(elements))));
      } else {
        TRY_RESULT(stack_entry, parse_stack_entry(word));
        stack.push_back(std::move(stack_entry));
      }
    }
    return std::move(stack);
  }

  static void store_entry(td::StringBuilder& sb, tonlib_api::tvm_StackEntry& entry) {
    downcast_call(entry, td::overloaded(
                             [&](tonlib_api::tvm_stackEntryCell& cell) {
                               auto r_cell = vm::std_boc_deserialize(cell.cell_->bytes_);
                               if (r_cell.is_error()) {
                                 sb << "<INVALID_CELL>";
                               }
                               auto cs = vm::load_cell_slice(r_cell.move_as_ok());
                               std::stringstream ss;
                               cs.print_rec(ss);
                               sb << ss.str();
                             },
                             [&](tonlib_api::tvm_stackEntrySlice& cell) {
                               auto r_cell = vm::std_boc_deserialize(cell.slice_->bytes_);
                               if (r_cell.is_error()) {
                                 sb << "<INVALID_CELL>";
                               }
                               auto cs = vm::load_cell_slice(r_cell.move_as_ok());
                               std::stringstream ss;
                               cs.print_rec(ss);
                               sb << ss.str();
                             },
                             [&](tonlib_api::tvm_stackEntryNumber& cell) { sb << cell.number_->number_; },
                             [&](tonlib_api::tvm_stackEntryTuple& cell) {
                               sb << "(";
                               for (auto& element : cell.tuple_->elements_) {
                                 sb << " ";
                                 store_entry(sb, *element);
                               }
                               sb << " )";
                             },
                             [&](tonlib_api::tvm_stackEntryList& cell) {
                               sb << "[";
                               for (auto& element : cell.list_->elements_) {
                                 sb << " ";
                                 store_entry(sb, *element);
                               }
                               sb << " ]";
                             },
                             [&](tonlib_api::tvm_stackEntryUnsupported& cell) { sb << "<UNSUPPORTED>"; }));
  }

  void run_method(td::ConstParser& parser, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, addr, to_account_address(parser.read_word(), false));

    auto method_str = parser.read_word();
    tonlib_api::object_ptr<tonlib_api::smc_MethodId> method;
    if (std::all_of(method_str.begin(), method_str.end(), [](auto c) { return c >= '0' && c <= '9'; })) {
      method = make_object<tonlib_api::smc_methodIdNumber>(td::to_integer<td::int32>(method_str.str()));
    } else {
      method = make_object<tonlib_api::smc_methodIdName>(method_str.str());
    }
    TRY_RESULT_PROMISE(promise, stack, parse_stack(parser, ""));
    td::StringBuilder sb;
    for (auto& entry : stack) {
      store_entry(sb, *entry);
      sb << "\n";
    }

    td::TerminalIO::out() << "Run " << to_string(method) << "With stack:\n" << sb.as_cslice();

    auto to_run = make_object<tonlib_api::smc_runGetMethod>(0 /*fixme*/, std::move(method), std::move(stack));

    send_query(make_object<tonlib_api::smc_load>(std::move(addr.address)),
               promise.send_closure(actor_id(this), &TonlibCli::run_method_2, std::move(to_run)));
  }

  void run_method_2(tonlib_api::object_ptr<tonlib_api::smc_runGetMethod> to_run,
                    tonlib_api::object_ptr<tonlib_api::smc_info> info, td::Promise<td::Unit> promise) {
    to_run->id_ = info->id_;
    send_query(std::move(to_run), promise.send_closure(actor_id(this), &TonlibCli::run_method_3));
  }
  void run_method_3(tonlib_api::object_ptr<tonlib_api::smc_runResult> info, td::Promise<td::Unit> promise) {
    td::StringBuilder sb;
    for (auto& entry : info->stack_) {
      store_entry(sb, *entry);
      sb << "\n";
    }

    td::TerminalIO::out() << "Got smc result. exit code: " << info->exit_code_ << ", gas_used: " << info->gas_used_
                          << "\n"
                          << sb.as_cslice();
    promise.set_value({});
  }

  void set_validate_config(td::Slice cmd, td::Slice path, td::Slice name, bool use_callback, bool ignore_cache,
                           td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, data, td::read_file_str(path.str()));

    auto config = make_object<tonlib_api::config>(std::move(data), name.str(), use_callback, ignore_cache);
    if (cmd == "setconfig") {
      send_query(make_object<tonlib_api::options_setConfig>(std::move(config)), promise.wrap([](auto&& info) {
        td::TerminalIO::out() << "Config is set\n";
        return td::Unit();
      }));
    } else {
      send_query(make_object<tonlib_api::options_validateConfig>(std::move(config)), promise.wrap([](auto&& info) {
        td::TerminalIO::out() << "Config is valid: " << to_string(info) << "\n";
        return td::Unit();
      }));
    }
  }

  void dump_netstats() {
    td::TerminalIO::out() << td::tag("snd", td::format::as_size(snd_bytes_)) << "\n";
    td::TerminalIO::out() << td::tag("rcv", td::format::as_size(rcv_bytes_)) << "\n";
  }
  void on_adnl_result(td::uint64 id, td::Result<td::BufferSlice> res) {
    if (res.is_ok()) {
      rcv_bytes_ += res.ok().size();
      send_query(make_object<tonlib_api::onLiteServerQueryResult>(id, res.move_as_ok().as_slice().str()),
                 [](auto r_ok) { LOG_IF(ERROR, r_ok.is_error()) << r_ok.error(); });
    } else {
      send_query(make_object<tonlib_api::onLiteServerQueryError>(
                     id, make_object<tonlib_api::error>(res.error().code(), res.error().message().str())),
                 [](auto r_ok) { LOG_IF(ERROR, r_ok.is_error()) << r_ok.error(); });
    }
  }

  td::Timestamp sync_started_;

  void on_tonlib_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) {
    if (id == 0) {
      switch (result->get_id()) {
        case tonlib_api::updateSendLiteServerQuery::ID: {
          auto update = tonlib_api::move_object_as<tonlib_api::updateSendLiteServerQuery>(std::move(result));
          CHECK(!raw_client_.empty());
          snd_bytes_ += update->data_.size();
          send_closure(raw_client_, &ton::adnl::AdnlExtClient::send_query, "query", td::BufferSlice(update->data_),
                       td::Timestamp::in(5),
                       [actor_id = actor_id(this), id = update->id_](td::Result<td::BufferSlice> res) {
                         send_closure(actor_id, &TonlibCli::on_adnl_result, id, std::move(res));
                       });
          return;
        }
        case tonlib_api::updateSyncState::ID: {
          auto update = tonlib_api::move_object_as<tonlib_api::updateSyncState>(std::move(result));
          switch (update->sync_state_->get_id()) {
            case tonlib_api::syncStateDone::ID: {
              td::TerminalIO::out() << "synchronization: DONE in "
                                    << td::format::as_time(td::Time::now() - sync_started_.at()) << "\n";
              sync_started_ = {};
              break;
            }
            case tonlib_api::syncStateInProgress::ID: {
              if (!sync_started_) {
                sync_started_ = td::Timestamp::now();
              }
              auto progress = tonlib_api::move_object_as<tonlib_api::syncStateInProgress>(update->sync_state_);
              auto from = progress->from_seqno_;
              auto to = progress->to_seqno_;
              auto at = progress->current_seqno_;
              auto d = to - from;
              if (d <= 0) {
                td::TerminalIO::out() << "synchronization: ???\n";
              } else {
                td::TerminalIO::out() << "synchronization: " << 100 * (at - from) / d << "%\n";
              }
              break;
            }
          }
          return;
        }
      }
    }
    auto it = query_handlers_.find(id);
    if (it == query_handlers_.end()) {
      return;
    }
    auto promise = std::move(it->second);
    query_handlers_.erase(it);
    promise.set_value(std::move(result));
  }

  void on_tonlib_error(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::error> error) {
    auto it = query_handlers_.find(id);
    if (it == query_handlers_.end()) {
      return;
    }
    auto promise = std::move(it->second);
    query_handlers_.erase(it);
    promise.set_error(td::Status::Error(error->code_, error->message_));
  }

  template <class QueryT>
  void send_query(tonlib_api::object_ptr<QueryT> query, td::Promise<typename QueryT::ReturnType> promise) {
    if (is_closing_) {
      return;
    }
    tonlib_api::object_ptr<tonlib_api::Function> func = std::move(query);
    if (block_mode_ == BlockMode::Manual && func->get_id() != tonlib_api::sync::ID) {
      if (!current_block_) {
        promise.set_error(td::Status::Error("empty current block"));
        return;
      }
      func = make_object<tonlib_api::withBlock>(
          make_object<tonlib_api::ton_blockIdExt>(current_block_->workchain_, current_block_->shard_,
                                                  current_block_->seqno_, current_block_->root_hash_,
                                                  current_block_->file_hash_),
          std::move(func));
    }
    auto query_id = next_query_id_++;
    td::actor::send_closure(client_, &tonlib::TonlibClient::request, query_id, std::move(func));
    query_handlers_[query_id] =
        [promise = std::move(promise)](td::Result<tonlib_api::object_ptr<tonlib_api::Object>> r_obj) mutable {
          if (r_obj.is_error()) {
            return promise.set_error(r_obj.move_as_error());
          }
          promise.set_value(ton::move_tl_object_as<typename QueryT::ReturnType::element_type>(r_obj.move_as_ok()));
        };
  }

  template <class QueryT>
  td::Result<typename QueryT::ReturnType> sync_send_query(tonlib_api::object_ptr<QueryT> query) {
    if (is_closing_) {
      return td::Status::Error("Closing");
    }
    auto r_obj = tonlib::TonlibClient::static_request(std::move(query));
    if (r_obj->get_id() == tonlib_api::error::ID) {
      auto err = ton::move_tl_object_as<tonlib_api::error>(std::move(r_obj));
      return td::Status::Error(err->code_, err->message_);
    }
    return ton::move_tl_object_as<typename QueryT::ReturnType::element_type>(r_obj);
  }

  td::Status validate_address(td::Slice addr) {
    TRY_STATUS(sync_send_query(make_object<tonlib_api::unpackAccountAddress>(addr.str())));
    return td::Status::OK();
  }

  void unpack_address(td::Slice addr) {
    send_query(make_object<tonlib_api::unpackAccountAddress>(addr.str()),
               [addr = addr.str()](auto r_parsed_addr) mutable {
                 if (r_parsed_addr.is_error()) {
                   LOG(ERROR) << "Failed to parse address: " << r_parsed_addr.error();
                   return;
                 }
                 LOG(ERROR) << to_string(r_parsed_addr.ok());
               });
  }

  void set_bounceable(td::Slice addr, bool bounceable) {
    send_query(make_object<tonlib_api::unpackAccountAddress>(addr.str()), [addr = addr.str(), bounceable,
                                                                           this](auto r_parsed_addr) mutable {
      if (r_parsed_addr.is_error()) {
        LOG(ERROR) << "Failed to parse address: " << r_parsed_addr.error();
        return;
      }
      auto parsed_addr = r_parsed_addr.move_as_ok();
      parsed_addr->bounceable_ = bounceable;
      this->send_query(make_object<tonlib_api::packAccountAddress>(std::move(parsed_addr)), [](auto r_addr) mutable {
        if (r_addr.is_error()) {
          LOG(ERROR) << "Failed to pack address";
          return;
        }
        td::TerminalIO::out() << r_addr.ok()->account_address_ << "\n";
      });
    });
  }

  void generate_key(td::SecureString entropy = {}) {
    if (entropy.size() < 20) {
      td::TerminalIO::out() << "Enter some entropy";
      cont_ = [this, entropy = std::move(entropy)](td::Slice new_entropy) {
        td::SecureString res(entropy.size() + new_entropy.size());
        res.as_mutable_slice().copy_from(entropy.as_slice());
        res.as_mutable_slice().substr(entropy.size()).copy_from(new_entropy);
        generate_key(std::move(res));
      };
      return;
    }
    td::TerminalIO::out() << "Enter password (could be empty)";
    cont_ = [this, entropy = std::move(entropy)](td::Slice password) mutable {
      generate_key(std::move(entropy), td::SecureString(password));
    };
  }

  void generate_key(td::SecureString entropy, td::SecureString password) {
    auto password_copy = password.copy();
    send_query(make_object<tonlib_api::createNewKey>(std::move(password_copy), td::SecureString() /*mnemonic password*/,
                                                     std::move(entropy)),
               [this, password = std::move(password)](auto r_key) mutable {
                 if (r_key.is_error()) {
                   LOG(ERROR) << "Failed to create new key: " << r_key.error();
                   return;
                 }
                 auto key = r_key.move_as_ok();
                 LOG(ERROR) << to_string(key);
                 KeyInfo info;
                 info.public_key = key->public_key_;
                 info.secret = std::move(key->secret_);
                 keys_.push_back(std::move(info));
                 export_key("exportkey", key->public_key_, keys_.size() - 1, std::move(password));
                 store_keys();
               });
  }

  void store_keys() {
    td::SecureString buf(10000);
    td::StringBuilder sb(buf.as_mutable_slice());
    for (auto& info : keys_) {
      sb << info.public_key << " " << td::base64_encode(info.secret) << "\n";
    }
    LOG_IF(FATAL, sb.is_error()) << "StringBuilder overflow";
    td::atomic_write_file(key_db_path(), sb.as_cslice());
  }

  void load_keys() {
    auto r_db = td::read_file_secure(key_db_path());
    if (r_db.is_error()) {
      return;
    }
    auto db = r_db.move_as_ok();
    td::ConstParser parser(db.as_slice());
    while (true) {
      auto public_key = parser.read_word().str();
      {
        auto tmp = td::base64_decode(public_key);
        if (tmp.is_ok()) {
          public_key = td::base64url_encode(tmp.move_as_ok());
        }
      }
      auto secret_b64 = parser.read_word();
      if (secret_b64.empty()) {
        break;
      }
      auto r_secret = td::base64_decode_secure(secret_b64);
      if (r_secret.is_error()) {
        LOG(ERROR) << "Invalid secret database at " << key_db_path();
        return;
      }

      KeyInfo info;
      info.public_key = public_key;
      info.secret = r_secret.move_as_ok();

      keys_.push_back(std::move(info));
    }
  }

  void dump_key(size_t i) {
    td::TerminalIO::out() << "  #" << i << ": Public key: " << keys_[i].public_key << " "
                          << "    Address: "
                          << to_account_address(PSLICE() << i, false).move_as_ok().address->account_address_ << "\n";
  }
  void dump_keys() {
    td::TerminalIO::out() << "Got " << keys_.size() << " keys"
                          << "\n";
    for (size_t i = 0; i < keys_.size(); i++) {
      dump_key(i);
    }
  }
  void delete_all_keys() {
    static td::Slice password = td::Slice("I have written down mnemonic words");
    td::TerminalIO::out() << "You are going to delete ALL PRIVATE KEYS. To confirm enter `" << password << "`\n";
    cont_ = [this](td::Slice entered) {
      if (password == entered) {
        this->do_delete_all_keys();
      } else {
        td::TerminalIO::out() << "Your keys left intact\n";
      }
    };
  }

  void do_delete_all_keys() {
    send_query(make_object<tonlib_api::deleteAllKeys>(), [](auto r_res) {
      if (r_res.is_error()) {
        td::TerminalIO::out() << "Something went wrong: " << r_res.error() << "\n";
        return;
      }
      td::TerminalIO::out() << "All your keys have been deleted\n";
    });
  }

  std::string key_db_path() {
    return options_.key_dir + TD_DIR_SLASH + "key_db";
  }
  std::string channel_db_path() {
    return options_.key_dir + TD_DIR_SLASH + "channel_db";
  }

  td::Result<size_t> to_key_i(td::Slice key) {
    if (key.empty()) {
      return td::Status::Error("Empty key id");
    }
    if (key[0] == '#') {
      TRY_RESULT(res, td::to_integer_safe<size_t>(key.substr(1)));
      if (res < keys_.size()) {
        return res;
      }
      return td::Status::Error("Invalid key id");
    }
    auto r_res = td::to_integer_safe<size_t>(key);
    if (r_res.is_ok() && r_res.ok() < keys_.size()) {
      return r_res.ok();
    }
    if (key.size() < 3) {
      return td::Status::Error("Too short key id");
    }

    auto prefix = td::to_lower(key);
    size_t res = 0;
    size_t cnt = 0;
    for (size_t i = 0; i < keys_.size(); i++) {
      auto full_key = td::to_lower(keys_[i].public_key);
      if (td::begins_with(full_key, prefix)) {
        res = i;
        cnt++;
      }
    }
    if (cnt == 0) {
      return td::Status::Error("Unknown key prefix");
    }
    if (cnt > 1) {
      return td::Status::Error("Non unique key prefix");
    }
    return res;
  }

  template <class F>
  auto with_account_state(int version, std::string public_key, td::uint32 wallet_id, F&& f) {
    if (version == 1) {
      return f(make_object<tonlib_api::testWallet_initialAccountState>(public_key));
    }
    if (version == 2) {
      return f(make_object<tonlib_api::wallet_initialAccountState>(public_key));
    }
    if (version == 4) {
      return f(make_object<tonlib_api::wallet_highload_v1_initialAccountState>(public_key, wallet_id));
    }
    if (version == 5) {
      return f(make_object<tonlib_api::wallet_highload_v2_initialAccountState>(public_key, wallet_id));
    }
    if (version == 6) {
      return f(make_object<tonlib_api::dns_initialAccountState>(public_key, wallet_id));
    }
    return f(make_object<tonlib_api::wallet_v3_initialAccountState>(public_key, wallet_id));
  }

  td::Result<Address> to_account_address(td::Slice public_key) {
    auto r_addr = [&, self = this](td::int32 version, td::int32 revision) {
      auto do_request = [revision, self](auto x) {
        return self->sync_send_query(make_object<tonlib_api::getAccountAddress>(std::move(x), revision));
      };
      return with_account_state(version, public_key.str(), wallet_id_, do_request);
    }(options_.wallet_version, options_.wallet_revision);
    TRY_RESULT(addr, std::move(r_addr));
    Address res;
    res.address = std::move(addr);
    res.public_key = public_key.str();
    return std::move(res);
  }

  td::Result<Address> to_account_address(td::Slice key, bool need_private_key) {
    if (key.empty()) {
      return td::Status::Error("account address is empty");
    }
    if (key == "none" && !need_private_key) {
      return Address{};
    }

    auto at_pos = key.find('@');
    td::optional<std::string> address;
    if (at_pos != td::Slice::npos) {
      address = key.substr(at_pos + 1).str();
      key.truncate(at_pos);
    }

    auto r_key_i = to_key_i(key);

    if (r_key_i.is_ok()) {
      auto& key = keys_[r_key_i.ok()];
      if (address) {
        Address res;
        res.public_key = key.public_key;
        res.secret = key.secret.copy();
        res.address = make_object<tonlib_api::accountAddress>(address.unwrap());
        return std::move(res);
      }

      auto r_addr = to_account_address(key.public_key);
      if (r_addr.is_ok()) {
        Address res = r_addr.move_as_ok();
        res.secret = keys_[r_key_i.ok()].secret.copy();
        return std::move(res);
      }
    }
    if (key == "giver") {
      auto obj = tonlib::TonlibClient::static_request(
          make_object<tonlib_api::getAccountAddress>(make_object<tonlib_api::testGiver_initialAccountState>(), 0));
      if (obj->get_id() != tonlib_api::error::ID) {
        Address res;
        res.address = ton::move_tl_object_as<tonlib_api::accountAddress>(obj);
        return std::move(res);
      } else {
        LOG(ERROR) << "Unexpected error during testGiver_getAccountAddress: " << to_string(obj);
      }
    }
    if (need_private_key) {
      return td::Status::Error("Don't have a private key for this address");
    }
    //TODO: validate address
    Address res;
    res.address = make_object<tonlib_api::accountAddress>(key.str());
    return std::move(res);
  }

  void delete_key(td::Slice key) {
    auto r_key_i = to_key_i(key);
    if (r_key_i.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << key << "]\n";
      return;
    }

    auto key_i = r_key_i.move_as_ok();
    send_query(make_object<tonlib_api::deleteKey>(
                   make_object<tonlib_api::key>(keys_[key_i].public_key, keys_[key_i].secret.copy())),

               [key = key.str()](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't delete key id: [" << key << "] " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << "Ok\n";
               });
  }
  void export_key(std::string cmd, td::Slice key) {
    if (key.empty()) {
      dump_keys();
      td::TerminalIO::out() << "Choose public key (hex prefix or #N)";
      cont_ = [this, cmd](td::Slice key) { this->export_key(cmd, key); };
      return;
    }
    auto r_key_i = to_key_i(key);
    if (r_key_i.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << key << "]\n";
      return;
    }
    auto key_i = r_key_i.move_as_ok();

    td::TerminalIO::out() << "Key #" << key_i << "\n"
                          << "public key: " << td::buffer_to_hex(keys_[key_i].public_key) << "\n";

    td::TerminalIO::out() << "Enter password (could be empty)";
    cont_ = [this, cmd, key = key.str(), key_i](td::Slice password) { this->export_key(cmd, key, key_i, password); };
  }

  void import_key_pem(td::Slice filename, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, data, td::read_file_secure(filename.str()));

    send_query(make_object<tonlib_api::importPemKey>(td::SecureString(), td::SecureString("cucumber"),
                                                     make_object<tonlib_api::exportedPemKey>(std::move(data))),
               promise.wrap([&](auto&& key) {
                 LOG(ERROR) << to_string(key);
                 KeyInfo info;
                 info.public_key = key->public_key_;
                 info.secret = std::move(key->secret_);
                 keys_.push_back(std::move(info));
                 export_key("exportkey", key->public_key_, keys_.size() - 1, td::SecureString());
                 store_keys();
                 return td::Unit();
               }));
  }
  void import_key_raw(td::Slice filename, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, data, td::read_file_secure(filename.str()));

    send_query(make_object<tonlib_api::importUnencryptedKey>(
                   td::SecureString(), make_object<tonlib_api::exportedUnencryptedKey>(std::move(data))),
               promise.wrap([&](auto&& key) {
                 LOG(ERROR) << to_string(key);
                 KeyInfo info;
                 info.public_key = key->public_key_;
                 info.secret = std::move(key->secret_);
                 keys_.push_back(std::move(info));
                 export_key("exportkey", key->public_key_, keys_.size() - 1, td::SecureString());
                 store_keys();
                 return td::Unit();
               }));
  }

  void export_key(std::string cmd, std::string key, size_t key_i, td::Slice password) {
    if (cmd == "exportkey") {
      send_query(make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKeyRegular>(
                     make_object<tonlib_api::key>(keys_[key_i].public_key, keys_[key_i].secret.copy()),
                     td::SecureString(password))),
                 [this, key = std::move(key), key_i](auto r_res) {
                   if (r_res.is_error()) {
                     td::TerminalIO::out() << "Can't export key id: [" << key << "] " << r_res.error() << "\n";
                     return;
                   }
                   dump_key(key_i);
                   for (auto& word : r_res.ok()->word_list_) {
                     td::TerminalIO::out() << "    " << word.as_slice() << "\n";
                   }
                 });
    } else {
      send_query(make_object<tonlib_api::exportPemKey>(
                     make_object<tonlib_api::inputKeyRegular>(
                         make_object<tonlib_api::key>(keys_[key_i].public_key, keys_[key_i].secret.copy()),
                         td::SecureString(password)),
                     td::SecureString("cucumber")),
                 [this, key = std::move(key), key_i](auto r_res) {
                   if (r_res.is_error()) {
                     td::TerminalIO::out() << "Can't export key id: [" << key << "] " << r_res.error() << "\n";
                     return;
                   }
                   dump_key(key_i);
                   td::TerminalIO::out() << "\n" << r_res.ok()->pem_.as_slice() << "\n";
                 });
    }
  }

  void import_key(td::Slice slice, std::vector<td::SecureString> words = {}) {
    td::ConstParser parser(slice);
    while (true) {
      auto word = parser.read_word();
      if (word.empty()) {
        break;
      }
      words.push_back(td::SecureString(word));
    }
    if (words.size() < 24) {
      td::TerminalIO::out() << "Enter mnemonic words (got " << words.size() << " out of 24)";
      cont_ = [this, words = std::move(words)](td::Slice slice) mutable { this->import_key(slice, std::move(words)); };
      return;
    }
    td::TerminalIO::out() << "Enter password (could be empty)";
    cont_ = [this, words = std::move(words)](td::Slice password) mutable {
      this->import_key(std::move(words), password);
    };
  }

  void import_key(std::vector<td::SecureString> words, td::Slice password) {
    send_query(make_object<tonlib_api::importKey>(td::SecureString(password), td::SecureString(""),
                                                  make_object<tonlib_api::exportedKey>(std::move(words))),
               [this, password = td::SecureString(password)](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't import key " << r_res.error() << "\n";
                   return;
                 }
                 auto key = r_res.move_as_ok();
                 LOG(ERROR) << to_string(key);
                 KeyInfo info;
                 info.public_key = key->public_key_;
                 info.secret = std::move(key->secret_);
                 keys_.push_back(std::move(info));
                 export_key("exportkey", key->public_key_, keys_.size() - 1, std::move(password));
                 store_keys();
               });
  }

  void get_state(td::Slice key, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, address, to_account_address(key, false));

    auto address_str = address.address->account_address_;
    send_query(make_object<tonlib_api::getAccountState>(
                   ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address))),
               promise.wrap([address_str](auto&& state) {
                 td::TerminalIO::out() << "Address: " << address_str << "\n";
                 td::TerminalIO::out() << "Balance: "
                                       << Grams{td::narrow_cast<td::uint64>(state->balance_ * (state->balance_ > 0))}
                                       << "\n";
                 td::TerminalIO::out() << "Sync utime: " << state->sync_utime_ << "\n";
                 td::TerminalIO::out() << "transaction.LT: " << state->last_transaction_id_->lt_ << "\n";
                 td::TerminalIO::out() << "transaction.Hash: " << td::base64_encode(state->last_transaction_id_->hash_)
                                       << "\n";
                 td::TerminalIO::out() << to_string(state->account_state_);
                 return td::Unit();
               }));
  }

  void get_address(td::Slice key, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, address, to_account_address(key, false));
    promise.set_value(td::Unit());
    td::TerminalIO::out() << address.address->account_address_ << "\n";
  }

  void get_history(td::Slice key, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, address, to_account_address(key, false));

    send_query(make_object<tonlib_api::getAccountState>(
                   ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address))),
               promise.send_closure(td::actor::actor_id(this), &TonlibCli::get_history2, key.str()));
  }

  void guess_revision(td::Slice key, td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, key_i, to_key_i(key));
    with_account_state(options_.wallet_version, keys_[key_i].public_key, wallet_id_, [&](auto state) {
      send_query(make_object<tonlib_api::guessAccountRevision>(std::move(state)), promise.wrap([](auto revisions) {
        td::TerminalIO::out() << to_string(revisions);
        return td::Unit();
      }));
    });
  }

  void get_history2(td::Slice key, td::Result<tonlib_api::object_ptr<tonlib_api::fullAccountState>> r_state,
                    td::Promise<td::Unit> promise) {
    TRY_RESULT_PROMISE(promise, state, std::move(r_state));
    auto r_address = to_account_address(key, true);
    if (r_address.is_error()) {
      r_address = to_account_address(key, false);
    }
    TRY_RESULT_PROMISE(promise, address, std::move(r_address));
    td::Slice password;

    auto input_key = address.input_key(password);

    send_query(make_object<tonlib_api::raw_getTransactions>(
                   std::move(input_key), ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address)),
                   std::move(state->last_transaction_id_)),
               promise.wrap([](auto res) {
                 td::StringBuilder sb;
                 for (tonlib_api::object_ptr<tonlib_api::raw_transaction>& t : res->transactions_) {
                   td::int64 balance = 0;
                   balance += t->in_msg_->value_;
                   for (auto& ot : t->out_msgs_) {
                     balance -= ot->value_;
                   }
                   if (balance >= 0) {
                     sb << Grams{td::uint64(balance)};
                   } else {
                     sb << "-" << Grams{td::uint64(-balance)};
                   }
                   sb << " Fee: " << Grams{td::uint64(t->fee_)};
                   if (t->in_msg_->source_->account_address_.empty()) {
                     sb << " External ";
                   } else {
                     sb << " From " << t->in_msg_->source_->account_address_;
                   }
                   auto print_msg_data = [](td::StringBuilder& sb,
                                            tonlib_api::object_ptr<tonlib_api::msg_Data>& msg_data) {
                     if (!msg_data) {
                       return;
                     }
                     sb << " ";
                     downcast_call(*msg_data,
                                   td::overloaded([&](tonlib_api::msg_dataRaw& raw) { sb << "<unknown message>"; },
                                                  [&](tonlib_api::msg_dataText& raw) { sb << "{" << raw.text_ << "}"; },
                                                  [&](tonlib_api::msg_dataEncryptedText& raw) { sb << "<encrypted>"; },
                                                  [&](tonlib_api::msg_dataDecryptedText& raw) {
                                                    sb << "decrypted{" << raw.text_ << "}";
                                                  }));
                   };
                   print_msg_data(sb, t->in_msg_->msg_data_);
                   for (auto& ot : t->out_msgs_) {
                     sb << "\n\t";
                     if (ot->destination_->account_address_.empty()) {
                       sb << " External ";
                     } else {
                       sb << " To " << ot->destination_->account_address_;
                     }
                     sb << " " << Grams{td::uint64(ot->value_)};
                     print_msg_data(sb, ot->msg_data_);
                   }
                   sb << "\n";
                 }
                 td::TerminalIO::out() << sb.as_cslice() << "\n";
                 return td::Unit();
               }));
  }

  void transfer(td::ConstParser& parser, td::Slice cmd, td::Promise<td::Unit> cmd_promise) {
    bool from_file = false;
    bool force = false;
    bool use_encryption = false;
    bool use_fake_key = false;
    bool estimate_fees = false;
    if (cmd != "init") {
      td::ConstParser cmd_parser(cmd);
      cmd_parser.advance(td::Slice("transfer").size());
      while (!cmd_parser.empty()) {
        auto c = cmd_parser.peek_char();
        cmd_parser.advance(1);
        if (c == 'F') {
          from_file = true;
        } else if (c == 'f') {
          force = true;
        } else if (c == 'e') {
          use_encryption = true;
        } else if (c == 'k') {
          use_fake_key = true;
        } else if (c == 'c') {
          estimate_fees = true;
        } else {
          cmd_promise.set_error(td::Status::Error(PSLICE() << "Unknown suffix '" << c << "'"));
          return;
        }
      }
    }

    auto from = parser.read_word();
    TRY_RESULT_PROMISE(cmd_promise, from_address, to_account_address(from, true));

    struct Message {
      Address to;
      td::int64 amount;
      std::string message;
    };

    std::vector<tonlib_api::object_ptr<tonlib_api::msg_message>> messages;
    auto add_message = [&](td::ConstParser& parser) {
      auto to = parser.read_word();
      auto grams = parser.read_word();
      parser.skip_whitespaces();
      auto message = parser.read_all();

      Message res;
      TRY_RESULT(address, to_account_address(to, false));
      TRY_RESULT(amount, parse_grams(grams));
      tonlib_api::object_ptr<tonlib_api::msg_Data> data;

      if (use_encryption) {
        data = make_object<tonlib_api::msg_dataDecryptedText>(message.str());
      } else {
        data = make_object<tonlib_api::msg_dataText>(message.str());
      }
      messages.push_back(
          make_object<tonlib_api::msg_message>(std::move(address.address), "", amount.nano, std::move(data)));
      return td::Status::OK();
    };

    if (from_file) {
      TRY_RESULT_PROMISE(cmd_promise, data, td::read_file(parser.read_word().str()));
      auto lines = td::full_split(data.as_slice(), '\n');
      for (auto& line : lines) {
        td::ConstParser parser(line);
        parser.skip_whitespaces();
        if (parser.empty()) {
          continue;
        }
        if (parser.read_word() != "SEND") {
          TRY_STATUS_PROMISE(cmd_promise, td::Status::Error("Expected `SEND` in file"));
        }
        TRY_STATUS_PROMISE(cmd_promise, add_message(parser));
      }
    } else {
      while (parser.skip_whitespaces(), !parser.empty()) {
        TRY_STATUS_PROMISE(cmd_promise, add_message(parser));
      }
    }

    td::Slice password;  // empty by default

    tonlib_api::object_ptr<tonlib_api::InputKey> key =
        !from_address.secret.empty()
            ? make_object<tonlib_api::inputKeyRegular>(
                  make_object<tonlib_api::key>(from_address.public_key, from_address.secret.copy()),
                  td::SecureString(password))
            : nullptr;
    if (use_fake_key) {
      key = make_object<tonlib_api::inputKeyFake>();
    }

    bool allow_send_to_uninited = force;

    send_query(make_object<tonlib_api::createQuery>(
                   std::move(key), std::move(from_address.address), 60,
                   make_object<tonlib_api::actionMsg>(std::move(messages), allow_send_to_uninited), nullptr),
               cmd_promise.send_closure(actor_id(this), &TonlibCli::transfer2, estimate_fees));
  }

  void transfer2(bool estimate_fees, td::Result<tonlib_api::object_ptr<tonlib_api::query_info>> r_info,
                 td::Promise<td::Unit> cmd_promise) {
    if (estimate_fees) {
      send_query(make_object<tonlib_api::query_estimateFees>(r_info.ok()->id_, true), cmd_promise.wrap([](auto&& info) {
        td::TerminalIO::out() << "Extimated fees: " << to_string(info);
        return td::Unit();
      }));
    } else {
      send_query(make_object<tonlib_api::query_send>(r_info.ok()->id_), cmd_promise.wrap([](auto&& info) {
        td::TerminalIO::out() << "Transfer sent: " << to_string(info);
        return td::Unit();
      }));
    }
  }

  void get_hints(td::Slice prefix) {
    auto obj = tonlib::TonlibClient::static_request(make_object<tonlib_api::getBip39Hints>(prefix.str()));
    if (obj->get_id() == tonlib_api::error::ID) {
      return;
    }
    td::TerminalIO::out() << to_string(obj);
  }
};

int main(int argc, char* argv[]) {
  SET_VERBOSITY_LEVEL(verbosity_INFO);
  td::set_default_failure_signal_handler();

  td::OptionsParser p;
  TonlibCli::Options options;
  p.set_description("console for validator for TON Blockchain");
  p.add_option('h', "help", "prints_help", [&]() {
    std::cout << (PSLICE() << p).c_str();
    std::exit(2);
    return td::Status::OK();
  });
  p.add_option('r', "disable-readline", "disable readline", [&]() {
    options.enable_readline = false;
    return td::Status::OK();
  });
  p.add_option('R', "enable-readline", "enable readline", [&]() {
    options.enable_readline = true;
    return td::Status::OK();
  });
  p.add_option('D', "directory", "set keys directory", [&](td::Slice arg) {
    options.key_dir = arg.str();
    return td::Status::OK();
  });
  p.add_option('M', "in-memory", "store keys only in-memory", [&]() {
    options.in_memory = true;
    return td::Status::OK();
  });
  p.add_option('E', "execute", "execute one command", [&](td::Slice arg) {
    options.one_shot = true;
    options.cmd = arg.str();
    return td::Status::OK();
  });
  p.add_option('v', "verbosity", "set verbosity level", [&](td::Slice arg) {
    auto verbosity = td::to_integer<int>(arg);
    SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL) + verbosity);
    return (verbosity >= 0 && verbosity <= 20) ? td::Status::OK() : td::Status::Error("verbosity must be 0..20");
  });
  p.add_option('C', "config-force", "set lite server config, drop config related blockchain cache", [&](td::Slice arg) {
    TRY_RESULT(data, td::read_file_str(arg.str()));
    options.config = std::move(data);
    options.ignore_cache = true;
    return td::Status::OK();
  });
  p.add_option('c', "config", "set lite server config", [&](td::Slice arg) {
    TRY_RESULT(data, td::read_file_str(arg.str()));
    options.config = std::move(data);
    return td::Status::OK();
  });
  p.add_option('N', "config-name", "set lite server config name", [&](td::Slice arg) {
    options.name = arg.str();
    return td::Status::OK();
  });
  p.add_option('n', "use-callbacks-for-network", "do not use this", [&]() {
    options.use_callbacks_for_network = true;
    return td::Status::OK();
  });
  p.add_option('w', "wallet-id", "do not use this", [&](td::Slice arg) {
    TRY_RESULT(wallet_id, td::to_integer_safe<td::uint32>((arg)));
    options.wallet_id = wallet_id;
    return td::Status::OK();
  });
  p.add_option('W', "wallet-version", "do not use this (version[.revision])", [&](td::Slice arg) {
    td::ConstParser parser(arg);
    TRY_RESULT(version, td::to_integer_safe<td::int32>((parser.read_till_nofail('.'))));
    options.wallet_version = version;
    LOG(INFO) << "Use wallet version = " << version;
    if (parser.peek_char() == '.') {
      parser.skip('.');
      TRY_RESULT(revision, td::to_integer_safe<td::int32>((parser.read_all())));
      options.wallet_revision = revision;
      LOG(INFO) << "Use wallet revision = " << revision;
    }
    return td::Status::OK();
  });

  auto S = p.run(argc, argv);
  if (S.is_error()) {
    std::cerr << S.move_as_error().message().str() << std::endl;
    std::_Exit(2);
  }

  td::actor::Scheduler scheduler({2});
  scheduler.run_in_context([&] { td::actor::create_actor<TonlibCli>("console", options).release(); });
  scheduler.run();
  return 0;
}
