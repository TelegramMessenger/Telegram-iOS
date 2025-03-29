//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ClientActor.h"
#include "td/telegram/Log.h"
#include "td/telegram/td_api_json.h"
#include "td/telegram/TdCallback.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/MultiPromise.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/crypto.h"
#include "td/utils/FileLog.h"
#include "td/utils/filesystem.h"
#include "td/utils/misc.h"
#include "td/utils/OptionParser.h"
#include "td/utils/port/path.h"
#include "td/utils/port/signals.h"
#include "td/utils/Promise.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"

#include <iostream>
#include <map>
#include <memory>

namespace td {

template <class T>
static void check_td_error(T &result) {
  LOG_CHECK(result->get_id() != td::td_api::error::ID) << to_string(result);
}

class TestClient : public Actor {
 public:
  explicit TestClient(td::string name) : name_(std::move(name)) {
  }
  struct Update {
    td::uint64 id;
    td::tl_object_ptr<td::td_api::Object> object;
    Update(td::uint64 id, td::tl_object_ptr<td::td_api::Object> object) : id(id), object(std::move(object)) {
    }
  };
  class Listener {
   public:
    Listener() = default;
    Listener(const Listener &) = delete;
    Listener &operator=(const Listener &) = delete;
    Listener(Listener &&) = delete;
    Listener &operator=(Listener &&) = delete;
    virtual ~Listener() = default;
    virtual void start_listen(TestClient *client) {
    }
    virtual void stop_listen() {
    }
    virtual void on_update(std::shared_ptr<Update> update) = 0;
  };
  struct RemoveListener {
    void operator()(Listener *listener) {
      send_closure(self, &TestClient::remove_listener, listener);
    }
    ActorId<TestClient> self;
  };
  using ListenerToken = std::unique_ptr<Listener, RemoveListener>;
  void close(td::Promise<> close_promise) {
    close_promise_ = std::move(close_promise);
    td_client_.reset();
  }

  td::unique_ptr<td::TdCallback> make_td_callback() {
    class TdCallbackImpl : public td::TdCallback {
     public:
      explicit TdCallbackImpl(td::ActorId<TestClient> client) : client_(client) {
      }
      void on_result(td::uint64 id, td::tl_object_ptr<td::td_api::Object> result) override {
        send_closure(client_, &TestClient::on_result, id, std::move(result));
      }
      void on_error(td::uint64 id, td::tl_object_ptr<td::td_api::error> error) override {
        send_closure(client_, &TestClient::on_error, id, std::move(error));
      }
      TdCallbackImpl(const TdCallbackImpl &) = delete;
      TdCallbackImpl &operator=(const TdCallbackImpl &) = delete;
      TdCallbackImpl(TdCallbackImpl &&) = delete;
      TdCallbackImpl &operator=(TdCallbackImpl &&) = delete;
      ~TdCallbackImpl() override {
        send_closure(client_, &TestClient::on_closed);
      }

     private:
      td::ActorId<TestClient> client_;
    };
    return td::make_unique<TdCallbackImpl>(actor_id(this));
  }

  void add_listener(td::unique_ptr<Listener> listener) {
    auto *ptr = listener.get();
    listeners_.push_back(std::move(listener));
    ptr->start_listen(this);
  }
  void remove_listener(Listener *listener) {
    pending_remove_.push_back(listener);
  }
  void do_pending_remove_listeners() {
    for (auto listener : pending_remove_) {
      do_remove_listener(listener);
    }
    pending_remove_.clear();
  }
  void do_remove_listener(Listener *listener) {
    for (size_t i = 0; i < listeners_.size(); i++) {
      if (listeners_[i].get() == listener) {
        listener->stop_listen();
        listeners_.erase(listeners_.begin() + i);
        break;
      }
    }
  }

  void on_result(td::uint64 id, td::tl_object_ptr<td::td_api::Object> result) {
    on_update(std::make_shared<Update>(id, std::move(result)));
  }
  void on_error(td::uint64 id, td::tl_object_ptr<td::td_api::error> error) {
    on_update(std::make_shared<Update>(id, std::move(error)));
  }
  void on_update(std::shared_ptr<Update> update) {
    for (auto &listener : listeners_) {
      listener->on_update(update);
    }
    do_pending_remove_listeners();
  }

