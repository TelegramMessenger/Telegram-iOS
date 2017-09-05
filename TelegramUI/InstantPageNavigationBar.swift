import Foundation
import Display
import AsyncDisplayKit

private let backArrowImage = NavigationBarTheme.generateBackArrowImage(color: .white)
private let moreImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/MoreIcon"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/ActionIcon"), color: .white)

final class InstantPageNavigationBar: ASDisplayNode {
    private var strings: PresentationStrings
    
    private let pageProgressNode: ASDisplayNode
    private let backButton: HighlightableButtonNode
    private let moreButton: HighlightableButtonNode
    private let actionButton: HighlightableButtonNode
    private let scrollToTopButton: HighlightableButtonNode
    private let arrowNode: ASImageNode
    
    private let intrinsicMoreSize: CGSize
    private let intrinsicSmallMoreSize: CGSize
    private let intrinsicActionSize: CGSize
    private let intrinsicSmallActionSize: CGSize
    
    private var dimmed: Bool = false
    private var buttonsAlphaFactor: CGFloat = 1.0
    
    var back: (() -> Void)?
    var share: (() -> Void)?
    var settings: (() -> Void)?
    var scrollToTop: (() -> Void)?
    
    init(strings: PresentationStrings) {
        self.strings = strings
        
        self.pageProgressNode = ASDisplayNode()
        self.pageProgressNode.isLayerBacked = true
        self.pageProgressNode.backgroundColor = UIColor(rgb: 0x242425)
        
        self.backButton = HighlightableButtonNode()
        self.moreButton = HighlightableButtonNode()
        self.actionButton = HighlightableButtonNode()
        self.scrollToTopButton = HighlightableButtonNode()
        
        self.actionButton.setImage(actionImage, for: [])
        self.intrinsicActionSize = CGSize(width: 44.0, height: 44.0)
        self.intrinsicSmallActionSize = CGSize(width: 20.0, height: 20.0)
        self.actionButton.frame = CGRect(origin: CGPoint(), size: self.intrinsicActionSize)
        
        self.moreButton.setImage(moreImage, for: [])
        self.intrinsicMoreSize = CGSize(width: 44.0, height: 44.0)
        self.intrinsicSmallMoreSize = CGSize(width: 20.0, height: 20.0)
        self.moreButton.frame = CGRect(origin: CGPoint(), size: self.intrinsicMoreSize)
        
        self.arrowNode = ASImageNode()
        self.arrowNode.image = backArrowImage
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        
        super.init()
        
        self.backgroundColor = .black
        
        self.backButton.addSubnode(self.arrowNode)
        
        self.addSubnode(self.pageProgressNode)
        self.addSubnode(self.backButton)
        self.addSubnode(self.scrollToTopButton)
        self.addSubnode(self.moreButton)
        self.addSubnode(self.actionButton)
        
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.actionButton.addTarget(self, action: #selector(self.actionPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTopPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func backPressed() {
        self.back?()
    }
    
    @objc func actionPressed() {
        self.share?()
    }
    
    @objc func morePressed() {
        self.settings?()
    }
    
    @objc func scrollToTopPressed() {
        self.scrollToTop?()
    }
    
    func updateDimmed(_ dimmed: Bool, transition: ContainedViewLayoutTransition) {
        if dimmed != self.dimmed {
            self.dimmed = dimmed
            transition.updateAlpha(node: self.arrowNode, alpha: dimmed ? 0.5 : 1.0)
            var buttonsAlpha = self.buttonsAlphaFactor
            if dimmed {
                buttonsAlpha *= 0.5
            }
            transition.updateAlpha(node: self.actionButton, alpha: buttonsAlpha)
        }
    }
    
    func updateLayout(size: CGSize, pageProgress: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.pageProgressNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: floorToScreenPixels(size.width * pageProgress), height: size.height)))
        
        transition.updateFrame(node: self.backButton, frame: CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: 100.0, height: size.height)))
        if let image = arrowNode.image {
            let arrowImageSize = image.size
            
            let arrowHeight: CGFloat
            if size.height.isLess(than: 64.0) {
                arrowHeight = 9.0 * size.height / 44.0 + 87.0 / 11.0;
            } else {
                arrowHeight = 21.0
            }
            let scaledArrowSize = CGSize(width: arrowImageSize.width * arrowHeight / arrowImageSize.height, height: arrowHeight)
            transition.updateFrame(node: self.arrowNode, frame: CGRect(origin: CGPoint(x: 8.0, y: max(0.0, size.height - 44.0) + floor((min(size.height, 44.0) - scaledArrowSize.height) / 2.0)), size: scaledArrowSize))
        }
        
        let offsetScaleFactor: CGFloat
        let buttonScaleFactor: CGFloat
        if size.height.isLess(than: 64.0) {
            offsetScaleFactor = max(size.height - 20.0, 0.0) / 44.0
            let k = (self.intrinsicMoreSize.height - self.intrinsicSmallMoreSize.height) / 44.0
            let b = self.intrinsicSmallMoreSize.height - k * 20.0;
            buttonScaleFactor = (k * size.height + b) / self.intrinsicMoreSize.height
        } else {
            offsetScaleFactor = 1.0
            buttonScaleFactor = 1.0
        }
        
        var alphaFactor = min(1.0, offsetScaleFactor * offsetScaleFactor)
        self.buttonsAlphaFactor = alphaFactor
        if self.dimmed {
            alphaFactor *= 0.5
        }
        
        transition.updateTransformScale(node: self.moreButton, scale: buttonScaleFactor)
        transition.updatePosition(node: self.moreButton, position: CGPoint(x: size.width - buttonScaleFactor * self.intrinsicMoreSize.width / 2.0, y: offsetScaleFactor * 20.0 + buttonScaleFactor * self.intrinsicMoreSize.height / 2.0))
        transition.updateAlpha(node: self.moreButton, alpha: alphaFactor)
        transition.updateTransformScale(node: self.actionButton, scale: buttonScaleFactor)
        transition.updatePosition(node: self.actionButton, position: CGPoint(x: size.width - buttonScaleFactor * self.intrinsicMoreSize.width - buttonScaleFactor * self.intrinsicActionSize.width / 2.0, y: offsetScaleFactor * 20.0 + buttonScaleFactor * self.intrinsicActionSize.height / 2.0))
        transition.updateAlpha(node: self.actionButton, alpha: alphaFactor)
        
        transition.updateFrame(node: self.scrollToTopButton, frame: CGRect(origin: CGPoint(x: 64.0, y: 0.0), size: CGSize(width: size.width - 64.0, height: size.height)))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dimmed {
            return nil
        } else {
            return super.hitTest(point, with: event)
        }
    }
}
