//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/Session.h"

#include "td/telegram/DhCache.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/DcAuthManager.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetType.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UniqueId.h"

#include "td/mtproto/DhCallback.h"
#include "td/mtproto/Handshake.h"
#include "td/mtproto/HandshakeActor.h"
#include "td/mtproto/RawConnection.h"
#include "td/mtproto/RSA.h"
#include "td/mtproto/SessionConnection.h"
#include "td/mtproto/TransportType.h"

#include "td/actor/PromiseFuture.h"

#include "td/utils/algorithm.h"
#include "td/utils/as.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Span.h"
#include "td/utils/Time.h"
#include "td/utils/Timer.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/utf8.h"
#include "td/utils/VectorQueue.h"

#include <atomic>
#include <memory>
#include <tuple>
#include <utility>

namespace td {

namespace detail {

class SemaphoreActor final : public Actor {
 public:
  explicit SemaphoreActor(size_t capacity) : capacity_(capacity) {
  }

  void execute(Promise<Promise<Unit>> promise) {
    if (capacity_ == 0) {
      pending_.push(std::move(promise));
    } else {
      start(std::move(promise));
    }
  }

 private:
  size_t capacity_;
  VectorQueue<Promise<Promise<Unit>>> pending_;

  void finish(Result<Unit>) {
    capacity_++;
    if (!pending_.empty()) {
      start(pending_.pop());
    }
  }

  void start(Promise<Promise<Unit>> promise) {
    CHECK(capacity_ > 0);
    capacity_--;
    promise.set_value(promise_send_closure(actor_id(this), &SemaphoreActor::finish));
  }
};

struct Semaphore {
  explicit Semaphore(size_t capacity) {
    semaphore_ = create_actor<SemaphoreActor>("Semaphore", capacity).release();
  }

  void execute(Promise<Promise<Unit>> promise) {
    send_closure(semaphore_, &SemaphoreActor::execute, std::move(promise));
  }

 private:
  ActorId<SemaphoreActor> semaphore_;
};

class GenAuthKeyActor final : public Actor {
 public:
  GenAuthKeyActor(Slice name, unique_ptr<mtproto::AuthKeyHandshake> handshake,
                  unique_ptr<mtproto::AuthKeyHandshakeContext> context,
                  Promise<unique_ptr<mtproto::RawConnection>> connection_promise,
                  Promise<unique_ptr<mtproto::AuthKeyHandshake>> handshake_promise,
                  std::shared_ptr<Session::Callback> callback)
      : name_(name.str())
      , handshake_(std::move(handshake))
      , context_(std::move(context))
      , connection_promise_(std::move(connection_promise))
      , handshake_promise_(std::move(handshake_promise))
      , callback_(std::move(callback)) {
    if (actor_count_.fetch_add(1, std::memory_order_relaxed) == MIN_HIGH_LOAD_ACTOR_COUNT - 1) {
      LOG(WARNING) << "Number of GenAuthKeyActor exceeded high-load threshold";
    }
  }
  GenAuthKeyActor(const GenAuthKeyActor &) = delete;
  GenAuthKeyActor &operator=(const GenAuthKeyActor &) = delete;
  GenAuthKeyActor(GenAuthKeyActor &&) = delete;
  GenAuthKeyActor &operator=(GenAuthKeyActor &&) = delete;
  ~GenAuthKeyActor() final {
    if (actor_count_.fetch_sub(1, std::memory_order_relaxed) == MIN_HIGH_LOAD_ACTOR_COUNT) {
      LOG(WARNING) << "Number of GenAuthKeyActor became lower than high-load threshold";
    }
  }

  static bool is_high_loaded() {
    return actor_count_.load(std::memory_order_relaxed) >= MIN_HIGH_LOAD_ACTOR_COUNT;
  }

  void on_network(uint32 network_generation) {
    if (network_generation_ != network_generation) {
      send_closure(std::move(child_), &mtproto::HandshakeActor::close);
    }
  }

 private:
  string name_;
  uint32 network_generation_ = 0;
  unique_ptr<mtproto::AuthKeyHandshake> handshake_;
  unique_ptr<mtproto::AuthKeyHandshakeContext> context_;
  Promise<unique_ptr<mtproto::RawConnection>> connection_promise_;
  Promise<unique_ptr<mtproto::AuthKeyHandshake>> handshake_promise_;
  std::shared_ptr<Session::Callback> callback_;
  CancellationTokenSource cancellation_token_source_;

  ActorOwn<mtproto::HandshakeActor> child_;
  Promise<Unit> finish_promise_;

  static constexpr size_t MIN_HIGH_LOAD_ACTOR_COUNT = 100;
  static std::atomic<size_t> actor_count_;

  static TD_THREAD_LOCAL Semaphore *semaphore_;
  Semaphore &get_handshake_semaphore() {
    auto old_context = set_context(std::make_shared<ActorContext>());
    auto old_tag = set_tag(string());
    init_thread_local<Semaphore>(semaphore_, 50);
    set_context(std::move(old_context));
    set_tag(std::move(old_tag));
    return *semaphore_;
  }

  void start_up() final {
    // Bug in Android clang and MSVC
    // std::tuple<Result<int>> b(std::forward_as_tuple(Result<int>()));
    get_handshake_semaphore().execute(promise_send_closure(actor_id(this), &GenAuthKeyActor::do_start_up));
  }

  void do_start_up(Result<Promise<Unit>> r_finish_promise) {
    if (r_finish_promise.is_error()) {
      LOG(ERROR) << "Unexpected error: " << r_finish_promise.error();
    } else {
      finish_promise_ = r_finish_promise.move_as_ok();
    }
    callback_->request_raw_connection(
        nullptr, PromiseCreator::cancellable_lambda(
                     cancellation_token_source_.get_cancellation_token(),
                     [actor_id = actor_id(this)](Result<unique_ptr<mtproto::RawConnection>> r_raw_connection) {
                       send_closure(actor_id, &GenAuthKeyActor::on_connection, std::move(r_raw_connection), false);
                     }));
  }

  void hangup() final {
    if (connection_promise_) {
      connection_promise_.set_error(Status::Error(1, "Canceled"));
    }
    if (handshake_promise_) {
      handshake_promise_.set_error(Status::Error(1, "Canceled"));
    }
    stop();
  }

