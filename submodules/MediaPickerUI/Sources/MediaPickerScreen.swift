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
import MergeLists
import Photos
import PhotosUI
import LegacyComponents
import AttachmentUI
import SegmentedControlNode
import ManagedAnimationNode
import ContextUI
import LegacyMediaPickerUI
import WebSearchUI

private class MediaAssetsContext: NSObject, PHPhotoLibraryChangeObserver {
    private var registeredChangeObserver = false
    private let changeSink = ValuePipe<PHChange>()
    private let mediaAccessSink = ValuePipe<PHAuthorizationStatus>()
    private let cameraAccessSink = ValuePipe<AVAuthorizationStatus?>()
    
    override init() {
        super.init()
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            PHPhotoLibrary.shared().register(self)
            self.registeredChangeObserver = true
        }
    }
    
    deinit {
        if self.registeredChangeObserver {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        self.changeSink.putNext(changeInstance)
    }
    
    func fetchResultAssets(_ initialFetchResult: PHFetchResult<PHAsset>) -> Signal<PHFetchResult<PHAsset>?, NoError> {
        let fetchResult = Atomic<PHFetchResult<PHAsset>>(value: initialFetchResult)
        return .single(initialFetchResult)
        |> then(
            self.changeSink.signal()
            |> mapToSignal { change in
                if let updatedFetchResult = change.changeDetails(for: fetchResult.with { $0 })?.fetchResultAfterChanges {
                    let _ = fetchResult.modify { _ in return updatedFetchResult }
                    return .single(updatedFetchResult)
                } else {
                    return .complete()
                }
            }
        )
    }
    
    func recentAssets() -> Signal<PHFetchResult<PHAsset>?, NoError> {
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        if let collection = collections.firstObject {
            let initialFetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            return fetchResultAssets(initialFetchResult)
        } else {
            return .single(nil)
        }
    }
    
    func mediaAccess() -> Signal<PHAuthorizationStatus, NoError> {
        let initialStatus: PHAuthorizationStatus
        if #available(iOS 14.0, *) {
            initialStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            initialStatus = PHPhotoLibrary.authorizationStatus()
        }
        return .single(initialStatus)
        |> then(
            self.mediaAccessSink.signal()
        )
    }
    
    func requestMediaAccess() -> Void {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.mediaAccessSink.putNext(status)
        }
    }
    
    func cameraAccess() -> Signal<AVAuthorizationStatus?, NoError> {
#if targetEnvironment(simulator)
        return .single(.authorized)
#else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return .single(AVCaptureDevice.authorizationStatus(for: .video))
            |> then(
                self.cameraAccessSink.signal()
            )
        } else {
            return .single(nil)
        }
#endif
    }
    
    func requestCameraAccess() -> Void {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] result in
            if result {
                self?.cameraAccessSink.putNext(.authorized)
            } else {
                self?.cameraAccessSink.putNext(.denied)
            }
        })
    }
}

final class MediaPickerInteraction {
    let openMedia: (PHFetchResult<PHAsset>, Int, UIImage?) -> Void
    let openSelectedMedia: (TGMediaSelectableItem, UIImage?) -> Void
    let toggleSelection: (TGMediaSelectableItem, Bool) -> Void
    let sendSelected: (TGMediaSelectableItem?, Bool, Int32?, Bool) -> Void
    let schedule: () -> Void
    let selectionState: TGMediaSelectionContext?
    let editingState: TGMediaEditingContext
    var hiddenMediaId: String?
    
    init(openMedia: @escaping (PHFetchResult<PHAsset>, Int, UIImage?) -> Void, openSelectedMedia: @escaping (TGMediaSelectableItem, UIImage?) -> Void, toggleSelection: @escaping (TGMediaSelectableItem, Bool) -> Void, sendSelected: @escaping (TGMediaSelectableItem?, Bool, Int32?, Bool) -> Void, schedule: @escaping  () -> Void, selectionState: TGMediaSelectionContext?, editingState: TGMediaEditingContext) {
        self.openMedia = openMedia
        self.openSelectedMedia = openSelectedMedia
        self.toggleSelection = toggleSelection
        self.sendSelected = sendSelected
        self.schedule = schedule
        self.selectionState = selectionState
        self.editingState = editingState
    }
}

