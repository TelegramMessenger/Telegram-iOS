//
//  HTTPServer.swift
//  NWHTTPServer
//
//  Copyright © 2020-2022 ZeeZide GmbH. All rights reserved.
//

import class Dispatch.DispatchQueue
import func  Dispatch.dispatchMain
import class Network.NWListener
import class Network.NWConnection
import class Network.NWParameters
import class Network.NWProtocolFramer
import class Network.NWProtocolTCP
import enum  Network.NWEndpoint

/**
 * A very simple Network.framework based HTTP server.
 * 
 * Example:
 *
 *     let server = HTTPServer { request, response in
 *         print("Received:", request)
 *         try response.send("Hello!\n")
 *     }
 *     server.run()
 *
 */
@available(iOS 13.0, *)
public final class HTTPServer {
    
  let queue    : DispatchQueue
  let handler  : ( IncomingMessage, ServerResponse ) throws -> Void
  let listener : NWListener
  
  private var clients   = [ ObjectIdentifier : ConnectionState ]()
  private var _listenCB : (( HTTPServer ) -> Void)?
  private var _errorCB  : (( HTTPServer, Swift.Error ) -> Void)?

  /**
   * Initialize an HTTP server.
   *
   * Example:
   *
   *     let server = HTTPServer { request, response in
   *         print("Received:", request)
   *         try response.send("Hello!\n")
   *     }
   *
   * - Parameters:
   *   - port:       The TCP port the server should listen on (default: 8000)
   *   - tcpOptions: Optional, alternative Network framework TCP options
   *   - queue:      The DispatchQueue the server operates on. This should be
   *                 a _serial_ queue. Defaults to `.main`
   *   - handler:    Closure to invoke when an HTTP request was received.
   */
  public init(port       : NWEndpoint.Port        = 8000,
              tcpOptions : NWProtocolTCP.Options? = nil,
              queue      : DispatchQueue = .main,
              handler    : @escaping
                           ( IncomingMessage, ServerResponse ) throws -> Void)
           throws
  {
    self.queue   = queue
    self.handler = handler
    
    let params : NWParameters = {
      let params = NWParameters(tls: nil, tcp: tcpOptions ?? {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle   = 2
        return tcpOptions
      }())
      
      let httpProtocol =
        NWProtocolFramer.Options(definition: HTTPProtocol.definition)
      
      params.defaultProtocolStack
        .applicationProtocols
        .insert(httpProtocol, at: 0)
      
      return params
    }()
    
    listener = try NWListener(using: params, on: port)
  }
  
  /**
   * Starts the server, never returns
   *
   * Example:
   *
   *     server.run()
   *
   * For more fine grained flow control, use `resume` and `suspend`.
   */
  public func run() -> Never {
    resume()
    dispatchMain()
  }
  
  /**
   * Starts the server in the background.
   *
   * Note: This does not keep a commandline tool (or thread) running, use `run`
   *       to start a server "forever".
   */
  public func resume() {
    listener.newConnectionHandler = handleNewConnection
    listener.stateUpdateHandler   = handleListenerStateChange
    listener.start(queue: queue)
  }
  
  /**
   * Stops the server and cancels all running connections.
   */
  public func suspend() {
    listener.cancel()
    listener.newConnectionHandler = nil
    listener.stateUpdateHandler   = nil
    
    // TBD: we could also offer a more graceful option
    for state in clients.values {
      state.cancel()
      unregister(state.connection)
    }
    assert(clients.isEmpty)
    clients = [:]
  }
  
  
  // MARK: - Events
  
  /**
   * Register a callback to be called when the server starts accepting requests.
   *
   * - Parameter execute: A closure to run when the server actually started
   *                      listening (i.e. can be reached by clients).
   */
  public func onListen(execute: @escaping ( HTTPServer ) -> Void) {
    _listenCB = execute
  }
  
  /**
   * Register an error handler which will be invoked when errors happen on
   * either the listener or the connection.
   *
   * - Parameter execute: A closure to run when the server encounters an error.
   */
  public func onError(execute: @escaping ( HTTPServer, Swift.Error ) -> Void) {
    _errorCB = execute
  }
  
  
  // MARK: - Connection Handling
  
  private enum ConnectionState {
    case idle   (NWConnection)
    case running(NWConnection, IncomingMessage, ServerResponse)
    
    var connection : NWConnection {
      switch self {
        case .idle   (let c)       : return c
        case .running(let c, _, _) : return c
      }
    }
    func cancel() {
      switch self {
        case .idle(let c):
          c.cancel()
        case .running(let c, let m, let res):
          if !m.readableEnded   { m.push(nil) }
          if !res.writableEnded { res.end()   }
          c.cancel()
      }
    }
    var incomingMessage : IncomingMessage? {
      switch self {
        case .idle                 : return nil
        case .running(_, let m, _) : return m
      }
    }
  }

