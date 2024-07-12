//
//  HTTPMethod.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public struct HTTPMethod: RawRepresentable, Hashable {
  
  public let rawValue : String
  
  @inlinable
  public init(rawValue string: String) { rawValue = string  }
}

extension HTTPMethod: CustomStringConvertible {
  @inlinable
  public var description: String { return rawValue }
}

@inlinable
public func ==(lhs: HTTPMethod, rhs: String) -> Bool {
  return lhs.rawValue == rhs
}
@inlinable
public func ==(lhs: String, rhs: HTTPMethod) -> Bool {
  return lhs == rhs.rawValue
}

public extension HTTPMethod {
  static let GET         : HTTPMethod = "GET"
  static let POST        : HTTPMethod = "POST"
  static let MKCALENDAR  : HTTPMethod = "MKCALENDAR"
  static let DELETE      : HTTPMethod = "DELETE"
  static let HEAD        : HTTPMethod = "HEAD"
  static let PUT         : HTTPMethod = "PUT"
  static let CONNECT     : HTTPMethod = "CONNECT"
  static let OPTIONS     : HTTPMethod = "OPTIONS"
  static let TRACE       : HTTPMethod = "TRACE"
  static let COPY        : HTTPMethod = "COPY"
  static let LOCK        : HTTPMethod = "LOCK"
  static let MKCOL       : HTTPMethod = "MKCOL"
  static let MOVE        : HTTPMethod = "MOVE"
  static let PROPFIND    : HTTPMethod = "PROPFIND"
  static let PROPPATCH   : HTTPMethod = "PROPPATCH"
  static let SEARCH      : HTTPMethod = "SEARCH"
  static let UNLOCK      : HTTPMethod = "UNLOCK"
  static let REPORT      : HTTPMethod = "REPORT"
  static let MKACTIVITY  : HTTPMethod = "MKACTIVITY"
  static let CHECKOUT    : HTTPMethod = "CHECKOUT"
  static let MERGE       : HTTPMethod = "MERGE"
  static let MSEARCH     : HTTPMethod = "MSEARCH"
  static let NOTIFY      : HTTPMethod = "NOTIFY"
  static let SUBSCRIBE   : HTTPMethod = "SUBSCRIBE"
  static let UNSUBSCRIBE : HTTPMethod = "UNSUBSCRIBE"
  static let PATCH       : HTTPMethod = "PATCH"
  static let PURGE       : HTTPMethod = "PURGE"
}

extension HTTPMethod: ExpressibleByStringLiteral {
  @inlinable
  public init(stringLiteral string: String) { self.init(rawValue: string) }
}
