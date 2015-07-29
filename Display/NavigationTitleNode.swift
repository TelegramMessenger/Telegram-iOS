import UIKit
import AsyncDisplayKit

public class NavigationTitleNode: ASDisplayNode {
    private let label: ASTextNode
    
    private var _text: NSString = ""
    public var text: NSString {
        get {
            return self._text
        }
        set(value) {
            self._text = value
            self.setText(value)
        }
    }
    
    public init(text: NSString) {
        self.label = ASTextNode()
        self.label.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.setText(text)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setText(text: NSString) {
        var titleAttributes = [String : AnyObject]()
        titleAttributes[NSFontAttributeName] = UIFont.boldSystemFontOfSize(17.0)
        titleAttributes[NSForegroundColorAttributeName] = UIColor.blackColor()
        let titleString = NSAttributedString(string: text as String, attributes: titleAttributes)
        self.label.attributedString = titleString
        self.invalidateCalculatedLayout()
    }
    
    public override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
        self.label.measure(constrainedSize)
        return self.label.calculatedSize
    }
    
    public override func layout() {
        self.label.frame = self.bounds
    }
}
