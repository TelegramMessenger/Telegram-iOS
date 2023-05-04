import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import MergeLists
import Photos
import PhotosUI
import LegacyComponents
import LegacyMediaPickerUI
import AttachmentUI
import ContextUI
import WebSearchUI
import SparseItemGrid
import UndoUI
import PresentationDataUtils
import MoreButtonNode

final class MediaPickerInteraction {
    let openMedia: (PHFetchResult<PHAsset>, Int, UIImage?) -> Void
    let openSelectedMedia: (TGMediaSelectableItem, UIImage?) -> Void
    let toggleSelection: (TGMediaSelectableItem, Bool, Bool) -> Bool
    let sendSelected: (TGMediaSelectableItem?, Bool, Int32?, Bool, @escaping () -> Void) -> Void
    let schedule: () -> Void
    let dismissInput: () -> Void
    let selectionState: TGMediaSelectionContext?
    let editingState: TGMediaEditingContext
    var hiddenMediaId: String?
    
    init(openMedia: @escaping (PHFetchResult<PHAsset>, Int, UIImage?) -> Void, openSelectedMedia: @escaping (TGMediaSelectableItem, UIImage?) -> Void, toggleSelection: @escaping (TGMediaSelectableItem, Bool, Bool) -> Bool, sendSelected: @escaping (TGMediaSelectableItem?, Bool, Int32?, Bool, @escaping () -> Void) -> Void, schedule: @escaping  () -> Void, dismissInput: @escaping () -> Void, selectionState: TGMediaSelectionContext?, editingState: TGMediaEditingContext) {
        self.openMedia = openMedia
        self.openSelectedMedia = openSelectedMedia
        self.toggleSelection = toggleSelection
        self.sendSelected = sendSelected
        self.schedule = schedule
        self.dismissInput = dismissInput
        self.selectionState = selectionState
        self.editingState = editingState
    }
}

private struct MediaPickerGridEntry: Comparable, Identifiable {
    let stableId: Int
    let content: MediaPickerGridItemContent
    let selectable: Bool
    
    static func <(lhs: MediaPickerGridEntry, rhs: MediaPickerGridEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(context: AccountContext, interaction: MediaPickerInteraction, theme: PresentationTheme) -> MediaPickerGridItem {
        return MediaPickerGridItem(content: self.content, interaction: interaction, theme: theme, selectable: self.selectable, enableAnimations: context.sharedContext.energyUsageSettings.fullTranslucency)
    }
}

private struct MediaPickerGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    
    init(previousList: [MediaPickerGridEntry], list: [MediaPickerGridEntry], context: AccountContext, interaction: MediaPickerInteraction, theme: PresentationTheme, scrollToItem: GridNodeScrollToItem?) {
         let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction, theme: theme), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction, theme: theme)) }
        
        self.scrollToItem = scrollToItem
    }
}

struct Month: Equatable {
    var packedValue: Int32

    init(packedValue: Int32) {
        self.packedValue = packedValue
    }

    init(localTimestamp: Int32) {
        var time: time_t = time_t(localTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&time, &timeinfo)

        let year = UInt32(max(timeinfo.tm_year, 0))
        let month = UInt32(max(timeinfo.tm_mon, 0))

        self.packedValue = Int32(bitPattern: year | (month << 16))
    }

    var year: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 0) & 0xffff)
    }

    var month: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 16) & 0xffff)
    }
}

public final class MediaPickerScreen: ViewController, AttachmentContainable {
    public enum Subject {
        public enum Media: Equatable {
            case image(UIImage)
            case video(URL)
            
            var asset: TGMediaSelectableItem {
                switch self {
                case let .image(image):
                    return image
                case let .video(url):
                    return TGCameraCapturedVideo(url: url)
                }
            }
            
            var identifier: String {
                switch self {
                case let .image(image):
                    return image.uniqueIdentifier
                case let .video(url):
                    return url.absoluteString
                }
            }
        }
        
        public enum AssetsMode: Equatable {
            case `default`
            case wallpaper
        }
        
        case assets(PHAssetCollection?, AssetsMode)
        case media([Media])
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    
    fileprivate var interaction: MediaPickerInteraction?
    
    private let peer: EnginePeer?
    private let threadTitle: String?
    private let chatLocation: ChatLocation?
    private let bannedSendPhotos: (Int32, Bool)?
    private let bannedSendVideos: (Int32, Bool)?
    private let subject: Subject
    private let saveEditedPhotos: Bool
    
    private let titleView: MediaPickerTitleView
    private let moreButtonNode: MoreButtonNode
    
    public weak var webSearchController: WebSearchController?
    
    public var openCamera: ((TGAttachmentCameraView?) -> Void)?
    public var presentSchedulePicker: (Bool, @escaping (Int32) -> Void) -> Void = { _, _ in }
    public var presentTimerPicker: (@escaping (Int32) -> Void) -> Void = { _ in }
    public var presentWebSearch: (MediaGroupsScreen, Bool) -> Void = { _, _ in }
    public var getCaptionPanelView: () -> TGCaptionPanelView? = { return nil }
    
    public var customSelection: ((PHAsset) -> Void)? = nil
    
    private var completed = false
    public var legacyCompletion: (_ signals: [Any], _ silently: Bool, _ scheduleTime: Int32?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void = { _, _, _, _, _ in }
    
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    var dismissAll: () -> Void = { }
    
    private class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        enum DisplayMode {
            case all
            case selected
        }
        
        enum State {
            case noAccess(cameraAccess: AVAuthorizationStatus?)
            case assets(fetchResult: PHFetchResult<PHAsset>?, preload: Bool, mediaAccess: PHAuthorizationStatus, cameraAccess: AVAuthorizationStatus?)
            case media([Subject.Media])
        }
        
        private weak var controller: MediaPickerScreen?
        private var presentationData: PresentationData
        fileprivate let mediaAssetsContext: MediaAssetsContext
        
        private var requestedMediaAccess = false
        private var requestedCameraAccess = false
        
        private let containerNode: ASDisplayNode
        private let backgroundNode: NavigationBackgroundNode
        private let gridNode: GridNode
        fileprivate var cameraView: TGAttachmentCameraView?
        private var cameraActivateAreaNode: AccessibilityAreaNode
        private var placeholderNode: MediaPickerPlaceholderNode?
        private var manageNode: MediaPickerManageNode?
        private var scrollingArea: SparseItemGridScrollingArea
        private var isFastScrolling = false
        
        private var selectionNode: MediaPickerSelectedListNode?
        
        private var nextStableId: Int = 1
        private var currentEntries: [MediaPickerGridEntry] = []
        private var enqueuedTransactions: [MediaPickerGridTransaction] = []
        private var state: State?
        
        private var preloadPromise = ValuePromise<Bool>(true)
        
        private var itemsDisposable: Disposable?
        private var selectionChangedDisposable: Disposable?
        private var itemsDimensionsUpdatedDisposable: Disposable?
        private var hiddenMediaDisposable: Disposable?
        
        private let hiddenMediaId = Promise<String?>(nil)
        
        private var selectionGesture: MediaPickerGridSelectionGesture<TGMediaSelectableItem>?
        
        private var fastScrollContentOffset = ValuePromise<CGPoint>(ignoreRepeated: true)
        private var fastScrollDisposable: Disposable?
        
        private var didSetReady = false
        private let _ready = Promise<Bool>()
        var ready: Promise<Bool> {
            return self._ready
        }
        
        fileprivate var isSuspended = false
        private var hasGallery = false
        private var isCameraPreviewVisible = true
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: MediaPickerScreen) {
            self.controller = controller
            self.presentationData = controller.presentationData
            
            var assetType: PHAssetMediaType?
            if case let .assets(_, mode) = controller.subject, case .wallpaper = mode {
                assetType = .image
            }
            let mediaAssetsContext = MediaAssetsContext(assetType: assetType)
            self.mediaAssetsContext = mediaAssetsContext
            
            self.containerNode = ASDisplayNode()
            self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
            self.backgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.gridNode = GridNode()
            self.scrollingArea = SparseItemGridScrollingArea()
            
            self.cameraActivateAreaNode = AccessibilityAreaNode()
            self.cameraActivateAreaNode.accessibilityLabel = "Camera"
            self.cameraActivateAreaNode.accessibilityTraits = [.button]
            
            super.init()
            
            if case .assets(nil, .default) = controller.subject {
            } else {
                self.preloadPromise.set(false)
            }
            
            self.addSubnode(self.containerNode)
            self.containerNode.addSubnode(self.backgroundNode)
            self.containerNode.addSubnode(self.gridNode)
            self.containerNode.addSubnode(self.scrollingArea)
            
            let preloadPromise = self.preloadPromise
            let updatedState: Signal<State, NoError>
            switch controller.subject {
            case let .assets(collection, _):
                updatedState = combineLatest(mediaAssetsContext.mediaAccess(), mediaAssetsContext.cameraAccess())
                |> mapToSignal { mediaAccess, cameraAccess -> Signal<State, NoError> in
                    if case .notDetermined = mediaAccess {
                        return .single(.assets(fetchResult: nil, preload: false, mediaAccess: mediaAccess, cameraAccess: cameraAccess))
                    } else if [.restricted, .denied].contains(mediaAccess) {
                        return .single(.noAccess(cameraAccess: cameraAccess))
                    } else {
                        if let collection = collection {
                            return combineLatest(mediaAssetsContext.fetchAssets(collection), preloadPromise.get())
                            |> map { fetchResult, preload in
                                return .assets(fetchResult: fetchResult, preload: preload, mediaAccess: mediaAccess, cameraAccess: cameraAccess)
                            }
                        } else {
                            return combineLatest(mediaAssetsContext.recentAssets(), preloadPromise.get())
                            |> map { fetchResult, preload in
                                return .assets(fetchResult: fetchResult, preload: preload, mediaAccess: mediaAccess, cameraAccess: cameraAccess)
                            }
                        }
                    }
                }
            case let .media(media):
                updatedState = .single(.media(media))
            }
            
            self.itemsDisposable = (updatedState
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateState(state)
            })
            
