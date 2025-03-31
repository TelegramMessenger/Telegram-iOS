//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
package org.drinkless.tdlib.example;

import org.drinkless.tdlib.JsonClient;

/**
 * Example class for TDLib usage from Java using JSON interface.
 */
public final class JsonExample {
    public static void main(String[] args) throws InterruptedException {
        // set log message handler to handle only fatal errors (0) and plain log messages (-1)
        JsonClient.setLogMessageHandler(0, new LogMessageHandler());

        // disable TDLib log and redirect fatal errors and plain log messages to a file
        JsonClient.execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
        JsonClient.execute("{\"@type\":\"setLogStream\",\"log_stream\":{\"@type\":\"logStreamFile\",\"path\":\"tdlib.log\",\"max_file_size\":128000000}}");

        // create client identifier
        int clientId = JsonClient.createClientId();

        // send first request to activate the client
        JsonClient.send(clientId, "{\"@type\":\"getOption\",\"name\":\"version\"}");

        // main loop
        while (true) {
            String result = JsonClient.receive(100.0);
            if (result != null) {
                System.out.println(result);
            }
        }
    }

    private static class LogMessageHandler implements JsonClient.LogMessageHandler {
        @Override
        public void onLogMessage(int verbosityLevel, String message) {
            System.err.print(message);
            if (verbosityLevel == 0) {
                System.err.println("Receive fatal error; the process will crash now");
            }
        }
    }
}
