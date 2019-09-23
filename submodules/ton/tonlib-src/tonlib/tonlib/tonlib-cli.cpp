#include "td/actor/actor.h"

#include "td/utils/filesystem.h"
#include "td/utils/OptionsParser.h"
#include "td/utils/Parser.h"
#include "td/utils/port/signals.h"
#include "td/utils/port/path.h"
#include "td/utils/Random.h"
#include "td/utils/as.h"

#include "terminal/terminal.h"

#include "tonlib/TonlibClient.h"
#include "tonlib/TonlibCallback.h"

#include "tonlib/ExtClientLazy.h"

#include "auto/tl/tonlib_api.hpp"

#include <iostream>
#include <map>

class TonlibCli : public td::actor::Actor {
 public:
  struct Options {
    bool enable_readline{true};
    std::string config;
    std::string key_dir{"."};
    bool use_callbacks_for_network{false};
  };
  TonlibCli(Options options) : options_(std::move(options)) {
  }

 private:
  Options options_;
  td::actor::ActorOwn<td::TerminalIO> io_;
  td::actor::ActorOwn<tonlib::TonlibClient> client_;
  std::uint64_t next_query_id_{1};
  td::Promise<td::Slice> cont_;

  struct KeyInfo {
    std::string public_key;
    td::SecureString secret;
  };
  std::vector<KeyInfo> keys_;

  std::map<std::uint64_t, td::Promise<tonlib_api::object_ptr<tonlib_api::Object>>> query_handlers_;

  td::actor::ActorOwn<ton::adnl::AdnlExtClient> raw_client_;