  void on_closed() {
    stop();
  }

  void start_up() override {
    auto old_context = set_context(std::make_shared<td::ActorContext>());
    set_tag(name_);
    LOG(INFO) << "START UP!";

    td_client_ = td::create_actor<td::ClientActor>("Td-proxy", make_td_callback());
  }

  td::ActorOwn<td::ClientActor> td_client_;

  td::string name_;

 private:
  td::vector<td::unique_ptr<Listener>> listeners_;
  td::vector<Listener *> pending_remove_;

  td::Promise<> close_promise_;
};

class Task : public TestClient::Listener {
 public:
  void on_update(std::shared_ptr<TestClient::Update> update) override {
    auto it = sent_queries_.find(update->id);
    if (it != sent_queries_.end()) {
      it->second.set_value(std::move(update->object));
      sent_queries_.erase(it);
    }
    process_update(update);
  }
  void start_listen(TestClient *client) override {
    client_ = client;
    start_up();
  }
  virtual void process_update(std::shared_ptr<TestClient::Update> update) {
  }

  template <class FunctionT, class CallbackT>
  void send_query(td::tl_object_ptr<FunctionT> function, CallbackT callback) {
    auto id = current_query_id_++;

    using ResultT = typename FunctionT::ReturnType;
    sent_queries_[id] =
        [callback = Promise<ResultT>(std::move(callback))](Result<tl_object_ptr<td_api::Object>> r_obj) mutable {
          TRY_RESULT_PROMISE(callback, obj, std::move(r_obj));
          if (obj->get_id() == td::td_api::error::ID) {
            auto err = move_tl_object_as<td_api::error>(std::move(obj));
            callback.set_error(Status::Error(err->code_, err->message_));
            return;
          }
          callback.set_value(move_tl_object_as<typename ResultT::element_type>(std::move(obj)));
        };
    send_closure(client_->td_client_, &td::ClientActor::request, id, std::move(function));
  }

 protected:
  std::map<td::uint64, Promise<td::tl_object_ptr<td::td_api::Object>>> sent_queries_;
  TestClient *client_ = nullptr;
  td::uint64 current_query_id_ = 1;

  virtual void start_up() {
  }
  void stop() {
    client_->remove_listener(this);
    client_ = nullptr;
  }
  bool is_alive() const {
    return client_ != nullptr;
  }
};

class InitTask : public Task {
 public:
  struct Options {
    string name;
    int32 api_id;
    string api_hash;
  };
  InitTask(Options options, td::Promise<> promise) : options_(std::move(options)), promise_(std::move(promise)) {
  }

 private:
  Options options_;
  td::Promise<> promise_;

  void start_up() override {
    send_query(td::make_tl_object<td::td_api::getOption>("version"),
               [](td::Result<td::td_api::object_ptr<td::td_api::OptionValue>> res) {
                 LOG(INFO) << td::td_api::to_string(res.ok());
               });
  }
  void process_authorization_state(td::tl_object_ptr<td::td_api::Object> authorization_state) {
    td::tl_object_ptr<td::td_api::Function> function;
    switch (authorization_state->get_id()) {
      case td::td_api::authorizationStateReady::ID:
        promise_.set_value({});
        stop();
        break;
      case td::td_api::authorizationStateWaitTdlibParameters::ID: {
        auto request = td::td_api::make_object<td::td_api::setTdlibParameters>();
        request->use_test_dc_ = true;
        request->database_directory_ = options_.name + TD_DIR_SLASH;
        request->use_message_database_ = true;
        request->use_secret_chats_ = true;
        request->api_id_ = options_.api_id;
        request->api_hash_ = options_.api_hash;
        request->system_language_code_ = "en";
        request->device_model_ = "Desktop";
        request->application_version_ = "tdclient-test";
        send(std::move(request));
        break;
      }
      default:
        LOG(ERROR) << "???";
        promise_.set_error(
            Status::Error(PSLICE() << "Unexpected authorization state " << to_string(authorization_state)));
        stop();
        break;
    }
  }
  template <class T>
  void send(T &&query) {
    send_query(std::move(query), [this](td::Result<typename T::element_type::ReturnType> res) {
      if (is_alive()) {
        res.ensure();
      }
    });
  }
  void process_update(std::shared_ptr<TestClient::Update> update) override {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateAuthorizationState::ID) {
      auto update_authorization_state = td::move_tl_object_as<td::td_api::updateAuthorizationState>(update->object);
      process_authorization_state(std::move(update_authorization_state->authorization_state_));
    }
  }
};

