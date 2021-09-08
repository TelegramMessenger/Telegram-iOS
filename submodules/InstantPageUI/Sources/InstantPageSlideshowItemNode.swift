import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences

private final class InstantPageSlideshowItemNode: ASDisplayNode {
    private var _index: Int?
    var index: Int {
        get {
            return self._index!
        } set(value) {
            self._index = value
        }
    }
    private let contentNode: ASDisplayNode
    
    var internalIsVisible: Bool = false {
        didSet {
            if self.internalParentVisible && oldValue != self.internalIsVisible && self.internalParentVisible {
                (self.contentNode as? InstantPageNode)?.updateIsVisible(self.internalIsVisible && self.internalParentVisible)
            }
        }
    }
    
    var internalParentVisible: Bool = false {
        didSet {
            if self.internalIsVisible && oldValue != self.internalIsVisible && self.internalParentVisible {
                (self.contentNode as? InstantPageNode)?.updateIsVisible(self.internalIsVisible && self.internalParentVisible)
            }
        }
    }
    
    init(contentNode: ASDisplayNode) {
        self.contentNode = contentNode
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    override func layout() {
        super.layout()
        
        self.contentNode.frame = self.bounds
    }
    
    func updateHiddenMedia(_ media: InstantPageMedia?) {
        if let node = self.contentNode as? InstantPageNode {
            node.updateHiddenMedia(media: media)
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let node = self.contentNode as? InstantPageNode {
            return node.transitionNode(media: media)
        }
        return nil
    }
}

private final class InstantPageSlideshowPagerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let sourcePeerType: MediaAutoDownloadPeerType
    private let theme: InstantPageTheme
    private let webPage: TelegramMediaWebpage
    private let openMedia: (InstantPageMedia) -> Void
    private let longPressMedia: (InstantPageMedia) -> Void
    private let pageGap: CGFloat
    
    private let scrollView: UIScrollView
    
    private var items: [InstantPageMedia] = []
    private var itemNodes: [InstantPageSlideshowItemNode] = []
    private var ignoreCentralItemIndexUpdate = false
    private var centralItemIndex: Int? {
        didSet {
            if oldValue != self.centralItemIndex && !self.ignoreCentralItemIndexUpdate {
                //self.centralItemIndexUpdated(self.centralItemIndex)
            }
        }
    }
    
    private var containerLayout: ContainerViewLayout?
    
    var centralItemIndexUpdated: (Int?) -> Void = { _ in }
    
    var internalIsVisible: Bool = false {
        didSet {
            if self.internalIsVisible != oldValue {
                for node in self.itemNodes {
                    node.internalParentVisible = self.internalIsVisible
                }
            }
        }
    }
    
    init(context: AccountContext, sourcePeerType: MediaAutoDownloadPeerType, theme: InstantPageTheme, webPage: TelegramMediaWebpage, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, pageGap: CGFloat = 0.0) {
        self.context = context
        self.sourcePeerType = sourcePeerType
        self.theme = theme
        self.webPage = webPage
        self.openMedia = openMedia
        self.longPressMedia = longPressMedia
        self.pageGap = pageGap
        self.scrollView = UIScrollView()
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        super.init()
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = !pageGap.isZero
        self.scrollView.bounces = !pageGap.isZero
        self.scrollView.isPagingEnabled = true
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.scrollsToTop = false
        self.view.addSubview(self.scrollView)
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
        var previousCentralNodeHorizontalOffset: CGFloat?
        if let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            previousCentralNodeHorizontalOffset = self.scrollView.contentOffset.x - centralNode.frame.minX
        }
        
        self.scrollView.frame = CGRect(origin: CGPoint(x: -self.pageGap, y: 0.0), size: CGSize(width: layout.size.width + self.pageGap * 2.0, height: layout.size.height))
        
        for i in 0 ..< self.itemNodes.count {
            self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
            //self.itemNodes[i].containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if let previousCentralNodeHorizontalOffset = previousCentralNodeHorizontalOffset, let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            self.scrollView.contentOffset = CGPoint(x: centralNode.frame.minX + previousCentralNodeHorizontalOffset, y: 0.0)
        }
        
        self.updateItemNodes()
    }
    
