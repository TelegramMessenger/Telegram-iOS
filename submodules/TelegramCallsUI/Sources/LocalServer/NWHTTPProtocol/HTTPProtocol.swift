//
//  HTTPProtocol.swift
//  NWHTTPProtocol
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import Foundation
import Network
import CHTTPParser

/**
 * A Network.framework HTTP protocol parser (aka a NWProtocolFramer).
 *
 * Just wrapping http_parser.c/h in the API boilerplate required for
 * Network.framework protocols.
 */
@available(iOS 13.0, *)
public final class HTTPProtocol: NWProtocolFramerImplementation {
  // Note: We don't really need a framer here because http_parser does all the
  //       framing already.
  
  public enum Error: Swift.Error {
    case parserError(name: String, description: String)
    case unknownMessageType
    case missingURI
    case writeFailed(Swift.Error)
  }
  
  public typealias Method  = String
  public typealias Header  = ( name: String, value: String )
  public typealias Headers = [ Header ]
  public typealias Status  = Int

  // Not required by protocol, but used for:
  // - protocol registration in protocol stack
  // - message object construction
  // - message object retrieval from context in receive
  public static let definition =
    NWProtocolFramer.Definition(implementation: HTTPProtocol.self)

  public static let label = "HTTP"

  private var parser   = UnsafeMutablePointer<http_parser>.allocate(capacity: 1)
  private var settings = http_parser_settings()
  
  public init(framer: NWProtocolFramer.Instance) {
    // TBD: maybe we could get the parser mode as an HTTP protocol option?!
    http_parser_init(parser, HTTP_BOTH)
    parser.pointee.data = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    
    settings.on_message_begin    = { $0?.framer.onBegin()         ; return 0 }
    settings.on_message_complete = { $0?.framer.messageFinished() ; return 0 }
    settings.on_headers_complete = { $0?.framer.headerFinished()  ; return 0 }
    
    settings.on_url = { parser, data, len in
      parser?.framer.processDataForState(.url, data, len) ?? 1
    }
    settings.on_header_field = { parser, data, len in
      parser?.framer.processDataForState(.headerName, data, len) ?? 1
    }
    settings.on_header_value = { parser, data, len in
      parser?.framer.processDataForState(.headerValue, data, len) ?? 1
    }
    settings.on_body = { parser, data, len in
      parser?.framer.processDataForState(.body, data, len) ?? 1
    }
  }
  deinit {
    parser.deallocate()
  }
  
  
  // MARK: - Lifecycle
  
  public func start  (framer: NWProtocolFramer.Instance)
              -> NWProtocolFramer.StartResult { return .ready }
  public func stop   (framer: NWProtocolFramer.Instance) -> Bool { return true }
  public func wakeup (framer: NWProtocolFramer.Instance) {}
  public func cleanup(framer: NWProtocolFramer.Instance) {}

  
  // MARK: - Parsing

  private enum ParseState {
    case idle, url, headerName, headerValue, body
  }
  
  private var parseState   = ParseState.idle
  private var url          : String?
  private var lastName     : String?
  private var headers      = [ ( name: String, value: String) ]()
  private var buffer       = Data(capacity: 500)
  private var activeFramer : NWProtocolFramer.Instance?
  
  private func onBegin() {
    clearState()
  }

  private func clearState() {
    self.url      = nil
    self.lastName = nil
    self.headers.removeAll(keepingCapacity: true)
  }
  
  private func emit(_ message: NWProtocolFramer.Message,
                    to framer: NWProtocolFramer.Instance)
  {
    let ok = framer.deliverInputNoCopy(length     : 0,
                                       message    : message,
                                       isComplete : true)
    assert(ok)
  }
  private func emit(_    data : Data,
                    to framer : NWProtocolFramer.Instance)
  {
    let message = NWProtocolFramer.Message.httpMessage
    message.isEndOfMessage  = http_body_is_final    (parser) != 0
    message.shouldKeepAlive = http_should_keep_alive(parser) != 0
    framer.deliverInput(data: data, message: message, isComplete: true)
  }
  private func emit(_    data : UnsafeBufferPointer<Int8>,
                    to framer : NWProtocolFramer.Instance)
  {
    emit(Data(buffer: data), to: framer)
  }

  private func headerFinished() {
    _ = processDataForState(.body, nil, 0) // start body
    
    assert(activeFramer != nil)
    guard let framer = activeFramer else { return }

    // We could also do HTTP major/minor too, not really important.

    if isRequest {
      assert(!isResponse)
      defer { clearState()}
      

      let method = http_method(CUnsignedInt(parser.pointee.method)).stringValue
      guard let url = url else {
        return emit(.init(error: .missingURI), to: framer)
      }
      return emit(.init(method: method, path: url, headers: headers,
                        shouldKeepAlive: http_should_keep_alive(parser) != 0),
                  to: framer)
    }
    
    if isResponse {
      assert(!isResponse)
      defer { clearState()}

      let status = Int(parser.pointee.status_code)
      return emit(.init(status: status, headers: headers), to: framer)
    }
    
    emit(.init(error: .unknownMessageType), to: framer)
  }
  
  private func messageFinished() {
    _ = processDataForState(.idle, nil, 0) // flush end body
    
    if let framer = activeFramer {
      // send explicit EOM
      let message = NWProtocolFramer.Message.httpMessage
      message.isEndOfMessage  = true
      message.shouldKeepAlive = http_should_keep_alive(parser) != 0
      emit(message, to: framer)
    }
  }

  private var isRequest  : Bool { return parser.pointee.type == 0 }
  private var isResponse : Bool { return parser.pointee.type == 1 }