class GetMe : public Task {
 public:
  struct Result {
    int64 user_id;
    int64 chat_id;
  };
  explicit GetMe(Promise<Result> promise) : promise_(std::move(promise)) {
  }
  void start_up() override {
    send_query(
        td::make_tl_object<td::td_api::getMe>(),
        [this](td::Result<td::td_api::object_ptr<td::td_api::user>> res) { with_user_id(res.move_as_ok()->id_); });
  }

 private:
  Promise<Result> promise_;
  Result result_;

  void with_user_id(int64 user_id) {
    result_.user_id = user_id;
    send_query(
        td::make_tl_object<td::td_api::createPrivateChat>(user_id, false),
        [this](td::Result<td::td_api::object_ptr<td::td_api::chat>> res) { with_chat_id(res.move_as_ok()->id_); });
  }

  void with_chat_id(int64 chat_id) {
    result_.chat_id = chat_id;
    promise_.set_value(std::move(result_));
    stop();
  }
};

class UploadFile : public Task {
 public:
  struct Result {
    std::string content;
    std::string remote_id;
  };
  UploadFile(std::string dir, std::string content, int64 chat_id, Promise<Result> promise)
      : dir_(std::move(dir)), content_(std::move(content)), chat_id_(std::move(chat_id)), promise_(std::move(promise)) {
  }
  void start_up() override {
    auto hash = hex_encode(sha256(content_)).substr(0, 10);
    content_path_ = dir_ + TD_DIR_SLASH + hash + ".data";
    id_path_ = dir_ + TD_DIR_SLASH + hash + ".id";

    auto r_id = read_file(id_path_);
    if (r_id.is_ok() && r_id.ok().size() > 10) {
      auto id = r_id.move_as_ok();
      LOG(ERROR) << "Receive file from cache";
      Result res;
      res.content = std::move(content_);
      res.remote_id = id.as_slice().str();
      promise_.set_value(std::move(res));
      stop();
      return;
    }

    write_file(content_path_, content_).ensure();

    send_query(td::make_tl_object<td::td_api::sendMessage>(
                   chat_id_, 0, nullptr, nullptr, nullptr,
                   td::make_tl_object<td::td_api::inputMessageDocument>(
                       td::make_tl_object<td::td_api::inputFileLocal>(content_path_), nullptr, true,
                       td::make_tl_object<td::td_api::formattedText>("tag", td::Auto()))),
               [this](td::Result<td::td_api::object_ptr<td::td_api::message>> res) { with_message(res.move_as_ok()); });
  }

 private:
  std::string dir_;
  std::string content_path_;
  std::string id_path_;
  std::string content_;
  int64 chat_id_;
  Promise<Result> promise_;
  int64 file_id_{0};

  void with_message(td::tl_object_ptr<td_api::message> message) {
    CHECK(message->content_->get_id() == td::td_api::messageDocument::ID);
    auto messageDocument = td::move_tl_object_as<td::td_api::messageDocument>(message->content_);
    on_file(*messageDocument->document_->document_, true);
  }

  void on_file(const td_api::file &file, bool force = false) {
    if (force) {
      file_id_ = file.id_;
    }
    if (file.id_ != file_id_) {
      return;
    }
    if (file.remote_->is_uploading_completed_) {
      Result res;
      res.content = std::move(content_);
      res.remote_id = file.remote_->id_;

      unlink(content_path_).ignore();
      atomic_write_file(id_path_, res.remote_id).ignore();

      promise_.set_value(std::move(res));
      stop();
    }
  }

  void process_update(std::shared_ptr<TestClient::Update> update) override {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateFile::ID) {
      auto updateFile = td::move_tl_object_as<td::td_api::updateFile>(update->object);
      on_file(*updateFile->file_);
    }
  }
};