  void on_connection(Result<unique_ptr<mtproto::RawConnection>> r_raw_connection, bool dummy) {
    if (r_raw_connection.is_error()) {
      connection_promise_.set_error(r_raw_connection.move_as_error());
      handshake_promise_.set_value(std::move(handshake_));
      return;
    }

    auto raw_connection = r_raw_connection.move_as_ok();
    VLOG(dc) << "Receive raw connection " << raw_connection.get();
    network_generation_ = raw_connection->extra().extra;
    child_ = create_actor_on_scheduler<mtproto::HandshakeActor>(
        PSLICE() << name_ + "::HandshakeActor", G()->get_slow_net_scheduler_id(), std::move(handshake_),
        std::move(raw_connection), std::move(context_), 10, std::move(connection_promise_),
        std::move(handshake_promise_));
  }
};

std::atomic<size_t> GenAuthKeyActor::actor_count_;
TD_THREAD_LOCAL Semaphore *GenAuthKeyActor::semaphore_{};

}  // namespace detail

void Session::PendingQueries::push(NetQueryPtr query) {
  auto &queue = query->is_high_priority() ? high_priority_queries_ : regular_queries_;
  queue.push(std::move(query));
}

NetQueryPtr Session::PendingQueries::pop() {
  auto &queue = high_priority_queries_.empty() ? regular_queries_ : high_priority_queries_;
  CHECK(!queue.empty());
  return queue.pop();
}

bool Session::PendingQueries::empty() const {
  return regular_queries_.empty() && high_priority_queries_.empty();
}

Session::Session(unique_ptr<Callback> callback, std::shared_ptr<AuthDataShared> shared_auth_data, int32 raw_dc_id,
                 int32 dc_id, bool is_primary, bool is_main, bool use_pfs, bool persist_tmp_auth_key, bool is_cdn,
                 bool need_destroy_auth_key, const mtproto::AuthKey &tmp_auth_key,
                 const vector<mtproto::ServerSalt> &server_salts)
    : raw_dc_id_(raw_dc_id)
    , dc_id_(dc_id)
    , is_primary_(is_primary)
    , is_main_(is_main)
    , persist_tmp_auth_key_(use_pfs && persist_tmp_auth_key)
    , is_cdn_(is_cdn)
    , need_destroy_auth_key_(need_destroy_auth_key) {
  VLOG(dc) << "Start connection " << tag("need_destroy_auth_key", need_destroy_auth_key_);
  if (need_destroy_auth_key_) {
    use_pfs = false;
    CHECK(!is_cdn);
  }

  shared_auth_data_ = std::move(shared_auth_data);
  auth_data_.set_use_pfs(use_pfs);
  auth_data_.set_main_auth_key(shared_auth_data_->get_auth_key());
  // auth_data_.break_main_auth_key();
  auth_data_.reset_server_time_difference(shared_auth_data_->get_server_time_difference());
  auto now = Time::now();
  auth_data_.set_future_salts(shared_auth_data_->get_future_salts(), now);
  if (use_pfs && !tmp_auth_key.empty()) {
    auth_data_.set_tmp_auth_key(tmp_auth_key);
    if (is_main_) {
      registered_temp_auth_key_ = TempAuthKeyWatchdog::register_auth_key_id(auth_data_.get_tmp_auth_key().id());
    }
    auth_data_.set_future_salts(server_salts, now);
  }
  uint64 session_id = 0;
  do {
    Random::secure_bytes(reinterpret_cast<uint8 *>(&session_id), sizeof(session_id));
  } while (session_id == 0);
  auth_data_.set_session_id(session_id);
  use_pfs_ = use_pfs;
  LOG(WARNING) << "Generate new session_id " << session_id << " for " << (use_pfs ? "temp " : "")
               << (is_cdn ? "CDN " : "") << "auth key " << auth_data_.get_auth_key().id() << " for "
               << (is_main_ ? "main " : "") << "DC" << dc_id;

  callback_ = std::shared_ptr<Callback>(callback.release());

  main_connection_.connection_id_ = 0;
  long_poll_connection_.connection_id_ = 1;

  if (is_cdn) {
    auth_data_.set_header(G()->mtproto_header().get_anonymous_header());
  } else {
    auth_data_.set_header(G()->mtproto_header().get_default_header());
  }
  last_activity_timestamp_ = now;
  last_success_timestamp_ = now - 366 * 86400;
  last_bind_success_timestamp_ = now - 366 * 86400;
}

bool Session::is_high_loaded() {
  return detail::GenAuthKeyActor::is_high_loaded();
}

bool Session::can_destroy_auth_key() const {
  return need_destroy_auth_key_;
}

void Session::start_up() {
  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<Session> session) : session_(std::move(session)) {
    }
    bool on_network(NetType network_type, uint32 network_generation) final {
      send_closure(session_, &Session::on_network, network_type != NetType::None, network_generation);
      return session_.is_alive();
    }
    bool on_online(bool online_flag) final {
      send_closure(session_, &Session::on_online, online_flag);
      return session_.is_alive();
    }
    bool on_logging_out(bool logging_out_flag) final {
      send_closure(session_, &Session::on_logging_out, logging_out_flag);
      return session_.is_alive();
    }

   private:
    ActorId<Session> session_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));

  yield();
}

void Session::on_network(bool network_flag, uint32 network_generation) {
  was_on_network_ = true;
  network_flag_ = network_flag;
  if (network_generation_ != network_generation) {
    network_generation_ = network_generation;
    connection_close(&main_connection_);
    connection_close(&long_poll_connection_);
  }

  for (auto &handshake_info : handshake_info_) {
    if (handshake_info.actor_.empty()) {
      continue;
    }
    send_closure(handshake_info.actor_, &detail::GenAuthKeyActor::on_network, network_generation);
  }

  loop();
}

void Session::on_online(bool online_flag) {
  LOG(DEBUG) << "Set online flag to " << online_flag;
  online_flag_ = online_flag;
  connection_online_update(Time::now(), true);
  loop();
}

void Session::on_logging_out(bool logging_out_flag) {
  LOG(DEBUG) << "Set logging out flag to " << logging_out_flag;
  logging_out_flag_ = logging_out_flag;
  connection_online_update(Time::now(), true);
  loop();
}

void Session::connection_online_update(double now, bool force) {
  bool new_connection_online_flag =
      (online_flag_ || logging_out_flag_) && (has_queries() || last_activity_timestamp_ + 10 > now || is_primary_);
  if (connection_online_flag_ == new_connection_online_flag && !force) {
    return;
  }
  connection_online_flag_ = new_connection_online_flag;
  VLOG(dc) << "Set connection_online " << connection_online_flag_;
  if (main_connection_.connection_) {
    main_connection_.connection_->set_online(connection_online_flag_, is_primary_);
  }
  if (long_poll_connection_.connection_) {
    long_poll_connection_.connection_->set_online(connection_online_flag_, is_primary_);
  }
}

void Session::send(NetQueryPtr &&query) {
  last_activity_timestamp_ = Time::now();

  // query->debug(PSTRING() << get_name() << ": received by Session");
  query->set_session_id(auth_data_.get_session_id());
  VLOG(net_query) << "Receive query " << query;
  if (query->update_is_ready()) {
    return_query(std::move(query));
    return;
  }
  add_query(std::move(query));
  loop();
}

