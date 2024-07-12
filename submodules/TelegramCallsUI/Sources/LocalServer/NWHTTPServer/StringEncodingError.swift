//
//  StringEncodingError.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import Foundation

public struct StringEncodingError : Swift.Error {
  public let encoding : String.Encoding
}
