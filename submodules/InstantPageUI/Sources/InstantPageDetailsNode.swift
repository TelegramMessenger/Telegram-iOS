import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private let detailsInset: CGFloat = 17.0
private let titleInset: CGFloat = 22.0

final class InstantPageDetailsNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let theme: InstantPageTheme
    let item: InstantPageDetailsItem
    
    private let titleTile: InstantPageTile
    private let titleTileNode: InstantPageTileNode
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let arrowNode: InstantPageDetailsArrowNode
    let separatorNode: ASDisplayNode
    let contentNode: InstantPageContentNode
    
    private let updateExpanded: (Bool) -> Void
    var expanded: Bool
    
    var previousNode: InstantPageDetailsNode?
    
    var requestLayoutUpdate: ((Bool) -> Void)?
    
    init(context: AccountContext, sourcePeerType: MediaAutoDownloadPeerType, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, item: InstantPageDetailsItem, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, currentlyExpanded: Bool?, updateDetailsExpanded: @escaping (Bool) -> Void) {
        self.context = context
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.theme = theme
        self.item = item
        
        self.updateExpanded = updateDetailsExpanded
        
        let frame = item.frame
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.titleTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: item.titleHeight))
        self.titleTile.items.append(contentsOf: item.titleItems)
        self.titleTileNode = InstantPageTileNode(tile: self.titleTile, backgroundColor: .clear)
        
        if let expanded = currentlyExpanded {
            self.expanded = expanded
        } else {
            self.expanded = item.initiallyExpanded
        }
        
        self.arrowNode = InstantPageDetailsArrowNode(color: theme.controlColor, open: self.expanded)
        self.separatorNode = ASDisplayNode()
        
        self.contentNode = InstantPageContentNode(context: context, strings: strings, nameDisplayOrder: nameDisplayOrder, sourcePeerType: sourcePeerType, theme: theme, items: item.items, contentSize: CGSize(width: item.frame.width, height: item.frame.height - item.titleHeight), openMedia: openMedia, longPressMedia: longPressMedia, openPeer: openPeer, openUrl: openUrl)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.contentNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleTileNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.separatorNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.separatorNode.alpha = 0.0
                    if let previousSeparator = strongSelf.previousNode?.separatorNode {
                        previousSeparator.alpha = 0.0
                    }
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    strongSelf.separatorNode.alpha = 1.0
                    strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    if let previousSeparator = strongSelf.previousNode?.separatorNode {
                        previousSeparator.alpha = 1.0
                        previousSeparator.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.contentNode.requestLayoutUpdate = { [weak self] animated in
            self?.requestLayoutUpdate?(animated)
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    @objc func buttonPressed() {
        self.setExpanded(!self.expanded, animated: true)
        self.updateExpanded(expanded)
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool) {
        self.expanded = expanded
        self.arrowNode.setOpen(expanded, animated: animated)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset = detailsInset + self.item.safeInset
        
        self.titleTileNode.frame = self.titleTile.frame
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: self.item.titleHeight + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: self.item.titleHeight))
        self.arrowNode.frame = CGRect(x: inset, y: floorToScreenPixels((self.item.titleHeight - 8.0) / 2.0) + 1.0, width: 13.0, height: 8.0)
        self.contentNode.frame = CGRect(x: 0.0, y: self.item.titleHeight, width: size.width, height: self.item.frame.height - self.item.titleHeight)
        
        let lineSize = CGSize(width: self.frame.width - inset, height: UIScreenPixel)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: self.item.rtl ? 0.0 : inset, y: self.item.titleHeight - lineSize.height), size: lineSize)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.contentNode.transitionNode(media: media)
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.contentNode.updateHiddenMedia(media: media)
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.arrowNode.color = theme.controlColor
        self.separatorNode.backgroundColor = theme.controlColor
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool) {
        if self.bounds.height > self.item.titleHeight {
            self.contentNode.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY), animated: animated)
        }
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if self.titleTileNode.frame.contains(location) {
            for case let item as InstantPageTextItem in self.item.titleItems {
                if item.frame.contains(location) {
                    return (item, self.titleTileNode.frame.origin)
                }
            }
        }
        else if let (textItem, parentOffset) = self.contentNode.textItemAtLocation(location.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY)) {
            return (textItem, self.contentNode.frame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
        }
        return nil
    }
    
    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
        if self.titleTileNode.frame.contains(point) {
            if self.item.linkSelectionRects(at: point).isEmpty {
                return .fail
            }
        } else if self.contentNode.frame.contains(point) {
            return self.contentNode.tapActionAtPoint(_: point.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY))
        }
        return .waitForSingleTap
    }
    
    var effectiveContentSize: CGSize {
        return self.contentNode.effectiveContentSize
    }
    
    func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        return self.contentNode.effectiveFrameForItem(item).offsetBy(dx: 0.0, dy: self.item.titleHeight)
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
        self.displayLink?.add(to: RunLoop.main, forMode: .common)
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    func setOpen(_ open: Bool, animated: Bool) {
        self.open = open
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
            let sign = CGFloat(targetProgress - self.progress > 0 ? 1 : -1)
            self.progress += 0.14 * sign
            if sign > 0 && self.progress > targetProgress {
                self.progress = 1.0
                self.targetProgress = nil
                self.displayLink?.isPaused = true
            } else if sign < 0 && self.progress < targetProgress {
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