private struct MediaPickerGridEntry: Comparable, Identifiable {
    let stableId: Int
    let content: MediaPickerGridItemContent
    
    static func <(lhs: MediaPickerGridEntry, rhs: MediaPickerGridEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(account: Account, interaction: MediaPickerInteraction, theme: PresentationTheme) -> MediaPickerGridItem {
        return MediaPickerGridItem(content: self.content, interaction: interaction, theme: theme)
    }
}

private struct MediaPickerGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    
    init(previousList: [MediaPickerGridEntry], list: [MediaPickerGridEntry], account: Account, interaction: MediaPickerInteraction, theme: PresentationTheme, scrollToItem: GridNodeScrollToItem?) {
         let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction, theme: theme), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction, theme: theme)) }
        
        self.scrollToItem = scrollToItem
    }
}

private final class MediaPickerSegmentedTitleView: UIView {
    private let titleNode: ImmediateTextNode
    private let segmentedControlNode: SegmentedControlNode
    
    public var theme: PresentationTheme {
        didSet {
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: NavigationBar.titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
        }
    }
    
    public var title: String = "" {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: self.title, font: NavigationBar.titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
                self.setNeedsLayout()
            }
        }
    }
    
    public var segmentsHidden = true {
        didSet {
            if self.segmentsHidden != oldValue {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.21, curve: .easeInOut)
                transition.updateAlpha(node: self.titleNode, alpha: self.segmentsHidden ? 1.0 : 0.0)
                transition.updateAlpha(node: self.segmentedControlNode, alpha: self.segmentsHidden ? 0.0 : 1.0)
                self.segmentedControlNode.isUserInteractionEnabled = !self.segmentsHidden
            }
        }
    }
    
    public var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.segmentedControlNode.items = self.segments.map { SegmentedControlItem(title: $0) }
                self.setNeedsLayout()
            }
        }
    }
    
    public var index: Int {
        get {
            return self.segmentedControlNode.selectedIndex
        }
        set {
            self.segmentedControlNode.selectedIndex = newValue
        }
    }
    
    public var indexUpdated: ((Int) -> Void)?
    
    public init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: segments.map { SegmentedControlItem(title: $0) }, selectedIndex: selectedIndex)
        self.segmentedControlNode.alpha = 0.0
        self.segmentedControlNode.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            self?.indexUpdated?(index)
        }
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.segmentedControlNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: min(300.0, size.width - 36.0)), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - controlSize.width) / 2.0), y: floorToScreenPixels((size.height - controlSize.height) / 2.0)), size: controlSize)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: 44.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}

private final class MediaPickerMoreButtonNode: ASDisplayNode {
    fileprivate final class MoreIconNode: ManagedAnimationNode {
        enum State: Equatable {
            case more
            case search
        }
        
        private let duration: Double = 0.21
        var iconState: State = .search
        
        init() {
            super.init(size: CGSize(width: 30.0, height: 30.0))
            
            self.trackTo(item: ManagedAnimationItem(source: .local("anim_moretosearch"), frames: .range(startFrame: 90, endFrame: 90), duration: 0.0))
        }
            
        func play() {
            if case .more = self.iconState {
                self.trackTo(item: ManagedAnimationItem(source: .local("anim_moredots"), frames: .range(startFrame: 0, endFrame: 46), duration: 0.76))
            }
        }
        
        func enqueueState(_ state: State, animated: Bool) {
            guard self.iconState != state else {
                return
            }
            
            let previousState = self.iconState
            self.iconState = state
            
            let source = ManagedAnimationSource.local("anim_moretosearch")
            
            let totalLength: Int = 90
            if animated {
                switch previousState {
                    case .more:
                        switch state {
                            case .more:
                                break
                            case .search:
                                self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        }
                    case .search:
                        switch state {
                            case .more:
                                self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                            case .search:
                                break
                        }
                }
            } else {
                switch state {
                    case .more:
                        self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
                    case .search:
                        self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                }
            }
        }
    }

