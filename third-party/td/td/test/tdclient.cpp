//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "data.h"

#include "td/telegram/Client.h"
#include "td/telegram/ClientActor.h"
#include "td/telegram/files/PartsManager.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/base64.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/thread.h"
#include "td/utils/Promise.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"

#include <atomic>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <utility>

template <class T>
static void check_td_error(T &result) {
  LOG_CHECK(result->get_id() != td::td_api::error::ID) << to_string(result);
}

class TestClient final : public td::Actor {
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
  void close(td::Promise<> close_promise) {
    close_promise_ = std::move(close_promise);
    td_client_.reset();
  }

  td::unique_ptr<td::TdCallback> make_td_callback() {
    class TdCallbackImpl final : public td::TdCallback {
     public:
      explicit TdCallbackImpl(td::ActorId<TestClient> client) : client_(client) {
      }
      void on_result(td::uint64 id, td::tl_object_ptr<td::td_api::Object> result) final {
        send_closure(client_, &TestClient::on_result, id, std::move(result));
      }
      void on_error(td::uint64 id, td::tl_object_ptr<td::td_api::error> error) final {
        send_closure(client_, &TestClient::on_error, id, std::move(error));
      }
      TdCallbackImpl(const TdCallbackImpl &) = delete;
      TdCallbackImpl &operator=(const TdCallbackImpl &) = delete;
      TdCallbackImpl(TdCallbackImpl &&) = delete;
      TdCallbackImpl &operator=(TdCallbackImpl &&) = delete;
      ~TdCallbackImpl() final {
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

  void start_up() final {
    td::rmrf(name_).ignore();
    auto old_context = set_context(std::make_shared<td::ActorContext>());
    set_tag(name_);
    LOG(INFO) << "Start up!";

    td_client_ = td::create_actor<td::ClientActor>("Td-proxy", make_td_callback());
  }

  td::ActorOwn<td::ClientActor> td_client_;

  td::string name_;

 private:
  td::vector<td::unique_ptr<Listener>> listeners_;
  td::vector<Listener *> pending_remove_;

  td::Promise<> close_promise_;
};

class TestClinetTask : public TestClient::Listener {
 public:
  void on_update(std::shared_ptr<TestClient::Update> update) final {
    auto it = sent_queries_.find(update->id);
    if (it != sent_queries_.end()) {
      it->second(std::move(update->object));
      sent_queries_.erase(it);
    }
    process_update(update);
  }
  void start_listen(TestClient *client) final {
    client_ = client;
    start_up();
  }
  virtual void process_update(std::shared_ptr<TestClient::Update> update) {
  }

  template <class F>
  void send_query(td::tl_object_ptr<td::td_api::Function> function, F callback) {
    auto id = current_query_id_++;
    sent_queries_[id] = std::forward<F>(callback);
    send_closure(client_->td_client_, &td::ClientActor::request, id, std::move(function));
  }

 protected:
  std::map<td::uint64, std::function<void(td::tl_object_ptr<td::td_api::Object>)>> sent_queries_;
  TestClient *client_ = nullptr;
  td::uint64 current_query_id_ = 1;

  virtual void start_up() {
  }
  void stop() {
    client_->remove_listener(this);
  }
};

class DoAuthentication final : public TestClinetTask {
 public:
  DoAuthentication(td::string name, td::string phone, td::string code, td::Promise<> promise)
      : name_(std::move(name)), phone_(std::move(phone)), code_(std::move(code)), promise_(std::move(promise)) {
  }
  void start_up() final {
    send_query(td::make_tl_object<td::td_api::getOption>("version"),
               [](auto res) { LOG(INFO) << td::td_api::to_string(res); });
  }
  void process_authorization_state(td::tl_object_ptr<td::td_api::Object> authorization_state) {
    td::tl_object_ptr<td::td_api::Function> function;
    switch (authorization_state->get_id()) {
      case td::td_api::authorizationStateWaitPhoneNumber::ID:
        function = td::make_tl_object<td::td_api::setAuthenticationPhoneNumber>(phone_, nullptr);
        break;
      case td::td_api::authorizationStateWaitEmailAddress::ID:
        function = td::make_tl_object<td::td_api::setAuthenticationEmailAddress>("alice_test@gmail.com");
        break;
      case td::td_api::authorizationStateWaitEmailCode::ID:
        function = td::make_tl_object<td::td_api::checkAuthenticationEmailCode>(
            td::make_tl_object<td::td_api::emailAddressAuthenticationCode>(code_));
        break;
      case td::td_api::authorizationStateWaitCode::ID:
        function = td::make_tl_object<td::td_api::checkAuthenticationCode>(code_);
        break;
      case td::td_api::authorizationStateWaitRegistration::ID:
        function = td::make_tl_object<td::td_api::registerUser>(name_, "", false);
        break;
      case td::td_api::authorizationStateWaitTdlibParameters::ID: {
        auto request = td::td_api::make_object<td::td_api::setTdlibParameters>();
        request->use_test_dc_ = true;
        request->database_directory_ = name_ + TD_DIR_SLASH;
        request->use_message_database_ = true;
        request->use_secret_chats_ = true;
        request->api_id_ = 94575;
        request->api_hash_ = "a3406de8d171bb422bb6ddf3bbd800e2";
        request->system_language_code_ = "en";
        request->device_model_ = "Desktop";
        request->application_version_ = "tdclient-test";
        function = std::move(request);
        break;
      }
      case td::td_api::authorizationStateReady::ID:
        on_authorization_ready();
        return;
      default:
        LOG(ERROR) << "Unexpected authorization state " << to_string(authorization_state);
        UNREACHABLE();
    }
    send_query(std::move(function), [](auto res) { LOG_CHECK(res->get_id() == td::td_api::ok::ID) << to_string(res); });
  }
  void on_authorization_ready() {
    LOG(INFO) << "Authorization is completed";
    stop();
  }

 private:
  td::string name_;
  td::string phone_;
  td::string code_;
  td::Promise<> promise_;

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateAuthorizationState::ID) {
      auto update_authorization_state = td::move_tl_object_as<td::td_api::updateAuthorizationState>(update->object);
      process_authorization_state(std::move(update_authorization_state->authorization_state_));
    }
  }
};

class SetUsername final : public TestClinetTask {
 public:
  SetUsername(td::string username, td::Promise<> promise)
      : username_(std::move(username)), promise_(std::move(promise)) {
  }

