//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileLoaderActor.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/ResourceManager.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/BufferedFd.h"
#include "td/utils/crypto.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Status.h"

namespace td {

class FileHashUploader final : public FileLoaderActor {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;

    virtual void on_ok(FullRemoteFileLocation location) = 0;
    virtual void on_error(Status status) = 0;
  };

  FileHashUploader(const FullLocalFileLocation &local, int64 size, unique_ptr<Callback> callback)
      : local_(local), size_(size), size_left_(size), callback_(std::move(callback)) {
  }

 private:
  ResourceState resource_state_;
  BufferedFd<FileFd> fd_;

  FullLocalFileLocation local_;
  int64 size_;
  int64 size_left_;
  unique_ptr<Callback> callback_;

  ActorShared<ResourceManager> resource_manager_;

  enum class State : int32 { CalcSha, NetRequest, WaitNetResult } state_ = State::CalcSha;
  bool stop_flag_ = false;
  Sha256State sha256_state_;

  void set_resource_manager(ActorShared<ResourceManager> resource_manager) final {
    resource_manager_ = std::move(resource_manager);
    send_closure(resource_manager_, &ResourceManager::update_resources, resource_state_);
  }

  void update_priority(int8 priority) final {
    send_closure(resource_manager_, &ResourceManager::update_priority, priority);
  }

  void update_resources(const ResourceState &other) final {
    if (stop_flag_) {
      return;
    }
    resource_state_.update_slave(other);
    loop();
  }

  void start_up() final;
  Status init();

  void loop() final;

  Status loop_impl();

  Status loop_sha();

  void on_result(NetQueryPtr net_query) final;

  Status on_result_impl(NetQueryPtr net_query);
};

}  // namespace td
