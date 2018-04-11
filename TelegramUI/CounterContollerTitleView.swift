import Foundation
import Display
import AsyncDisplayKit

struct CounterContollerTitle: Equatable {
    let title: String
    let counter: String
}

final class CounterContollerTitleView: UIView {
    private var theme: PresentationTheme
    private let titleNode: ASTextNode
    
    func f() {
        
    }
    
    var title: CounterContollerTitle = CounterContollerTitle(title: "", counter: "") {
        didSet {
            if self.title != oldValue {
                let string = NSMutableAttributedString()
                string.append(NSAttributedString(string: title.title, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor))
                string.append(NSAttributedString(string: "  " + title.counter, font: Font.regular(15.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                self.titleNode.attributedText = string
                
                self.setNeedsLayout()
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        super.init(frame: CGRect())
        
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
