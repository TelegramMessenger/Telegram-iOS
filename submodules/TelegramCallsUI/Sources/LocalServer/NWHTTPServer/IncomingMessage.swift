//
//  IncomingMessage.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Foundation.Data
import class  Foundation.JSONDecoder
import class  Foundation.JSONSerialization

/**
 * Represents an incoming HTTP message.
 *
 * This can be both, a Request or a Response - it is a Response when it got
 * created by a client and it is a Request if it is coming from the Server.
 *
 * The content of the message can be either streamed to the client,
 * or if no data callback is set, it will get buffered within the
 * object.
 * In both cases one needs to wait for `end`!
 *
 * Content Buffering:
 *
 *     let server = try HTTPServer { request, response in
 *         print("Request:", request)
 *         request.onEnd {
 *             print("received content:", request.content)
 *             response.send("OK, got it!\n")
 *         }
 *     }
 *
 * Content Streaming:
 *
 *     let server = try HTTPServer { request, response in
 *         print("Request:", request)
 *         request.onData { data in
 *             print("received data chunk:", data)
 *         }
 *         request.onEnd {
 *             response.send("OK, got it!\n")
 *         }
 *     }
 *
 */
@available(iOS 13.0, *)
open class IncomingMessage: CustomStringConvertible {
  // Most is marked `open` in case the consumer wants to patch stuff in a
  // subclass.
  
  public enum IncomingType {
    case request (method: HTTPMethod, path: String)
    case response(status: HTTPStatus)
  }
    
  open var messageType   : IncomingType
  open var headers       : HTTPProtocol.Headers
  open var bufferedData  = Data()
  open var readableEnded = false

  open var _errorCB      : (( Swift.Error ) -> Void)?
  open var _dataCB       : (( Data ) -> Void)?
  open var _endCB        : (() -> Void)?

  public init(method: HTTPMethod, path: String,
              headers: HTTPProtocol.Headers = [])
  {
    self.messageType = .request(method: method, path: path)
    self.headers     = headers
  }
  public init(status: HTTPStatus, headers: HTTPProtocol.Headers = []) {
    self.messageType = .response(status: status)
    self.headers     = headers
  }
  
  
  // MARK: - Callbacks
  
  /**
   * Register a callback to be executed when content is received. When a
   * callback is set, the buffer won't get filled.
   *
   * If data was accumulated already, it will be flushed to that closure.
   *
   * Example:
   *
   *     request.onData { data in
   *         print("received data chunk:", data)
   *     }
   *
   */
  open func onData(execute: @escaping ( Data ) -> Void) {
    _dataCB = execute
    flush() // TBD: async?
  }
  
  /**
   * Register a callback to be executed when the request has been retrieved
   * completely, i.e. all body data has been read.
   */
  open func onEnd(execute: @escaping () -> Void) {
    guard !readableEnded else { return execute() } // TBD: async?
    _endCB = execute
  }
  
  /**
   * Register a callback to be executed when request specific errors arrive.
   * If none is set, errors will be sent to the HTTPserver error handler.
   */
  open func onError(execute: @escaping ( Swift.Error ) -> Void) {
    _errorCB = execute
  }
  
  internal func emitError(_ error: Swift.Error) -> Bool {
    guard let cb = _errorCB else { return false }
    cb(error)
    return true
  }
  

  // MARK: - Receiving Body Data
  
  private func flush() {
    guard let dataCB = _dataCB  else { return }
    guard !bufferedData.isEmpty else { return }
    let data = bufferedData; bufferedData = Data()
    dataCB(data)
  }
  private func invalidate() {
    _dataCB  = nil
    _endCB   = nil
    _errorCB = nil
  }
  
  /**
   * Push new body data into the request. Push `nil` for end-of-message.
   */
  open func push(_ data: Data?) {
    assert(!readableEnded)
    guard !readableEnded else { return }
    
    guard let data = data else { // EOF
      readableEnded = true
      flush()
      _endCB?()
      return invalidate()
    }
    
    if let dataCB = _dataCB {
      flush()
      dataCB(data)
    }
    else {
      bufferedData.append(data)
    }
  }
  
  
  // MARK: - Content Accessors (when used w/o a callback)
  
