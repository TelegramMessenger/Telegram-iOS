//
//  MobyAnalyticsLogger.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/13/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

public protocol MobyAnalyticsLoggerProtocol {
    func logAdvertiseAccountLoaded(_ advertiseAccount: AnalyticsAdvertiseAccount)
    func logError(apiPath: String, error: Error)
    func logAttributionDetails(_ attributionDetails: [String: AnyObject])
}

public extension MobyAnalyticsLoggerProtocol {
    func logAttributionDetails(_ attributionDetails: [String: AnyObject]) {}
}
