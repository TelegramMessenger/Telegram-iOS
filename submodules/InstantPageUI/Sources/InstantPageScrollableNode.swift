import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import Display
import TelegramPresentationData

protocol InstantPageScrollableItem: AnyObject, InstantPageItem {
    var contentSize: CGSize { get }
    var horizontalInset: CGFloat { get }
    var isRTL: Bool { get }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)?
}

private final class InstantPageScrollableContentNodeParameters: NSObject {
    let item: InstantPageScrollableItem
    
    init(item: InstantPageScrollableItem) {
        self.item = item
        super.init()
    }
}

final class InstantPageScrollableContentNode: ASDisplayNode {
    let item: InstantPageScrollableItem
    
    init(item: InstantPageScrollableItem, additionalNodes: [InstantPageNode]) {
        self.item = item
        super.init()
        
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        
        for case let node as ASDisplayNode in additionalNodes {
            self.addSubnode(node)
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageScrollableContentNodeParameters(item: self.item)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageScrollableContentNodeParameters {
            parameters.item.drawInTile(context: context)
        }
    }
}

final class InstantPageScrollableNode: ASScrollNode, InstantPageNode {
    let item: InstantPageScrollableItem
    let contentNode: InstantPageScrollableContentNode
    
    var contentOffset: CGPoint {
        return self.view.contentOffset
    }
    
    init(item: InstantPageScrollableItem, additionalNodes: [InstantPageNode]) {
        self.item = item
        self.contentNode = InstantPageScrollableContentNode(item: item, additionalNodes: additionalNodes)
        super.init()
        
        self.isOpaque = false
        self.contentNode.frame = CGRect(origin: CGPoint(x: item.horizontalInset, y: 0.0), size: item.contentSize)
        self.view.contentSize = CGSize(width: item.contentSize.width + item.horizontalInset * 2.0, height: item.contentSize.height)
        if item.isRTL {
            self.view.contentOffset = CGPoint(x: self.view.contentSize.width - item.frame.width, y: 0.0)
        }
        self.view.alwaysBounceVertical = false
        self.view.showsHorizontalScrollIndicator = false
        self.view.showsVerticalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.view.contentInsetAdjustmentBehavior = .never
        }
        self.addSubnode(self.contentNode)
        
        self.view.interactiveTransitionGestureRecognizerTest = { [weak self] point -> Bool in
            if let strongSelf = self {
                if strongSelf.view.contentOffset.x < 1.0 {
                    return false
                } else {
                    return point.x - strongSelf.view.contentOffset.x > 30.0
                }
            } else {
                return false
            }
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
}
