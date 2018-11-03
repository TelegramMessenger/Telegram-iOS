import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Display
import SafariServices

final class InstantPageControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    private var settings: InstantPagePresentationSettings?
    private var presentationTheme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    private var theme: InstantPageTheme?
    private var manualThemeOverride: InstantPageThemeType?
    private let getNavigationController: () -> NavigationController?
    private let present: (ViewController, Any?) -> Void
    private let pushController: (ViewController) -> Void
    private let openPeer: (PeerId) -> Void
    
    private var webPage: TelegramMediaWebpage?
    private var initialAnchor: String?
    
    private var containerLayout: ContainerViewLayout?
    private var setupScrollOffsetOnLayout: Bool = false
    
    private let statusBar: StatusBar
    private let navigationBar: InstantPageNavigationBar
    private let scrollNode: ASScrollNode
    private let scrollNodeHeader: ASDisplayNode
    private let scrollNodeFooter: ASDisplayNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private var textSelectionNode: LinkHighlightingNode?
    private var settingsNode: InstantPageSettingsNode?
    private var settingsDimNode: ASDisplayNode?
    
    var currentLayout: InstantPageLayout?
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithNodes: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileNode] = [:]
    var visibleItemsWithNodes: [Int: InstantPageNode] = [:]
    
    var currentWebEmbedHeights: [Int : CGFloat] = [:]
    var currentExpandedDetails: [Int : Bool]?
    var currentDetailsItems: [InstantPageDetailsItem] = []
    
    var previousContentOffset: CGPoint?
    var isDeceleratingBecauseOfDragging = false
    
    private let hiddenMediaDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let loadWebpageDisposable = MetaDisposable()
    
    private let updateLayoutDisposable = MetaDisposable()
    
    private var themeReferenceDate: Date?
    
    init(account: Account, settings: InstantPagePresentationSettings?, presentationTheme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, statusBar: StatusBar, getNavigationController: @escaping () -> NavigationController?, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, openPeer: @escaping (PeerId) -> Void, navigateBack: @escaping () -> Void) {
        self.account = account
        self.presentationTheme = presentationTheme
        self.dateTimeFormat = dateTimeFormat
        self.strings = strings
        self.settings = settings
        let themeReferenceDate = Date()
        self.themeReferenceDate = themeReferenceDate
        self.theme = settings.flatMap { settings in
            return instantPageThemeForType(instantPageThemeTypeForSettingsAndTime(presentationTheme: presentationTheme, settings: settings, time: themeReferenceDate), settings: settings)
        }
        
        self.statusBar = statusBar
        self.getNavigationController = getNavigationController
        self.present = present
        self.pushController = pushController
        self.openPeer = openPeer
        
        self.navigationBar = InstantPageNavigationBar(strings: strings)
        self.scrollNode = ASScrollNode()
        self.scrollNodeHeader = ASDisplayNode()
        self.scrollNodeHeader.backgroundColor = .black
        
        self.scrollNodeFooter = ASDisplayNode()
        self.scrollNodeFooter.backgroundColor = .black
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        if let theme = self.theme {
            self.backgroundColor = theme.pageBackgroundColor
            self.scrollNodeFooter.backgroundColor = theme.panelBackgroundColor
        }
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.scrollNodeHeader)
        self.scrollNode.addSubnode(self.scrollNodeFooter)
        self.addSubnode(self.navigationBar)
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.delegate = self
        
        self.navigationBar.back = navigateBack
        self.navigationBar.share = { [weak self] in
            if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                let shareController = ShareController(account: account, subject: .url(content.url))
                strongSelf.present(shareController, nil)
            }
        }
        self.navigationBar.settings = { [weak self] in
            if let strongSelf = self {
                strongSelf.presentSettings()
            }
        }
        self.navigationBar.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: -strongSelf.scrollNode.view.contentInset.top), animated: true)
            }
        }
    }
    
    deinit {
        self.hiddenMediaDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.loadWebpageDisposable.dispose()
    }
    
    func update(settings: InstantPagePresentationSettings, strings: PresentationStrings) {
        if self.settings != settings || self.strings !== strings {
            let previousSettings = self.settings
            var updateLayout = previousSettings == nil
            
            if let previousSettings = previousSettings {
                if previousSettings.themeType != settings.themeType {
                    self.themeReferenceDate = nil
                }
            }
            
            self.settings = settings
            let themeType = instantPageThemeTypeForSettingsAndTime(presentationTheme: self.presentationTheme, settings: settings, time: self.themeReferenceDate)
            let theme = instantPageThemeForType(themeType, settings: settings)
            self.theme = theme
            self.strings = strings
            
            self.settingsNode?.updateSettingsAndCurrentThemeType(settings: settings, type: themeType)
            
            var animated = false
            if let previousSettings = previousSettings {
                if previousSettings.themeType != settings.themeType || previousSettings.autoNightMode != settings.autoNightMode {
                    updateLayout = true
                    animated = true
                }
                if previousSettings.fontSize != settings.fontSize || previousSettings.forceSerif != settings.forceSerif {
                    animated = false
                    updateLayout = true
                }
            }
            
            self.backgroundColor = theme.pageBackgroundColor
            
            if updateLayout {
                if animated {
                    if let snapshotView = self.scrollNode.view.snapshotView(afterScreenUpdates: false) {
                        self.view.insertSubview(snapshotView, aboveSubview: self.scrollNode.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                
                self.updateLayout()
                
                self.scrollNodeFooter.backgroundColor = theme.panelBackgroundColor
                for (_, itemNode) in self.visibleItemsWithNodes {
                    itemNode.update(strings: strings, theme: theme)
                }
                
                self.updateVisibleItems()
                self.updateNavigationBar()
                
                self.recursivelyEnsureDisplaySynchronously(true)
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        recognizer.delaysTouchesBegan = false
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let currentLayout = strongSelf.currentLayout {
                    for item in currentLayout.items {
                        let frame = strongSelf.effectiveFrameForItem(item)
                        if frame.contains(point) {
                            if item is InstantPagePeerReferenceItem {
                                return .fail
                            } else if item is InstantPageAudioItem {
                                return .fail
                            } else if item is InstantPageArticleItem {
                                return .fail
                            } else if item is InstantPageFeedbackItem {
                                return .fail
                            } else if item is InstantPageDetailsItem {
                                return .fail
                            }
                            break
                        }
                    }
                }
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.scrollNode.view.addGestureRecognizer(recognizer)
    }
    
    func updateWebPage(_ webPage: TelegramMediaWebpage?, anchor: String?) {
        if self.webPage != webPage {
            if self.webPage != nil && self.currentLayout != nil {
                if let snaphotView = self.scrollNode.view.snapshotView(afterScreenUpdates: false) {
                    self.scrollNode.view.superview?.insertSubview(snaphotView, aboveSubview: self.scrollNode.view)
                    snaphotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snaphotView] _ in
                        snaphotView?.removeFromSuperview()
                    })
                }
            }
            
            self.setupScrollOffsetOnLayout = self.webPage == nil
            self.webPage = webPage
            self.initialAnchor = anchor
            
            self.currentLayout = nil
            self.updateLayout()
            
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            if let containerLayout = self.containerLayout {
                self.containerLayoutUpdated(containerLayout, navigationBarHeight: 0.0, transition: .immediate)
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
        if let settingsDimNode = self.settingsDimNode {
            transition.updateFrame(node: settingsDimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        if let settingsNode = self.settingsNode {
            settingsNode.updateLayout(layout: layout, transition: transition)
            transition.updateFrame(node: settingsNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        let maxBarHeight: CGFloat
        if !layout.safeInsets.top.isZero {
            maxBarHeight = layout.safeInsets.top + 34.0
        } else {
            maxBarHeight = (layout.statusBarHeight ?? 0.0) + 44.0
        }
        
        let scrollInsetTop = maxBarHeight
        
        let resetOffset = self.scrollNode.bounds.size.width.isZero || self.setupScrollOffsetOnLayout
        let widthUpdated = !self.scrollNode.bounds.size.width.isEqual(to: layout.size.width)
        
        var shouldUpdateVisibleItems = false
        if self.scrollNode.bounds.size != layout.size || !self.scrollNode.view.contentInset.top.isEqual(to: scrollInsetTop) {
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            self.scrollNodeHeader.frame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0), size: CGSize(width: layout.size.width, height: 2000.0))
            self.scrollNode.view.contentInset = UIEdgeInsetsMake(scrollInsetTop, 0.0, layout.intrinsicInsets.bottom, 0.0)
            if widthUpdated {
                self.updateLayout()
            }
            shouldUpdateVisibleItems = true
            self.updateNavigationBar()
        }
        if resetOffset {
            var contentOffset = CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top)
            if let anchor = self.initialAnchor, !anchor.isEmpty {
                if let items = self.currentLayout?.items {
                    self.setupScrollOffsetOnLayout = false
                    outer: for item in items {
                        if let item = item as? InstantPageAnchorItem, item.anchor == anchor {
                            contentOffset = CGPoint(x: 0.0, y: item.frame.origin.y - self.scrollNode.view.contentInset.top)
                            break outer
                        }
                    }
                }
            } else {
                self.setupScrollOffsetOnLayout = false
            }
            self.scrollNode.view.contentOffset = contentOffset
        }
        if shouldUpdateVisibleItems {
            self.updateVisibleItems()
        }
    }
    
    private func updateLayout() {
        guard let containerLayout = self.containerLayout, let webPage = self.webPage, let theme = self.theme else {
            return
        }
        
        let currentLayout = instantPageLayoutForWebPage(webPage, boundingWidth: containerLayout.size.width, safeInset: containerLayout.safeInsets.left, strings: self.strings, theme: theme, dateTimeFormat: self.dateTimeFormat, webEmbedHeights: self.currentWebEmbedHeights)
        
        for (_, tileNode) in self.visibleTiles {
            tileNode.removeFromSupernode()
        }
        self.visibleTiles.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: containerLayout.size.width)
        
        var currentDetailsItems: [InstantPageDetailsItem] = []
        var currentLayoutItemsWithNodes: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int : Int] = [:]
        
        var expandedDetails: [Int : Bool] = [:]
        
        var itemIndex = -1
        for item in currentLayout.items {
            if item.wantsNode {
                itemIndex += 1
                currentLayoutItemsWithNodes.append(item)
                if let group = item.distanceThresholdGroup() {
                    let count: Int
                    if let currentCount = distanceThresholdGroupCount[Int(group)] {
                        count = currentCount
                    } else {
                        count = 0
                    }
                    distanceThresholdGroupCount[Int(group)] = count + 1
                }
                
                if let detailsItem = item as? InstantPageDetailsItem {
                    expandedDetails[itemIndex] = detailsItem.initiallyExpanded
                }
            }
            if let item = item as? InstantPageDetailsItem {
                currentDetailsItems.append(item)
            }
        }
        
        if self.currentExpandedDetails == nil {
            self.currentExpandedDetails = expandedDetails
        }
        
        self.currentLayout = currentLayout
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithNodes = currentLayoutItemsWithNodes
        self.currentDetailsItems = currentDetailsItems
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
        
        self.scrollNode.view.contentSize = currentLayout.contentSize
        self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: currentLayout.contentSize.height), size: CGSize(width: containerLayout.size.width, height: 2000.0))
    }
    
    func updateVisibleItems(animated: Bool = false) {
        guard let theme = self.theme else {
            return
        }
        
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        let visibleBounds = self.scrollNode.view.bounds
        
        var topNode: ASDisplayNode?
        let topTileNode = topNode
        if let scrollSubnodes = self.scrollNode.subnodes {
            for node in scrollSubnodes.reversed() {
                if let node = node as? InstantPageTileNode {
                    topNode = node
                    break
                }
            }
        }
        
        var collapseOffset: CGFloat = 0.0
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        var itemIndex = -1
        var embedIndex = -1
        var detailsIndex = -1
        
        for item in self.currentLayoutItemsWithNodes {
            itemIndex += 1
            if item is InstantPageWebEmbedItem {
                embedIndex += 1
            }
            if item is InstantPageDetailsItem {
                detailsIndex += 1
            }
    
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }
            
            var itemFrame = item.frame.offsetBy(dx: 0.0, dy: -collapseOffset)
            var thresholdedItemFrame = itemFrame
            thresholdedItemFrame.origin.y -= itemThreshold
            thresholdedItemFrame.size.height += itemThreshold * 2.0
            
            if let expanded = self.currentExpandedDetails?[detailsIndex], !expanded {
                collapseOffset += itemFrame.height - 44.0
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: 44.0))
            }
            
            if visibleBounds.intersects(thresholdedItemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemNode = self.visibleItemsWithNodes[itemIndex]
                if let currentItemNode = itemNode {
                    if !item.matchesNode(currentItemNode) {
                        (currentItemNode as! ASDisplayNode).removeFromSupernode()
                        self.visibleItemsWithNodes.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    let itemIndex = itemIndex
                    let embedIndex = embedIndex
                    let detailsIndex = detailsIndex
                    if let itemNode = item.node(account: self.account, strings: self.strings, theme: theme, openMedia: { [weak self] media in
                        self?.openMedia(media)
                    }, openPeer: { [weak self] peerId in
                        self?.openPeer(peerId)
                    }, openUrl: { [weak self] url in
                        self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                        self?.updateWebEmbedHeight(embedIndex, height)
                    }, updateDetailsExpanded: { [weak self] expanded in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }) {
                        itemNode.frame = itemFrame
                        if let topNode = topNode {
                            self.scrollNode.insertSubnode(itemNode, aboveSubnode: topNode)
                        } else {
                            self.scrollNode.insertSubnode(itemNode, at: 0)
                        }
                        topNode = itemNode
                        self.visibleItemsWithNodes[itemIndex] = itemNode
                    }
                } else {
                    if (itemNode as! ASDisplayNode).frame != itemFrame {
                        let previousFrame = (itemNode as! ASDisplayNode).frame
                        (itemNode as! ASDisplayNode).frame = itemFrame
                        transition.animateFrame(node: (itemNode as! ASDisplayNode), from: previousFrame)
                    }
                }
            }
        }
        
        topNode = topTileNode
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            
            var tileFrame = tile.frame
            if tileIndex > 0 {
                tileFrame = tileFrame.offsetBy(dx: 0.0, dy: -collapseOffset)
            }
            var tileVisibleFrame = tileFrame
            tileVisibleFrame.origin.y -= 400.0
            tileVisibleFrame.size.height += 400.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) || animated {
                visibleTileIndices.insert(tileIndex)
                
                if visibleTiles[tileIndex] == nil {
                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: theme.pageBackgroundColor)
                    tileNode.frame = tile.frame
                    if let topNode = topNode {
                        self.scrollNode.insertSubnode(tileNode, aboveSubnode: topNode)
                    } else {
                        self.scrollNode.insertSubnode(tileNode, at: 0)
                    }
                    topNode = tileNode
                    self.visibleTiles[tileIndex] = tileNode
                } else {
                    if visibleTiles[tileIndex]!.frame != tileFrame {
                        let previousFrame = visibleTiles[tileIndex]!.frame
                        visibleTiles[tileIndex]!.frame = tileFrame
                        transition.animateFrame(node: visibleTiles[tileIndex]!, from: previousFrame)
                    }
                }
            }
        }
        
        if let currentLayout = self.currentLayout, collapseOffset > 0.0 {
            let effectiveContentHeight = currentLayout.contentSize.height - collapseOffset
            if effectiveContentHeight != self.scrollNode.view.contentSize.height {
                transition.animateView {
                    self.scrollNode.view.contentSize = CGSize(width: currentLayout.contentSize.width, height: effectiveContentHeight)
                }
                let previousFrame = self.scrollNodeFooter.frame
                self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: effectiveContentHeight), size: CGSize(width: previousFrame.width, height: 2000.0))
                transition.animateFrame(node: self.scrollNodeFooter, from: previousFrame)
            }
        }
        
        var removeTileIndices: [Int] = []
        for (index, tileNode) in self.visibleTiles {
            if !visibleTileIndices.contains(index) {
                removeTileIndices.append(index)
                tileNode.removeFromSupernode()
            }
        }
        for index in removeTileIndices {
            self.visibleTiles.removeValue(forKey: index)
        }
        
        var removeItemIndices: [Int] = []
        for (index, itemNode) in self.visibleItemsWithNodes {
            if !visibleItemIndices.contains(index) {
                removeItemIndices.append(index)
                (itemNode as! ASDisplayNode).removeFromSupernode()
            } else {
                var itemFrame = (itemNode as! ASDisplayNode).frame
                let itemThreshold: CGFloat = 200.0
                itemFrame.origin.y -= itemThreshold
                itemFrame.size.height += itemThreshold * 2.0
                itemNode.updateIsVisible(visibleBounds.intersects(itemFrame))
            }
        }
        for index in removeItemIndices {
            self.visibleItemsWithNodes.removeValue(forKey: index)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateVisibleItems()
        self.updateNavigationBar()
        self.previousContentOffset = self.scrollNode.view.contentOffset
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.isDeceleratingBecauseOfDragging = decelerate
        if !decelerate {
            self.updateNavigationBar(forceState: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.updateNavigationBar(forceState: true)
        self.isDeceleratingBecauseOfDragging = false
    }
    
    func updateNavigationBar(forceState: Bool = false) {
        guard let containerLayout = self.containerLayout else {
            return
        }
        
        let bounds = self.scrollNode.view.bounds
        let contentOffset = self.scrollNode.view.contentOffset
        
        let maxBarHeight: CGFloat
        let minBarHeight: CGFloat
        if !containerLayout.safeInsets.top.isZero {
            maxBarHeight = containerLayout.safeInsets.top + 34.0
            minBarHeight = containerLayout.safeInsets.top + 8.0
        } else {
            maxBarHeight = (containerLayout.statusBarHeight ?? 0.0) + 44.0
            minBarHeight = 20.0
        }
        
        var pageProgress: CGFloat = 0.0
        if !self.scrollNode.view.contentSize.height.isZero {
            let value = (contentOffset.y + self.scrollNode.view.contentInset.top) / (self.scrollNode.view.contentSize.height - bounds.size.height + self.scrollNode.view.contentInset.top)
            pageProgress = max(0.0, min(1.0, value))
        }
        
        let delta: CGFloat
        if let previousContentOffset = self.previousContentOffset {
            delta = contentOffset.y - previousContentOffset.y
        } else {
            delta = 0.0
        }
        self.previousContentOffset = contentOffset
        
        var transition: ContainedViewLayoutTransition = .immediate
        var navigationBarFrame = self.navigationBar.frame
        navigationBarFrame.size.width = bounds.size.width
        if navigationBarFrame.size.height.isZero {
            navigationBarFrame.size.height = maxBarHeight
        }
        if forceState {
            transition = .animated(duration: 0.3, curve: .spring)
            
            let transitionFactor = (navigationBarFrame.size.height - minBarHeight) / (maxBarHeight - minBarHeight)
            
            if contentOffset.y <= -self.scrollNode.view.contentInset.top || transitionFactor > 0.4 {
                navigationBarFrame.size.height = maxBarHeight
            } else {
                navigationBarFrame.size.height = minBarHeight
            }
        } else {
            if contentOffset.y <= -self.scrollNode.view.contentInset.top {
                navigationBarFrame.size.height = maxBarHeight
            } else {
                navigationBarFrame.size.height -= delta
            }
            navigationBarFrame.size.height = max(minBarHeight, min(maxBarHeight, navigationBarFrame.size.height))
        }
        
        let transitionFactor = (navigationBarFrame.size.height - minBarHeight) / (maxBarHeight - minBarHeight)
        
        if containerLayout.safeInsets.top.isZero {
            let statusBarAlpha = min(1.0, max(0.0, transitionFactor))
            transition.updateAlpha(node: self.statusBar, alpha: statusBarAlpha * statusBarAlpha)
            self.statusBar.verticalOffset = navigationBarFrame.size.height - maxBarHeight
        } else {
            transition.updateAlpha(node: self.statusBar, alpha: 1.0)
            self.statusBar.verticalOffset = 0.0
        }
        
        transition.updateFrame(node: self.navigationBar, frame: navigationBarFrame)
        self.navigationBar.updateLayout(size: navigationBarFrame.size, minHeight: minBarHeight, maxHeight: maxBarHeight, topInset: containerLayout.safeInsets.top, leftInset: containerLayout.safeInsets.left, rightInset: containerLayout.safeInsets.right, pageProgress: pageProgress, transition: transition)
        
        transition.animateView {
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: navigationBarFrame.size.height, left: 0.0, bottom: containerLayout.intrinsicInsets.bottom, right: 0.0)
        }
    }
    
    private func updateTouchesAtPoint(_ location: CGPoint?) {
        var rects: [CGRect]?
        if let location = location, let currentLayout = self.currentLayout {
            for item in currentLayout.items {
                if item.frame.contains(location) {
                    let itemNodeFrame = item.frame
                    var itemRects = item.linkSelectionRects(at: location.offsetBy(dx: -item.frame.minX, dy: -item.frame.minY))
                    var contentOffset = CGPoint()
                    if let item = item as? InstantPageTableItem {
                        contentOffset = tableContentOffset(item: item)
                    }
                    
                    for i in 0 ..< itemRects.count {
                        itemRects[i] = itemRects[i].offsetBy(dx: itemNodeFrame.minX - contentOffset.x, dy: itemNodeFrame.minY).insetBy(dx: -2.0, dy: -2.0)
                    }
                    if !itemRects.isEmpty {
                        rects = itemRects
                        break
                    }
                }
            }
        }
        
        if let rects = rects {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: UIColor(rgb: 0x007be8).withAlphaComponent(0.4))
                linkHighlightingNode.isUserInteractionEnabled = false
                self.linkHighlightingNode = linkHighlightingNode
                self.scrollNode.addSubnode(linkHighlightingNode)
            }
            linkHighlightingNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
    }
    
    private func tableContentOffset(item: InstantPageTableItem) -> CGPoint {
        var contentOffset = CGPoint()
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let itemNode = itemNode as? InstantPageTableNode, itemNode.item === item {
                contentOffset = itemNode.contentOffset
                break
            }
        }
        return contentOffset
    }
    
    private func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        let layoutOrigin = item.frame.origin
        var origin = layoutOrigin
        
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if !expanded && layoutOrigin.y >= item.frame.maxY {
                let offset = 44.0 - item.frame.height
                origin.y += offset
            }
        }
        
        if let item = item as? InstantPageDetailsItem {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: expanded ? item.frame.height : 44.0))
        } else {
            return CGRect(origin: origin, size: item.frame.size)
        }
    }
    
    private func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if let currentLayout = self.currentLayout {
            for item in currentLayout.items {
                let frame = self.effectiveFrameForItem(item)
                if frame.contains(location) {
                    if let item = item as? InstantPageTextItem, item.selectable {
                        return (item, CGPoint())
                    } else if let item = item as? InstantPageTableItem {
                        let contentOffset = tableContentOffset(item: item)
                        if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -item.frame.minX + contentOffset.x, dy: -item.frame.minY)) {
                            return (textItem, item.frame.origin.offsetBy(dx: parentOffset.x - contentOffset.x, dy: parentOffset.y))
                        }
                    } else if let item = item as? InstantPageDetailsItem {
                        
                    }
                }
            }
        }
        return nil
    }
    
    private func urlForTapLocation(_ location: CGPoint) -> InstantPageUrlItem? {
        if let (item, parentOffset) = self.textItemAtLocation(location) {
            return item.urlAttribute(at: location.offsetBy(dx: -item.frame.minX - parentOffset.x, dy: -item.frame.minY - parentOffset.y))
        }
        return nil
    }
    
    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let url = self.urlForTapLocation(location) {
                                self.openUrl(url)
                            }
                        case .longTap:
                            if let url = self.urlForTapLocation(location) {
                                let canOpenIn = availableOpenInOptions(applicationContext: self.account.telegramApplicationContext, item: .url(url: url.url)).count > 1
                                let openText = canOpenIn ? self.strings.Conversation_FileOpenIn : self.strings.Conversation_LinkDialogOpen
                                let actionSheet = ActionSheetController(presentationTheme: self.presentationTheme)
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                    ActionSheetTextItem(title: url.url),
                                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let strongSelf = self {
                                            strongSelf.openUrl(url)
                                        }
                                    }),
                                    ActionSheetButtonItem(title: self.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        UIPasteboard.general.string = url.url
                                    }),
                                    ActionSheetButtonItem(title: self.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let link = URL(string: url.url) {
                                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                        }
                                    })
                                ]), ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: self.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])])
                                self.present(actionSheet, nil)
                            } else if let (item, parentOffset) = self.textItemAtLocation(location) {
                                let textNodeFrame = effectiveFrameForItem(item)
                                var itemRects = item.lineRects()
                                for i in 0 ..< itemRects.count {
                                    itemRects[i] = itemRects[i].offsetBy(dx: parentOffset.x + textNodeFrame.minX, dy: parentOffset.y + textNodeFrame.minY).insetBy(dx: -2.0, dy: -2.0)
                                }
                                self.updateTextSelectionRects(itemRects, text: item.plainText())
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    private func updateTextSelectionRects(_ rects: [CGRect], text: String?) {
        if let text = text, !rects.isEmpty {
            let textSelectionNode: LinkHighlightingNode
            if let current = self.textSelectionNode {
                textSelectionNode = current
            } else {
                textSelectionNode = LinkHighlightingNode(color: UIColor.lightGray.withAlphaComponent(0.4))
                textSelectionNode.isUserInteractionEnabled = false
                self.textSelectionNode = textSelectionNode
                self.scrollNode.addSubnode(textSelectionNode)
            }
            textSelectionNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
            textSelectionNode.updateRects(rects)
            
            var coveringRect = rects[0]
            for i in 1 ..< rects.count {
                coveringRect = coveringRect.union(rects[i])
            }
            
            let controller = ContextMenuController(actions: [ContextMenuAction(content: .text(self.strings.Conversation_ContextMenuCopy), action: {
                UIPasteboard.general.string = text
            }), ContextMenuAction(content: .text(self.strings.Conversation_ContextMenuShare), action: { [weak self] in
                if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                    strongSelf.present(ShareController(account: strongSelf.account, subject: .quote(text: text, url: content.url)), nil)
                }
            })])
            controller.dismissed = { [weak self] in
                self?.updateTextSelectionRects([], text: nil)
            }
            self.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (strongSelf.scrollNode, coveringRect.insetBy(dx: -3.0, dy: -3.0), strongSelf, strongSelf.bounds)
                } else {
                    return nil
                }
            }))
            textSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
        } else if let textSelectionNode = self.textSelectionNode {
            self.textSelectionNode = nil
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.removeFromSupernode()
            })
        }
    }
    
    private func openUrl(_ url: InstantPageUrlItem) {
        guard let items = self.currentLayout?.items else {
            return
        }
        
        if let webPage = self.webPage, url.webpageId == webPage.id, let anchorRange = url.url.range(of: "#") {
            let anchor = url.url[anchorRange.upperBound...]
            if !anchor.isEmpty {
                for item in items {
                    if let item = item as? InstantPageAnchorItem, item.anchor == anchor {
                        self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: item.frame.origin.y - self.scrollNode.view.contentInset.top), animated: true)
                        return
                    }
                }
            }
        }
        
        self.resolveUrlDisposable.set((resolveUrl(account: self.account, url: url.url) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                switch result {
                    case let .externalUrl(externalUrl):
                        if let webpageId = url.webpageId {
                            var anchor: String?
                            if let anchorRange = externalUrl.range(of: "#") {
                                anchor = String(externalUrl[anchorRange.upperBound...])
                            }
                            strongSelf.loadWebpageDisposable.set((webpagePreview(account: strongSelf.account, url: externalUrl, webpageId: webpageId) |> deliverOnMainQueue).start(next: { webpage in
                                if let strongSelf = self, let webpage = webpage {
                                    strongSelf.pushController(InstantPageController(account: strongSelf.account, webPage: webpage, anchor: anchor))
                                }
                            }))
                        } else {
                            openExternalUrl(account: strongSelf.account, url: externalUrl, presentationData: strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: strongSelf.getNavigationController(), dismissInput: {
                                self?.view.endEditing(true)
                            })
                        }
                    default:
                        openResolvedUrl(result, account: strongSelf.account, navigationController: strongSelf.getNavigationController(), openPeer: { peerId, navigation in
                            switch navigation {
                                case let .chat(_, messageId):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), messageId: messageId)
                                    }
                                case let .withBotStartPayload(botStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), botStart: botStart, keepStack: .always)
                                    }
                                case .info:
                                    let _ = (strongSelf.account.postbox.loadedPeerWithId(peerId)
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self {
                                            if let controller = peerInfoController(account: strongSelf.account, peer: peer) {
                                                strongSelf.getNavigationController()?.pushViewController(controller)
                                            }
                                        }
                                    })
                                default:
                                    break
                            }
                        }, present: { c, a in
                            self?.present(c, a)
                        }, dismissInput: {
                            self?.view.endEditing(true)
                        })
                }
            }
        }))
    }
    
    private func openMedia(_ media: InstantPageMedia) {
        guard let items = self.currentLayout?.items, let webPage = self.webPage else {
            return
        }
        
        if let map = media.media as? TelegramMediaMap {
            let controller = legacyLocationController(message: nil, mapMedia: map, account: self.account, modal: false, openPeer: { _ in }, sendLiveLocation: { _, _ in }, stopLiveLocation: { }, openUrl: { _ in })
            self.pushController(controller)
            return
        }
        
        if let file = media.media as? TelegramMediaFile, (file.isVoice || file.isMusic) {
            var medias: [InstantPageMedia] = []
            var initialIndex = 0
            for item in items {
                for itemMedia in item.medias {
                    if let itemFile = itemMedia.media as? TelegramMediaFile, (itemFile.isVoice || itemFile.isMusic) {
                        if itemMedia.index == media.index {
                            initialIndex = medias.count
                        }
                        medias.append(itemMedia)
                    }
                }
            }
            self.account.telegramApplicationContext.mediaManager?.setPlaylist(InstantPageMediaPlaylist(webPage: webPage, items: medias, initialItemIndex: initialIndex), type: file.isVoice ? .voice : .music)
            return
        }
        
        var medias: [InstantPageMedia] = []
        for item in items {
            medias.append(contentsOf: item.medias)
        }
        
        medias = medias.filter {
            $0.media is TelegramMediaImage
        }
        
        var entries: [InstantPageGalleryEntry] = []
        for media in medias {
            entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, location: InstantPageGalleryEntryLocation(position: Int32(entries.count), totalCount: Int32(medias.count))))
        }
        
        var centralIndex: Int?
        for i in 0 ..< entries.count {
            if entries[i].media == media {
                centralIndex = i
                break
            }
        }
        
        if let centralIndex = centralIndex {
            let controller = InstantPageGalleryController(account: self.account, webPage: webPage, entries: entries, centralIndex: centralIndex, replaceRootController: { _, _ in
            }, baseNavigationController: self.getNavigationController())
            self.hiddenMediaDisposable.set((controller.hiddenMedia |> deliverOnMainQueue).start(next: { [weak self] entry in
                if let strongSelf = self {
                    for (_, itemNode) in strongSelf.visibleItemsWithNodes {
                        itemNode.updateHiddenMedia(media: entry?.media)
                    }
                }
            }))
            self.present(controller, InstantPageGalleryControllerPresentationArguments(transitionArguments: { [weak self] entry -> GalleryTransitionArguments? in
                if let strongSelf = self {
                    for (_, itemNode) in strongSelf.visibleItemsWithNodes {
                        if let transitionNode = itemNode.transitionNode(media: entry.media) {
                            return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { _ in
                            })
                        }
                    }
                }
                return nil
            }))
        }
    }
    
    private func updateWebEmbedHeight(_ index: Int, _ height: CGFloat) {
        let currentHeight = self.currentWebEmbedHeights[index]
        if height != currentHeight {
            if let currentHeight = currentHeight, currentHeight > height {
                return
            }
            self.currentWebEmbedHeights[index] = height
            
            let signal: Signal<Void, NoError> = (.complete() |> delay(0.08, queue: Queue.mainQueue()))
            self.updateLayoutDisposable.set(signal.start(completed: { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateLayout()
                    strongSelf.updateVisibleItems()
                }
            }))
        }
    }
    
    private func updateDetailsExpanded(_ index: Int, _ expanded: Bool) {
        if var currentExpandedDetails = self.currentExpandedDetails {
            currentExpandedDetails[index] = expanded
            self.currentExpandedDetails = currentExpandedDetails
        }
        self.updateVisibleItems(animated: true)
    }
    
    private func presentSettings() {
        guard let settings = self.settings, let containerLayout = self.containerLayout else {
            return
        }
        if self.settingsNode == nil {
            let settingsNode = InstantPageSettingsNode(strings: self.strings, settings: settings, currentThemeType: instantPageThemeTypeForSettingsAndTime(presentationTheme: self.presentationTheme, settings: settings, time: self.themeReferenceDate), applySettings: { [weak self] settings in
                if let strongSelf = self {
                    strongSelf.update(settings: settings, strings: strongSelf.strings)
                    let _ = updateInstantPagePresentationSettingsInteractively(postbox: strongSelf.account.postbox, { _ in
                        return settings
                    }).start()
                }
            }, openInSafari: { [weak self] in
                if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                    strongSelf.account.telegramApplicationContext.applicationBindings.openUrl(content.url)
                }
            })
            self.addSubnode(settingsNode)
            self.settingsNode = settingsNode
            
            let settingsDimNode = ASDisplayNode()
            settingsDimNode.backgroundColor = UIColor(rgb: 0, alpha: 0.1)
            settingsDimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(settingsDimTapped(_:))))
            self.insertSubnode(settingsDimNode, belowSubnode: self.navigationBar)
            self.settingsDimNode = settingsDimNode
            
            settingsDimNode.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
            
            settingsNode.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
            settingsNode.updateLayout(layout: containerLayout, transition: .immediate)
            settingsNode.animateIn()
            settingsDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
            self.navigationBar.updateDimmed(true, transition: transition)
            transition.updateAlpha(node: self.statusBar, alpha: 0.5)
        }
    }
    
    @objc func settingsDimTapped(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let settingsNode = self.settingsNode {
                self.settingsNode = nil
                settingsNode.animateOut(completion: { [weak settingsNode] in
                    settingsNode?.removeFromSupernode()
                })
            }
            
            if let settingsDimNode = self.settingsDimNode {
                self.settingsDimNode = nil
                settingsDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak settingsDimNode] _ in
                    settingsDimNode?.removeFromSupernode()
                })
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
            self.navigationBar.updateDimmed(false, transition: transition)
            transition.updateAlpha(node: self.statusBar, alpha: 1.0)
        }
    }
}