 private:
  td::string username_;
  td::Promise<> promise_;
  td::int64 self_id_ = 0;
  td::string tag_;

  void start_up() final {
    send_query(td::make_tl_object<td::td_api::getMe>(), [this](auto res) { this->process_me_user(std::move(res)); });
  }

  void process_me_user(td::tl_object_ptr<td::td_api::Object> res) {
    CHECK(res->get_id() == td::td_api::user::ID);
    auto user = td::move_tl_object_as<td::td_api::user>(res);
    self_id_ = user->id_;
    auto current_username = user->usernames_ != nullptr ? user->usernames_->editable_username_ : td::string();
    if (current_username != username_) {
      LOG(INFO) << "Set username: " << username_;
      send_query(td::make_tl_object<td::td_api::setUsername>(username_), [this](auto res) {
        CHECK(res->get_id() == td::td_api::ok::ID);
        this->send_self_message();
      });
    } else {
      send_self_message();
    }
  }

  void send_self_message() {
    tag_ = PSTRING() << td::format::as_hex(td::Random::secure_int64());

    send_query(td::make_tl_object<td::td_api::createPrivateChat>(self_id_, false), [this](auto res) {
      CHECK(res->get_id() == td::td_api::chat::ID);
      auto chat = td::move_tl_object_as<td::td_api::chat>(res);
      this->send_query(td::make_tl_object<td::td_api::sendMessage>(
                           chat->id_, 0, nullptr, nullptr, nullptr,
                           td::make_tl_object<td::td_api::inputMessageText>(
                               td::make_tl_object<td::td_api::formattedText>(PSTRING() << tag_ << " INIT", td::Auto()),
                               nullptr, false)),
                       [](auto res) {});
    });
  }

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateMessageSendSucceeded::ID) {
      auto updateNewMessage = td::move_tl_object_as<td::td_api::updateMessageSendSucceeded>(update->object);
      auto &message = updateNewMessage->message_;
      if (message->content_->get_id() == td::td_api::messageText::ID) {
        auto messageText = td::move_tl_object_as<td::td_api::messageText>(message->content_);
        auto text = messageText->text_->text_;
        if (text.substr(0, tag_.size()) == tag_) {
          LOG(INFO) << "Receive self-message";
          return stop();
        }
      }
    }
  }
};

class CheckTestA final : public TestClinetTask {
 public:
  CheckTestA(td::string tag, td::Promise<> promise) : tag_(std::move(tag)), promise_(std::move(promise)) {
  }

 private:
  td::string tag_;
  td::Promise<> promise_;
  td::string previous_text_;
  int cnt_ = 20;

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (update->object->get_id() == td::td_api::updateNewMessage::ID) {
      auto updateNewMessage = td::move_tl_object_as<td::td_api::updateNewMessage>(update->object);
      auto &message = updateNewMessage->message_;
      if (message->content_->get_id() == td::td_api::messageText::ID) {
        auto messageText = td::move_tl_object_as<td::td_api::messageText>(message->content_);
        auto text = messageText->text_->text_;
        if (text.substr(0, tag_.size()) == tag_) {
          LOG_CHECK(text > previous_text_) << td::tag("now", text) << td::tag("previous", previous_text_);
          previous_text_ = text;
          cnt_--;
          LOG(INFO) << "Receive " << td::tag("text", text) << td::tag("left", cnt_);
          if (cnt_ == 0) {
            return stop();
          }
        }
      }
    }
  }
};