class TestDownloadFile : public Task {
 public:
  TestDownloadFile(std::string remote_id, std::string content, Promise<Unit> promise)
      : remote_id_(std::move(remote_id)), content_(std::move(content)), promise_(std::move(promise)) {
  }
  void start_up() override {
    send_query(td::make_tl_object<td::td_api::getRemoteFile>(remote_id_, nullptr),
               [this](td::Result<td::td_api::object_ptr<td::td_api::file>> res) { start_file(*res.ok()); });
  }

 private:
  std::string remote_id_;
  std::string content_;
  Promise<Unit> promise_;
  struct Range {
    size_t begin;
    size_t end;
  };
  int32 file_id_{0};
  std::vector<Range> ranges_;

  void start_file(const td_api::file &file) {
    LOG(ERROR) << "Start";
    file_id_ = file.id_;
    //    CHECK(!file.local_->is_downloading_active_);
    //    CHECK(!file.local_->is_downloading_completed_);
    //    CHECK(file.local_->download_offset_ == 0);
    if (!file.local_->path_.empty()) {
      unlink(file.local_->path_).ignore();
    }

    auto size = narrow_cast<size_t>(file.size_);
    Random::Xorshift128plus rnd(123);

    size_t begin = 0;

    while (begin + 128u < size) {
      auto chunk_size = rnd.fast(128, 3096);
      auto end = begin + chunk_size;
      if (end > size) {
        end = size;
      }

      ranges_.push_back({begin, end});
      begin = end;
    }

    rand_shuffle(as_mutable_span(ranges_), rnd);
    start_chunk();
  }

  void on_get_chunk(const td_api::file &file) {
    LOG(ERROR) << "Receive chunk";
    auto range = ranges_.back();
    std::string received_chunk(range.end - range.begin, '\0');
    FileFd::open(file.local_->path_, FileFd::Flags::Read).move_as_ok().pread(received_chunk, range.begin).ensure();
    CHECK(received_chunk == as_slice(content_).substr(range.begin, range.end - range.begin));
    ranges_.pop_back();
    if (ranges_.empty()) {
      promise_.set_value(Unit{});
      return stop();
    }
    start_chunk();
  }

  void start_chunk() {
    send_query(td::make_tl_object<td::td_api::downloadFile>(
                   file_id_, 1, static_cast<int64>(ranges_.back().begin),
                   static_cast<int64>(ranges_.back().end - ranges_.back().begin), true),
               [this](td::Result<td::td_api::object_ptr<td::td_api::file>> res) { on_get_chunk(*res.ok()); });
  }
};

static std::string gen_readable_file(size_t block_size, size_t block_count) {
  std::string content;
  for (size_t block_id = 0; block_id < block_count; block_id++) {
    std::string block;
    for (size_t line = 0; block.size() < block_size; line++) {
      block += PSTRING() << "\nblock=" << block_id << ", line=" << line;
    }
    block.resize(block_size);
    content += block;
  }
  return content;
}

class TestTd : public Actor {
 public:
  struct Options {
    std::string alice_dir = "alice";
    std::string bob_dir = "bob";
    int32 api_id{0};
    string api_hash;
  };

  explicit TestTd(Options options) : options_(std::move(options)) {
  }

 private:
  Options options_;
  ActorOwn<TestClient> alice_;
  GetMe::Result alice_id_;
  std::string alice_cache_dir_;
  ActorOwn<TestClient> bob_;

  void start_up() override {
    alice_ = create_actor<TestClient>("Alice", "Alice");
    bob_ = create_actor<TestClient>("Bob", "Bob");

    MultiPromiseActorSafe mp("init");
    mp.add_promise(promise_send_closure(actor_id(this), &TestTd::check_init));

    InitTask::Options options;
    options.api_id = options_.api_id;
    options.api_hash = options_.api_hash;

    options.name = options_.alice_dir;
    td::send_closure(alice_, &TestClient::add_listener, td::make_unique<InitTask>(options, mp.get_promise()));
    options.name = options_.bob_dir;
    td::send_closure(bob_, &TestClient::add_listener, td::make_unique<InitTask>(options, mp.get_promise()));
  }

