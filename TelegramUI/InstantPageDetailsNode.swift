import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let detailsHeaderHeight: CGFloat = 44.0
private let detailsInset: CGFloat = 17.0
private let titleInset: CGFloat = 22.0

final class InstantPageDetailsNode: ASDisplayNode, InstantPageNode {
    let item: InstantPageDetailsItem
    
    private let titleTile: InstantPageTile
    private let titleTileNode: InstantPageTileNode
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let arrowNode: InstantPageDetailsArrowNode
    private let separatorNode: ASDisplayNode
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, item: InstantPageDetailsItem) {
        self.item = item
        let frame = item.frame
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.titleTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: detailsHeaderHeight))
        self.titleTileNode = InstantPageTileNode(tile: self.titleTile, backgroundColor: .clear)
    
        let titleItems = layoutTextItemWithString(item.title, boundingWidth: frame.size.width - detailsInset * 2.0 - titleInset, offset: CGPoint(x: detailsInset + titleInset, y: 0.0)).0
        var offset: CGFloat?
        for var item in titleItems {
            var itemOffset = floorToScreenPixels((detailsHeaderHeight - item.frame.height) / 2.0)
            if item is InstantPageTextItem {
                offset = itemOffset
            } else if let offset = offset {
                itemOffset = offset
            }
            item.frame = item.frame.offsetBy(dx: 0.0, dy: itemOffset)
        }
        self.titleTile.items.append(contentsOf: titleItems)
        
        self.arrowNode = InstantPageDetailsArrowNode(color: theme.controlColor, open: false)
        self.separatorNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleTileNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.separatorNode)
        
        let lineSize = CGSize(width: frame.width - detailsInset, height: UIScreenPixel)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: item.rtl ? 0.0 : detailsInset, y: detailsHeaderHeight - lineSize.height), size: lineSize)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    if strongSelf.separatorNode.frame.minY < strongSelf.highlightedBackgroundNode.frame.maxY {
                        strongSelf.separatorNode.alpha = 0.0
                    }
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    if strongSelf.separatorNode.alpha < 1.0 {
                        strongSelf.separatorNode.alpha = 1.0
                        strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    @objc func buttonPressed() {
        self.arrowNode.setOpen(!self.arrowNode.open, animated: true)
        //self.openUrl(InstantPageUrlItem(url: self.url, webpageId: self.webpageId))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.titleTileNode.frame = self.titleTile.frame
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: detailsHeaderHeight + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: detailsHeaderHeight))
        self.arrowNode.frame = CGRect(x: detailsInset, y: floorToScreenPixels((detailsHeaderHeight - 8.0) / 2.0) + 1.0, width: 13.0, height: 8.0)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
//        self.titleNode.attributedText = NSAttributedString(string: self.title, font: UIFont(name: "Georgia", size: 17.0), textColor: theme.panelPrimaryColor)
//        self.descriptionNode.attributedText = NSAttributedString(string: self.pageDescription, font: theme.serif ? UIFont(name: "Georgia", size: 15.0) : Font.regular(15.0), textColor: theme.panelSecondaryColor)
        self.arrowNode.color = theme.controlColor
        self.separatorNode.backgroundColor = theme.controlColor
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
    }
}

private final class InstantPageDetailsArrowNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

final class InstantPageDetailsArrowNode : ASDisplayNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    private (set) var open: Bool
    
    private var progress: CGFloat = 0.0
    private var targetProgress: CGFloat?
    
    private var displayLink: CADisplayLink?
    
    init(color: UIColor, open: Bool) {
        self.color = color
        self.open = open
        self.progress = open ? 1.0 : 0.0
        
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
        
        class DisplayLinkProxy: NSObject {
            weak var target: InstantPageDetailsArrowNode?
            init(target: InstantPageDetailsArrowNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink?.isPaused = true
        self.displayLink?.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    func setOpen(_ open: Bool, animated: Bool) {
        let openProgress: CGFloat = open ? 1.0 : 0.0
        if animated {
            self.targetProgress = openProgress
            self.displayLink?.isPaused = false
        } else {
            self.progress = openProgress
            self.targetProgress = nil
            self.displayLink?.isPaused = true
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        if self.targetProgress != nil {
            self.displayLink?.isPaused = false
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.displayLink?.isPaused = true
    }
    
    private func displayLinkEvent() {
        if let targetProgress = self.targetProgress {
//            var fps: Int = 60
//            if let link = self.displayLink, link.duration > 0 {
//                fps = Int(round(1000 / link.duration) / 1000)
//            }
            let delta = targetProgress - self.progress
            self.progress += delta * 0.01
            if delta > 0 && self.progress > targetProgress {
                self.progress = 1.0
                self.targetProgress = nil
                self.displayLink?.isPaused = true
            } else if delta < 0 && self.progress < targetProgress {
                self.progress = 0.0
                self.targetProgress = nil
                self.displayLink?.isPaused = true
            }
        }
        
        self.setNeedsDisplay()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageDetailsArrowNodeParameters(color: self.color, progress: self.progress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageDetailsArrowNodeParameters {
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineCap(.round)
            context.setLineWidth(2.0)
            
            context.move(to: CGPoint(x: 1.0, y: 1.0 + 5.0 * parameters.progress))
            context.addLine(to: CGPoint(x: 6.0, y: 6.0 - 5.0 * parameters.progress))
            context.addLine(to: CGPoint(x: 11.0, y: 1.0 + 5.0 * parameters.progress))
            context.strokePath()
        }
    }
}
