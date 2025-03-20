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
import Camera
import CameraScreen
import MediaEditor
import ImageObjectSeparation
import ChatSendMessageActionUI
import AnimatedCountLabelNode
import MediaAssetsContext

final class MediaPickerInteraction {
    let downloadManager: AssetDownloadManager
    let openMedia: (PHFetchResult<PHAsset>, Int, UIImage?) -> Void
    let openSelectedMedia: (TGMediaSelectableItem, UIImage?) -> Void
    let openDraft: (MediaEditorDraft, UIImage?) -> Void
    let toggleSelection: (TGMediaSelectableItem, Bool, Bool) -> Bool
    let sendSelected: (TGMediaSelectableItem?, Bool, Int32?, Bool, ChatSendMessageActionSheetController.SendParameters?, @escaping () -> Void) -> Void
    let schedule: (ChatSendMessageActionSheetController.SendParameters?) -> Void
    let dismissInput: () -> Void
    let selectionState: TGMediaSelectionContext?
    let editingState: TGMediaEditingContext
    var hiddenMediaId: String?
        
    init(downloadManager: AssetDownloadManager, openMedia: @escaping (PHFetchResult<PHAsset>, Int, UIImage?) -> Void, openSelectedMedia: @escaping (TGMediaSelectableItem, UIImage?) -> Void, openDraft: @escaping (MediaEditorDraft, UIImage?) -> Void, toggleSelection: @escaping (TGMediaSelectableItem, Bool, Bool) -> Bool, sendSelected: @escaping (TGMediaSelectableItem?, Bool, Int32?, Bool, ChatSendMessageActionSheetController.SendParameters?, @escaping () -> Void) -> Void, schedule: @escaping  (ChatSendMessageActionSheetController.SendParameters?) -> Void, dismissInput: @escaping () -> Void, selectionState: TGMediaSelectionContext?, editingState: TGMediaEditingContext) {
        self.downloadManager = downloadManager
        self.openMedia = openMedia
        self.openSelectedMedia = openSelectedMedia
        self.openDraft = openDraft
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
    let stories: Bool
    
    static func <(lhs: MediaPickerGridEntry, rhs: MediaPickerGridEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(context: AccountContext, interaction: MediaPickerInteraction, theme: PresentationTheme, strings: PresentationStrings) -> MediaPickerGridItem {
        return MediaPickerGridItem(content: self.content, interaction: interaction, theme: theme, strings: strings, selectable: self.selectable, enableAnimations: context.sharedContext.energyUsageSettings.fullTranslucency, stories: self.stories)
    }
}

private struct MediaPickerGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    
    init(previousList: [MediaPickerGridEntry], list: [MediaPickerGridEntry], context: AccountContext, interaction: MediaPickerInteraction, theme: PresentationTheme, strings: PresentationStrings, scrollToItem: GridNodeScrollToItem?) {
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings)) }
        
        self.scrollToItem = scrollToItem
    }
    
    init(clearList: [MediaPickerGridEntry]) {
        var deletions: [Int] = []
        var i = 0
        for _ in clearList {
            deletions.append(i)
            i += 1
        }
        self.deletions = deletions
        self.insertions = []
        self.updates = []
        self.scrollToItem = nil
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

private var savedStoriesContentOffset: CGFloat?

public final class MediaPickerScreenImpl: ViewController, MediaPickerScreen, AttachmentContainable {
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
            case story
            case addImage
            case cover
            case createSticker
            case createAvatar
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
    private let isScheduledMessages: Bool
    private let threadTitle: String?
    private let chatLocation: ChatLocation?
    private let bannedSendPhotos: (Int32, Bool)?
    private let bannedSendVideos: (Int32, Bool)?
    private let canBoostToUnrestrict: Bool
    fileprivate let paidMediaAllowed: Bool
    private let subject: Subject
    fileprivate let forCollage: Bool
    private let saveEditedPhotos: Bool
    
    private var explicitMultipleSelection = false
    
    private let titleView: MediaPickerTitleView
    private let cancelButtonNode: WebAppCancelButtonNode
    private let moreButtonNode: MoreButtonNode
    private let selectedButtonNode: SelectedButtonNode
    
    public weak var webSearchController: WebSearchController?
    
    public var openCamera: ((Any?) -> Void)?
    public var presentSchedulePicker: (Bool, @escaping (Int32) -> Void) -> Void = { _, _ in }
    public var presentTimerPicker: (@escaping (Int32) -> Void) -> Void = { _ in }
    public var presentWebSearch: (MediaGroupsScreen, Bool) -> Void = { _, _ in }
    public var getCaptionPanelView: () -> TGCaptionPanelView? = { return nil }
    public var openBoost: () -> Void = { }
    
    public var customSelection: ((MediaPickerScreenImpl, Any) -> Void)? = nil
    
    public var createFromScratch: () -> Void = {}
    public var presentFilePicker: () -> Void = {}
    public var openAvatarEditor: () -> Void = {}
    
    private var completed = false
    public var legacyCompletion: (_ fromGallery: Bool, _ signals: [Any], _ silently: Bool, _ scheduleTime: Int32?, ChatSendMessageActionSheetController.SendParameters?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void = { _, _, _, _, _, _, _ in }
    
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false
    
    public var getCurrentSendMessageContextMediaPreview: (() -> ChatSendMessageContextScreenMediaPreview?)? = nil
    
    private let selectedCollection = Promise<PHAssetCollection?>(nil)
    private var selectedCollectionValue: PHAssetCollection? {
        didSet {
            self.selectedCollection.set(.single(self.selectedCollectionValue))
        }
    }
    
    var dismissAll: () -> Void = { }
    public var editCover: (CGSize, @escaping (UIImage) -> Void) -> Void = { _, _ in }
    
    private class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate {
        enum DisplayMode {
            case all
            case selected
        }
        
        enum State {
            case noAccess(cameraAccess: AVAuthorizationStatus?)
            case assets(fetchResult: PHFetchResult<PHAsset>?, preload: Bool, drafts: [MediaEditorDraft], mediaAccess: PHAuthorizationStatus, cameraAccess: AVAuthorizationStatus?)
            case media([Subject.Media])
        }
        
        private weak var controller: MediaPickerScreenImpl?
        private var presentationData: PresentationData
        fileprivate let mediaAssetsContext: MediaAssetsContext
        
        private var requestedMediaAccess = false
        private var requestedCameraAccess = false
        
        private let containerNode: ASDisplayNode
        private let backgroundNode: NavigationBackgroundNode
        fileprivate let gridNode: GridNode
        
        fileprivate let cameraWrapperView: UIView
        fileprivate var cameraView: TGAttachmentCameraView?
        
        fileprivate var modernCamera: Camera?
        fileprivate var modernCameraView: CameraSimplePreviewView?
        fileprivate var modernCameraTapGestureRecognizer: UITapGestureRecognizer?
        
        fileprivate var avatarEditorPreviewView: AvatarEditorPreviewView?
        
        private var cameraActivateAreaNode: AccessibilityAreaNode
        private var placeholderNode: MediaPickerPlaceholderNode?
        private var manageNode: MediaPickerManageNode?
        private var scrollingArea: SparseItemGridScrollingArea
        private var isFastScrolling = false
        
        private var selectionNode: MediaPickerSelectedListNode?
        
        private var nextStableId: Int = 1
        private var currentEntries: [MediaPickerGridEntry] = []
        private var enqueuedTransactions: [MediaPickerGridTransaction] = []
        fileprivate var state: State?
        
        private var preloadPromise = ValuePromise<Bool>(true)
        
        private var itemsDisposable: Disposable?
        private var selectionChangedDisposable: Disposable?
        private var itemsDimensionsUpdatedDisposable: Disposable?
        private var hiddenMediaDisposable: Disposable?
        
        fileprivate let hiddenMediaId = Promise<String?>(nil)
        
        private var selectionGesture: MediaPickerGridSelectionGesture<TGMediaSelectableItem>?
        
        private var fastScrollContentOffset = ValuePromise<CGPoint>(ignoreRepeated: true)
        private var fastScrollDisposable: Disposable?
                
        private var didSetReady = false
        private let _ready = Promise<Bool>()
        var ready: Promise<Bool> {
            return self._ready
        }
        
        fileprivate var isSuspended = false
        fileprivate var hasGallery = false
        private var isCameraPreviewVisible = true
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: MediaPickerScreenImpl) {
            self.controller = controller
            self.presentationData = controller.presentationData
            
            var assetType: PHAssetMediaType?
            if case let .assets(_, mode) = controller.subject, [.wallpaper, .addImage, .cover, .createSticker].contains(mode) {
                assetType = .image
            }
            let mediaAssetsContext = MediaAssetsContext(assetType: assetType)
            self.mediaAssetsContext = mediaAssetsContext
            
            self.containerNode = ASDisplayNode()
            self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
            self.backgroundNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            self.gridNode = GridNode()
            self.scrollingArea = SparseItemGridScrollingArea()
            
            self.cameraWrapperView = UIView()
            self.cameraWrapperView.clipsToBounds = true
            
            self.cameraActivateAreaNode = AccessibilityAreaNode()
            self.cameraActivateAreaNode.accessibilityLabel = "Camera"
            self.cameraActivateAreaNode.accessibilityTraits = [.button]
            
            super.init()
            
            if case .assets(nil, .default) = controller.subject {
            } else if case .assets(nil, .story) = controller.subject, (savedStoriesContentOffset ?? 0.0).isZero {
            } else {
                self.preloadPromise.set(false)
            }
            
            self.addSubnode(self.containerNode)
            self.containerNode.addSubnode(self.backgroundNode)
            self.containerNode.addSubnode(self.gridNode)
            self.containerNode.addSubnode(self.scrollingArea)
            
            self.gridNode.scrollView.addSubview(self.cameraWrapperView)
            
            let selectedCollection = controller.selectedCollection.get()
            let preloadPromise = self.preloadPromise
            let updatedState: Signal<State, NoError>
            switch controller.subject {
            case let .assets(collection, mode):
                let drafts: Signal<[MediaEditorDraft], NoError>
                if mode == .story {
                    drafts = storyDrafts(engine: controller.context.engine)
                } else {
                    drafts = .single([])
                }
                updatedState = combineLatest(mediaAssetsContext.mediaAccess(), mediaAssetsContext.cameraAccess())
                |> mapToSignal { mediaAccess, cameraAccess -> Signal<State, NoError> in
                    if case .notDetermined = mediaAccess {
                        return .single(.assets(fetchResult: nil, preload: false, drafts: [], mediaAccess: mediaAccess, cameraAccess: cameraAccess))
                    } else if [.restricted, .denied].contains(mediaAccess) {
                        return .single(.noAccess(cameraAccess: cameraAccess))
                    } else {
                        return selectedCollection
                        |> mapToSignal { selectedCollection in
                            let collection = selectedCollection ?? collection
                            if let collection {
                                return combineLatest(mediaAssetsContext.fetchAssets(collection), preloadPromise.get())
                                |> map { fetchResult, preload in
                                    return .assets(fetchResult: fetchResult, preload: preload, drafts: [], mediaAccess: mediaAccess, cameraAccess: selectedCollection != nil ? nil : cameraAccess)
                                }
                            } else {
                                return combineLatest(mediaAssetsContext.recentAssets(), preloadPromise.get(), drafts)
                                |> map { fetchResult, preload, drafts in
                                    return .assets(fetchResult: fetchResult, preload: preload, drafts: drafts, mediaAccess: mediaAccess, cameraAccess: cameraAccess)
                                }
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
            
            controller.getCurrentSendMessageContextMediaPreview = { [weak self] () -> ChatSendMessageContextScreenMediaPreview? in
                guard let self else {
                    return nil
                }
                guard let controller = self.controller else {
                    return nil
                }
                guard let (layout, navigationHeight) = self.validLayout else {
                    return nil
                }
                
                var persistentItems = false
                if case .media = controller.subject {
                    persistentItems = true
                }
                var isObscuredExternalPreview = false
                if case .selected = self.currentDisplayMode {
                    isObscuredExternalPreview = true
                }
                let previewNode = MediaPickerSelectedListNode(context: controller.context, persistentItems: persistentItems, isExternalPreview: true, isObscuredExternalPreview: isObscuredExternalPreview)
                let clippingRect = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - navigationHeight - layout.intrinsicInsets.bottom - layout.additionalInsets.bottom - 1.0)))
                previewNode.globalClippingRect = self.view.convert(clippingRect, to: nil)
                previewNode.interaction = self.controller?.interaction
                previewNode.getTransitionView = { [weak self] identifier in
                    guard let self else {
                        return nil
                    }
                    var node: MediaPickerGridItemNode?
                    self.gridNode.forEachItemNode { itemNode in
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
                }
                let selectedItems = controller.interaction?.selectionState?.selectedItems() as? [TGMediaSelectableItem] ?? []
                previewNode.updateLayout(size: layout.size, insets: UIEdgeInsets(), items: selectedItems, grouped: self.controller?.groupedValue ?? true, theme: self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper, bubbleCorners: self.presentationData.chatBubbleCorners, transition: .immediate)
                
                return previewNode
            }
        }
        
        deinit {
            self.itemsDisposable?.dispose()
            self.hiddenMediaDisposable?.dispose()
            self.selectionChangedDisposable?.dispose()
            self.itemsDimensionsUpdatedDisposable?.dispose()
            self.fastScrollDisposable?.dispose()
            self.currentAssetDownloadDisposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            guard let controller = self.controller else {
                return
            }
            
            self.gridNode.scrollView.alwaysBounceVertical = true
            self.gridNode.scrollView.showsVerticalScrollIndicator = false
            
            if case let .assets(_, mode) = controller.subject, [.wallpaper, .story, .addImage, .cover, .createSticker, .createAvatar].contains(mode) {
                
            } else {
                let selectionGesture = MediaPickerGridSelectionGesture<TGMediaSelectableItem>()
                selectionGesture.delegate = self.wrappedGestureRecognizerDelegate
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
                
                if let self {
                    var cameraView: UIView?
                    if let view = self.cameraView {
                        cameraView = view
                    } else if let _ = self.modernCameraView {
                        cameraView = self.cameraWrapperView
                    }
                    if let cameraView {
                        self.isCameraPreviewVisible = self.gridNode.scrollView.bounds.intersects(cameraView.frame)
                        self.updateIsCameraActive()
                    }
                }
            }
            self.updateScrollingArea()
            
            let throttledContentOffsetSignal = self.fastScrollContentOffset.get()
            |> mapToThrottled { next -> Signal<CGPoint, NoError> in
                return .single(next) |> then(.complete() |> delay(0.05, queue: Queue.concurrentDefaultQueue()))
            }
            self.fastScrollDisposable = (throttledContentOffsetSignal
            |> deliverOnMainQueue).start(next: { [weak self] contentOffset in
                if let self {
                    self.gridNode.scrollView.setContentOffset(contentOffset, animated: false)
                }
            })
            
            if case .assets(nil, .createAvatar) = controller.subject {
                let avatarEditorPreviewView = AvatarEditorPreviewView(context: controller.context)
                avatarEditorPreviewView.tapped = { [weak self] in
                    self?.controller?.openAvatarEditor()
                }
                self.gridNode.view.addSubview(avatarEditorPreviewView)
                self.avatarEditorPreviewView = avatarEditorPreviewView
            }
            
            var useLegacyCamera = false
            var useModernCamera = false
            if case .assets(nil, .default) = controller.subject {
                useLegacyCamera = true
            } else if case .assets(nil, let mode) = controller.subject, [.createSticker, .createAvatar].contains(mode) {
                useModernCamera = true
            }
            
            if useLegacyCamera {
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
            } else if useModernCamera, !Camera.isIpad {
                #if !targetEnvironment(simulator)
                var cameraPosition: Camera.Position = .back
                if case .assets(nil, .createAvatar) = controller.subject {
                    cameraPosition = .front
                }
                
                let cameraPreviewView = CameraSimplePreviewView(frame: .zero, main: true)
                cameraPreviewView.resetPlaceholder(front: cameraPosition == .front)
                self.modernCameraView = cameraPreviewView
                
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.cameraTapped))
                cameraPreviewView.addGestureRecognizer(tapGestureRecognizer)
                self.modernCameraTapGestureRecognizer = tapGestureRecognizer
                
                if #available(iOS 13.0, *) {
                    let _ = (cameraPreviewView.isPreviewing
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                        self?.modernCameraView?.removePlaceholder(delay: 0.35)
                    })
                } else {
                    Queue.mainQueue().after(0.35) {
                        cameraPreviewView.removePlaceholder(delay: 0.15)
                    }
                }
                
                self.cameraWrapperView.addSubview(cameraPreviewView)
                
                let setupCamera = {
                    let camera = Camera(
                        configuration: Camera.Configuration(
                            preset: .hd1920x1080,
                            position: cameraPosition,
                            isDualEnabled: false,
                            audio: false,
                            photo: true,
                            metadata: false
                        ),
                        previewView: cameraPreviewView,
                        secondaryPreviewView: nil
                    )
                    self.modernCamera = camera
                    camera.startCapture()
                }
                
                if case .assets(nil, .createAvatar) = controller.subject {
                    Queue.mainQueue().after(0.4, {
                        setupCamera()
                    })
                } else {
                    setupCamera()
                }
                #endif
            } else {
                self.containerNode.clipsToBounds = true
            }
        }
        
        @objc private func cameraTapped() {
            guard let camera = self.modernCamera, let previewView = self.modernCameraView else {
                return
            }
            self.modernCameraTapGestureRecognizer?.isEnabled = false
            self.controller?.openCamera?(
                CameraHolder(
                    camera: camera,
                    previewView: previewView,
                    parentView: self.cameraWrapperView,
                    restore: { [weak self, weak previewView] in
                        guard let self else {
                            return
                        }
                        self.modernCameraTapGestureRecognizer?.isEnabled = true
                        if let previewView {
                            self.cameraWrapperView.addSubview(previewView)
                            if let (layout, navigationBarHeight) = self.validLayout {
                                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                previewView.layer.removeAllAnimations()
                            }
                        }
                    }
                )
            )
        }
        
        func updateIsCameraActive() {
            let isCameraActive = !self.isSuspended && !self.hasGallery && self.isCameraPreviewVisible
            if let cameraView = self.cameraView {
                if isCameraActive {
                    cameraView.resumePreview()
                } else {
                    cameraView.pausePreview()
                }
            } else if let camera = self.modernCamera, let cameraView = self.modernCameraView {
                if isCameraActive {
                    cameraView.isEnabled = true
                    camera.startCapture()
                } else {
                    cameraView.isEnabled = false
                    camera.stopCapture()
                }
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
        
        fileprivate var resetOnUpdate = false
        fileprivate func updateState(_ state: State) {
            guard let controller = self.controller, let interaction = controller.interaction else {
                return
            }
            
            let previousState = self.state
            self.state = state
            
            var stableId: Int = 0
            var entries: [MediaPickerGridEntry] = []
            
            var updateLayout = false
            
            var stories = false
            var selectable = true
            if case let .assets(_, mode) = controller.subject, mode != .default {
                selectable = controller.explicitMultipleSelection
                if mode == .story {
                    stories = true
                }
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
            case let .assets(fetchResult, preload, drafts, mediaAccess, cameraAccess):
                if let fetchResult = fetchResult {
                    let totalCount = fetchResult.count
                    let count = preload ? min(13, totalCount) : totalCount
                    
                    var draftIndex = 0
                    for draft in drafts {
                        entries.append(MediaPickerGridEntry(stableId: stableId, content: .draft(draft, draftIndex), selectable: selectable, stories: stories))
                        stableId += 1
                        draftIndex += 1
                    }
                    
                    for i in 0 ..< count {
                        let index: Int
                        if case let .assets(collection, _) = controller.subject, let _ = collection {
                            index = i
                        } else {
                            index = totalCount - i - 1
                        }
                        entries.append(MediaPickerGridEntry(stableId: stableId, content: .asset(fetchResult, index), selectable: selectable, stories: stories))
                        stableId += 1
                    }
                    
                    if case let .assets(previousFetchResult, _, _, _, previousCameraAccess) = previousState, previousFetchResult == nil || previousCameraAccess != cameraAccess {
                        updateLayout = true
                    }
                    
                    #if DEBUG
                    if case let .assets(collection, _) = controller.subject, collection?.localizedTitle == "BulkTest" {
                        for i in 0 ..< totalCount {
                            let backingAsset = fetchResult.object(at: i)
                            let asset = TGMediaAsset(phAsset: backingAsset)
                            controller.interaction?.selectionState?.setItem(asset, selected: true)
                        }
                    }
                    #endif
                    
                    if !stories, case .notDetermined = cameraAccess, !self.requestedCameraAccess {
                        self.requestedCameraAccess = true
                        self.mediaAssetsContext.requestCameraAccess()
                    }
                    
                    if !controller.didSetupGroups {
                        controller.didSetupGroups = true
                        Queue.concurrentDefaultQueue().after(0.4) {
                            var isCreateSticker = false
                            if case .assets(_, .createSticker) = controller.subject {
                                isCreateSticker = true
                            }
                            controller.groupsPromise.set(
                                combineLatest(
                                    self.mediaAssetsContext.fetchAssetsCollections(.album),
                                    self.mediaAssetsContext.fetchAssetsCollections(.smartAlbum)
                                )
                                |> map { albums, smartAlbums -> [MediaGroupItem] in
                                    var collections: [PHAssetCollection] = []
                                    smartAlbums.enumerateObjects { collection, _, _ in
                                        if [.smartAlbumUserLibrary, .smartAlbumFavorites].contains(collection.assetCollectionSubtype) {
                                            collections.append(collection)
                                        }
                                    }
                                    smartAlbums.enumerateObjects { collection, index, _ in
                                        var supportedAlbums: [PHAssetCollectionSubtype] = [
                                            .smartAlbumBursts,
                                            .smartAlbumPanoramas,
                                            .smartAlbumScreenshots,
                                            .smartAlbumSelfPortraits,
                                            .smartAlbumSlomoVideos,
                                            .smartAlbumTimelapses,
                                            .smartAlbumVideos,
                                            .smartAlbumAllHidden
                                        ]
                                        if #available(iOS 11, *) {
                                            supportedAlbums.append(.smartAlbumAnimated)
                                            supportedAlbums.append(.smartAlbumDepthEffect)
                                            supportedAlbums.append(.smartAlbumLivePhotos)
                                        }
                                        
                                        if isCreateSticker {
                                            supportedAlbums = supportedAlbums.filter { type in
                                                if type == .smartAlbumSlomoVideos || type == .smartAlbumTimelapses || type == .smartAlbumVideos {
                                                    return false
                                                }
                                                return true
                                            }
                                        }
                                        
                                        if supportedAlbums.contains(collection.assetCollectionSubtype) {
                                            let result = PHAsset.fetchAssets(in: collection, options: nil)
                                            if result.count > 0 {
                                                collections.append(collection)
                                            }
                                        }
                                    }
                                    albums.enumerateObjects(options: [.reverse]) { collection, _, _ in
                                        let result = PHAsset.fetchAssets(in: collection, options: nil)
                                        if result.count > 0 {
                                            collections.append(collection)
                                        }
                                    }
                                    
                                    var items: [MediaGroupItem] = []
                                    for collection in collections {
                                        let result = PHAsset.fetchAssets(in: collection, options: nil)
                                        let firstItem: PHAsset?
                                        if [.smartAlbumUserLibrary, .smartAlbumFavorites].contains(collection.assetCollectionSubtype) {
                                            firstItem = result.lastObject
                                        } else {
                                            firstItem = result.firstObject
                                        }
                                        items.append(
                                            MediaGroupItem(
                                                collection: collection,
                                                firstItem: firstItem,
                                                count: result.count
                                            )
                                        )
                                    }
                                    return items
                                }
                            )
                        }
                    }
                } else if case .notDetermined = mediaAccess, !self.requestedMediaAccess {
                    self.requestedMediaAccess = true
                    self.mediaAssetsContext.requestMediaAccess()
                }
            case let .media(media):
                let count = media.count
                for i in 0 ..< count {
                    entries.append(MediaPickerGridEntry(stableId: stableId, content: .media(media[i], i), selectable: true, stories: stories))
                    stableId += 1
                }
            }
        
            var previousEntries = self.currentEntries
            
            if self.resetOnUpdate {
                self.enqueueTransaction(MediaPickerGridTransaction(clearList: previousEntries))
                self.resetOnUpdate = false
                previousEntries = []
            }
            
            self.currentEntries = entries
            
            var scrollToItem: GridNodeScrollToItem?
            if case let .assets(collection, _) = controller.subject, let _ = collection, previousEntries.isEmpty && !entries.isEmpty {
                scrollToItem = GridNodeScrollToItem(index: entries.count - 1, position: .bottom(0.0), transition: .immediate, directionHint: .down, adjustForSection: false)
            }
            
            let transaction = MediaPickerGridTransaction(previousList: previousEntries, list: entries, context: controller.context, interaction: interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, scrollToItem: scrollToItem)
            self.enqueueTransaction(transaction)
            
            if !self.didSetReady {
                updateLayout = true
            }
            
            if updateLayout, let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: previousState == nil ? .immediate : .animated(duration: 0.2, curve: .easeInOut))
            }
            self.updateNavigation(transition: .immediate)
        }
        
        private func resetItems() {
            
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
        
        private(set) var currentDisplayMode: DisplayMode = .all {
            didSet {
                self.displayModeUpdated(self.currentDisplayMode)
            }
        }
        var displayModeUpdated: (DisplayMode) -> Void = { _ in }
        
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
                
                let selectionNode = MediaPickerSelectedListNode(context: controller.context, persistentItems: persistentItems, isExternalPreview: false, isObscuredExternalPreview: false)
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
                        self.selectionNode?.animateIn(transition: .animated(duration: 0.25, curve: .easeInOut), initiated: { [weak self] in
                            self?.updateNavigation(transition: .immediate)
                        }, completion: completion)
                    case .all:
                        self.selectionNode?.animateOut(transition: .animated(duration: 0.25, curve: .easeInOut), completion: completion)
                    }
                } else {
                    self.updateNavigation(transition: .immediate)
                }
            }
        }
        
        private weak var currentGalleryController: TGModernGalleryController?
        private weak var currentGalleryParentController: ViewController?
        
        fileprivate var currentAssetDownloadDisposable = MetaDisposable()
        
        fileprivate func closeGalleryController() {
            if let _ = self.currentGalleryController, let currentGalleryParentController = self.currentGalleryParentController {
                self.currentGalleryController = nil
                self.currentGalleryParentController = nil
                
                currentGalleryParentController.dismiss(completion: nil)
            }
        }
        
        fileprivate func cancelAssetDownloads() {
            guard let downloadManager = self.controller?.downloadManager else {
                return
            }
            self.currentAssetDownloadDisposable.set(nil)
            downloadManager.cancelAllDownloads()
        }
        
        fileprivate func requestAssetDownload(asset: PHAsset) {
            guard let downloadManager = self.controller?.downloadManager else {
                return
            }
            downloadManager.download(asset: asset)
            self.currentAssetDownloadDisposable.set(
                (downloadManager.downloadProgress(identifier: asset.localIdentifier)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let self, case .completed = status, let controller = self.controller, let customSelection = self.controller?.customSelection {
                        customSelection(controller, asset)
                    }
                })
            )
        }
        
        private var openingMedia = false
        fileprivate func openMedia(fetchResult: PHFetchResult<PHAsset>, index: Int, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, let interaction = controller.interaction, let (layout, _) = self.validLayout, !self.openingMedia else {
                return
            }
            Queue.mainQueue().justDispatch {
                self.dismissInput()
            }
            
            if controller.explicitMultipleSelection {
                let asset = fetchResult[index]
                if let selectableItem = TGMediaAsset(phAsset: asset), let selectionContext = interaction.selectionState {
                    let value = !selectionContext.isIdentifierSelected(selectableItem.uniqueIdentifier)
                    let _ = interaction.toggleSelection(selectableItem, value, false)
                }
                return
            }
    
            if let customSelection = controller.customSelection {
                self.openingMedia = true
                
                let asset = fetchResult[index]
                
                let _ = (checkIfAssetIsLocal(asset)
                |> deliverOnMainQueue).start(next: { [weak self] isLocallyAvailable in
                    guard let self else {
                        return
                    }
                    if isLocallyAvailable {
                        self.cancelAssetDownloads()
                        customSelection(controller, asset)
                    } else {
                        self.requestAssetDownload(asset: asset)
                    }
                })
                
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
            
            self.currentGalleryController = presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, threadTitle: controller.threadTitle, chatLocation: controller.chatLocation, isScheduledMessages: controller.isScheduledMessages, presentationData: self.presentationData, source: .fetchResult(fetchResult: fetchResult, index: index, reversed: reversed), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: hasSchedule, hasTimer: hasTimer, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.gridNode.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime, completion in
                if let strongSelf = self {
                    strongSelf.controller?.interaction?.sendSelected(result, silently, scheduleTime, false, nil, completion)
                }
            }, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.currentGalleryParentController = c
                c.navigationPresentation = .flatModal
                self?.controller?.parentController()?.push(c)
                //self?.controller?.present(c, in: .window(.root), with: a)
            }, finishedTransitionIn: { [weak self] in
                self?.openingMedia = false
                self?.hasGallery = true
                self?.updateIsCameraActive()
            }, willTransitionOut: { [weak self] in
                self?.hasGallery = false
                self?.updateIsCameraActive()
            }, dismissAll: { [weak self] in
                self?.controller?.dismissAll()
            }, editCover: { [weak self] dimensions, completion in
                self?.controller?.editCover(dimensions, completion)
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
            self.currentGalleryController = presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, threadTitle: controller.threadTitle, chatLocation: controller.chatLocation, isScheduledMessages: controller.isScheduledMessages, presentationData: self.presentationData, source: .selection(item: item), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: true, hasTimer: hasTimer, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.selectionNode?.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime, completion in
                if let strongSelf = self {
                    strongSelf.controller?.interaction?.sendSelected(result, silently, scheduleTime, false, nil, completion)
                }
            }, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.currentGalleryParentController = c
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
            }, editCover: { _, _ in
                
            })
        }
        
        fileprivate func openDraft(draft: MediaEditorDraft, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, !self.openingMedia else {
                return
            }
            Queue.mainQueue().justDispatch {
                self.dismissInput()
            }
            
            if let customSelection = controller.customSelection {
                self.openingMedia = true
                customSelection(controller, draft)
                Queue.mainQueue().after(0.3) {
                    self.openingMedia = false
                }
            }
        }
        
        fileprivate func send(fromGallery: Bool = false, asFile: Bool = false, silently: Bool, scheduleTime: Int32?, animated: Bool, parameters: ChatSendMessageActionSheetController.SendParameters?, completion: @escaping () -> Void) {
            guard let controller = self.controller, !controller.completed else {
                return
            }
            controller.dismissAllTooltips()
            
            var parameters = parameters
            if parameters == nil {
                var textIsAboveMedia = false
                if let interaction = controller.interaction {
                    textIsAboveMedia = interaction.editingState.isCaptionAbove()
                }
                parameters = ChatSendMessageActionSheetController.SendParameters(
                    effect: nil,
                    textIsAboveMedia: textIsAboveMedia
                )
            }
            
            var hasHeic = false
            let allItems = controller.interaction?.selectionState?.selectedItems() ?? []
            for item in allItems {
                if item is TGCameraCapturedVideo {
                } else if let asset = item as? TGMediaAsset, asset.uniformTypeIdentifier.contains("heic") {
                    hasHeic = true
                    break
                }
            }
            
            let proceed: (Bool) -> Void = { [weak self] convertToJpeg in
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
                controller.legacyCompletion(fromGallery, signals, silently, scheduleTime, parameters, { [weak self] identifier in
                    return !asFile ? self?.getItemSnapshot(identifier) : nil
                }, { [weak self] in
                    completion()
                    self?.controller?.dismiss(animated: animated)
                })
                
                Queue.mainQueue().after(1.5) {
                    controller.isDismissing = false
                    controller.completed = false
                }
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
        
        fileprivate func defaultTransitionView() -> UIView? {
            var transitionNode: MediaPickerGridItemNode?
            if let itemNode = self.gridNode.itemNodeAtPoint(.zero) {
                if let itemNode = itemNode as? MediaPickerGridItemNode {
                    transitionNode = itemNode
                }
            }
            let transitionView = transitionNode?.transitionView(snapshot: false)
            return transitionView
        }
        
        fileprivate func transitionView(for identifier: String, snapshot: Bool = true, hideSource: Bool = false) -> UIView? {
            if let selectionNode = self.selectionNode, selectionNode.alpha > 0.0 {
                return selectionNode.transitionView(for: identifier, hideSource: hideSource)
            } else {
                var transitionNode: MediaPickerGridItemNode?
                self.gridNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                        transitionNode = itemNode
                    }
                }
                let transitionView = transitionNode?.transitionView(snapshot: snapshot)
                if hideSource {
                    transitionNode?.isHidden = true
                }
                return transitionView
            }
        }
        
        fileprivate func transitionImage(for identifier: String) -> UIImage? {
            var transitionNode: MediaPickerGridItemNode?
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                    transitionNode = itemNode
                }
            }
            return transitionNode?.transitionImage()
        }
        
        private func enqueueTransaction(_ transaction: MediaPickerGridTransaction) {
            self.enqueuedTransactions.append(transaction)
            
            if let _ = self.validLayout {
                self.dequeueTransaction()
            }
        }
        
        private var didRestoreContentOffset = false
        private func dequeueTransaction() {
            if self.enqueuedTransactions.isEmpty {
                return
            }
            let transaction = self.enqueuedTransactions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transaction.deletions, insertItems: transaction.insertions, updateItems: transaction.updates, scrollToItem: transaction.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
            
            if let subject = self.controller?.subject, case .assets(_, .story) = subject, let contentOffset = savedStoriesContentOffset, !self.didRestoreContentOffset {
                if contentOffset > 64.0 {
                    self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
                    self.controller?.requestAttachmentMenuExpansion()
                }
                self.didRestoreContentOffset = true
            }
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
            guard let controller = self.controller else {
                return
            }
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
            
            var cutoutRects: [CGRect] = []
            var cameraRect: CGRect? = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: 0.0), size: CGSize(width: itemWidth, height: itemWidth * 2.0 + 1.0))
            if self.cameraView == nil && self.modernCameraView == nil {
                cameraRect = nil
            }
                        
            var manageHeight: CGFloat = 0.0
            if case let .assets(_, _, _, mediaAccess, cameraAccess) = self.state {
                if cameraAccess == nil {
                    cameraRect = nil
                }
                
                var bannedSendMedia: (Int32, Bool)?
                if let bannedSendPhotos = controller.bannedSendPhotos, let bannedSendVideos = controller.bannedSendVideos {
                    bannedSendMedia = (max(bannedSendPhotos.0, bannedSendVideos.0), bannedSendPhotos.1 || bannedSendVideos.1)
                }
                
                if let (untilDate, personal) = bannedSendMedia {
                    self.gridNode.isHidden = true
                    self.controller?.titleView.isEnabled = false
                    
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
                        placeholderNode = MediaPickerPlaceholderNode(content: .bannedSendMedia(text: banDescription, canBoost: controller.canBoostToUnrestrict))
                        placeholderNode.boostPressed = { [weak controller] in
                            controller?.openBoost()
                        }
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
            
            if let cameraRect {
                cutoutRects.append(cameraRect)
            }
            if let _ = self.avatarEditorPreviewView {
                cutoutRects.append(CGRect(x: cameraRect != nil ? cameraRect!.maxX + itemSpacing : layout.safeInsets.left, y: 0.0, width: itemWidth, height: itemWidth))
            }
            
            var itemHeight = itemWidth
            if case let .assets(_, mode) = controller.subject, case .story = mode {
                itemHeight = floor(itemWidth * 1.227)
            }
            let preloadSize: CGFloat = itemHeight// * 3.0
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: bounds.size, insets: gridInsets, scrollIndicatorInsets: nil, preloadSize: preloadSize, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemHeight), fillWidth: true, lineSpacing: itemSpacing, itemSpacing: itemSpacing), cutouts: cutoutRects), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { [weak self] _ in
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
                Queue.mainQueue().after(0.01) {
                    strongSelf.cameraWrapperView.superview?.addSubview(strongSelf.cameraWrapperView)
                }
            })
            
            if let avatarEditorPreviewView = self.avatarEditorPreviewView {
                avatarEditorPreviewView.frame = CGRect(origin: CGPoint(x: cameraRect != nil ? cameraRect!.maxX + itemSpacing : layout.safeInsets.left, y: 0.0), size: CGSize(width: itemWidth, height: itemWidth))
                avatarEditorPreviewView.updateLayout(size: CGSize(width: itemWidth, height: itemWidth))
            }
            
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
            
            
            var cameraView: UIView?
            if let view = self.cameraView {
                cameraView = view
            } else if let view = self.modernCameraView {
                cameraView = view
            }
            
            if let cameraView {
                if let cameraRect = cameraRect {
                    if cameraView.superview == self.cameraWrapperView {
                        transition.updateFrame(view: self.cameraWrapperView, frame: cameraRect)
                        
                        let screenWidth = min(layout.deviceMetrics.screenSize.width, layout.deviceMetrics.screenSize.height)
                        let cameraFullSize = CGSize(width: screenWidth, height: floorToScreenPixels(layout.size.width * 1.77778))
                        let cameraScale = max(cameraRect.width / cameraFullSize.width, cameraRect.height / cameraFullSize.height)
                        
                        cameraView.bounds = CGRect(origin: .zero, size: cameraFullSize)
                        cameraView.center = CGPoint(x: cameraRect.size.width / 2.0, y: cameraRect.size.height / 2.0)
                        cameraView.transform = CGAffineTransform(scaleX: cameraScale, y: cameraScale)

                    } else if cameraView.superview == self.gridNode.scrollView {
                        transition.updateFrame(view: cameraView, frame: cameraRect)
                    }
                    self.cameraActivateAreaNode.frame = cameraRect
                    self.cameraWrapperView.isHidden = false
                    cameraView.isHidden = false
                } else {
                    self.cameraWrapperView.isHidden = true
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
                var hasCamera = cameraAccess == .authorized
                var story = false
                if let subject = self.controller?.subject {
                    if case .assets(_, .story) = subject {
                        hasCamera = false
                        story = true
                        self.controller?.navigationItem.rightBarButtonItem = nil
                    } else if case .assets(_, .createSticker) = subject {
                        hasCamera = false
                    } else if case .assets(_, .createAvatar) = subject {
                        hasCamera = false
                    }
                }
                
                var placeholderTransition = transition
                let placeholderNode: MediaPickerPlaceholderNode
                if let current = self.placeholderNode {
                    placeholderNode = current
                } else {
                    placeholderNode = MediaPickerPlaceholderNode(content: .intro(story: story))
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
                placeholderNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, hasCamera: hasCamera, transition: placeholderTransition)
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
    
    private let downloadManager = AssetDownloadManager()
    
    private var isDismissing = false
    
    fileprivate let mainButtonStatePromise = Promise<AttachmentMainButtonState?>(nil)

    private let mainButtonAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        peer: EnginePeer?,
        threadTitle: String?,
        chatLocation: ChatLocation?,
        isScheduledMessages: Bool = false,
        bannedSendPhotos: (Int32, Bool)? = nil,
        bannedSendVideos: (Int32, Bool)? = nil,
        canBoostToUnrestrict: Bool = false,
        paidMediaAllowed: Bool = false,
        subject: Subject,
        forCollage: Bool = false,
        sendPaidMessageStars: Int64? = nil,
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
        self.isScheduledMessages = isScheduledMessages
        self.bannedSendPhotos = bannedSendPhotos
        self.bannedSendVideos = bannedSendVideos
        self.canBoostToUnrestrict = canBoostToUnrestrict
        self.paidMediaAllowed = paidMediaAllowed
        self.subject = subject
        self.forCollage = forCollage
        self.saveEditedPhotos = saveEditedPhotos
        self.mainButtonStatePromise.set(.single(mainButtonState))
        self.mainButtonAction = mainButtonAction
        
        let selectionContext = selectionContext ?? TGMediaSelectionContext()
        
        self.titleView = MediaPickerTitleView(theme: self.presentationData.theme, segments: [self.presentationData.strings.Attachment_AllMedia, self.presentationData.strings.Attachment_SelectedMedia(1)], selectedIndex: 0)
        
        if case let .assets(collection, mode) = subject {
            if let collection = collection {
                self.titleView.title = collection.localizedTitle ?? presentationData.strings.Attachment_Gallery
            } else {
                switch mode {
                case .default:
                    self.titleView.title = presentationData.strings.MediaPicker_Recents
                    self.titleView.isEnabled = true
                case .createSticker:
                    self.titleView.title = presentationData.strings.MediaPicker_Recents
                    self.titleView.subtitle = presentationData.strings.MediaPicker_CreateSticker
                    self.titleView.isEnabled = true
                case .createAvatar:
                    self.titleView.title = presentationData.strings.MediaPicker_Recents
                    self.titleView.subtitle = presentationData.strings.MediaPicker_SetNewPhoto
                    self.titleView.isEnabled = true
                case .story:
                    self.titleView.title = presentationData.strings.MediaPicker_Recents
                    self.titleView.isEnabled = true
                case .wallpaper:
                    self.titleView.title = presentationData.strings.Conversation_Theme_ChooseWallpaperTitle
                case .addImage:
                    self.titleView.title = presentationData.strings.MediaPicker_AddImage
                case .cover:
                    self.titleView.title = presentationData.strings.MediaPicker_ChooseCover
                }
            }
        } else {
            self.titleView.title = presentationData.strings.Attachment_Gallery
        }
        
        self.cancelButtonNode = WebAppCancelButtonNode(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        self.selectedButtonNode = SelectedButtonNode(theme: self.presentationData.theme)
        self.selectedButtonNode.alpha = 0.0
        self.selectedButtonNode.transform = CATransform3DMakeScale(0.01, 0.01, 1.0)
        
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
            
            if let selectionContext = self.interaction?.selectionState, let editingContext = self.interaction?.editingState {
                var price: Int64?
                for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                    if price == nil, let itemPrice = editingContext.price(for: item) as? Int64 {
                        price = itemPrice
                        break
                    }
                }
                
                if let price, let item = item as? TGMediaEditableItem {
                    editingContext.setPrice(NSNumber(value: price), for: item)
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
        
        self.titleView.action = { [weak self] in
            if let self {
                self.presentGroupsMenu()
            }
        }
                
        self.navigationItem.titleView = self.titleView
        
        if case let .assets(collection, mode) = self.subject, mode != .default {
            if case .wallpaper = mode {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.backPressed))
            } else if collection == nil {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
                
                if forCollage {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Select, target: self, action: #selector(self.selectPressed))
                } else {
                    if [.createSticker].contains(mode) {
                        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
                        self.navigationItem.rightBarButtonItem?.action = #selector(self.rightButtonPressed)
                        self.navigationItem.rightBarButtonItem?.target = self
                    }
                }
            } else {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.backPressed))
            }
        } else {
            if case let .assets(collection, _) = self.subject, collection != nil {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.backPressed))
            } else {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: self.cancelButtonNode)
                self.navigationItem.leftBarButtonItem?.action = #selector(self.cancelPressed)
                self.navigationItem.leftBarButtonItem?.target = self
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
        
        self.selectedButtonNode.addTarget(self, action: #selector(self.selectedPressed), forControlEvents: .touchUpInside)
        
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
        
        self.interaction = MediaPickerInteraction(downloadManager: self.downloadManager,
        openMedia: { [weak self] fetchResult, index, immediateThumbnail in
            self?.controllerNode.openMedia(fetchResult: fetchResult, index: index, immediateThumbnail: immediateThumbnail)
        },
        openSelectedMedia: { [weak self] item, immediateThumbnail in
            self?.controllerNode.openSelectedMedia(item: item, immediateThumbnail: immediateThumbnail)
        },
        openDraft: { [weak self] draft, immediateThumbnail in
            self?.controllerNode.openDraft(draft: draft, immediateThumbnail: immediateThumbnail)
        },
        toggleSelection: { [weak self] item, value, suggestUndo in
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
        }, sendSelected: { [weak self] currentItem, silently, scheduleTime, animated, parameters, completion in
            if let strongSelf = self, let selectionState = strongSelf.interaction?.selectionState, !strongSelf.isDismissing {
                strongSelf.isDismissing = true
                if let currentItem = currentItem {
                    selectionState.setItem(currentItem, selected: true)
                }
                strongSelf.controllerNode.send(fromGallery: currentItem != nil, silently: silently, scheduleTime: scheduleTime, animated: animated, parameters: parameters, completion: completion)
            }
        }, schedule: { [weak self] parameters in
            if let strongSelf = self {
                strongSelf.presentSchedulePicker(false, { [weak self] time in
                    self?.interaction?.sendSelected(nil, false, time, true, parameters, {})
                })
            }
        }, dismissInput: { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.dismissInput()
            }
        }, selectionState: selectionContext, editingState: editingContext ?? TGMediaEditingContext())
        self.interaction?.selectionState?.grouping = true
        
        self.interaction?.editingState.sendPaidMessageStars = sendPaidMessageStars ?? 0
        
        if case let .media(media) = self.subject {
            for item in media {
                selectionContext.setItem(item.asset, selected: true)
            }
        }
        
        self.updateSelectionState(count: Int32(selectionContext.count()))
        
        if case let .assets(_, mode) = self.subject, case .createSticker = mode {
            let _ = cutoutAvailability(context: context).startStandalone()
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
        
        self.controllerNode.displayModeUpdated = { [weak self] _ in
            guard let self else {
                return
            }
            let count = Int32(self.interaction?.selectionState?.count() ?? 0)
            self.updateSelectionState(count: count)
        }
        if case .media = self.subject {
            self.controllerNode.updateDisplayMode(.selected, animated: false)
        }
        
        super.displayNodeDidLoad()
    }
    
    public func closeGalleryController() {
        self.controllerNode.closeGalleryController()
    }
    
    public var groupsPresented: () -> Void = {}
    
    private var didSetupGroups = false
    private let groupsPromise = Promise<[MediaGroupItem]>()
    
    public func presentGroupsMenu() {
        self.groupsPresented()
        
        let _ = (self.groupsPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] items in
            guard let self else {
                return
            }
            let items = items.filter { $0.count > 0 || $0.collection.assetCollectionSubtype == .smartAlbumAllHidden }
            var dismissImpl: (() -> Void)?
            let content: ContextControllerItemsContent = MediaGroupsContextMenuContent(
                context: self.context,
                items: items,
                selectGroup: { [weak self] collection in
                    guard let self else {
                        return
                    }
                    self.controllerNode.resetOnUpdate = true
                    if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                        self.selectedCollectionValue = nil
                        self.titleView.title = self.presentationData.strings.MediaPicker_Recents
                    } else {
                        self.selectedCollectionValue = collection
                        self.titleView.title = collection.localizedTitle ?? ""
                    }
                    self.scrollToTop?()
                    dismissImpl?()
                }
            )
            
            self.titleView.isHighlighted = true
            let contextController = ContextController(
                presentationData: self.presentationData,
                source: .reference(MediaPickerContextReferenceContentSource(controller: self, sourceNode: self.titleView.contextSourceNode)),
                items: .single(ContextController.Items(content: .custom(content))),
                gesture: nil
            )
            contextController.dismissed = { [weak self] in
                self?.titleView.isHighlighted = false
            }
            dismissImpl = { [weak contextController] in
                contextController?.dismiss()
            }
            self.presentInGlobalOverlay(contextController)
        })
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
    
    fileprivate var selectionCount: Int32 = 0
    fileprivate func updateSelectionState(count: Int32) {
        self.selectionCount = count
        guard let layout = self.validLayout else {
            return
        }
    
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
        var moreIsVisible = false
        if case let .assets(_, mode) = self.subject, [.story, .createSticker].contains(mode) {
            moreIsVisible = true
        } else if case let .media(media) = self.subject {
            self.titleView.title = media.count == 1 ? self.presentationData.strings.Attachment_Pasteboard : self.presentationData.strings.Attachment_SelectedMedia(count)
            self.titleView.segmentsHidden = true
            moreIsVisible = true
//            self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        } else {
            let title: String
            let isEnabled: Bool
            if self.controllerNode.currentDisplayMode == .selected {
                title = self.presentationData.strings.Attachment_SelectedMedia(count)
                isEnabled = false
            } else {
                title = self.selectedCollectionValue?.localizedTitle ?? self.presentationData.strings.MediaPicker_Recents
                isEnabled = true
            }
            self.titleView.updateTitle(title: title, isEnabled: isEnabled, animated: true)
            self.cancelButtonNode.setState(isEnabled ? .cancel : .back, animated: true)
            
            let selectedSize = self.selectedButtonNode.update(count: count)
            
            var safeInset: CGFloat = 0.0
            if layout.safeInsets.right > 0.0 {
                safeInset += layout.safeInsets.right + 16.0
            }
            let navigationHeight = navigationLayout(layout: layout).navigationFrame.height
            self.selectedButtonNode.frame = CGRect(origin: CGPoint(x: self.view.bounds.width - 54.0 - selectedSize.width - safeInset, y: floorToScreenPixels((navigationHeight - selectedSize.height) / 2.0) + 1.0), size: selectedSize)
            
            let isSelectionButtonVisible = count > 0 && self.controllerNode.currentDisplayMode == .all
            transition.updateAlpha(node: self.selectedButtonNode, alpha: isSelectionButtonVisible ? 1.0 : 0.0)
            transition.updateTransformScale(node: self.selectedButtonNode, scale: isSelectionButtonVisible ? 1.0 : 0.01)
            
            if self.selectedButtonNode.supernode == nil {
                self.navigationBar?.addSubnode(self.selectedButtonNode)
            }
            
            self.titleView.segmentsHidden = true
            moreIsVisible = count > 0
        }
        
        transition.updateAlpha(node: self.moreButtonNode.iconNode, alpha: moreIsVisible ? 1.0 : 0.0)
        transition.updateTransformScale(node: self.moreButtonNode.iconNode, scale: moreIsVisible ? 1.0 : 0.1)
        
        //if self. {
            //self.mainButtonStatePromise.set(.single(AttachmentMainButtonState(text: "Add", badge: "\(count)", font: .bold, background: .color(self.presentationData.theme.actionSheet.controlAccentColor), textColor: self.presentationData.theme.list.itemCheckColors.foregroundColor, isVisible: count > 0, progress: .none, isEnabled: true, hasShimmer: false)))
        //}
    }
    
    private func updateThemeAndStrings() {
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.titleView.theme = self.presentationData.theme
        self.cancelButtonNode.theme = self.presentationData.theme
        self.moreButtonNode.theme = self.presentationData.theme
        self.selectedButtonNode.theme = self.presentationData.theme
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    @objc private func backPressed() {
        if let _ = self.navigationController {
            self.dismiss()
        } else {
            self.updateNavigationStack { current in
                var mediaPickerContext: AttachmentMediaPickerContext?
                if let first = current.first as? MediaPickerScreenImpl {
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
        
    public override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.cancelAssetDownloads()
        
        if case .assets(_, .story) = self.subject {
            let contentOffset = self.controllerNode.gridNode.scrollView.contentOffset.y
            if contentOffset > 100.0 || savedStoriesContentOffset != nil {
                savedStoriesContentOffset = contentOffset
            }
        }
        
        if let camera = self.controllerNode.modernCamera {
            if let cameraView = self.controllerNode.modernCameraView {
                cameraView.isEnabled = false
            }
            camera.stopCapture(invalidate: true)
        }
        
        super.dismiss(completion: completion)
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
    
    private weak var groupsController: MediaGroupsScreen?
    private func presentSearch(activateOnDisplay: Bool) {
        guard self.moreButtonNode.iconNode.iconState == .search, case let .assets(_, mode) = self.subject else {
            return
        }
        
        self.requestAttachmentMenuExpansion()
        
        var embedded = true
        if case .story = mode {
            embedded = false
        }
        
        var updateNavigationStackImpl: ((AttachmentContainable) -> Void)?
        let groupsController = MediaGroupsScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, mediaAssetsContext: self.controllerNode.mediaAssetsContext, embedded: embedded, openGroup: { [weak self] collection in
            if let strongSelf = self {
                let mediaPicker = MediaPickerScreenImpl(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: strongSelf.peer, threadTitle: strongSelf.threadTitle, chatLocation: strongSelf.chatLocation, isScheduledMessages: strongSelf.isScheduledMessages, bannedSendPhotos: strongSelf.bannedSendPhotos, bannedSendVideos: strongSelf.bannedSendVideos, subject: .assets(collection, mode), editingContext: strongSelf.interaction?.editingState, selectionContext: strongSelf.interaction?.selectionState)
                
                mediaPicker.presentSchedulePicker = strongSelf.presentSchedulePicker
                mediaPicker.presentTimerPicker = strongSelf.presentTimerPicker
                mediaPicker.getCaptionPanelView = strongSelf.getCaptionPanelView
                mediaPicker.legacyCompletion = strongSelf.legacyCompletion
                mediaPicker.customSelection = strongSelf.customSelection
                mediaPicker.dismissAll = { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
                
                mediaPicker._presentedInModal = true
                mediaPicker.updateNavigationStack = strongSelf.updateNavigationStack
                
                updateNavigationStackImpl?(mediaPicker)
            }
        })
        groupsController.updateNavigationStack = self.updateNavigationStack
        if !embedded {
            groupsController._presentedInModal = true
        }
        
        updateNavigationStackImpl = { [weak self, weak groupsController] c in
            if let self {
                if case .story = mode, let groupsController {
                    self.updateNavigationStack({ _ in return ([self, groupsController, c], self.mediaPickerContext)})
                } else {
                    self.updateNavigationStack({ _ in return ([self, c], self.mediaPickerContext)})
                }
            }
        }
        
        if case .story = mode {
            self.updateNavigationStack({ _ in return ([self, groupsController], self.mediaPickerContext)})
        } else {
            self.presentWebSearch(groupsController, activateOnDisplay)
        }
        self.groupsController = groupsController
    }
    
    @objc private func cancelPressed() {
        self.dismissAllTooltips()
        if case .back = self.cancelButtonNode.state {
            self.controllerNode.updateDisplayMode(.all)
        } else {
            self.dismiss()
        }
    }
    
    @objc private func selectPressed() {
        self.navigationItem.setRightBarButton(nil, animated: true)
        self.explicitMultipleSelection = true
        
        if let state = self.controllerNode.state {
            self.controllerNode.updateState(state)
        }
    }
    
    @objc private func selectedPressed() {
        self.controllerNode.updateDisplayMode(.selected, animated: true)
    }
    
    @objc private func searchOrMorePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard self.moreButtonNode.iconNode.alpha > 0.0 else {
            return
        }
        let strings = self.presentationData.strings
        if case let .assets(_, mode) = self.subject, [.createSticker].contains(mode) {
            var items: [ContextMenuItem] = []
            if mode != .addImage {
                items.append(.action(ContextMenuActionItem(text: strings.Attachment_Create, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Draw"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    self?.createFromScratch()
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.Attachment_SelectFromFiles, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/File"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                
                self?.presentFilePicker()
            })))
            
            let contextController = ContextController(presentationData: self.presentationData, source: .reference(MediaPickerContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            self.presentInGlobalOverlay(contextController)
            
            return
        }
        
        switch self.moreButtonNode.iconNode.iconState {
            case .search:
//            self.presentSearch(activateOnDisplay: true)
                break
            case .more:
                let selectionCount = self.selectionCount
            
                var isSpoilerAvailable = true
                if let peer = self.peer, case .secretChat = peer {
                    isSpoilerAvailable = false
                }
            
                var hasSpoilers = false
                var price: Int64?
                var hasGeneric = false
                if let selectionContext = self.interaction?.selectionState, let editingContext = self.interaction?.editingState {
                    for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                        if price == nil, let itemPrice = editingContext.price(for: item) as? Int64 {
                            price = itemPrice
                        }
                        if editingContext.spoiler(for: item) {
                            hasSpoilers = true
                        } else {
                            hasGeneric = true
                        }
                    }
                }
            
                var isCaptionAboveMediaAvailable: Signal<Bool, NoError> = .single(false)
                if let mediaPickerContext = self.mediaPickerContext {
                    isCaptionAboveMediaAvailable = .single(mediaPickerContext.hasCaption)
                }
                        
                let items: Signal<ContextController.Items, NoError> = combineLatest(
                    self.groupedPromise.get(),
                    isCaptionAboveMediaAvailable
                )
                |> deliverOnMainQueue
                |> map { [weak self] grouped, isCaptionAboveMediaAvailable -> ContextController.Items in
                    guard let self else {
                        return ContextController.Items(content: .list([]))
                    }
                    var items: [ContextMenuItem] = []
                    if !hasSpoilers && price == nil {
                        items.append(.action(ContextMenuActionItem(text: selectionCount > 1 ? strings.Attachment_SendAsFiles : strings.Attachment_SendAsFile, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/File"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            self?.controllerNode.send(asFile: true, silently: false, scheduleTime: nil, animated: true, parameters: nil, completion: {})
                        })))
                    }
                    if selectionCount > 1, price == nil {
                        items.append(.action(ContextMenuActionItem(text: strings.Attachment_SendWithoutGrouping, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Media Grid/GroupingOff"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            self?.groupedValue = false
                            self?.controllerNode.send(asFile: false, silently: false, scheduleTime: nil, animated: true, parameters: nil, completion: {})
                        })))
                    }
                    
                    var isPaidAvailable = false
                    if self.paidMediaAllowed, selectionCount <= 10 {
                        isPaidAvailable = true
                    }
                    if isSpoilerAvailable || isPaidAvailable || (selectionCount > 0 && isCaptionAboveMediaAvailable) {
                        if !items.isEmpty {
                            items.append(.separator)
                        }
                        
                        if isCaptionAboveMediaAvailable {
                            var mediaCaptionIsAbove = false
                            if let interaction = self.interaction {
                                mediaCaptionIsAbove = interaction.editingState.isCaptionAbove()
                            }
                            
                            items.append(.action(ContextMenuActionItem(text: mediaCaptionIsAbove ? strings.Chat_SendMessageMenu_MoveCaptionDown : strings.Chat_SendMessageMenu_MoveCaptionUp, icon: { _ in return nil }, iconAnimation: ContextMenuActionItem.IconAnimation(
                                name: !mediaCaptionIsAbove ? "message_preview_sort_above" : "message_preview_sort_below"
                            ), action: { [weak self]  _, f in
                                f(.default)
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                if let interaction = strongSelf.interaction {
                                    interaction.editingState.setCaptionAbove(!interaction.editingState.isCaptionAbove())
                                }
                            })))
                        }
                        if isSpoilerAvailable && price == nil {
                            items.append(.action(ContextMenuActionItem(text: hasGeneric ? strings.Attachment_EnableSpoiler : strings.Attachment_DisableSpoiler, icon: { _ in return nil }, iconAnimation: ContextMenuActionItem.IconAnimation(
                                name: "anim_spoiler",
                                loop: true
                            ), action: { [weak self]  _, f in
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
                        if isPaidAvailable {
                            let title: String
                            let titleLayout: ContextMenuActionItemTextLayout
                            if let price {
                                title = strings.Attachment_Paid_EditPrice
                                titleLayout = .secondLineWithValue(strings.Attachment_Paid_EditPrice_Stars(Int32(price)))
                            } else {
                                title = strings.Attachment_Paid_Create
                                titleLayout = .twoLinesMax
                            }
                            items.append(.action(ContextMenuActionItem(text: title, textLayout: titleLayout, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Paid"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self]  _, f in
                                f(.default)
                                guard let  self else {
                                    return
                                }
                                
                                let controller = self.context.sharedContext.makeStarsAmountScreen(context: self.context, initialValue: price, completion: { [weak self] amount in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if let selectionContext = strongSelf.interaction?.selectionState, let editingContext = strongSelf.interaction?.editingState {
                                        selectionContext.selectionLimit = 10
                                        for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                                            editingContext.setPrice(NSNumber(value: amount), for: item)
                                        }
                                    }
                                })
                                self.parentController()?.push(controller)
                            })))
                        }
                    }
                    return ContextController.Items(content: .list(items))
                }
            
                let contextController = ContextController(presentationData: self.presentationData, source: .reference(MediaPickerContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
                self.presentInGlobalOverlay(contextController)
        }
    }
    
    fileprivate func defaultTransitionView() -> UIView? {
        return self.controllerNode.defaultTransitionView()
    }
    
    public func transitionView(for identifier: String, snapshot: Bool, hideSource: Bool = false) -> UIView? {
        return self.controllerNode.transitionView(for: identifier, snapshot: snapshot, hideSource: hideSource)
    }
    
    public func transitionImage(for identifier: String) -> UIImage? {
        return self.controllerNode.transitionImage(for: identifier)
    }
    
    public func updateHiddenMediaId(_ id: String?) {
        if self.customSelection != nil {
            self.controllerNode.hasGallery = id != nil
            self.controllerNode.updateIsCameraActive()
        }
        self.controllerNode.hiddenMediaId.set(.single(id))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
                
        self.validLayout = layout
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)

        var safeInset: CGFloat = 0.0
        if layout.safeInsets.right > 0.0 {
            safeInset += layout.safeInsets.right + 16.0
        }
        let navigationHeight = navigationLayout(layout: layout).navigationFrame.height
        self.selectedButtonNode.frame = CGRect(origin: CGPoint(x: self.view.bounds.width - 54.0 - self.selectedButtonNode.frame.width - safeInset, y: floorToScreenPixels((navigationHeight - self.selectedButtonNode.frame.height) / 2.0) + 1.0), size: self.selectedButtonNode.frame.size)
    }
    
    public func dismissAnimated() {
        self.requestDismiss(completion: {})
    }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return MediaPickerContext(controller: self)
    }
}

final class MediaPickerContext: AttachmentMediaPickerContext {
    private weak var controller: MediaPickerScreenImpl?
    
    var selectionCount: Signal<Int, NoError> {
        if self.controller?.forCollage == true {
            return .single(0)
        } else {
            return Signal { [weak self] subscriber in
                let disposable = self?.controller?.interaction?.selectionState?.selectionChangedSignal().start(next: { [weak self] value in
                    subscriber.putNext(Int(self?.controller?.interaction?.selectionState?.count() ?? 0))
                }, error: { _ in }, completed: { })
                return ActionDisposable {
                    disposable?.dispose()
                }
            }
        }
    }
    
    var caption: Signal<NSAttributedString?, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            guard let caption = self.controller?.interaction?.editingState.forcedCaption() else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            
            let disposable = caption.start(next: { caption in
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
    
    var hasCaption: Bool {
        guard let isForcedCaption = self.controller?.interaction?.editingState.isForcedCaption() else {
            return false
        }
        return isForcedCaption
    }
    
    var canMakePaidContent: Bool {
        guard let controller = self.controller else {
            return false
        }
        var isPaidAvailable = false
        if controller.paidMediaAllowed && controller.selectionCount <= 10 {
            isPaidAvailable = true
        }
        return isPaidAvailable
    }
    
    var price: Int64? {
        guard let controller = self.controller else {
            return nil
        }
        var price: Int64?
        if let selectionContext = controller.interaction?.selectionState, let editingContext = controller.interaction?.editingState {
            for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                if price == nil, let itemPrice = editingContext.price(for: item) as? Int64 {
                    price = itemPrice
                    break
                }
            }
        }
        return price
    }
    
    func setPrice(_ price: Int64) {
        guard let controller = self.controller else {
            return
        }
        if let selectionContext = controller.interaction?.selectionState, let editingContext = controller.interaction?.editingState {
            selectionContext.selectionLimit = 10
            for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                editingContext.setPrice(NSNumber(value: price), for: item)
            }
        }
    }
    
    var hasTimers: Bool {
        guard let controller = self.controller else {
            return false
        }
        if let selectionContext = controller.interaction?.selectionState, let editingContext = controller.interaction?.editingState {
            for case let item as TGMediaEditableItem in selectionContext.selectedItems() {
                if let time = editingContext.timer(for: item), time.intValue > 0 {
                    return true
                }
            }
        }
        return false
    }
    
    var captionIsAboveMedia: Signal<Bool, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putNext(false)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            guard let captionAbove = self.controller?.interaction?.editingState.captionAbove() else {
                subscriber.putNext(false)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            
            let disposable = captionAbove.start(next: { caption in
                if let caption = caption as? NSNumber {
                    subscriber.putNext(caption.boolValue)
                } else {
                    subscriber.putNext(false)
                }
            }, error: { _ in }, completed: { })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
    
    func setCaptionIsAboveMedia(_ captionIsAboveMedia: Bool) -> Void {
        self.controller?.interaction?.editingState.setCaptionAbove(captionIsAboveMedia) 
    }
        
    public var loadingProgress: Signal<CGFloat?, NoError> {
        return .single(nil)
    }
    
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return self.controller?.mainButtonStatePromise.get() ?? .single(nil)
    }
    
    init(controller: MediaPickerScreenImpl) {
        self.controller = controller
    }
    
    func setCaption(_ caption: NSAttributedString) {
        self.controller?.interaction?.editingState.setForcedCaption(caption, skipUpdate: true)
    }
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode, parameters: ChatSendMessageActionSheetController.SendParameters?) {
        self.controller?.interaction?.sendSelected(nil, mode == .silently, mode == .whenOnline ? scheduleWhenOnlineTimestamp : nil, true, parameters, {})
    }
    
    func schedule(parameters: ChatSendMessageActionSheetController.SendParameters?) {
        self.controller?.interaction?.schedule(parameters)
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
    completion: @escaping (MediaPickerScreenImpl, Any) -> Void = { _, _ in },
    openColors: @escaping () -> Void
) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.animateAppearance = animateAppearance
    controller.requestController = { [weak controller] _, present in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let mediaPickerController = MediaPickerScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .wallpaper), mainButtonState: AttachmentMainButtonState(text: presentationData.strings.Conversation_Theme_SetColorWallpaper, font: .regular, background: .color(.clear), textColor: presentationData.theme.actionSheet.controlAccentColor, isVisible: true, progress: .none, isEnabled: true, hasShimmer: false), mainButtonAction: {
            controller?.dismiss(animated: true)
            openColors()
        })
        mediaPickerController.customSelection = completion
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}

public func mediaPickerController(
    context: AccountContext,
    hasSearch: Bool,
    completion: @escaping (Any) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkColorPresentationTheme)
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.requestController = { _, present in
        let mediaPickerController = MediaPickerScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .addImage), mainButtonState: nil, mainButtonAction: nil)
        mediaPickerController.customSelection = { controller, result in
            completion(result)
            controller.dismiss(animated: true)
        }
        if hasSearch {
            mediaPickerController.presentWebSearch = { [weak mediaPickerController] groups, activateOnDisplay in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
                |> deliverOnMainQueue).start(next: { configuration in
                    let webSearchController = WebSearchController(
                        context: context,
                        updatedPresentationData: updatedPresentationData,
                        peer: nil,
                        chatLocation: nil,
                        configuration: configuration,
                        mode: .editor(completion: { [weak mediaPickerController] image in
                            completion(image)
                            mediaPickerController?.dismiss(animated: true)
                        }),
                        activateOnDisplay: activateOnDisplay
                    )
                    mediaPickerController?.present(webSearchController, in: .current)
                })
            }
        }
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}

