//
//  HTTPStatus.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//


public struct HTTPStatus: RawRepresentable, Hashable {
  public let rawValue : Int
  public init(rawValue status: Int) { self.rawValue     = status  }
}

extension HTTPStatus {
  public init(_ status: Int) { self.init(rawValue: status) }
}

extension HTTPStatus: ExpressibleByIntegerLiteral {
  public init(integerLiteral status: Int) { self.init(rawValue: status) }
}

public extension HTTPStatus {
  
  static let ok              : HTTPStatus = 200
  static let created         : HTTPStatus = 201
  static let noContent       : HTTPStatus = 204
  
  static let badRequest      : HTTPStatus = 400
  static let paymentRequired : HTTPStatus = 402
  static let forbidden       : HTTPStatus = 403
  static let notFound        : HTTPStatus = 404
  
  static let serverError     : HTTPStatus = 500
}