void Session::on_bind_result(NetQueryPtr query) {
  LOG(INFO) << "Receive answer to BindKey: " << query;
  being_binded_tmp_auth_key_id_ = 0;
  last_bind_query_id_ = 0;

  Status status;
  if (query->is_error()) {
    status = query->move_as_error();
    if (status.code() == 400 && status.message() == "ENCRYPTED_MESSAGE_INVALID") {
      auto server_time = G()->server_time();
      auto auth_key_creation_date = auth_data_.get_main_auth_key().created_at();
      auto auth_key_age = server_time - auth_key_creation_date;
      auto is_server_time_reliable = G()->is_server_time_reliable();
      auto last_success_time = use_pfs_ ? last_bind_success_timestamp_ : last_success_timestamp_;
      auto now = Time::now();
      bool has_immunity =
          !is_server_time_reliable || auth_key_age < 60 || (auth_key_age > 86400 && last_success_time > now - 86400);
      auto debug = PSTRING() << ". Server time is " << server_time << ", auth key created at " << auth_key_creation_date
                             << ", is_server_time_reliable = " << is_server_time_reliable << ", use_pfs = " << use_pfs_
                             << ", last_success_time = " << last_success_time << ", now = " << now;
      if (!use_pfs_) {
        if (has_immunity) {
          LOG(WARNING) << "Do not drop main key, because it was created too recently" << debug;
        } else {
          LOG(WARNING) << "Drop main key because check with temporary key failed" << debug;
          auth_data_.drop_main_auth_key();
          on_auth_key_updated();
          G()->log_out("Main authorization key is invalid");
        }
      } else {
        if (has_immunity) {
          LOG(WARNING) << "Do not validate main key, because it was created too recently" << debug;
        } else {
          need_check_main_key_ = true;
          auth_data_.set_use_pfs(false);
          LOG(WARNING) << "Receive ENCRYPTED_MESSAGE_INVALID error, validate main key" << debug;
        }
      }
    }
  } else {
    auto answer = query->move_as_ok();
    auto r_flag = fetch_result<telegram_api::auth_bindTempAuthKey>(answer);
    if (r_flag.is_error()) {
      status = r_flag.move_as_error();
    } else if (!r_flag.ok()) {
      status = Status::Error("Returned false");
    }
  }
  if (status.is_ok()) {
    LOG(INFO) << "Bound temp auth key " << auth_data_.get_tmp_auth_key().id();
    auth_data_.on_bind();
    last_bind_success_timestamp_ = Time::now();
    on_tmp_auth_key_updated();
  } else if (status.message() == "DispatchTtlError") {
    LOG(INFO) << "Resend bind auth key " << auth_data_.get_tmp_auth_key().id() << " request after DispatchTtlError";
  } else {
    LOG(ERROR) << "BindKey failed: " << status;
    connection_close(&main_connection_);
    connection_close(&long_poll_connection_);
  }

  yield();
}

void Session::on_check_key_result(NetQueryPtr query) {
  LOG(INFO) << "Receive answer to GetNearestDc: " << query;
  being_checked_main_auth_key_id_ = 0;
  last_check_query_id_ = 0;

  Status status;
  if (query->is_error()) {
    status = query->move_as_error();
  } else {
    auto answer = query->move_as_ok();
    auto r_flag = fetch_result<telegram_api::help_getNearestDc>(answer);
    if (r_flag.is_error()) {
      status = r_flag.move_as_error();
    }
  }
  if (status.is_ok() || status.code() != -404) {
    LOG(INFO) << "Check main key ok";
    need_check_main_key_ = false;
    auth_data_.set_use_pfs(true);
  } else {
    LOG(ERROR) << "Check main key failed: " << status;
    connection_close(&main_connection_);
    connection_close(&long_poll_connection_);
  }

  yield();
}

void Session::on_result(NetQueryPtr query) {
  CHECK(UniqueId::extract_type(query->id()) == UniqueId::BindKey);
  if (last_bind_query_id_ == query->id()) {
    return on_bind_result(std::move(query));
  }
  if (last_check_query_id_ == query->id()) {
    return on_check_key_result(std::move(query));
  }
  query->clear();
}

void Session::return_query(NetQueryPtr &&query) {
  last_activity_timestamp_ = Time::now();

  query->set_session_id(0);
  callback_->on_result(std::move(query));
}

void Session::flush_pending_invoke_after_queries() {
  while (!pending_invoke_after_queries_.empty()) {
    auto &query = pending_invoke_after_queries_.front();
    pending_queries_.push(std::move(query));
    pending_invoke_after_queries_.pop_front();
  }
}

void Session::close() {
  LOG(INFO) << "Close session (external)";
  close_flag_ = true;
  connection_close(&main_connection_);
  connection_close(&long_poll_connection_);

  for (auto &it : sent_queries_) {
    auto &query = it.second.net_query_;
    query->set_message_id(0);
    pending_queries_.push(std::move(query));
  }
  sent_queries_.clear();
  sent_containers_.clear();

  flush_pending_invoke_after_queries();
  CHECK(sent_queries_.empty());
  while (!pending_queries_.empty()) {
    auto query = pending_queries_.pop();
    query->set_error_resend();
    return_query(std::move(query));
  }

  callback_->on_closed();
  stop();
}

void Session::hangup() {
  LOG(DEBUG) << "HANGUP";
  close();
}

void Session::raw_event(const Event::Raw &event) {
  auto message_id = mtproto::MessageId(event.u64);
  auto it = sent_queries_.find(message_id);
  if (it == sent_queries_.end()) {
    return;
  }

  dec_container(it->first, it->second);
  mark_as_known(it->first, it->second);

  auto query = std::move(it->second.net_query_);
  LOG(DEBUG) << "Drop answer for " << query;
  query->set_message_id(0);
  sent_queries_.erase(it);
  return_query(std::move(query));

  if (main_connection_.state_ == ConnectionInfo::State::Ready) {
    main_connection_.connection_->cancel_answer(message_id);
  } else {
    to_cancel_message_ids_.push_back(message_id);
  }
  loop();
}

/** Connection::Callback **/
void Session::on_connected() {
  if (is_main_) {
    connection_token_ =
        mtproto::ConnectionManager::connection(static_cast<ActorId<mtproto::ConnectionManager>>(G()->state_manager()));
  }
}

Status Session::on_pong(double ping_time, double pong_time, double current_time) {
  constexpr int MIN_CONNECTION_ACTIVE = 60;
  if (current_info_ == &main_connection_ &&
      Timestamp::at(current_info_->created_at_ + MIN_CONNECTION_ACTIVE).is_in_past()) {
    Status status;
    if (!unknown_queries_.empty()) {
      status = Status::Error(PSLICE() << "No state info for " << unknown_queries_.size() << " queries from auth key "
                                      << auth_data_.get_auth_key().id() << " for "
                                      << format::as_time(Time::now() - current_info_->created_at_)
                                      << " after ping sent at " << ping_time << " and answered at " << pong_time
                                      << " with the current server time " << current_time);
    }
    if (!sent_queries_list_.empty()) {
      double query_timeout = 60 + (current_time - ping_time);
      for (auto it = sent_queries_list_.prev; it != &sent_queries_list_; it = it->prev) {
        auto query = Query::from_list_node(it);
        if (Timestamp::at(query->sent_at_ + query_timeout).is_in_past()) {
          if (status.is_ok()) {
            status =
                Status::Error(PSLICE() << "No answer from auth key " << auth_data_.get_auth_key().id() << " for "
                                       << query->net_query_ << " for " << format::as_time(Time::now() - query->sent_at_)
                                       << " after ping sent at " << ping_time << " and answered at " << pong_time
                                       << " with the current server time " << current_time);
          }
          query->is_acknowledged_ = false;
        } else {
          break;
        }
      }
    }
    return status;
  }
  return Status::OK();
}

void Session::on_auth_key_updated() {
  shared_auth_data_->set_auth_key(auth_data_.get_main_auth_key());
}

void Session::on_tmp_auth_key_updated() {
  callback_->on_tmp_auth_key_updated(auth_data_.get_tmp_auth_key());
}

void Session::on_server_salt_updated() {
  if (auth_data_.use_pfs()) {
    callback_->on_server_salt_updated(auth_data_.get_future_salts());
    return;
  }
  shared_auth_data_->set_future_salts(auth_data_.get_future_salts());
}

void Session::on_server_time_difference_updated(bool force) {
  shared_auth_data_->update_server_time_difference(auth_data_.get_server_time_difference(), force);
}