  bool is_closing_{false};
  td::uint32 ref_cnt_{1};

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
    io_ = td::TerminalIO::create("> ", options_.enable_readline, std::make_unique<Cb>(actor_shared(this)));
    td::actor::send_closure(io_, &td::TerminalIO::set_log_interface);

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
    client_ = td::actor::create_actor<tonlib::TonlibClient>("Tonlib", td::make_unique<TonlibCb>(actor_shared(this)));

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

    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::init>(make_object<tonlib_api::options>(options_.config, options_.key_dir,
                                                                              options_.use_callbacks_for_network)),
               [](auto r_ok) {
                 LOG_IF(ERROR, r_ok.is_error()) << r_ok.error();
                 td::TerminalIO::out() << "Tonlib is inited\n";
               });
  }
  void hangup_shared() override {
    CHECK(ref_cnt_ > 0);
    ref_cnt_--;
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
    if (cmd == "help") {
      td::TerminalIO::out() << "help - show this help\n";
      td::TerminalIO::out() << "genkey - generate new secret key\n";
      td::TerminalIO::out() << "keys - show all stored keys\n";
      td::TerminalIO::out() << "exportkey [key_id] - export key\n";
      td::TerminalIO::out() << "setconfig <path> - set lite server config\n";
      td::TerminalIO::out() << "getstate <key_id> - get state of simple wallet with requested key\n";
      td::TerminalIO::out()
          << "gethistory <key_id> - get history fo simple wallet with requested key (last 10 transactions)\n";
      td::TerminalIO::out() << "init <key_id> - init simple wallet with requested key\n";
      td::TerminalIO::out() << "transfer <from_key_id> <to_key_id> <amount> - transfer <amount> of grams from "
                               "<from_key_id> to <to_key_id>.\n"
                            << "\t<from_key_id> could also be 'giver'\n"
                            << "\t<to_key_id> could also be 'giver' or smartcontract address\n";
      td::TerminalIO::out() << "exit - exit from this programm\n";
    } else if (cmd == "genkey") {
      generate_key();
    } else if (cmd == "exit") {
      is_closing_ = true;
      io_.reset();
      client_.reset();
      ref_cnt_--;
      try_stop();
    } else if (cmd == "keys") {
      dump_keys();
    } else if (cmd == "exportkey") {
      export_key(parser.read_word());
    } else if (cmd == "importkey") {
      import_key(parser.read_all());
    } else if (cmd == "setconfig") {
      set_config(parser.read_word());
    } else if (cmd == "getstate") {
      get_state(parser.read_word());
    } else if (cmd == "gethistory") {
      get_history(parser.read_word());
    } else if (cmd == "init") {
      init_simple_wallet(parser.read_word());
    } else if (cmd == "transfer") {
      auto from = parser.read_word();
      auto to = parser.read_word();
      auto grams = parser.read_word();
      transfer(from, to, grams);
    } else if (cmd == "hint") {
      get_hints(parser.read_word());
    }
  }

  void on_adnl_result(td::uint64 id, td::Result<td::BufferSlice> res) {
    using tonlib_api::make_object;
    if (res.is_ok()) {
      send_query(make_object<tonlib_api::onLiteServerQueryResult>(id, res.move_as_ok().as_slice().str()),
                 [](auto r_ok) { LOG_IF(ERROR, r_ok.is_error()) << r_ok.error(); });
      LOG(ERROR) << "!!!";
    } else {
      send_query(make_object<tonlib_api::onLiteServerQueryError>(
                     id, make_object<tonlib_api::error>(res.error().code(), res.error().message().str())),
                 [](auto r_ok) { LOG_IF(ERROR, r_ok.is_error()) << r_ok.error(); });
    }
  }

  void on_tonlib_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) {
    if (id == 0) {
      if (result->get_id() == tonlib_api::updateSendLiteServerQuery::ID) {
        auto update = tonlib_api::move_object_as<tonlib_api::updateSendLiteServerQuery>(std::move(result));
        CHECK(!raw_client_.empty());
        send_closure(raw_client_, &ton::adnl::AdnlExtClient::send_query, "query", td::BufferSlice(update->data_),
                     td::Timestamp::in(5),
                     [actor_id = actor_id(this), id = update->id_](td::Result<td::BufferSlice> res) {
                       send_closure(actor_id, &TonlibCli::on_adnl_result, id, std::move(res));
                     });
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
    auto query_id = next_query_id_++;
    td::actor::send_closure(client_, &tonlib::TonlibClient::request, query_id, std::move(query));
    query_handlers_[query_id] =
        [promise = std::move(promise)](td::Result<tonlib_api::object_ptr<tonlib_api::Object>> r_obj) mutable {
          if (r_obj.is_error()) {
            return promise.set_error(r_obj.move_as_error());
          }
          promise.set_value(ton::move_tl_object_as<typename QueryT::ReturnType::element_type>(r_obj.move_as_ok()));
        };
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
    send_query(tonlib_api::make_object<tonlib_api::createNewKey>(
                   std::move(password_copy), td::SecureString() /*mnemonic password*/, std::move(entropy)),
               [this, password = std::move(password)](auto r_key) mutable {
                 if (r_key.is_error()) {
                   LOG(ERROR) << "Failed to create new key: " << r_key.error();
                 }
                 auto key = r_key.move_as_ok();
                 LOG(ERROR) << to_string(key);
                 KeyInfo info;
                 info.public_key = key->public_key_;
                 info.secret = std::move(key->secret_);
                 keys_.push_back(std::move(info));
                 export_key(info.public_key, keys_.size() - 1, std::move(password));
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
      auto public_key = parser.read_word();
      auto secret_b64 = parser.read_word();
      if (secret_b64.empty()) {
        break;
      }
      auto r_secret = td::base64_decode_secure(secret_b64);
      if (r_secret.is_error()) {
        LOG(ERROR) << "Invalid secret database at " << key_db_path();
      }

      KeyInfo info;
      info.public_key = public_key.str();
      info.secret = r_secret.move_as_ok();
      LOG(INFO) << info.public_key;

      keys_.push_back(std::move(info));
    }
  }

  void dump_keys() {
    td::TerminalIO::out() << "Got " << keys_.size() << " keys"
                          << "\n";
    for (size_t i = 0; i < keys_.size(); i++) {
      td::TerminalIO::out() << "  #" << i << ": " << keys_[i].public_key << "\n";
      td::TerminalIO::out() << "    " << to_account_address(PSLICE() << i, false).move_as_ok().address->account_address_
                            << "\n";
    }
  }

  std::string key_db_path() {
    return options_.key_dir + TD_DIR_SLASH + "key_db";
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

  struct Address {
    tonlib_api::object_ptr<tonlib_api::accountAddress> address;
    std::string public_key;
    td::SecureString secret;
  };

  td::Result<Address> to_account_address(td::Slice key, bool need_private_key) {
    if (key.empty()) {
      return td::Status::Error("account address is empty");
    }
    auto r_key_i = to_key_i(key);
    using tonlib_api::make_object;
    if (r_key_i.is_ok()) {
      auto obj = tonlib::TonlibClient::static_request(make_object<tonlib_api::testWallet_getAccountAddress>(
          make_object<tonlib_api::testWallet_initialAccountState>(keys_[r_key_i.ok()].public_key)));
      if (obj->get_id() != tonlib_api::error::ID) {
        Address res;
        res.address = ton::move_tl_object_as<tonlib_api::accountAddress>(obj);
        res.public_key = keys_[r_key_i.ok()].public_key;
        res.secret = keys_[r_key_i.ok()].secret.copy();
        return std::move(res);
      }
    }
    if (key == "giver") {
      auto obj = tonlib::TonlibClient::static_request(make_object<tonlib_api::testGiver_getAccountAddress>());
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

  void export_key(td::Slice key) {
    if (key.empty()) {
      dump_keys();
      td::TerminalIO::out() << "Choose public key (hex prefix or #N)";
      cont_ = [this](td::Slice key) { this->export_key(key); };
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
    cont_ = [this, key = key.str(), key_i](td::Slice password) { this->export_key(key, key_i, password); };
  }

  void export_key(std::string key, size_t key_i, td::Slice password) {
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(
                   make_object<tonlib_api::key>(keys_[key_i].public_key, keys_[key_i].secret.copy()),
                   td::SecureString(password))),
               [key = std::move(key)](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't export key id: [" << key << "] " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << to_string(r_res.ok());
               });
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
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::importKey>(td::SecureString(password), td::SecureString(),
                                                  make_object<tonlib_api::exportedKey>(std::move(words))),
               [](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't import key " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << to_string(r_res.ok());
               });
  }

  void set_config(td::Slice path) {
    auto r_data = td::read_file_str(path.str());
    if (r_data.is_error()) {
      td::TerminalIO::out() << "Can't read file [" << path << "] : " << r_data.error() << "\n";
      return;
    }

    auto data = r_data.move_as_ok();
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::options_setConfig>(data), [](auto r_res) {
      if (r_res.is_error()) {
        td::TerminalIO::out() << "Can't set config: " << r_res.error() << "\n";
        return;
      }
      td::TerminalIO::out() << to_string(r_res.ok());
    });
  }

  void get_state(td::Slice key) {
    if (key.empty()) {
      dump_keys();
      td::TerminalIO::out() << "Choose public key (hex prefix or #N)";
      cont_ = [this](td::Slice key) { this->get_state(key); };
      return;
    }
    auto r_address = to_account_address(key, false);
    if (r_address.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << key << "]\n";
      return;
    }
    auto address = r_address.move_as_ok();
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::generic_getAccountState>(
                   ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address))),
               [](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't get state: " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << to_string(r_res.ok());
               });
  }
  void get_history(td::Slice key) {
    if (key.empty()) {
      dump_keys();
      td::TerminalIO::out() << "Choose public key (hex prefix or #N)";
      cont_ = [this](td::Slice key) { this->get_state(key); };
      return;
    }
    auto r_address = to_account_address(key, false);
    if (r_address.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << key << "]\n";
      return;
    }
    auto address = r_address.move_as_ok();
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::generic_getAccountState>(
                   ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address))),
               [this, key = key.str()](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't get state: " << r_res.error() << "\n";
                   return;
                 }
                 this->get_history(key, *r_res.move_as_ok());
               });
  }

  void get_history(td::Slice key, tonlib_api::generic_AccountState& state) {
    auto r_address = to_account_address(key, false);
    if (r_address.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << key << "]\n";
      return;
    }
    auto address = r_address.move_as_ok();

    tonlib_api::object_ptr<tonlib_api::internal_transactionId> transaction_id;
    downcast_call(state, [&](auto& state) { transaction_id = std::move(state.account_state_->last_transaction_id_); });

    send_query(
        tonlib_api::make_object<tonlib_api::raw_getTransactions>(
            ton::move_tl_object_as<tonlib_api::accountAddress>(std::move(address.address)), std::move(transaction_id)),
        [](auto r_res) {
          if (r_res.is_error()) {
            td::TerminalIO::out() << "Can't get transactions: " << r_res.error() << "\n";
            return;
          }
          td::TerminalIO::out() << to_string(r_res.move_as_ok()) << "\n";
        });
  }

  void transfer(td::Slice from, td::Slice to, td::Slice grams) {
    auto r_from_address = to_account_address(from, true);
    if (r_from_address.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << from << "] : " << r_from_address.error() << "\n";
      return;
    }
    auto r_to_address = to_account_address(to, false);
    if (r_to_address.is_error()) {
      td::TerminalIO::out() << "Unknown key id: [" << to << "] : " << r_to_address.error() << "\n";
      return;
    }
    auto r_grams = td::to_integer_safe<td::uint64>(grams);
    if (r_grams.is_error()) {
      td::TerminalIO::out() << "Invalid grams amount: [" << grams << "]\n";
      return;
    }
    if (from != "giver") {
      td::TerminalIO::out() << "Enter password (could be empty)";
      cont_ = [this, from = r_from_address.move_as_ok(), to = r_to_address.move_as_ok(), grams = r_grams.move_as_ok()](
                  td::Slice password) mutable { this->transfer(std::move(from), std::move(to), grams, password); };
      return;
    }
    transfer(r_from_address.move_as_ok(), r_to_address.move_as_ok(), r_grams.move_as_ok(), "");
  }

  void transfer(Address from, Address to, td::uint64 grams, td::Slice password) {
    td::TerminalIO::out() << "Enter message (could be empty)";
    cont_ = [this, from = std::move(from), to = std::move(to), grams,
             password = password.str()](td::Slice message) mutable {
      this->transfer(std::move(from), std::move(to), grams, password, message);
    };
    return;
  }
  void transfer(Address from, Address to, td::uint64 grams, td::Slice password, td::Slice message) {
    using tonlib_api::make_object;
    auto key = !from.secret.empty()
                   ? make_object<tonlib_api::inputKey>(
                         make_object<tonlib_api::key>(from.public_key, from.secret.copy()), td::SecureString(password))
                   : nullptr;
    send_query(make_object<tonlib_api::generic_sendGrams>(std::move(key), std::move(from.address),
                                                          std::move(to.address), grams, message.str()),
               [](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't get state: " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << to_string(r_res.ok());
               });
  }

  void init_simple_wallet(td::Slice key) {
    if (key.empty()) {
      dump_keys();
      td::TerminalIO::out() << "Choose public key (hex prefix or #N)";
      cont_ = [this](td::Slice key) { this->init_simple_wallet(key); };
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
    cont_ = [this, key = key.str(), key_i](td::Slice password) { this->init_simple_wallet(key, key_i, password); };
  }

  void init_simple_wallet(std::string key, size_t key_i, td::Slice password) {
    using tonlib_api::make_object;
    send_query(make_object<tonlib_api::testWallet_init>(make_object<tonlib_api::inputKey>(
                   make_object<tonlib_api::key>(keys_[key_i].public_key, keys_[key_i].secret.copy()),
                   td::SecureString(password))),
               [key = std::move(key)](auto r_res) {
                 if (r_res.is_error()) {
                   td::TerminalIO::out() << "Can't init wallet with key: [" << key << "] " << r_res.error() << "\n";
                   return;
                 }
                 td::TerminalIO::out() << to_string(r_res.ok());
               });
  }

  void get_hints(td::Slice prefix) {
    using tonlib_api::make_object;
    auto obj = tonlib::TonlibClient::static_request(make_object<tonlib_api::getBip39Hints>(prefix.str()));
    if (obj->get_id() == tonlib_api::error::ID) {
      return;
    }
    td::TerminalIO::out() << to_string(obj);
  }
};

int main(int argc, char* argv[]) {
  using tonlib_api::make_object;
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
  p.add_option('v', "verbosity", "set verbosity level", [&](td::Slice arg) {
    auto verbosity = td::to_integer<int>(arg);
    SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL) + verbosity);
    return (verbosity >= 0 && verbosity <= 20) ? td::Status::OK() : td::Status::Error("verbosity must be 0..20");
  });
  p.add_option('C', "config", "set lite server config", [&](td::Slice arg) {
    TRY_RESULT(data, td::read_file_str(arg.str()));
    options.config = std::move(data);
    return td::Status::OK();
  });
  p.add_option('c', "use_callbacks_for_network (for debug)", "do not use this", [&]() {
    options.use_callbacks_for_network = true;
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