  void check_init(Result<Unit> res) {
    LOG_IF(FATAL, res.is_error()) << res.error();
    alice_cache_dir_ = options_.alice_dir + TD_DIR_SLASH + "cache";
    mkdir(alice_cache_dir_).ignore();

    td::send_closure(alice_, &TestClient::add_listener,
                     td::make_unique<GetMe>(promise_send_closure(actor_id(this), &TestTd::with_alice_id)));

    //close();
  }

  void with_alice_id(Result<GetMe::Result> alice_id) {
    alice_id_ = alice_id.move_as_ok();
    LOG(ERROR) << "Alice user_id=" << alice_id_.user_id << ", chat_id=" << alice_id_.chat_id;
    auto content = gen_readable_file(65536, 20);
    send_closure(alice_, &TestClient::add_listener,
                 td::make_unique<UploadFile>(alice_cache_dir_, std::move(content), alice_id_.chat_id,
                                             promise_send_closure(actor_id(this), &TestTd::with_file)));
  }
  void with_file(Result<UploadFile::Result> r_result) {
    auto result = r_result.move_as_ok();
    send_closure(
        alice_, &TestClient::add_listener,
        td::make_unique<TestDownloadFile>(result.remote_id, std::move(result.content),
                                          promise_send_closure(actor_id(this), &TestTd::after_test_download_file)));
  }
  void after_test_download_file(Result<Unit>) {
    close();
  }

  void close() {
    MultiPromiseActorSafe mp("close");
    mp.add_promise(promise_send_closure(actor_id(this), &TestTd::check_close));
    td::send_closure(alice_, &TestClient::close, mp.get_promise());
    td::send_closure(bob_, &TestClient::close, mp.get_promise());
  }

  void check_close(Result<Unit> res) {
    Scheduler::instance()->finish();
    stop();
  }
};

static void fail_signal(int sig) {
  signal_safe_write_signal_number(sig);
  while (true) {
    // spin forever to allow debugger to attach
  }
}

static void on_fatal_error(const char *error) {
  std::cerr << "Fatal error: " << error << std::endl;
}
int main(int argc, char **argv) {
  ignore_signal(SignalType::HangUp).ensure();
  ignore_signal(SignalType::Pipe).ensure();
  set_signal_handler(SignalType::Error, fail_signal).ensure();
  set_signal_handler(SignalType::Abort, fail_signal).ensure();
  Log::set_fatal_error_callback(on_fatal_error);
  init_openssl_threads();

  TestTd::Options test_options;

  test_options.api_id = [](auto x) -> int32 {
    if (x) {
      return to_integer<int32>(Slice(x));
    }
    return 0;
  }(std::getenv("TD_API_ID"));
  test_options.api_hash = [](auto x) -> std::string {
    if (x) {
      return x;
    }
    return std::string();
  }(std::getenv("TD_API_HASH"));

  int new_verbosity_level = VERBOSITY_NAME(INFO);

  OptionParser options;
  options.set_description("TDLib experimental tester");
  options.add_option('v', "verbosity", "Set verbosity level", [&](Slice level) {
    int new_verbosity = 1;
    while (begins_with(level, "v")) {
      new_verbosity++;
      level.remove_prefix(1);
    }
    if (!level.empty()) {
      new_verbosity += to_integer<int>(level) - (new_verbosity == 1);
    }
    new_verbosity_level = VERBOSITY_NAME(FATAL) + new_verbosity;
  });
  options.add_check([&] {
    if (test_options.api_id == 0 || test_options.api_hash.empty()) {
      return Status::Error("You must provide valid api-id and api-hash obtained at https://my.telegram.org");
    }
    return Status::OK();
  });
  auto r_non_options = options.run(argc, argv, 0);
  if (r_non_options.is_error()) {
    LOG(PLAIN) << argv[0] << ": " << r_non_options.error().message();
    LOG(PLAIN) << options;
    return 1;
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);

  td::ConcurrentScheduler sched(4, 0);
  sched.create_actor_unsafe<TestTd>(0, "TestTd", std::move(test_options)).release();
  sched.start();
  while (sched.run_main(10)) {
  }
  sched.finish();
  return 0;
}
}  // namespace td

int main(int argc, char **argv) {
  return td::main(argc, argv);
}