  private func addData(_ data: UnsafePointer<Int8>?, _ length: Int) -> Int32 {
    switch parseState {
    
      case .idle:
        guard length == 0 else {
          assertionFailure("receiving data in idle state!")
          return 1
        }
        return 0
        
      case .url, .headerName, .headerValue:
        guard length > 0 else { return 0 }
        buffer.append(UnsafeBufferPointer(start: data, count: length))
        return 0
        
      case .body:
        guard let framer = activeFramer else { return 1 }
        guard length > 0 else { return 1 }
        assert(activeFramer != nil)
        
        // TBD: Can we avoid the copying? Maybe. Would need to track more
        //      things (i.e. whether state switches happened).
        let bptr = UnsafeBufferPointer(start: data, count: length)
        emit(bptr, to: framer)
        return 0
    }
  }
  
  private func flushOldState(_ oldState: ParseState) -> Int32 {
    defer { buffer.removeAll() }
    
    var bufferAsString : String? {
      return String(data: buffer, encoding: .utf8) // Hm, latin-1? ;-)
    }
    
    switch oldState { // finish up OLD parse state
      case .idle:
        assert(buffer.isEmpty)
        guard buffer.isEmpty else { return 1 }
        
      case .headerValue:
        assert(lastName != nil)
        guard let n = lastName, let s = bufferAsString else { return 1 }
        headers.append( (name: n, value: s) )
        lastName = nil
      
      case .headerName:
        assert(lastName == nil)
        guard lastName == nil, let s = bufferAsString else { return 1 }
        lastName = s

      case .url:
        assert(url == nil)
        guard url == nil, let s = bufferAsString else { return 1 }
        url = s

      case .body:
        if !buffer.isEmpty {
          guard let framer = activeFramer else { return 1 }
          emit(buffer, to: framer)
        }
    }
    
    return 0
  }
  
  private func processDataForState(_ state: ParseState,
                                   _ ptr: UnsafePointer<Int8>?, _ length: Int)
               -> Int32
  {
    if state == parseState { // more data for same field
      return addData(ptr, length)
    }
    
    let rc = flushOldState(parseState)
    if rc != 0 { return rc }
    assert(buffer.isEmpty)
    
    /* start thew new state */
    parseState = state
    return addData(ptr, length)
  }
  
  public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    // Note: http_parser itself does all the framing already
    assert(activeFramer == nil, "handleInput reentrancy")
    activeFramer = framer
    defer { activeFramer = nil }
    
    _ = framer.parseInput(minimumIncompleteLength: 1,
                          maximumLength: 1024 * 1024)
    {
      buffer, isComplete in
      
      let bytesConsumed = http_parser_execute(
        parser, &settings,
        buffer?.baseAddress?.assumingMemoryBound(to: Int8.self),
        buffer?.count ?? 0
      )
      
      let errno = http_errno(parser.pointee.http_errno)
      if errno != HPE_OK {
        let error = HTTPProtocol.Error
              .parserError(name: errno.name, description: errno.description)
        
        emit(.init(error: error), to: framer)
        if bytesConsumed < 1 { return buffer?.count ?? 1 } // Hm
      }

      return bytesConsumed
    }
    return 0
  }

  
  // MARK: - Output
  
  public func handleOutput(framer        : NWProtocolFramer.Instance,
                           message       : NWProtocolFramer.Message,
                           messageLength : Int,
                           isComplete    : Bool)
  {
    // We can also support trailers and chunking, but would need to
    // track more output state.
    
    assert(isComplete)
    
    func headerData(with firstLine: String) -> Data {
      var header = firstLine
      message.headers.forEach { ( name, value ) in
        header += name + ": " + value + "\r\n"
      }
      header += "\r\n"
      guard let data = header.data(using: .utf8) else {
        assertionFailure("could not encode header data?")
        return Data()
      }
      return data
    }
    
    if let status = message.status {
      assert(message.method == nil, "message has status AND method?!")
      let reason = http_status(UInt32(status)).reason
      let data = headerData(
        with: "HTTP/1.1 \(status) \(reason)\r\n")
      assert(!data.isEmpty)
      framer.writeOutput(data: data)
    }
    else if let method = message.method {
      assert(message.status == nil, "message has status AND method?!")
      assert(message.path   == nil, "method but no path?")
      let uri = message.path ?? "/"
      let data = headerData(with: "\(method) \(uri) HTTP/1.1\r\n")
      assert(!data.isEmpty)
      framer.writeOutput(data: data)
    }
    
    // body data (the user can also include some in the original message)
    if messageLength > 0 {
      do {
        assert(messageLength > 0)
        try framer.writeOutputNoCopy(length: messageLength)
      }
      catch {
        assertionFailure("write error: \(error)")
        let error = HTTPProtocol.Error.writeFailed(error)
        emit(.init(error: error), to: framer)
      }
    }
  }
}


// MARK: - Helper Extensions

fileprivate extension http_method {
  var stringValue : String { return String(cString: http_method_str(self)) }
}
fileprivate extension http_status {
  var reason : String { return String(cString: http_status_str(self)) }
}
fileprivate extension http_errno {
  var name        : String { return String(cString: http_errno_name(self)) }
  var description : String {
    return String(cString: http_errno_description(self))
  }
}

@available(iOS 13.0, *)
fileprivate extension UnsafeMutablePointer where Pointee == http_parser {
  var framer : HTTPProtocol {
    return unsafeBitCast(pointee.data, to: HTTPProtocol.self)
  }
}