  private func handleListenerStateChange(_ state: NWListener.State) {
    switch state {
      case .setup, .waiting : break
      case .ready           : _listenCB?(self)
      case .cancelled       : suspend()
        
      case .failed(let error):
        suspend()
        _errorCB?(self, error)
        
      @unknown default: break
    }
  }
  
  private func handleStateChange(_ state: NWConnection.State,
                                 on connection: NWConnection)
  {
    switch state {
      case .setup, .preparing, .waiting: break
      case .ready     : readNextMessage(from: connection)
      case .cancelled : unregister(connection)
        
      case .failed(let error):
        unregister(connection)
        _errorCB?(self, error)
        
      @unknown default: break
    }
  }
  
  private func unregister(_ connection: NWConnection) {
    if let state = clients.removeValue(forKey: ObjectIdentifier(connection)) {
      if case .running(_, let req, let res) = state {
        if !req.readableEnded { req.push(nil) }
        if !res.writableEnded { res.end() }
      }
    }
    connection.stateUpdateHandler = nil
  }
  
  private func handleNewConnection(_ connection: NWConnection) {
    let oid = ObjectIdentifier(connection)
    assert(clients[oid] == nil)
    clients[oid] = .idle(connection)
    
    connection.stateUpdateHandler = {
      self.handleStateChange($0, on: connection)
    }
    connection.start(queue: queue)
  }
  
  private func readNextMessage(from connection: NWConnection) {
    let oid = ObjectIdentifier(connection)
    
    connection.receiveMessage { data, context, isComplete, error in
      assert(isComplete || error != nil) // right?
      
      guard let state = self.clients[oid] else { // already cancelled.
        // can happen when the server is suspended (that cancels all the
        // connections and drops all states synchronously).
        return
      }
      
      func emitError(_ error: Swift.Error) {
        if case .running(_, let req, _) = state, req.emitError(error) {
          // error handled as part of the request
        }
        else if let cb = self._errorCB {
          cb(self, error)
        }
      }
      func endBothEnds() {
        if case .running(_, let req, let res) = state {
          if !req.readableEnded { req.push(nil) }
          if !res.writableEnded { res.end() }
        }
      }
      
      if let error = error {
        emitError(error)
        connection.cancel() // no recovery possible?
        return endBothEnds()
      }
      
      guard let message = context.httpMessage else {
        switch state {
          case .idle: // hit if the client closes a keep-alive connection
            connection.cancel()
            return endBothEnds()
          case .running(_, let req, _):
            if !req.readableEnded { req.push(nil) }
            // Do not close `response`(/connection), we could still be writing!
        }
        return
      }
      
      if let error = message.error {
        emitError(error)
        connection.cancel() // no recovery possible?
        return endBothEnds()
      }
      
      /* HTTP Request HEAD */
      if let method = message.method, let path = message.path {
        if case .running(_, let req, _) = state {
          if !req.readableEnded { req.push(nil) }
        }
        
        let req = IncomingMessage(method: .init(rawValue: method), path: path,
                                  headers: message.headers)
        let res = ServerResponse(keepAlive: false)
        res.connection = connection
        
        res.onEnd { res in
          if let state = self.clients[oid],
             case .running(let connection, _, _) = state,
             connection === res.connection
          {
            self.clients[oid] = .idle(connection)
          }
        }
        
        self.clients[oid] = ConnectionState.running(connection, req, res)
        
        do {
          try self.handler(req, res)
          return self.readNextMessage(from: connection)
        }
        catch {
          emitError(error)
          if !res.writableEnded && !res.didWriteHead {
            res.keepAlive = false
            res.writeHead(status: 500, headers: [ "Connection": "close" ])
            res.end()
          }
          return connection.cancel()
        }
      }
      
      /* HTTP response HEAD */
      if let _ = message.status {
        // attempt to send a response to the server :-)
        switch state {
          case .idle    : break
          case .running : endBothEnds()
        }
        return connection.cancel()
      }
      
      
      func endRequest() {
        if case .running(_, let req, _) = state {
          if !req.readableEnded { req.push(nil) }
        }
      }
      
      if let data = data {
        assert(message.status == nil && message.method == nil)
        switch state {
          case .idle:
            assertionFailure("receiving body data, w/o a HEAD?")
            return connection.cancel()
            
          case .running(_, let req, let res):
            res.keepAlive = message.shouldKeepAlive
            if data.isEmpty {
              assert(message.isEndOfMessage)
              endRequest()
            }
            else {
              req.push(data)
              if message.isEndOfMessage { endRequest() }
            }
            return self.readNextMessage(from: connection)
        }
      }
      
      if message.isEndOfMessage {
        endRequest()
        return self.readNextMessage(from: connection)
      }

      assertionFailure("got neither data nor metadata? \(message)")
      return connection.cancel()
    }
  }
}

