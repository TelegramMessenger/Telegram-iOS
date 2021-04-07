import Foundation

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func dataSizeString(_ size: Int, forceDecimal: Bool = false, formatting: DataSizeStringFormatting) -> String {
    return dataSizeString(Int64(size), forceDecimal: forceDecimal, formatting: formatting)
}

public struct DataSizeStringFormatting {
    let decimalSeparator: String
    let byte: (String) -> (String, [(Int, NSRange)])
    let kilobyte: (String) -> (String, [(Int, NSRange)])
    let megabyte: (String) -> (String, [(Int, NSRange)])
    let gigabyte: (String) -> (String, [(Int, NSRange)])
    
    public init(decimalSeparator: String, byte: @escaping (String) -> (String, [(Int, NSRange)]), kilobyte: @escaping (String) -> (String, [(Int, NSRange)]), megabyte: @escaping (String) -> (String, [(Int, NSRange)]), gigabyte: @escaping (String) -> (String, [(Int, NSRange)])) {
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
            return formatting.gigabyte("\(size / (1024 * 1024 * 1024))\(formatting.decimalSeparator)\(remainder)").0
        } else {
            return formatting.gigabyte("\(size / (1024 * 1024 * 1024))").0
        }
    } else if size >= 1024 * 1024 {
        let remainder = Int64((Double(size % (1024 * 1024)) / (1024.0 * 102.4)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return formatting.megabyte( "\(size / (1024 * 1024))\(formatting.decimalSeparator)\(remainder)").0
        } else {
            return formatting.megabyte("\(size / (1024 * 1024))").0
        }
    } else if size >= 1024 {
        let remainder = (size % (1024)) / (102)
        if remainder != 0 || forceDecimal {
            return formatting.kilobyte("\(size / 1024)\(formatting.decimalSeparator)\(remainder)").0
        } else {
            return formatting.kilobyte("\(size / 1024)").0
        }
    } else {
        return formatting.byte("\(size)").0
    }
}