class TestA final : public TestClinetTask {
 public:
  TestA(td::string tag, td::string username) : tag_(std::move(tag)), username_(std::move(username)) {
  }

  void start_up() final {
    send_query(td::make_tl_object<td::td_api::searchPublicChat>(username_), [this](auto res) {
      CHECK(res->get_id() == td::td_api::chat::ID);
      auto chat = td::move_tl_object_as<td::td_api::chat>(res);
      for (int i = 0; i < 20; i++) {
        this->send_query(
            td::make_tl_object<td::td_api::sendMessage>(
                chat->id_, 0, nullptr, nullptr, nullptr,
                td::make_tl_object<td::td_api::inputMessageText>(
                    td::make_tl_object<td::td_api::formattedText>(PSTRING() << tag_ << " " << (1000 + i), td::Auto()),
                    nullptr, false)),
            [&](auto res) { this->stop(); });
      }
    });
  }

 private:
  td::string tag_;
  td::string username_;
};

class TestSecretChat final : public TestClinetTask {
 public:
  TestSecretChat(td::string tag, td::string username) : tag_(std::move(tag)), username_(std::move(username)) {
  }

  void start_up() final {
    auto f = [this](auto res) {
      CHECK(res->get_id() == td::td_api::chat::ID);
      auto chat = td::move_tl_object_as<td::td_api::chat>(res);
      this->chat_id_ = chat->id_;
      this->secret_chat_id_ = td::move_tl_object_as<td::td_api::chatTypeSecret>(chat->type_)->secret_chat_id_;
    };
    send_query(td::make_tl_object<td::td_api::searchPublicChat>(username_), [this, f = std::move(f)](auto res) mutable {
      CHECK(res->get_id() == td::td_api::chat::ID);
      auto chat = td::move_tl_object_as<td::td_api::chat>(res);
      CHECK(chat->type_->get_id() == td::td_api::chatTypePrivate::ID);
      auto info = td::move_tl_object_as<td::td_api::chatTypePrivate>(chat->type_);
      this->send_query(td::make_tl_object<td::td_api::createNewSecretChat>(info->user_id_), std::move(f));
    });
  }

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateSecretChat::ID) {
      auto update_secret_chat = td::move_tl_object_as<td::td_api::updateSecretChat>(update->object);
      if (update_secret_chat->secret_chat_->id_ != secret_chat_id_ ||
          update_secret_chat->secret_chat_->state_->get_id() != td::td_api::secretChatStateReady::ID) {
        return;
      }
      LOG(INFO) << "Send encrypted messages";
      for (int i = 0; i < 20; i++) {
        send_query(
            td::make_tl_object<td::td_api::sendMessage>(
                chat_id_, 0, nullptr, nullptr, nullptr,
                td::make_tl_object<td::td_api::inputMessageText>(
                    td::make_tl_object<td::td_api::formattedText>(PSTRING() << tag_ << " " << (1000 + i), td::Auto()),
                    nullptr, false)),
            [](auto res) {});
      }
    }
  }

 private:
  td::string tag_;
  td::string username_;
  td::int64 secret_chat_id_ = 0;
  td::int64 chat_id_ = 0;
};

class TestFileGenerated final : public TestClinetTask {
 public:
  TestFileGenerated(td::string tag, td::string username) : tag_(std::move(tag)), username_(std::move(username)) {
  }

