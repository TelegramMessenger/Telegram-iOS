import Foundation
import CoreText
import AVFoundation

extension Character {
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        if #available(iOS 10.2, *) {
            return (firstScalar.properties.isEmoji && firstScalar.value > 0x238C) || firstScalar.isEmoji
        } else {
            return firstScalar.isEmoji
        }
    }

    var isCombinedIntoEmoji: Bool {
        if #available(iOS 10.2, *) {
            return self.unicodeScalars.count > 1 && self.unicodeScalars.first?.properties.isEmoji ?? false
        } else {
            return self.unicodeScalars.count > 1 && self.unicodeScalars.first?.isEmoji ?? false
        }
    }

    var isEmoji: Bool {
        return self.isSimpleEmoji || self.isCombinedIntoEmoji
    }
}

public extension UnicodeScalar {
    var isEmoji: Bool {
        switch self.value {
            case 0x1F600...0x1F64F, 0x1F300...0x1F5FF, 0x1F680...0x1F6FF, 0x1F1E6...0x1F1FF, 0xE0020...0xE007F, 0xFE00...0xFE0F, 0x1F900...0x1F9FF, 0x1F018...0x1F0F5, 0x1F200...0x1F270, 65024...65039, 9100...9300, 8400...8447, 0x1F004, 0x1F18E, 0x1F191...0x1F19A, 0x1F5E8, 0x1FA70...0x1FA73, 0x1FA78...0x1FA7A, 0x1FA80...0x1FA82, 0x1FA90...0x1FA95, 0x1FAE0, 0x1FAF0...0x1FAF6, 0x1F382:
                return true
            case 0x2603, 0x265F, 0x267E, 0x2692, 0x26C4, 0x26C8, 0x26CE, 0x26CF, 0x26D1...0x26D3, 0x26E9, 0x26F0...0x26F9, 0x2705, 0x270A, 0x270B, 0x2728, 0x274E, 0x2753...0x2755, 0x274C, 0x2795...0x2797, 0x27B0, 0x27BF:
                return true
            default:
                return false
        }
    }
    
    var maybeEmoji: Bool {
        switch self.value {
            case 0x2A, 0x23, 0x30...0x39, 0xA9, 0xAE:
                return true
            case 0x2600...0x26FF, 0x2700...0x27BF, 0x1F100...0x1F1FF:
                return true
            case 0x203C, 0x2049, 0x2122, 0x2194...0x2199, 0x21A9, 0x21AA, 0x2139, 0x2328, 0x231A, 0x231B, 0x24C2, 0x25AA, 0x25AB, 0x25B6, 0x25FB...0x25FE, 0x25C0, 0x2934, 0x2935, 0x2B05...0x2B07, 0x2B1B...0x2B1E, 0x2B50, 0x2B55, 0x3030, 0x3297, 0x3299:
                return true
            default:
                return false
        }
    }
    
    static var ZeroWidthJoiner = UnicodeScalar(0x200D)!
    static var VariationSelector = UnicodeScalar(0xFE0F)!
}

private final class FrameworkClass: NSObject {
}

public extension String {
    func trimmingTrailingSpaces() -> String {
        var t = self
        while t.hasSuffix(" ") {
            t = "" + t.dropLast()
        }
        return t
    }
    
    var isSingleEmoji: Bool {
        return self.count == 1 && self.containsEmoji
//        return self.emojis.count == 1 && self.containsEmoji
    }
    
    var containsEmoji: Bool {
        return self.contains { $0.isEmoji }
        //return self.unicodeScalars.contains { $0.isEmoji }
    }
    
    var containsOnlyEmoji: Bool {
        return !self.isEmpty && !self.contains { !$0.isEmoji }
//        guard !self.isEmpty else {
//            return false
//        }
//        var nextShouldBeVariationSelector = false
//        for scalar in self.unicodeScalars {
//            if nextShouldBeVariationSelector {
//                if scalar == UnicodeScalar.VariationSelector {
//                    nextShouldBeVariationSelector = false
//                    continue
//                } else {
//                    return false
//                }
//            }
//            if !scalar.isEmoji && scalar.maybeEmoji {
//                nextShouldBeVariationSelector = true
//            }
//            else if !scalar.isEmoji && scalar != UnicodeScalar.ZeroWidthJoiner {
//                return false
//            }
//        }
//        return !nextShouldBeVariationSelector
    }
    
    var emojis: [String] {
        var emojis: [String] = []
        self.enumerateSubstrings(in: self.startIndex ..< self.endIndex, options: .byComposedCharacterSequences) { substring, _, _, _ in
            if let substring = substring {
                emojis.append(substring)
            }
        }
        return emojis
    }
    
    var trimmingEmojis: String {
        var string: String = ""
        self.enumerateSubstrings(in: self.startIndex ..< self.endIndex, options: .byComposedCharacterSequences) { substring, _, _, _ in
            if let substring = substring, !substring.containsEmoji {
                string.append(substring)
            }
        }
        return string
    }
    
    var normalizedEmoji: String {
        var string = ""
        
        var nextShouldBeVariationSelector = false
        for scalar in self.unicodeScalars {
            if nextShouldBeVariationSelector {
                if scalar != UnicodeScalar.VariationSelector {
                    string.unicodeScalars.append(UnicodeScalar.VariationSelector)
                }
                nextShouldBeVariationSelector = false
            }
            string.unicodeScalars.append(scalar)
            if !scalar.isEmoji && scalar.maybeEmoji {
                nextShouldBeVariationSelector = true
            }
        }
        
        if nextShouldBeVariationSelector {
            string.unicodeScalars.append(UnicodeScalar.VariationSelector)
        }
        
        return string
    }
    
    var basicEmoji: (String, String?) {
        let fitzCodes: [UInt32] = [
            0x1f3fb,
            0x1f3fc,
            0x1f3fd,
            0x1f3fe,
            0x1f3ff
        ]
        
        var string = ""
        var fitzModifier: String?
        for scalar in self.unicodeScalars {
            if fitzCodes.contains(scalar.value) {
                fitzModifier = String(scalar)
                continue
            }
            string.unicodeScalars.append(scalar)
            if scalar.value == 0x2764 && self.unicodeScalars.count < 3 {
                break
            }
        }
        return (string, fitzModifier)
    }
    
    var strippedEmoji: String {
        var string = ""
        for scalar in self.unicodeScalars {
            if scalar.value != 0xfe0f {
                string.unicodeScalars.append(scalar)
            }
        }
        return string
    }
}