    var action: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    private let containerNode: ContextControllerSourceNode
    let contextSourceNode: ContextReferenceContentNode
    private let buttonNode: HighlightableButtonNode
    let iconNode: MoreIconNode
    
    var theme: PresentationTheme {
        didSet {
            self.iconNode.customColor = self.theme.rootController.navigationBar.buttonColor
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.contextSourceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.buttonNode = HighlightableButtonNode()
        self.iconNode = MoreIconNode()
        self.iconNode.customColor = self.theme.rootController.navigationBar.buttonColor
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.iconNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.action?(strongSelf.contextSourceNode, gesture)
        }
    }
    
    @objc private func buttonPressed() {
        self.action?(self.contextSourceNode, nil)
        if case .more = self.iconNode.iconState {
            self.iconNode.play()
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let animationSize = CGSize(width: 30.0, height: 30.0)
        let inset: CGFloat = 0.0
        self.iconNode.frame = CGRect(origin: CGPoint(x: inset + 4.0, y: floor((constrainedSize.height - animationSize.height) / 2.0)), size: animationSize)
        
        let size = CGSize(width: animationSize.width + inset * 2.0, height: constrainedSize.height)
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = bounds
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        return size
    }
}

public final class MediaPickerScreen: ViewController, AttachmentContainable {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let peer: EnginePeer?
    private let chatLocation: ChatLocation?
    
    private let titleView: MediaPickerSegmentedTitleView
    private let moreButtonNode: MediaPickerMoreButtonNode
    
    public weak var webSearchController: WebSearchController?
    
    public var openCamera: ((TGAttachmentCameraView?) -> Void)?
    public var presentStickers: ((@escaping (TelegramMediaFile, Bool, UIView, CGRect) -> Void) -> TGPhotoPaintStickersScreen?)?
    public var presentSchedulePicker: (Bool, @escaping (Int32) -> Void) -> Void = { _, _ in }
    public var presentTimerPicker: (@escaping (Int32) -> Void) -> Void = { _ in }
    public var presentWebSearch: () -> Void = {}
    public var getCaptionPanelView: () -> TGCaptionPanelView? = { return nil }
    
    public var legacyCompletion: (_ signals: [Any], _ silently: Bool, _ scheduleTime: Int32?) -> Void = { _, _, _ in }
    
    public var requestAttachmentMenuExpansion: () -> Void = {}

    private class Node: ViewControllerTracingNode {
        enum DisplayMode {
            case all
            case selected
        }
        
        enum State {
            case noAccess(cameraAccess: AVAuthorizationStatus?)
            case assets(fetchResult: PHFetchResult<PHAsset>?, mediaAccess: PHAuthorizationStatus, cameraAccess: AVAuthorizationStatus?)
        }
        
        private weak var controller: MediaPickerScreen?
        fileprivate var interaction: MediaPickerInteraction?
        private var presentationData: PresentationData
        private let mediaAssetsContext: MediaAssetsContext
        
        private let gridNode: GridNode
        private var cameraView: TGAttachmentCameraView?
        private var placeholderNode: MediaPickerPlaceholderNode?
        private var manageNode: MediaPickerManageNode?
        
        private let selectionNode: MediaPickerSelectedListNode
        
        private var nextStableId: Int = 1
        private var currentEntries: [MediaPickerGridEntry] = []
        private var enqueuedTransactions: [MediaPickerGridTransaction] = []
        private var state: State?
        
        private var itemsDisposable: Disposable?
        private var selectionChangedDisposable: Disposable?
        private var itemsDimensionsUpdatedDisposable: Disposable?
        private var hiddenMediaDisposable: Disposable?
        
        private let hiddenMediaId = Promise<String?>(nil)
        