  void start_up() final {
  }

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateNewMessage::ID) {
      auto updateNewMessage = td::move_tl_object_as<td::td_api::updateNewMessage>(update->object);
      auto &message = updateNewMessage->message_;
      chat_id_ = message->chat_id_;
      if (message->content_->get_id() == td::td_api::messageText::ID) {
        auto messageText = td::move_tl_object_as<td::td_api::messageText>(message->content_);
        auto text = messageText->text_->text_;
        if (text.substr(0, tag_.size()) == tag_) {
          if (text.substr(tag_.size() + 1) == "ONE_FILE") {
            return one_file();
          }
        }
      }
    } else if (update->object->get_id() == td::td_api::updateFileGenerationStart::ID) {
      auto info = td::move_tl_object_as<td::td_api::updateFileGenerationStart>(update->object);
      generate_file(info->generation_id_, info->original_path_, info->destination_path_, info->conversion_);
    } else if (update->object->get_id() == td::td_api::updateFile::ID) {
      auto file = td::move_tl_object_as<td::td_api::updateFile>(update->object);
      LOG(INFO) << to_string(file);
    }
  }

  void one_file() {
    LOG(ERROR) << "Start one_file test";
    auto file_path = PSTRING() << "test_documents" << TD_DIR_SLASH << "a.txt";
    td::mkpath(file_path).ensure();
    auto raw_file =
        td::FileFd::open(file_path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
            .move_as_ok();
    auto file = td::BufferedFd<td::FileFd>(std::move(raw_file));
    for (int i = 1; i < 100000; i++) {
      file.write(PSLICE() << i << "\n").ensure();
    }
    file.flush_write().ensure();  // important
    file.close();
    send_query(td::make_tl_object<td::td_api::sendMessage>(
                   chat_id_, 0, nullptr, nullptr, nullptr,
                   td::make_tl_object<td::td_api::inputMessageDocument>(
                       td::make_tl_object<td::td_api::inputFileGenerated>(file_path, "square", 0),
                       td::make_tl_object<td::td_api::inputThumbnail>(
                           td::make_tl_object<td::td_api::inputFileGenerated>(file_path, "thumbnail", 0), 0, 0),
                       true, td::make_tl_object<td::td_api::formattedText>(tag_, td::Auto()))),
               [](auto res) { check_td_error(res); });

    send_query(td::make_tl_object<td::td_api::sendMessage>(
                   chat_id_, 0, nullptr, nullptr, nullptr,
                   td::make_tl_object<td::td_api::inputMessageDocument>(
                       td::make_tl_object<td::td_api::inputFileGenerated>(file_path, "square", 0), nullptr, true,
                       td::make_tl_object<td::td_api::formattedText>(tag_, td::Auto()))),
               [](auto res) { check_td_error(res); });
  }

  class GenerateFile final : public td::Actor {
   public:
    GenerateFile(TestClinetTask *parent, td::int64 id, td::string original_path, td::string destination_path,
                 td::string conversion)
        : parent_(parent)
        , id_(id)
        , original_path_(std::move(original_path))
        , destination_path_(std::move(destination_path))
        , conversion_(std::move(conversion)) {
    }

   private:
    TestClinetTask *parent_;
    td::int64 id_;
    td::string original_path_;
    td::string destination_path_;
    td::string conversion_;

    FILE *from = nullptr;
    FILE *to = nullptr;

    void start_up() final {
      from = std::fopen(original_path_.c_str(), "rb");
      CHECK(from);
      to = std::fopen(destination_path_.c_str(), "wb");
      CHECK(to);
      yield();
    }

    void loop() final {
      int cnt = 0;
      while (true) {
        td::uint32 x;
        auto r = std::fscanf(from, "%u", &x);
        if (r != 1) {
          return stop();
        }
        std::fprintf(to, "%u\n", x * x);
        if (++cnt >= 10000) {
          break;
        }
      }
      auto ready = std::ftell(to);
      LOG(ERROR) << "Ready: " << ready;
      parent_->send_query(td::make_tl_object<td::td_api::setFileGenerationProgress>(
                              id_, 1039823 /*yeah, exact size of this file*/, td::narrow_cast<td::int32>(ready)),
                          [](auto result) { check_td_error(result); });
      set_timeout_in(0.02);
    }
    void tear_down() final {
      std::fclose(from);
      std::fclose(to);
      parent_->send_query(td::make_tl_object<td::td_api::finishFileGeneration>(id_, nullptr),
                          [](auto result) { check_td_error(result); });
    }
  };

  void generate_file(td::int64 id, const td::string &original_path, const td::string &destination_path,
                     const td::string &conversion) {
    LOG(ERROR) << "Generate file " << td::tag("id", id) << td::tag("original_path", original_path)
               << td::tag("destination_path", destination_path) << td::tag("conversion", conversion);
    if (conversion == "square") {
      td::create_actor<GenerateFile>("GenerateFile", this, id, original_path, destination_path, conversion).release();
    } else if (conversion == "thumbnail") {
      td::write_file(destination_path, td::base64url_decode(td::Slice(thumbnail, thumbnail_size)).ok()).ensure();
      send_query(td::make_tl_object<td::td_api::finishFileGeneration>(id, nullptr),
                 [](auto result) { check_td_error(result); });
    } else {
      LOG(FATAL) << "Unknown " << td::tag("conversion", conversion);
    }
  }

 private:
  td::string tag_;
  td::string username_;
  td::int64 chat_id_ = 0;
};

class CheckTestC final : public TestClinetTask {
 public:
  CheckTestC(td::string username, td::string tag, td::Promise<> promise)
      : username_(std::move(username)), tag_(std::move(tag)), promise_(std::move(promise)) {
  }

  void start_up() final {
    send_query(td::make_tl_object<td::td_api::searchPublicChat>(username_), [this](auto res) {
      CHECK(res->get_id() == td::td_api::chat::ID);
      auto chat = td::move_tl_object_as<td::td_api::chat>(res);
      chat_id_ = chat->id_;
      this->one_file();
    });
  }

 private:
  td::string username_;
  td::string tag_;
  td::Promise<> promise_;
  td::int64 chat_id_ = 0;