    func centralItemNode() -> InstantPageSlideshowItemNode? {
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            return centralItemNode
        } else {
            return nil
        }
    }
    
    func replaceItems(_ items: [InstantPageMedia], centralItemIndex: Int?, keepFirst: Bool = false) {
        var keptItemNode: InstantPageSlideshowItemNode?
        for itemNode in self.itemNodes {
            if keepFirst && itemNode.index == 0 {
                keptItemNode = itemNode
            } else {
                itemNode.removeFromSupernode()
            }
        }
        self.itemNodes.removeAll()
        if let keptItemNode = keptItemNode {
            self.itemNodes.append(keptItemNode)
        }
        if let centralItemIndex = centralItemIndex, centralItemIndex >= 0 && centralItemIndex < items.count {
            self.centralItemIndex = centralItemIndex
        } else {
            self.centralItemIndex = nil
        }
        self.items = items
        
        self.updateItemNodes()
    }
    
    private func makeNodeForItem(at index: Int) -> InstantPageSlideshowItemNode {
        let media = self.items[index]
        let contentNode: ASDisplayNode
        if let _ = media.media as? TelegramMediaImage {
            contentNode = InstantPageImageNode(context: self.context, sourcePeerType: self.sourcePeerType, theme: self.theme, webPage: self.webPage, media: media, attributes: [], interactive: true, roundCorners: false, fit: false, openMedia: self.openMedia, longPressMedia: self.longPressMedia, activatePinchPreview: nil, pinchPreviewFinished: nil)
        } else if let _ = media.media as? TelegramMediaFile {
            contentNode = ASDisplayNode()
        } else {
            contentNode = ASDisplayNode()
        }
        
        let node = InstantPageSlideshowItemNode(contentNode: contentNode)
        
        node.index = index
        return node
    }
    
    private func visibleItemNode(at index: Int) -> InstantPageSlideshowItemNode? {
        for itemNode in self.itemNodes {
            if itemNode.index == index {
                return itemNode
            }
        }
        return nil
    }
    
    private func addVisibleItemNode(_ node: InstantPageSlideshowItemNode) {
        var added = false
        for i in 0 ..< self.itemNodes.count {
            if node.index < self.itemNodes[i].index {
                self.itemNodes.insert(node, at: i)
                added = true
                break
            }
        }
        if !added {
            self.itemNodes.append(node)
        }
        self.scrollView.addSubview(node.view)
    }
    
    private func removeVisibleItemNode(internalIndex: Int) {
        self.itemNodes[internalIndex].view.removeFromSuperview()
        self.itemNodes.remove(at: internalIndex)
    }
    
    private func updateItemNodes() {
        if self.items.isEmpty || self.containerLayout == nil {
            return
        }
        
        var resetOffsetToCentralItem = false
        if self.itemNodes.isEmpty {
            let node = self.makeNodeForItem(at: self.centralItemIndex ?? 0)
            node.frame = CGRect(origin: CGPoint(), size: scrollView.bounds.size)
            if let _ = self.containerLayout {
                //node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
            }
            self.addVisibleItemNode(node)
            self.centralItemIndex = node.index
            resetOffsetToCentralItem = true
        }
        
        var notifyCentralItemUpdated = false
        
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            if centralItemIndex != 0 {
                if self.visibleItemNode(at: centralItemIndex - 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex - 1)
                    node.frame = centralItemNode.frame.offsetBy(dx: -centralItemNode.frame.size.width - self.pageGap, dy: 0.0)
                    if let _ = self.containerLayout {
                        //node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            if centralItemIndex != items.count - 1 {
                if self.visibleItemNode(at: centralItemIndex + 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex + 1)
                    node.frame = centralItemNode.frame.offsetBy(dx: centralItemNode.frame.size.width + self.pageGap, dy: 0.0)
                    if let _ = self.containerLayout {
                        //node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            for i in 0 ..< self.itemNodes.count {
                self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
            }
            
            if resetOffsetToCentralItem {
                self.scrollView.contentOffset = CGPoint(x: centralItemNode.frame.minX - self.pageGap, y: 0.0)
            }
            
            if let centralItemCandidateNode = self.centralItemCandidate(), centralItemCandidateNode.index != centralItemIndex {
                for i in (0 ..< self.itemNodes.count).reversed() {
                    let node = self.itemNodes[i]
                    if node.index < centralItemCandidateNode.index - 1 || node.index > centralItemCandidateNode.index + 1 {
                        self.removeVisibleItemNode(internalIndex: i)
                    }
                }
                
                self.ignoreCentralItemIndexUpdate = true
                self.centralItemIndex = centralItemCandidateNode.index
                self.ignoreCentralItemIndexUpdate = false
                notifyCentralItemUpdated = true
                
                if centralItemCandidateNode.index != 0 {
                    if self.visibleItemNode(at: centralItemCandidateNode.index - 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index - 1)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: -centralItemCandidateNode.frame.size.width - self.pageGap, dy: 0.0)
                        if let _ = self.containerLayout {
                            //node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                if centralItemCandidateNode.index != items.count - 1 {
                    if self.visibleItemNode(at: centralItemCandidateNode.index + 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index + 1)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: centralItemCandidateNode.frame.size.width + self.pageGap, dy: 0.0)
                        if let _ = self.containerLayout {
                            //node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                let previousCentralCandidateHorizontalOffset = self.scrollView.contentOffset.x - centralItemCandidateNode.frame.minX
                
                for i in 0 ..< self.itemNodes.count {
                    self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
                }
                
                self.scrollView.contentOffset = CGPoint(x: centralItemCandidateNode.frame.minX + previousCentralCandidateHorizontalOffset, y: 0.0)
            }
            
            self.scrollView.contentSize = CGSize(width: CGFloat(self.itemNodes.count) * self.scrollView.bounds.size.width, height: self.scrollView.bounds.size.height)
        } else {
            assertionFailure()
        }
        
        for itemNode in self.itemNodes {
            //itemNode.centralityUpdated(isCentral: itemNode.index == self.centralItemIndex)
            //itemNode.visibilityUpdated(isVisible: self.scrollView.bounds.intersects(itemNode.frame))
            itemNode.internalIsVisible = self.scrollView.bounds.intersects(itemNode.frame)
        }
        
        if notifyCentralItemUpdated {
            self.centralItemIndexUpdated(self.centralItemIndex)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateItemNodes()
    }
    
    private func centralItemCandidate() -> InstantPageSlideshowItemNode? {
        let hotizontlOffset = self.scrollView.contentOffset.x + self.pageGap
        var closestNodeAndDistance: (Int, CGFloat)?
        for i in 0 ..< self.itemNodes.count {
            let node = self.itemNodes[i]
            let distance = abs(node.frame.minX - hotizontlOffset)
            if let currentClosestNodeAndDistance = closestNodeAndDistance {
                if distance < currentClosestNodeAndDistance.1 {
                    closestNodeAndDistance = (node.index, distance)
                }
            } else {
                closestNodeAndDistance = (node.index, distance)
            }
        }
        if let closestNodeAndDistance = closestNodeAndDistance {
            return self.visibleItemNode(at: closestNodeAndDistance.0)
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(_ media: InstantPageMedia?) {
        for node in self.itemNodes {
            node.updateHiddenMedia(media)
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        for node in self.itemNodes {
            if let transitionNode = node.transitionNode(media: media) {
                return transitionNode
            }
        }
        return nil
    }
}

final class InstantPageSlideshowNode: ASDisplayNode, InstantPageNode {
    var medias: [InstantPageMedia] = []
    
    private let pagerNode: InstantPageSlideshowPagerNode
    private let pageControlNode: PageControlNode
    
    init(context: AccountContext, sourcePeerType: MediaAutoDownloadPeerType, theme: InstantPageTheme, webPage: TelegramMediaWebpage, medias: [InstantPageMedia], openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void) {
        self.medias = medias
        
        self.pagerNode = InstantPageSlideshowPagerNode(context: context, sourcePeerType: sourcePeerType, theme: theme, webPage: webPage, openMedia: openMedia, longPressMedia: longPressMedia)
        self.pagerNode.replaceItems(medias, centralItemIndex: nil)
        
        self.pageControlNode = PageControlNode(dotColor: .white, inactiveDotColor: UIColor(white: 1.0, alpha: 0.5))
        self.pageControlNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.backgroundColor = theme.panelSecondaryColor
        self.clipsToBounds = true
        
        self.addSubnode(self.pagerNode)
        self.addSubnode(self.pageControlNode)
        self.pageControlNode.pagesCount = medias.count
        self.pageControlNode.setPage(0)
        self.pagerNode.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self, let index = index {
                strongSelf.pageControlNode.setPage(CGFloat(index))
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        self.pagerNode.frame = self.bounds
        self.pagerNode.containerLayoutUpdated(ContainerViewLayout(size: self.bounds.size, metrics: LayoutMetrics(), deviceMetrics: .unknown(screenSize: CGSize(), statusBarHeight: 0.0, onScreenNavigationHeight: nil), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
        
        self.pageControlNode.layer.transform = CATransform3DIdentity
        self.pageControlNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.bounds.size.height - 20.0), size: CGSize(width: self.bounds.size.width, height: 20.0))
        
        let maxWidth = self.bounds.width - 36.0;
        let size = self.pageControlNode.calculateSizeThatFits(self.bounds.size)
        if size.width > maxWidth
        {
            let scale = maxWidth / size.width
            self.pageControlNode.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.pagerNode.transitionNode(media: media)
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.pagerNode.updateHiddenMedia(media)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        self.pagerNode.internalIsVisible = isVisible
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.backgroundColor = theme.panelSecondaryColor
    }
}
