//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

/**
 * \file
 * C interface for interaction with TDLib via JSON-serialized objects.
 * Can be used to easily integrate TDLib with any programming language which supports calling C functions
 * and is able to work with JSON.
 *
 * The JSON serialization of TDLib API objects is straightforward: all API objects are represented as JSON objects with
 * the same keys as the API object field names. The object type name is stored in the special field "@type" which is
 * optional in places where type is uniquely determined by the context.
 * Fields of Bool type are stored as Boolean, fields of int32, int53, and double types are stored as Number, fields of
 * int64 and string types are stored as String, fields of bytes type are base64 encoded and then stored as String,
 * fields of array type are stored as Array.
 *
 * The main TDLib interface is asynchronous. To match requests with a corresponding response, the field "@extra" can
 * be added to the request object. The corresponding response will have an "@extra" field with exactly the same value.
 * Each returned object will have an "@client_id" field, containing the identifier of the client for which
 * a response or an update was received.
 *
 * A TDLib client instance can be created through td_create_client_id.
 * Requests can be sent using td_send and the received client identifier.
 * New updates and responses to requests can be received through td_receive from any thread after the first request
 * has been sent to the client instance. This function must not be called simultaneously from two different threads.
 * Also, note that all updates and responses to requests must be applied in the order they were received for consistency.
 * Some TDLib requests can be executed synchronously from any thread using td_execute.
 * TDLib client instances are destroyed automatically after they are closed.
 * All TDLib client instances must be closed before application termination to ensure data consistency.
 *
 * General pattern of usage:
 * \code
 * int client_id = td_create_client_id();
 * // share the client_id with other threads, which will be able to send requests via td_send
 *
 * const double WAIT_TIMEOUT = 10.0; // seconds
 * while (true) {
 *   const char *result = td_receive(WAIT_TIMEOUT);
 *   if (result) {
 *     // parse the result as a JSON object and process it as an incoming update or the answer to a previously sent request
 *   }
 * }
 * \endcode
 */

#include "td/telegram/tdjson_export.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns an opaque identifier of a new TDLib instance.
 * The TDLib instance will not send updates until the first request is sent to it.
 * \return Opaque identifier of a new TDLib instance.
 */
TDJSON_EXPORT int td_create_client_id();

/**
 * Sends request to the TDLib client. May be called from any thread.
 * \param[in] client_id TDLib client identifier.
 * \param[in] request JSON-serialized null-terminated request to TDLib.
 */
TDJSON_EXPORT void td_send(int client_id, const char *request);

/**
 * Receives incoming updates and request responses. Must not be called simultaneously from two different threads.
 * The returned pointer can be used until the next call to td_receive or td_execute, after which it will be deallocated by TDLib.
 * \param[in] timeout The maximum number of seconds allowed for this function to wait for new data.
 * \return JSON-serialized null-terminated incoming update or request response. May be NULL if the timeout expires.
 */
TDJSON_EXPORT const char *td_receive(double timeout);

/**
 * Synchronously executes a TDLib request.
 * A request can be executed synchronously, only if it is documented with "Can be called synchronously".
 * The returned pointer can be used until the next call to td_receive or td_execute, after which it will be deallocated by TDLib.
 * \param[in] request JSON-serialized null-terminated request to TDLib.
 * \return JSON-serialized null-terminated request response.
 */
TDJSON_EXPORT const char *td_execute(const char *request);

/**
 * A type of callback function that will be called when a message is added to the internal TDLib log.
 *
 * \param verbosity_level Log verbosity level with which the message was added from -1 up to 1024.
 *                        If 0, then TDLib will crash as soon as the callback returns.
 *                        None of the TDLib methods can be called from the callback.
 * \param message Null-terminated UTF-8-encoded string with the message added to the log.
 */
typedef void (*td_log_message_callback_ptr)(int verbosity_level, const char *message);

