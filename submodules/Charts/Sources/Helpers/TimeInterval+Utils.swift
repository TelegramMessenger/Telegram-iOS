//
//  TimeInterval+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation

extension TimeInterval {
    static let minute: TimeInterval = 60
    static let hour: TimeInterval = 60 * 60
    static let day: TimeInterval = 60 * 60 * 24
    static let osXDuration: TimeInterval = 0.25
    static let expandAnimationDuration: TimeInterval = 0.4
    static var animationDurationMultipler: Double = 1.0

    static var defaultDuration: TimeInterval {
        return innerDefaultDuration * animationDurationMultipler
    }
    private static var innerDefaultDuration: TimeInterval = osXDuration
    
    static func setDefaultSuration(_ duration: TimeInterval) {
        innerDefaultDuration = duration
    }
}
