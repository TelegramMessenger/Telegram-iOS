import Foundation
import UIKit

extension UnicodeScalar {
    var isEmoji: Bool {
        switch value {
            case 0x3030, 0x00AE, 0x00A9, // Special Characters
                0x1D000 ... 0x1F77F, // Emoticons
                0x2100 ... 0x27BF, // Misc symbols and Dingbats
                0xFE00 ... 0xFE0F, // Variation Selectors
                0x1F900 ... 0x1F9FF: // Supplemental Symbols and Pictographs
                return true
            default:
                return false
        }
    }
    
    var isZeroWidthJoiner: Bool {
        return value == 8205
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
    
    var glyphCount: Int {
        let richText = NSAttributedString(string: self)
        let line = CTLineCreateWithAttributedString(richText)
        return CTLineGetGlyphCount(line)
    }
    
    var isSingleEmoji: Bool {
        return glyphCount == 1 && containsEmoji
    }
    
    var containsEmoji: Bool {
        return !unicodeScalars.filter { $0.isEmoji }.isEmpty
    }
    
    var containsOnlyEmoji: Bool {
        return unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil
    }
    
    // The next tricks are mostly to demonstrate how tricky it can be to determine emoji's
    // If anyone has suggestions how to improve this, please let me know
    var emojiString: String {
        return emojiScalars.map { String($0) }.reduce("", +)
    }
    
    var firstEmoji: String {
        if let first = emojiScalars.first {
            return String(first)
        } else {
            return ""
        }
    }
    
    var emojis: [String] {
        var scalars: [[UnicodeScalar]] = []
        var currentScalarSet: [UnicodeScalar] = []
        var previousScalar: UnicodeScalar?
        
        for scalar in emojiScalars {
            if let prev = previousScalar, !prev.isZeroWidthJoiner && !scalar.isZeroWidthJoiner {
                scalars.append(currentScalarSet)
                currentScalarSet = []
            }
            currentScalarSet.append(scalar)
            
            previousScalar = scalar
        }
        
        scalars.append(currentScalarSet)
        
        return scalars.map { $0.map{ String($0) } .reduce("", +) }
    }
    
    fileprivate var emojiScalars: [UnicodeScalar] {
        var chars: [UnicodeScalar] = []
        var previous: UnicodeScalar?
        for cur in unicodeScalars {
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