public func storyMediaPickerController(
    context: AccountContext,
    isDark: Bool,
    forCollage: Bool,
    selectionLimit: Int?,
    getSourceRect: @escaping () -> CGRect,
    completion: @escaping (Any, UIView, CGRect, UIImage?, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void,
    multipleCompletion: @escaping ([Any]) -> Void,
    dismissed: @escaping () -> Void,
    groupsPresented: @escaping () -> Void
) -> ViewController {
    var presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    if isDark {
        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
    }
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
   
    var selectionContext: TGMediaSelectionContext?
    if let selectionLimit {
        selectionContext = TGMediaSelectionContext()
        selectionContext?.selectionLimit = Int32(selectionLimit)
        selectionContext?.selectionLimitExceeded = {
            HapticFeedback().error()
        }
    }
    
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.forceSourceRect = true
    controller.getSourceRect = getSourceRect
    controller.requestController = { _, present in
        let mediaPickerController = MediaPickerScreenImpl(
            context: context,
            updatedPresentationData: updatedPresentationData,
            peer: nil,
            threadTitle: nil,
            chatLocation: nil,
            bannedSendPhotos: nil,
            bannedSendVideos: nil,
            subject: .assets(nil, .story),
            forCollage: forCollage,
            selectionContext: selectionContext,
            mainButtonState: nil,
            mainButtonAction: { [weak selectionContext] in
                if let selectionContext, let selectedItems = selectionContext.selectedItems() {
                    var results: [Any] = []
                    for item in selectedItems {
                        if let item = item as? TGMediaAsset, let asset = item.backingAsset {
                            results.append(asset)
                        }
                    }
                    multipleCompletion(results)
                }
            }
        )
        mediaPickerController.groupsPresented = groupsPresented
        mediaPickerController.customSelection = { controller, result in
            if let result = result as? MediaEditorDraft {
                controller.updateHiddenMediaId(result.path)
                if let transitionView = controller.transitionView(for: result.path, snapshot: false) {
                    let transitionOut: (Bool?) -> (UIView, CGRect)? = { isNew in
                        if let isNew {
                            controller.updateHiddenMediaId(result.path)
                            if isNew {
                                if let transitionView = controller.defaultTransitionView() {
                                    return (transitionView, transitionView.bounds)
                                }
                            } else {
                                if let transitionView = controller.transitionView(for: result.path, snapshot: false) {
                                    return (transitionView, transitionView.bounds)
                                }
                            }
                        }
                        return nil
                    }
                    completion(result, transitionView, transitionView.bounds, controller.transitionImage(for: result.path), transitionOut, { [weak controller] in
                        controller?.updateHiddenMediaId(nil)
                    })
                }
            } else if let result = result as? PHAsset {
                if !forCollage {
                    controller.updateHiddenMediaId(result.localIdentifier)
                }
                if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                    let transitionOut: (Bool?) -> (UIView, CGRect)? = { isNew in
                        if let isNew {
                            if isNew {
                                controller.updateHiddenMediaId(nil)
                                if let transitionView = controller.defaultTransitionView() {
                                    return (transitionView, transitionView.bounds)
                                }
                            } else if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                                return (transitionView, transitionView.bounds)
                            }
                        }
                        return nil
                    }
                    completion(result, transitionView, transitionView.bounds, controller.transitionImage(for: result.localIdentifier), transitionOut, { [weak controller] in
                        controller?.updateHiddenMediaId(nil)
                    })
                }
            }
        }
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.willDismiss = { [weak selectionContext] in
        dismissed()
        selectionContext?.clear()
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}

public func stickerMediaPickerController(
    context: AccountContext,
    getSourceRect: @escaping () -> CGRect?,
    completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void,
    dismissed: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.forceSourceRect = true
    controller.getSourceRect = getSourceRect
    controller.requestController = { [weak controller] _, present in
        let mediaPickerController = MediaPickerScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .createSticker), mainButtonState: nil, mainButtonAction: nil)
        mediaPickerController.customSelection = { controller, result in
            if let result = result as? PHAsset {
                controller.updateHiddenMediaId(result.localIdentifier)
                if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                    let transitionOut: (Bool?) -> (UIView, CGRect)? = { isNew in
                        if let isNew {
                            if isNew {
                                controller.updateHiddenMediaId(nil)
                                if let transitionView = controller.defaultTransitionView() {
                                    return (transitionView, transitionView.bounds)
                                }
                            } else if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                                return (transitionView, transitionView.bounds)
                            }
                        }
                        return nil
                    }
                    completion(result, transitionView, transitionView.bounds, controller.transitionImage(for: result.localIdentifier), false, transitionOut, { [weak controller] in
                        controller?.updateHiddenMediaId(nil)
                    })
                }
            }
        }
        mediaPickerController.createFromScratch = { [weak controller] in
            completion(nil, nil, .zero, nil, false, { _ in return nil }, {
            })
            controller?.dismiss(animated: true)
        }
        mediaPickerController.presentFilePicker = { [weak controller] in
            controller?.present(legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["public.image"], forceDarkTheme: false, dismissed: {
            }, completion: { urls in
                if let url = urls.first {
                    let isScopedResource = url.startAccessingSecurityScopedResource()
                    Logger.shared.log("MediaPicker", "isScopedResource = \(isScopedResource)")
                    
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    var error: NSError?
                    coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &error, byAccessor: { sourceUrl in
                        let fileName =  "img_\(sourceUrl.lastPathComponent)"
                        let copyPath = NSTemporaryDirectory() + fileName
                        
                        try? FileManager.default.removeItem(atPath: copyPath)
                        do {
                            try FileManager.default.copyItem(at: sourceUrl, to: URL(fileURLWithPath: copyPath))
                        } catch let e {
                            Logger.shared.log("MediaPicker", "copy file error \(e)")
                            if isScopedResource {
                                url.stopAccessingSecurityScopedResource()
                            }
                            return
                        }
                        
                        if let image = UIImage(contentsOfFile: copyPath) {
                            completion(image, nil, .zero, nil, false, { _ in return nil }, {})
                        }
                    })
                }
            }), in: .window(.root))
                                
            controller?.dismiss(animated: true)
        }
        mediaPickerController.openCamera = { [weak controller] cameraHolder in
            guard let cameraHolder = cameraHolder as? CameraHolder else {
                return
            }
            
            var returnToCameraImpl: (() -> Void)?
            let cameraScreen = CameraScreenImpl(
                context: context,
                mode: .sticker,
                holder: cameraHolder,
                transitionIn: CameraScreenImpl.TransitionIn(
                    sourceView: cameraHolder.parentView,
                    sourceRect: cameraHolder.parentView.bounds,
                    sourceCornerRadius: 0.0
                ),
                transitionOut: { _ in
                    return CameraScreenImpl.TransitionOut(
                        destinationView: cameraHolder.parentView,
                        destinationRect: cameraHolder.parentView.bounds,
                        destinationCornerRadius: 0.0
                    )
                },
                completion: { result, _, commit in
                    completion(result, nil, .zero, nil, true, { _ in return nil }, {
                        returnToCameraImpl?()
                    })
                }
            )
            cameraScreen.transitionedOut = { [weak cameraHolder] in
                if let cameraHolder {
                    cameraHolder.restore()
                }
            }
            controller?.push(cameraScreen)
            
            returnToCameraImpl = { [weak cameraScreen] in
                if let cameraScreen {
                    cameraScreen.returnFromEditor()
                }
            }
        }
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.willDismiss = {
        dismissed()
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}

