//
//  MobyValidationError.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/9/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

public enum MobyValidationError: Error {
    case noRecieptData
    case network(_ underlyingError: Error)
    case localValidation(_ underlyingError: Error)
    case invalidResponseData
    case invalidRequestBody
    case invalidAPIKey
    case noProduct
    case unknown
}
