//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
package org.drinkless.tdlib;

/**
 * Main class for interaction with the TDLib using JSON interface.
 */
public final class JsonClient {
    static {
        try {
            System.loadLibrary("tdjsonjava");
        } catch (UnsatisfiedLinkError e) {
            e.printStackTrace();
        }
    }

    /**
     * Returns an opaque identifier of a new TDLib instance.
     * The TDLib instance will not send updates until the first request is sent to it.
     * @return Opaque identifier of a new TDLib instance.
     */
    public static native int createClientId();

    /**
     * Sends request to the TDLib client. May be called from any thread.
     * @param clientId TDLib client identifier.
     * @param request JSON-serialized request.
     */
    public static native void send(int clientId, String request);

    /**
     * Receives incoming updates and request responses. Must not be called simultaneously from two different threads.
     * @param timeout The maximum number of seconds allowed for this function to wait for new data.
     * @return JSON-serialized incoming update or request response. May be null if the timeout expired before new data received.
     */
    public static native String receive(double timeout);

    /**
     * Synchronously executes a TDLib request.
     * A request can be executed synchronously, only if it is documented with "Can be called synchronously".
     * @param request JSON-serialized request.
     * @return JSON-serialized request response. May be null if the request is invalid.
     */
    public static native String execute(String request);

    /**
     * Interface for handler of messages that are added to the internal TDLib log.
     */
    public interface LogMessageHandler {
        /**
         * Callback called on messages that are added to the internal TDLib log.
         *
         * @param verbosityLevel Log verbosity level with which the message was added from -1 up to 1024.
         *                       If 0, then TDLib will crash as soon as the callback returns.
         *                       None of the TDLib methods can be called from the callback.
         * @param message        The message added to the internal TDLib log.
         */
        void onLogMessage(int verbosityLevel, String message);
    }

    /**
     * Sets the handler for messages that are added to the internal TDLib log.
     * None of the TDLib methods can be called from the callback.
     *
     * @param maxVerbosityLevel The maximum verbosity level of messages for which the callback will be called.
     * @param logMessageHandler Handler for messages that are added to the internal TDLib log. Pass null to remove the handler.
     */
    public static native void setLogMessageHandler(int maxVerbosityLevel, JsonClient.LogMessageHandler logMessageHandler);

    /**
     * The class can't be instantiated.
     */
    private JsonClient() {
    }
}
