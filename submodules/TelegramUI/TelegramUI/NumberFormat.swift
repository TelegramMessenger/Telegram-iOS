import Foundation

func convertToArabicNumeralString(_ string: String) -> String {
    var string = string
    let arabicNumbers = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"]
    for (arabic, generic) in arabicNumbers {
        string = string.replacingOccurrences(of: generic, with: arabic)
    }
    return string
}
