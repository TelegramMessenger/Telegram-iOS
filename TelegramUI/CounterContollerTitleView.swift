import Foundation
import Display
import AsyncDisplayKit

struct CounterContollerTitle: Equatable {
    let title: String
    let counter: String
    
    static func ==(lhs: CounterContollerTitle, rhs: CounterContollerTitle) -> Bool {
        return lhs.title == rhs.title && lhs.counter == rhs.counter
    }
}

final class CounterContollerTitleView: UIView {
    private let titleNode: ASTextNode
    
    var title: CounterContollerTitle = CounterContollerTitle(title: "", counter: "") {
        didSet {
            if self.title != oldValue {
                let string = NSMutableAttributedString()
                string.append(NSAttributedString(string: title.title, font: Font.medium(17.0), textColor: .black))
                string.append(NSAttributedString(string: "  " + title.counter, font: Font.regular(15.0), textColor: .gray))
                self.titleNode.attributedText = string
                
                self.setNeedsLayout()
            }
        }
    }
    
    override init(frame: CGRect) {
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        super.init(frame: frame)
        
        self.addSubnode(self.titleNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        let titleSize = self.titleNode.measure(CGSize(width: max(1.0, size.width), height: size.height))
        let combinedHeight = titleSize.height
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
    }
}
