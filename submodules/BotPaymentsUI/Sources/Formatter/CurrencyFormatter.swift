//
//  CurrencyFormatter.swift
//  CurrencyText
//
//  Created by Felipe Lefèvre Marino on 1/27/19.
//

import Foundation

import TelegramStringFormatting

// MARK: - Currency protocols

public protocol CurrencyFormatting {
    var maxDigitsCount: Int { get }
    var decimalDigits: Int { get set }
    var maxValue: Double? { get set }
    var minValue: Double? { get set }
    var initialText: String { get }
    var currencySymbol: String { get set }
    
    func string(from double: Double) -> String?
    func unformatted(string: String) -> String?
    func double(from string: String) -> Double?
}

public protocol CurrencyAdjusting {
    func formattedStringWithAdjustedDecimalSeparator(from string: String) -> String?
    func formattedStringAdjustedToFitAllowedValues(from string: String) -> String?
}

// MARK: - Currency formatter

public class CurrencyFormatter: CurrencyFormatting {
    
    /// Set the locale to retrieve the currency from
    /// You can pass a Swift type Locale or one of the
    /// Locales enum options - that encapsulates all available locales.
    public var locale: LocaleConvertible {
        set { self.numberFormatter.locale = newValue.locale }
        get { self.numberFormatter.locale }
    }
    
    /// Set the desired currency type
    /// * Note: The currency take effetcs above the displayed currency symbol,
    /// however details such as decimal separators, grouping separators and others
    /// will be set based on the defined locale. So for a precise experience, please
    /// preferarbly setup both, when you are setting a currency that does not match the
    /// default/current user locale.
    public var currency: Currency {
        set { numberFormatter.currencyCode = newValue.rawValue }
        get { Currency(rawValue: numberFormatter.currencyCode) ?? .dollar }
    }
    
    /// Define if currency symbol should be presented or not.
    /// Note: when set to false the current currency symbol is removed
    public var showCurrencySymbol: Bool = true {
        didSet {
            numberFormatter.currencySymbol = showCurrencySymbol ? numberFormatter.currencySymbol : ""
        }
    }
    
    /// The currency's symbol.
    /// Can be used to read or set a custom symbol.
    /// Note: showCurrencySymbol must be set to true for
    /// the currencySymbol to be correctly changed.
    public var currencySymbol: String {
        set {
            guard showCurrencySymbol else { return }
            numberFormatter.currencySymbol = newValue
        }
        get { numberFormatter.currencySymbol }
    }
    
    /// The lowest number allowed as input.
    /// This value is initially set to the text field text
    /// when defined.
    public var minValue: Double? {
        set {
            guard let newValue = newValue else { return }
            numberFormatter.minimum = NSNumber(value: newValue)
        }
        get {
            if let minValue = numberFormatter.minimum {
                return Double(truncating: minValue)
            }
            return nil
        }
    }
    
    /// The highest number allowed as input.
    /// The text field will not allow the user to increase the input
    /// value beyond it, when defined.
    public var maxValue: Double? {
        set {
            guard let newValue = newValue else { return }
            numberFormatter.maximum = NSNumber(value: newValue)
        }
        get {
            if let maxValue = numberFormatter.maximum {
                return Double(truncating: maxValue)
            }
            return nil
        }
    }
    
    /// The number of decimal digits shown.
    /// default is set to zero.
    /// * Example: With decimal digits set to 3, if the value to represent is "1",
    /// the formatted text in the fractions will be ",001".
    /// Other than that with the value as 1, the formatted text fractions will be ",1".
    public var decimalDigits: Int {
        set {
            numberFormatter.minimumFractionDigits = newValue
            numberFormatter.maximumFractionDigits = newValue
        }
        get { numberFormatter.minimumFractionDigits }
    }
    