void Session::on_closed(Status status) {
  if (!close_flag_ && is_main_) {
    connection_token_.reset();
  }
  auto raw_connection = current_info_->connection_->move_as_raw_connection();
  Scheduler::unsubscribe_before_close(raw_connection->get_poll_info().get_pollable_fd_ref());
  raw_connection->close();

  if (status.is_error() && status.code() == -404) {
    if (auth_data_.use_pfs()) {
      LOG(WARNING) << "Invalidate tmp_key";
      auth_data_.drop_tmp_auth_key();
      on_tmp_auth_key_updated();
      yield();
    } else if (is_cdn_) {
      LOG(WARNING) << "Invalidate CDN tmp_key";
      auth_data_.drop_main_auth_key();
      on_auth_key_updated();
      on_session_failed(status.clone());
    } else if (need_destroy_auth_key_) {
      LOG(WARNING) << "Session connection was closed, because main auth_key has been successfully destroyed";
      auth_data_.drop_main_auth_key();
      on_auth_key_updated();
    } else {
      // log out if has error and or 1 minute is passed from start, or 1 minute has passed since auth_key creation
      if (!use_pfs_) {
        LOG(WARNING) << "Use PFS to check main key";
        auth_data_.set_use_pfs(true);
      } else if (need_check_main_key_) {
        LOG(WARNING) << "Invalidate main key";
        bool can_drop_main_auth_key_without_logging_out =
            !is_main_ && G()->net_query_dispatcher().get_main_dc_id().get_raw_id() != raw_dc_id_;
        auth_data_.drop_main_auth_key();
        on_auth_key_updated();
        if (can_drop_main_auth_key_without_logging_out) {
          on_session_failed(status.clone());
        } else {
          G()->log_out("Main PFS authorization key is invalid");
        }
      } else {
        LOG(WARNING) << "Session connection was closed: " << status << ' ' << current_info_->connection_->get_name();
      }
      yield();
    }
  } else {
    if (status.is_error()) {
      LOG(WARNING) << "Session connection with " << sent_queries_.size() << " pending requests was closed: " << status
                   << ' ' << current_info_->connection_->get_name();
    } else {
      LOG(INFO) << "Session connection with " << sent_queries_.size() << " pending requests was closed: " << status
                << ' ' << current_info_->connection_->get_name();
    }
  }

  // resend all queries without ack
  for (auto it = sent_queries_.begin(); it != sent_queries_.end();) {
    if (!it->second.is_acknowledged_ && it->second.connection_id_ == current_info_->connection_id_) {
      cleanup_container(it->first, it->second);
      // mark query as unknown
      if (status.is_error() && status.code() == 500) {
        mark_as_known(it->first, it->second);

        auto &query = it->second.net_query_;
        VLOG(net_query) << "Resend query (on_disconnected, no ack) " << query;
        query->set_message_id(0);
        query->set_error(Status::Error(500, PSLICE() << "Session failed: " << status.message()),
                         current_info_->connection_->get_name().str());
        return_query(std::move(query));
        it = sent_queries_.erase(it);
      } else {
        mark_as_unknown(it->first, it->second);
        ++it;
      }
    } else {
      ++it;
    }
  }

  current_info_->connection_.reset();
  current_info_->state_ = ConnectionInfo::State::Empty;
}

void Session::on_new_session_created(uint64 unique_id, mtproto::MessageId first_message_id) {
  LOG(INFO) << "New session " << unique_id << " created with first " << first_message_id;
  if (!use_pfs_ && !auth_data_.use_pfs()) {
    last_success_timestamp_ = Time::now();
  }
  if (is_main_) {
    LOG(DEBUG) << "Sending updatesTooLong to force getDifference";
    BufferSlice packet(4);
    as<int32>(packet.as_mutable_slice().begin()) = telegram_api::updatesTooLong::ID;
    last_activity_timestamp_ = Time::now();
    callback_->on_update(std::move(packet), auth_data_.get_auth_key().id());
  }
  auto first_query_it = sent_queries_.find(first_message_id);
  if (first_query_it != sent_queries_.end()) {
    first_message_id = first_query_it->second.container_message_id_;
    LOG(INFO) << "Update first message to container's " << first_message_id;
  } else {
    LOG(INFO) << "Failed to find sent " << first_message_id << " from the new session";
  }
  for (auto it = sent_queries_.begin(); it != sent_queries_.end();) {
    Query &query = it->second;
    if (query.container_message_id_ < first_message_id) {
      // container vector leak otherwise
      cleanup_container(it->first, query);
      mark_as_known(it->first, query);
      resend_query(std::move(query.net_query_));
      it = sent_queries_.erase(it);
    } else {
      ++it;
    }
  }
}

void Session::on_session_failed(Status status) {
  if (status.is_error()) {
    LOG(WARNING) << "Session failed: " << status;
  } else {
    LOG(INFO) << "Session will be closed soon";
  }
  // this connection will be closed soon
  close_flag_ = true;
  callback_->on_failed();
}

void Session::on_container_sent(mtproto::MessageId container_message_id, vector<mtproto::MessageId> message_ids) {
  CHECK(container_message_id != mtproto::MessageId());

  td::remove_if(message_ids, [&](mtproto::MessageId message_id) {
    auto it = sent_queries_.find(message_id);
    if (it == sent_queries_.end()) {
      return true;  // remove
    }
    it->second.container_message_id_ = container_message_id;
    return false;
  });
  if (message_ids.empty()) {
    return;
  }
  auto size = message_ids.size();
  sent_containers_.emplace(container_message_id, ContainerInfo{size, std::move(message_ids)});
}

void Session::on_message_ack(mtproto::MessageId message_id) {
  on_message_ack_impl(message_id, 1);
}

void Session::on_message_ack_impl(mtproto::MessageId container_message_id, int32 type) {
  auto cit = sent_containers_.find(container_message_id);
  if (cit != sent_containers_.end()) {
    auto container_info = std::move(cit->second);
    sent_containers_.erase(cit);

    for (auto message_id : container_info.message_ids) {
      on_message_ack_impl_inner(message_id, type, true);
    }
    return;
  }

  on_message_ack_impl_inner(container_message_id, type, false);
}

void Session::on_message_ack_impl_inner(mtproto::MessageId message_id, int32 type, bool in_container) {
  auto it = sent_queries_.find(message_id);
  if (it == sent_queries_.end()) {
    return;
  }
  VLOG(net_query) << "Ack " << it->second.net_query_;
  it->second.is_acknowledged_ = true;
  {
    auto lock = it->second.net_query_->lock();
    it->second.net_query_->get_data_unsafe().ack_state_ |= type;
  }
  it->second.net_query_->quick_ack_promise_.set_value(Unit());
  if (!in_container) {
    cleanup_container(message_id, it->second);
  }
  mark_as_known(it->first, it->second);
}

void Session::dec_container(mtproto::MessageId container_message_id, const Query &query) {
  if (query.container_message_id_ == container_message_id) {
    // message was sent without any container
    return;
  }
  auto it = sent_containers_.find(query.container_message_id_);
  if (it == sent_containers_.end()) {
    return;
  }
  CHECK(it->second.ref_cnt > 0);
  it->second.ref_cnt--;
  if (it->second.ref_cnt == 0) {
    sent_containers_.erase(it);
  }
}

void Session::cleanup_container(mtproto::MessageId container_message_id, const Query &query) {
  if (query.container_message_id_ == container_message_id) {
    // message was sent without any container
    return;
  }

  // we can forget container now, since we have an answer for its part.
  // TODO: we can do it only for one element per container
  sent_containers_.erase(query.container_message_id_);
}

