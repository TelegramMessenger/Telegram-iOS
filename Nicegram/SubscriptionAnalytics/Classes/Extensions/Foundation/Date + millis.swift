//
//  Date + millis.swift
//  Translator
//
//  Created by Vadim Suhodolskiy on 7/10/20.
//  Copyright © 2020 Boris Lysenko. All rights reserved.
//

import Foundation

extension Date {
    init(millis: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(millis / 1000))
        self.addTimeInterval(TimeInterval(Double(millis % 1000) / 1000))
    }
}