public func avatarMediaPickerController(
    context: AccountContext,
    getSourceRect: @escaping () -> CGRect?,
    canDelete: Bool,
    performDelete: @escaping () -> Void,
    completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void,
    dismissed: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.forceSourceRect = true
    controller.getSourceRect = getSourceRect
    controller.requestController = { [weak controller] _, present in
        
        var mainButtonState: AttachmentMainButtonState?
        
        if canDelete {
            mainButtonState = AttachmentMainButtonState(text: presentationData.strings.MediaPicker_RemovePhoto, font: .regular, background: .color(.clear), textColor: presentationData.theme.actionSheet.destructiveActionTextColor, isVisible: true, progress: .none, isEnabled: true, hasShimmer: false)
        }
        
        let mediaPickerController = MediaPickerScreenImpl(
            context: context,
            updatedPresentationData: updatedPresentationData,
            peer: nil,
            threadTitle: nil,
            chatLocation: nil,
            bannedSendPhotos: nil,
            bannedSendVideos: nil,
            subject: .assets(nil, .createAvatar),
            mainButtonState: mainButtonState,
            mainButtonAction: { [weak controller] in
                controller?.dismiss(animated: true)
                performDelete()
            }
        )
        mediaPickerController.customSelection = { controller, result in
            if let result = result as? PHAsset {
                controller.updateHiddenMediaId(result.localIdentifier)
                if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                    let transitionOut: (Bool?) -> (UIView, CGRect)? = { isNew in
                        if let isNew {
                            if isNew {
                                controller.updateHiddenMediaId(nil)
                                if let transitionView = controller.defaultTransitionView() {
                                    return (transitionView, transitionView.bounds)
                                }
                            } else if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                                return (transitionView, transitionView.bounds)
                            }
                        }
                        return nil
                    }
                    completion(result, transitionView, transitionView.bounds, controller.transitionImage(for: result.localIdentifier), false, transitionOut, { [weak controller] in
                        controller?.updateHiddenMediaId(nil)
                    })
                }
            }
        }
        mediaPickerController.openAvatarEditor = { [weak controller] in
            completion(nil, nil, .zero, nil, false, { _ in return nil }, {
            })
            controller?.dismiss(animated: true)
        }
        mediaPickerController.openCamera = { [weak controller] cameraHolder in
            guard let cameraHolder = cameraHolder as? CameraHolder else {
                return
            }
            
            var returnToCameraImpl: (() -> Void)?
            let cameraScreen = CameraScreenImpl(
                context: context,
                mode: .avatar,
                holder: cameraHolder,
                transitionIn: CameraScreenImpl.TransitionIn(
                    sourceView: cameraHolder.parentView,
                    sourceRect: cameraHolder.parentView.bounds,
                    sourceCornerRadius: 0.0
                ),
                transitionOut: { _ in
                    return CameraScreenImpl.TransitionOut(
                        destinationView: cameraHolder.parentView,
                        destinationRect: cameraHolder.parentView.bounds,
                        destinationCornerRadius: 0.0
                    )
                },
                completion: { result, _, commit in
                    completion(result, nil, .zero, nil, true, { _ in return nil }, {
                        returnToCameraImpl?()
                    })
                }
            )
            cameraScreen.transitionedOut = { [weak cameraHolder] in
                if let cameraHolder {
                    cameraHolder.restore()
                }
            }
            controller?.push(cameraScreen)
            
            returnToCameraImpl = { [weak cameraScreen] in
                if let cameraScreen {
                    cameraScreen.returnFromEditor()
                }
            }
        }
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.willDismiss = {
        dismissed()
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}