        private var didSetReady = false
        private let _ready = Promise<Bool>()
        var ready: Promise<Bool> {
            return self._ready
        }
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: MediaPickerScreen) {
            self.controller = controller
            self.presentationData = controller.presentationData
            
            let mediaAssetsContext = MediaAssetsContext()
            self.mediaAssetsContext = mediaAssetsContext
            
            self.gridNode = GridNode()
            
            self.selectionNode = MediaPickerSelectedListNode(context: controller.context)
            self.selectionNode.alpha = 0.0
            self.selectionNode.isUserInteractionEnabled = false
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.gridNode)
            self.addSubnode(self.selectionNode)
                        
            self.interaction = MediaPickerInteraction(openMedia: { [weak self] fetchResult, index, immediateThumbnail in
                self?.openMedia(fetchResult: fetchResult, index: index, immediateThumbnail: immediateThumbnail)
            }, openSelectedMedia: { [weak self] item, immediateThumbnail in
                self?.openSelectedMedia(item: item, immediateThumbnail: immediateThumbnail)
            }, toggleSelection: { [weak self] item, value in
                if let strongSelf = self {
                    strongSelf.interaction?.selectionState?.setItem(item, selected: value)
                }
            }, sendSelected: { [weak self] currentItem, silently, scheduleTime, animated in
                if let strongSelf = self, let selectionState = strongSelf.interaction?.selectionState {
                    if let currentItem = currentItem {
                        selectionState.setItem(currentItem, selected: true)
                    }
                    strongSelf.send(silently: silently, scheduleTime: scheduleTime, animated: animated)
                }
            }, schedule: { [weak self] in
                if let strongSelf = self {
                    strongSelf.controller?.presentSchedulePicker(false, { [weak self] time in
                        self?.interaction?.sendSelected(nil, false, time, true)
                    })
                }
            }, selectionState: TGMediaSelectionContext(), editingState: TGMediaEditingContext())
            self.interaction?.selectionState?.grouping = true
            
            let updatedState = combineLatest(mediaAssetsContext.mediaAccess(), mediaAssetsContext.cameraAccess())
            |> mapToSignal { mediaAccess, cameraAccess -> Signal<State, NoError> in
                if case .notDetermined = mediaAccess {
                    return .single(.assets(fetchResult: nil, mediaAccess: mediaAccess, cameraAccess: cameraAccess))
                } else if [.restricted, .denied].contains(mediaAccess) {
                    return .single(.noAccess(cameraAccess: cameraAccess))
                } else {
                    return mediaAssetsContext.recentAssets()
                    |> map { fetchResult in
                        return .assets(fetchResult: fetchResult, mediaAccess: mediaAccess, cameraAccess: cameraAccess)
                    }
                }
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
            
            self.hiddenMediaDisposable = (self.hiddenMediaId.get()
            |> deliverOnMainQueue).start(next: { [weak self] id in
                if let strongSelf = self {
                    strongSelf.interaction?.hiddenMediaId = id
                    
                    strongSelf.gridNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? MediaPickerGridItemNode {
                            itemNode.updateHiddenMedia()
                        }
                    }
                    
                    strongSelf.selectionNode.updateHiddenMedia()
                }
            })
            
