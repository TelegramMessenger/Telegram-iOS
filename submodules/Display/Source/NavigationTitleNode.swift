import UIKit
import AsyncDisplayKit

public class NavigationTitleNode: ASDisplayNode {
    private let label: ImmediateTextNode
    
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
    
    public var color: UIColor = UIColor.black {
        didSet {
            self.setText(self._text)
        }
    }
    
    public init(text: NSString) {
        self.label = ImmediateTextNode()
        self.label.maximumNumberOfLines = 1
        self.label.truncationType = .end
        self.label.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.setText(text)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setText(_ text: NSString) {
        var titleAttributes = [NSAttributedString.Key : AnyObject]()
        titleAttributes[NSAttributedString.Key.font] = UIFont.boldSystemFont(ofSize: 17.0)
        titleAttributes[NSAttributedString.Key.foregroundColor] = self.color
        let titleString = NSAttributedString(string: text as String, attributes: titleAttributes)
        self.label.attributedText = titleString
        self.invalidateCalculatedLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let _ = self.label.updateLayout(constrainedSize)
        return self.label.calculatedSize
    }
    
    public override func layout() {
        self.label.frame = self.bounds
    }
}