/**
 * Sets the callback that will be called when a message is added to the internal TDLib log.
 * None of the TDLib methods can be called from the callback.
 * By default the callback is not set.
 *
 * \param[in] max_verbosity_level The maximum verbosity level of messages for which the callback will be called.
 * \param[in] callback Callback that will be called when a message is added to the internal TDLib log.
 *                     Pass nullptr to remove the callback.
 */
TDJSON_EXPORT void td_set_log_message_callback(int max_verbosity_level, td_log_message_callback_ptr callback);

/**
 * \file
 * Alternatively, you can use old TDLib JSON interface, which will be removed in TDLib 2.0.0.
 *
 * Objects and functions serialization to JSON is the same for both JSON interfaces.
 *
 * The main TDLib interface is asynchronous. To match requests with a corresponding response a field "@extra" can
 * be added to the request object. The corresponding response will have an "@extra" field with exactly the same value.
 *
 * A TDLib client instance can be created through td_json_client_create.
 * Requests then can be sent using td_json_client_send from any thread.
 * New updates and request responses can be received through td_json_client_receive from any thread. This function
 * must not be called simultaneously from two different threads. Also, note that all updates and request responses
 * must be applied in the order they were received to ensure consistency.
 * Given this information, it's advisable to call this function from a dedicated thread.
 * Some service TDLib requests can be executed synchronously from any thread by using td_json_client_execute.
 * The TDLib client instance can be destroyed via td_json_client_destroy.
 *
 * General pattern of usage:
 * \code
 * void *client = td_json_client_create();
 * // somehow share the client with other threads, which will be able to send requests via td_json_client_send
 *
 * const double WAIT_TIMEOUT = 10.0; // seconds
 * int is_closed = 0;  // should be set to 1, when updateAuthorizationState with authorizationStateClosed is received
 * while (!is_closed) {
 *   const char *result = td_json_client_receive(client, WAIT_TIMEOUT);
 *   if (result) {
 *     // parse the result as JSON object and process it as an incoming update or an answer to a previously sent request
 *   }
 * }
 * td_json_client_destroy(client);
 * \endcode
 */

/**
 * Creates a new instance of TDLib.
 * \return Pointer to the created instance of TDLib.
 */
TDJSON_EXPORT void *td_json_client_create();

/**
 * Sends request to the TDLib client. May be called from any thread.
 * \param[in] client The client.
 * \param[in] request JSON-serialized null-terminated request to TDLib.
 */
TDJSON_EXPORT void td_json_client_send(void *client, const char *request);

/**
 * Receives incoming updates and request responses from the TDLib client. May be called from any thread, but
 * must not be called simultaneously from two different threads.
 * Returned pointer will be deallocated by TDLib during next call to td_json_client_receive or td_json_client_execute
 * in the same thread, so it can't be used after that.
 * \param[in] client The client.
 * \param[in] timeout The maximum number of seconds allowed for this function to wait for new data.
 * \return JSON-serialized null-terminated incoming update or request response. May be NULL if the timeout expires.
 */
TDJSON_EXPORT const char *td_json_client_receive(void *client, double timeout);

/**
 * Synchronously executes TDLib request. May be called from any thread.
 * Only a few requests can be executed synchronously.
 * Returned pointer will be deallocated by TDLib during next call to td_json_client_receive or td_json_client_execute
 * in the same thread, so it can't be used after that.
 * \param[in] client The client. Currently, ignored for all requests, so NULL can be passed.
 * \param[in] request JSON-serialized null-terminated request to TDLib.
 * \return JSON-serialized null-terminated request response.
 */
TDJSON_EXPORT const char *td_json_client_execute(void *client, const char *request);

/**
 * Destroys the TDLib client instance. After this is called the client instance must not be used anymore.
 * \param[in] client The client.
 */
TDJSON_EXPORT void td_json_client_destroy(void *client);

#ifdef __cplusplus
}  // extern "C"
#endif
