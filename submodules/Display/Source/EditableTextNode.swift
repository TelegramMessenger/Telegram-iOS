import Foundation
import UIKit
import AsyncDisplayKit

open class EditableTextNode: ASEditableTextNode {
    override public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            guard newValue != self.keyboardAppearance else {
                return
            }
            super.keyboardAppearance = newValue
            self.textView.reloadInputViews()
        }
    }
    
    public var isRTL: Bool {
        if let text = self.textView.text, !text.isEmpty {
            let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
            tagger.string = text
            
            let lang = tagger.tag(at: 0, scheme: .language, tokenRange: nil, sentenceRange: nil)
            if let lang = lang?.rawValue, lang.contains("he") || lang.contains("ar") || lang.contains("fa") {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

public extension UITextView {
    var numberOfLines: Int {
        let layoutManager = self.layoutManager
        let numberOfGlyphs = layoutManager.numberOfGlyphs
        var lineRange: NSRange = NSMakeRange(0, 1)
        var index = 0
        var numberOfLines = 0
        
        while index < numberOfGlyphs {
            layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            index = NSMaxRange(lineRange)
            numberOfLines += 1
        }
        return numberOfLines
    }
}