  void one_file() {
    send_query(td::make_tl_object<td::td_api::sendMessage>(
                   chat_id_, 0, nullptr, nullptr, nullptr,
                   td::make_tl_object<td::td_api::inputMessageText>(
                       td::make_tl_object<td::td_api::formattedText>(PSTRING() << tag_ << " ONE_FILE", td::Auto()),
                       nullptr, false)),
               [](auto res) { check_td_error(res); });
  }

  void process_update(std::shared_ptr<TestClient::Update> update) final {
    if (!update->object) {
      return;
    }
    if (update->object->get_id() == td::td_api::updateNewMessage::ID) {
      auto updateNewMessage = td::move_tl_object_as<td::td_api::updateNewMessage>(update->object);
      auto &message = updateNewMessage->message_;
      if (message->content_->get_id() == td::td_api::messageDocument::ID) {
        auto messageDocument = td::move_tl_object_as<td::td_api::messageDocument>(message->content_);
        auto text = messageDocument->caption_->text_;
        if (text.substr(0, tag_.size()) == tag_) {
          file_id_to_check_ = messageDocument->document_->document_->id_;
          LOG(ERROR) << "Receive file " << to_string(messageDocument->document_->document_);
          send_query(td::make_tl_object<td::td_api::downloadFile>(file_id_to_check_, 1, 0, 0, false),
                     [](auto res) { check_td_error(res); });
        }
      }
    } else if (update->object->get_id() == td::td_api::updateFile::ID) {
      auto updateFile = td::move_tl_object_as<td::td_api::updateFile>(update->object);
      if (updateFile->file_->id_ == file_id_to_check_ && (updateFile->file_->local_->is_downloading_completed_)) {
        check_file(updateFile->file_->local_->path_);
      }
    }
  }

  void check_file(td::CSlice path) {
    FILE *from = std::fopen(path.c_str(), "rb");
    CHECK(from);
    td::uint32 x;
    td::uint32 y = 1;
    while (std::fscanf(from, "%u", &x) == 1) {
      CHECK(x == y * y);
      y++;
    }
    std::fclose(from);
    stop();
  }
  td::int32 file_id_to_check_ = 0;
};

class LoginTestActor final : public td::Actor {
 public:
  explicit LoginTestActor(td::Status *status) : status_(status) {
    *status_ = td::Status::OK();
  }

 private:
  td::Status *status_;
  td::ActorOwn<TestClient> alice_;
  td::ActorOwn<TestClient> bob_;

  td::string alice_phone_ = "9996636437";
  td::string bob_phone_ = "9996636438";
  td::string alice_username_ = "alice_" + alice_phone_;
  td::string bob_username_ = "bob_" + bob_phone_;

  td::string stage_name_;

  void begin_stage(td::string stage_name, double timeout) {
    LOG(WARNING) << "Begin stage '" << stage_name << "'";
    stage_name_ = std::move(stage_name);
    set_timeout_in(timeout);
  }

  void start_up() final {
    begin_stage("Logging in", 160);
    alice_ = td::create_actor<TestClient>("AliceClient", "alice");
    bob_ = td::create_actor<TestClient>("BobClient", "bob");

    td::send_closure(alice_, &TestClient::add_listener,
                     td::make_unique<DoAuthentication>(
                         "alice", alice_phone_, "33333",
                         td::create_event_promise(self_closure(this, &LoginTestActor::start_up_fence_dec))));

    td::send_closure(bob_, &TestClient::add_listener,
                     td::make_unique<DoAuthentication>(
                         "bob", bob_phone_, "33333",
                         td::create_event_promise(self_closure(this, &LoginTestActor::start_up_fence_dec))));
  }

  int start_up_fence_ = 3;
  void start_up_fence_dec() {
    --start_up_fence_;
    if (start_up_fence_ == 0) {
      init();
    } else if (start_up_fence_ == 1) {
      return init();
      class WaitActor final : public td::Actor {
       public:
        WaitActor(double timeout, td::Promise<> promise) : timeout_(timeout), promise_(std::move(promise)) {
        }
        void start_up() final {
          set_timeout_in(timeout_);
        }
        void timeout_expired() final {
          stop();
        }

       private:
        double timeout_;
        td::Promise<> promise_;
      };
      td::create_actor<WaitActor>("WaitActor", 2,
                                  td::create_event_promise(self_closure(this, &LoginTestActor::start_up_fence_dec)))
          .release();
    }
  }

  void init() {
    td::send_closure(alice_, &TestClient::add_listener,
                     td::make_unique<SetUsername>(alice_username_, td::create_event_promise(self_closure(
                                                                       this, &LoginTestActor::init_fence_dec))));
    td::send_closure(bob_, &TestClient::add_listener,
                     td::make_unique<SetUsername>(
                         bob_username_, td::create_event_promise(self_closure(this, &LoginTestActor::init_fence_dec))));
  }

  int init_fence_ = 2;
  void init_fence_dec() {
    if (--init_fence_ == 0) {
      test_a();
    }
  }

  int test_a_fence_ = 2;
  void test_a_fence() {
    if (--test_a_fence_ == 0) {
      test_b();
    }
  }

