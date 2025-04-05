//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/ResourceState.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

namespace td {

class ResourceManager;

class FileLoaderActor : public NetQueryCallback {
 public:
  virtual void set_resource_manager(ActorShared<ResourceManager> resource_manager) = 0;
  virtual void update_priority(int8 priority) = 0;
  virtual void update_resources(const ResourceState &other) = 0;
};

}  // namespace td
