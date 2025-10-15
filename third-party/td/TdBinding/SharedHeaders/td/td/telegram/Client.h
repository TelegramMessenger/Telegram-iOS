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

#include <cstdint>
#include <memory>

namespace td {

/**
 * The native C++ interface for interaction with TDLib.
 *
 * A TDLib client instance can be created through the method ClientManager::create_client_id.
 * Requests can be sent using the method ClientManager::send from any thread.
 * New updates and responses to requests can be received using the method ClientManager::receive from any thread after
 * the first request has been sent to the client instance. ClientManager::receive must not be called simultaneously from
 * two different threads. Also, note that all updates and responses to requests should be applied in the same order as
 * they were received, to ensure consistency.
 * Some TDLib requests can be executed synchronously from any thread using the method ClientManager::execute.
 *
 * General pattern of usage:
 * \code
 * td::ClientManager manager;
 * auto client_id = manager.create_client_id();
 * // somehow share the manager and the client_id with other threads,
 * // which will be able to send requests via manager.send(client_id, ...)
 *
 * // send some dummy requests to the new instance to activate it
 * manager.send(client_id, ...);
 *
 * const double WAIT_TIMEOUT = 10.0;  // seconds
 * while (true) {
 *   auto response = manager.receive(WAIT_TIMEOUT);
 *   if (response.object == nullptr) {
 *     continue;
 *   }
 *
 *   if (response.request_id == 0) {
 *     // process response.object as an incoming update of the type td_api::Update for the client response.client_id
 *   } else {
 *     // process response.object as an answer to a request response.request_id for the client response.client_id
 *   }
 * }
 * \endcode
 */
class ClientManager final {
 public:
  /**
   * Creates a new TDLib client manager.
   */
  ClientManager();

  /**
   * Opaque TDLib client instance identifier.
   */
  using ClientId = std::int32_t;

  /**
   * Request identifier.
   * Responses to TDLib requests will have the same request id as the corresponding request.
   * Updates from TDLib will have the request_id == 0, incoming requests are thus not allowed to have request_id == 0.
   */
  using RequestId = std::uint64_t;

  /**
   * Returns an opaque identifier of a new TDLib instance.
   * The TDLib instance will not send updates until the first request is sent to it.
   * \return Opaque identifier of a new TDLib instance.
   */
  ClientId create_client_id();

  /**
   * Sends request to TDLib. May be called from any thread.
   * \param[in] client_id TDLib client instance identifier.
   * \param[in] request_id Request identifier. Must be non-zero.
   * \param[in] request Request to TDLib.
   */
  void send(ClientId client_id, RequestId request_id, td_api::object_ptr<td_api::Function> &&request);

  /**
   * A response to a request, or an incoming update from TDLib.
   */
  struct Response {
    /**
     * TDLib client instance identifier, for which the response was received.
     */
    ClientId client_id;

    /**
     * Request identifier to which the response corresponds, or 0 for incoming updates from TDLib.
     */
    RequestId request_id;

    /**
     * TDLib API object representing a response to a TDLib request or an incoming update.
     */
    td_api::object_ptr<td_api::Object> object;
  };

  /**
   * Receives incoming updates and responses to requests from TDLib. May be called from any thread, but must not be
   * called simultaneously from two different threads.
   * \param[in] timeout The maximum number of seconds allowed for this function to wait for new data.
   * \return An incoming update or response to a request. The object returned in the response may be a nullptr
   *         if the timeout expires.
   */
  Response receive(double timeout);

  /**
   * Synchronously executes a TDLib request.
   * A request can be executed synchronously, only if it is documented with "Can be called synchronously".
   * \param[in] request Request to the TDLib.
   * \return The request response.
   */
  static td_api::object_ptr<td_api::Object> execute(td_api::object_ptr<td_api::Function> &&request);

  /**
   * A type of callback function that will be called when a message is added to the internal TDLib log.
   *
   * \param verbosity_level Log verbosity level with which the message was added from -1 up to 1024.
   *                        If 0, then TDLib will crash as soon as the callback returns.
   *                        None of the TDLib methods can be called from the callback.
   * \param message Null-terminated UTF-8-encoded string with the message added to the log.
   */
  using LogMessageCallbackPtr = void (*)(int verbosity_level, const char *message);