  /**
   * Returns all body data buffered so far. Note that this will be empty at the
   * time the HTTPServer handler is invoked!
   * To wait for all content to arrive in the buffer, use the `onEnd` callback.
   *
   * Example:
   *
   *     request.onEnd {
   *         print("received content:", request.content)
   *     }
   *
   * No data will be buffered if the user has installed an `onData` handler.
   */
  open var content : Data {
    return bufferedData
  }
  
  /**
   * Returns all body data buffered so far. Note that this will be empty at the
   * time the HTTPServer handler is invoked!
   * To wait for all content to arrive in the buffer, use the `onEnd` callback.
   *
   * This variant tries to return the content as an UTF-8 string. If a
   * conversion to UTF-8 fails, an error will be emitted and nil will be
   * returned.
   *
   * Example:
   *
   *     request.onEnd {
   *         print("received content:", request.contentAsString ?? "-")
   *     }
   *
   * No data will be buffered if the user has installed an `onData` handler.
   */
  open var contentAsString : String? {
    // TODO: scan for charset in headers :-)
    guard !content.isEmpty else { return "" }
    guard let s = String(data: content, encoding: .utf8) else {
      _errorCB?(StringEncodingError(encoding: .utf8))
      return nil
    }
    return s
  }
  
  /**
   * Returns all body data buffered so far. Note that this will be empty at the
   * time the HTTPServer handler is invoked!
   * To wait for all content to arrive in the buffer, use the `onEnd` callback.
   *
   * This variant tries to parse the content as JSON into a Decodable type
   * provided.
   *
   * Example:
   *
   *     struct Entry: Codable {
   *       let date  : Date
   *       let title : String
   *       let body  : String
   *     }
   *
   *     request.onEnd {
   *         guard let entry = try? request.decodeJSON(as: Entry.self) else {
   *             response.writeHead(status: badRequest)
   *             response.end()
   *             return
   *         }
   *         print("received entry:", entry)
   *         response.send("got entry!")
   *     }
   *
   * No data will be buffered if the user has installed an `onData` handler.
   */
  open func decodeJSON<T: Decodable>(as type: T.Type) throws -> T {
    return try JSONDecoder().decode(type, from: content)
  }

  /**
   * Returns all body data buffered so far. Note that this will be empty at the
   * time the HTTPServer handler is invoked!
   * To wait for all content to arrive in the buffer, use the `onEnd` callback.
   *
   * This variant tries to parse the content as JSON into property list values.
   *
   * Example:
   *
   *     request.onEnd {
   *         guard let entry = try? request.decodeJSON()
   *                       as? [ String : String] else
   *         {
   *             response.writeHead(status: badRequest)
   *             response.end()
   *             return
   *         }
   *         print("received entry:", entry)
   *         response.send("got entry!")
   *     }
   *
   * No data will be buffered if the user has installed an `onData` handler.
   */
  open func decodeJSON(options : JSONSerialization.ReadingOptions = []) throws
            -> Any
  {
    return try JSONSerialization.jsonObject(with: content, options: options)
  }

  
  // MARK: - HTTP Requests
  
  @inlinable
  public var method : HTTPMethod {
    guard case .request(let method, _) = messageType else { return "" }
    return method
  }
  
  @inlinable
  public var url : String {
    guard case .request(_, let path) = messageType else { return "" }
    return path
  }
  
  // MARK: - HTTP Responses
 
  @inlinable
  public var statusCode : Int {
    guard case .response(let status) = messageType else { return 0 }
    return status.rawValue
  }
  
  
  // MARK: - Description
  
  open var description: String {
    var ms = "<"
    
    switch messageType {
      case .request(let method, let path):
        ms += method.rawValue + ": " + path
      case .response(let status):
        ms += "\(status)"
    }
    
    headers.forEach { ( name, value ) in
      ms += " " + name + "=" + value
    }
    
    ms += ">"
    return ms
  }
}
