import Foundation

public enum ArabicNumeralStringType {
    case western
    case eastern
}

public func normalizeArabicNumeralString(_ string: String, type: ArabicNumeralStringType) -> String {
    var string = string
    let numerals = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"]
    for (easternNumeral, westernNumeral) in numerals {
        switch type {
            case .western:
                string = string.replacingOccurrences(of: easternNumeral, with: westernNumeral)
            case .eastern:
                string = string.replacingOccurrences(of: westernNumeral, with: easternNumeral)
        }
        
    }
    return string
}