  /**
   * Sets the callback that will be called when a message is added to the internal TDLib log.
   * None of the TDLib methods can be called from the callback.
   * By default the callback is not set.
   *
   * \param[in] max_verbosity_level The maximum verbosity level of messages for which the callback will be called.
   * \param[in] callback Callback that will be called when a message is added to the internal TDLib log.
   *                     Pass nullptr to remove the callback.
   */
  static void set_log_message_callback(int max_verbosity_level, LogMessageCallbackPtr callback);

  /**
   * Destroys the client manager and all TDLib client instances managed by it.
   */
  ~ClientManager();

  /**
   * Move constructor.
   */
  ClientManager(ClientManager &&other) noexcept;

  /**
   * Move assignment operator.
   */
  ClientManager &operator=(ClientManager &&other) noexcept;

  /**
   * Returns a pointer to a singleton ClientManager instance.
   * \return A unique singleton ClientManager instance.
   */
  static ClientManager *get_manager_singleton();

 private:
  friend class Client;
  class Impl;
  std::unique_ptr<Impl> impl_;
};

/**
 * Old native C++ interface for interaction with TDLib to be removed in TDLib 2.0.0.
 *
 * The TDLib instance is created for the lifetime of the Client object.
 * Requests to TDLib can be sent using the Client::send method from any thread.
 * New updates and responses to requests can be received using the Client::receive method from any thread,
 * this function must not be called simultaneously from two different threads. Also, note that all updates and
 * responses to requests should be applied in the same order as they were received, to ensure consistency.
 * Given this information, it's advisable to call this function from a dedicated thread.
 * Some service TDLib requests can be executed synchronously from any thread using the Client::execute method.
 *
 * General pattern of usage:
 * \code
 * std::shared_ptr<td::Client> client = std::make_shared<td::Client>();
 * // somehow share the client with other threads, which will be able to send requests via client->send
 *
 * const double WAIT_TIMEOUT = 10.0;  // seconds
 * bool is_closed = false;            // should be set to true, when updateAuthorizationState with
 *                                    // authorizationStateClosed is received
 * while (!is_closed) {
 *   auto response = client->receive(WAIT_TIMEOUT);
 *   if (response.object == nullptr) {
 *     continue;
 *   }
 *
 *   if (response.id == 0) {
 *     // process response.object as an incoming update of type td_api::Update
 *   } else {
 *     // process response.object as an answer to a sent request with identifier response.id
 *   }
 * }
 * \endcode
 */
class Client final {
 public:
  /**
   * Creates a new TDLib client.
   */
  Client();

  /**
   * A request to the TDLib.
   */
  struct Request {
    /**
     * Request identifier.
     * Responses to TDLib requests will have the same id as the corresponding request.
     * Updates from TDLib will have id == 0, incoming requests are thus disallowed to have id == 0.
     */
    std::uint64_t id;

    /**
     * TDLib API function representing a request to TDLib.
     */
    td_api::object_ptr<td_api::Function> function;
  };

  /**
   * Sends request to TDLib. May be called from any thread.
   * \param[in] request Request to TDLib.
   */
  void send(Request &&request);

  /**
   * A response to a request, or an incoming update from TDLib.
   */
  struct Response {
    /**
     * TDLib request identifier, which corresponds to the response, or 0 for incoming updates from TDLib.
     */
    std::uint64_t id;

    /**
     * TDLib API object representing a response to a TDLib request or an incoming update.
     */
    td_api::object_ptr<td_api::Object> object;
  };

  /**
   * Receives incoming updates and request responses from TDLib. May be called from any thread, but shouldn't be
   * called simultaneously from two different threads.
   * \param[in] timeout The maximum number of seconds allowed for this function to wait for new data.
   * \return An incoming update or request response. The object returned in the response may be a nullptr
   *         if the timeout expires.
   */
  Response receive(double timeout);

  /**
   * Synchronously executes TDLib requests. Only a few requests can be executed synchronously.
   * May be called from any thread.
   * \param[in] request Request to the TDLib.
   * \return The request response.
   */
  static Response execute(Request &&request);

  /**
   * Destroys the client and TDLib instance.
   */
  ~Client();

  /**
   * Move constructor.
   */
  Client(Client &&other) noexcept;

  /**
   * Move assignment operator.
   */
  Client &operator=(Client &&other) noexcept;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace td