    /// Set decimal numbers behavior.
    /// When set to true decimalDigits are automatically set to 2 (most currencies pattern),
    /// and the decimal separator is presented. Otherwise decimal digits are not shown and
    /// the separator gets hidden as well
    /// When reading it returns the current pattern based on the setup.
    /// Note: Setting decimal digits after, or alwaysShowsDecimalSeparator can overlap this definitios,
    /// and should be only done if you need specific cases
    public var hasDecimals: Bool {
        set {
            self.decimalDigits = newValue ? 2 : 0
            self.numberFormatter.alwaysShowsDecimalSeparator = newValue ? true : false
        }
        get { decimalDigits != 0 }
    }
    
    /// Defines the string that is the decimal separator
    /// Note: only presented when hasDecimals is true OR decimalDigits
    /// is greater than 0.
    public var decimalSeparator: String {
        set { self.numberFormatter.currencyDecimalSeparator = newValue }
        get { numberFormatter.currencyDecimalSeparator }
    }
    
    /// Can be used to set a custom currency code string
    public var currencyCode: String {
        set { self.numberFormatter.currencyCode = newValue }
        get { numberFormatter.currencyCode }
    }
    
    /// Sets if decimal separator should always be presented,
    /// even when decimal digits are disabled
    public var alwaysShowsDecimalSeparator: Bool {
        set { self.numberFormatter.alwaysShowsDecimalSeparator = newValue }
        get { numberFormatter.alwaysShowsDecimalSeparator }
    }
    
    /// The amount of grouped numbers. This definition is fixed for at least
    /// the first non-decimal group of numbers, and is applied to all other
    /// groups if secondaryGroupingSize does not have another value.
    public var groupingSize: Int {
        set { self.numberFormatter.groupingSize = newValue }
        get { numberFormatter.groupingSize }
    }
    
    /// The amount of grouped numbers after the first group.
    /// Example: for the given value of 99999999999, when grouping size
    /// is set to 3 and secondaryGroupingSize has 4 as value,
    /// the number is represented as: (9999) (9999) [999].
    /// Beign [] grouping size and () secondary grouping size.
    public var secondaryGroupingSize: Int {
        set { self.numberFormatter.secondaryGroupingSize = newValue }
        get { numberFormatter.secondaryGroupingSize }
    }
    
    /// Defines the string that is shown between groups of numbers
    /// * Example: a monetary value of a thousand (1000) with a grouping
    /// separator == "." is represented as `1.000` *.
    /// Note: It automatically sets hasGroupingSeparator to true.
    public var groupingSeparator: String {
        set {
            self.numberFormatter.currencyGroupingSeparator = newValue
            self.numberFormatter.usesGroupingSeparator = true
        }
        get { self.numberFormatter.currencyGroupingSeparator }
    }
    
    /// Sets if has separator between all group of numbers.
    /// * Example: when set to false, a bug number such as a million
    /// is represented by tight numbers "1000000". Otherwise if set
    /// to true each group is separated by the defined `groupingSeparator`. *
    /// Note: When set to true only works by defining a grouping separator.
    public var hasGroupingSeparator: Bool {
        set { self.numberFormatter.usesGroupingSeparator = newValue }
        get { self.numberFormatter.usesGroupingSeparator }
    }
    
    /// Value that will be presented when the text field
    /// text values matches zero (0)
    public var zeroSymbol: String? {
        set { numberFormatter.zeroSymbol = newValue }
        get { numberFormatter.zeroSymbol }
    }
    
    /// Value that will be presented when the text field
    /// is empty. The default is "" - empty string
    public var nilSymbol: String {
        set { numberFormatter.nilSymbol = newValue }
        get { return numberFormatter.nilSymbol }
    }
    
    /// Encapsulated Number formatter
    let numberFormatter: NumberFormatter
    
    /// Maximum allowed number of integers
    public var maxIntegers: Int? {
        set {
            guard let maxIntegers = newValue else { return }
            numberFormatter.maximumIntegerDigits = maxIntegers
        }
        get { return numberFormatter.maximumIntegerDigits }
    }
    
    /// Returns the maximum allowed number of numerical characters
    public var maxDigitsCount: Int {
        numberFormatter.maximumIntegerDigits + numberFormatter.maximumFractionDigits
    }
    
    /// The value zero formatted to serve as initial text.
    public var initialText: String {
        numberFormatter.string(from: 0) ?? "0.0"
    }
    
