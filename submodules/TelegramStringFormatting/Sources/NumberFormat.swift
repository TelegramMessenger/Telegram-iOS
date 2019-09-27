import Foundation

public enum ArabicNumeralStringType {
    case western
    case arabic
    case persian
}

public func normalizeArabicNumeralString(_ string: String, type: ArabicNumeralStringType) -> String {
    var string = string
    
    let numerals = [
        ("0", "٠", "۰"),
        ("1", "١", "۱"),
        ("2", "٢", "۲"),
        ("3", "٣", "۳"),
        ("4", "٤", "۴"),
        ("5", "٥", "۵"),
        ("6", "٦", "۶"),
        ("7", "٧", "۷"),
        ("8", "٨", "۸"),
        ("9", "٩", "۹"),
        (",", "٫", "٫")
    ]
    for (western, arabic, persian) in numerals {
        switch type {
            case .western:
                string = string.replacingOccurrences(of: arabic, with: western)
                string = string.replacingOccurrences(of: persian, with: western)
            case .arabic:
                string = string.replacingOccurrences(of: western, with: arabic)
                string = string.replacingOccurrences(of: persian, with: arabic)
            case .persian:
                string = string.replacingOccurrences(of: western, with: persian)
                string = string.replacingOccurrences(of: arabic, with: persian)
        }
        
    }
    return string
}
