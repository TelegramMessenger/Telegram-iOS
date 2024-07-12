//
//  ServerResponse.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Foundation.Data
import class  Foundation.JSONEncoder
import class  Foundation.JSONSerialization
import class  Network.NWConnection
import class  Network.NWProtocolFramer
import enum   Network.NWError

/**
 * Represents an HTTP response sent by the server.
 *
 * `ServerResponse` is not usually created by user code, it is provided to
 * the HTTPServer handler closure when a request is initiated.
 *
 * Example:
 *
 *     let server = HTTPServer { request, response in
 *         try response.send("Hello!\n")
 *     }
 *     server.run()
 *
 * The `send` functions are convenience which setup things like Content-Length
 * and Content-Type headers.
 *
 * When using the lower level `write` function, make sure to properly `end`
 * the request!
 *
 * Example:
 *
 *     let server = HTTPServer { request, response in
 *         response.write("Hello" .data(using: .utf8)!)
 *         response.write(" World".data(using: .utf8)!)
 *         response.keepAlive = false // because we set no content-length
 *         response.end() // important!
 *     }
 *     server.run()
 *
 */

@available(iOS 13.0, *)
open class ServerResponse {
  // Most is marked `open` in case the consumer wants to patch stuff in a
  // subclass.

  open var connection    : NWConnection?
  open var keepAlive     : Bool
  open var status        : HTTPStatus
  open var headers       : [ String : String ]
  
  open var didWriteHead  = false
  open var content       : Data?
  open var writableEnded = false
  
  open var _endHandlers  = [ ( ServerResponse ) -> Void ]()
  
  /**
   * Setup a new `ServerResponse`.
   *
   * `ServerResponse` is not usually created by user code, it is provided to
   * the HTTPServer handler closure when a request is initiated.
   */
  public init(status    : HTTPStatus = 200,
              headers   : [ String : String ] = [:],
              keepAlive : Bool = false)
  {
    self.status    = status
    self.headers   = headers
    self.keepAlive = keepAlive
    if !keepAlive && self.headers["Connection"] == nil {
      self.headers["Connection"] = "close"
    }
  }
  
  
  // MARK: - Event Handlers
  
  // Note: We could add onError, but we can't really do much in this case?
  //       It currently just cancels the connection which should teardown
  //       everything.
  
  /**
   * Register closures to be executed when the response has been fully written
   * to the client. I.e. if `end` has been called and successfully executed.
   */
  open func onEnd(execute: @escaping ( ServerResponse ) -> Void) {
    guard !writableEnded else {
      return execute(self) // TBD: async this?
    }
    _endHandlers.append(execute)
  }
  
  
  // MARK: - Writing Response Data
  
  /**
   * Write the HTTP response head to the connection.
   *
   * Status and headers can be provided as arguments, and are combined w/
   * the values set in the response object.
   *
   * Consider using the higher level `send` functions instead.
   */
  open func writeHead(status  : HTTPStatus? = nil,
                      headers : [ String : String ] = [:])
  {
    assert(!didWriteHead)
    assert(!writableEnded)
    
    guard let connection = connection else {
      if let status = status { self.status = status }
      for ( name, value ) in headers {
        self.headers[name] = value
      }
      return
    }
    
    didWriteHead = true
    
    var headerArray = HTTPProtocol.Headers()
    headerArray.reserveCapacity(headers.count + self.headers.count)
    for ( name, value ) in self.headers {
      guard headers[name] == nil else { continue }
      headerArray.append( ( name: name, value: value ) )
    }
    for ( name, value ) in headers {
      headerArray.append( ( name: name, value: value ) )
    }
    
    let message = NWProtocolFramer.Message(status  : status?.rawValue
                                                  ?? self.status.rawValue,
                                           headers : headerArray)
    let context = NWConnection
      .ContentContext(identifier: "HTTPResponseHead", metadata: [ message ])
    
    connection.send(content: nil,
                    contentContext: context, isComplete: true,
                    completion: .contentProcessed({ error in
                      if let error = error { self.handleWriteError(error) }
                    }))

    flushIfPossible()
  }
  
  /**
   * Write HTTP body data to the connection.
   *
   * If the response head has not been written yet, it will be now.
   *
   * Important: Once finished writing to the response, call `end` to mark
   *            the response as complete.
   *
   * Consider using the higher level `send` functions instead.
   */
  @discardableResult
  open func write(_ data: Data) -> Bool {
    assert(!writableEnded)
    guard let connection = connection else {
      if content?.append(data) == nil { content = data }
      let hwm = 1000
      return (content?.count ?? 0) < hwm
    }
    
    if !didWriteHead { writeHead() }
    flushIfPossible()
    guard !data.isEmpty else { return true }

    let message = NWProtocolFramer.Message.httpMessage
    let context = NWConnection
      .ContentContext(identifier: "HTTPResponseBody", metadata: [ message ])
    
    connection.send(content: data,
                    contentContext: context, isComplete: true,
                    completion: .contentProcessed({ error in
                      if let error = error { self.handleWriteError(error) }
                    }))
    return true
  }

