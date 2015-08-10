import Foundation
import UIKit

public class KeyboardHostWindow: UIWindow {
    let textField: UITextField
    
    convenience public init() {
        self.init(frame: CGRect())
    }
    
    override init(frame: CGRect) {
        self.textField = UITextField(frame: CGRect(x: -110.0, y: 0.0, width: 100.0, height: 50.0))
        
        super.init(frame: frame)
        
        self.windowLevel = 1000.0
        self.rootViewController = UIViewController()
        self.addSubview(self.textField)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func acquireFirstResponder() {
        textField.becomeFirstResponder()
    }
}
