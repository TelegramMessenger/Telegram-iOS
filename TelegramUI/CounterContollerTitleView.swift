import Foundation
import Display
import AsyncDisplayKit

struct CounterContollerTitle: Equatable {
    let title: String
    let counter: String
}

final class CounterContollerTitleView: UIView {
    private var theme: PresentationTheme
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    var title: CounterContollerTitle = CounterContollerTitle(title: "", counter: "") {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: self.title.title, font: Font.bold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                self.subtitleNode.attributedText = NSAttributedString(string: self.title.counter, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                
                self.accessibilityLabel = self.title.title
                self.accessibilityValue = self.title.counter
                
                self.setNeedsLayout()
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.truncationType = .end
        self.subtitleNode.isOpaque = false
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = UIAccessibilityTraitHeader
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let spacing: CGFloat = 0.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width), height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: max(1.0, size.width), height: size.height))
        let combinedHeight = titleSize.height + subtitleSize.height + spacing
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + spacing), size: subtitleSize)
        self.subtitleNode.frame = subtitleFrame
    }
}
