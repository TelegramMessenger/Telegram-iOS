import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle

private let backArrowImage = NavigationBarTheme.generateBackArrowImage(color: .white)
private let moreImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/MoreIcon"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Instant View/ActionIcon"), color: .white)

final private class InstantPageProgressNode: ASDisplayNode {
    private let foregroundNode: ASDisplayNode
    private var progress: CGFloat = 0.0
    
    override init() {
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.backgroundColor = .white
        
        super.init()
        
        self.addSubnode(self.foregroundNode)
    }
    
    func setProgress(_ progress: CGFloat, animated: Bool = false) {
        if self.progress == progress && animated {
            return
        }
        
        let size = self.bounds.size
        
        self.progress = progress
        
        let transition: ContainedViewLayoutTransition
        if animated && progress > 0.0 {
            transition = .animated(duration: 0.7, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let alpaTransition: ContainedViewLayoutTransition
        if animated {
            alpaTransition = .animated(duration: 0.3, curve: .easeInOut)
        } else {
            alpaTransition = .immediate
        }
        
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width * progress, height: size.height))
        
        let alpha: CGFloat = progress < 0.001 || progress > 0.999 ? 0.0 : 1.0
        alpaTransition.updateAlpha(node: self.foregroundNode, alpha: alpha)
    }
}

final class InstantPageNavigationBar: ASDisplayNode {
    private var strings: PresentationStrings
    
    private let pageProgressNode: ASDisplayNode
    private let backButton: HighlightableButtonNode
    private let moreButton: HighlightableButtonNode
    private let actionButton: HighlightableButtonNode
    private let scrollToTopButton: HighlightableButtonNode
    private let arrowNode: ASImageNode
    private let titleNode: ASTextNode
    
    private let progressNode: InstantPageProgressNode
    
    private let intrinsicMoreSize: CGSize
    private let intrinsicSmallMoreSize: CGSize
    private let intrinsicActionSize: CGSize
    private let intrinsicSmallActionSize: CGSize
    
    private var dimmed: Bool = false
    private var buttonsAlphaFactor: CGFloat = 1.0
    
    private var currentTitle: String?
    
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
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        
        self.progressNode = InstantPageProgressNode()
        
        super.init()
        
        self.backgroundColor = .black
        
        self.backButton.addSubnode(self.arrowNode)
        
        self.addSubnode(self.pageProgressNode)
        self.addSubnode(self.backButton)
        self.addSubnode(self.scrollToTopButton)
        self.addSubnode(self.moreButton)
        self.addSubnode(self.actionButton)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.progressNode)
        
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
    
    func setLoadProgress(_ progress: CGFloat) {
        self.progressNode.setProgress(progress, animated: true)
    }
    
    func updateLayout(size: CGSize, minHeight: CGFloat, maxHeight: CGFloat, topInset: CGFloat, leftInset: CGFloat, rightInset: CGFloat, title: String?, pageProgress: CGFloat, transition: ContainedViewLayoutTransition) {
        let progressHeight = size.height
        transition.updateFrame(node: self.pageProgressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - progressHeight), size: CGSize(width: floorToScreenPixels(size.width * pageProgress), height: progressHeight)))
        
        let transitionFactor = (size.height - minHeight) / (maxHeight - minHeight)
        
        transition.updateFrame(node: self.backButton, frame: CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: 100.0, height: size.height)))
        if let image = arrowNode.image {
            let arrowImageSize = image.size
            
            let arrowHeight: CGFloat
            if size.height.isLess(than: maxHeight) {
                arrowHeight = floor(9.0 * transitionFactor + 12.0)
            } else {
                arrowHeight = 21.0
            }
            let scaledArrowSize = CGSize(width: arrowImageSize.width * arrowHeight / arrowImageSize.height, height: arrowHeight)
            let arrowOffset = floor(8.0 * transitionFactor + 4.0)
            transition.updateFrame(node: self.arrowNode, frame: CGRect(origin: CGPoint(x: leftInset + 8.0, y: size.height - arrowHeight - arrowOffset), size: scaledArrowSize))
        }
        
        let offsetScaleFactor: CGFloat
        let buttonScaleFactor: CGFloat
        if size.height.isLess(than: maxHeight) {
            offsetScaleFactor = transitionFactor
            buttonScaleFactor = ((transitionFactor * self.intrinsicMoreSize.height) + ((1.0 - transitionFactor) * self.intrinsicSmallMoreSize.height)) / self.intrinsicMoreSize.height
        } else {
            offsetScaleFactor = 1.0
            buttonScaleFactor = 1.0
        }
        
        var alphaFactor = min(1.0, offsetScaleFactor * offsetScaleFactor)
        self.buttonsAlphaFactor = alphaFactor
        if self.dimmed {
            alphaFactor *= 0.5
        }
        
        if title != self.currentTitle {
            self.currentTitle = title
            if let title = title {
                self.titleNode.transform = CATransform3DIdentity
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
                let titleSize = self.titleNode.measure(CGSize(width: size.width - leftInset - rightInset - 170.0, height: size.height))
                self.titleNode.frame = CGRect(origin: CGPoint(x: (size.width - titleSize.width) / 2.0, y: size.height - 30.0), size: titleSize)
            }
        }
        
        let maxMoreOffset = self.intrinsicMoreSize.height / 2.0 + floor((44.0 - self.intrinsicMoreSize.height) / 2.0)
        let minMoreOffset = self.intrinsicSmallMoreSize.height / 2.0 + floor((20.0 - self.intrinsicSmallMoreSize.height) / 2.0)
        let moreOffset = (transitionFactor * maxMoreOffset) + ((1.0 - transitionFactor) * minMoreOffset)
        
        transition.updateTransformScale(node: self.titleNode, scale: 0.75 + transitionFactor * 0.25)
        transition.updatePosition(node: self.titleNode, position: CGPoint(x: size.width / 2.0, y: size.height - moreOffset))
        
        transition.updateTransformScale(node: self.moreButton, scale: buttonScaleFactor)
        transition.updatePosition(node: self.moreButton, position: CGPoint(x: size.width - rightInset - buttonScaleFactor * self.intrinsicMoreSize.width / 2.0, y: size.height - moreOffset))
        transition.updateAlpha(node: self.moreButton, alpha: alphaFactor)
        transition.updateTransformScale(node: self.actionButton, scale: buttonScaleFactor)
        transition.updatePosition(node: self.actionButton, position: CGPoint(x: size.width - rightInset - buttonScaleFactor * self.intrinsicMoreSize.width - buttonScaleFactor * self.intrinsicActionSize.width / 2.0, y: size.height - moreOffset))
        transition.updateAlpha(node: self.actionButton, alpha: alphaFactor)
        
        transition.updateFrame(node: self.scrollToTopButton, frame: CGRect(origin: CGPoint(x: leftInset + 64.0, y: 0.0), size: CGSize(width: size.width - leftInset - rightInset - 64.0, height: size.height)))
        
        let loadProgressHeight: CGFloat = 2.0
        transition.updateFrame(node: self.progressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - loadProgressHeight - UIScreenPixel), size: CGSize(width: size.width, height: loadProgressHeight)))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dimmed {
            return nil
        } else {
            return super.hitTest(point, with: event)
        }
    }
}