public func coverMediaPickerController(
    context: AccountContext,
    completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void,
    dismissed: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkColorPresentationTheme)
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.requestController = { [weak controller] _, present in
        let mediaPickerController = MediaPickerScreenImpl(
            context: context,
            updatedPresentationData: updatedPresentationData,
            peer: nil,
            threadTitle: nil,
            chatLocation: nil,
            bannedSendPhotos: nil,
            bannedSendVideos: nil,
            subject: .assets(nil, .cover)
        )
        mediaPickerController.customSelection = { controller, result in
            if let result = result as? PHAsset {
                controller.updateHiddenMediaId(result.localIdentifier)
                if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                    let transitionOut: (Bool?) -> (UIView, CGRect)? = { isNew in
                        if let isNew {
                            if isNew {
                                controller.updateHiddenMediaId(nil)
                                if let transitionView = controller.defaultTransitionView() {
                                    return (transitionView, transitionView.bounds)
                                }
                            } else if let transitionView = controller.transitionView(for: result.localIdentifier, snapshot: false) {
                                return (transitionView, transitionView.bounds)
                            }
                        }
                        return nil
                    }
                    completion(result, transitionView, transitionView.bounds, controller.transitionImage(for: result.localIdentifier), false, transitionOut, { [weak controller] in
                        controller?.updateHiddenMediaId(nil)
                    })
                }
            }
        }
        mediaPickerController.openAvatarEditor = { [weak controller] in
            completion(nil, nil, .zero, nil, false, { _ in return nil }, {
            })
            controller?.dismiss(animated: true)
        }
        present(mediaPickerController, mediaPickerController.mediaPickerContext)
    }
    controller.willDismiss = {
        dismissed()
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    return controller
}