  void test_a() {
    begin_stage("Ready to create chats", 80);
    td::string alice_tag = PSTRING() << td::format::as_hex(td::Random::secure_int64());
    td::string bob_tag = PSTRING() << td::format::as_hex(td::Random::secure_int64());

    td::send_closure(bob_, &TestClient::add_listener,
                     td::make_unique<CheckTestA>(
                         alice_tag, td::create_event_promise(self_closure(this, &LoginTestActor::test_a_fence))));
    td::send_closure(alice_, &TestClient::add_listener,
                     td::make_unique<CheckTestA>(
                         bob_tag, td::create_event_promise(self_closure(this, &LoginTestActor::test_a_fence))));

    td::send_closure(alice_, &TestClient::add_listener, td::make_unique<TestA>(alice_tag, bob_username_));
    td::send_closure(bob_, &TestClient::add_listener, td::make_unique<TestA>(bob_tag, alice_username_));
    // td::send_closure(alice_, &TestClient::add_listener, td::make_unique<TestChat>(bob_username_));
  }

  void timeout_expired() final {
    LOG(FATAL) << "Timeout expired in stage '" << stage_name_ << "'";
  }

  int test_b_fence_ = 1;
  void test_b_fence() {
    if (--test_b_fence_ == 0) {
      test_c();
    }
  }

  int test_c_fence_ = 1;
  void test_c_fence() {
    if (--test_c_fence_ == 0) {
      finish();
    }
  }

  void test_b() {
    begin_stage("Create secret chat", 40);
    td::string tag = PSTRING() << td::format::as_hex(td::Random::secure_int64());

    td::send_closure(
        bob_, &TestClient::add_listener,
        td::make_unique<CheckTestA>(tag, td::create_event_promise(self_closure(this, &LoginTestActor::test_b_fence))));
    td::send_closure(alice_, &TestClient::add_listener, td::make_unique<TestSecretChat>(tag, bob_username_));
  }

  void test_c() {
    begin_stage("Send generated file", 240);
    td::string tag = PSTRING() << td::format::as_hex(td::Random::secure_int64());

    td::send_closure(
        bob_, &TestClient::add_listener,
        td::make_unique<CheckTestC>(alice_username_, tag,
                                    td::create_event_promise(self_closure(this, &LoginTestActor::test_c_fence))));
    td::send_closure(alice_, &TestClient::add_listener, td::make_unique<TestFileGenerated>(tag, bob_username_));
  }

  int finish_fence_ = 2;
  void finish_fence() {
    finish_fence_--;
    if (finish_fence_ == 0) {
      td::Scheduler::instance()->finish();
      stop();
    }
  }

  void finish() {
    td::send_closure(alice_, &TestClient::close,
                     td::create_event_promise(self_closure(this, &LoginTestActor::finish_fence)));
    td::send_closure(bob_, &TestClient::close,
                     td::create_event_promise(self_closure(this, &LoginTestActor::finish_fence)));
  }
};

class Tdclient_login final : public td::Test {
 public:
  using Test::Test;
  bool step() final {
    if (!is_inited_) {
      sched_.create_actor_unsafe<LoginTestActor>(0, "LoginTestActor", &result_).release();
      sched_.start();
      is_inited_ = true;
    }

    bool ret = sched_.run_main(10);
    if (ret) {
      return true;
    }
    sched_.finish();
    if (result_.is_error()) {
      LOG(ERROR) << result_;
    }
    ASSERT_TRUE(result_.is_ok());
    return false;
  }

 private:
  bool is_inited_ = false;
  td::ConcurrentScheduler sched_{4, 0};
  td::Status result_;
};
//RegisterTest<Tdclient_login> Tdclient_login("Tdclient_login");

TEST(Client, Simple) {
  td::Client client;
  // client.execute({1, td::td_api::make_object<td::td_api::setLogTagVerbosityLevel>("actor", 1)});
  client.send({3, td::make_tl_object<td::td_api::testSquareInt>(3)});
  while (true) {
    auto result = client.receive(10);
    if (result.id == 3) {
      auto test_int = td::td_api::move_object_as<td::td_api::testInt>(result.object);
      ASSERT_EQ(test_int->value_, 9);
      break;
    }
  }
}

