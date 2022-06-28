import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Display
import SafariServices
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ShareController
import SaveToCameraRoll
import GalleryUI
import OpenInExternalAppUI
import LocationUI
import UndoUI
import ContextUI
import TranslateUI

final class InstantPageControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private weak var controller: InstantPageController?
    private let context: AccountContext
    private var settings: InstantPagePresentationSettings?
    private var themeSettings: PresentationThemeSettings?
    private var presentationTheme: PresentationTheme
    private var strings: PresentationStrings
    private var nameDisplayOrder: PresentationPersonNameOrder
    private let autoNightModeTriggered: Bool
    private var dateTimeFormat: PresentationDateTimeFormat
    private var theme: InstantPageTheme?
    private let sourcePeerType: MediaAutoDownloadPeerType
    private var manualThemeOverride: InstantPageThemeType?
    private let getNavigationController: () -> NavigationController?
    private let present: (ViewController, Any?) -> Void
    private let pushController: (ViewController) -> Void
    private let openPeer: (PeerId) -> Void
    
    private var webPage: TelegramMediaWebpage?
    private var initialAnchor: String?
    private var pendingAnchor: String?
    private var initialState: InstantPageStoredState?
    
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
    
    var currentAccessibilityAreas: [AccessibilityAreaNode] = []
    
    private var previousContentOffset: CGPoint?
    private var isDeceleratingBecauseOfDragging = false
    
    private let hiddenMediaDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let loadWebpageDisposable = MetaDisposable()
    
    private let loadProgress = ValuePromise<CGFloat>(1.0, ignoreRepeated: true)
    private let loadProgressDisposable = MetaDisposable()
    
    private let updateLayoutDisposable = MetaDisposable()
    
    private var themeReferenceDate: Date?
    
    var currentState: InstantPageStoredState {
        var details: [InstantPageStoredDetailsState] = []
        if let currentExpandedDetails = self.currentExpandedDetails {
            for (index, expanded) in currentExpandedDetails {
                details.append(InstantPageStoredDetailsState(index: Int32(clamping: index), expanded: expanded, details: []))
            }
        }
        return InstantPageStoredState(contentOffset: Double(self.scrollNode.view.contentOffset.y), details: details)
    }
    
    init(controller: InstantPageController, context: AccountContext, settings: InstantPagePresentationSettings?, themeSettings: PresentationThemeSettings?, presentationTheme: PresentationTheme, strings: PresentationStrings,  dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, autoNightModeTriggered: Bool, statusBar: StatusBar, sourcePeerType: MediaAutoDownloadPeerType, getNavigationController: @escaping () -> NavigationController?, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, openPeer: @escaping (PeerId) -> Void, navigateBack: @escaping () -> Void) {
        self.controller = controller
        self.context = context
        self.presentationTheme = presentationTheme
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.autoNightModeTriggered = autoNightModeTriggered
        self.strings = strings
        self.settings = settings
        let themeReferenceDate = Date()
        self.themeReferenceDate = themeReferenceDate
        self.theme = settings.flatMap { settings in
            return instantPageThemeForType(instantPageThemeTypeForSettingsAndTime(themeSettings: themeSettings, settings: settings, time: themeReferenceDate, forceDarkTheme: autoNightModeTriggered).0, settings: settings)
        }
        self.sourcePeerType = sourcePeerType
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
                let shareController = ShareController(context: context, subject: .url(content.url))
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    }
                }
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
        
        self.loadProgressDisposable.set((self.loadProgress.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.navigationBar.setLoadProgress(value)
        }))
    }
    
    deinit {
        self.hiddenMediaDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.loadWebpageDisposable.dispose()
        self.loadProgressDisposable.dispose()
    }
    
    func update(settings: InstantPagePresentationSettings, themeSettings: PresentationThemeSettings?, strings: PresentationStrings) {
        if self.settings != settings || self.strings !== strings {
            let previousSettings = self.settings
            var updateLayout = previousSettings == nil
            
            if let previousSettings = previousSettings {
                if previousSettings.themeType != settings.themeType {
                    self.themeReferenceDate = nil
                }
            }
            
            self.settings = settings
            self.themeSettings = themeSettings
            let themeType = instantPageThemeTypeForSettingsAndTime(themeSettings: self.themeSettings, settings: settings, time: self.themeReferenceDate, forceDarkTheme: self.autoNightModeTriggered)
            let theme = instantPageThemeForType(themeType.0, settings: settings)
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
                
                self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
                self.updateNavigationBar()
                
                self.recursivelyEnsureDisplaySynchronously(true)
                
                if let layout = self.containerLayout {
                    self.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: .immediate)
                }
            }
        }
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
    
    override func didLoad() {
        super.didLoad()
        
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
    }
    
    func updateWebPage(_ webPage: TelegramMediaWebpage?, anchor: String?, state: InstantPageStoredState? = nil) {
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
            self.updateLayout()
            
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            if let containerLayout = self.containerLayout {
                self.containerLayoutUpdated(containerLayout, navigationBarHeight: 0.0, transition: .immediate)
            }
            
            if let webPage = webPage, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                self.loadProgress.set(1.0)
                
                if let anchor = self.pendingAnchor {
                    self.pendingAnchor = nil
                    self.scrollToAnchor(anchor)
                }
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
            if let statusBarHeight = layout.statusBarHeight, statusBarHeight > 34.0 {
                maxBarHeight = statusBarHeight + 44.0
            } else {
                maxBarHeight = layout.safeInsets.top + 34.0
            }
        } else {
            maxBarHeight = (layout.statusBarHeight ?? 0.0) + 44.0
        }
        
        let scrollInsetTop = maxBarHeight
        
        let resetOffset = self.scrollNode.bounds.size.width.isZero || self.setupScrollOffsetOnLayout || !(self.initialAnchor ?? "").isEmpty
        let widthUpdated = !self.scrollNode.bounds.size.width.isEqual(to: layout.size.width)
        
        var shouldUpdateVisibleItems = false
        if self.scrollNode.bounds.size != layout.size || !self.scrollNode.view.contentInset.top.isEqual(to: scrollInsetTop) {
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            self.scrollNodeHeader.frame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0), size: CGSize(width: layout.size.width, height: 2000.0))
            self.scrollNode.view.contentInset = UIEdgeInsets(top: scrollInsetTop, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
            if widthUpdated {
                self.updateLayout()
            }
            shouldUpdateVisibleItems = true
            self.updateNavigationBar()
        }
        var didSetScrollOffset = false
        if resetOffset {
            var contentOffset = CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top)
            if let state = self.initialState {
                didSetScrollOffset = true
                contentOffset = CGPoint(x: 0.0, y: CGFloat(state.contentOffset))
            }
            else if let anchor = self.initialAnchor, !anchor.isEmpty {
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
                self.previousContentOffset = contentOffset
                self.updateNavigationBar()
                if self.currentLayout != nil {
                    self.setupScrollOffsetOnLayout = false
                }
            }
        }
        if shouldUpdateVisibleItems {
            self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
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
        
        let accessibilityAreas = instantPageAccessibilityAreasFromLayout(currentLayout, boundingWidth: containerLayout.size.width)
        
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
        self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: currentLayout.contentSize.height), size: CGSize(width: containerLayout.size.width, height: 2000.0))
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {
        guard let theme = self.theme else {
            return
        }
        
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
            if let imageItem = item as? InstantPageImageItem, imageItem.media.media is TelegramMediaWebpage {
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
                    if let newNode = item.node(context: self.context, strings: self.strings, nameDisplayOrder: self.nameDisplayOrder, theme: theme, sourcePeerType: self.sourcePeerType, openMedia: { [weak self] media in
                        self?.openMedia(media)
                    }, longPressMedia: { [weak self] media in
                        self?.longPressMedia(media)
                    }, activatePinchPreview: { [weak self] sourceNode in
                        guard let strongSelf = self, let controller = strongSelf.controller else {
                            return
                        }
                        let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                            guard let strongSelf = self else {
                                return CGRect()
                            }

                            let localRect = CGRect(origin: CGPoint(x: 0.0, y: strongSelf.navigationBar.frame.maxY), size: CGSize(width: strongSelf.bounds.width, height: strongSelf.bounds.height - strongSelf.navigationBar.frame.maxY))
                            return strongSelf.view.convert(localRect, to: nil)
                        })
                        controller.window?.presentInGlobalOverlay(pinchController)
                    }, pinchPreviewFinished: { [weak self] itemNode in
                        guard let strongSelf = self else {
                            return
                        }
                        for (_, listItemNode) in strongSelf.visibleItemsWithNodes {
                            if let listItemNode = listItemNode as? InstantPagePeerReferenceNode {
                                if listItemNode.frame.intersects(itemNode.frame) && listItemNode.frame.maxY <= itemNode.frame.maxY + 2.0 {
                                    listItemNode.layer.animateAlpha(from: 0.0, to: listItemNode.alpha, duration: 0.25)
                                    break
                                }
                            }
                        }
                    }, openPeer: { [weak self] peerId in
                        self?.openPeer(peerId)
                    }, openUrl: { [weak self] url in
                        self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                        self?.updateWebEmbedHeight(embedIndex, height)
                    }, updateDetailsExpanded: { [weak self] expanded in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }, currentExpandedDetails: self.currentExpandedDetails) {
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
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
            if let statusBarHeight = containerLayout.statusBarHeight, statusBarHeight > 34.0 {
                maxBarHeight = statusBarHeight + 44.0
            } else {
                maxBarHeight = containerLayout.safeInsets.top + 34.0
            }
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
        if self.setupScrollOffsetOnLayout {
            delta = 0.0
        } else if let previousContentOffset = self.previousContentOffset {
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
        
        if case .regular = containerLayout.metrics.widthClass {
            navigationBarFrame.size.height = maxBarHeight
        } else {
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
            
            if self.setupScrollOffsetOnLayout {
                navigationBarFrame.size.height = maxBarHeight
            }
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
        
        var title: String?
        if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
            title = content.websiteName
        }
        
        transition.updateFrame(node: self.navigationBar, frame: navigationBarFrame)
        self.navigationBar.updateLayout(size: navigationBarFrame.size, minHeight: minBarHeight, maxHeight: maxBarHeight, topInset: containerLayout.safeInsets.top, leftInset: containerLayout.safeInsets.left, rightInset: containerLayout.safeInsets.right, title: title, pageProgress: pageProgress, transition: transition)
        
        transition.animateView {
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: navigationBarFrame.size.height, left: 0.0, bottom: containerLayout.intrinsicInsets.bottom, right: 0.0)
        }
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
                let highlightColor = self.theme?.linkHighlightColor ?? UIColor(rgb: 0x007aff).withAlphaComponent(0.4)
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
    
    private func longPressMedia(_ media: InstantPageMedia) {
        let controller = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.strings.Conversation_ContextMenuCopy), action: { [weak self] in
            if let strongSelf = self, let image = media.media as? TelegramMediaImage {
                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                let _ = copyToPasteboard(context: strongSelf.context, postbox: strongSelf.context.account.postbox, mediaReference: .standalone(media: media)).start()
            }
        }), ContextMenuAction(content: .text(title: self.strings.Conversation_LinkDialogSave, accessibilityLabel: self.strings.Conversation_LinkDialogSave), action: { [weak self] in
            if let strongSelf = self, let image = media.media as? TelegramMediaImage {
                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                let _ = saveToCameraRoll(context: strongSelf.context, postbox: strongSelf.context.account.postbox, mediaReference: .standalone(media: media)).start()
            }
        }), ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuShare, accessibilityLabel: self.strings.Conversation_ContextMenuShare), action: { [weak self] in
            if let strongSelf = self, let webPage = strongSelf.webPage, let image = media.media as? TelegramMediaImage {
                strongSelf.present(ShareController(context: strongSelf.context, subject: .image(image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.media(media: .webPage(webPage: WebpageReference(webPage), media: image), resource: $0.resource)) }))), nil)
            }
        })], catchTapsOutside: true)
        self.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
            if let strongSelf = self {
                for (_, itemNode) in strongSelf.visibleItemsWithNodes {
                    if let (node, _, _) = itemNode.transitionNode(media: media) {
                        return (strongSelf.scrollNode, node.convert(node.bounds, to: strongSelf.scrollNode), strongSelf, strongSelf.bounds)
                    }
                }
            }
            return nil
        }))
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
                            if let theme = self.theme, let url = self.urlForTapLocation(location) {
                                let canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: url.url)).count > 1
                                let openText = canOpenIn ? self.strings.Conversation_FileOpenIn : self.strings.Conversation_LinkDialogOpen
                                let actionSheet = ActionSheetController(instantPageTheme: theme)
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                    ActionSheetTextItem(title: url.url),
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
                                    ActionSheetButtonItem(title: self.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
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
            let strings = self.strings
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
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    }
                }), ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuShare, accessibilityLabel: strings.Conversation_ContextMenuShare), action: { [weak self] in
                    if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                        strongSelf.present(ShareController(context: strongSelf.context, subject: .quote(text: text, url: content.url)), nil)
                    }
                })]
                
                let (canTranslate, language) = canTranslateText(context: context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
                if canTranslate {
                    actions.append(ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuTranslate, accessibilityLabel: strings.Conversation_ContextMenuTranslate), action: { [weak self] in
                        let controller = TranslateScreen(context: context, text: text, fromLanguage: language)
                        controller.pushController = { [weak self] c in
                            (self?.controller?.navigationController as? NavigationController)?._keepModalDismissProgress = true
                            self?.controller?.push(c)
                        }
                        controller.presentController = { [weak self] c in
                            self?.controller?.present(c, in: .window(.root))
                        }
                        self?.present(controller, nil)
                    }))
                }
                
                let controller = ContextMenuController(actions: actions)
                controller.dismissed = { [weak self] in
                    self?.updateTextSelectionRects([], text: nil)
                }
                self?.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                    if let strongSelf = self {
                        return (strongSelf.scrollNode, coveringRect.insetBy(dx: -3.0, dy: -3.0), strongSelf, strongSelf.bounds)
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
        guard let theme = self.theme, let webPage = self.webPage else {
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
        
        let controller = InstantPageReferenceController(context: self.context, sourcePeerType: self.sourcePeerType, theme: theme, webPage: webPage, anchorText: anchorText, openUrl: { [weak self] url in
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
                        targetY -= self.containerLayout?.statusBarHeight ?? 20.0
                    }
                    self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: targetY), animated: true)
                }
            } else if let webPage = self.webPage, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, !instantPage.isComplete {
                self.loadProgress.set(0.5)
                self.pendingAnchor = anchor
            }
        } else {
            self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top), animated: true)
        }
    }
    
    private func openUrl(_ url: InstantPageUrlItem) {
        var baseUrl = url.url
        var anchor: String?
        if let anchorRange = url.url.range(of: "#") {
            anchor = String(baseUrl[anchorRange.upperBound...]).removingPercentEncoding
            baseUrl = String(baseUrl[..<anchorRange.lowerBound])
        }

        if let webPage = self.webPage, case let .Loaded(content) = webPage.content, let page = content.instantPage, page.url == baseUrl, let anchor = anchor {
            self.scrollToAnchor(anchor)
            return
        }
        
        self.loadProgress.set(0.0)
        self.loadProgress.set(0.02)
    
        self.loadWebpageDisposable.set(nil)
        self.resolveUrlDisposable.set((self.context.sharedContext.resolveUrl(context: self.context, peerId: nil, url: url.url, skipUrlAuth: true)
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
                            strongSelf.loadWebpageDisposable.set((webpagePreviewWithProgress(account: strongSelf.context.account, url: externalUrl, webpageId: webpageId)
                            |> deliverOnMainQueue).start(next: { result in
                                if let strongSelf = self {
                                    switch result {
                                        case let .result(webpage):
                                            if let webpage = webpage, case .Loaded = webpage.content {
                                                strongSelf.loadProgress.set(1.0)
                                                strongSelf.pushController(InstantPageController(context: strongSelf.context, webPage: webpage, sourcePeerType: strongSelf.sourcePeerType, anchor: anchor))
                                            }
                                            break
                                        case let .progress(progress):
                                            strongSelf.loadProgress.set(CGFloat(0.07 + progress * (1.0 - 0.07)))
                                    }
                                }
                            }))
                        } else {
                            strongSelf.loadProgress.set(1.0)
                            strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: externalUrl, forceExternal: false, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, navigationController: strongSelf.getNavigationController(), dismissInput: {
                                self?.view.endEditing(true)
                            })
                        }
                    default:
                        strongSelf.loadProgress.set(1.0)
                        strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.getNavigationController(), forceExternal: false, openPeer: { peerId, navigation in
                            switch navigation {
                                case let .chat(_, subject, peekData):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), subject: subject, peekData: peekData))
                                    }
                                case let .withBotStartPayload(botStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), botStart: botStart, keepStack: .always))
                                    }
                                case let .withAttachBot(attachBotStart):
                                    if let navigationController = strongSelf.getNavigationController() {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
                                    }
                                case .info:
                                    let _ = (strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self {
                                            if let controller = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                                strongSelf.getNavigationController()?.pushViewController(controller)
                                            }
                                        }
                                    })
                                default:
                                    break
                            }
                        }, sendFile: nil,
                        sendSticker: nil,
                        requestMessageActionUrlAuth: nil,
                        joinVoiceChat: nil,
                        present: { c, a in
                            self?.present(c, a)
                        }, dismissInput: {
                            self?.view.endEditing(true)
                        }, contentContext: nil)
                }
            }
        }))
    }
    
    private func openUrlIn(_ url: InstantPageUrlItem) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = OpenInActionSheetController(context: self.context, item: .url(url: url.url), openUrl: { [weak self] url in
            if let strongSelf = self, let navigationController = strongSelf.getNavigationController() {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
            }
        })
        self.present(actionSheet, nil)
    }
    
    private func mediasFromItems(_ items: [InstantPageItem]) -> [InstantPageMedia] {
        var medias: [InstantPageMedia] = []
        for item in items {
            if let detailsItem = item as? InstantPageDetailsItem {
                medias.append(contentsOf: mediasFromItems(detailsItem.items))
            } else {
                medias.append(contentsOf: item.medias)
            }
        }
        return medias
    }
    
    private func openMedia(_ media: InstantPageMedia) {
        guard let items = self.currentLayout?.items, let webPage = self.webPage else {
            return
        }
        
        if let map = media.media as? TelegramMediaMap {
            let controllerParams = LocationViewParams(sendLiveLocation: { _ in
            }, stopLiveLocation: { _ in
            }, openUrl: { _ in }, openPeer: { _ in
            }, showAll: false)
            
            let peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer, text: "", attributes: [], media: [map], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
            
            let controller = LocationViewController(context: self.context, subject: message, params: controllerParams)
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
            self.context.sharedContext.mediaManager.setPlaylist((self.context.account, InstantPageMediaPlaylist(webPage: webPage, items: medias, initialItemIndex: initialIndex)), type: file.isVoice ? .voice : .music, control: .playback(.play))
            return
        }
        
        var fromPlayingVideo = false
        
        var entries: [InstantPageGalleryEntry] = []
        if media.media is TelegramMediaWebpage {
            entries.append(InstantPageGalleryEntry(index: 0, pageId: webPage.webpageId, media: media, caption: nil, credit: nil, location: nil))
        } else if let file = media.media as? TelegramMediaFile, file.isAnimated {
            fromPlayingVideo = true
            entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, credit: media.credit, location: nil))
        } else {
            fromPlayingVideo = true
            var medias: [InstantPageMedia] = mediasFromItems(items)
            medias = medias.filter {
                return $0.media is TelegramMediaImage || $0.media is TelegramMediaFile
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
            let controller = InstantPageGalleryController(context: self.context, webPage: webPage, entries: entries, centralIndex: centralIndex, fromPlayingVideo: fromPlayingVideo, replaceRootController: { _, _ in
            }, baseNavigationController: self.getNavigationController())
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
                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.scrollNode.view.bounds)
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
    
    private func presentSettings() {
        guard let settings = self.settings, let containerLayout = self.containerLayout else {
            return
        }
        if self.settingsNode == nil {
            let settingsNode = InstantPageSettingsNode(strings: self.strings, settings: settings, currentThemeType: instantPageThemeTypeForSettingsAndTime(themeSettings: self.themeSettings, settings: settings, time: self.themeReferenceDate, forceDarkTheme: self.autoNightModeTriggered), applySettings: { [weak self] settings in
                if let strongSelf = self {
                    strongSelf.update(settings: settings, themeSettings: strongSelf.themeSettings, strings: strongSelf.strings)
                    let _ = updateInstantPagePresentationSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, { _ in
                        return settings
                    }).start()
                }
            }, openInSafari: { [weak self] in
                if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                    strongSelf.context.sharedContext.applicationBindings.openUrl(content.url)
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
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
            self.navigationBar.updateDimmed(false, transition: transition)
            transition.updateAlpha(node: self.statusBar, alpha: 1.0)
        }
    }
}