void Session::mark_as_known(mtproto::MessageId message_id, Query &query) {
  {
    auto lock = query.net_query_->lock();
    query.net_query_->get_data_unsafe().unknown_state_ = false;
  }
  if (!query.is_unknown_) {
    return;
  }
  VLOG(net_query) << "Mark as known " << query.net_query_;
  query.is_unknown_ = false;
  unknown_queries_.erase(message_id);
  if (unknown_queries_.empty()) {
    flush_pending_invoke_after_queries();
  }
}

void Session::mark_as_unknown(mtproto::MessageId message_id, Query &query) {
  {
    auto lock = query.net_query_->lock();
    query.net_query_->get_data_unsafe().unknown_state_ = true;
  }
  if (query.is_unknown_) {
    return;
  }
  VLOG(net_query) << "Mark as unknown " << query.net_query_;
  query.is_unknown_ = true;
  CHECK(message_id != mtproto::MessageId());
  unknown_queries_.insert(message_id);
}

Status Session::on_update(BufferSlice packet) {
  if (is_cdn_) {
    return Status::Error("Receive an update from a CDN connection");
  }

  if (!use_pfs_ && !auth_data_.use_pfs()) {
    last_success_timestamp_ = Time::now();
  }
  last_activity_timestamp_ = Time::now();
  callback_->on_update(std::move(packet), auth_data_.get_auth_key().id());
  return Status::OK();
}

Status Session::on_message_result_ok(mtproto::MessageId message_id, BufferSlice packet, size_t original_size) {
  last_success_timestamp_ = Time::now();

  TlParser parser(packet.as_slice());
  int32 response_tl_id = parser.fetch_int();

  auto it = sent_queries_.find(message_id);
  if (it == sent_queries_.end()) {
    LOG(DEBUG) << "Drop result to " << message_id << tag("original_size", original_size)
               << tag("response_tl", format::as_hex(response_tl_id));

    if (original_size > 16 * 1024) {
      dropped_size_ += original_size;
      if (dropped_size_ > (256 * 1024)) {
        auto dropped_size = dropped_size_;
        dropped_size_ = 0;
        return Status::Error(
            2, PSLICE() << "Too many dropped packets " << tag("total_size", format::as_size(dropped_size)));
      }
    }
    return Status::OK();
  }

  auth_data_.on_api_response();
  Query &query = it->second;
  VLOG(net_query) << "Return query result " << query.net_query_;

  if (!parser.get_error()) {
    // Steal authorization information.
    // It is a dirty hack, yep.
    if (response_tl_id == telegram_api::auth_authorization::ID ||
        response_tl_id == telegram_api::auth_loginTokenSuccess::ID ||
        response_tl_id == telegram_api::auth_sentCodeSuccess::ID) {
      if (query.net_query_->tl_constructor() != telegram_api::auth_importAuthorization::ID) {
        G()->net_query_dispatcher().set_main_dc_id(raw_dc_id_);
      }
      auth_data_.set_auth_flag(true);
      shared_auth_data_->set_auth_key(auth_data_.get_main_auth_key());
    }
  }

  cleanup_container(message_id, query);
  mark_as_known(message_id, query);
  query.net_query_->on_net_read(original_size);
  query.net_query_->set_ok(std::move(packet));
  query.net_query_->set_message_id(0);
  return_query(std::move(query.net_query_));

  sent_queries_.erase(it);
  return Status::OK();
}

void Session::on_message_result_error(mtproto::MessageId message_id, int error_code, string message) {
  if (!check_utf8(message)) {
    LOG(ERROR) << "Receive invalid error message \"" << message << '"';
    message = "INVALID_UTF8_ERROR_MESSAGE";
  }
  if (error_code <= -10000 || error_code >= 10000 || error_code == 0) {
    LOG(ERROR) << "Receive invalid error code " << error_code << " with message \"" << message << '"';
    error_code = 500;
  }

  // UNAUTHORIZED
  if (error_code == 401 && message != "SESSION_PASSWORD_NEEDED") {
    if (auth_data_.use_pfs() && message == CSlice("AUTH_KEY_PERM_EMPTY")) {
      LOG(INFO) << "Receive AUTH_KEY_PERM_EMPTY in session " << auth_data_.get_session_id() << " for auth key "
                << auth_data_.get_tmp_auth_key().id();
      // temporary key can be dropped any time
      auth_data_.drop_tmp_auth_key();
      on_tmp_auth_key_updated();
      error_code = 500;
    } else {
      if (auth_data_.use_pfs() && !is_main_) {
        // temporary key can be dropped any time
        auth_data_.drop_tmp_auth_key();
        on_tmp_auth_key_updated();
        error_code = 500;
      }

      bool can_drop_main_auth_key_without_logging_out = is_cdn_;
      if (!is_main_ && G()->net_query_dispatcher().get_main_dc_id().get_raw_id() != raw_dc_id_) {
        can_drop_main_auth_key_without_logging_out = true;
      }
      LOG(INFO) << "Receive 401, " << message << " in session " << auth_data_.get_session_id() << " for auth key "
                << auth_data_.get_auth_key().id() << ", PFS = " << auth_data_.use_pfs() << ", is_main = " << is_main_
                << ", can_drop_main_auth_key_without_logging_out = " << can_drop_main_auth_key_without_logging_out;
      if (can_drop_main_auth_key_without_logging_out) {
        auth_data_.drop_main_auth_key();
        on_auth_key_updated();
        error_code = 500;
      } else {
        auth_data_.set_auth_flag(false);
        G()->log_out(message);
        shared_auth_data_->set_auth_key(auth_data_.get_main_auth_key());
        on_session_failed(Status::OK());
      }
    }
  }
  if (error_code == 400 && (message == "CONNECTION_NOT_INITED" || message == "CONNECTION_LAYER_INVALID")) {
    LOG(WARNING) << "Receive " << message;
    auth_data_.on_connection_not_inited();
    error_code = 500;
  }

  if (message_id == mtproto::MessageId()) {
    LOG(ERROR) << "Receive an error without message_id";
    return;
  }

  if (error_code < 0) {
    LOG(WARNING) << "Receive MTProto error " << error_code << " : " << message << " in session "
                 << auth_data_.get_session_id() << " for auth key " << auth_data_.get_auth_key().id() << " with "
                 << sent_queries_.size() << " pending requests";
  }
  auto it = sent_queries_.find(message_id);
  if (it == sent_queries_.end()) {
    current_info_->connection_->force_ack();
    return;
  }

  Query &query = it->second;
  VLOG(net_query) << "Return query error " << query.net_query_;

  cleanup_container(message_id, query);
  mark_as_known(message_id, query);
  query.net_query_->set_error(Status::Error(error_code, message), current_info_->connection_->get_name().str());
  query.net_query_->set_message_id(0);
  return_query(std::move(query.net_query_));

  sent_queries_.erase(it);
}

void Session::on_message_failed_inner(mtproto::MessageId message_id, bool in_container) {
  LOG(INFO) << "Message inner failed for " << message_id;
  auto it = sent_queries_.find(message_id);
  if (it == sent_queries_.end()) {
    return;
  }

  Query &query = it->second;
  if (!in_container) {
    cleanup_container(message_id, query);
  }
  mark_as_known(message_id, query);

  query.net_query_->debug_send_failed();
  resend_query(std::move(query.net_query_));
  sent_queries_.erase(it);
}