TEST(Client, SimpleMulti) {
  std::vector<td::Client> clients(7);
  //for (auto &client : clients) {
  //client.execute({1, td::td_api::make_object<td::td_api::setLogTagVerbosityLevel>("td_requests", 1)});
  //}

  for (size_t i = 0; i < clients.size(); i++) {
    clients[i].send({i + 2, td::make_tl_object<td::td_api::testSquareInt>(3)});
    if (td::Random::fast_bool()) {
      clients[i].send({1, td::make_tl_object<td::td_api::close>()});
    }
  }

  for (size_t i = 0; i < clients.size(); i++) {
    while (true) {
      auto result = clients[i].receive(10);
      if (result.id == i + 2) {
        CHECK(result.object->get_id() == td::td_api::testInt::ID);
        auto test_int = td::td_api::move_object_as<td::td_api::testInt>(result.object);
        ASSERT_EQ(test_int->value_, 9);
        break;
      }
    }
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(Client, Multi) {
  td::vector<td::thread> threads;
  std::atomic<int> ok_count{0};
  for (int i = 0; i < 4; i++) {
    threads.emplace_back([i, &ok_count] {
      for (int j = 0; j < 1000; j++) {
        td::Client client;
        auto request_id = static_cast<td::uint64>(j + 2 + 1000 * i);
        client.send({request_id, td::make_tl_object<td::td_api::testSquareInt>(3)});
        if (j & 1) {
          client.send({1, td::make_tl_object<td::td_api::close>()});
        }
        while (true) {
          auto result = client.receive(10);
          if (result.id == request_id) {
            ok_count++;
            if ((j & 1) == 0) {
              client.send({1, td::make_tl_object<td::td_api::close>()});
            }
          }
          if (result.id == 0 && result.object != nullptr &&
              result.object->get_id() == td::td_api::updateAuthorizationState::ID &&
              static_cast<const td::td_api::updateAuthorizationState *>(result.object.get())
                      ->authorization_state_->get_id() == td::td_api::authorizationStateClosed::ID) {
            ok_count++;
            break;
          }
        }
      }
    });
  }

  for (auto &thread : threads) {
    thread.join();
  }
  ASSERT_EQ(8 * 1000, ok_count.load());
}

TEST(Client, Manager) {
  td::vector<td::thread> threads;
  td::ClientManager client;
#if !TD_EVENTFD_UNSUPPORTED  // Client must be used from a single thread if there is no EventFd
  int threads_n = 4;
#else
  int threads_n = 1;
#endif
  int clients_n = 1000;
  client.send(0, 3, td::make_tl_object<td::td_api::testSquareInt>(3));
  client.send(-1, 3, td::make_tl_object<td::td_api::testSquareInt>(3));
  for (int i = 0; i < threads_n; i++) {
    threads.emplace_back([&] {
      for (int i = 0; i <= clients_n; i++) {
        auto id = client.create_client_id();
        if (i != 0) {
          client.send(id, 3, td::make_tl_object<td::td_api::testSquareInt>(3));
        }
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }

  std::set<td::int32> ids;
  while (ids.size() != static_cast<size_t>(threads_n) * clients_n) {
    auto event = client.receive(10);
    if (event.client_id == 0 || event.client_id == -1) {
      ASSERT_EQ(td::td_api::error::ID, event.object->get_id());
      ASSERT_EQ(400, static_cast<td::td_api::error &>(*event.object).code_);
      continue;
    }
    if (event.request_id == 3) {
      ASSERT_EQ(td::td_api::testInt::ID, event.object->get_id());
      ASSERT_TRUE(ids.insert(event.client_id).second);
    }
  }
}

#if !TD_EVENTFD_UNSUPPORTED  // Client must be used from a single thread if there is no EventFd
TEST(Client, Close) {
  std::atomic<bool> stop_send{false};
  std::atomic<bool> can_stop_receive{false};
  std::atomic<td::int64> send_count{1};
  std::atomic<td::int64> receive_count{0};
  td::Client client;

  std::mutex request_ids_mutex;
  std::set<td::uint64> request_ids;
  request_ids.insert(1);
  td::thread send_thread([&] {
    td::uint64 request_id = 2;
    while (!stop_send.load()) {
      {
        std::unique_lock<std::mutex> guard(request_ids_mutex);
        request_ids.insert(request_id);
      }
      client.send({request_id++, td::make_tl_object<td::td_api::testSquareInt>(3)});
      send_count++;
    }
    can_stop_receive = true;
  });

  td::thread receive_thread([&] {
    auto max_continue_send = td::Random::fast_bool() ? 0 : 1000;
    while (true) {
      auto response = client.receive(10.0);
      if (response.object == nullptr) {
        if (!stop_send) {
          stop_send = true;
        } else {
          return;
        }
      }
      if (response.id > 0) {
        if (!stop_send && response.object->get_id() == td::td_api::error::ID &&
            static_cast<td::td_api::error &>(*response.object).code_ == 500 &&
            td::Random::fast(0, max_continue_send) == 0) {
          stop_send = true;
        }
        receive_count++;
        {
          std::unique_lock<std::mutex> guard(request_ids_mutex);
          size_t erased_count = request_ids.erase(response.id);
          CHECK(erased_count > 0);
        }
      }
      if (can_stop_receive && receive_count == send_count) {
        break;
      }
    }
  });

  td::usleep_for((td::Random::fast_bool() ? 0 : 1000) * (td::Random::fast_bool() ? 1 : 50));
  client.send({1, td::make_tl_object<td::td_api::close>()});

  send_thread.join();
  receive_thread.join();
  ASSERT_EQ(send_count.load(), receive_count.load());
  ASSERT_TRUE(request_ids.empty());
}

TEST(Client, ManagerClose) {
  std::atomic<bool> stop_send{false};
  std::atomic<bool> can_stop_receive{false};
  std::atomic<td::int64> send_count{1};
  std::atomic<td::int64> receive_count{0};
  td::ClientManager client_manager;
  auto client_id = client_manager.create_client_id();

  std::mutex request_ids_mutex;
  std::set<td::uint64> request_ids;
  request_ids.insert(1);
  td::thread send_thread([&] {
    td::uint64 request_id = 2;
    while (!stop_send.load()) {
      {
        std::unique_lock<std::mutex> guard(request_ids_mutex);
        request_ids.insert(request_id);
      }
      client_manager.send(client_id, request_id++, td::make_tl_object<td::td_api::testSquareInt>(3));
      send_count++;
    }
    can_stop_receive = true;
  });

  td::thread receive_thread([&] {
    auto max_continue_send = td::Random::fast_bool() ? 0 : 1000;
    bool can_stop_send = false;
    while (true) {
      auto response = client_manager.receive(10.0);
      if (response.object == nullptr) {
        if (!stop_send) {
          can_stop_send = true;
        } else {
          return;
        }
      }
      if (can_stop_send && max_continue_send-- <= 0) {
        stop_send = true;
      }
      if (response.request_id > 0) {
        receive_count++;
        {
          std::unique_lock<std::mutex> guard(request_ids_mutex);
          size_t erased_count = request_ids.erase(response.request_id);
          CHECK(erased_count > 0);
        }
      }
      if (can_stop_receive && receive_count == send_count) {
        break;
      }
    }
  });

  td::usleep_for((td::Random::fast_bool() ? 0 : 1000) * (td::Random::fast_bool() ? 1 : 50));
  client_manager.send(client_id, 1, td::make_tl_object<td::td_api::close>());

  send_thread.join();
  receive_thread.join();
  ASSERT_EQ(send_count.load(), receive_count.load());
  ASSERT_TRUE(request_ids.empty());
}
#endif
#endif

TEST(Client, ManagerCloseOneThread) {
  td::ClientManager client_manager;

  td::uint64 request_id = 2;
  std::map<td::uint64, td::int32> sent_requests;
  td::uint64 sent_count = 0;
  td::uint64 receive_count = 0;

  auto send_request = [&](td::int32 client_id, td::int32 expected_error_code) {
    sent_count++;
    sent_requests.emplace(request_id, expected_error_code);
    client_manager.send(client_id, request_id++, td::make_tl_object<td::td_api::testSquareInt>(3));
  };

  auto receive = [&] {
    while (receive_count != sent_count) {
      auto response = client_manager.receive(1.0);
      if (response.object == nullptr) {
        continue;
      }
      if (response.request_id > 0) {
        receive_count++;
        auto it = sent_requests.find(response.request_id);
        CHECK(it != sent_requests.end());
        auto expected_error_code = it->second;
        sent_requests.erase(it);

        if (expected_error_code == 0) {
          if (response.request_id == 1) {
            ASSERT_EQ(td::td_api::ok::ID, response.object->get_id());
          } else {
            ASSERT_EQ(td::td_api::testInt::ID, response.object->get_id());
          }
        } else {
          ASSERT_EQ(td::td_api::error::ID, response.object->get_id());
          ASSERT_EQ(expected_error_code, static_cast<td::td_api::error &>(*response.object).code_);
        }
      }
    }
  };

  for (int t = 0; t < 3; t++) {
    for (td::int32 i = -5; i <= 0; i++) {
      send_request(i, 400);
    }

    receive();

    auto client_id = client_manager.create_client_id();

    for (td::int32 i = -5; i < 5; i++) {
      send_request(i, i == client_id ? 0 : (i > 0 && i < client_id ? 500 : 400));
    }

    receive();

    for (int i = 0; i < 10; i++) {
      send_request(client_id, 0);
    }

    receive();

    sent_count++;
    sent_requests.emplace(1, 0);
    client_manager.send(client_id, 1, td::make_tl_object<td::td_api::close>());

    for (int i = 0; i < 10; i++) {
      send_request(client_id, 500);
    }

    receive();

    for (int i = 0; i < 10; i++) {
      send_request(client_id, 500);
    }

    receive();
  }

  ASSERT_TRUE(sent_requests.empty());
}

TEST(PartsManager, hands) {
  {
    td::PartsManager pm;
    pm.init(0, 100000, false, 10, {0, 1, 2}, false, true).ensure_error();
    //pm.set_known_prefix(0, false).ensure();
  }
  {
    td::PartsManager pm;
    pm.init(1, 100000, true, 10, {0, 1, 2}, false, true).ensure_error();
  }
}
