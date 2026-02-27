import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import CheckNode

public final class ShareActionButtonNode: HighlightTrackingButtonNode {
    private let referenceNode: ContextReferenceContentNode
    private let containerNode: ContextControllerSourceNode
    
    private let badgeLabel: TextNode
    private var badgeText: NSAttributedString?
    private let badgeBackground: ASImageNode
    
    public var badgeBackgroundColor: UIColor {
        didSet {
            self.badgeBackground.image = generateStretchableFilledCircleImage(diameter: 22.0, color: self.badgeBackgroundColor)
        }
    }
    
    public var badgeTextColor: UIColor {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    public var badge: String? {
        didSet {
            if self.badge != oldValue {
                if let badge = self.badge {
                    self.badgeText = NSAttributedString(string: badge, font: Font.regular(14.0), textColor: self.badgeTextColor, paragraphAlignment: .center)
                    self.badgeLabel.isHidden = false
                    self.badgeBackground.isHidden = false
                } else {
                    self.badgeText = nil
                    self.badgeLabel.isHidden = true
                    self.badgeBackground.isHidden = true
                }
                
                self.setNeedsLayout()
            }
        }
    }
    
    var shouldBegin: (() -> Bool)?
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
        
        self.badgeLabel = TextNode()
        self.badgeLabel.isHidden = true
        self.badgeLabel.isUserInteractionEnabled = false
        self.badgeLabel.displaysAsynchronously = false
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.isHidden = true
        self.badgeBackground.isLayerBacked = true
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        
        self.badgeBackground.image = generateStretchableFilledCircleImage(diameter: 22.0, color: badgeBackgroundColor)
        
        super.init()
        
        self.containerNode.addSubnode(self.referenceNode)
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.badgeBackground)
        self.addSubnode(self.badgeLabel)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            if let shouldBegin = strongSelf.shouldBegin {
                return shouldBegin()
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.referenceNode, gesture)
        }
    }
    
    override public func layout() {
        super.layout()
        
        if !self.badgeLabel.isHidden {
            let (badgeLayout, badgeApply) = TextNode.asyncLayout(self.badgeLabel)(TextNodeLayoutArguments(attributedString: self.badgeText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            let _ = badgeApply()
            
            let backgroundSize = CGSize(width: max(22.0, badgeLayout.size.width + 10.0 + 1.0), height: 22.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: self.titleNode.frame.maxX + 6.0, y: self.bounds.size.height - 39.0), size: backgroundSize)
            
            self.badgeBackground.frame = backgroundFrame
            self.badgeLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeLayout.size.width / 2.0), y: backgroundFrame.minY + 3.0), size: badgeLayout.size)
        }
        
        self.containerNode.frame = self.bounds
        self.referenceNode.frame = self.bounds
    }
}

public final class ShareStartAtTimestampNode: HighlightTrackingButtonNode {
    private let checkNode: CheckNode
    private let titleTextNode: TextNode
    
    public var titleTextColor: UIColor {
        didSet {
            self.setNeedsLayout()
        }
    }
    public var checkNodeTheme: CheckNodeTheme {
        didSet {
            self.checkNode.theme = self.checkNodeTheme
        }
    }
    
    private let titleText: String
    
    public var value: Bool {
        return self.checkNode.selected
    }
    
    public var updated: (() -> Void)?
    
    public init(titleText: String, titleTextColor: UIColor, checkNodeTheme: CheckNodeTheme) {
        self.titleText = titleText
        self.titleTextColor = titleTextColor
        self.checkNodeTheme = checkNodeTheme
        
        self.checkNode = CheckNode(theme: checkNodeTheme, content: .check)
        self.checkNode.isUserInteractionEnabled = false
        
        self.titleTextNode = TextNode()
        self.titleTextNode.isUserInteractionEnabled = false
        self.titleTextNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
        self.addSubnode(self.titleTextNode)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        self.checkNode.setSelected(!self.checkNode.selected, animated: true)
        self.updated?()
    }
    
    override public func layout() {
        super.layout()
        
        if self.bounds.width < 1.0 {
            return
        }
        
        let checkSize: CGFloat = 18.0
        let checkSpacing: CGFloat = 10.0
        
        let (titleTextLayout, titleTextApply) = TextNode.asyncLayout(self.titleTextNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.titleText, font: Font.regular(13.0), textColor: self.titleTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: self.bounds.width - 8.0 * 2.0 - checkSpacing - checkSize, height: 100.0), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleTextApply()
        
        let contentWidth = checkSize + checkSpacing + titleTextLayout.size.width
        let checkFrame = CGRect(origin: CGPoint(x: floor((self.bounds.width - contentWidth) * 0.5), y: floor((self.bounds.height - checkSize) * 0.5)), size: CGSize(width: checkSize, height: checkSize))
        
        let isFirstTime = self.checkNode.bounds.isEmpty
        self.checkNode.frame = checkFrame
        if isFirstTime {
            self.checkNode.setSelected(false, animated: false)
        }
            
        self.titleTextNode.frame = CGRect(origin: CGPoint(x: checkFrame.maxX + checkSpacing, y: floor((self.bounds.height - titleTextLayout.size.height) * 0.5)), size: titleTextLayout.size)
    }
}