            self.gridNode.scrollingInitiated = { [weak self] in
                self?.dismissInput()
            }
            
            self.gridNode.visibleContentOffsetChanged = { [weak self] _ in
                self?.updateNavigation(transition: .immediate)
            }
            
            self.hiddenMediaDisposable = (self.hiddenMediaId.get()
            |> deliverOnMainQueue).start(next: { [weak self] id in
                if let strongSelf = self {
                    strongSelf.controller?.interaction?.hiddenMediaId = id
                    
                    strongSelf.gridNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? MediaPickerGridItemNode {
                            itemNode.updateHiddenMedia()
                        }
                    }
                    
                    strongSelf.selectionNode?.updateHiddenMedia()
                }
            })
            
            if let selectionState = self.controller?.interaction?.selectionState {
                func selectionChangedSignal(selectionState: TGMediaSelectionContext) -> Signal<Bool, NoError> {
                    return Signal { subscriber in
                        let disposable = selectionState.selectionChangedSignal()?.start(next: { next in
                            if let next = next as? TGMediaSelectionChange {
                                subscriber.putNext(next.animated)
                            }
                        }, completed: {})
                        return ActionDisposable {
                            disposable?.dispose()
                        }
                    }
                }
                
                self.selectionChangedDisposable = (selectionChangedSignal(selectionState: selectionState)
                |> deliverOnMainQueue).start(next: { [weak self] animated in
                    if let strongSelf = self {
                        strongSelf.updateSelectionState(animated: animated)
                    }
                })
            }
            
