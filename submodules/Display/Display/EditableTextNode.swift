import Foundation
import UIKit
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
            super.keyboardAppearance = newValue
            self.textView.reloadInputViews()
        }
    }
}
