//
//  ScalesNumberFormatter.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

private let milionsScale = "M"
private let thousandsScale = "K"

class ScalesNumberFormatter: NumberFormatter, @unchecked Sendable {
    override func string(from number: NSNumber) -> String? {
        let value = number.doubleValue
        let pow = log10(value)
        if pow >= 6 {
            guard let string = super.string(from: NSNumber(value: value / 1_000_000)) else {
                return nil
            }
            return string + milionsScale
        } else if pow >= 4 {
            guard let string = super.string(from: NSNumber(value: value / 1_000)) else {
                return nil
            }
            return string + thousandsScale
        } else {
            return super.string(from: number)
        }
    }
}

class TonNumberFormatter: NumberFormatter, @unchecked Sendable {
    override func string(from number: NSNumber) -> String? {
        var balanceText = "\(number.intValue)"
        let decimalSeparator = self.decimalSeparator ?? "."
        while balanceText.count < 10 {
            balanceText.insert("0", at: balanceText.startIndex)
        }
        balanceText.insert(contentsOf: decimalSeparator, at: balanceText.index(balanceText.endIndex, offsetBy: -9))
        while true {
            if balanceText.hasSuffix("0") {
                if balanceText.hasSuffix("\(decimalSeparator)0") {
                    balanceText.removeLast()
                    balanceText.removeLast()
                    break
                } else {
                    balanceText.removeLast()
                }
            } else {
                break
            }
        }
        return balanceText
    }
}


