import Foundation
import Display
import AsyncDisplayKit

private let backArrowImage = UIImage(bundleImageName: "Instant View/BackArrow")?.precomposed()
private let settingsImage = UIImage(bundleImageName: "Instant View/SettingsIcon")?.precomposed()

final class InstantPageNavigationBar: ASDisplayNode {
    private var strings: PresentationStrings
    
    private var pageProgress: CGFloat = 0.0
    
    let pageProgressNode: ASDisplayNode
    let backButton: HighlightableButtonNode
    let shareButton: HighlightableButtonNode
    let settingsButton: HighlightableButtonNode
    let scrollToTopButton: HighlightableButtonNode
    let arrowNode: ASImageNode
    let shareLabel: ASTextNode
    var shareLabelSize: CGSize
    var shareLabelSmallSize: CGSize
    
    var back: (() -> Void)?
    var share: (() -> Void)?
    var settings: (() -> Void)?
    
    init(strings: PresentationStrings) {
        self.strings = strings
        
        self.pageProgressNode = ASDisplayNode()
        self.pageProgressNode.isLayerBacked = true
        
        self.backButton = HighlightableButtonNode()
        self.shareButton = HighlightableButtonNode()
        self.settingsButton = HighlightableButtonNode()
        self.scrollToTopButton = HighlightableButtonNode()
        
        self.settingsButton.setImage(settingsImage, for: [])
        self.settingsButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: 44.0, height: 44.0))
        
        self.arrowNode = ASImageNode()
        self.arrowNode.image = backArrowImage
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        
        self.shareLabel = ASTextNode()
        self.shareLabel.attributedText = NSAttributedString(string: strings.Channel_Share, font: Font.regular(17.0), textColor: UIColor(white: 1.0, alpha: 0.7))
        self.shareLabel.isLayerBacked = true
        self.shareLabel.displaysAsynchronously = false
        
        let shareLabelSmall = ASTextNode()
        shareLabelSmall.attributedText = NSAttributedString(string: strings.Channel_Share, font: Font.regular(12.0), textColor: UIColor(white: 1.0, alpha: 0.7))
        
        self.shareLabelSize = self.shareLabel.measure(CGSize(width: 200.0, height: 100.0))
        self.shareLabelSmallSize = shareLabelSmall.measure(CGSize(width: 200.0, height: 100.0))
        
        self.shareLabel.frame = CGRect(origin: CGPoint(), size: self.shareLabelSize)
        
        super.init()
        
        self.backgroundColor = .black
        
        self.backButton.addSubnode(self.arrowNode)
        self.shareButton.addSubnode(self.shareLabel)
        
        self.addSubnode(self.pageProgressNode)
        self.addSubnode(self.backButton)
        self.addSubnode(self.shareButton)
        self.addSubnode(self.scrollToTopButton)
        //self.addSubnode(self.settingsButton)
        
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.shareButton.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        self.settingsButton.addTarget(self, action: #selector(self.settingsPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func backPressed() {
        self.back?()
    }
    
    @objc func sharePressed() {
        self.share?()
    }
    
    @objc func settingsPressed() {
        self.settings?()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
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
        
        transition.updateFrame(node: shareButton, frame: CGRect(origin: CGPoint(x: size.width - 80.0, y: 0.0), size: CGSize(width: 80.0, height: size.height)))
        
        let shareImageSize = self.shareLabelSize
        let shareSmallImageSize = self.shareLabelSmallSize
        let shareHeight: CGFloat
        if size.height.isLess(than: 64.0) {
            let k = (shareImageSize.height - shareSmallImageSize.height) / 44.0
            let b = shareSmallImageSize.height - k * 20.0;
            shareHeight = k * size.height + b
        } else {
            shareHeight = shareImageSize.height;
        }
        let shareHeightFactor = shareHeight / shareImageSize.height
        transition.updateTransformScale(node: self.shareLabel, scale: shareHeightFactor)
        
        let scaledShareSize = CGSize(width: shareImageSize.width * shareHeightFactor, height: shareImageSize.height * shareHeightFactor)
        let shareLabelCenter = CGPoint(x: 80.0 - 8.0 - scaledShareSize.width / 2.0, y: max(0.0, size.height - 44.0) + min(size.height, 44.0) / 2.0)
        transition.updatePosition(node: self.shareLabel, position: shareLabelCenter)
        
        let alpha = 1.0 - (shareImageSize.height - shareHeight) / (shareImageSize.height - shareSmallImageSize.height)
        let diffFactor = shareSmallImageSize.height / shareImageSize.height
        let smallSettingsWidth = 44.0 * diffFactor
        let offset = smallSettingsWidth / 4.0
        
        let spacing = max(4.0, (shareLabelCenter.x - scaledShareSize.width / 2.0) * -1.0 + 4.0)
        
        let xa = shareLabelCenter.x - scaledShareSize.width / 2.0
        let xb = spacing - (44.0 * shareHeightFactor) / 2.0
        let ya = max(0.0, size.height - 44.0)
        let yb = min(size.height, 44.0) / 2.0 - 22.0 - 44.0 / 2.0
        transition.updatePosition(node: self.settingsButton, position: CGPoint(x: xa - xb, y: ya + yb))
        transition.updateTransformScale(node: self.settingsButton, scale: shareHeightFactor)
        
        transition.updateAlpha(node: self.settingsButton, alpha: alpha)
        
        transition.updateFrame(node: self.scrollToTopButton, frame: CGRect(origin: CGPoint(x: 100.0, y: 0.0), size: CGSize(width: size.width - 100.0 - 80.0 - 44.0, height: size.height)))
    }
}
