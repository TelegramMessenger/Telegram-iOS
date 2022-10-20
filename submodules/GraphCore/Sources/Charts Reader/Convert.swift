//
//  Convert.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

public enum Convert {
    public static func doubleFrom(_ value: Any?) throws -> Double {
        guard let double = try doubleFrom(value, lenientCast: false)  else {
            throw ChartsError.generalConversion("Unable to cast \(String(describing: value)) to \(Double.self)")
        }
        return double
    }
    
    public static func doubleFrom(_ value: Any?, lenientCast: Bool = false) throws -> Double? {
        guard let value = value else {
            return nil
        }
        if let intValue = value as? Int {
            return Double(intValue)
        } else if let floatValue = value as? Float {
            return Double(floatValue)
        } else if let int64Value = value as? Int64 {
            return Double(int64Value)
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let stringValue = value as? String {
            if let doubleValue = Double(stringValue) {
                return doubleValue
            }
        }
        if lenientCast {
            return nil
        } else {
            throw ChartsError.generalConversion("Unable to cast \(String(describing: value)) to \(Double.self)")
        }
    }
}
