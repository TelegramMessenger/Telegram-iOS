import Foundation
import AsyncDisplayKit

public final class TextFieldNodeView: UITextField {
    public var didDeleteBackwardWhileEmpty: (() -> Void)?
    
    var fixOffset: Bool = true
    
    override public func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.offsetBy(dx: 0.0, dy: -UIScreenPixel)
    }
    
    override public func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return self.editingRect(forBounds: bounds.offsetBy(dx: 0.0, dy: self.fixOffset ? 0.0 : -UIScreenPixel))
    }
    
    override public func deleteBackward() {
        if self.text == nil || self.text!.isEmpty {
            self.didDeleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
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