  /**
   * Finish the response.
   *
   * If the response head has not been written yet, it will be now, the same
   * for any potentially buffered data.
   *
   * Consider using the higher level `send` functions instead.
   */
  open func end() {
    assert(!writableEnded)

    writableEnded = true
    let callbacks = _endHandlers; _endHandlers = []
    
    guard let connection = connection else {
      return callbacks.forEach { $0(self) }
    }

    if !didWriteHead { writeHead() }
    flushIfPossible()

    let message = NWProtocolFramer.Message.httpMessage
    message.isEndOfMessage = true
    let context = NWConnection
      .ContentContext(identifier: "HTTPResponseEnd", metadata: [ message ])
    
    let keepAlive = self.keepAlive
    connection.send(content: nil, contentContext: context, isComplete: true,
                    completion: .contentProcessed({ error in
                      callbacks.forEach { $0(self) }
                      if !keepAlive {
                        connection.cancel()
                      }
                      // TODO: still need to teardown the state!
                      self.handleWriteResult(error)
                      self.connection = nil
                    }))
  }
  
  /**
   * If body content has been buffered due to a connection not being available,
   * this will try to flush the buffer.
   */
  public func flushIfPossible() {
    /* Flush buffered content */
    guard let connection = connection             else { return }
    defer { self.content = nil }
    guard let content = content, !content.isEmpty else { return }
    connection.send(content: content,
                    completion: .contentProcessed(handleWriteResult(_:)))
  }

  
  // MARK: - Error Handling
  
  private func handleWriteResult(_ error: NWError?) {
    if let error = error {
      handleWriteError(error)
    }
  }
  
  /**
   * Invoked by writing functions if a write failed.
   *
   * This will cancel the connection and call all `onEnd` callbacks.
   */
  open func handleWriteError(_ error: NWError) {
    keepAlive = false
    if !writableEnded { // like `end`, but no flush, EOM etc
      writableEnded = true
      let callbacks = _endHandlers; _endHandlers = []
      callbacks.forEach { $0(self) }
    }
    connection?.cancel()
    connection = nil
  }
  
  
  // MARK: - Header Access
  // This is crazy wrong and expects consistent casing :-)
  
  /**
   * Extract the `Content-Type` header, if available.
   */
  var contentType: String? {
    set {
      if let v = newValue { headers["Content-Type"] = v }
      else { headers.removeValue(forKey: "Content-Type") }
    }
    get { return headers["Content-Type"] }
  }
  
  
  // MARK: - Write Convenience

  /**
   * Send the `Data` object to the client. Can only be called once.
   *
   * This sets the `Content-Length` header to the length of the Data.
   * If no `Content-Type` header is set, it will add that as
   * "application/octet-stream".
   *
   * Example:
   *
   *     response.send("hello".data(using: .utf8)!)
   *
   */
  open func send(_ data: Data) {
    if !didWriteHead {
      if headers["Content-Length"] == nil {
        headers["Content-Length"] = "\(data.count)"
      }
      if contentType == nil {
        contentType = "application/octet-stream"
      }
    }
    write(data)
    end()
  }
  
  /**
   * Send the `String` object as UTF-8 to the client. Can only be called once.
   *
   * This sets the `Content-Length` header to the length of the UTF-8
   * representation of the String.
   * If no `Content-Type` header is set, it will add that as
   * "text/plain; charset=UTF-8".
   *
   * If the UTF-8 conversion fails, a `StringEncodingError` is thrown.
   *
   * Example:
   *
   *     try response.send("hello")
   *
   */
  open func send(_ string: String) throws {
    if contentType == nil { contentType = "text/plain; charset=UTF-8" }
    
    if string.isEmpty { return send(Data()) }

    // TODO: scan headers for requested charset
    guard let data = string.data(using: .utf8) else {
      throw StringEncodingError(encoding: .utf8)
    }
    
    send(data)
  }
  
  /**
   * Send the `String` object as UTF-8 to the client. Can only be called once.
   *
   * This sets the `Content-Length` header to the length of the UTF-8
   * representation of the String.
   * If no `Content-Type` header is set, it will add that as
   * "text/plain; charset=UTF-8".
   *
   * If the UTF-8 conversion fails, a `StringEncodingError` is thrown.
   *
   * Example:
   *
   *     try response.send("hello")
   *
   */
  open func send<S: StringProtocol>(_ string: S) throws {
    try send(String(string))
  }

  /**
   * Send the Encodable object as JSON to the client. Can only be called once.
   *
   * This sets the `Content-Length` header to the length of the encoded data.
   * If no `Content-Type` header is set, it will add that as
   * "application/json; charset=UTF-8".
   *
   * Example:
   *
   *     struct Entry: Codable {
   *       let date  : Date
   *       let title : String
   *       let body  : String
   *     }
   *     try response.send(Entry(date: Date(), title: "Hello", body: "World")
   *
   */
  open func sendJSON<T: Encodable>(_ value: T) throws {
    if contentType == nil { contentType = "application/json; charset=UTF-8" }
    let data = try JSONEncoder().encode(value)
    send(data)
  }
  
  /**
   * Send the property list object as JSON to the client. Can only be called
   * once.
   *
   * This sets the `Content-Length` header to the length of the encoded data.
   * If no `Content-Type` header is set, it will add that as
   * "application/json; charset=UTF-8".
   *
   * Example:
   *
   *     try response.send([ "title": "Hello", "body": "World" ])
   *
   */
  open func sendJSON(_ value : Any,
                     options : JSONSerialization.WritingOptions = []) throws
  {
    if contentType == nil { contentType = "application/json; charset=UTF-8" }
    let data =
      try JSONSerialization.data(withJSONObject: value, options: options)
    send(data)
  }
}
