//
//  TimeZone.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/9/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}

extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}

extension Calendar {
    static let utc: Calendar = {
        var calendar = Calendar.current
        calendar.locale = Locale.posix
        calendar.timeZone = TimeZone.utc
        return calendar
    }()
}

extension DateFormatter {
    static func utc(format: String = "") -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.utc
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.utc
        return formatter
    }
}