            if let editingState = self.controller?.interaction?.editingState {
                func itemsDimensionsUpdatedSignal(editingState: TGMediaEditingContext) -> Signal<Void, NoError> {
                    return Signal { subscriber in
                        let disposable = editingState.cropAdjustmentsUpdatedSignal()?.start(next: { next in
                            subscriber.putNext(Void())
                        }, completed: {})
                        return ActionDisposable {
                            disposable?.dispose()
                        }
                    }
                }
                
                self.itemsDimensionsUpdatedDisposable = (itemsDimensionsUpdatedSignal(editingState: editingState)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.updateSelectionState()
                    }
                })
            }
        }
        
        deinit {
            self.itemsDisposable?.dispose()
            self.hiddenMediaDisposable?.dispose()
            self.selectionChangedDisposable?.dispose()
            self.itemsDimensionsUpdatedDisposable?.dispose()
            self.fastScrollDisposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            guard let controller = self.controller else {
                return
            }
            
            self.gridNode.scrollView.alwaysBounceVertical = true
            self.gridNode.scrollView.showsVerticalScrollIndicator = false
            
            if case let .assets(_, mode) = controller.subject, case .wallpaper = mode {
                
            } else {
                let selectionGesture = MediaPickerGridSelectionGesture<TGMediaSelectableItem>()
                selectionGesture.delegate = self
                selectionGesture.began = { [weak self] in
                    self?.controller?.cancelPanGesture()
                }
                selectionGesture.updateIsScrollEnabled = { [weak self] isEnabled in
                    self?.gridNode.scrollView.isScrollEnabled = isEnabled
                }
                selectionGesture.itemAt = { [weak self] point in
                    if let strongSelf = self, let itemNode = strongSelf.gridNode.itemNodeAtPoint(point) as? MediaPickerGridItemNode, let selectableItem = itemNode.selectableItem {
                        return (selectableItem, strongSelf.controller?.interaction?.selectionState?.isIdentifierSelected(selectableItem.uniqueIdentifier) ?? false)
                    } else {
                        return nil
                    }
                }
                selectionGesture.updateSelection = { [weak self] asset, selected in
                    if let strongSelf = self {
                        strongSelf.controller?.interaction?.selectionState?.setItem(asset, selected: selected, animated: true, sender: nil)
                    }
                }
                selectionGesture.sideInset = 44.0
                self.gridNode.view.addGestureRecognizer(selectionGesture)
                self.selectionGesture = selectionGesture
            }
            
            if let controller = self.controller, case let .assets(collection, _) = controller.subject, collection != nil {
                self.gridNode.view.interactiveTransitionGestureRecognizerTest = { point -> Bool in
                    return point.x > 44.0
                }
                
                self.selectionGesture?.sideInset = 44.0
            }
            
            self.scrollingArea.beginScrolling = { [weak self] in
                guard let strongSelf = self else {
                    return nil
                }
                strongSelf.controller?.requestAttachmentMenuExpansion()
                strongSelf.isFastScrolling = true
                return strongSelf.gridNode.scrollView
            }
            self.scrollingArea.finishedScrolling = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isFastScrolling = false
            }
            self.scrollingArea.setContentOffset = { [weak self] offset in
                guard let strongSelf = self else {
                    return
                }
                Queue.concurrentDefaultQueue().async {
                    strongSelf.fastScrollContentOffset.set(offset)
                }
            }
            self.gridNode.visibleItemsUpdated = { [weak self] _ in
                self?.updateScrollingArea()
                
                if let self, let cameraView = self.cameraView {
                    self.isCameraPreviewVisible = self.gridNode.scrollView.bounds.intersects(cameraView.frame)
                    self.updateIsCameraActive()
                }
            }
            self.updateScrollingArea()
            
            let throttledContentOffsetSignal = self.fastScrollContentOffset.get()
            |> mapToThrottled { next -> Signal<CGPoint, NoError> in
                return .single(next) |> then(.complete() |> delay(0.02, queue: Queue.concurrentDefaultQueue()))
            }
            self.fastScrollDisposable = (throttledContentOffsetSignal
            |> deliverOnMainQueue).start(next: { [weak self] contentOffset in
                if let self {
                    self.gridNode.scrollView.setContentOffset(contentOffset, animated: false)
                }
            })
            
            if let controller = self.controller, case .assets(nil, .default) = controller.subject {
                let enableAnimations = self.controller?.context.sharedContext.energyUsageSettings.fullTranslucency ?? true
  
                let cameraView = TGAttachmentCameraView(forSelfPortrait: false, videoModeByDefault: controller.bannedSendPhotos != nil && controller.bannedSendVideos == nil)!
                cameraView.clipsToBounds = true
                cameraView.removeCorners()
                cameraView.pressed = { [weak self, weak cameraView] in
                    if let strongSelf = self, !strongSelf.openingMedia {
                        strongSelf.dismissInput()
                        strongSelf.controller?.openCamera?(strongSelf.cameraView)
                        
                        if !enableAnimations {
                            cameraView?.startPreview()
                        }
                    }
                }
                self.cameraView = cameraView
                
                if enableAnimations {
                    cameraView.startPreview()
                }
                
                self.gridNode.scrollView.addSubview(cameraView)
                self.gridNode.addSubnode(self.cameraActivateAreaNode)
            } else {
                self.containerNode.clipsToBounds = true
            }
        }
        
        func updateIsCameraActive() {
            let isCameraActive = !self.isSuspended && !self.hasGallery && self.isCameraPreviewVisible
            if isCameraActive {
                self.cameraView?.resumePreview()
            } else {
                self.cameraView?.pausePreview()
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer.view is UIScrollView || otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            } else {
                return false
            }
        }
                        
        fileprivate func dismissInput() {
            self.view.window?.endEditing(true)
        }
        
        private func scrollerTextForTag(tag: Int32) -> String {
            let month = Month(packedValue: tag)
            return stringForMonth(strings: self.presentationData.strings, month: month.month, ofYear: month.year)
        }
        
        private var currentScrollingTag: Int32?
        private func updateScrollingArea() {
            guard let (layout, _) = self.validLayout else {
                return
            }

            var tag: Int32?
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? MediaPickerGridItemNode {
                    tag = itemNode.tag
                }
            }

            let dateString = tag.flatMap { self.scrollerTextForTag(tag: $0) }
            if self.currentScrollingTag != tag {
                self.currentScrollingTag = tag
                if self.scrollingArea.isDragging {
                    self.scrollingArea.feedbackTap()
                }
            }

            self.scrollingArea.update(
                containerSize: layout.size,
                containerInsets: self.gridNode.gridLayout.insets,
                contentHeight: self.gridNode.scrollView.contentSize.height,
                contentOffset: self.gridNode.scrollView.bounds.minY,
                isScrolling: self.gridNode.scrollView.isDragging || self.gridNode.scrollView.isDecelerating,
                date: (dateString ?? "", tag ?? 0),
                theme: self.presentationData.theme,
                transition: .immediate
            )
        }
        
        private func updateState(_ state: State) {
            guard let controller = self.controller, let interaction = controller.interaction else {
                return
            }
            
            let previousState = self.state
            self.state = state
            
            var stableId: Int = 0
            var entries: [MediaPickerGridEntry] = []
            
            var updateLayout = false
            
            var selectable = true
            if case let .assets(_, mode) = controller.subject, mode != .default {
                selectable = false
            }
            
            switch state {
            case let .noAccess(cameraAccess):
                if case .assets = previousState {
                    updateLayout = true
                } else if case let .noAccess(previousCameraAccess) = previousState, previousCameraAccess != cameraAccess {
                    updateLayout = true
                }
                if case .notDetermined = cameraAccess, !self.requestedCameraAccess {
                    self.requestedCameraAccess = true
                    self.mediaAssetsContext.requestCameraAccess()
                }
            case let .assets(fetchResult, preload, mediaAccess, cameraAccess):
                if let fetchResult = fetchResult {
                    let totalCount = fetchResult.count
                    let count = preload ? min(13, totalCount) : totalCount
                    
                    for i in 0 ..< count {
                        let index: Int
                        if case let .assets(collection, _) = controller.subject, let _ = collection {
                            index = i
                        } else {
                            index = totalCount - i - 1
                        }
                        entries.append(MediaPickerGridEntry(stableId: stableId, content: .asset(fetchResult, index), selectable: selectable))
                        stableId += 1
                    }
                    
                    if case let .assets(previousFetchResult, _, _, previousCameraAccess) = previousState, previousFetchResult == nil || previousCameraAccess != cameraAccess {
                        updateLayout = true
                    }
                    
                    if case .notDetermined = cameraAccess, !self.requestedCameraAccess {
                        self.requestedCameraAccess = true
                        self.mediaAssetsContext.requestCameraAccess()
                    }
                } else if case .notDetermined = mediaAccess, !self.requestedMediaAccess {
                    self.requestedMediaAccess = true
                    self.mediaAssetsContext.requestMediaAccess()
                }
            case let .media(media):
                let count = media.count
                for i in 0 ..< count {
                    entries.append(MediaPickerGridEntry(stableId: stableId, content: .media(media[i], i), selectable: true))
                    stableId += 1
                }
            }
        
            let previousEntries = self.currentEntries
            self.currentEntries = entries
            
            var scrollToItem: GridNodeScrollToItem?
            if case let .assets(collection, _) = controller.subject, let _ = collection, previousEntries.isEmpty && !entries.isEmpty {
                scrollToItem = GridNodeScrollToItem(index: entries.count - 1, position: .bottom(0.0), transition: .immediate, directionHint: .down, adjustForSection: false)
            }
            
            let transaction = MediaPickerGridTransaction(previousList: previousEntries, list: entries, context: controller.context, interaction: interaction, theme: self.presentationData.theme, scrollToItem: scrollToItem)
            self.enqueueTransaction(transaction)
            
            if updateLayout, let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: previousState == nil ? .immediate : .animated(duration: 0.2, curve: .easeInOut))
            }
            self.updateNavigation(transition: .immediate)
        }
        
        private func updateSelectionState(animated: Bool = false) {
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? MediaPickerGridItemNode {
                    itemNode.updateSelectionState(animated: animated)
                }
            }
            self.selectionNode?.updateSelectionState()
            
            let count = Int32(self.controller?.interaction?.selectionState?.count() ?? 0)
            self.controller?.updateSelectionState(count: count)
            
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            self.backgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.backgroundNode.updateColor(color: self.presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        }
        
        private var currentDisplayMode: DisplayMode = .all
        func updateDisplayMode(_ displayMode: DisplayMode, animated: Bool = true) {
            let updated = self.currentDisplayMode != displayMode
            self.currentDisplayMode = displayMode
            
            self.dismissInput()
            self.controller?.dismissAllTooltips()
            
            if case .selected = displayMode, self.selectionNode == nil, let controller = self.controller {
                var persistentItems = false
                if case .media = controller.subject {
                    persistentItems = true
                }
                
                let selectionNode = MediaPickerSelectedListNode(context: controller.context, persistentItems: persistentItems)
                selectionNode.alpha = animated ? 0.0 : 1.0
                selectionNode.layer.allowsGroupOpacity = true
                selectionNode.isUserInteractionEnabled = false
                selectionNode.interaction = self.controller?.interaction
                selectionNode.getTransitionView = { [weak self] identifier in
                    if let strongSelf = self {
                        var node: MediaPickerGridItemNode?
                        strongSelf.gridNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                                node = itemNode
                            }
                        }
                        if let node = node {
                            return (node.view, node.spoilerNode?.dustNode, { [weak node] animateCheckNode in
                                node?.animateFadeIn(animateCheckNode: animateCheckNode, animateSpoilerNode: false)
                            })
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
                self.containerNode.insertSubnode(selectionNode, aboveSubnode: self.gridNode)
                self.selectionNode = selectionNode
                
                if let (layout, navigationBarHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            }
            
            self.gridNode.isUserInteractionEnabled = displayMode == .all
            self.selectionNode?.isUserInteractionEnabled = displayMode == .selected
            
            var completion: () -> Void = {}
            if updated && displayMode == .all {
                completion = {
                    self.updateNavigation(transition: .animated(duration: 0.1, curve: .easeInOut))
                    self.selectionNode?.alpha = 0.0
                }
            }
            
            if updated {
                if animated {
                    switch displayMode {
                    case .selected:
                        self.selectionNode?.animateIn(initiated: { [weak self] in
                            self?.updateNavigation(transition: .immediate)
                        }, completion: completion)
                    case .all:
                        self.selectionNode?.animateOut(completion: completion)
                    }
                } else {
                    self.updateNavigation(transition: .immediate)
                }
            }
        }
        
        private weak var currentGalleryController: TGModernGalleryController?
        
        private var openingMedia = false
        fileprivate func openMedia(fetchResult: PHFetchResult<PHAsset>, index: Int, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, let interaction = controller.interaction, let (layout, _) = self.validLayout, !self.openingMedia else {
                return
            }
            Queue.mainQueue().justDispatch {
                self.dismissInput()
            }
    
            if let customSelection = controller.customSelection {
                self.openingMedia = true
                customSelection(fetchResult[index])
                Queue.mainQueue().after(0.3) {
                    self.openingMedia = false
                }
                return
            }
            
            let reversed: Bool
            if case .assets(nil, _) = controller.subject {
                reversed = true
            } else {
                reversed = false
            }
            let index = reversed ? fetchResult.count - index - 1 : index
            
            var hasTimer = false
            if controller.chatLocation?.peerId != controller.context.account.peerId && controller.chatLocation?.peerId?.namespace == Namespaces.Peer.CloudUser {
                hasTimer = true
            }
            
            let hasSchedule = true
            
            self.openingMedia = true
            
            self.currentGalleryController = presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, threadTitle: controller.threadTitle, chatLocation: controller.chatLocation, presentationData: self.presentationData, source: .fetchResult(fetchResult: fetchResult, index: index, reversed: reversed), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: hasSchedule, hasTimer: hasTimer, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.gridNode.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime, completion in
                if let strongSelf = self {
                    strongSelf.controller?.interaction?.sendSelected(result, silently, scheduleTime, false, completion)
                }
            }, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, finishedTransitionIn: { [weak self] in
                self?.openingMedia = false
                self?.hasGallery = true
                self?.updateIsCameraActive()
            }, willTransitionOut: { [weak self] in
                self?.hasGallery = false
                self?.updateIsCameraActive()
            }, dismissAll: { [weak self] in
                self?.controller?.dismissAll()
            })
        }
        
        fileprivate func openSelectedMedia(item: TGMediaSelectableItem, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, let interaction = controller.interaction, let (layout, _) = self.validLayout, !self.openingMedia else {
                return
            }
            Queue.mainQueue().justDispatch {
                self.dismissInput()
            }
            
            var hasTimer = false
            if controller.chatLocation?.peerId != controller.context.account.peerId && controller.chatLocation?.peerId?.namespace == Namespaces.Peer.CloudUser {
                hasTimer = true
            }
            
            self.openingMedia = true
            self.currentGalleryController = presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, threadTitle: controller.threadTitle, chatLocation: controller.chatLocation, presentationData: self.presentationData, source: .selection(item: item), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: true, hasTimer: hasTimer, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.selectionNode?.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime, completion in
                if let strongSelf = self {
                    strongSelf.controller?.interaction?.sendSelected(result, silently, scheduleTime, false, completion)
                }
            }, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, finishedTransitionIn: { [weak self] in
                self?.openingMedia = false
                self?.hasGallery = true
                self?.updateIsCameraActive()
            }, willTransitionOut: { [weak self] in
                self?.hasGallery = false
                self?.updateIsCameraActive()
            }, dismissAll: { [weak self] in
                self?.controller?.dismissAll()
            })
        }
        
        fileprivate func send(asFile: Bool = false, silently: Bool, scheduleTime: Int32?, animated: Bool, completion: @escaping () -> Void) {
            guard let controller = self.controller, !controller.completed else {
                return
            }
            controller.dismissAllTooltips()
            
            var hasHeic = false
            let allItems = controller.interaction?.selectionState?.selectedItems() ?? []
            for item in allItems {
                if item is TGCameraCapturedVideo {
                } else if let asset = item as? TGMediaAsset, asset.uniformTypeIdentifier.contains("heic") {
                    hasHeic = true
                    break
                }
            }
            
            let proceed: (Bool) -> Void = { convertToJpeg in
                let signals: [Any]!
                switch controller.subject {
                case .assets:
                    signals = TGMediaAssetsController.resultSignals(for: controller.interaction?.selectionState, editingContext: controller.interaction?.editingState, intent: asFile ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent, currentItem: nil, storeAssets: true, convertToJpeg: convertToJpeg, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: controller.saveEditedPhotos)
                case .media:
                    signals = TGMediaAssetsController.pasteboardResultSignals(for: controller.interaction?.selectionState, editingContext: controller.interaction?.editingState, intent: asFile ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent, currentItem: nil, descriptionGenerator: legacyAssetPickerItemGenerator())
                }
                guard let signals = signals else {
                    return
                }
                controller.completed = true
                controller.legacyCompletion(signals, silently, scheduleTime, { [weak self] identifier in
                    return !asFile ? self?.getItemSnapshot(identifier) : nil
                }, { [weak self] in
                    completion()
                    self?.controller?.dismiss(animated: animated)
                })
            }
            
            if asFile && hasHeic {
                controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.MediaPicker_JpegConversionText, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.MediaPicker_KeepHeic, action: {
                    proceed(false)
                }), TextAlertAction(type: .genericAction, title: self.presentationData.strings.MediaPicker_ConvertToJpeg, action: {
                    proceed(true)
                })], actionLayout: .vertical), in: .window(.root))
            } else {
                proceed(false)
            }
        }

        private func openLimitedMediaOptions() {
            let presentationData = self.presentationData
            let controller = ActionSheetController(presentationData: self.presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Media_LimitedAccessSelectMore, color: .accent, action: { [weak self] in
                        dismissAction()
                        if #available(iOS 14.0, *), let strongController = self?.controller {
                            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: strongController)
                        }
                    }),
                    ActionSheetButtonItem(title: presentationData.strings.Media_LimitedAccessChangeSettings, color: .accent, action: { [weak self] in
                        dismissAction()
                        self?.controller?.context.sharedContext.applicationBindings.openSettings()
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            self.controller?.present(controller, in: .window(.root))
        }
        
        private func getItemSnapshot(_ identifier: String) -> UIView? {
            guard let selectionState = self.controller?.interaction?.selectionState else {
                return nil
            }
            
            if let galleryController = self.currentGalleryController {
                if selectionState.count() > 1 {
                    return nil
                }
                
                return galleryController.transitionView()
            }
            
            if selectionState.grouping && selectionState.count() > 1 && (self.selectionNode?.alpha ?? 0.0).isZero {
                return nil
            }
            
            if let view = self.transitionView(for: identifier, hideSource: true) {
                return view
            } else {
                return nil
            }
        }
        
        private func transitionView(for identifier: String, hideSource: Bool = false) -> UIView? {
            if let selectionNode = self.selectionNode, selectionNode.alpha > 0.0 {
                return selectionNode.transitionView(for: identifier, hideSource: hideSource)
            } else {
                var transitionNode: MediaPickerGridItemNode?
                self.gridNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                        transitionNode = itemNode
                    }
                }
                let transitionView = transitionNode?.transitionView()
                if hideSource {
                    transitionNode?.isHidden = true
                }
                return transitionView
            }
        }
        
        private func enqueueTransaction(_ transaction: MediaPickerGridTransaction) {
            self.enqueuedTransactions.append(transaction)
            
            if let _ = self.validLayout {
                self.dequeueTransaction()
            }
        }
        
        private func dequeueTransaction() {
            if self.enqueuedTransactions.isEmpty {
                return
            }
            let transaction = self.enqueuedTransactions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transaction.deletions, insertItems: transaction.insertions, updateItems: transaction.updates, scrollToItem: transaction.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        }
        
        func scrollToTop(animated: Bool = false) {
            if let selectionNode = self.selectionNode, selectionNode.alpha > 0.0 {
                selectionNode.scrollToTop(animated: animated)
            } else {
                self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.gridNode.scrollView.contentInset.top), animated: animated)
            }
        }
        
        private var previousContentOffset: GridNodeVisibleContentOffset?
        
        func updateNavigation(delayDisappear: Bool = false, transition: ContainedViewLayoutTransition) {
            if let selectionNode = self.selectionNode, selectionNode.alpha > 0.0 {
                self.controller?.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                self.controller?.updateTabBarAlpha(1.0, transition)
            } else if self.placeholderNode != nil {
                self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
                
                if delayDisappear {
                    Queue.mainQueue().after(0.25) {
                        self.controller?.updateTabBarAlpha(0.0, transition)
                    }
                } else {
                    self.controller?.updateTabBarAlpha(0.0, transition)
                }
            } else {
                var previousContentOffsetValue: CGFloat?
                if let previousContentOffset = self.previousContentOffset, case let .known(value) = previousContentOffset {
                    previousContentOffsetValue = value
                }
                
                let offset = self.gridNode.visibleContentOffset()
                switch offset {
                    case let .known(value):
                        let transition: ContainedViewLayoutTransition
                        if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue > 2.0 {
                            transition = .animated(duration: 0.2, curve: .easeInOut)
                        } else {
                            transition = .immediate
                        }
                        self.controller?.navigationBar?.updateBackgroundAlpha(min(2.0, value) / 2.0, transition: transition)
                    case .unknown, .none:
                        self.controller?.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                }
                self.controller?.updateTabBarAlpha(1.0, transition)
            }
            
            let count = Int32(self.controller?.interaction?.selectionState?.count() ?? 0)
            if count > 0 {
                self.controller?.updateTabBarAlpha(1.0, transition)
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let firstTime = self.validLayout == nil
            self.validLayout = (layout, navigationBarHeight)
            
            var insets = layout.insets(options: [])
            insets.top += navigationBarHeight
            
            let bounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height))
            let innerBounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height))
            
            let itemsPerRow: Int
            if case .compact = layout.metrics.widthClass {
                self._ready.set(.single(true))
                switch layout.orientation {
                    case .portrait:
                        itemsPerRow = 3
                    case .landscape:
                        itemsPerRow = 5
                }
            } else {
                itemsPerRow = 3
            }
            let width = layout.size.width - layout.safeInsets.left - layout.safeInsets.right
            let itemSpacing: CGFloat = 1.0
            let itemWidth = floorToScreenPixels((width - itemSpacing * CGFloat(itemsPerRow - 1)) / CGFloat(itemsPerRow))
            
            var cameraRect: CGRect? = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: 0.0), size: CGSize(width: itemWidth, height: itemWidth * 2.0 + 1.0))
            if self.cameraView == nil {
                cameraRect = nil
            }
            
            var manageHeight: CGFloat = 0.0
            if case let .assets(_, _, mediaAccess, cameraAccess) = self.state {
                if cameraAccess == nil {
                    cameraRect = nil
                }
                
                var bannedSendMedia: (Int32, Bool)?
                if let bannedSendPhotos = self.controller?.bannedSendPhotos, let bannedSendVideos = self.controller?.bannedSendVideos {
                    bannedSendMedia = (max(bannedSendPhotos.0, bannedSendVideos.0), bannedSendPhotos.1 || bannedSendVideos.1)
                }
                
                if let (untilDate, personal) = bannedSendMedia {
                    self.gridNode.isHidden = true
                    
                    let banDescription: String
                    if untilDate != 0 && untilDate != Int32.max {
                        banDescription = self.presentationData.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat)).string
                    } else if personal {
                        banDescription = self.presentationData.strings.Conversation_RestrictedMedia
                    } else {
                        banDescription = self.presentationData.strings.Conversation_DefaultRestrictedMedia
                    }
                    
                    var placeholderTransition = transition
                    let placeholderNode: MediaPickerPlaceholderNode
                    if let current = self.placeholderNode {
                        placeholderNode = current
                    } else {
                        placeholderNode = MediaPickerPlaceholderNode(content: .bannedSendMedia(banDescription))
                        self.containerNode.insertSubnode(placeholderNode, aboveSubnode: self.gridNode)
                        self.placeholderNode = placeholderNode
                        
                        placeholderTransition = .immediate
                    }
                    placeholderNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, hasCamera: false, transition: placeholderTransition)
                    placeholderTransition.updateFrame(node: placeholderNode, frame: innerBounds)
                    
                    self.updateNavigation(transition: .immediate)
                } else if case .notDetermined = mediaAccess {
                } else {
                    if case .limited = mediaAccess {
                        let manageNode: MediaPickerManageNode
                        if let current = self.manageNode {
                            manageNode = current
                        } else {
                            manageNode = MediaPickerManageNode()
                            manageNode.pressed = { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.openLimitedMediaOptions()
                                }
                            }
                            self.manageNode = manageNode
                            self.gridNode.addSubnode(manageNode)
                        }
                        manageHeight = manageNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, subject: .limitedMedia, transition: transition)
                        transition.updateFrame(node: manageNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -manageHeight), size: CGSize(width: layout.size.width, height: manageHeight)))
                    } else if [.denied, .restricted].contains(cameraAccess) {
                        cameraRect = nil
                        
                        let manageNode: MediaPickerManageNode
                        if let current = self.manageNode {
                            manageNode = current
                        } else {
                            manageNode = MediaPickerManageNode()
                            manageNode.pressed = { [weak self] in
                                self?.controller?.context.sharedContext.applicationBindings.openSettings()
                            }
                            self.manageNode = manageNode
                            self.gridNode.addSubnode(manageNode)
                        }
                        manageHeight = manageNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, subject: .camera, transition: transition)
                        transition.updateFrame(node: manageNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -manageHeight), size: CGSize(width: layout.size.width, height: manageHeight)))
                    } else if let manageNode = self.manageNode {
                        self.manageNode = nil
                        manageNode.removeFromSupernode()
                    }
                }
            } else {
                cameraRect = nil
            }
            
            let cleanGridInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
            let gridInsets = UIEdgeInsets(top: insets.top + manageHeight, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
            transition.updateFrame(node: self.gridNode, frame: innerBounds)
            self.scrollingArea.frame = innerBounds
            
            transition.updateFrame(node: self.backgroundNode, frame: innerBounds)
            self.backgroundNode.update(size: bounds.size, transition: transition)
            
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: bounds.height)))
            
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: bounds.size, insets: gridInsets, scrollIndicatorInsets: nil, preloadSize: itemWidth, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth), fillWidth: true, lineSpacing: itemSpacing, itemSpacing: itemSpacing), cutout: cameraRect), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.didSetReady && strongSelf.state != nil {
                    strongSelf.didSetReady = true
                    Queue.mainQueue().justDispatch {
                        strongSelf._ready.set(.single(true)
                        |> delay(0.05, queue: Queue.mainQueue()))
                        
                        Queue.mainQueue().after(0.5, {
                            strongSelf.preloadPromise.set(false)
                        })
                    }
                }
            })
            
            if let selectionNode = self.selectionNode, let controller = self.controller {
                let selectedItems = controller.interaction?.selectionState?.selectedItems() as? [TGMediaSelectableItem] ?? []
                let updateSelectionNode = {
                    selectionNode.updateLayout(size: bounds.size, insets: cleanGridInsets, items: selectedItems, grouped: self.controller?.groupedValue ?? true, theme: self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper, bubbleCorners: self.presentationData.chatBubbleCorners, transition: transition)
                }
                
                if selectedItems.count < 1 && self.currentDisplayMode == .selected {
                    self.updateDisplayMode(.all)
                    Queue.mainQueue().after(0.3, updateSelectionNode)
                } else {
                    updateSelectionNode()
                }
                transition.updateFrame(node: selectionNode, frame: innerBounds)
            }
            
            if let cameraView = self.cameraView {
                if let cameraRect = cameraRect {
                    transition.updateFrame(view: cameraView, frame: cameraRect)
                    self.cameraActivateAreaNode.frame = cameraRect
                    cameraView.isHidden = false
                } else {
                    cameraView.isHidden = true
                }
            }
            
            if firstTime {
                while !self.enqueuedTransactions.isEmpty {
                    self.dequeueTransaction()
                }
            }
            
            var bannedSendMedia: (Int32, Bool)?
            if let bannedSendPhotos = self.controller?.bannedSendPhotos, let bannedSendVideos = self.controller?.bannedSendVideos {
                bannedSendMedia = (max(bannedSendPhotos.0, bannedSendVideos.0), bannedSendPhotos.1 || bannedSendVideos.1)
            }
            
            if case let .noAccess(cameraAccess) = self.state {
                var placeholderTransition = transition
                let placeholderNode: MediaPickerPlaceholderNode
                if let current = self.placeholderNode {
                    placeholderNode = current
                } else {
                    placeholderNode = MediaPickerPlaceholderNode(content: .intro)
                    placeholderNode.settingsPressed = { [weak self] in
                        self?.controller?.context.sharedContext.applicationBindings.openSettings()
                    }
                    placeholderNode.cameraPressed = { [weak self] in
                        self?.dismissInput()
                        self?.controller?.openCamera?(nil)
                    }
                    self.containerNode.insertSubnode(placeholderNode, aboveSubnode: self.gridNode)
                    self.placeholderNode = placeholderNode
                    
                    if transition.isAnimated {
                        placeholderNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    placeholderTransition = .immediate
                    
                    self.updateNavigation(transition: .immediate)
                }
                placeholderNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, hasCamera: cameraAccess == .authorized, transition: placeholderTransition)
                placeholderTransition.updateFrame(node: placeholderNode, frame: innerBounds)
            } else if let placeholderNode = self.placeholderNode, bannedSendMedia == nil {
                self.placeholderNode = nil
                placeholderNode.removeFromSupernode()
            }
        }
    }
    
    private var validLayout: ContainerViewLayout?
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var groupedValue: Bool = true {
        didSet {
            self.groupedPromise.set(self.groupedValue)
            self.interaction?.selectionState?.grouping = self.groupedValue
            
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
    }
    private let groupedPromise = ValuePromise<Bool>(true)
    
    private var isDismissing = false
    
    fileprivate let mainButtonState: AttachmentMainButtonState?
    private let mainButtonAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        peer: EnginePeer?,
        threadTitle: String?,
        chatLocation: ChatLocation?,
        bannedSendPhotos: (Int32, Bool)?,
        bannedSendVideos: (Int32, Bool)?,
        subject: Subject,
        editingContext: TGMediaEditingContext? = nil,
        selectionContext: TGMediaSelectionContext? = nil,
        saveEditedPhotos: Bool = false,
        mainButtonState: AttachmentMainButtonState? = nil,
        mainButtonAction: (() -> Void)? = nil
    ) {
        self.context = context
                
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.updatedPresentationData = updatedPresentationData
        self.peer = peer
        self.threadTitle = threadTitle
        self.chatLocation = chatLocation
        self.bannedSendPhotos = bannedSendPhotos
        self.bannedSendVideos = bannedSendVideos
        self.subject = subject
        self.saveEditedPhotos = saveEditedPhotos
        self.mainButtonState = mainButtonState
        self.mainButtonAction = mainButtonAction
        
        let selectionContext = selectionContext ?? TGMediaSelectionContext()
        
        self.titleView = MediaPickerTitleView(theme: self.presentationData.theme, segments: [self.presentationData.strings.Attachment_AllMedia, self.presentationData.strings.Attachment_SelectedMedia(1)], selectedIndex: 0)
        
        if case let .assets(collection, mode) = subject {
            if let collection = collection {
                self.titleView.title = collection.localizedTitle ?? presentationData.strings.Attachment_Gallery
            } else {
                switch mode {
                case .default:
                    self.titleView.title = presentationData.strings.Attachment_Gallery
                case .wallpaper:
                    self.titleView.title = presentationData.strings.Conversation_Theme_ChooseWallpaperTitle
                }
            }
        } else {
            self.titleView.title = presentationData.strings.Attachment_Gallery
        }
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
                
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.statusBar.statusBarStyle = .Ignore
        
        selectionContext.attemptSelectingItem = { [weak self] item in
            guard let self else {
                return false
            }
            if let _ = item as? TGMediaPickerGalleryPhotoItem {
                if self.bannedSendPhotos != nil {
                    self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedPhoto, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    
                    return false
                }
            } else if let _ = item as? TGMediaPickerGalleryVideoItem {
                if self.bannedSendVideos != nil {
                    self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedVideo, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    
                    return false
                }
            } else if let asset = item as? TGMediaAsset {
                if asset.isVideo {
                    if self.bannedSendVideos != nil {
                        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedVideo, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                } else {
                    if self.bannedSendPhotos != nil {
                        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedPhoto, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            }
            
            return true
        }
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.titleView.indexUpdated = { [weak self] index in
            if let strongSelf = self {
                strongSelf.controllerNode.updateDisplayMode(index == 0 ? .all : .selected)
            }
        }
                
        self.navigationItem.titleView = self.titleView
        
        if case let .assets(_, mode) = self.subject, mode != .default {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        } else {
            if case let .assets(collection, _) = self.subject, collection != nil {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.backPressed))
            } else {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
            }
            
            if self.bannedSendPhotos != nil && self.bannedSendVideos != nil {
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
                self.navigationItem.rightBarButtonItem?.action = #selector(self.rightButtonPressed)
                self.navigationItem.rightBarButtonItem?.target = self
            }
        }
        
        self.moreButtonNode.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.searchOrMorePressed(node: strongSelf.moreButtonNode.contextSourceNode, gesture: gesture)
            }
        }
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let webSearchController = strongSelf.webSearchController {
                    webSearchController.scrollToTop?()
                } else {
                    strongSelf.controllerNode.scrollToTop(animated: true)
                }
            }
        }
        
        self.scrollToTopWithTabBar = { [weak self] in
            if let strongSelf = self {
                if let webSearchController = strongSelf.webSearchController {
                    webSearchController.cancel()
                } else {
                    strongSelf.scrollToTop?()
                }
            }
        }
        
        self.interaction = MediaPickerInteraction(openMedia: { [weak self] fetchResult, index, immediateThumbnail in
            self?.controllerNode.openMedia(fetchResult: fetchResult, index: index, immediateThumbnail: immediateThumbnail)
        }, openSelectedMedia: { [weak self] item, immediateThumbnail in
            self?.controllerNode.openSelectedMedia(item: item, immediateThumbnail: immediateThumbnail)
        }, toggleSelection: { [weak self] item, value, suggestUndo in
            if let self = self, let selectionState = self.interaction?.selectionState {
                if let _ = item as? TGMediaPickerGalleryPhotoItem {
                    if self.bannedSendPhotos != nil {
                        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedPhoto, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                } else if let _ = item as? TGMediaPickerGalleryVideoItem {
                    if self.bannedSendVideos != nil {
                        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedVideo, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                } else if let asset = item as? TGMediaAsset {
                    if asset.isVideo {
                        if self.bannedSendVideos != nil {
                            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedVideo, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return false
                        }
                    } else {
                        if self.bannedSendPhotos != nil {
                            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Chat_SendNotAllowedPhoto, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return false
                        }
                    }
                }
                
                var showUndo = false
                if suggestUndo {
                    if !value {
                        selectionState.saveState()
                        showUndo = true
                    } else {
                        selectionState.clearSavedState()
                    }
                }
                
                let success = selectionState.setItem(item, selected: value)
                
                if showUndo {
                    self.showSelectionUndo(item: item)
                }
                
                return success
            } else {
                return false
            }
        }, sendSelected: { [weak self] currentItem, silently, scheduleTime, animated, completion in
            if let strongSelf = self, let selectionState = strongSelf.interaction?.selectionState, !strongSelf.isDismissing {
                strongSelf.isDismissing = true
                if let currentItem = currentItem {
                    selectionState.setItem(currentItem, selected: true)
                }
                strongSelf.controllerNode.send(silently: silently, scheduleTime: scheduleTime, animated: animated, completion: completion)
            }
        }, schedule: { [weak self] in
            if let strongSelf = self {
                strongSelf.presentSchedulePicker(false, { [weak self] time in
                    self?.interaction?.sendSelected(nil, false, time, true, {})
                })
            }
        }, dismissInput: { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.dismissInput()
            }
        }, selectionState: selectionContext, editingState: editingContext ?? TGMediaEditingContext())
        self.interaction?.selectionState?.grouping = true
        
        if case let .media(media) = self.subject {
            for item in media {
                selectionContext.setItem(item.asset, selected: true)
            }
        }
        
        self.updateSelectionState(count: Int32(selectionContext.count()))
        
        self.longTapWithTabBar = { [weak self] in
            if let strongSelf = self {
                strongSelf.presentSearch(activateOnDisplay: false)
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        
        self._ready.set(self.controllerNode.ready.get())
        
        if case .media = self.subject {
            self.controllerNode.updateDisplayMode(.selected, animated: false)
        }
        
        super.displayNodeDidLoad()
    }
    
    private weak var undoOverlayController: UndoOverlayController?
    private func showSelectionUndo(item: TGMediaSelectableItem) {
        let scale = min(2.0, UIScreenScale)
        let targetSize = CGSize(width: 64.0 * scale, height: 64.0 * scale)
        
        let image: Signal<UIImage?, NoError>
        if let item = item as? TGMediaAsset {
            image = assetImage(asset: item.backingAsset, targetSize: targetSize, exact: false)
        } else if let item = item as? TGCameraCapturedVideo {
            image = assetImage(asset: item.originalAsset.backingAsset, targetSize: targetSize, exact: false)
        } else if let item = item as? TGMediaEditableItem {
            image = Signal<UIImage?, NoError> { subscriber in
                let disposable = item.thumbnailImageSignal?().start(next: { next in
                    if let next = next as? UIImage {
                        subscriber.putNext(next)
                    }
                }, error: { _ in
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return ActionDisposable {
                    disposable?.dispose()
                }
            }
        } else {
            return
        }

        let _ = (image
        |> deliverOnMainQueue).start(next: { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            
            var photosCount = 0
            var videosCount = 0
            strongSelf.interaction?.selectionState?.enumerateDeselectedItems({ item in
                if let item = item as? TGMediaAsset {
                    if item.isVideo {
                        videosCount += 1
                    } else {
                        photosCount += 1
                    }
                } else if let _ = item as? TGCameraCapturedVideo {
                    videosCount += 1
                } else if let _ = item as? UIImage {
                    photosCount += 1
                }
            })
            let totalCount = Int32(photosCount + videosCount)
            
            let presentationData = strongSelf.presentationData
            let text: String
            if photosCount > 0 && videosCount > 0 {
                text = presentationData.strings.Attachment_DeselectedItems(totalCount)
            } else if photosCount > 0 {
                text = presentationData.strings.Attachment_DeselectedPhotos(totalCount)
            } else if videosCount > 0 {
                text = presentationData.strings.Attachment_DeselectedVideos(totalCount)
            } else {
                text = presentationData.strings.Attachment_DeselectedItems(totalCount)
            }
            
            if let undoOverlayController = strongSelf.undoOverlayController {
                undoOverlayController.content = .image(image: image ?? UIImage(), title: nil, text: text, round: false, undoText: presentationData.strings.Undo_Undo)
            } else {
                var elevatedLayout = true
                if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                    elevatedLayout = false
                }
                let undoOverlayController = UndoOverlayController(presentationData: presentationData, content: .image(image: image ?? UIImage(), title: nil, text: text, round: false, undoText: presentationData.strings.Undo_Undo), elevatedLayout: elevatedLayout, action: { [weak self] action in
                    guard let strongSelf = self else {
                        return true
                    }
                    switch action {
                        case .undo:
                            strongSelf.interaction?.selectionState?.restoreState()
                        default:
                            strongSelf.interaction?.selectionState?.clearSavedState()
                    }
                    return true
                })
                if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                    strongSelf.present(undoOverlayController, in: .current)
                } else {
                    strongSelf.present(undoOverlayController, in: .window(.root))
                }
                strongSelf.undoOverlayController = undoOverlayController
            }
        })
    }
    
    private var selectionCount: Int32 = 0
    fileprivate func updateSelectionState(count: Int32) {
        self.selectionCount = count
        
        if case let .media(media) = self.subject {
            self.titleView.title = media.count == 1 ? self.presentationData.strings.Attachment_Pasteboard : self.presentationData.strings.Attachment_SelectedMedia(count)
            self.titleView.segmentsHidden = true
            self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        } else {
            if count > 0 {
                self.titleView.segments = [self.presentationData.strings.Attachment_AllMedia, self.presentationData.strings.Attachment_SelectedMedia(count)]
                self.titleView.segmentsHidden = false
                self.moreButtonNode.iconNode.enqueueState(.more, animated: true)
            } else {
                self.titleView.segmentsHidden = true
                self.moreButtonNode.iconNode.enqueueState(.search, animated: true)
                
                if self.titleView.index != 0 {
                    Queue.mainQueue().after(0.3) {
                        self.titleView.index = 0
                    }
                }
            }
        }
    }
    
    private func updateThemeAndStrings() {
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.titleView.theme = self.presentationData.theme
        self.moreButtonNode.theme = self.presentationData.theme
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    @objc private func backPressed() {
        if let _ = self.navigationController {
            self.dismiss()
        } else {
            self.updateNavigationStack { current in
                var mediaPickerContext: AttachmentMediaPickerContext?
                if let first = current.first as? MediaPickerScreen {
                    mediaPickerContext = first.webSearchController?.mediaPickerContext ?? first.mediaPickerContext
                }
                return (current.filter { $0 !== self }, mediaPickerContext)
            }
        }
    }
    
    func mainButtonPressed() {
        self.mainButtonAction?()
    }
    
    func dismissAllTooltips() {
        self.undoOverlayController?.dismissWithCommitAction()
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        if let selectionState = self.interaction?.selectionState, selectionState.count() > 0 {
            self.isDismissing = true
            
            let text: String
            if case .media = self.subject {
                text = self.presentationData.strings.Attachment_DiscardPasteboardAlertText
            } else {
                text = self.presentationData.strings.Attachment_CancelSelectionAlertText
            }
            
            let controller = textAlertController(context: self.context, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Attachment_CancelSelectionAlertNo, action: {
            }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Attachment_CancelSelectionAlertYes, action: { [weak self] in
                self?.dismissAllTooltips()
                completion()
            })])
            controller.dismissed = { [weak self] _ in
                self?.isDismissing = false
            }
            self.present(controller, in: .window(.root))
        } else {
            completion()
        }
    }
    
    public func shouldDismissImmediately() -> Bool {
        if let selectionState = self.interaction?.selectionState, selectionState.count() > 0 {
            return false
        } else {
            return true
        }
    }
    
    @objc private func cancelPressed() {
        self.dismissAllTooltips()
        
        self.dismiss()
    }
    
    @objc private func rightButtonPressed() {
        self.moreButtonNode.buttonPressed()
    }
    
    public func resetForReuse() {
        if let webSearchController = self.webSearchController {
            self.webSearchController = nil
            webSearchController.dismiss()
        }
        self.scrollToTop?()
        
        self.controllerNode.isSuspended = true
        self.controllerNode.updateIsCameraActive()
    }
    
    public func prepareForReuse() {
        self.controllerNode.isSuspended = false
        self.controllerNode.updateIsCameraActive()
        self.controllerNode.updateNavigation(delayDisappear: true, transition: .immediate)
    }
    
    private func presentSearch(activateOnDisplay: Bool) {
        guard self.moreButtonNode.iconNode.iconState == .search, case let .assets(_, mode) = self.subject else {
            return
        }
        self.requestAttachmentMenuExpansion()
        self.presentWebSearch(MediaGroupsScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, mediaAssetsContext: self.controllerNode.mediaAssetsContext, openGroup: { [weak self] collection in
            if let strongSelf = self {
                let mediaPicker = MediaPickerScreen(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: strongSelf.peer, threadTitle: strongSelf.threadTitle, chatLocation: strongSelf.chatLocation, bannedSendPhotos: strongSelf.bannedSendPhotos, bannedSendVideos: strongSelf.bannedSendVideos, subject: .assets(collection, mode), editingContext: strongSelf.interaction?.editingState, selectionContext: strongSelf.interaction?.selectionState)
                
                mediaPicker.presentSchedulePicker = strongSelf.presentSchedulePicker
                mediaPicker.presentTimerPicker = strongSelf.presentTimerPicker
                mediaPicker.getCaptionPanelView = strongSelf.getCaptionPanelView
                mediaPicker.legacyCompletion = strongSelf.legacyCompletion
                mediaPicker.dismissAll = { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
                
                mediaPicker._presentedInModal = true
                mediaPicker.updateNavigationStack = strongSelf.updateNavigationStack
                strongSelf.updateNavigationStack({ _ in return ([strongSelf, mediaPicker], strongSelf.mediaPickerContext)})
            }
        }), activateOnDisplay)
    }
    
    @objc private func searchOrMorePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        switch self.moreButtonNode.iconNode.iconState {
            case .search:
                self.presentSearch(activateOnDisplay: true)
            case .more:
                let strings = self.presentationData.strings
                let selectionCount = self.selectionCount
            
                var isSpoilerAvailable = true
                if let peer = self.peer, case .secretChat = peer {
                    isSpoilerAvailable = false
                }
            
                var hasSpoilers = false
                var hasGeneric = false
                if let selectionContext = self.interaction?.selectionState, let editingContext = self.interaction?.editingState {
                    for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                        if editingContext.spoiler(for: item) {
                            hasSpoilers = true
                        } else {
                            hasGeneric = true
                        }
                    }
                }
                        
                let items: Signal<ContextController.Items, NoError>  = self.groupedPromise.get()
                |> deliverOnMainQueue
                |> map { [weak self] grouped -> ContextController.Items in
                    var items: [ContextMenuItem] = []
                    if !hasSpoilers {
                        items.append(.action(ContextMenuActionItem(text: selectionCount > 1 ? strings.Attachment_SendAsFiles : strings.Attachment_SendAsFile, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/File"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            self?.controllerNode.send(asFile: true, silently: false, scheduleTime: nil, animated: true, completion: {})
                        })))
                    }
                    if selectionCount > 1 {
                        if !items.isEmpty {
                            items.append(.separator)
                        }
                        items.append(.action(ContextMenuActionItem(text: strings.Attachment_Grouped, icon: { theme in
                            if !grouped {
                                return nil
                            }
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            self?.groupedValue = true
                        })))
                        items.append(.action(ContextMenuActionItem(text: strings.Attachment_Ungrouped, icon: { theme in
                            if grouped {
                                return nil
                            }
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                        }, action: {  [weak self] _, f in
                            f(.default)
                            
                            self?.groupedValue = false
                        })))
                    }
                    if isSpoilerAvailable {
                        if !items.isEmpty {
                            items.append(.separator)
                        }
                        items.append(.action(ContextMenuActionItem(text: hasGeneric ? strings.Attachment_EnableSpoiler : strings.Attachment_DisableSpoiler, icon: { _ in return nil }, animationName: "anim_spoiler", action: { [weak self]  _, f in
                            f(.default)
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let selectionContext = strongSelf.interaction?.selectionState, let editingContext = strongSelf.interaction?.editingState {
                                for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                                    editingContext.setSpoiler(hasGeneric, for: item)
                                }
                            }
                        })))
                    }
                    return ContextController.Items(content: .list(items))
                }
            
                let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(MediaPickerContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
                self.presentInGlobalOverlay(contextController)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return MediaPickerContext(controller: self)
    }
}

