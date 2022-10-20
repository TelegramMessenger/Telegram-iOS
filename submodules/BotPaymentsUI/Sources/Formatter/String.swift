//
//  String.swift
//  CurrencyText
//
//  Created by Felipe Lefèvre Marino on 4/3/18.
//  Copyright © 2018 Felipe Lefèvre Marino. All rights reserved.
//

import Foundation

public protocol CurrencyString {
    var representsZero: Bool { get }
    var hasNumbers: Bool { get }
    var lastNumberOffsetFromEnd: Int? { get }
    func numeralFormat() -> String
    mutating func updateDecimalSeparator(decimalDigits: Int)
}

//Currency String Extension
extension String: CurrencyString {

    // MARK: Properties
    
    /// Informs with the string represents the value of zero
    public var representsZero: Bool {
        return numeralFormat().replacingOccurrences(of: "0", with: "").count == 0
    }
    
    /// Returns if the string does have any character that represents numbers
    public var hasNumbers: Bool {
        return numeralFormat().count > 0
    }

    /// The offset from end index to the index _right after_ the last number in the String.
    /// e.g. For the String "123some", the last number position is 4, because from the _end index_ to the index of _3_
    /// there is an offset of 4, "e, m, o and s".
    public var lastNumberOffsetFromEnd: Int? {
        guard let indexOfLastNumber = lastIndex(where: { $0.isNumber }) else { return nil }
        let indexAfterLastNumber = index(after: indexOfLastNumber)
        return distance(from: endIndex, to: indexAfterLastNumber)
    }

    // MARK: Functions
    
    /// Updates a currency string decimal separator position based on
    /// the amount of decimal digits desired
    ///
    /// - Parameter decimalDigits: The amount of decimal digits of the currency formatted string
    public mutating func updateDecimalSeparator(decimalDigits: Int) {
        guard decimalDigits != 0 && count >= decimalDigits else { return }
        let decimalsRange = index(endIndex, offsetBy: -decimalDigits)..<endIndex
        
        let decimalChars = self[decimalsRange]
        replaceSubrange(decimalsRange, with: "." + decimalChars)
    }
    
    /// The numeral format of a string - remove all non numerical ocurrences
    ///
    /// - Returns: itself without the non numerical characters ocurrences
    public func numeralFormat() -> String {
        return replacingOccurrences(of:"[^0-9]", with: "", options: .regularExpression)
    }
}

// MARK: - Static constants

extension String {
    public static let negativeSymbol = "-"
}