    //MARK: - INIT
    
    /// Handler to initialize a new style.
    public typealias InitHandler = ((CurrencyFormatter) -> (Void))
    
    /// Initialize a new currency formatter with optional configuration handler callback.
    ///
    /// - Parameter handler: configuration handler callback.

    public init(currency: String, _ handler: InitHandler? = nil) {
        numberFormatter = setupCurrencyNumberFormatter(currency: currency)

        numberFormatter.alwaysShowsDecimalSeparator = false
        /*numberFormatter.numberStyle = .currency
        
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumIntegerDigits = 1*/
        
        handler?(self)
    }
}

// MARK: Format
extension CurrencyFormatter {
    
    /// Returns a currency string from a given double value.
    ///
    /// - Parameter double: the monetary amount.
    /// - Returns: formatted currency string.
    public func string(from double: Double) -> String? {
        let validValue = valueAdjustedToFitAllowedValues(from: double)
        return numberFormatter.string(from: validValue)
    }
    
    /// Returns a double from a string that represents a numerical value.
    ///
    /// - Parameter string: string that describes the numerical value.
    /// - Returns: the value as a Double.
    public func double(from string: String) -> Double? {
        Double(string)
    }
    
    /// Receives a currency formatted string and returns its
    /// numerical/unformatted representation.
    ///
    /// - Parameter string: currency formatted string
    /// - Returns: numerical representation
    public func unformatted(string: String) -> String? {
        string.numeralFormat()
    }
}

// MARK: - Currency adjusting conformance

extension CurrencyFormatter: CurrencyAdjusting {

    /// Receives a currency formatted String, and returns it with its decimal separator adjusted.
    ///
    /// _Note_: Useful when appending values to a currency formatted String.
    /// E.g. "$ 23.24" after users taps an additional number, is equal = "$ 23.247".
    /// Which gets updated to "$ 232.47".
    ///
    /// - Parameter string: The currency formatted String
    /// - Returns: The currency formatted received String with its decimal separator adjusted
    public func formattedStringWithAdjustedDecimalSeparator(from string: String) -> String? {
        let adjustedString = numeralStringWithAdjustedDecimalSeparator(from: string)
        guard let value = double(from: adjustedString) else { return nil }

        return self.numberFormatter.string(from: value)
    }

    /// Receives a currency formatted String, and returns it to fit the formatter's min and max values, when needed.
    ///
    /// - Parameter string: The currency formatted String
    /// - Returns: The currency formatted String, or the formatted version of its closes allowed value, min or max, depending on the closest boundary.
    public func formattedStringAdjustedToFitAllowedValues(from string: String) -> String? {
        let adjustedString = numeralStringWithAdjustedDecimalSeparator(from: string)
        guard let originalValue = double(from: adjustedString) else { return nil }

        return self.string(from: originalValue)
    }

    /// Receives a currency formatted String, and returns a numeral version of it with its decimal separator adjusted.
    ///
    /// E.g. "$ 23.24", after users taps an additional number, get equal as "$ 23.247". The returned value would be "232.47".
    ///
    /// - Parameter string: The currency formatted String
    /// - Returns: The received String with numeral format and with its decimal separator adjusted
    private func numeralStringWithAdjustedDecimalSeparator(from string: String) -> String {
        var updatedString = string.numeralFormat()
        let isNegative: Bool = string.contains(String.negativeSymbol)

        updatedString = isNegative ? .negativeSymbol + updatedString : updatedString
        updatedString.updateDecimalSeparator(decimalDigits: decimalDigits)

        return updatedString
    }

    /// Receives a Double value, and returns it adjusted to fit min and max allowed values, when needed.
    /// If the value respect number formatter's min and max, it will be returned without changes.
    ///
    /// - Parameter value: The value to be adjusted if needed
    /// - Returns: The value updated or not, depending on the formatter's settings
    private func valueAdjustedToFitAllowedValues(from value: Double) -> Double {
        if let minValue = minValue, value < minValue {
            return minValue
        } else if let maxValue = maxValue, value > maxValue {
            return maxValue
        }

        return value
    }
}
