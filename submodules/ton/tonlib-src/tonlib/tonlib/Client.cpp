/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "Client.h"

#include "tonlib/TonlibClient.h"
#include "tonlib/TonlibCallback.h"

#include "td/actor/actor.h"
#include "td/utils/MpscPollableQueue.h"

int VERBOSITY_NAME(tonlib_requests) = VERBOSITY_NAME(DEBUG);

namespace tonlib {
class Client::Impl final {
 public:
  using OutputQueue = td::MpscPollableQueue<Client::Response>;
  Impl() {
    output_queue_ = std::make_shared<OutputQueue>();
    output_queue_->init();

    class Callback : public TonlibCallback {
     public:
      explicit Callback(std::shared_ptr<OutputQueue> output_queue) : output_queue_(std::move(output_queue)) {
      }
      void on_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) override {
        output_queue_->writer_put({id, std::move(result)});
      }
      void on_error(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::error> error) override {
        output_queue_->writer_put({id, std::move(error)});
      }
      Callback(const Callback&) = delete;
      Callback& operator=(const Callback&) = delete;
      Callback(Callback&&) = delete;
      Callback& operator=(Callback&&) = delete;
      ~Callback() override {
        output_queue_->writer_put({0, nullptr});
      }

     private:
      std::shared_ptr<OutputQueue> output_queue_;
    };

    scheduler_.run_in_context([&] {
      tonlib_ = td::actor::create_actor<TonlibClient>(td::actor::ActorOptions().with_name("Tonlib").with_poll(),
                                                      td::make_unique<Callback>(output_queue_));
    });

    scheduler_thread_ = td::thread([&] { scheduler_.run(); });
  }

  void send(Client::Request request) {
    if (request.id == 0 || request.function == nullptr) {
      LOG(ERROR) << "Drop wrong request " << request.id;
      return;
    }

    scheduler_.run_in_context_external(
        [&] { send_closure(tonlib_, &TonlibClient::request, request.id, std::move(request.function)); });
  }

  Client::Response receive(double timeout) {
    VLOG(tonlib_requests) << "Begin to wait for updates with timeout " << timeout;
    auto is_locked = receive_lock_.exchange(true);
    CHECK(!is_locked);
    auto response = receive_unlocked(timeout);
    is_locked = receive_lock_.exchange(false);
    CHECK(is_locked);
    VLOG(tonlib_requests) << "End to wait for updates, returning object " << response.id << ' '
                          << response.object.get();
    return response;
  }

  Impl(const Impl&) = delete;
  Impl& operator=(const Impl&) = delete;
  Impl(Impl&&) = delete;
  Impl& operator=(Impl&&) = delete;
  ~Impl() {
    LOG(ERROR) << "~Impl";
    scheduler_.run_in_context_external([&] { tonlib_.reset(); });
    LOG(ERROR) << "Wait till closed";
    while (!is_closed_) {
      receive(10);
    }
    LOG(ERROR) << "Stop";
    scheduler_.run_in_context_external([] { td::actor::SchedulerContext::get()->stop(); });
    LOG(ERROR) << "join";
    scheduler_thread_.join();
  }

 private:
  std::shared_ptr<OutputQueue> output_queue_;
  int output_queue_ready_cnt_{0};
  std::atomic<bool> receive_lock_{false};
  bool is_closed_{false};

  td::actor::Scheduler scheduler_{{1}};
  td::thread scheduler_thread_;
  td::actor::ActorOwn<TonlibClient> tonlib_;

  Client::Response receive_unlocked(double timeout) {
    if (output_queue_ready_cnt_ == 0) {
      output_queue_ready_cnt_ = output_queue_->reader_wait_nonblock();
    }
    if (output_queue_ready_cnt_ > 0) {
      output_queue_ready_cnt_--;
      auto res = output_queue_->reader_get_unsafe();
      if (res.object == nullptr && res.id == 0) {
        is_closed_ = true;
      }
      return res;
    }
    if (timeout != 0) {
      output_queue_->reader_get_event_fd().wait(static_cast<int>(timeout * 1000));
      return receive_unlocked(0);
    }
    return {0, nullptr};
  }
};

Client::Client() : impl_(std::make_unique<Impl>()) {
  // At least it should be enough for everybody who uses tonlib
  // FIXME
  //td::init_openssl_threads();
}

void Client::send(Request&& request) {
  impl_->send(std::move(request));
}

Client::Response Client::receive(double timeout) {
  return impl_->receive(timeout);
}

Client::Response Client::execute(Request&& request) {
  Response response;
  response.id = request.id;
  response.object = TonlibClient::static_request(std::move(request.function));
  return response;
}

Client::~Client() = default;
Client::Client(Client&& other) = default;
Client& Client::operator=(Client&& other) = default;
}  // namespace tonlib
