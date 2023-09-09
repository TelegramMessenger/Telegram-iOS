import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SegmentedControlNode
import ContextUI

final class MediaPickerTitleView: UIView {
    let contextSourceNode: ContextReferenceContentNode
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: ImmediateTextNode
    private let arrowNode: ASImageNode
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
    
    public var isEnabled: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = self.isEnabled
            self.arrowNode.isHidden = !self.isEnabled
        }
    }
    
    public var isHighlighted: Bool = false {
        didSet {
            self.alpha = self.isHighlighted ? 0.5 : 1.0
        }
    }
    
    public var segmentsHidden = true {
        didSet {
            if self.segmentsHidden != oldValue {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.21, curve: .easeInOut)
                transition.updateAlpha(node: self.titleNode, alpha: self.segmentsHidden ? 1.0 : 0.0)
                transition.updateAlpha(node: self.arrowNode, alpha: self.segmentsHidden ? 1.0 : 0.0)
                transition.updateAlpha(node: self.segmentedControlNode, alpha: self.segmentsHidden ? 0.0 : 1.0)
                self.segmentedControlNode.isUserInteractionEnabled = !self.segmentsHidden
                self.buttonNode.isUserInteractionEnabled = self.isEnabled && self.segmentsHidden
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
    public var action: () -> Void = {}
    
    public init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        
        self.contextSourceNode = ContextReferenceContentNode()
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/DownArrow"), color: theme.rootController.navigationBar.secondaryTextColor)
        self.arrowNode.isHidden = true
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: segments.map { SegmentedControlItem(title: $0) }, selectedIndex: selectedIndex)
        self.segmentedControlNode.alpha = 0.0
        self.segmentedControlNode.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            self?.indexUpdated?(index)
        }
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.arrowNode.alpha = 0.5
                self.titleNode.alpha = 0.5
            } else {
                self.arrowNode.alpha = 1.0
                self.titleNode.alpha = 1.0
            }
        }
        
        self.addSubnode(self.contextSourceNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.segmentedControlNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        self.contextSourceNode.frame = self.bounds.insetBy(dx: 0.0, dy: 14.0)
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: min(300.0, size.width - 36.0)), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - controlSize.width) / 2.0), y: floorToScreenPixels((size.height - controlSize.height) / 2.0)), size: controlSize)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 210.0, height: 44.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
        
        if let arrowSize = self.arrowNode.image?.size {
            self.arrowNode.frame = CGRect(origin: CGPoint(x: self.titleNode.frame.maxX + 5.0, y: floorToScreenPixels((size.height - arrowSize.height) / 2.0) + 1.0 - UIScreenPixel), size: arrowSize)
        }
        self.buttonNode.frame = CGRect(origin: .zero, size: size)
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
}
