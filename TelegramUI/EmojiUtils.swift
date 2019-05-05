import Foundation
import CoreText

extension UnicodeScalar {
    var isEmoji: Bool {
        switch self.value {
            case 0x1F600...0x1F64F, // Emoticons
                 0x1F300...0x1F5FF, // Misc Symbols and Pictographs
                 0x1F680...0x1F6FF, // Transport and Map
                 0x1F1E6...0x1F1FF, // Regional country flags
                 0xE0020...0xE007F, // Tags
                 0xFE00...0xFE0F, // Variation Selectors
                 0x1F900...0x1F9FF, // Supplemental Symbols and Pictographs
                 127000...127600, // Various asian characters
                 65024...65039, // Variation selector
                 9100...9300, // Misc items
                 8400...8447: // Combining Diacritical Marks for Symbols
                return true
            default:
                return false
        }
    }
    
    var maybeEmoji: Bool {
        switch self.value {
            case 0x2600...0x26FF, // Misc symbols
                 0x2700...0x27BF: // Dingbats
                return true
            default:
                return false
        }
    }
    
    var isZeroWidthJoiner: Bool {
        return self.value == 8205
    }
}

extension String {
    func trimmingTrailingSpaces() -> String {
        var t = self
        while t.hasSuffix(" ") {
            t = "" + t.dropLast()
        }
        return t
    }
    
    var isSingleEmoji: Bool {
        return self.emojis.count == 1 && self.containsEmoji
    }
    
    var containsEmoji: Bool {
        return self.unicodeScalars.contains { $0.isEmoji }
    }
    
    var containsOnlyEmoji: Bool {
        guard !self.isEmpty else {
            return false
        }
        var nextShouldBeFE0F = false
        for scalar in self.unicodeScalars {
            if nextShouldBeFE0F {
                if scalar.value == 0xfe0f {
                    nextShouldBeFE0F = false
                    continue
                } else {
                    return false
                }
            }
            if scalar.maybeEmoji {
                nextShouldBeFE0F = true
            }
            else if !scalar.isEmoji && !scalar.isZeroWidthJoiner {
                return false
            }
        }
        return !nextShouldBeFE0F
    }
    
    var emojiString: String {
        return self.emojiScalars.map { String($0) }.reduce("", +)
    }
    
    var firstEmoji: String {
        if let first = self.emojiScalars.first {
            return String(first)
        } else {
            return ""
        }
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
    
    fileprivate var emojiScalars: [UnicodeScalar] {
        var chars: [UnicodeScalar] = []
        var previous: UnicodeScalar?
        for cur in self.unicodeScalars {
            if let previous = previous, previous.isZeroWidthJoiner && cur.isEmoji {
                chars.append(previous)
                chars.append(cur)
            } else if cur.isEmoji {
                chars.append(cur)
            }
            
            previous = cur
        }
        
        return chars
    }
}