final class MediaPickerContext: AttachmentMediaPickerContext {
    private weak var controller: MediaPickerScreen?
    
    var selectionCount: Signal<Int, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = self?.controller?.interaction?.selectionState?.selectionChangedSignal().start(next: { [weak self] value in
                subscriber.putNext(Int(self?.controller?.interaction?.selectionState?.count() ?? 0))
            }, error: { _ in }, completed: { })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
    
    var caption: Signal<NSAttributedString?, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = self?.controller?.interaction?.editingState.forcedCaption().start(next: { caption in
                if let caption = caption as? NSAttributedString {
                    subscriber.putNext(caption)
                } else {
                    subscriber.putNext(nil)
                }
            }, error: { _ in }, completed: { })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
        
    public var loadingProgress: Signal<CGFloat?, NoError> {
        return .single(nil)
    }
    
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return .single(self.controller?.mainButtonState)
    }
    
    init(controller: MediaPickerScreen) {
        self.controller = controller
    }
    
    func setCaption(_ caption: NSAttributedString) {
        self.controller?.interaction?.editingState.setForcedCaption(caption, skipUpdate: true)
    }
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode) {
        self.controller?.interaction?.sendSelected(nil, mode == .silently, mode == .whenOnline ? scheduleWhenOnlineTimestamp : nil, true, {})
    }
    
    func schedule() {
        self.controller?.interaction?.schedule()
    }
    
    func mainButtonAction() {
        self.controller?.mainButtonPressed()
    }
}

