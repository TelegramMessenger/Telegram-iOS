import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SegmentedControlNode

final class MediaPickerTitleView: UIView {
    private let titleNode: ImmediateTextNode
    private let segmentedControlNode: SegmentedControlNode
    
    public var theme: PresentationTheme {
        didSet {
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: NavigationBar.titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
        }
    }
    
    public var title: String = "" {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: self.title, font: NavigationBar.titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
                self.setNeedsLayout()
            }
        }
    }
    
    public var segmentsHidden = true {
        didSet {
            if self.segmentsHidden != oldValue {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.21, curve: .easeInOut)
                transition.updateAlpha(node: self.titleNode, alpha: self.segmentsHidden ? 1.0 : 0.0)
                transition.updateAlpha(node: self.segmentedControlNode, alpha: self.segmentsHidden ? 0.0 : 1.0)
                self.segmentedControlNode.isUserInteractionEnabled = !self.segmentsHidden
            }
        }
    }
    
    public var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.segmentedControlNode.items = self.segments.map { SegmentedControlItem(title: $0) }
                self.setNeedsLayout()
            }
        }
    }
    
    public var index: Int {
        get {
            return self.segmentedControlNode.selectedIndex
        }
        set {
            self.segmentedControlNode.selectedIndex = newValue
        }
    }
    
    public var indexUpdated: ((Int) -> Void)?
    
    public init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: segments.map { SegmentedControlItem(title: $0) }, selectedIndex: selectedIndex)
        self.segmentedControlNode.alpha = 0.0
        self.segmentedControlNode.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            self?.indexUpdated?(index)
        }
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.segmentedControlNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: min(300.0, size.width - 36.0)), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - controlSize.width) / 2.0), y: floorToScreenPixels((size.height - controlSize.height) / 2.0)), size: controlSize)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: 44.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}
