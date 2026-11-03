//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

///\file

#include "td/telegram/td_api.h"
#include "td/telegram/td_api.hpp"
#include "td/telegram/TdCallback.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"

#include <memory>

namespace td {

class NetQueryStats;
class Td;

/**
 * This is a low-level Actor interface for interaction with TDLib. The interface is a lot more flexible than
 * the ClientManager interface, however, for most usages the ClientManager interface should be sufficient.
 */
class ClientActor final : public Actor {
 public:
  /// Options for ClientActor creation.
  struct Options {
    /// NetQueryStats object for this client.
    std::shared_ptr<NetQueryStats> net_query_stats;

    /// Default constructor.
    Options() {
    }
  };

  /**
   * Creates a ClientActor using the specified callback.
   * \param[in] callback Callback for outgoing notifications from TDLib.
   * \param[in] options Options to create the TDLib.
   */
  explicit ClientActor(unique_ptr<TdCallback> callback, Options options = {});

  /**
   * Sends one request to TDLib. The answer will be received via callback.
   * \param[in] id Request identifier, must be positive.
   * \param[in] request The request.
   */
  void request(uint64 id, td_api::object_ptr<td_api::Function> request);

  /**
   * Synchronously executes a TDLib request. Only a few requests can be executed synchronously.
   * May be called from any thread.
   * \param[in] request Request to the TDLib instance.
   * \return The request response.
   */
  static td_api::object_ptr<td_api::Object> execute(td_api::object_ptr<td_api::Function> request);

  /**
   * Destroys the ClientActor and the TDLib instance.
   */
  ~ClientActor() final;

  /**
   * Move constructor.
   */
  ClientActor(ClientActor &&other) noexcept;

  /**
   * Move assignment operator.
   */
  ClientActor &operator=(ClientActor &&other) noexcept;

  ClientActor(const ClientActor &) = delete;

  ClientActor &operator=(const ClientActor &) = delete;

 private:
  void start_up() final;

  ActorOwn<Td> td_;
  unique_ptr<TdCallback> callback_;
  Options options_;
};

/**
 * Creates NetQueryStats object, which can be shared between different clients.
 */
std::shared_ptr<NetQueryStats> create_net_query_stats();

/**
 * Dumps information about all pending network queries to the internal TDLib log.
 * This is useful for library debugging.
 */
void dump_pending_network_queries(NetQueryStats &stats);

/**
 * Returns the current number of pending network queries. Useful for library debugging.
 * \return Number of currently pending network queries.
 */
uint64 get_pending_network_query_count(NetQueryStats &stats);

}  // namespace td