private final class MediaPickerContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

public class MediaPickerGridSelectionGesture<T> : UIPanGestureRecognizer {
    public var itemAt: (CGPoint) -> (T, Bool)? = { _ in return nil }
    public var updateSelection: (T, Bool) -> Void = { _, _ in}
    public var updateIsScrollEnabled: (Bool) -> Void = { _ in}
    public var began: () -> Void = {}
    
    private var processing = false
    private var selecting = false
    
    private var initialLocation: CGPoint?
    
    public var sideInset: CGFloat = 0.0
    
    public init() {
        super.init(target: nil, action: nil)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, self.numberOfTouches == 1 else {
            return
        }
        
        let location = touch.location(in: self.view)
        if location.x > self.sideInset {
            self.initialLocation = location
        } else {
            self.state = .failed
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first, let initialLocation = self.initialLocation else {
            self.state = .failed
            return
        }
        
        let location = touch.location(in: self.view)
        let translation = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)
        
        var additionalLocation: CGPoint?
        if !self.processing {
            if abs(translation.y) > 5.0 {
                self.state = .failed
            } else if abs(translation.x) > 8.0 {
                self.processing = true
                self.updateIsScrollEnabled(false)
                self.began()
                
                if let (_, selected) = self.itemAt(location) {
                    self.selecting = !selected
                }
                
                additionalLocation = self.initialLocation
            }
        }
        
        if self.processing {
            if let additionalLocation = additionalLocation {
                if let (item, selected) = self.itemAt(additionalLocation), selected != self.selecting {
                    self.updateSelection(item, self.selecting)
                }
            }
            
            if let (item, selected) = self.itemAt(location), selected != self.selecting {
                self.updateSelection(item, self.selecting)
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .failed
        self.reset()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .failed
        self.reset()
    }
    
    public override func reset() {
        super.reset()
        
        self.processing = false
        self.initialLocation = nil
        self.updateIsScrollEnabled(true)
    }
}

public func wallpaperMediaPickerController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    animateAppearance: Bool,
    completion: @escaping (PHAsset) -> Void = { _ in },
    openColors: @escaping () -> Void
) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.animateAppearance = animateAppearance
    controller.requestController = { [weak controller] _, present in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let mediaPickerController = MediaPickerScreen(context: context, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .wallpaper), mainButtonState: AttachmentMainButtonState(text: presentationData.strings.Conversation_Theme_SetColorWallpaper, font: .regular, background: .color(.clear), textColor: presentationData.theme.actionSheet.controlAccentColor, isVisible: true, progress: .none, isEnabled: true), mainButtonAction: {
            controller?.dismiss(animated: true)
            openColors()
        })
        mediaPickerController.customSelection = completion
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}
