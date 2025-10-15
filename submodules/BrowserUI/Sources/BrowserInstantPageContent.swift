import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import InstantPageUI
import UndoUI
import TranslateUI
import ContextUI
import Pasteboard
import SaveToCameraRoll
import ShareController
import SafariServices
import LocationUI
import OpenInExternalAppUI
import GalleryUI

final class BrowserInstantPageContent: UIView, BrowserContent, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var theme: InstantPageTheme
    private var settings: InstantPagePresentationSettings = .defaultSettings
    private let sourceLocation: InstantPageSourceLocation
    private let preloadedResouces: [Any]?
    private var originalContent: BrowserContent?
    private let url: String
    
    private var webPage: (webPage: TelegramMediaWebpage, instantPage: InstantPage?)?
    
    let uuid: UUID
    
    var currentState: BrowserContentState {
        return self._state
    }
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
        
    private var initialAnchor: String?
    private var pendingAnchor: String?
    private var initialState: InstantPageStoredState?
    
    private let wrapperNode: ASDisplayNode
    fileprivate let scrollNode: ASScrollNode
    private let scrollNodeFooter: ASDisplayNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private var textSelectionNode: LinkHighlightingNode?
    
    var currentLayout: InstantPageLayout?
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithNodes: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileNode] = [:]
    var visibleItemsWithNodes: [Int: InstantPageNode] = [:]
    
    var currentWebEmbedHeights: [Int : CGFloat] = [:]
    var currentExpandedDetails: [Int : Bool]?
    var currentDetailsItems: [InstantPageDetailsItem] = []
    
    var currentAccessibilityAreas: [AccessibilityAreaNode] = []
    
    var pushContent: (BrowserScreen.Subject, BrowserContent?) -> Void = { _, _ in }
    var restoreContent: (BrowserContent) -> Void = { _ in }
    var openAppUrl: (String) -> Void = { _ in }
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    var minimize: () -> Void = { }
    var close: () -> Void = { }
    
    var openPeer: (EnginePeer) -> Void = { _ in }
    
    var present: (ViewController, Any?) -> Void = { _, _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    var push: (ViewController) -> Void = { _ in }
    var getNavigationController: () -> NavigationController? = { return nil }
    
    private var webpageDisposable: Disposable?
    private let hiddenMediaDisposable = MetaDisposable()
    private let loadWebpageDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let updateLayoutDisposable = MetaDisposable()
        
    private let loadProgress = ValuePromise<CGFloat>(1.0, ignoreRepeated: true)
    private let readingProgress = ValuePromise<CGFloat>(1.0, ignoreRepeated: true)

    private var containerLayout: (size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets)?
    private var setupScrollOffsetOnLayout = false
    
    init(context: AccountContext, presentationData: PresentationData, webPage: TelegramMediaWebpage, anchor: String?, url: String, sourceLocation: InstantPageSourceLocation, preloadedResouces: [Any]?, originalContent: BrowserContent? = nil) {
        self.context = context
        var instantPage: InstantPage?
        if case let .Loaded(content) = webPage.content {
            instantPage = content.instantPage?._parse()
        }
        self.webPage = (webPage, instantPage)
        self.presentationData = presentationData
        self.theme = instantPageThemeForType(presentationData.theme.overallDarkAppearance ? .dark : .light, settings: .defaultSettings)
        self.sourceLocation = sourceLocation
        self.preloadedResouces = preloadedResouces
        self.originalContent = originalContent
        self.url = url
        self.initialAnchor = anchor
        
        self.uuid = UUID()
        
        let title: String
        if case let .Loaded(content) = webPage.content {
            title = content.title ?? ""
        } else {
            title = ""
        }
        
        let isInnerInstantViewEnabled = originalContent != nil
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, readingProgress: 0.0, contentType: .instantPage, isInnerInstantViewEnabled: isInnerInstantViewEnabled)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        self.wrapperNode = ASDisplayNode()
        self.scrollNode = ASScrollNode()
        self.scrollNode.backgroundColor = self.theme.pageBackgroundColor
        
        self.scrollNodeFooter = ASDisplayNode()
        self.scrollNodeFooter.backgroundColor = self.theme.panelBackgroundColor
        
        super.init(frame: .zero)
        
        self.statePromise.set(.single(self._state)
        |> then(
            combineLatest(
                self.loadProgress.get(),
                self.readingProgress.get()
            )
            |> map { estimatedProgress, readingProgress in
                return BrowserContentState(title: title, url: url, estimatedProgress: estimatedProgress, readingProgress: readingProgress, contentType: .instantPage, isInnerInstantViewEnabled: isInnerInstantViewEnabled)
            }
        ))
        
        self.addSubnode(self.wrapperNode)
        self.wrapperNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.scrollNodeFooter)
        
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.delegate = self
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        recognizer.delaysTouchesBegan = false
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                return strongSelf.tapActionAtPoint(point)
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.scrollNode.view.addGestureRecognizer(recognizer)
        
        self.webpageDisposable = (actualizedWebpage(account: context.account, webpage: webPage) |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            self.updateWebPage(result, anchor: self.initialAnchor)
        })
    }
    
    deinit {
        self.webpageDisposable?.dispose()
        self.hiddenMediaDisposable.dispose()
        self.loadWebpageDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.updateLayoutDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.theme = instantPageThemeForType(presentationData.theme.overallDarkAppearance ? .dark : .light, settings: self.settings)
        self.updatePageLayout()
        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
    }
    
    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
        if let currentLayout = self.currentLayout {
            for item in currentLayout.items {
                let frame = self.effectiveFrameForItem(item)
                if frame.contains(point) {
                    if item is InstantPagePeerReferenceItem {
                        return .fail
                    } else if item is InstantPageAudioItem {
                        return .fail
                    } else if item is InstantPageArticleItem {
                        return .fail
                    } else if item is InstantPageFeedbackItem {
                        return .fail
                    } else if let item = item as? InstantPageDetailsItem {
                        for (_, itemNode) in self.visibleItemsWithNodes {
                            if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
                                return itemNode.tapActionAtPoint(point.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY))
                            }
                        }
                    }
                    if !(item is InstantPageImageItem || item is InstantPagePlayableVideoItem) {
                        break
                    }
                }
            }
        }
        return .waitForSingleTap
    }
    
    private func updateTouchesAtPoint(_ location: CGPoint?) {
        var rects: [CGRect]?
        if let location = location, let currentLayout = self.currentLayout {
            for item in currentLayout.items {
                let itemFrame = self.effectiveFrameForItem(item)
                if itemFrame.contains(location) {
                    var contentOffset = CGPoint()
                    if let item = item as? InstantPageScrollableItem {
                        contentOffset = self.scrollableContentOffset(item: item)
                    }
                    var itemRects = item.linkSelectionRects(at: location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY))
                    
                    for i in 0 ..< itemRects.count {
                        itemRects[i] = itemRects[i].offsetBy(dx: itemFrame.minX - contentOffset.x, dy: itemFrame.minY).insetBy(dx: -2.0, dy: -2.0)
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
                let highlightColor = self.theme.linkHighlightColor
                linkHighlightingNode = LinkHighlightingNode(color: highlightColor)
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
    
    private func updateWebPage(_ webPage: TelegramMediaWebpage?, anchor: String?, state: InstantPageStoredState? = nil) {
        if self.webPage?.webPage != webPage {
            if self.webPage != nil && self.currentLayout != nil {
                if let snapshotView = self.scrollNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = self.scrollNode.frame
                    self.scrollNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.scrollNode.view)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
            
            self.setupScrollOffsetOnLayout = self.webPage == nil
            if let webPage {
                var instantPage: InstantPage?
                if case let .Loaded(content) = webPage.content {
                    instantPage = content.instantPage?._parse()
                }
                self.webPage = (webPage, instantPage)
            } else {
                self.webPage = nil
            }
            if let anchor = anchor {
                self.initialAnchor = anchor.removingPercentEncoding
            } else if let state = state {
                self.initialState = state
                if !state.details.isEmpty {
                    var storedExpandedDetails: [Int: Bool] = [:]
                    for state in state.details {
                        storedExpandedDetails[Int(clamping: state.index)] = state.expanded
                    }
                    self.currentExpandedDetails = storedExpandedDetails
                }
            }
            self.currentLayout = nil
            self.updatePageLayout()
            
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            self.requestLayout(transition: .immediate)
            
            if let webPage = webPage, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                self.loadProgress.set(1.0)
                
                if let anchor = self.pendingAnchor {
                    self.pendingAnchor = nil
                    self.scrollToAnchor(anchor)
                }
            }
        }
    }
    
    private func requestLayout(transition: ContainedViewLayoutTransition) {
        guard let (size, insets, fullInsets) = self.containerLayout else {
            return
        }
        self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: .zero, transition: transition)
    }
    
    func reload() {
    }
    
    func stop() {
    }
    
    func navigateBack() {
        
    }
    
    func navigateForward() {
        
    }
    
    func navigateTo(historyItem: BrowserContentState.HistoryItem) {
        
    }
    
    var currentFontState = BrowserPresentationState.FontState(size: 100, isSerif: false)
    func updateFontState(_ state: BrowserPresentationState.FontState) {
        self.currentFontState = state
        
        let fontSize: InstantPagePresentationFontSize
        switch state.size {
        case 50:
            fontSize = .xxsmall
        case 75:
            fontSize = .xsmall
        case 85:
            fontSize = .small
        case 100:
            fontSize = .standard
        case 115:
            fontSize = .large
        case 125:
            fontSize = .xlarge
        case 150:
            fontSize = .xxlarge
        default:
            fontSize = .standard
        }
        
        self.settings = InstantPagePresentationSettings(
            themeType: self.presentationData.theme.overallDarkAppearance ? .dark : .light,
            fontSize: fontSize,
            forceSerif: state.isSerif,
            autoNightMode: false,
            ignoreAutoNightModeUntil: 0
        )
        self.theme = instantPageThemeForType(self.presentationData.theme.overallDarkAppearance ? .dark : .light, settings: self.settings)
        self.updatePageLayout()
        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
    }
    
    func toggleInstantView(_ enabled: Bool) {
        if !enabled, let originalContent = self.originalContent {
            self.restoreContent(originalContent)
        }
    }
        
    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
        
    }
    
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?) {
        
    }
    
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?) {
        
    }
    
    func scrollToTop() {
        let scrollView = self.scrollNode.view
        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: true)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: safeInsets, transition: transition.containedViewLayoutTransition)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (size, insets, fullInsets)
        
        var updateVisibleItems = false
        let resetContentOffset = self.scrollNode.bounds.size.width.isZero || self.setupScrollOffsetOnLayout || !(self.initialAnchor ?? "").isEmpty
        
        var scrollInsets = insets
        scrollInsets.top = 0.0
        if self.scrollNode.view.contentInset != scrollInsets {
            self.scrollNode.view.contentInset = scrollInsets
            self.scrollNode.view.scrollIndicatorInsets = scrollInsets
        }
        
        self.wrapperNode.frame = CGRect(origin: .zero, size: size)
        
        let scrollFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top))
        let scrollFrameUpdated = self.scrollNode.bounds.size != scrollFrame.size
        if scrollFrameUpdated {
            let widthUpdated = self.scrollNode.bounds.size.width != scrollFrame.width
            self.scrollNode.frame = scrollFrame
            if widthUpdated {
                self.updatePageLayout()
            }
            updateVisibleItems = true
        }
        
        if resetContentOffset {
            var didSetScrollOffset = false
            var contentOffset = CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top)
            if let state = self.initialState {
                didSetScrollOffset = true
                contentOffset = CGPoint(x: 0.0, y: CGFloat(state.contentOffset))
            } else if let anchor = self.initialAnchor, !anchor.isEmpty {
                self.initialAnchor = nil
                if let items = self.currentLayout?.items {
                    didSetScrollOffset = true
                    if let (item, lineOffset, _, _) = self.findAnchorItem(anchor, items: items) {
                        contentOffset = CGPoint(x: 0.0, y: item.frame.minY + lineOffset - self.scrollNode.view.contentInset.top)
                    }
                }
            } else {
                didSetScrollOffset = true
            }
            self.scrollNode.view.contentOffset = contentOffset
            if didSetScrollOffset {
                //update scroll event
                if self.currentLayout != nil {
                    self.setupScrollOffsetOnLayout = false
                }
            }
        }
        
        if updateVisibleItems {
            self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
        }
    }
    
    private func updatePageLayout() {
        guard let (size, insets, _) = self.containerLayout, let (webPage, instantPage) = self.webPage else {
            return
        }
        
        let currentLayout = instantPageLayoutForWebPage(webPage, instantPage: instantPage, userLocation: self.sourceLocation.userLocation, boundingWidth: size.width, safeInset: insets.left, strings: self.presentationData.strings, theme: self.theme, dateTimeFormat: self.presentationData.dateTimeFormat, webEmbedHeights: self.currentWebEmbedHeights)
        
        for (_, tileNode) in self.visibleTiles {
            tileNode.removeFromSupernode()
        }
        self.visibleTiles.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: size.width)
        
        var currentDetailsItems: [InstantPageDetailsItem] = []
        var currentLayoutItemsWithNodes: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int : Int] = [:]
        
        var expandedDetails: [Int : Bool] = [:]
        
        var detailsIndex = -1
        for item in currentLayout.items {
            if item.wantsNode {
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
                    detailsIndex += 1
                    expandedDetails[detailsIndex] = detailsItem.initiallyExpanded
                    currentDetailsItems.append(detailsItem)
                }
            }
        }
        
        if var currentExpandedDetails = self.currentExpandedDetails {
            for (index, expanded) in expandedDetails {
                if currentExpandedDetails[index] == nil {
                    currentExpandedDetails[index] = expanded
                }
            }
            self.currentExpandedDetails = currentExpandedDetails
        } else {
            self.currentExpandedDetails = expandedDetails
        }
        
        let accessibilityAreas = instantPageAccessibilityAreasFromLayout(currentLayout, boundingWidth: size.width)
        
        self.currentLayout = currentLayout
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithNodes = currentLayoutItemsWithNodes
        self.currentDetailsItems = currentDetailsItems
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
        
        for areaNode in self.currentAccessibilityAreas {
            areaNode.removeFromSupernode()
        }
        for areaNode in accessibilityAreas {
            self.scrollNode.addSubnode(areaNode)
        }
        self.currentAccessibilityAreas = accessibilityAreas
        
        self.scrollNode.view.contentSize = currentLayout.contentSize
        self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: currentLayout.contentSize.height), size: CGSize(width: size.width, height: 2000.0))
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
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
        
        var previousDetailsNode: InstantPageDetailsNode?
        
        for item in self.currentLayoutItemsWithNodes {
            itemIndex += 1
            if item is InstantPageWebEmbedItem {
                embedIndex += 1
            }
            if let imageItem = item as? InstantPageImageItem, imageItem.media.media._asMedia() is TelegramMediaWebpage {
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
            
            if let detailsItem = item as? InstantPageDetailsItem, let expanded = self.currentExpandedDetails?[detailsIndex] {
                let height = expanded ? self.effectiveSizeForDetails(detailsItem).height : detailsItem.titleHeight
                collapseOffset += itemFrame.height - height
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: height))
            }
            
            if visibleBounds.intersects(thresholdedItemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemNode = self.visibleItemsWithNodes[itemIndex]
                if let currentItemNode = itemNode {
                    if !item.matchesNode(currentItemNode) {
                        currentItemNode.removeFromSupernode()
                        self.visibleItemsWithNodes.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    let itemIndex = itemIndex
                    let embedIndex = embedIndex
                    let detailsIndex = detailsIndex
                    if let newNode = item.node(context: self.context, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, theme: self.theme, sourceLocation: self.sourceLocation, openMedia: { [weak self] media in
                        self?.openMedia(media)
                    }, longPressMedia: { [weak self] media in
                        self?.longPressMedia(media)
                    }, activatePinchPreview: { [weak self] sourceNode in
                        self?.activatePinchPreview(sourceNode: sourceNode)
                    }, pinchPreviewFinished: { [weak self] itemNode in
                        self?.pinchPreviewFinished(itemNode: itemNode)
                    }, openPeer: { [weak self] peerId in
                        self?.openPeer(peerId)
                    }, openUrl: { [weak self] url in
                        self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                        self?.updateWebEmbedHeight(embedIndex, height)
                    }, updateDetailsExpanded: { [weak self] expanded in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }, currentExpandedDetails: self.currentExpandedDetails, getPreloadedResource: { [weak self] url in
                        return self?.getPreloadedResource(url)
                    }) {
                        newNode.frame = itemFrame
                        newNode.updateLayout(size: itemFrame.size, transition: transition)
                        if let topNode = topNode {
                            self.scrollNode.insertSubnode(newNode, aboveSubnode: topNode)
                        } else {
                            self.scrollNode.insertSubnode(newNode, at: 0)
                        }
                        topNode = newNode
                        self.visibleItemsWithNodes[itemIndex] = newNode
                        itemNode = newNode
                        
                        if let itemNode = itemNode as? InstantPageDetailsNode {
                            itemNode.requestLayoutUpdate = { [weak self] animated in
                                if let strongSelf = self {
                                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.scrollNode.view.bounds, animated: animated)
                                }
                            }
                            
                            if let previousDetailsNode = previousDetailsNode {
                                if itemNode.frame.minY - previousDetailsNode.frame.maxY < 1.0 {
                                    itemNode.previousNode = previousDetailsNode
                                }
                            }
                            previousDetailsNode = itemNode
                        }
                    }
                } else {
                    if let itemNode = itemNode, itemNode.frame != itemFrame {
                        transition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(size: itemFrame.size, transition: transition)
                    }
                }
                
                if let itemNode = itemNode as? InstantPageDetailsNode {
                    itemNode.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY), animated: animated)
                }
            }
        }
        
        topNode = topTileNode
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            
            let tileFrame = effectiveFrameForTile(tile)
            var tileVisibleFrame = tileFrame
            tileVisibleFrame.origin.y -= 400.0
            tileVisibleFrame.size.height += 400.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if self.visibleTiles[tileIndex] == nil {
                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: theme.pageBackgroundColor)
                    tileNode.frame = tileFrame
                    if let topNode = topNode {
                        self.scrollNode.insertSubnode(tileNode, aboveSubnode: topNode)
                    } else {
                        self.scrollNode.insertSubnode(tileNode, at: 0)
                    }
                    topNode = tileNode
                    self.visibleTiles[tileIndex] = tileNode
                } else {
                    if visibleTiles[tileIndex]!.frame != tileFrame {
                        transition.updateFrame(node: self.visibleTiles[tileIndex]!, frame: tileFrame)
                    }
                }
            }
        }
    
        if let currentLayout = self.currentLayout {
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
                itemNode.removeFromSupernode()
            } else {
                var itemFrame = itemNode.frame
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
    
    private func getPreloadedResource(_ url: String) -> Data? {
        guard let preloadedResouces = self.preloadedResouces else {
            return nil
        }
        var cleanUrl = url
        var components = URLComponents(string: url)
        components?.queryItems = nil
        cleanUrl = components?.url?.absoluteString ?? cleanUrl
        for resource in preloadedResouces {
            if let resource = resource as? [String: Any], let resourceUrl = resource["WebResourceURL"] as? String {
                if resourceUrl == url || resourceUrl.hasPrefix(cleanUrl) {
                    return resource["WebResourceData"] as? Data
                }
            }
        }
        return nil
    }
    
    private struct ScrollingOffsetState: Equatable {
        var value: CGFloat
        var isDraggingOrDecelerating: Bool
    }
    
    private var previousScrollingOffset: ScrollingOffsetState?
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
        self.updateScrollingOffset(isReset: false, transition: .immediate)
    }
    
    private func snapScrollingOffsetToInsets() {
        let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
        self.updateScrollingOffset(isReset: false, transition: transition)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.snapScrollingOffsetToInsets()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.snapScrollingOffsetToInsets()
    }
    
    private func updateScrollingOffset(isReset: Bool, transition: ComponentTransition) {
        let scrollView = self.scrollNode.view
        let isInteracting = scrollView.isDragging || scrollView.isDecelerating
        if let previousScrollingOffsetValue = self.previousScrollingOffset {
            let currentBounds = scrollView.bounds
            let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
            let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
            
            let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
            self.onScrollingUpdate(ContentScrollingUpdate(
                relativeOffset: relativeOffset,
                absoluteOffsetToTopEdge: offsetToTopEdge,
                absoluteOffsetToBottomEdge: offsetToBottomEdge,
                isReset: isReset,
                isInteracting: isInteracting,
                transition: transition
            ))
        }
        self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: isInteracting)
        
        var readingProgress: CGFloat = 0.0
        if !scrollView.contentSize.height.isZero {
            let value = (scrollView.contentOffset.y + scrollView.contentInset.top) / (scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.contentInset.top)
            readingProgress = max(0.0, min(1.0, value))
        }
        self.readingProgress.set(readingProgress)
    }
    
    func resetScrolling() {
        self.updateScrollingOffset(isReset: true, transition: .spring(duration: 0.4))
    }
    
    private func scrollableContentOffset(item: InstantPageScrollableItem) -> CGPoint {
        var contentOffset = CGPoint()
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let itemNode = itemNode as? InstantPageScrollableNode, itemNode.item === item {
                contentOffset = itemNode.contentOffset
                break
            }
        }
        return contentOffset
    }
    
    private func nodeForDetailsItem(_ item: InstantPageDetailsItem) -> InstantPageDetailsNode? {
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let detailsNode = itemNode as? InstantPageDetailsNode, detailsNode.item === item {
                return detailsNode
            }
        }
        return nil
    }
    
    private func effectiveSizeForDetails(_ item: InstantPageDetailsItem) -> CGSize {
        if let node = nodeForDetailsItem(item) {
            return CGSize(width: item.frame.width, height: node.effectiveContentSize.height + item.titleHeight)
        } else {
            return item.frame.size
        }
    }
    
    private func effectiveFrameForTile(_ tile: InstantPageTile) -> CGRect {
        let layoutOrigin = tile.frame.origin
        var origin = layoutOrigin
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        return CGRect(origin: origin, size: tile.frame.size)
    }
    
    private func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        let layoutOrigin = item.frame.origin
        var origin = layoutOrigin
        
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        
        if let item = item as? InstantPageDetailsItem {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: height))
        } else {
            return CGRect(origin: origin, size: item.frame.size)
        }
    }
    
    private func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if let currentLayout = self.currentLayout {
            for item in currentLayout.items {
                let itemFrame = self.effectiveFrameForItem(item)
                if itemFrame.contains(location) {
                    if let item = item as? InstantPageTextItem, item.selectable {
                        return (item, CGPoint(x: itemFrame.minX - item.frame.minX, y: itemFrame.minY - item.frame.minY))
                    } else if let item = item as? InstantPageScrollableItem {
                        let contentOffset = scrollableContentOffset(item: item)
                        if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY)) {
                            return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x - contentOffset.x, dy: parentOffset.y))
                        }
                    } else if let item = item as? InstantPageDetailsItem {
                        for (_, itemNode) in self.visibleItemsWithNodes {
                            if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
                                if let (textItem, parentOffset) = itemNode.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX, dy: -itemFrame.minY)) {
                                    return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
                                }
                            }
                        }
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
    
    private func openUrl(_ url: InstantPageUrlItem) {
        var baseUrl = url.url
        var anchor: String?
        if let anchorRange = url.url.range(of: "#") {
            anchor = String(baseUrl[anchorRange.upperBound...]).removingPercentEncoding
            baseUrl = String(baseUrl[..<anchorRange.lowerBound])
        }
        
        if !baseUrl.hasPrefix("http://") && !baseUrl.hasPrefix("https://") {
            if let updatedUrl = URL(string: baseUrl, relativeTo: URL(string: "/", relativeTo: URL(string: self.url))) {
                baseUrl = updatedUrl.absoluteString
            }
        }

        if let page = self.webPage?.instantPage, page.url == baseUrl || baseUrl.isEmpty, let anchor = anchor {
            self.scrollToAnchor(anchor)
            return
        }
        
        self.loadProgress.set(0.0)
        self.loadProgress.set(0.02)
    
        self.loadWebpageDisposable.set(nil)
        self.resolveUrlDisposable.set((self.context.sharedContext.resolveUrl(context: self.context, peerId: nil, url: baseUrl, skipUrlAuth: true)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.loadProgress.set(0.07)
                switch result {
                    case let .externalUrl(externalUrl):
                        if let webpageId = url.webpageId {
                            var anchor: String?
                            if let anchorRange = externalUrl.range(of: "#") {
                                anchor = String(externalUrl[anchorRange.upperBound...])
                            }
                            strongSelf.loadWebpageDisposable.set((webpagePreviewWithProgress(account: strongSelf.context.account, urls: [externalUrl], webpageId: webpageId)
                            |> deliverOnMainQueue).start(next: { result in
                                if let strongSelf = self {
                                    switch result {
                                        case let .result(webpageResult):
                                            if let webpageResult = webpageResult, case .Loaded = webpageResult.webpage.content {
                                                strongSelf.loadProgress.set(1.0)
                                                strongSelf.pushContent(.instantPage(webPage: webpageResult.webpage, anchor: anchor, sourceLocation: strongSelf.sourceLocation, preloadedResources: nil), nil)
                                            }
                                            break
                                        case let .progress(progress):
                                            strongSelf.loadProgress.set(CGFloat(0.07 + progress * (1.0 - 0.07)))
                                    }
                                }
                            }))
                        } else {
                            strongSelf.loadProgress.set(1.0)
                            strongSelf.pushContent(.webPage(url: externalUrl), nil)
                        }
                    case let .instantView(webpage, anchor):
                        strongSelf.loadProgress.set(1.0)
                        strongSelf.pushContent(.instantPage(webPage: webpage, anchor: anchor, sourceLocation: strongSelf.sourceLocation, preloadedResources: nil), nil)
                    default:
                        strongSelf.loadProgress.set(1.0)
                        strongSelf.minimize()
                        strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.getNavigationController(), forceExternal: false, forceUpdate: false, openPeer: { peer, navigation in
                            switch navigation {
                                case let .chat(_, subject, peekData):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: subject, peekData: peekData))
                                    }
                                case let .withBotStartPayload(botStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botStart: botStart, keepStack: .always))
                                    }
                                case let .withAttachBot(attachBotStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
                                    }
                                case let .withBotApp(botAppStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botAppStart: botAppStart))
                                    }
                                case .info:
                                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self, let peer = peer {
                                            if let controller = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                                strongSelf.getNavigationController()?.pushViewController(controller)
                                            }
                                        }
                                    })
                                default:
                                    break
                            }
                        },
                        sendFile: nil,
                        sendSticker: nil,
                        sendEmoji: nil,
                        requestMessageActionUrlAuth: nil,
                        joinVoiceChat: nil,
                        present: { c, a in
                            self?.present(c, a)
                        }, dismissInput: { [weak self] in
                            self?.endEditing(true)
                        }, contentContext: nil, progress: nil, completion: nil)
                }
            }
        }))
    }
    
    private func openUrlIn(_ url: InstantPageUrlItem) {
        var baseUrl = url.url
        if !baseUrl.hasPrefix("http://") && !baseUrl.hasPrefix("https://") {
            if let updatedUrl = URL(string: baseUrl, relativeTo: URL(string: "/", relativeTo: URL(string: self.url))) {
                baseUrl = updatedUrl.absoluteString
            }
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = OpenInActionSheetController(context: self.context, item: .url(url: baseUrl), openUrl: { [weak self] url in
            if let self {
                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
            }
        })
        self.present(actionSheet, nil)
    }
        
    private func openMedia(_ media: InstantPageMedia) {
        guard let items = self.currentLayout?.items, let (webPage, _) = self.webPage else {
            return
        }
        
        func mediasFromItems(_ items: [InstantPageItem]) -> [InstantPageMedia] {
            var medias: [InstantPageMedia] = []
            for item in items {
                if let detailsItem = item as? InstantPageDetailsItem {
                    medias.append(contentsOf: mediasFromItems(detailsItem.items))
                } else {
                    if let item = item as? InstantPageImageItem, item.interactive {
                        medias.append(contentsOf: item.medias)
                    } else if let item = item as? InstantPagePlayableVideoItem, item.interactive {
                        medias.append(contentsOf: item.medias)
                    }
                }
            }
            return medias
        }
        
        if case let .geo(map) = media.media {
            let controllerParams = LocationViewParams(sendLiveLocation: { _ in
            }, stopLiveLocation: { _ in
            }, openUrl: { _ in }, openPeer: { _ in
            }, showAll: false)
            
            let peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: peer, text: "", attributes: [], media: [map], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let controller = LocationViewController(context: self.context, subject: EngineMessage(message), params: controllerParams)
            self.push(controller)
            return
        }
        
        if case let .file(file) = media.media, (file.isVoice || file.isMusic) {
            var medias: [InstantPageMedia] = []
            var initialIndex = 0
            for item in items {
                for itemMedia in item.medias {
                    if case let .file(itemFile) = itemMedia.media, (itemFile.isVoice || itemFile.isMusic) {
                        if itemMedia.index == media.index {
                            initialIndex = medias.count
                        }
                        medias.append(itemMedia)
                    }
                }
            }
            self.context.sharedContext.mediaManager.setPlaylist((self.context, InstantPageMediaPlaylist(webPage: webPage, items: medias, initialItemIndex: initialIndex)), type: file.isVoice ? .voice : .music, control: .playback(.play))
            return
        }
        
        var fromPlayingVideo = false
        
        var entries: [InstantPageGalleryEntry] = []
        if case let .webpage(webPage) = media.media {
            entries.append(InstantPageGalleryEntry(index: 0, pageId: webPage.webpageId, media: media, caption: nil, credit: nil, location: nil))
        } else if case let .file(file) = media.media, file.isAnimated {
            fromPlayingVideo = true
            entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, credit: media.credit, location: nil))
        } else {
            fromPlayingVideo = true
            var medias: [InstantPageMedia] = mediasFromItems(items)
            medias = medias.filter { item in
                switch item.media {
                case .image, .file:
                    return true
                default:
                    return false
                }
            }
            
            for media in medias {
                entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, credit: media.credit, location: InstantPageGalleryEntryLocation(position: Int32(entries.count), totalCount: Int32(medias.count))))
            }
        }
        
        var centralIndex: Int?
        for i in 0 ..< entries.count {
            if entries[i].media == media {
                centralIndex = i
                break
            }
        }
        
        if let centralIndex = centralIndex {
            let controller = InstantPageGalleryController(context: self.context, userLocation: self.sourceLocation.userLocation, webPage: webPage, entries: entries, centralIndex: centralIndex, fromPlayingVideo: fromPlayingVideo, replaceRootController: { _, _ in
            }, baseNavigationController: self.getNavigationController(), getPreloadedResource: { [weak self] url in
                return self?.getPreloadedResource(url)
            })
            self.hiddenMediaDisposable.set((controller.hiddenMedia |> deliverOnMainQueue).start(next: { [weak self] entry in
                if let strongSelf = self {
                    for (_, itemNode) in strongSelf.visibleItemsWithNodes {
                        itemNode.updateHiddenMedia(media: entry?.media)
                    }
                }
            }))
            controller.openUrl = { [weak self] url in
                self?.openUrl(url)
            }
            self.present(controller, InstantPageGalleryControllerPresentationArguments(transitionArguments: { [weak self] entry -> GalleryTransitionArguments? in
                if let strongSelf = self {
                    for (_, itemNode) in strongSelf.visibleItemsWithNodes {
                        if let transitionNode = itemNode.transitionNode(media: entry.media) {
                            return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { view in
                                if let strongSelf = self {
                                    strongSelf.scrollNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.scrollNode.view)
                                }
                            })
                        }
                    }
                }
                return nil
            }))
        }
    }
    
    private func longPressMedia(_ media: InstantPageMedia) {
        let controller = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
            if let self, let image = media.media._asMedia() as? TelegramMediaImage {
                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                let _ = copyToPasteboard(context: self.context, postbox: self.context.account.postbox, userLocation: self.sourceLocation.userLocation, mediaReference: .standalone(media: media)).start()
            }
        }), ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_LinkDialogSave, accessibilityLabel: self.presentationData.strings.Conversation_LinkDialogSave), action: { [weak self] in
            if let self, let image = media.media._asMedia() as? TelegramMediaImage {
                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                let _ = saveToCameraRoll(context: self.context, postbox: self.context.account.postbox, userLocation: self.sourceLocation.userLocation, mediaReference: .standalone(media: media)).start()
            }
        }), ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuShare, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuShare), action: { [weak self] in
            if let self, let (webPage, _) = self.webPage, let image = media.media._asMedia() as? TelegramMediaImage {
                self.present(ShareController(context: self.context, subject: .image(image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.media(media: .webPage(webPage: WebpageReference(webPage), media: image), resource: $0.resource)) }))), nil)
            }
        })], catchTapsOutside: true)
        self.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
            if let self {
                for (_, itemNode) in self.visibleItemsWithNodes {
                    if let (node, _, _) = itemNode.transitionNode(media: media) {
                        return (self.scrollNode, node.convert(node.bounds, to: self.scrollNode), self.wrapperNode, self.wrapperNode.bounds)
                    }
                }
            }
            return nil
        }))
    }
    
    private func activatePinchPreview(sourceNode: PinchSourceContainerNode) {
        let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: { [weak self] in
            guard let self else {
                return CGRect()
            }
            let localRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.width, height: self.bounds.height))
            return self.convert(localRect, to: nil)
        })
        self.presentInGlobalOverlay(pinchController)
    }
    
    private func pinchPreviewFinished(itemNode: ASDisplayNode) {
        for (_, listItemNode) in self.visibleItemsWithNodes {
            if let listItemNode = listItemNode as? InstantPagePeerReferenceNode {
                if listItemNode.frame.intersects(itemNode.frame) && listItemNode.frame.maxY <= itemNode.frame.maxY + 2.0 {
                    listItemNode.layer.animateAlpha(from: 0.0, to: listItemNode.alpha, duration: 0.25)
                    break
                }
            }
        }
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
                                var baseUrl = url.url
                                if !baseUrl.hasPrefix("http://") && !baseUrl.hasPrefix("https://") {
                                    if let updatedUrl = URL(string: baseUrl, relativeTo: URL(string: "/", relativeTo: URL(string: self.url))) {
                                        baseUrl = updatedUrl.absoluteString
                                    }
                                }
                                
                                let canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: baseUrl)).count > 1
                                let openText = canOpenIn ? self.presentationData.strings.Conversation_FileOpenIn : self.presentationData.strings.Conversation_LinkDialogOpen
                                let actionSheet = ActionSheetController(instantPageTheme: self.theme)
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                    ActionSheetTextItem(title: baseUrl),
                                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let strongSelf = self {
                                            if canOpenIn {
                                                strongSelf.openUrlIn(url)
                                            } else {
                                                strongSelf.openUrl(url)
                                            }
                                        }
                                    }),
                                    ActionSheetButtonItem(title: self.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        UIPasteboard.general.string = baseUrl
                                    }),
                                    ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let link = URL(string: baseUrl) {
                                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                        }
                                    })
                                ]), ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])])
                                self.present(actionSheet, nil)
                            } else if let (item, parentOffset) = self.textItemAtLocation(location) {
                                let textFrame = item.frame
                                var itemRects = item.lineRects()
                                for i in 0 ..< itemRects.count {
                                    itemRects[i] = itemRects[i].offsetBy(dx: parentOffset.x + textFrame.minX, dy: parentOffset.y + textFrame.minY).insetBy(dx: -2.0, dy: -2.0)
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
            
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = self.presentationData.strings
            let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] sharedData in
                let translationSettings: TranslationSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                    translationSettings = current
                } else {
                    translationSettings = TranslationSettings.defaultSettings
                }
                
                var actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuCopy, accessibilityLabel: strings.Conversation_ContextMenuCopy), action: { [weak self] in
                    UIPasteboard.general.string = text
                    
                    if let strongSelf = self {
                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    }
                }), ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuShare, accessibilityLabel: strings.Conversation_ContextMenuShare), action: { [weak self] in
                    if let strongSelf = self, let (webPage, _) = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                        strongSelf.present(ShareController(context: strongSelf.context, subject: .quote(text: text, url: content.url)), nil)
                    }
                })]
                
                let (canTranslate, language) = canTranslateText(context: context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
                if canTranslate {
                    actions.append(ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuTranslate, accessibilityLabel: strings.Conversation_ContextMenuTranslate), action: { [weak self] in
                        let controller = TranslateScreen(context: context, text: text, canCopy: true, fromLanguage: language)
                        controller.pushController = { [weak self] c in
                            self?.getNavigationController()?._keepModalDismissProgress = true
                            self?.push(c)
                        }
                        controller.presentController = { [weak self] c in
                            self?.present(c, nil)
                        }
                        self?.present(controller, nil)
                    }))
                }
                
                let controller = makeContextMenuController(actions: actions)
                controller.dismissed = { [weak self] in
                    self?.updateTextSelectionRects([], text: nil)
                }
                self?.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                    if let strongSelf = self {
                        return (strongSelf.scrollNode, coveringRect.insetBy(dx: -3.0, dy: -3.0), strongSelf.wrapperNode, strongSelf.wrapperNode.bounds)
                    } else {
                        return nil
                    }
                }))
            })
            
            textSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
        } else if let textSelectionNode = self.textSelectionNode {
            self.textSelectionNode = nil
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.removeFromSupernode()
            })
        }
    }
    
    private func findAnchorItem(_ anchor: String, items: [InstantPageItem]) -> (InstantPageItem, CGFloat, Bool, [InstantPageDetailsItem])? {
        for item in items {
            if let item = item as? InstantPageAnchorItem, item.anchor == anchor {
                return (item, -10.0, false, [])
            } else if let item = item as? InstantPageTextItem {
                if let (lineIndex, empty) = item.anchors[anchor] {
                    return (item, item.lines[lineIndex].frame.minY - 10.0, !empty, [])
                }
            }
            else if let item = item as? InstantPageTableItem {
                if let (offset, empty) = item.anchors[anchor] {
                    return (item, offset - 10.0, !empty, [])
                }
            }
            else if let item = item as? InstantPageDetailsItem {
                if let (foundItem, offset, reference, detailsItems) = self.findAnchorItem(anchor, items: item.items) {
                    var detailsItems = detailsItems
                    detailsItems.insert(item, at: 0)
                    return (foundItem, offset, reference, detailsItems)
                }
            }
        }
        return nil
    }
    
    private func presentReferenceView(item: InstantPageTextItem, referenceAnchor: String) {
        guard let (webPage, instantPage) = self.webPage else {
            return
        }
        
        var targetAnchor: InstantPageTextAnchorItem?
        for (name, (line, _)) in item.anchors {
            if name == referenceAnchor {
                let anchors = item.lines[line].anchorItems
                for anchor in anchors {
                    if anchor.name == referenceAnchor {
                        targetAnchor = anchor
                        break
                    }
                }
            }
        }
        
        guard let anchorText = targetAnchor?.anchorText else {
            return
        }
        
        let controller = InstantPageReferenceController(context: self.context, sourceLocation: self.sourceLocation, theme: theme, webPage: webPage, instantPage: instantPage, anchorText: anchorText, openUrl: { [weak self] url in
            self?.openUrl(url)
        }, openUrlIn: { [weak self] url in
            self?.openUrlIn(url)
        }, present: { [weak self] c, a in
            self?.present(c, a)
        })
        self.present(controller, nil)
    }
    
    private func scrollToAnchor(_ anchor: String) {
        guard let items = self.currentLayout?.items else {
            return
        }
        
        if !anchor.isEmpty {
            if let (item, lineOffset, reference, detailsItems) = findAnchorItem(String(anchor), items: items) {
                if let item = item as? InstantPageTextItem, reference {
                    self.presentReferenceView(item: item, referenceAnchor: anchor)
                } else {
                    var previousDetailsNode: InstantPageDetailsNode?
                    var containerOffset: CGFloat = 0.0
                    for detailsItem in detailsItems {
                        if let previousNode = previousDetailsNode {
                            previousNode.contentNode.updateDetailsExpanded(detailsItem.index, true, animated: false)
                            let frame = previousNode.effectiveFrameForItem(detailsItem)
                            containerOffset += frame.minY
                            
                            previousDetailsNode = previousNode.contentNode.nodeForDetailsItem(detailsItem)
                            previousDetailsNode?.setExpanded(true, animated: false)
                        } else {
                            self.updateDetailsExpanded(detailsItem.index, true, animated: false)
                            let frame = self.effectiveFrameForItem(detailsItem)
                            containerOffset += frame.minY
                            
                            previousDetailsNode = self.nodeForDetailsItem(detailsItem)
                            previousDetailsNode?.setExpanded(true, animated: false)
                        }
                    }
                    
                    let frame: CGRect
                    if let previousDetailsNode = previousDetailsNode {
                        frame = previousDetailsNode.effectiveFrameForItem(item)
                    } else {
                        frame = self.effectiveFrameForItem(item)
                    }
                    
                    var targetY = min(containerOffset + frame.minY + lineOffset, self.scrollNode.view.contentSize.height - self.scrollNode.frame.height)
                    if targetY < self.scrollNode.view.contentOffset.y {
                        targetY -= self.scrollNode.view.contentInset.top
                    } else {
                        targetY -= self.containerLayout?.insets.top ?? 20.0
                    }
                    self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: targetY), animated: true)
                }
            } else if let instantPage = self.webPage?.instantPage, !instantPage.isComplete {
//                self.loadProgress.set(0.5)
                self.pendingAnchor = anchor
            }
        } else {
            self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top), animated: true)
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
                if let self {
                    self.updatePageLayout()
                    self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
                }
            }))
        }
    }
    
    private func updateDetailsExpanded(_ index: Int, _ expanded: Bool, animated: Bool = true) {
        if var currentExpandedDetails = self.currentExpandedDetails {
            currentExpandedDetails[index] = expanded
            self.currentExpandedDetails = currentExpandedDetails
        }
        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds, animated: animated)
    }
    
    func addToRecentlyVisited() {
        if let (webPage, _) = self.webPage {
            let _ = addRecentlyVisitedLink(engine: self.context.engine, webPage: webPage).startStandalone()
        }
    }
    
    func makeContentSnapshotView() -> UIView? {
        return nil
    }
}