void Session::on_message_failed(mtproto::MessageId message_id, Status status) {
  LOG(INFO) << "Failed to send " << message_id << ": " << status;
  status.ignore();

  auto cit = sent_containers_.find(message_id);
  if (cit != sent_containers_.end()) {
    auto container_info = std::move(cit->second);
    sent_containers_.erase(cit);

    for (auto contained_message_id : container_info.message_ids) {
      on_message_failed_inner(contained_message_id, true);
    }
    return;
  }

  on_message_failed_inner(message_id, false);
}

void Session::on_message_info(mtproto::MessageId message_id, int32 state, mtproto::MessageId answer_message_id,
                              int32 answer_size, int32 source) {
  auto it = sent_queries_.find(message_id);
  if (it != sent_queries_.end()) {
    if (it->second.net_query_->update_is_ready()) {
      dec_container(it->first, it->second);
      mark_as_known(it->first, it->second);

      auto query = std::move(it->second.net_query_);
      query->set_message_id(0);
      sent_queries_.erase(it);
      return_query(std::move(query));
      return;
    }
  }
  LOG(INFO) << "Receive info about " << message_id << " with state = " << state << " and answer " << answer_message_id
            << " from " << source;
  if (message_id != mtproto::MessageId()) {
    if (it == sent_queries_.end()) {
      return;
    }
    switch (state & 7) {
      case 1:
      case 2:
      case 3:
        return on_message_failed(message_id,
                                 Status::Error("Message wasn't received by the server and must be re-sent"));
      case 0:
        if (answer_message_id == mtproto::MessageId()) {
          LOG(ERROR) << "Unexpected message_info.state == 0 for " << message_id << ": " << tag("state", state)
                     << tag("answer", answer_message_id);
          return on_message_failed(message_id, Status::Error("Unexpected message_info.state == 0"));
        }
      // fallthrough
      case 4:
        CHECK(0 <= source && source <= 3);
        on_message_ack_impl(message_id, (answer_message_id != mtproto::MessageId() ? 2 : 0) |
                                            (((state | source) & ((1 << 28) - 1)) << 2));
        break;
      default:
        LOG(ERROR) << "Invalid message info " << tag("state", state);
    }
  }

  // ok, we are waiting for result of message_id. let's ask to resend it
  if (answer_message_id != mtproto::MessageId()) {
    if (it != sent_queries_.end()) {
      VLOG_IF(net_query, message_id != mtproto::MessageId())
          << "Resend answer " << answer_message_id << ": " << tag("answer_size", answer_size) << it->second.net_query_;
      it->second.net_query_->debug(PSTRING() << get_name() << ": resend answer");
    }
    current_info_->connection_->resend_answer(answer_message_id);
  }
}

Status Session::on_destroy_auth_key() {
  auth_data_.drop_main_auth_key();
  on_auth_key_updated();
  return Status::Error("Close because of on_destroy_auth_key");
}

bool Session::has_queries() const {
  return !pending_invoke_after_queries_.empty() || !pending_queries_.empty() || !sent_queries_.empty();
}

void Session::resend_query(NetQueryPtr query) {
  VLOG(net_query) << "Resend " << query;
  query->set_message_id(0);

  if (UniqueId::extract_type(query->id()) == UniqueId::BindKey) {
    query->set_error_resend();
    return_query(std::move(query));
  } else {
    add_query(std::move(query));
  }
}

void Session::add_query(NetQueryPtr &&net_query) {
  CHECK(UniqueId::extract_type(net_query->id()) != UniqueId::BindKey);
  net_query->debug(PSTRING() << get_name() << ": pending");
  pending_queries_.push(std::move(net_query));
}

void Session::connection_send_query(ConnectionInfo *info, NetQueryPtr &&net_query, mtproto::MessageId message_id) {
  CHECK(info->state_ == ConnectionInfo::State::Ready);
  current_info_ = info;

  if (net_query->update_is_ready()) {
    return return_query(std::move(net_query));
  }

  Span<NetQueryRef> invoke_after = net_query->invoke_after();
  vector<mtproto::MessageId> invoke_after_message_ids;
  for (auto &ref : invoke_after) {
    auto invoke_after_message_id = mtproto::MessageId(ref->message_id());
    if (ref->session_id() != auth_data_.get_session_id() || invoke_after_message_id == mtproto::MessageId()) {
      net_query->set_error_resend_invoke_after();
      return return_query(std::move(net_query));
    }
    invoke_after_message_ids.push_back(invoke_after_message_id);
  }
  if (!invoke_after.empty()) {
    if (!unknown_queries_.empty()) {
      net_query->debug(PSTRING() << get_name() << ": wait unknown query to invoke after it");
      pending_invoke_after_queries_.push_back(std::move(net_query));
      return;
    }
  }

  auto now = Time::now();
  const bool immediately_fail_query = false;
  if (!immediately_fail_query) {
    net_query->debug(PSTRING() << get_name() << ": send to " << info->connection_->get_debug_str());
    message_id = info->connection_->send_query(
        net_query->query().clone(), net_query->gzip_flag() == NetQuery::GzipFlag::On, message_id,
        invoke_after_message_ids, static_cast<bool>(net_query->quick_ack_promise_));

    net_query->on_net_write(net_query->query().size());
  } else {
    if (message_id == mtproto::MessageId()) {
      message_id = auth_data_.next_message_id(now);
    }
  }
  net_query->set_message_id(message_id.get());
  VLOG(net_query) << "Send query to connection " << net_query << tag("invoke_after", invoke_after_message_ids);
  {
    auto lock = net_query->lock();
    net_query->get_data_unsafe().unknown_state_ = false;
    net_query->get_data_unsafe().ack_state_ = 0;
  }
  if (!net_query->cancel_slot_.empty()) {
    LOG(DEBUG) << "Set event for net_query cancellation for " << message_id;
    net_query->cancel_slot_.set_event(EventCreator::raw(actor_id(), message_id.get()));
  }
  auto status =
      sent_queries_.emplace(message_id, Query{message_id, std::move(net_query), main_connection_.connection_id_, now});
  LOG_CHECK(status.second) << message_id;
  sent_queries_list_.put(status.first->second.get_list_node());
  if (immediately_fail_query) {
    on_message_result_error(message_id, 401, "TEST_ERROR");
  }
}

void Session::connection_open(ConnectionInfo *info, double now, bool ask_info) {
  CHECK(info->state_ == ConnectionInfo::State::Empty);
  if (!network_flag_) {
    return;
  }
  if (!auth_data_.has_auth_key(now)) {
    return;
  }
  info->ask_info_ = ask_info;

  info->state_ = ConnectionInfo::State::Connecting;
  info->cancellation_token_source_ = CancellationTokenSource{};
  // NB: rely on constant location of info
  auto promise = PromiseCreator::cancellable_lambda(
      info->cancellation_token_source_.get_cancellation_token(),
      [actor_id = actor_id(this), info](Result<unique_ptr<mtproto::RawConnection>> res) {
        send_closure(actor_id, &Session::connection_open_finish, info, std::move(res));
      });

  if (cached_connection_) {
    VLOG(dc) << "Reuse cached connection";
    promise.set_value(std::move(cached_connection_));
  } else {
    VLOG(dc) << "Request new connection";
    unique_ptr<mtproto::AuthData> auth_data;
    if (auth_data_.use_pfs() && auth_data_.has_auth_key(now)) {
      // auth_data = make_unique<mtproto::AuthData>(auth_data_);
    }
    callback_->request_raw_connection(std::move(auth_data), std::move(promise));
  }

  info->wakeup_at_ = now + 1000;
}

