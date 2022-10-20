import Foundation
import UIKit
import AsyncDisplayKit

public final class TextFieldNodeView: UITextField {
    public var didDeleteBackwardWhileEmpty: (() -> Void)?
    
    var fixOffset: Bool = true
    
    override public func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.offsetBy(dx: 0.0, dy: 0.0).integral
    }
    
    override public func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.offsetBy(dx: 0.0, dy: 0.0).integral
    }
    
    override public func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return self.editingRect(forBounds: bounds.offsetBy(dx: 0.0, dy: 0.0))
    }
    
    override public func deleteBackward() {
        if self.text == nil || self.text!.isEmpty {
            self.didDeleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
    }
    
    override public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            guard newValue != self.keyboardAppearance else {
                return
            }
            let resigning = self.isFirstResponder
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

public class TextFieldNode: ASDisplayNode {
    public var textField: TextFieldNodeView {
        return self.view as! TextFieldNodeView
    }
    
    public var fixOffset: Bool = true {
        didSet {
            self.textField.fixOffset = self.fixOffset
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return TextFieldNodeView()
        })
    }
}
