//
//  String.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/26/19.
//  Copyright © 2019 Crowdin. All rights reserved.
//

import Foundation

// MARK: - String localization extension.
extension String {
	/// Extension method for simplifying strings localization.
	public var cw_localized: String {
		return NSLocalizedString(self, comment: .empty)
	}
    
    /// Extension method for simplifying strings localization with argumets.
    ///
    /// - Parameter arguments: Formatted string arguments.
    /// - Returns: Localized formatted string.
    public func cw_localized(with arguments: [CVarArg]) -> String {
        return String(format: NSLocalizedString(self, comment: .empty), arguments: arguments)
    }
    
    /// Extension method for simplifying strings localization with argumets.
    /// - Parameter args: Formatted string arguments.
    /// - Returns: Localized formatted string. 
    public func cw_localized(with args: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: .empty), args)
    }
}

// MARK: - Formatting detection.
extension String {
    /// Detect whether current string is formated.
	var isFormated: Bool {
		return formatTypesRegEx.matches(in: self, options: [], range: NSRange(location: 0, length: self.count)).count > 0
	}
}

// MARK: - Static strings.
extension String {
    static let dot = "."
    static let empty = ""
    static let space = " "
    static let enter = "\n"
    static let pathDelimiter = "/"
    static let minus = "-"
}

// MARK: - Match finding.
extension String {
    /// Detect whether formated string mached to a given string.
    /// Additional explentaion:
    /// For example if we want to check whether formated string "my %@ value" is matchin to string "my awesome value". The result will be true as all strings parts from formated string("my ", " value") are included in string "my awesome value".
    ///
    /// - Parameters:
    ///   - formatedString: Formated string.
    ///   - string: String to check match.
    /// - Returns: Bool value which indicates whether given string metches with formated string.
    static func findMatch(for formatedString: String, with string: String) -> Bool {
        // Check is it equal:
        if formatedString == string { return true }
        // If not try to parse localized string as formated:
        let matches = formatTypesRegEx.matches(in: formatedString, options: [], range: NSRange(location: 0, length: formatedString.count))
        // If it is not formated string return false.
        guard matches.count > 0 else { return false }
        let ranges = matches.compactMap({ $0.range })
        let nsStringValue = formatedString as NSString
        let components = nsStringValue.splitBy(ranges: ranges)
        for component in components {
            if !string.contains(component) {
                return false
            }
        }
        return true
    }
}

// MARK: - NSString splitting.
extension NSString {
    /// Spit current string by a given ranges.
    /// Additional explenation:
    /// For example we have string "Awesome string" and we want to split it by range (7,1). Result arrayy will be: ["Awesome", "string"]
    ///
    /// - Parameter ranges: Array of renges to split by.
    /// - Returns: Array of substrings
    func splitBy(ranges: [NSRange]) -> [String] {
        var values = [String]()
        for index in 0...ranges.count - 1 {
            let range = ranges[index]
            guard range.location != NSNotFound else { continue }
            if index == 0 {
                if range.location != 0 {
                    guard self.isValid(range: range) else { continue }
                    values.append(self.substring(with: NSRange(location: 0, length: range.location)))
                }
            } else {
                let previousRange = ranges[index - 1]
                let location = previousRange.location + previousRange.length
                let substringRange = NSRange(location: location, length: range.location - location)
                guard self.isValid(range: substringRange) else { continue }
                values.append(self.substring(with: substringRange))
            }
            if index == ranges.count - 1 {
                if range.location + range.length == self.length { continue }
                let location = range.location + range.length
                let substringRange = NSRange(location: location, length: self.length - location)
                guard self.isValid(range: substringRange) else { continue }
                values.append(self.substring(with: substringRange))
            }
        }
        return values
    }
    
    /// Detect whether given range is valid and is it avalaible to use for current string.
    ///
    /// - Parameter range: NSRange value for checking.
    /// - Returns: Bool value which indicates whether passed range is valid for current string.
    private func isValid(range: NSRange) -> Bool {
        return range.location != NSNotFound && range.location + range.length <= length && range.length > 0
    }
}

// MARK: - Values finding.
extension String {
    /// Method for values detection passed for localization string creation for given string and format string.
    /// Additional explenation:
    /// For example, we have a string "String with string parameter - test, and an integer parameter - 2". The format string is "String with string parameter - %@, and integer parameter - %llu". Result of this method will be an array of two objects - ["test", 2].
    ///
    /// - Parameters:
    ///   - string: String for searching values.
    ///   - format: Format string.
    /// - Returns: An array of detected values in a given string with a given format. If passed format doesn't match with string nil will be returned.
    static func findValues(for string: String, with format: String) -> [Any]? {
        let parts = FormatPart.formatParts(formatString: format)
        let matches = formatTypesRegEx.matches(in: format, options: [], range: NSRange(location: 0, length: format.count))
        guard matches.count > 0 else { return nil }
        let ranges = matches.compactMap({ $0.range })
        let nsStringValue = format as NSString
        let components = nsStringValue.splitBy(ranges: ranges)
        
        let nsStringText = string as NSString
        
        var valueRanges = [NSRange]()
        components.forEach({ valueRanges.append(nsStringText.range(of: $0)) })
        
        guard valueRanges.count > 0 else { return nil }
        
        let values = nsStringText.splitBy(ranges: valueRanges)
        
        guard values.count == parts.count else { return nil }
        
        var result = [Any]()
        
        for index in 0...parts.count - 1 {
            let part = parts[index]
            let value = values[index]
            guard let formatSpecifier = part.formatSpecifier else {
                result.append(value)
                continue
            }
            var formatValue: Any?
            switch formatSpecifier {
            case .object: formatValue = value
            case .double: formatValue = Double(value)
            case .int: formatValue = Int(value)
            case .uInt: formatValue = UInt(value)
            case .character: formatValue = Character(value)
            case .cStringPointer: formatValue = value
            case .voidPointer: formatValue = value
            case .topType: formatValue = value
            }
            guard let nonNilFormatValue = formatValue else { return nil }
            result.append(nonNilFormatValue)
        }
        
        return result
    }
}