void Session::connection_add(unique_ptr<mtproto::RawConnection> raw_connection) {
  VLOG(dc) << "Cache connection " << raw_connection.get();
  cached_connection_ = std::move(raw_connection);
  cached_connection_timestamp_ = Time::now();
}

void Session::connection_check_mode(ConnectionInfo *info) {
  if (close_flag_ || info->state_ != ConnectionInfo::State::Ready) {
    return;
  }
  if (info->mode_ != mode_) {
    LOG(WARNING) << "Close connection because of outdated mode_";
    connection_close(info);
  }
}

void Session::connection_open_finish(ConnectionInfo *info,
                                     Result<unique_ptr<mtproto::RawConnection>> r_raw_connection) {
  if (close_flag_ || info->state_ != ConnectionInfo::State::Connecting) {
    VLOG(dc) << "Ignore raw connection while closing";
    return;
  }
  current_info_ = info;
  if (r_raw_connection.is_error()) {
    LOG(WARNING) << "Failed to open socket: " << r_raw_connection.error();
    info->state_ = ConnectionInfo::State::Empty;
    yield();
    return;
  }

  auto raw_connection = r_raw_connection.move_as_ok();
  VLOG(dc) << "Receive raw connection " << raw_connection.get();
  if (raw_connection->extra().extra != network_generation_) {
    LOG(WARNING) << "Receive RawConnection with old network_generation";
    info->state_ = ConnectionInfo::State::Empty;
    yield();
    return;
  }

  Mode expected_mode =
      raw_connection->get_transport_type().type == mtproto::TransportType::Http ? Mode::Http : Mode::Tcp;
  if (mode_ != expected_mode) {
    VLOG(dc) << "Change mode " << mode_ << "--->" << expected_mode;
    mode_ = expected_mode;
    if (info->connection_id_ == 1 && mode_ != Mode::Http) {
      LOG(WARNING) << "Receive TCP connection for long poll connection";
      connection_add(std::move(raw_connection));
      info->state_ = ConnectionInfo::State::Empty;
      yield();
      return;
    }
  }

  mtproto::SessionConnection::Mode mode;
  Slice mode_name;
  if (mode_ == Mode::Tcp) {
    mode = mtproto::SessionConnection::Mode::Tcp;
    mode_name = Slice("TCP");
  } else {
    if (info->connection_id_ == 0) {
      mode = mtproto::SessionConnection::Mode::Http;
      mode_name = Slice("HTTP");
    } else {
      mode = mtproto::SessionConnection::Mode::HttpLongPoll;
      mode_name = Slice("LongPoll");
    }
  }
  auto name = PSTRING() << get_name() << "::Connect::" << mode_name << "::" << raw_connection->extra().debug_str;
  LOG(INFO) << "Finished to open connection " << name;
  info->connection_ = make_unique<mtproto::SessionConnection>(mode, std::move(raw_connection), &auth_data_);
  if (can_destroy_auth_key()) {
    info->connection_->destroy_key();
  }
  info->connection_->set_online(connection_online_flag_, is_primary_);
  info->connection_->set_name(name);
  Scheduler::subscribe(info->connection_->get_poll_info().extract_pollable_fd(this));
  info->mode_ = mode_;
  info->state_ = ConnectionInfo::State::Ready;
  info->created_at_ = Time::now();
  info->wakeup_at_ = info->created_at_ + 10;
  if (unknown_queries_.size() > MAX_INFLIGHT_QUERIES) {
    LOG(ERROR) << "With current limits `Too many queries with unknown state` error must be impossible";
    on_session_failed(Status::Error("Too many queries with unknown state"));
    return;
  }
  if (info->ask_info_) {
    for (auto &message_id : unknown_queries_) {
      info->connection_->get_state_info(message_id);
    }
    for (auto &message_id : to_cancel_message_ids_) {
      info->connection_->cancel_answer(message_id);
    }
    to_cancel_message_ids_.clear();
  }
  yield();
}

void Session::connection_flush(ConnectionInfo *info) {
  CHECK(info->state_ == ConnectionInfo::State::Ready);
  current_info_ = info;
  info->wakeup_at_ = info->connection_->flush(static_cast<mtproto::SessionConnection::Callback *>(this));
}

void Session::connection_close(ConnectionInfo *info) {
  current_info_ = info;
  if (info->state_ != ConnectionInfo::State::Ready) {
    return;
  }
  info->connection_->force_close(static_cast<mtproto::SessionConnection::Callback *>(this));
  CHECK(info->state_ == ConnectionInfo::State::Empty);
}

bool Session::need_send_check_main_key() const {
  return need_check_main_key_ && auth_data_.get_main_auth_key().id() != being_checked_main_auth_key_id_;
}

bool Session::connection_send_check_main_key(ConnectionInfo *info) {
  if (!need_check_main_key_) {
    return false;
  }
  uint64 key_id = auth_data_.get_main_auth_key().id();
  if (key_id == being_checked_main_auth_key_id_) {
    return false;
  }
  CHECK(info->state_ != ConnectionInfo::State::Empty);
  LOG(INFO) << "Check main key";
  being_checked_main_auth_key_id_ = key_id;
  last_check_query_id_ = UniqueId::next(UniqueId::BindKey);
  NetQueryPtr query = G()->net_query_creator().create(last_check_query_id_, nullptr, telegram_api::help_getNearestDc(),
                                                      {}, DcId::main(), NetQuery::Type::Common, NetQuery::AuthFlag::On);
  query->dispatch_ttl_ = 0;
  query->set_callback(actor_shared(this));
  connection_send_query(info, std::move(query));

  return true;
}

bool Session::need_send_bind_key() const {
  return auth_data_.use_pfs() && !auth_data_.get_bind_flag() &&
         auth_data_.get_tmp_auth_key().id() != being_binded_tmp_auth_key_id_;
}

bool Session::need_send_query() const {
  return !close_flag_ && !need_check_main_key_ && (!auth_data_.use_pfs() || auth_data_.get_bind_flag()) &&
         !pending_queries_.empty() && !can_destroy_auth_key();
}

bool Session::connection_send_bind_key(ConnectionInfo *info) {
  CHECK(info->state_ != ConnectionInfo::State::Empty);
  uint64 key_id = auth_data_.get_tmp_auth_key().id();
  if (key_id == being_binded_tmp_auth_key_id_) {
    return false;
  }
  being_binded_tmp_auth_key_id_ = key_id;
  last_bind_query_id_ = UniqueId::next(UniqueId::BindKey);

  int64 perm_auth_key_id = auth_data_.get_main_auth_key().id();
  int64 nonce = Random::secure_int64();
  auto expires_at = static_cast<int32>(auth_data_.get_server_time(auth_data_.get_tmp_auth_key().expires_at()));
  mtproto::MessageId message_id;
  BufferSlice encrypted;
  std::tie(message_id, encrypted) = info->connection_->encrypted_bind(perm_auth_key_id, nonce, expires_at);

  LOG(INFO) << "Bind key: " << tag("tmp", key_id) << tag("perm", static_cast<uint64>(perm_auth_key_id));
  NetQueryPtr query = G()->net_query_creator().create(
      last_bind_query_id_, nullptr,
      telegram_api::auth_bindTempAuthKey(perm_auth_key_id, nonce, expires_at, std::move(encrypted)), {}, DcId::main(),
      NetQuery::Type::Common, NetQuery::AuthFlag::On);
  query->dispatch_ttl_ = 0;
  query->set_callback(actor_shared(this));
  connection_send_query(info, std::move(query), message_id);

  return true;
}

