//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include <iostream>
#include <td/telegram/td_json_client.h>

// Basic example of TDLib JSON interface usage.
// Native interface should be preferred instead in C++, so here is only an example of
// the main event cycle, which should be essentially the same for all languages.

int main() {
  // disable TDLib logging
  td_execute("{\"@type\":\"setLogVerbosityLevel\", \"new_verbosity_level\":0}");

  int client_id = td_create_client_id();
  // somehow share the client_id with other threads, which will be able to send requests via td_send

  // start the client by sending request to it
  td_send(client_id, "{\"@type\":\"getOption\", \"name\":\"version\"}");

  const bool test_incorrect_queries = false;
  if (test_incorrect_queries) {
    td_execute("{\"@type\":\"setLogVerbosityLevel\", \"new_verbosity_level\":1}");
    td_execute("");
    td_execute("test");
    td_execute("\"test\"");
    td_execute("{\"@type\":\"test\", \"@extra\":1}");

    td_send(client_id, "{\"@type\":\"getFileMimeType\"}");
    td_send(client_id, "{\"@type\":\"getFileMimeType\", \"@extra\":1}");
    td_send(client_id, "{\"@type\":\"getFileMimeType\", \"@extra\":null}");
    td_send(client_id, "{\"@type\":\"test\"}");
    td_send(client_id, "[]");
    td_send(client_id, "{\"@type\":\"test\", \"@extra\":1}");
    td_send(client_id, "{\"@type\":\"sendMessage\", \"chat_id\":true, \"@extra\":1}");
    td_send(client_id, "test");
  }

  const double WAIT_TIMEOUT = 10.0;  // seconds
  while (true) {
    const char *result = td_receive(WAIT_TIMEOUT);
    if (result != nullptr) {
      // parse the result as a JSON object and process it as an incoming update or an answer to a previously sent request

      // if (result is UpdateAuthorizationState with authorizationStateClosed) {
      //   break;
      // }

      std::cout << result << std::endl;
    }
  }
}