private class SelectedButtonNode: HighlightableButtonNode {
    private let background = ASImageNode()
    private let icon = ASImageNode()
    private let label = ImmediateAnimatedCountLabelNode()
    
    var theme: PresentationTheme {
        didSet {
            self.icon.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/SelectedIcon"), color: self.theme.list.itemCheckColors.foregroundColor)
            self.background.image = generateStretchableFilledCircleImage(radius: 21.0 / 2.0, color: self.theme.list.itemCheckColors.fillColor)
            let _ = self.update(count: self.count)
        }
    }
    
    private var count: Int32 = 0
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        super.init()
        
        self.background.displaysAsynchronously = false
        self.icon.displaysAsynchronously = false
        self.label.displaysAsynchronously = false
        
        self.icon.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/SelectedIcon"), color: self.theme.list.itemCheckColors.foregroundColor)
        self.background.image = generateStretchableFilledCircleImage(radius: 21.0 / 2.0, color: self.theme.list.itemCheckColors.fillColor)
        
        self.addSubnode(self.background)
        self.addSubnode(self.icon)
        self.addSubnode(self.label)
    }
    
    func update(count: Int32) -> CGSize {
        self.count = count
        
        let diameter: CGFloat = 21.0
        let font = Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers])
        
        let stringValue = "\(max(1, count))"
        var segments: [AnimatedCountLabelNode.Segment] = []
        for char in stringValue {
            if let intValue = Int(String(char)) {
                segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: self.theme.list.itemCheckColors.foregroundColor)))
            }
        }
        self.label.segments = segments
                
        let textSize = self.label.updateLayout(size: CGSize(width: 100.0, height: diameter), animated: true)
        let size = CGSize(width: textSize.width + 28.0, height: diameter)
        
        if let _ = self.icon.image {
            let iconSize = CGSize(width: 14.0, height: 11.0)
            let iconFrame = CGRect(origin: CGPoint(x: 5.0, y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            self.icon.frame = iconFrame
        }
        
        self.label.frame = CGRect(origin: CGPoint(x: 21.0, y: floor((size.height - textSize.height) / 2.0) - UIScreenPixel), size: textSize)
        self.background.frame = CGRect(origin: .zero, size: size)
        
        return size
    }
}
