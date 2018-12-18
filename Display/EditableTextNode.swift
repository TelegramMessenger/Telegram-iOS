import Foundation
import AsyncDisplayKit

public class EditableTextNode: ASEditableTextNode {
    override public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            guard newValue != self.keyboardAppearance else {
                return
            }
            let resigning = self.isFirstResponder()
            if resigning {
                self.resignFirstResponder()
            }
            super.keyboardAppearance = newValue
            if resigning {
                self.becomeFirstResponder()
            }
        }
    }
}
