import Foundation
import AppBundle
import PresentationStrings

public typealias PresentationStrings = _PresentationStrings

public extension PresentationStrings {
    typealias FormattedString = _FormattedString
    typealias Component = _PresentationStringsComponent
}

public extension _FormattedString {
    typealias Range = _FormattedStringRange

    var _tuple: (String, [(Int, NSRange)]) {
        return (self.string, self.ranges.map { item -> (Int, NSRange) in
            return (item.index, item.range)
        })
    }
}

public func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString

    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}

public let defaultPresentationStrings = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: "en", localizedName: "English", pluralizationRulesCode: nil, dict: NSDictionary(contentsOf: URL(fileURLWithPath: getAppBundle().path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en")!)) as! [String : String]), secondaryComponent: nil, groupingSeparator: "")

public func dataSizeString(_ size: Int, forceDecimal: Bool = false, formatting: DataSizeStringFormatting) -> String {
    return dataSizeString(Int64(size), forceDecimal: forceDecimal, formatting: formatting)
}

public struct DataSizeStringFormatting {
    let decimalSeparator: String
    let byte: (String) -> PresentationStrings.FormattedString
    let kilobyte: (String) -> PresentationStrings.FormattedString
    let megabyte: (String) -> PresentationStrings.FormattedString
    let gigabyte: (String) -> PresentationStrings.FormattedString

    public init(
        decimalSeparator: String,
        byte: @escaping (String) -> PresentationStrings.FormattedString,
        kilobyte: @escaping (String) -> PresentationStrings.FormattedString,
        megabyte: @escaping (String) -> PresentationStrings.FormattedString,
        gigabyte: @escaping (String) -> PresentationStrings.FormattedString
    ) {
        self.decimalSeparator = decimalSeparator
        self.byte = byte
        self.kilobyte = kilobyte
        self.megabyte = megabyte
        self.gigabyte = gigabyte
    }
}

public func dataSizeString(_ size: Int64, forceDecimal: Bool = false, formatting: DataSizeStringFormatting) -> String {
    if size >= 1024 * 1024 * 1024 {
        let remainder = Int64((Double(size % (1024 * 1024 * 1024)) / (1024 * 1024 * 102.4)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return formatting.gigabyte("\(size / (1024 * 1024 * 1024))\(formatting.decimalSeparator)\(remainder)").string
        } else {
            return formatting.gigabyte("\(size / (1024 * 1024 * 1024))").string
        }
    } else if size >= 1024 * 1024 {
        let remainder = Int64((Double(size % (1024 * 1024)) / (1024.0 * 102.4)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return formatting.megabyte( "\(size / (1024 * 1024))\(formatting.decimalSeparator)\(remainder)").string
        } else {
            return formatting.megabyte("\(size / (1024 * 1024))").string
        }
    } else if size >= 1024 {
        let remainder = (size % (1024)) / (102)
        if remainder != 0 || forceDecimal {
            return formatting.kilobyte("\(size / 1024)\(formatting.decimalSeparator)\(remainder)").string
        } else {
            return formatting.kilobyte("\(size / 1024)").string
        }
    } else {
        return formatting.byte("\(size)").string
    }
}

public func countString(_ count: Int64, forceDecimal: Bool = false) -> String {
    let decimalSeparator = "."
    if count >= 1000 * 1000 * 1000 {
        let remainder = Int64((Double(count % (1000 * 1000 * 1000)) / (1000 * 1000 * 100.0)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return "\(count / (1000 * 1000 * 1000))\(decimalSeparator)\(remainder)T"
        } else {
            return "\(count / (1000 * 1000 * 1000))T"
        }
    } else if count >= 1000 * 1000 {
        let remainder = Int64((Double(count % (1000 * 1000)) / (1000.0 * 100.0)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return "\(count / (1000 * 1000))\(decimalSeparator)\(remainder)M"
        } else {
            return "\(count / (1000 * 1000))M"
        }
    } else if count >= 1000 {
        let remainder = (count % (1000)) / (102)
        if remainder != 0 || forceDecimal {
            return "\(count / 1000)\(decimalSeparator)\(remainder)K"
        } else {
            return "\(count / 1000)K"
        }
    } else {
        return "\(count)"
    }
}