void Session::on_handshake_ready(Result<unique_ptr<mtproto::AuthKeyHandshake>> r_handshake) {
  auto handshake_id = narrow_cast<HandshakeId>(get_link_token() - 1);
  bool is_main = handshake_id == MainAuthKeyHandshake;
  auto &info = handshake_info_[handshake_id];
  info.flag_ = false;
  info.actor_.reset();

  if (r_handshake.is_error()) {
    LOG(ERROR) << "Handshake failed: " << r_handshake.move_as_error();
  } else {
    auto handshake = r_handshake.move_as_ok();
    if (!handshake->is_ready_for_finish()) {
      LOG(INFO) << "Handshake is not yet ready";
      info.handshake_ = std::move(handshake);
    } else {
      if (is_main) {
        auth_data_.set_main_auth_key(handshake->release_auth_key());
        on_auth_key_updated();
      } else {
        auth_data_.set_tmp_auth_key(handshake->release_auth_key());
        if (is_main_) {
          registered_temp_auth_key_ = TempAuthKeyWatchdog::register_auth_key_id(auth_data_.get_tmp_auth_key().id());
        }
        on_tmp_auth_key_updated();
      }
      LOG(WARNING) << "Update auth key in session_id " << auth_data_.get_session_id() << " to "
                   << auth_data_.get_auth_key().id();
      connection_close(&main_connection_);
      connection_close(&long_poll_connection_);

      // Salt of temporary key is different salt. Do not rewrite it
      if (auth_data_.use_pfs() ^ is_main) {
        auth_data_.set_server_salt(handshake->get_server_salt(), Time::now());
        on_server_salt_updated();
      }
      if (auth_data_.update_server_time_difference(handshake->get_server_time_diff())) {
        on_server_time_difference_updated(true);
      }
    }
  }

  loop();
}

void Session::create_gen_auth_key_actor(HandshakeId handshake_id) {
  auto &info = handshake_info_[handshake_id];
  if (info.flag_) {
    return;
  }
  LOG(INFO) << "Create GenAuthKeyActor " << handshake_id;
  info.flag_ = true;
  bool is_main = handshake_id == MainAuthKeyHandshake;
  if (!info.handshake_) {
    auto key_validity_time = is_main && !is_cdn_ ? 0 : Random::fast(23 * 60 * 60, 24 * 60 * 60);
    info.handshake_ = make_unique<mtproto::AuthKeyHandshake>(dc_id_, key_validity_time);
  }
  class AuthKeyHandshakeContext final : public mtproto::AuthKeyHandshakeContext {
   public:
    AuthKeyHandshakeContext(mtproto::DhCallback *dh_callback,
                            std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key)
        : dh_callback_(dh_callback), public_rsa_key_(std::move(public_rsa_key)) {
    }
    mtproto::DhCallback *get_dh_callback() final {
      return dh_callback_;
    }
    mtproto::PublicRsaKeyInterface *get_public_rsa_key_interface() final {
      return public_rsa_key_.get();
    }

   private:
    mtproto::DhCallback *dh_callback_;
    std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key_;
  };

  info.actor_ = create_actor<detail::GenAuthKeyActor>(
      PSLICE() << get_name() << "::GenAuthKey", get_name(), std::move(info.handshake_),
      td::make_unique<AuthKeyHandshakeContext>(DhCache::instance(), shared_auth_data_->public_rsa_key()),
      PromiseCreator::lambda(
          [actor_id = actor_id(this), guard = callback_](Result<unique_ptr<mtproto::RawConnection>> r_connection) {
            if (r_connection.is_error()) {
              if (r_connection.error().code() != 1) {
                LOG(WARNING) << "Failed to open connection: " << r_connection.error();
              }
              return;
            }
            send_closure(actor_id, &Session::connection_add, r_connection.move_as_ok());
          }),
      PromiseCreator::lambda([self = actor_shared(this, handshake_id + 1),
                              handshake_perf = PerfWarningTimer("handshake", 1000.1),
                              guard = callback_](Result<unique_ptr<mtproto::AuthKeyHandshake>> handshake) mutable {
        // later is just to avoid lost hangup
        send_closure_later(std::move(self), &Session::on_handshake_ready, std::move(handshake));
      }),
      callback_);
}

void Session::auth_loop(double now) {
  if (can_destroy_auth_key()) {
    return;
  }
  if (auth_data_.need_main_auth_key()) {
    create_gen_auth_key_actor(MainAuthKeyHandshake);
  }
  if (auth_data_.need_tmp_auth_key(now, persist_tmp_auth_key_ ? 2 * 60 : 60 * 60)) {
    create_gen_auth_key_actor(TmpAuthKeyHandshake);
  }
}

void Session::timeout_expired() {
  send_closure_later(actor_id(this), &Session::loop);
}

void Session::loop() {
  if (!was_on_network_) {
    return;
  }
  auto now = Time::now();

  if (cached_connection_timestamp_ < now - 10) {
    cached_connection_.reset();
  }
  if (!is_main_ && !has_queries() && !need_destroy_auth_key_ && last_activity_timestamp_ < now - ACTIVITY_TIMEOUT) {
    on_session_failed(Status::OK());
  }

  auth_loop(now);
  connection_online_update(now, false);

  double wakeup_at = 0;
  main_connection_.wakeup_at_ = 0;
  long_poll_connection_.wakeup_at_ = 0;

  // NB: order is crucial. First long_poll_connection, then main_connection
  // Otherwise, queries could be sent with big delay

  connection_check_mode(&main_connection_);
  connection_check_mode(&long_poll_connection_);
  if (mode_ == Mode::Http) {
    if (long_poll_connection_.state_ == ConnectionInfo::State::Ready) {
      connection_flush(&long_poll_connection_);
    }
    if (!close_flag_ && long_poll_connection_.state_ == ConnectionInfo::State::Empty) {
      connection_open(&long_poll_connection_, now);
    }
    relax_timeout_at(&wakeup_at, long_poll_connection_.wakeup_at_);
  }

  if (main_connection_.state_ == ConnectionInfo::State::Ready) {
    // do not send queries before we have key and e.t.c
    // do not send queries before tmp_key is bound
    bool need_flush = true;
    while (main_connection_.state_ == ConnectionInfo::State::Ready) {
      if (auth_data_.is_ready(now)) {
        if (need_send_query()) {
          while (!pending_queries_.empty() && sent_queries_.size() < MAX_INFLIGHT_QUERIES) {
            auto query = pending_queries_.pop();
            connection_send_query(&main_connection_, std::move(query));
            need_flush = true;
          }
        }
        if (need_send_bind_key()) {
          // send auth.bindTempAuthKey
          connection_send_bind_key(&main_connection_);
          need_flush = true;
        }
        if (need_send_check_main_key()) {
          connection_send_check_main_key(&main_connection_);
          need_flush = true;
        }
      }
      if (need_flush) {
        connection_flush(&main_connection_);
        need_flush = false;
      } else {
        break;
      }
    }
  }
  if (!close_flag_ && main_connection_.state_ == ConnectionInfo::State::Empty) {
    connection_open(&main_connection_, now, true /*send ask_info*/);
  }

  connection_online_update(now, false);  // has_queries() could have been changed

  relax_timeout_at(&wakeup_at, main_connection_.wakeup_at_);

  if (wakeup_at != 0) {
    set_timeout_at(wakeup_at);
  }
}

}  // namespace td