            if let selectionState = self.interaction?.selectionState {
                func selectionChangedSignal(selectionState: TGMediaSelectionContext) -> Signal<Void, NoError> {
                    return Signal { subscriber in
                        let disposable = selectionState.selectionChangedSignal()?.start(next: { next in
                            subscriber.putNext(Void())
                        }, completed: {})
                        return ActionDisposable {
                            disposable?.dispose()
                        }
                    }
                }
                
                self.selectionChangedDisposable = (selectionChangedSignal(selectionState: selectionState)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.updateSelectionState()
                    }
                })
            }
            
            if let editingState = self.interaction?.editingState {
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
                        
            self.selectionNode.interaction = self.interaction
        }
        
        deinit {
            self.itemsDisposable?.dispose()
            self.hiddenMediaDisposable?.dispose()
            self.selectionChangedDisposable?.dispose()
            self.itemsDimensionsUpdatedDisposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.gridNode.scrollView.alwaysBounceVertical = true
            self.gridNode.scrollView.showsVerticalScrollIndicator = false
            
            let cameraView = TGAttachmentCameraView(forSelfPortrait: false)!
            cameraView.clipsToBounds = true
            cameraView.removeCorners()
            cameraView.pressed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.controller?.openCamera?(strongSelf.cameraView)
                }
            }
            self.cameraView = cameraView
            cameraView.startPreview()
            
            self.gridNode.scrollView.addSubview(cameraView)
        }
                
        private func dismissInput() {
            self.view.window?.endEditing(true)
        }
        
        private var requestedMediaAccess = false
        private var requestedCameraAccess = false
        
        private func updateState(_ state: State) {
            guard let interaction = self.interaction, let controller = self.controller else {
                return
            }
            
            let previousState = self.state
            self.state = state
            
            var stableId: Int = 0
            var entries: [MediaPickerGridEntry] = []
            
            var updateLayout = false
            
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
                case let .assets(fetchResult, mediaAccess, cameraAccess):
                    if let fetchResult = fetchResult {
                        for i in 0 ..< fetchResult.count {
                            entries.append(MediaPickerGridEntry(stableId: stableId, content: .asset(fetchResult, fetchResult.count - i - 1)))
                            stableId += 1
                        }
                        
                        if case let .assets(previousFetchResult, _, previousCameraAccess) = previousState, previousFetchResult == nil || previousCameraAccess != cameraAccess {
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
            }
        
            let previousEntries = self.currentEntries
            self.currentEntries = entries
            
            let transaction = MediaPickerGridTransaction(previousList: previousEntries, list: entries, account: controller.context.account, interaction: interaction, theme: self.presentationData.theme, scrollToItem: nil)
            self.enqueueTransaction(transaction)
            
            if updateLayout, let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: previousState == nil ? .immediate : .animated(duration: 0.2, curve: .easeInOut))
            }
        }
        
        private func updateSelectionState() {
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? MediaPickerGridItemNode {
                    itemNode.updateSelectionState()
                }
            }
            self.selectionNode.updateSelectionState()
            
            let count = Int32(self.interaction?.selectionState?.count() ?? 0)
            self.controller?.updateSelectionState(count: count)
            
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        
        private var currentDisplayMode: DisplayMode = .all
        func updateMode(_ displayMode: DisplayMode) {
            self.currentDisplayMode = displayMode
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            self.gridNode.isUserInteractionEnabled = displayMode == .all
            
            transition.updateAlpha(node: self.selectionNode, alpha: displayMode == .selected ? 1.0 : 0.0)
            self.selectionNode.isUserInteractionEnabled = displayMode == .selected
        }
        
        private func openMedia(fetchResult: PHFetchResult<PHAsset>, index: Int, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, let interaction = self.interaction, let (layout, _) = self.validLayout else {
                return
            }
            
            let index = fetchResult.count - index - 1
            presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, chatLocation: controller.chatLocation, presentationData: self.presentationData, source: .fetchResult(fetchResult: fetchResult, index: index), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: true, hasTimer: true, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.gridNode.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime in
                if let strongSelf = self {
                    strongSelf.interaction?.sendSelected(result, silently, scheduleTime, false)
                }
            }, presentStickers: controller.presentStickers, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            })
        }
        
        private func openSelectedMedia(item: TGMediaSelectableItem, immediateThumbnail: UIImage?) {
            guard let controller = self.controller, let interaction = self.interaction, let (layout, _) = self.validLayout else {
                return
            }
            presentLegacyMediaPickerGallery(context: controller.context, peer: controller.peer, chatLocation: controller.chatLocation, presentationData: self.presentationData, source: .selection(item: item), immediateThumbnail: immediateThumbnail, selectionContext: interaction.selectionState, editingContext: interaction.editingState, hasSilentPosting: true, hasSchedule: true, hasTimer: true, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, initialLayout: layout, transitionHostView: { [weak self] in
                return self?.selectionNode.view
            }, transitionView: { [weak self] identifier in
                return self?.transitionView(for: identifier)
            }, completed: { [weak self] result, silently, scheduleTime in
                if let strongSelf = self {
                    strongSelf.interaction?.sendSelected(result, silently, scheduleTime, false)
                }
            }, presentStickers: controller.presentStickers, presentSchedulePicker: controller.presentSchedulePicker, presentTimerPicker: controller.presentTimerPicker, getCaptionPanelView: controller.getCaptionPanelView, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            })
        }
        
        fileprivate func send(asFile: Bool = false, silently: Bool, scheduleTime: Int32?, animated: Bool) {
            guard let signals = TGMediaAssetsController.resultSignals(for: self.interaction?.selectionState, editingContext: self.interaction?.editingState, intent: asFile ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent, currentItem: nil, storeAssets: true, convertToJpeg: false, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: true) else {
                return
            }
            self.controller?.legacyCompletion(signals, silently, scheduleTime)
            self.controller?.dismiss(animated: animated)
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
        
        private func transitionView(for identifier: String) -> UIView? {
            if self.selectionNode.alpha > 0.0 {
                return self.selectionNode.transitionView(for: identifier)
            } else {
                var transitionNode: MediaPickerGridItemNode?
                self.gridNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                        transitionNode = itemNode
                    }
                }
                return transitionNode?.transitionView()
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
            if self.selectionNode.alpha > 0.0 {
                self.selectionNode.scrollToTop(animated: animated)
            } else {
                self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.gridNode.scrollView.contentInset.top), animated: animated)
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let firstTime = self.validLayout == nil
            self.validLayout = (layout, navigationBarHeight)
            
            var insets = layout.insets(options: [])
            insets.top += navigationBarHeight
            
            let bounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height))
            
            let itemsPerRow: Int
            if case .compact = layout.metrics.widthClass {
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
            
            var manageHeight: CGFloat = 0.0
            if case let .assets(_, mediaAccess, cameraAccess) = self.state {
                if cameraAccess == nil {
                    cameraRect = nil
                }
                if case .notDetermined = mediaAccess {
                    
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
            transition.updateFrame(node: self.gridNode, frame: bounds)
            
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: bounds.size, insets: gridInsets, scrollIndicatorInsets: nil, preloadSize: 200.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth), fillWidth: true, lineSpacing: itemSpacing, itemSpacing: itemSpacing), cutout: cameraRect), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    Queue.mainQueue().justDispatch {
                        strongSelf._ready.set(.single(true))
                    }
                }
            })
            
            let selectedItems = self.interaction?.selectionState?.selectedItems() as? [TGMediaSelectableItem] ?? []
            let updateSelectionNode = {
                self.selectionNode.updateLayout(size: bounds.size, insets: cleanGridInsets, items: selectedItems, grouped: self.controller?.groupedValue ?? true, theme: self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper, bubbleCorners: self.presentationData.chatBubbleCorners, transition: transition)
            }
            
            if selectedItems.count < 1 && self.currentDisplayMode == .selected {
                self.updateMode(.all)
                Queue.mainQueue().after(0.3, updateSelectionNode)
            } else {
                updateSelectionNode()
            }
            transition.updateFrame(node: self.selectionNode, frame: bounds)
            
            if let cameraView = self.cameraView {
                if let cameraRect = cameraRect {
                    transition.updateFrame(view: cameraView, frame: cameraRect)
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
            
            if case let .noAccess(cameraAccess) = self.state {
                let placeholderNode: MediaPickerPlaceholderNode
                if let current = self.placeholderNode {
                    placeholderNode = current
                } else {
                    placeholderNode = MediaPickerPlaceholderNode()
                    placeholderNode.settingsPressed = { [weak self] in
                        self?.controller?.context.sharedContext.applicationBindings.openSettings()
                    }
                    placeholderNode.cameraPressed = { [weak self] in
                        self?.controller?.openCamera?(nil)
                    }
                    self.insertSubnode(placeholderNode, aboveSubnode: self.selectionNode)
                    self.placeholderNode = placeholderNode
                }
                placeholderNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, hasCamera: cameraAccess == .authorized, transition: transition)
                transition.updateFrame(node: placeholderNode, frame: bounds)
            } else if let placeholderNode = self.placeholderNode {
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
            self.controllerNode.interaction?.selectionState?.grouping = self.groupedValue
            
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
    }
    private let groupedPromise = ValuePromise<Bool>(true)
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: EnginePeer?, chatLocation: ChatLocation?) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
        self.chatLocation = chatLocation
        
        self.titleView = MediaPickerSegmentedTitleView(theme: self.presentationData.theme, segments: [self.presentationData.strings.Attachment_AllMedia, self.presentationData.strings.Attachment_SelectedMedia(1)], selectedIndex: 0)
        self.titleView.title = self.presentationData.strings.Attachment_Gallery
        
        self.moreButtonNode = MediaPickerMoreButtonNode(theme: self.presentationData.theme)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.statusBar.statusBarStyle = .Ignore
        
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
                strongSelf.controllerNode.updateMode(index == 0 ? .all : .selected)
            }
        }
        
        self.navigationItem.titleView = self.titleView
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
        
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
        
        super.displayNodeDidLoad()
    }
    
    private var selectionCount: Int32 = 0
    fileprivate func updateSelectionState(count: Int32) {
        self.selectionCount = count
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
    
    private func updateThemeAndStrings() {
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.titleView.theme = self.presentationData.theme
        self.moreButtonNode.theme = self.presentationData.theme
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    public func prepareForReuse() {
        if let webSearchController = self.webSearchController {
            self.webSearchController = nil
            webSearchController.dismiss()
        }
        self.scrollToTop?()
    }
    
    @objc private func searchOrMorePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        switch self.moreButtonNode.iconNode.iconState {
            case .search:
                self.requestAttachmentMenuExpansion()
                self.presentWebSearch()
            case .more:
                let strings = self.presentationData.strings
                let selectionCount = self.selectionCount
            
                let items: Signal<ContextController.Items, NoError>  = self.groupedPromise.get()
                |> deliverOnMainQueue
                |> map { [weak self] grouped -> ContextController.Items in
                    var items: [ContextMenuItem] = []
                    items.append(.action(ContextMenuActionItem(text: selectionCount > 1 ? strings.Attachment_SendAsFiles : strings.Attachment_SendAsFile, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/File"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)

                        self?.controllerNode.send(asFile: true, silently: false, scheduleTime: nil, animated: true)
                    })))
                
                    if selectionCount > 1 {
                        items.append(.separator)
                        
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
    
    public var mediaPickerContext: MediaPickerContext? {
        if let interaction = self.controllerNode.interaction {
            return MediaPickerContext(interaction: interaction)
        } else {
            return nil
        }
    }
}

public class MediaPickerContext: AttachmentMediaPickerContext {
    private weak var interaction: MediaPickerInteraction?
    
    public var selectionCount: Signal<Int, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = self?.interaction?.selectionState?.selectionChangedSignal().start(next: { [weak self] value in
                subscriber.putNext(Int(self?.interaction?.selectionState?.count() ?? 0))
            }, error: { _ in }, completed: { })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
    
    public var caption: Signal<NSAttributedString?, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = self?.interaction?.editingState.forcedCaption().start(next: { caption in
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
        
    init(interaction: MediaPickerInteraction) {
        self.interaction = interaction
    }
    
    public func setCaption(_ caption: NSAttributedString) {
        self.interaction?.editingState.setForcedCaption(caption, skipUpdate: true)
    }
    
    public func send(silently: Bool, mode: AttachmentMediaPickerSendMode) {
        self.interaction?.sendSelected(nil, silently, nil, true)
    }
    
    public func schedule() {
        self.interaction?.schedule()
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
        return ContextControllerReferenceViewInfo(referenceNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
