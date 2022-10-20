import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

public struct CounterContollerTitle: Equatable {
    public var title: String
    public var counter: String
    
    public init(title: String, counter: String) {
        self.title = title
        self.counter = counter
    }
}

public final class CounterContollerTitleView: UIView {
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    public var title: CounterContollerTitle = CounterContollerTitle(title: "", counter: "") {
        didSet {
            if self.title != oldValue {
                self.update()
            }
        }
    }
    
    public var theme: PresentationTheme {
        didSet {
            self.update()
        }
    }
    
    private func update() {
        self.titleNode.attributedText = NSAttributedString(string: self.title.title, font: Font.semibold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.title.counter, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
        
        self.accessibilityLabel = self.title.title
        self.accessibilityValue = self.title.counter
        
        self.setNeedsLayout()
    }
    
    public init(theme: PresentationTheme) {
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
        self.accessibilityTraits = .header
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
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
