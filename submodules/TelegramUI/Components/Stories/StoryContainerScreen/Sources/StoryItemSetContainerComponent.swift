import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import ComponentDisplayAdapters
import ReactionSelectionNode
import EntityKeyboard
import MessageInputPanelComponent
import TelegramPresentationData
import SwiftSignalKit
import AccountContext
import LegacyInstantVideoController
import UndoUI
import ContextUI
import TelegramCore
import Postbox
import AvatarNode
import MediaEditorScreen
import ImageCompression
import ShareWithPeersScreen
import PlainButtonComponent
import TooltipUI
import PresentationDataUtils
import PeerReportScreen
import ChatEntityKeyboardInputNode
import TextFieldComponent
import TextFormat
import LocalMediaResources
import SaveToCameraRoll
import BundleIconComponent
import PeerListItemComponent
import PremiumUI
import AttachmentUI
import StickerPackPreviewUI
import TextNodeWithEntities
import TelegramStringFormatting
import LottieComponent
import Pasteboard
import Speak
import TranslateUI
import TelegramUIPreferences
import StoryFooterPanelComponent
import TelegramNotices
import SliderContextItem
import SaveProgressScreen

public final class StoryAvailableReactions: Equatable {
    let reactionItems: [ReactionItem]
    
    init(reactionItems: [ReactionItem]) {
        self.reactionItems = reactionItems
    }
    
    public static func ==(lhs: StoryAvailableReactions, rhs: StoryAvailableReactions) -> Bool {
        return lhs === rhs
    }
}

public final class StoryItemSetContainerComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var derivedBottomInset: CGFloat = 0.0
        public fileprivate(set) var derivedMediaSize: CGSize = .zero
        public fileprivate(set) var dismissFraction: CGFloat = 0.0
        
        public init() {
        }
    }
    
    public final class TransitionHint {
        public let allowSynchronousLoads: Bool
        
        public init(allowSynchronousLoads: Bool) {
            self.allowSynchronousLoads = allowSynchronousLoads
        }
    }
    
    public enum NavigationDirection {
        case previous
        case next
        case id(StoryId)
    }
    
    public struct PinchState: Equatable {
        var scale: CGFloat
        var location: CGPoint
        var offset: CGPoint
        
        init(scale: CGFloat, location: CGPoint, offset: CGPoint) {
            self.scale = scale
            self.location = location
            self.offset = offset
        }
    }
    
    public let context: AccountContext
    public let externalState: ExternalState
    public let storyItemSharedState: StoryContentItem.SharedState
    public let availableReactions: StoryAvailableReactions?
    public let slice: StoryContentContextState.FocusedSlice
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let containerInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let statusBarHeight: CGFloat
    public let inputHeight: CGFloat
    public let metrics: LayoutMetrics
    public let deviceMetrics: DeviceMetrics
    public let isProgressPaused: Bool
    public let isAudioMuted: Bool
    public let audioMode: StoryContentItem.AudioMode
    public let hideUI: Bool
    public let visibilityFraction: CGFloat
    public let isPanning: Bool
    public let pinchState: PinchState?
    public let presentController: (ViewController, Any?) -> Void
    public let presentInGlobalOverlay: (ViewController, Any?) -> Void
    public let close: () -> Void
    public let navigate: (NavigationDirection) -> Void
    public let delete: () -> Void
    public let markAsSeen: (StoryId) -> Void
    public let reorder: () -> Void
    public let controller: () -> ViewController?
    public let toggleAmbientMode: () -> Void
    public let keyboardInputData: Signal<ChatEntityKeyboardInputNode.InputData, NoError>
    public let closeFriends: Promise<[EnginePeer]>
    public let blockedPeers: BlockedPeersContext?
    let sharedViewListsContext: StoryItemSetViewListComponent.SharedListsContext
    let stealthModeTimeout: Int32?
    public let isDismissed: Bool
    
    init(
        context: AccountContext,
        externalState: ExternalState,
        storyItemSharedState: StoryContentItem.SharedState,
        availableReactions: StoryAvailableReactions?,
        slice: StoryContentContextState.FocusedSlice,
        theme: PresentationTheme,
        strings: PresentationStrings,
        containerInsets: UIEdgeInsets,
        safeInsets: UIEdgeInsets,
        statusBarHeight: CGFloat,
        inputHeight: CGFloat,
        metrics: LayoutMetrics,
        deviceMetrics: DeviceMetrics,
        isProgressPaused: Bool,
        isAudioMuted: Bool,
        audioMode: StoryContentItem.AudioMode,
        hideUI: Bool,
        visibilityFraction: CGFloat,
        isPanning: Bool,
        pinchState: PinchState?,
        presentController: @escaping (ViewController, Any?) -> Void,
        presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void,
        close: @escaping () -> Void,
        navigate: @escaping (NavigationDirection) -> Void,
        delete: @escaping () -> Void,
        markAsSeen: @escaping (StoryId) -> Void,
        reorder: @escaping () -> Void,
        controller: @escaping () -> ViewController?,
        toggleAmbientMode: @escaping () -> Void,
        keyboardInputData: Signal<ChatEntityKeyboardInputNode.InputData, NoError>,
        closeFriends: Promise<[EnginePeer]>,
        blockedPeers: BlockedPeersContext?,
        sharedViewListsContext: StoryItemSetViewListComponent.SharedListsContext,
        stealthModeTimeout: Int32?,
        isDismissed: Bool
    ) {
        self.context = context
        self.externalState = externalState
        self.storyItemSharedState = storyItemSharedState
        self.availableReactions = availableReactions
        self.slice = slice
        self.theme = theme
        self.strings = strings
        self.containerInsets = containerInsets
        self.safeInsets = safeInsets
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.isProgressPaused = isProgressPaused
        self.isAudioMuted = isAudioMuted
        self.audioMode = audioMode
        self.hideUI = hideUI
        self.visibilityFraction = visibilityFraction
        self.isPanning = isPanning
        self.pinchState = pinchState
        self.presentController = presentController
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.close = close
        self.navigate = navigate
        self.delete = delete
        self.markAsSeen = markAsSeen
        self.reorder = reorder
        self.controller = controller
        self.toggleAmbientMode = toggleAmbientMode
        self.keyboardInputData = keyboardInputData
        self.closeFriends = closeFriends
        self.blockedPeers = blockedPeers
        self.sharedViewListsContext = sharedViewListsContext
        self.stealthModeTimeout = stealthModeTimeout
        self.isDismissed = isDismissed
    }
    
    public static func ==(lhs: StoryItemSetContainerComponent, rhs: StoryItemSetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.availableReactions !== rhs.availableReactions {
            return false
        }
        if lhs.slice != rhs.slice {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
            return false
        }
        if lhs.inputHeight != rhs.inputHeight {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.isProgressPaused != rhs.isProgressPaused {
            return false
        }
        if lhs.isAudioMuted != rhs.isAudioMuted {
            return false
        }
        if lhs.audioMode != rhs.audioMode {
            return false
        }
        if lhs.hideUI != rhs.hideUI {
            return false
        }
        if lhs.visibilityFraction != rhs.visibilityFraction {
            return false
        }
        if lhs.isPanning != rhs.isPanning {
            return false
        }
        if lhs.pinchState != rhs.pinchState {
            return false
        }
        if lhs.stealthModeTimeout != rhs.stealthModeTimeout {
            return false
        }
        if lhs.isDismissed != rhs.isDismissed {
            return false
        }
        return true
    }
    
    struct ItemLayout {
        var containerSize: CGSize
        var contentFrame: CGRect
        var contentMinScale: CGFloat
        var contentScaleFraction: CGFloat
        var contentOverflowFraction: CGFloat
        
        var itemSpacing: CGFloat
        var centralVisibleItemWidth: CGFloat
        var sideVisibleItemWidth: CGFloat
        var fullItemScrollDistance: CGFloat
        var sideVisibleItemScale: CGFloat
        var halfItemScrollDistance: CGFloat
        
        init(
            containerSize: CGSize,
            contentFrame: CGRect,
            contentMinScale: CGFloat,
            contentScaleFraction: CGFloat,
            contentOverflowFraction: CGFloat
        ) {
            self.containerSize = containerSize
            self.contentFrame = contentFrame
            self.contentMinScale = contentMinScale
            self.contentScaleFraction = contentScaleFraction
            self.contentOverflowFraction = contentOverflowFraction
            
            self.itemSpacing = 12.0
            self.centralVisibleItemWidth = self.contentFrame.width * self.contentMinScale
            self.sideVisibleItemWidth = self.centralVisibleItemWidth - 54.0
            self.fullItemScrollDistance = self.centralVisibleItemWidth * 0.5 + self.itemSpacing + self.sideVisibleItemWidth * 0.5
            self.sideVisibleItemScale = self.contentMinScale * (self.sideVisibleItemWidth / self.centralVisibleItemWidth)
            self.halfItemScrollDistance = self.sideVisibleItemWidth * 0.5 + self.itemSpacing + self.sideVisibleItemWidth * 0.5
        }
    }
    
    final class VisibleItem {
        let externalState = StoryContentItem.ExternalState()
        let unclippedContainerView: UIView
        let contentContainerView: UIView
        let contentTintLayer = SimpleLayer()
        var contentViewsShadowView: UIImageView?
        let view = ComponentView<StoryContentItem.Environment>()
        var currentProgress: Double = 0.0
        var isBuffering: Bool = false
        var requestedNext: Bool = false
        var footerPanel: ComponentView<Empty>?
        
        init() {
            self.unclippedContainerView = UIView()
            self.unclippedContainerView.isUserInteractionEnabled = false
            
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.contentContainerView.layer.cornerCurve = .continuous
            }
            
            self.contentTintLayer.backgroundColor = UIColor(white: 0.0, alpha: 1.0).cgColor
        }
    }
    
    final class InfoItem {
        let component: AnyComponent<Empty>
        let view = ComponentView<Empty>()
        
        init(component: AnyComponent<Empty>) {
            self.component = component
        }
    }
    
    final class CaptionItem {
        let itemId: StoryId
        let externalState = StoryContentCaptionComponent.ExternalState()
        let view = ComponentView<Empty>()
        
        init(itemId: StoryId) {
            self.itemId = itemId
        }
    }
    
    final class ViewList {
        let view = ComponentView<Empty>()
        
        init() {
        }
    }
    
    private final class PanState {
        var fraction: CGFloat
        weak var scrollView: UIScrollView?
        var startContentOffsetY: CGFloat = 0.0
        var accumulatedOffset: CGFloat = 0.0
        var dismissedTooltips: Bool = false
        var didLockScrolling: Bool = false
        var contentOffset: CGFloat?
        
        init(fraction: CGFloat, scrollView: UIScrollView?) {
            self.fraction = fraction
            self.scrollView = scrollView
        }
    }
    
    private final class Scroller: UIScrollView {
        override init(frame: CGRect) {
            super.init(frame: frame)

            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.contentInsetAdjustmentBehavior = .never
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private static let shadowImage: UIImage? = {
        UIImage(named: "Stories/PanelGradient")
    }()
    
    enum ViewListDisplayState {
        case hidden
        case half
        case full
    }
    
    public final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let sendMessageContext: StoryItemSetContainerSendMessage
        
        private let scroller: Scroller
        
        let componentContainerView: UIView
        let overlayContainerView: SparseContainerView
        let itemsContainerView: UIView
        let controlsContainerView: UIView
        let controlsClippingView: UIView
        let controlsNavigationClippingView: UIView
        let topContentGradientView: UIImageView
        let bottomContentGradientLayer: SimpleGradientLayer
        let contentDimView: UIView
        
        let closeButton: HighlightableButton
        let closeButtonIconView: UIImageView
        
        let navigationStrip = ComponentView<MediaNavigationStripComponent.EnvironmentType>()
        let seekLabel = ComponentView<Empty>()
        
        var centerInfoItem: InfoItem?
        var leftInfoItem: InfoItem?
        
        let moreButton = ComponentView<Empty>()
        var currentSoundButtonState: Bool?
        let soundButton = ComponentView<Empty>()
        var privacyIcon: ComponentView<Empty>?
        
        var captionItem: CaptionItem?
        
        var videoRecordingBackgroundView: UIVisualEffectView?
        let inputPanel = ComponentView<Empty>()
        let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        let inputPanelContainer = SparseContainerView()
        private let inputPanelBackground = ComponentView<Empty>()
        
        var isUpdatingComponent: Bool = false
        
        var preparingToDisplayViewList: Bool = false
        
        var viewListDisplayState: ViewListDisplayState = .hidden
        
        private var targetViewListDisplayStateIsFull: Bool = false
        private var viewListMetrics: (minHeight: CGFloat, maxHeight: CGFloat, currentHeight: CGFloat)?
        
        var isSearchActive: Bool = false
        
        var viewLists: [StoryId: ViewList] = [:]
        let viewListsContainer: UIView
        
        var isEditingStory: Bool = false
        
        var itemLayout: ItemLayout?
        var ignoreScrolling: Bool = false
        
        var visibleItems: [StoryId: VisibleItem] = [:]
        var trulyValidIds: [StoryId] = []
        
        var reactionContextNode: ReactionContextNode?
        weak var disappearingReactionContextNode: ReactionContextNode?
        weak var willDismissReactionContextNode: ReactionContextNode?
        var displayLikeReactions: Bool = false
        var tempReactionsGesture: ContextGesture?
        var waitingForReactionAnimateOutToLike: MessageReaction.Reaction?
        weak var standaloneReactionAnimation: StandaloneReactionAnimation?
        
        weak var contextController: ContextController?
        weak var privacyController: ShareWithPeersScreen?
        
        var isReporting: Bool = false
        
        var component: StoryItemSetContainerComponent?
        weak var state: EmptyComponentState?
        
        private var audioRecorderDisposable: Disposable?
        private var audioRecorderStatusDisposable: Disposable?
        private var videoRecorderDisposable: Disposable?
        
        private weak var voiceMessagesRestrictedTooltipController: TooltipController?
        
        let transitionCloneContainerView: UIView
        
        private var awaitingSwitchToId: (from: StoryId, to: StoryId)?
        private var animateNextNavigationId: StoryId?
        private var initializedOffset: Bool = false
        
        private var viewListPanState: PanState?
        private var isCompletingViewListPan: Bool = false
        private var viewListSwipeRecognizer: InteractiveTransitionGestureRecognizer?
        
        private var verticalPanState: PanState?
        
        private var isAnimatingOut: Bool = false
        
        private var scheduledStoryUnpinnedUndoOverlay: ViewController?
        
        override init(frame: CGRect) {
            self.sendMessageContext = StoryItemSetContainerSendMessage()
            
            self.componentContainerView = UIView()
            
            self.overlayContainerView = SparseContainerView()
            
            self.itemsContainerView = UIView()
            
            self.scroller = Scroller()
            self.scroller.alwaysBounceHorizontal = true
            self.scroller.showsVerticalScrollIndicator = false
            self.scroller.showsHorizontalScrollIndicator = false
            self.scroller.decelerationRate = .normal
            self.scroller.delaysContentTouches = false
            
            self.controlsContainerView = SparseContainerView()
            self.controlsClippingView = SparseContainerView()
            self.controlsClippingView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.controlsClippingView.layer.cornerCurve = .continuous
            }
            
            self.controlsNavigationClippingView = SparseContainerView()
            self.controlsNavigationClippingView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.controlsNavigationClippingView.layer.cornerCurve = .continuous
            }
            
            self.topContentGradientView = UIImageView()
            if let image = StoryItemSetContainerComponent.shadowImage {
                self.topContentGradientView.image = image.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(image.size.height - 1.0))
                self.topContentGradientView.transform = CGAffineTransformMakeScale(1.0, -1.0)
            }
            
            self.bottomContentGradientLayer = SimpleGradientLayer()
            
            self.contentDimView = UIView()
            self.contentDimView.isUserInteractionEnabled = false
            
            self.closeButton = HighlightableButton()
            self.closeButtonIconView = UIImageView()
            
            self.transitionCloneContainerView = UIView()
            
            self.inputPanelContainer.clipsToBounds = true
            
            self.viewListsContainer = SparseContainerView()
            self.viewListsContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.componentContainerView)
            self.addSubview(self.overlayContainerView)

            self.itemsContainerView.addSubview(self.scroller)
            self.scroller.delegate = self
            self.itemsContainerView.addGestureRecognizer(self.scroller.panGestureRecognizer)
            
            self.componentContainerView.addSubview(self.itemsContainerView)
            self.componentContainerView.addSubview(self.controlsNavigationClippingView)
            self.componentContainerView.addSubview(self.controlsClippingView)
            self.componentContainerView.addSubview(self.controlsContainerView)
            
            self.controlsClippingView.addSubview(self.contentDimView)
            self.controlsNavigationClippingView.addSubview(self.topContentGradientView)
            self.layer.addSublayer(self.bottomContentGradientLayer)
            
            self.componentContainerView.addSubview(self.viewListsContainer)
            
            self.closeButton.addSubview(self.closeButtonIconView)
            self.overlayContainerView.addSubview(self.closeButton)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.delegate = self
            self.itemsContainerView.addGestureRecognizer(tapRecognizer)
            
            let verticalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.viewListDismissPanGesture(_:)), allowedDirections: { [weak self] point in
                guard let self else {
                    return []
                }
                
                for (_, viewList) in self.viewLists {
                    if let view = viewList.view.view, view.hitTest(self.convert(point, to: view), with: nil) != nil {
                        return [.down]
                    }
                }
                
                if self.reactionContextNode != nil {
                    return []
                }
                if hasFirstResponder(self) {
                    return []
                }
                
                if self.itemsContainerView.frame.contains(point) {
                    if self.viewListDisplayState != .hidden {
                    } else {
                        if !self.isPointInsideContentArea(point: point) {
                            return []
                        }
                    }
                }
                
                return [.down]
            })
            verticalPanRecognizer.delegate = self
            self.addGestureRecognizer(verticalPanRecognizer)
            
            let viewListSwipeRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.viewListPanGesture(_:)), allowedDirections: { [weak self] point in
                guard let self else {
                    return []
                }
                if self.viewListDisplayState != .half {
                    return []
                }
                if self.bounds.contains(point), !self.itemsContainerView.frame.contains(point) {
                    return [.left, .right]
                } else {
                    return []
                }
            })
            self.viewListSwipeRecognizer = viewListSwipeRecognizer
            self.addGestureRecognizer(viewListSwipeRecognizer)
            
            self.audioRecorderDisposable = (self.sendMessageContext.audioRecorder.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] audioRecorder in
                guard let self else {
                    return
                }
                if self.sendMessageContext.audioRecorderValue !== audioRecorder {
                    self.sendMessageContext.audioRecorderValue = audioRecorder
                    self.component?.controller()?.lockOrientation = audioRecorder != nil
                    
                    self.audioRecorderStatusDisposable?.dispose()
                    self.audioRecorderStatusDisposable = nil
                    
                    if let audioRecorder = audioRecorder {
                        self.sendMessageContext.wasRecordingDismissed = false
                        
                        if !audioRecorder.beginWithTone {
                            HapticFeedback().impact(.light)
                        }
                        audioRecorder.start()
                        self.audioRecorderStatusDisposable = (audioRecorder.recordingState
                        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                            guard let self else {
                                return
                            }
                            if case .stopped = value {
                                self.sendMessageContext.stopMediaRecording(view: self)
                            }
                        })
                    }
                    
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            })
            
            self.videoRecorderDisposable = (self.sendMessageContext.videoRecorder.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] videoRecorder in
                guard let self else {
                    return
                }
                if self.sendMessageContext.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = self.sendMessageContext.videoRecorderValue
                    self.sendMessageContext.videoRecorderValue = videoRecorder
                    self.component?.controller()?.lockOrientation = videoRecorder != nil
                    
                    if let videoRecorder = videoRecorder {
                        self.sendMessageContext.wasRecordingDismissed = false
                        HapticFeedback().impact(.light)
                        
                        videoRecorder.onDismiss = { [weak self] isCancelled in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.wasRecordingDismissed = true
                            self.sendMessageContext.videoRecorder.set(.single(nil))
                        }
                        videoRecorder.onStop = { [weak self] in
                            guard let self else {
                                return
                            }
                            /*if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                                    }
                                })
                            }*/
                            let _ = self
                        }
                        videoRecorder.didStop = { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.hasRecordedVideoPreview = true
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                        self.component?.controller()?.present(videoRecorder, in: .window(.root))
                        
                        if self.sendMessageContext.isMediaRecordingLocked {
                            videoRecorder.lockVideo()
                        }
                    }
                    
                    if let previousVideoRecorderValue {
                        let _ = previousVideoRecorderValue.dismissVideo()
                    }
                    
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.audioRecorderDisposable?.dispose()
            self.audioRecorderStatusDisposable?.dispose()
            self.audioRecorderStatusDisposable?.dispose()
            self.videoRecorderDisposable?.dispose()
            self.updateDisposable.dispose()
        }
        
        func allowsExternalGestures(point: CGPoint) -> Bool {
            if self.viewListDisplayState != .hidden {
                return false
            }
            return true
        }
        
        func allowsInstantPauseOnTouch(point: CGPoint) -> Bool {
            guard let component = self.component else {
                return false
            }
            guard let visibleItem = self.visibleItems[component.slice.item.id] else {
                return false
            }
            guard let itemView = visibleItem.view.view as? StoryItemContentComponent.View else {
                return false
            }
            if let captionItem = self.captionItem, (captionItem.externalState.isExpanded || captionItem.externalState.isSelectingText) {
                return false
            }
            
            let localPoint = self.convert(point, to: itemView)
            if itemView.bounds.contains(localPoint) {
                if !itemView.allowsInstantPauseOnTouch(point: localPoint) {
                    return false
                }
            }
            
            return true
        }
        
        func isPointInsideContentArea(point: CGPoint) -> Bool {
            if self.reactionContextNode != nil {
                return false
            }
            
            if let inputPanelView = self.inputPanel.view, inputPanelView.alpha != 0.0 {
                if inputPanelView.frame.contains(point) {
                    return false
                }
            }
            
            if let inputMediaView = self.sendMessageContext.inputMediaNode {
                if inputMediaView.frame.contains(point) {
                    return false
                }
            }
            
            if let centerInfoItemView = self.centerInfoItem?.view.view {
                if centerInfoItemView.convert(centerInfoItemView.bounds, to: self).contains(point) {
                    return false
                }
            }
            
            if let leftInfoItemView = self.leftInfoItem?.view.view {
                if leftInfoItemView.convert(leftInfoItemView.bounds, to: self).contains(point) {
                    return false
                }
            }
            
            if let captionItemView = self.captionItem?.view.view as? StoryContentCaptionComponent.View {
                if captionItemView.hitTest(self.convert(point, to: captionItemView), with: nil) != nil {
                    return false
                }
            }
            
            if self.controlsClippingView.frame.contains(point) {
                if let result = self.controlsClippingView.hitTest(self.convert(point, to: self.controlsClippingView), with: nil) {
                    if result != self.controlsClippingView {
                        return false
                    }
                }
                return true
            }
            
            if self.controlsContainerView.frame.contains(point) {
                if let result = self.controlsContainerView.hitTest(self.convert(point, to: self.controlsContainerView), with: nil) {
                    if result != self.controlsContainerView {
                        return false
                    }
                }
                return true
            }
            
            return false
        }
        
        func allowsInteractiveGestures() -> Bool {
            if self.viewListDisplayState != .hidden {
                return false
            }
            return true
        }
        
        func allowsVerticalPanGesture() -> Bool {
            if self.viewListDisplayState != .hidden {
                return false
            }
            return true
        }
        
        func rewindCurrentItem() {
            guard let component = self.component else {
                return
            }
            guard let visibleItem = self.visibleItems[component.slice.item.id] else {
                return
            }
            if let itemView = visibleItem.view.view as? StoryContentItem.View {
                itemView.rewind()
            }
        }
        
        func leaveAmbientMode() {
            guard let component = self.component else {
                return
            }
            guard let visibleItem = self.visibleItems[component.slice.item.id] else {
                return
            }
            if let itemView = visibleItem.view.view as? StoryContentItem.View {
                itemView.leaveAmbientMode()
            }
            
            self.state?.updated(transition: .immediate)
        }
        
        func enterAmbientMode(ambient: Bool) {
            guard let component = self.component else {
                return
            }
            guard let visibleItem = self.visibleItems[component.slice.item.id] else {
                return
            }
            if let itemView = visibleItem.view.view as? StoryContentItem.View {
                itemView.enterAmbientMode(ambient: ambient)
            }
            
            self.state?.updated(transition: .immediate)
        }
        
        @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                if otherGestureRecognizer is UIPanGestureRecognizer {
                    return true
                }
                return false
            } else {
                return false
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer {
                if let otherGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer {
                    if otherGestureRecognizer.view is UIScrollView {
                        return true
                    }
                    if let component = self.component, let viewList = self.viewLists[component.slice.item.id], let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                        if otherGestureRecognizer.view === viewListView {
                            return true
                        }
                    }
                }
                return false
            } else {
                return false
            }
        }
        
        func hasActiveDeactivateableInput() -> Bool {
            if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                if view.canDeactivateInput() && (hasFirstResponder(self) || self.sendMessageContext.currentInputMode == .media) {
                    return true
                }
            }
            return false
        }
        
        func deactivateInput() {
            if let view = self.inputPanel.view as? MessageInputPanelComponent.View, view.canDeactivateInput() {
                self.sendMessageContext.currentInputMode = .text
                if hasFirstResponder(self) {
                    view.deactivateInput()
                } else {
                    self.state?.updated(transition: .spring(duration: 0.4).withUserData(TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))))
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let component = self.component, let itemLayout = self.itemLayout {
                
                if self.displayLikeReactions {
                    self.displayLikeReactions = false
                    self.sendMessageContext.currentInputMode = .text
                    self.willDismissReactionContextNode = self.reactionContextNode
                    
                    if hasFirstResponder(self) {
                        self.endEditing(true)
                    }
                    
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    self.updateIsProgressPaused()
                } else if self.hasActiveDeactivateableInput() {
                    Queue.mainQueue().justDispatch {
                        self.deactivateInput()
                    }
                } else if self.viewListDisplayState != .hidden {
                    let point = recognizer.location(in: self)
                    
                    for (id, visibleItem) in self.visibleItems {
                        if visibleItem.contentContainerView.convert(visibleItem.contentContainerView.bounds, to: self).contains(point) {
                            if id == component.slice.item.id {
                                let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
                                
                                self.viewListDisplayState = .hidden
                                self.isSearchActive = false
                                
                                self.state?.updated(transition: transition)
                            } else {
                                self.animateNextNavigationId = id
                                component.navigate(.id(id))
                            }
                            
                            break
                        }
                    }
                } else if let captionItem = self.captionItem, (captionItem.externalState.isExpanded || captionItem.externalState.isSelectingText) {
                    if let captionItemView = captionItem.view.view as? StoryContentCaptionComponent.View {
                        if captionItem.externalState.isSelectingText {
                            captionItemView.cancelTextSelection()
                        } else {
                            captionItemView.collapse(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    }
                } else {
                    let referenceSize = self.controlsContainerView.frame.size
                    let point = recognizer.location(in: self.controlsContainerView)
                    
                    var selectedMediaArea: MediaArea?
                    
                    let safeAreaInset: CGFloat = 48.0
                    if point.x > safeAreaInset && point.x < referenceSize.width - safeAreaInset {
                        func isPoint(_ point: CGPoint, in area: MediaArea) -> Bool {
                            let tx = point.x - area.coordinates.x / 100.0 * referenceSize.width
                            let ty = point.y - area.coordinates.y / 100.0 * referenceSize.height
                            
                            let rad = -area.coordinates.rotation * Double.pi / 180.0
                            let cosTheta = cos(rad)
                            let sinTheta = sin(rad)
                            let rotatedX = tx * cosTheta - ty * sinTheta
                            let rotatedY = tx * sinTheta + ty * cosTheta
                            
                            return abs(rotatedX) <= area.coordinates.width / 100.0 * referenceSize.width / 2.0 * 1.1 && abs(rotatedY) <= area.coordinates.height / 100.0 * referenceSize.height / 2.0 * 1.1
                        }
                        
                        for area in component.slice.item.storyItem.mediaAreas.reversed() {
                            if case .reaction = area {
                                continue
                            }
                            
                            if isPoint(point, in: area) {
                                selectedMediaArea = area
                                break
                            }
                        }
                    }
                    
                    if let selectedMediaArea {
                        self.sendMessageContext.activateMediaArea(view: self, mediaArea: selectedMediaArea, position: point)
                    } else {
                        var direction: NavigationDirection?
                        if point.x < itemLayout.containerSize.width * 0.25 {
                            direction = .previous
                        } else {
                            direction = .next
                        }
                        
                        if let direction {
                            component.navigate(direction)
                        }
                    }
                }
            }
        }
        
        @objc private func viewListPanGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                if !self.bounds.isEmpty {
                    let translation = recognizer.translation(in: self)
                    let fraction: CGFloat = max(-1.0, min(1.0, translation.x / self.bounds.width))
                    self.viewListPanState = PanState(fraction: fraction, scrollView: nil)
                    self.isCompletingViewListPan = false
                    self.layer.removeAnimation(forKey: "isCompletingViewListPan")
                    self.state?.updated(transition: .immediate)
                }
            case .changed:
                if let viewListPanState = self.viewListPanState {
                    let translation = recognizer.translation(in: self)
                    let fraction: CGFloat = max(-1.0, min(1.0, translation.x / self.bounds.width))
                    viewListPanState.fraction = fraction
                    self.viewListPanState = viewListPanState
                    self.isCompletingViewListPan = false
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if let viewListPanState = self.viewListPanState {
                    let velocity = recognizer.velocity(in: self)
                    
                    var consumed = false
                    if let component = self.component, let currentIndex = component.slice.allItems.firstIndex(where: { $0.id == component.slice.item.id }) {
                        if (viewListPanState.fraction <= -0.3 || (viewListPanState.fraction <= -0.05 && velocity.x <= -200.0)), currentIndex != component.slice.allItems.count - 1 {
                            let nextItem = component.slice.allItems[currentIndex + 1]
                            self.animateNextNavigationId = nextItem.id
                            component.navigate(.id(nextItem.id))
                            consumed = true
                        } else if (viewListPanState.fraction >= 0.3 || (viewListPanState.fraction >= 0.05 && velocity.x >= 200.0)), currentIndex != 0 {
                            let previousItem = component.slice.allItems[currentIndex - 1]
                            self.animateNextNavigationId = previousItem.id
                            component.navigate(.id(previousItem.id))
                            consumed = true
                        }
                    }
                    
                    if !consumed {
                        let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
                        self.viewListPanState = nil
                        self.isCompletingViewListPan = true
                        transition.attachAnimation(view: self, id: "isCompletingViewListPan", completion: { [weak self] completed in
                            guard let self, completed else {
                                return
                            }
                            if self.isCompletingViewListPan {
                                self.isCompletingViewListPan = false
                                self.state?.updated(transition: .immediate)
                            }
                        })
                        self.state?.updated(transition: transition)
                    }
                }
            default:
                break
            }
        }
        
        @objc private func viewListDismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            switch recognizer.state {
            case .began, .changed:
                let translation = recognizer.translation(in: self)
                let fraction = max(-1.0, min(1.0, translation.y / self.bounds.height))
                
                if let verticalPanState = self.verticalPanState {
                    verticalPanState.fraction = fraction
                } else {
                    var targetScrollView: UIScrollView?
                    if case .began = recognizer.state, self.viewListDisplayState != .hidden, let viewList = self.viewLists[component.slice.item.id], let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                        if let hitResult = viewListView.hitTest(self.convert(recognizer.location(in: self), to: viewListView), with: nil) {
                            func findTargetScrollView(target: UIView, minParent: UIView) -> UIScrollView? {
                                if target === viewListView {
                                    return nil
                                }
                                if let target = target as? UIScrollView {
                                    return target
                                }
                                if let parent = target.superview {
                                    return findTargetScrollView(target: parent, minParent: minParent)
                                } else {
                                    return nil
                                }
                            }
                            targetScrollView = findTargetScrollView(target: hitResult, minParent: viewListView)
                        }
                    }
                    self.verticalPanState = PanState(fraction: fraction, scrollView: targetScrollView)
                }
                
                if let verticalPanState = self.verticalPanState {
                    if abs(verticalPanState.fraction) >= 0.1 && !verticalPanState.dismissedTooltips {
                        verticalPanState.dismissedTooltips = true
                        self.dismissAllTooltips()
                    }
                    
                    if let viewListMetrics = self.viewListMetrics, let scrollView = verticalPanState.scrollView {
                        let relativeTranslationY = recognizer.translation(in: self).y - verticalPanState.startContentOffsetY
                        let overflowY = scrollView.contentOffset.y - relativeTranslationY
                        
                        if !verticalPanState.didLockScrolling {
                            if scrollView.contentOffset.y == 0.0 {
                                verticalPanState.didLockScrolling = true
                            }
                            if let previousContentOffset = verticalPanState.contentOffset, (previousContentOffset < 0.0) != (scrollView.contentOffset.y < 0.0) {
                                verticalPanState.didLockScrolling = true
                            }
                        }
                        
                        var resetContentOffset = false
                        if self.viewListDisplayState == .half && verticalPanState.didLockScrolling {
                            verticalPanState.accumulatedOffset += -overflowY
                            if scrollView.contentOffset.y > 0.0 {
                                //verticalPanState.accumulatedOffset = max(0.0, verticalPanState.accumulatedOffset)
                            }
                            
                            let viewListHeight = viewListMetrics.minHeight - verticalPanState.accumulatedOffset
                            let viewListExpandDistance = viewListHeight - viewListMetrics.maxHeight
                            let viewListOffsetOverflow = max(0.0, viewListExpandDistance)
                            resetContentOffset = viewListOffsetOverflow <= 0.0
                            //print("viewListOffsetOverflow: \(viewListOffsetOverflow)")
                            
                            if verticalPanState.accumulatedOffset < -(viewListMetrics.maxHeight - viewListMetrics.minHeight) {
                                verticalPanState.accumulatedOffset = -(viewListMetrics.maxHeight - viewListMetrics.minHeight)
                            }
                        } else {
                            verticalPanState.accumulatedOffset += -overflowY
                            verticalPanState.accumulatedOffset = max(0.0, verticalPanState.accumulatedOffset)
                        }
                        //print("accumulatedOffset: \(verticalPanState.accumulatedOffset)")
                        
                        if verticalPanState.accumulatedOffset > 0.0 || resetContentOffset {
                            scrollView.contentOffset = CGPoint()
                            
                            if self.viewListDisplayState != .hidden, let viewList = self.viewLists[component.slice.item.id], let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                                let eventCycleState = StoryItemSetViewListComponent.EventCycleState()
                                eventCycleState.ignoreScrolling = true
                                viewListView.setEventCycleState(eventCycleState)
                                
                                DispatchQueue.main.async { [weak viewListView] in
                                    guard let viewListView else {
                                        return
                                    }
                                    viewListView.setEventCycleState(nil)
                                }
                            }
                        }
                        
                        verticalPanState.contentOffset = scrollView.contentOffset.y
                        verticalPanState.startContentOffsetY = recognizer.translation(in: self).y
                    } else {
                        if verticalPanState.fraction <= -0.15 {
                            if let activate = self.activateInputWhileDragging() {
                                recognizer.state = .cancelled
                                
                                activate()
                            }
                        }
                    }
                    
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if let verticalPanState = self.verticalPanState {
                    self.verticalPanState = nil
                    
                    let velocity = recognizer.velocity(in: self)
                    let translation = recognizer.translation(in: self)
                    
                    if self.viewListDisplayState != .hidden {
                        if verticalPanState.scrollView != nil {
                            if verticalPanState.accumulatedOffset > 0.0 {
                                if verticalPanState.fraction >= 0.3 || (verticalPanState.fraction >= 0.05 && velocity.y >= 150.0) {
                                    if self.isSearchActive {
                                        self.isSearchActive = false
                                        self.viewListDisplayState = .half
                                    } else {
                                        self.viewListDisplayState = .hidden
                                        self.isSearchActive = false
                                    }
                                }
                                
                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else if verticalPanState.accumulatedOffset < 0.0 && self.targetViewListDisplayStateIsFull {
                                if verticalPanState.fraction <= -0.05 || velocity.y <= -80.0 {
                                    self.viewListDisplayState = .full
                                } else {
                                    self.viewListDisplayState = .half
                                }
                                self.state?.updated(transition: verticalPanState.accumulatedOffset == 0.0 ? .immediate : ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else {
                                self.state?.updated(transition: verticalPanState.accumulatedOffset == 0.0 ? .immediate : ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            }
                        } else {
                            if verticalPanState.fraction >= 0.3 || (verticalPanState.fraction >= 0.05 && velocity.y >= 150.0) {
                                self.viewListDisplayState = .hidden
                                self.isSearchActive = false
                            } else if self.targetViewListDisplayStateIsFull {
                                if verticalPanState.fraction <= -0.05 && velocity.y <= -80.0 {
                                    self.viewListDisplayState = .full
                                } else if verticalPanState.fraction >= 0.05 && velocity.y >= -80.0 {
                                    self.viewListDisplayState = .half
                                }
                                self.dismissAllTooltips()
                            }
                            
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    } else {
                        if let visibleItemView = self.visibleItems[component.slice.item.id]?.view.view as? StoryItemContentComponent.View  {
                            visibleItemView.seekEnded()
                        }
                        if translation.y > 200.0 || (translation.y > 5.0 && velocity.y > 200.0) {
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                            self.component?.controller()?.dismiss()
                        } else if translation.y < -200.0 || (translation.y < -100.0 && velocity.y < -100.0) {
                            var displayViewLists = false
                            if component.slice.effectivePeer.id == component.context.account.peerId {
                                displayViewLists = true
                            } else if case let .channel(channel) = component.slice.effectivePeer, channel.flags.contains(.isCreator) || component.slice.additionalPeerData.canViewStats {
                                displayViewLists = true
                            }
                            
                            if displayViewLists {
                                self.viewListDisplayState = self.targetViewListDisplayStateIsFull ? .full : .half
                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                                self.dismissAllTooltips()
                            } else {
                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                                
                                if let activate = self.activateInputWhileDragging() {
                                    activate()
                                }
                            }
                        } else {
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                        }
                    }
                }
            default:
                break
            }
        }
        
        @objc private func closePressed() {
            guard let component = self.component else {
                return
            }
            
            if self.viewListDisplayState != .hidden {
                self.viewListDisplayState = .hidden
                self.isSearchActive = false
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
            } else {
                component.close()
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            
            if self.displayLikeReactions, let reactionContextNode = self.reactionContextNode {
                if let result, result.isDescendant(of: reactionContextNode.view) {
                    return result
                } else {
                    return self.itemsContainerView
                }
            }
            
            if let inputView = self.inputPanel.view, let inputViewHitTest = inputView.hitTest(self.convert(point, to: inputView), with: event) {
                return inputViewHitTest
            }
            
            guard let result else {
                return nil
            }
            
            if result === self.scroller {
                if self.viewListDisplayState == .full {
                    return self
                }
                return self.itemsContainerView
            } else if self.viewListDisplayState == .half && result.isDescendant(of: self.itemsContainerView) {
                return self.itemsContainerView
            }
            
            return result
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
                
                if let component = self.component, let itemLayout = self.itemLayout, itemLayout.contentScaleFraction >= 1.0 - 0.0001 {
                    var index = Int(round(scrollView.contentOffset.x / itemLayout.fullItemScrollDistance))
                    index = max(0, min(index, component.slice.allItems.count - 1))
                    
                    if let currentIndex = component.slice.allItems.firstIndex(where: { $0.id == component.slice.item.id }) {
                        if index != currentIndex {
                            let nextId = component.slice.allItems[index].id
                            component.navigate(.id(nextId))
                        }
                    }
                }
            }
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            if targetContentOffset.pointee.x <= 0.0 || targetContentOffset.pointee.x >= scrollView.contentSize.width - scrollView.bounds.width {
                return
            }
            
            let closestIndex = Int(round(targetContentOffset.pointee.x / itemLayout.fullItemScrollDistance))
            targetContentOffset.pointee.x = CGFloat(closestIndex) * itemLayout.fullItemScrollDistance
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.snapScrolling()
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.snapScrolling()
        }
        
        private func snapScrolling() {
            guard let itemLayout = self.itemLayout else {
                return
            }
            let contentOffset = self.scroller.contentOffset
            if contentOffset.x <= 0.0 || contentOffset.x >= self.scroller.contentSize.width - self.scroller.bounds.width {
                return
            }
            
            let closestIndex = Int(round(contentOffset.x / itemLayout.fullItemScrollDistance))
            self.scroller.setContentOffset(CGPoint(x: CGFloat(closestIndex) * itemLayout.fullItemScrollDistance, y: 0.0), animated: true)
        }
        
        private func isProgressPaused() -> Bool {
            return self.itemProgressMode() == .pause
        }
        
        private func itemProgressMode() -> StoryContentItem.ProgressMode {
            guard let component = self.component else {
                return .pause
            }
            if component.pinchState != nil {
                return .pause
            }
            if self.verticalPanState != nil {
                return .pause
            }
            if self.inputPanelExternalState.isEditing || component.isProgressPaused || self.sendMessageContext.actionSheet != nil || self.sendMessageContext.isViewingAttachedStickers || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil || self.viewListDisplayState != .hidden {
                return .pause
            }
            if let reactionContextNode = self.reactionContextNode, reactionContextNode.isReactionSearchActive {
                return .pause
            }
            if self.privacyController != nil {
                return .pause
            }
            if self.isReporting {
                return .pause
            }
            if self.isEditingStory {
                return .pause
            }
            if self.sendMessageContext.attachmentController != nil {
                return .pause
            }
            if self.sendMessageContext.shareController != nil {
                return .pause
            }
            if self.sendMessageContext.statusController != nil {
                return .pause
            }
            if self.sendMessageContext.lookupController != nil {
                return .pause
            }
            if self.sendMessageContext.menuController != nil {
                return .pause
            }
            if self.sendMessageContext.progressPauseContext.hasExternalController {
                return .pause
            }
            if let navigationController = component.controller()?.navigationController as? NavigationController {
                let topViewController = navigationController.topViewController
                if !(topViewController is StoryContainerScreen) && !(topViewController is MediaEditorScreen) && !(topViewController is ShareWithPeersScreen) && !(topViewController is AttachmentController) {
                    return .pause
                }
            }
            if let captionItem = self.captionItem, captionItem.externalState.isExpanded || captionItem.externalState.isSelectingText {
                return .blurred
            }
            if self.displayLikeReactions {
                return .blurred
            }
            return .play
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var hintAllowSynchronousLoads = true
            if let hint = transition.userData(TransitionHint.self) {
                hintAllowSynchronousLoads = hint.allowSynchronousLoads
            }
            
            var validIds: [StoryId] = []
            var trulyValidIds: [StoryId] = []
            
            let centralItemX = itemLayout.contentFrame.center.x
            
            let currentContentScale = itemLayout.contentMinScale * itemLayout.contentScaleFraction + 1.0 * (1.0 - itemLayout.contentScaleFraction)
            let scaledCentralVisibleItemWidth = itemLayout.contentFrame.width * currentContentScale
            let scaledSideVisibleItemWidth = scaledCentralVisibleItemWidth - 54.0 * itemLayout.contentScaleFraction
            let scaledFullItemScrollDistance = scaledCentralVisibleItemWidth * 0.5 + itemLayout.itemSpacing + scaledSideVisibleItemWidth * 0.5
            let scaledHalfItemScrollDistance = scaledSideVisibleItemWidth * 0.5 + itemLayout.itemSpacing + scaledSideVisibleItemWidth * 0.5
            
            if let centralIndex = component.slice.allItems.firstIndex(where: { $0.id == component.slice.item.id }) {
                let centralItemOffset: CGFloat = itemLayout.fullItemScrollDistance * CGFloat(centralIndex)
                let effectiveScrollingOffsetX = self.scroller.contentOffset.x * itemLayout.contentScaleFraction + centralItemOffset * (1.0 - itemLayout.contentScaleFraction)
                
                for index in 0 ..< component.slice.allItems.count {
                    let item = component.slice.allItems[index]
                    
                    var offsetFraction: CGFloat = -effectiveScrollingOffsetX / itemLayout.fullItemScrollDistance
                    if let viewListPanState = self.viewListPanState {
                        offsetFraction += viewListPanState.fraction
                    }
                    
                    let zeroIndexOffset = index
                    let centerFraction: CGFloat = CGFloat(zeroIndexOffset)
                    
                    let combinedFraction = offsetFraction + centerFraction
                    let combinedFractionSign: CGFloat = combinedFraction < 0.0 ? -1.0 : 1.0
                    
                    let unboundFractionDistanceToCenter: CGFloat = abs(combinedFraction)
                    let fractionDistanceToCenter: CGFloat = min(1.0, unboundFractionDistanceToCenter)
                    let _ = fractionDistanceToCenter
                    
                    var itemPositionX = centralItemX
                    itemPositionX += min(1.0, abs(combinedFraction)) * combinedFractionSign * scaledFullItemScrollDistance
                    itemPositionX += max(0.0, abs(combinedFraction) - 1.0) * combinedFractionSign * scaledHalfItemScrollDistance
                    
                    var logicalItemPositionX = centralItemX
                    logicalItemPositionX += min(1.0, abs(combinedFraction)) * combinedFractionSign * itemLayout.fullItemScrollDistance
                    logicalItemPositionX += max(0.0, abs(combinedFraction) - 1.0) * combinedFractionSign * itemLayout.halfItemScrollDistance
                    
                    var itemVisible = false
                    let itemLeftEdge = logicalItemPositionX - itemLayout.fullItemScrollDistance * 0.5
                    let itemRightEdge = logicalItemPositionX + itemLayout.fullItemScrollDistance * 0.5
                    if itemRightEdge >= -itemLayout.containerSize.width && itemLeftEdge < itemLayout.containerSize.width * 2.0 {
                        itemVisible = true
                    }
                    
                    if itemLayout.contentScaleFraction <= 0.0001 && !self.preparingToDisplayViewList {
                        if index != centralIndex {
                            itemVisible = false
                        }
                    }
                    var reevaluateVisibilityOnCompletion = false
                    if !itemVisible {
                        if transition.animation.isImmediate {
                            continue
                        } else {
                            if self.visibleItems[item.id] == nil {
                                continue
                            } else {
                                reevaluateVisibilityOnCompletion = true
                            }
                        }
                    }
                    
                    let scaleFraction: CGFloat = abs(max(-1.0, min(1.0, combinedFraction)))
                    
                    let minItemScale = itemLayout.contentMinScale * (1.0 - scaleFraction) + itemLayout.sideVisibleItemScale * scaleFraction
                    let itemScale: CGFloat = itemLayout.contentScaleFraction * minItemScale + (1.0 - itemLayout.contentScaleFraction) * 1.0
                    
                    validIds.append(item.id)
                    if itemVisible {
                        trulyValidIds.append(item.id)
                    }
                    
                    var itemTransition = transition
                    let visibleItem: VisibleItem
                    if let current = self.visibleItems[item.id] {
                        visibleItem = current
                    } else {
                        itemTransition = .immediate
                        visibleItem = VisibleItem()
                        self.visibleItems[item.id] = visibleItem
                    }
                    
                    let itemEnvironment = StoryContentItem.Environment(
                        externalState: visibleItem.externalState,
                        sharedState: component.storyItemSharedState,
                        theme: component.theme,
                        presentationProgressUpdated: { [weak self, weak visibleItem] progress, isBuffering, canSwitch in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let visibleItem else {
                                return
                            }
                            if visibleItem.currentProgress != progress || visibleItem.isBuffering != isBuffering || canSwitch {
                                visibleItem.currentProgress = progress
                                
                                let isBufferingUpdated = visibleItem.isBuffering != isBuffering
                                visibleItem.isBuffering = isBuffering
                                
                                if let navigationStripView = self.navigationStrip.view as? MediaNavigationStripComponent.View {
                                    navigationStripView.updateCurrentItemProgress(value: progress, isBuffering: isBuffering, transition: .immediate)
                                }
                                
                                if isBufferingUpdated && !self.isUpdatingComponent {
                                    if !self.isUpdatingComponent {
                                        self.state?.updated(transition: .immediate)
                                    }
                                }
                                
                                if progress >= 1.0 && canSwitch && !visibleItem.requestedNext {
                                    visibleItem.requestedNext = true
                                    
                                    component.navigate(.next)
                                }
                            }
                        },
                        markAsSeen: { [weak self] id in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.markAsSeen(id)
                        }
                    )
                    let _ = visibleItem.view.update(
                        transition: itemTransition.withUserData(StoryItemContentComponent.Hint(
                            synchronousLoad: index == centralIndex && itemLayout.contentScaleFraction <= 0.0001 && hintAllowSynchronousLoads
                        )),
                        component: AnyComponent(StoryItemContentComponent(
                            context: component.context,
                            strings: component.strings,
                            peer: component.slice.effectivePeer,
                            item: item.storyItem,
                            availableReactions: component.availableReactions,
                            entityFiles: item.entityFiles,
                            audioMode: component.audioMode,
                            baseRate: component.storyItemSharedState.baseRate,
                            isVideoBuffering: visibleItem.isBuffering,
                            isCurrent: index == centralIndex,
                            preferHighQuality: component.slice.additionalPeerData.preferHighQualityStories,
                            activateReaction: { [weak self] reactionView, reaction in
                                guard let self else {
                                    return
                                }
                                self.sendMessageContext.activateInlineReaction(view: self, reactionView: reactionView, reaction: reaction)
                            }
                        )),
                        environment: {
                            itemEnvironment
                        },
                        containerSize: itemLayout.contentFrame.size
                    )
                    if let view = visibleItem.view.view {
                        if visibleItem.contentContainerView.superview == nil {
                            self.itemsContainerView.addSubview(visibleItem.contentContainerView)
                            self.itemsContainerView.layer.addSublayer(visibleItem.contentTintLayer)
                            self.itemsContainerView.addSubview(visibleItem.unclippedContainerView)
                            visibleItem.contentContainerView.addSubview(view)
                        }
                        
                        itemTransition.setPosition(view: view, position: CGPoint(x: itemLayout.contentFrame.size.width * 0.5, y: itemLayout.contentFrame.size.height * 0.5))
                        itemTransition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
                        let itemId = item.id
                        itemTransition.setPosition(view: visibleItem.contentContainerView, position: CGPoint(x: itemPositionX, y: itemLayout.contentFrame.center.y), completion: { [weak self] _ in
                            guard reevaluateVisibilityOnCompletion, let self else {
                                return
                            }
                            if !self.trulyValidIds.contains(itemId), let visibleItem = self.visibleItems[itemId] {
                                self.visibleItems.removeValue(forKey: itemId)
                                visibleItem.contentContainerView.removeFromSuperview()
                                visibleItem.unclippedContainerView.removeFromSuperview()
                                visibleItem.contentTintLayer.removeFromSuperlayer()
                                visibleItem.footerPanel?.view?.removeFromSuperview()
                                visibleItem.contentViewsShadowView?.removeFromSuperview()
                            }
                        })
                        itemTransition.setBounds(view: visibleItem.contentContainerView, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
                        itemTransition.setPosition(view: visibleItem.unclippedContainerView, position: CGPoint(x: itemPositionX, y: itemLayout.contentFrame.center.y))
                        itemTransition.setBounds(view: visibleItem.unclippedContainerView, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
                        itemTransition.setPosition(layer: visibleItem.contentTintLayer, position: CGPoint(x: itemPositionX, y: itemLayout.contentFrame.center.y))
                        itemTransition.setBounds(layer: visibleItem.contentTintLayer, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
                        var transform = CATransform3DMakeScale(itemScale, itemScale, 1.0)
                        if let pinchState = component.pinchState {
                            let pinchOffset = CGPoint(
                                x: pinchState.location.x - itemLayout.contentFrame.width / 2.0,
                                y: pinchState.location.y - itemLayout.contentFrame.height / 2.0
                            )
                            transform = CATransform3DTranslate(
                                transform,
                                pinchState.offset.x - pinchOffset.x * (pinchState.scale - 1.0),
                                pinchState.offset.y - pinchOffset.y * (pinchState.scale - 1.0),
                                0.0
                            )
                            transform = CATransform3DScale(transform, pinchState.scale, pinchState.scale, 0.0)
                        }
                        itemTransition.setTransform(view: visibleItem.contentContainerView, transform: transform)
                        itemTransition.setCornerRadius(layer: visibleItem.contentContainerView.layer, cornerRadius: 12.0 * (1.0 / itemScale))
                        
                        itemTransition.setTransform(view: visibleItem.unclippedContainerView, transform: transform)
                        
                        itemTransition.setTransform(layer: visibleItem.contentTintLayer, transform: transform)
                        
                        let countedFractionDistanceToCenter: CGFloat = max(0.0, min(1.0, unboundFractionDistanceToCenter / 3.0))
                        var itemAlpha: CGFloat = 1.0 * (1.0 - countedFractionDistanceToCenter) + 0.0 * countedFractionDistanceToCenter
                        itemAlpha = max(0.0, min(1.0, itemAlpha))
                        
                        let collapsedAlpha = itemAlpha * itemLayout.contentScaleFraction + 0.0 * (1.0 - itemLayout.contentScaleFraction)
                        itemAlpha = (1.0 - fractionDistanceToCenter) * itemAlpha + fractionDistanceToCenter * collapsedAlpha
                        
                        itemAlpha *= (1.0 - itemLayout.contentOverflowFraction)
                        
                        itemTransition.setAlpha(layer: visibleItem.contentTintLayer, alpha: 1.0 - itemAlpha)
                        
                        var itemProgressMode = self.itemProgressMode()
                        if index != centralIndex {
                            itemProgressMode = .pause
                        }

                        if let view = view as? StoryContentItem.View {
                            view.setProgressMode(itemProgressMode)
                        }
                        
                        var isChannel = false
                        var canShare = true
                        var displayFooter = false
                        var displayFooterViews = true
                        if case let .channel(channel) = component.slice.effectivePeer {
                            isChannel = true
                            if channel.addressName == nil {
                                canShare = false
                            }
                            switch channel.info {
                            case .broadcast:
                                displayFooter = true
                            case .group:
                                var canBypassRestrictions = false
                                if let appliedBoosts = component.slice.additionalPeerData.appliedBoosts, let boostsToUnrestrict = component.slice.additionalPeerData.boostsToUnrestrict {
                                    canBypassRestrictions = appliedBoosts >= boostsToUnrestrict
                                }
                                if let bannedSendText = channel.hasBannedPermission(.banSendText, ignoreDefault: canBypassRestrictions), bannedSendText.1 || component.slice.additionalPeerData.boostsToUnrestrict == nil {
                                    displayFooter = true
                                }
                            }
                        } else if component.slice.effectivePeer.id == component.context.account.peerId {
                            displayFooter = true
                        } else if component.slice.item.storyItem.isPending {
                            displayFooter = true
                        } else if case let .user(user) = component.slice.peer, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                            displayFooter = true
                            displayFooterViews = false
                        }
                        if component.slice.item.storyItem.isForwardingDisabled {
                            canShare = false
                        }
                        
                        if displayFooter {
                            let contentViewsShadowView: UIImageView
                            if let current = visibleItem.contentViewsShadowView {
                                contentViewsShadowView = current
                            } else {
                                contentViewsShadowView = UIImageView(image: StoryItemSetContainerComponent.shadowImage)
                                visibleItem.contentViewsShadowView = contentViewsShadowView
                                visibleItem.contentContainerView.addSubview(contentViewsShadowView)
                            }
                            
                            let shadowHeight: CGFloat = 100.0
                            
                            let shadowFrame = CGRect(origin: CGPoint(x: 0.0, y: itemLayout.contentFrame.height - shadowHeight), size: CGSize(width: itemLayout.contentFrame.width, height: shadowHeight))
                            itemTransition.setPosition(view: contentViewsShadowView, position: shadowFrame.center)
                            itemTransition.setBounds(view: contentViewsShadowView, bounds: CGRect(origin: CGPoint(), size: shadowFrame.size))
                            itemTransition.setAlpha(view: contentViewsShadowView, alpha: itemLayout.contentScaleFraction)
                            
                            let footerPanel: ComponentView<Empty>
                            if let current = visibleItem.footerPanel {
                                footerPanel = current
                            } else {
                                footerPanel = ComponentView()
                                visibleItem.footerPanel = footerPanel
                            }
                            
                            let singleDistanceToCenter = max(0.0, min(1.0, abs(unboundFractionDistanceToCenter)))
                            
                            var footerExpandFraction = itemLayout.contentScaleFraction
                            footerExpandFraction = footerExpandFraction.interpolate(to: 1.0, amount: singleDistanceToCenter)
                            
                            let footerSize = footerPanel.update(
                                transition: itemTransition,
                                component: AnyComponent(StoryFooterPanelComponent(
                                    context: component.context,
                                    theme: component.theme,
                                    strings: component.strings,
                                    peer: component.slice.effectivePeer,
                                    storyItem: item.storyItem,
                                    myReaction: item.storyItem.myReaction.flatMap { value -> StoryFooterPanelComponent.MyReaction? in
                                        var centerAnimation: TelegramMediaFile?
                                        var animationFileId: Int64?
                                        
                                        switch value {
                                        case .builtin:
                                            if let availableReactions = component.availableReactions {
                                                for availableReaction in availableReactions.reactionItems {
                                                    if availableReaction.reaction.rawValue == value {
                                                        centerAnimation = availableReaction.listAnimation._parse()
                                                        break
                                                    }
                                                }
                                            }
                                        case let .custom(fileId):
                                            animationFileId = fileId
                                        case .stars:
                                            if let availableReactions = component.availableReactions {
                                                for availableReaction in availableReactions.reactionItems {
                                                    if availableReaction.reaction.rawValue == value {
                                                        centerAnimation = availableReaction.listAnimation._parse()
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if animationFileId == nil && centerAnimation == nil {
                                            return nil
                                        }
                                        
                                        return StoryFooterPanelComponent.MyReaction(reaction: value, file: centerAnimation, animationFileId: animationFileId)
                                    },
                                    isChannel: isChannel,
                                    canViewChannelStats: component.slice.additionalPeerData.canViewStats,
                                    canShare: canShare,
                                    externalViews: nil,
                                    displayViews: displayFooterViews,
                                    expandFraction: footerExpandFraction,
                                    expandViewStats: { [weak self] in
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        if self.viewLists[component.slice.item.id] == nil {
                                            return
                                        }
                                        
                                        if self.viewListDisplayState == .hidden {
                                            self.viewListDisplayState = .half
                                            
                                            self.preparingToDisplayViewList = true
                                            self.updateScrolling(transition: .immediate)
                                            self.preparingToDisplayViewList = false
                                            
                                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                            
                                            self.dismissAllTooltips()
                                        }
                                    },
                                    deleteAction: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        
                                        self.performDeleteAction()
                                    },
                                    moreAction: { [weak self] sourceView, gesture in
                                        guard let self else {
                                            return
                                        }
                                        self.performMoreAction(sourceView: sourceView, gesture: gesture)
                                    },
                                    likeAction: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.performLikeAction()
                                    },
                                    forwardAction: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.sendMessageContext.performShareAction(view: self)
                                    },
                                    repostAction: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.openStoryEditing(repost: true)
                                    },
                                    cancelUploadAction: { [weak self] in
                                        guard let self, let component = self.component, let controller = self.component?.controller() as? StoryContainerScreen else {
                                            return
                                        }
                                        component.context.engine.messages.cancelStoryUpload(stableId: component.slice.item.storyItem.id)
                                        controller.dismissWithoutTransitionOut()
                                    }
                                )),
                                environment: {},
                                containerSize: CGSize(width: itemLayout.containerSize.width, height: 200.0)
                            )
                            if let footerPanelView = footerPanel.view {
                                if footerPanelView.superview == nil {
                                    self.componentContainerView.addSubview(footerPanelView)
                                }
                                
                                var footerPanelY: CGFloat = self.itemsContainerView.frame.minY + itemLayout.contentFrame.center.y + itemLayout.contentFrame.height * 0.5 * itemScale
                                footerPanelY += (1.0 - footerExpandFraction) * (10.0) + footerExpandFraction * (-41.0)
                                
                                let footerPanelMinScale: CGFloat = (1.0 - scaleFraction) + (itemLayout.sideVisibleItemScale / itemLayout.contentMinScale) * scaleFraction
                                let footerPanelScale = itemLayout.contentScaleFraction * footerPanelMinScale + 1.0 * (1.0 - itemLayout.contentScaleFraction)
                                
                                footerPanelY += (footerSize.height - footerSize.height * footerPanelScale) * 0.5
                                
                                let footerPanelFrame = CGRect(origin: CGPoint(x: itemPositionX - footerSize.width * 0.5, y: footerPanelY), size: footerSize)
                                
                                itemTransition.setPosition(view: footerPanelView, position: footerPanelFrame.center)
                                itemTransition.setBounds(view: footerPanelView, bounds: CGRect(origin: CGPoint(), size: footerPanelFrame.size))
                                itemTransition.setScale(view: footerPanelView, scale: footerPanelScale)
                                
                                var footerAlpha: CGFloat = 1.0 - itemLayout.contentOverflowFraction
                                
                                let minFooterAlpha: CGFloat = 1.0 - fractionDistanceToCenter
                                footerAlpha = footerAlpha * itemLayout.contentScaleFraction + minFooterAlpha * (1.0 - itemLayout.contentScaleFraction)
                                
                                if component.hideUI || self.isEditingStory {
                                    footerAlpha = 0.0
                                }
                                
                                footerAlpha *= itemAlpha
                                
                                itemTransition.setAlpha(view: footerPanelView, alpha: footerAlpha)
                            }
                        } else if let footerPanel = visibleItem.footerPanel {
                            visibleItem.footerPanel = nil
                            footerPanel.view?.removeFromSuperview()
                        }
                    }
                }
            }
            
            self.trulyValidIds = trulyValidIds
            
            var removeIds: [StoryId] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    visibleItem.contentContainerView.removeFromSuperview()
                    visibleItem.unclippedContainerView.removeFromSuperview()
                    visibleItem.contentTintLayer.removeFromSuperlayer()
                    visibleItem.footerPanel?.view?.removeFromSuperview()
                    visibleItem.contentViewsShadowView?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func updateIsProgressPaused() {
            let progressMode = self.itemProgressMode()
            var centralId: StoryId?
            if let component = self.component {
                centralId = component.slice.item.id
            }
            
            for (id, visibleItem) in self.visibleItems {
                if let view = visibleItem.view.view {
                    if let view = view as? StoryContentItem.View {
                        var itemMode = progressMode
                        if id != centralId {
                            itemMode = .pause
                        }
                        view.setProgressMode(itemMode)
                    }
                }
            }
        }
        
        func inFocusUpdated(isInFocus: Bool) {
            self.updateIsProgressPaused()
        }
        
        func activateInput() -> Bool {
            guard let component = self.component else {
                return false
            }
            
            var displayViewLists = false
            if component.slice.effectivePeer.id == component.context.account.peerId {
                displayViewLists = true
            } else if case let .channel(channel) = component.slice.effectivePeer, channel.flags.contains(.isCreator) || component.slice.additionalPeerData.canViewStats {
                displayViewLists = true
            }
            
            if displayViewLists {
                self.viewListDisplayState = .half
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                
                self.dismissAllTooltips()
                
                return true
            } else {
                var canReply = false
                if case .user = component.slice.effectivePeer {
                    canReply = true
                    
                    if component.slice.effectivePeer.id == component.context.account.peerId {
                        canReply = false
                    } else if component.slice.effectivePeer.isService {
                        canReply = false
                    } else if case .unsupported = component.slice.item.storyItem.media {
                        canReply = false
                    }
                }
                
                if canReply {
                    if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                        inputPanelView.activateInput()
                        return false
                    }
                }
            }
            return false
        }
        
        func activateInputWhileDragging() -> (() -> Void)? {
            guard let component = self.component else {
                return nil
            }
            
            var canReply = false
            if case .user = component.slice.effectivePeer {
                canReply = true
                
                if component.slice.effectivePeer.id == component.context.account.peerId {
                    canReply = false
                } else if component.slice.effectivePeer.isService {
                    canReply = false
                } else if case .unsupported = component.slice.item.storyItem.media {
                    canReply = false
                }
            }
            
            if canReply {
                if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                    return { [weak self, weak inputPanelView] in
                        guard let self, let inputPanelView else {
                            return
                        }
                        
                        if self.displayLikeReactions {
                            self.displayLikeReactions = false
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                        }
                        
                        inputPanelView.activateInput()
                    }
                }
            }
            
            return nil
        }
        
        func animateIn(transitionIn: StoryContainerScreen.TransitionIn, completion: @escaping () -> Void) {
            if let inputPanelView = self.inputPanel.view {
                inputPanelView.layer.animatePosition(
                    from: CGPoint(x: 0.0, y: self.bounds.height - inputPanelView.frame.minY),
                    to: CGPoint(),
                    duration: 0.48,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    additive: true
                )
                inputPanelView.layer.animateAlpha(from: 0.0, to: inputPanelView.alpha, duration: 0.28)
            }
            for (_, viewList) in self.viewLists {
                if let viewListView = viewList.view.view {
                    viewListView.layer.animatePosition(
                        from: CGPoint(x: 0.0, y: self.bounds.height - self.controlsContainerView.frame.maxY),
                        to: CGPoint(),
                        duration: 0.3,
                        timingFunction: kCAMediaTimingFunctionSpring,
                        additive: true
                    )
                    viewListView.layer.animateAlpha(from: 0.0, to: viewListView.alpha, duration: 0.28)
                }
            }
            if let captionItemView = self.captionItem?.view.view {
                captionItemView.layer.animatePosition(
                    from: CGPoint(x: 0.0, y: self.bounds.height - captionItemView.frame.minY),
                    to: CGPoint(),
                    duration: 0.25,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    additive: true
                )
                captionItemView.layer.animateAlpha(from: 0.0, to: captionItemView.alpha, duration: 0.28)
            }
            
            if let component = self.component, let sourceView = transitionIn.sourceView, let visibleItem = self.visibleItems[component.slice.item.id] {
                let contentContainerView = visibleItem.contentContainerView
                let unclippedContainerView = visibleItem.unclippedContainerView
                
                if let footerPanelView = visibleItem.footerPanel?.view {
                    footerPanelView.layer.animatePosition(
                        from: CGPoint(x: 0.0, y: self.bounds.height - footerPanelView.frame.minY),
                        to: CGPoint(),
                        duration: 0.48,
                        timingFunction: kCAMediaTimingFunctionSpring,
                        additive: true
                    )
                    footerPanelView.layer.animateAlpha(from: 0.0, to: footerPanelView.alpha, duration: 0.28)
                }
                
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                if let moreButtonView = self.moreButton.view {
                    moreButtonView.layer.animateAlpha(from: 0.0, to: moreButtonView.alpha, duration: 0.25)
                }
                if let soundButtonView = self.soundButton.view {
                    soundButtonView.layer.animateAlpha(from: 0.0, to: soundButtonView.alpha, duration: 0.25)
                }
                if let closeFriendIcon = self.privacyIcon?.view {
                    closeFriendIcon.layer.animateAlpha(from: 0.0, to: closeFriendIcon.alpha, duration: 0.25)
                }
                self.closeButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                    completion()
                })
                
                self.topContentGradientView.layer.animateAlpha(from: 0.0, to: self.topContentGradientView.alpha, duration: 0.25)
                
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - contentContainerView.frame.minX, y: sourceLocalFrame.minY - contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                if let leftInfoView = self.leftInfoItem?.view.view {
                    if transitionIn.sourceIsAvatar {
                        let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: CGPoint(x: innerSourceLocalFrame.center.x - leftInfoView.layer.position.x, y: innerSourceLocalFrame.center.y - leftInfoView.layer.position.y), to: CGPoint(), elevation: 0.0, duration: 0.3, curve: .spring, reverse: false)
                        leftInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", additive: true)
                        
                        leftInfoView.layer.animateScale(from: innerSourceLocalFrame.width / leftInfoView.bounds.width, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        leftInfoView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
                
                contentContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: contentContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                contentContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: contentContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                contentContainerView.layer.animate(
                    from: transitionIn.sourceCornerRadius as NSNumber,
                    to: contentContainerView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
                unclippedContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: contentContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                unclippedContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: contentContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                
                self.controlsContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.controlsContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.controlsContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                
                self.controlsClippingView.layer.animatePosition(from: sourceLocalFrame.center, to: self.controlsClippingView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsClippingView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.controlsClippingView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsClippingView.layer.animate(
                    from: transitionIn.sourceCornerRadius as NSNumber,
                    to: self.controlsClippingView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
                self.controlsNavigationClippingView.layer.animatePosition(from: sourceLocalFrame.center, to: self.controlsNavigationClippingView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsNavigationClippingView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.controlsNavigationClippingView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                
                if let component = self.component, let visibleItemView = self.visibleItems[component.slice.item.id]?.view.view {
                    let innerScale = innerSourceLocalFrame.width / visibleItemView.bounds.width
                    let innerFromFrame = CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: CGSize(width: innerSourceLocalFrame.width, height: visibleItemView.bounds.height * innerScale))
                    
                    visibleItemView.layer.animatePosition(
                        from: CGPoint(
                            x: innerFromFrame.midX,
                            y: innerFromFrame.midY
                        ),
                        to: visibleItemView.layer.position,
                        duration: 0.3,
                        timingFunction: kCAMediaTimingFunctionSpring
                    )
                    visibleItemView.layer.animateScale(from: innerScale, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            } else {
                completion()
            }
        }
        
        func animateOut(transitionOut: StoryContainerScreen.TransitionOut, transitionCloneMasterView: UIView, completion: @escaping () -> Void) {
            func fixScale(layer: CALayer) {
                layer.rasterizationScale = UIScreenScale
                
                for sublayer in layer.sublayers ?? [] {
                    fixScale(layer: sublayer)
                }
            }
            
            var cleanups: [() -> Void] = []
            
            self.isAnimatingOut = true
            
            self.sendMessageContext.animateOut(bounds: self.bounds)
            
            self.sendMessageContext.tooltipScreen?.dismiss()
            self.sendMessageContext.tooltipScreen = nil
            
            self.contextController?.dismiss()
            self.contextController = nil
            
            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                self.standaloneReactionAnimation = nil
                standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                    standaloneReactionAnimation?.view.removeFromSuperview()
                })
            }
            
            if let inputPanelView = self.inputPanel.view {
                inputPanelView.layer.animatePosition(
                    from: CGPoint(),
                    to: CGPoint(x: 0.0, y: self.bounds.height - inputPanelView.frame.minY),
                    duration: 0.3,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    removeOnCompletion: false,
                    additive: true
                )
                inputPanelView.layer.animateAlpha(from: inputPanelView.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            if let inputPanelBackground = self.inputPanelBackground.view {
                inputPanelBackground.layer.animatePosition(
                    from: CGPoint(),
                    to: CGPoint(x: 0.0, y: self.bounds.height - inputPanelBackground.frame.minY),
                    duration: 0.3,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    removeOnCompletion: false,
                    additive: true
                )
                inputPanelBackground.layer.animateAlpha(from: inputPanelBackground.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            for (_, viewList) in self.viewLists {
                if let viewListView = viewList.view.view {
                    viewListView.layer.animatePosition(
                        from: CGPoint(),
                        to: CGPoint(x: 0.0, y: self.bounds.height - self.controlsContainerView.frame.maxY),
                        duration: 0.3,
                        timingFunction: kCAMediaTimingFunctionSpring,
                        removeOnCompletion: false,
                        additive: true
                    )
                    viewListView.layer.animateAlpha(from: viewListView.alpha, to: 0.0, duration: 0.28, removeOnCompletion: false)
                }
            }
            if let captionItemView = self.captionItem?.view.view {
                captionItemView.layer.animatePosition(
                    from: CGPoint(),
                    to: CGPoint(x: 0.0, y: self.bounds.height - captionItemView.frame.minY),
                    duration: 0.3,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    removeOnCompletion: false,
                    additive: true
                )
                captionItemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            
            if let reactionContextNode = self.reactionContextNode {
                self.reactionContextNode = nil
                reactionContextNode.layer.animateAlpha(from: reactionContextNode.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak reactionContextNode] _ in
                    reactionContextNode?.view.removeFromSuperview()
                })
            }
            if let disappearingReactionContextNode = self.disappearingReactionContextNode {
                self.disappearingReactionContextNode = nil
                disappearingReactionContextNode.layer.animateAlpha(from: disappearingReactionContextNode.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak disappearingReactionContextNode] _ in
                    disappearingReactionContextNode?.view.removeFromSuperview()
                })
            }
            
            if let component = self.component, let sourceView = transitionOut.destinationView, let visibleItem = self.visibleItems[component.slice.item.id] {
                if let footerPanelView = visibleItem.footerPanel?.view {
                    footerPanelView.layer.animatePosition(
                        from: CGPoint(),
                        to: CGPoint(x: 0.0, y: self.bounds.height - footerPanelView.frame.minY),
                        duration: 0.3,
                        timingFunction: kCAMediaTimingFunctionSpring,
                        removeOnCompletion: false,
                        additive: true
                    )
                    footerPanelView.layer.animateAlpha(from: footerPanelView.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
                }
                
                let contentContainerView = visibleItem.contentContainerView
                let unclippedContainerView = visibleItem.unclippedContainerView
                
                let sourceLocalFrame = sourceView.convert(transitionOut.destinationRect, to: self.componentContainerView)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - contentContainerView.frame.minX, y: sourceLocalFrame.minY - contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                let contentSourceFrame = contentContainerView.frame
                
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let moreButtonView = self.moreButton.view {
                    moreButtonView.layer.animateAlpha(from: moreButtonView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let soundButtonView = self.soundButton.view {
                    soundButtonView.layer.animateAlpha(from: soundButtonView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let closeFriendIconView = self.privacyIcon?.view {
                    closeFriendIconView.layer.animateAlpha(from: closeFriendIconView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let captionView = self.captionItem?.view.view {
                    captionView.layer.animateAlpha(from: captionView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                self.closeButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                self.topContentGradientView.layer.animateAlpha(from: self.topContentGradientView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                
                if let leftInfoView = self.leftInfoItem?.view.view {
                    if transitionOut.destinationIsAvatar {
                        let transitionView = transitionOut.transitionView
                        
                        var transitionViewsImpl: [UIView] = []
                        
                        if let transitionViewImpl = transitionView?.makeView() {
                            fixScale(layer: transitionViewImpl.layer)
                            transitionViewsImpl.append(transitionViewImpl)
                            
                            let transitionSourceContainerView = UIView(frame: self.bounds)
                            transitionSourceContainerView.isUserInteractionEnabled = false
                            self.componentContainerView.insertSubview(transitionSourceContainerView, aboveSubview: self.itemsContainerView)
                            
                            transitionSourceContainerView.addSubview(transitionViewImpl)
                            
                            if let insertCloneTransitionView = transitionView?.insertCloneTransitionView {
                                if let transitionCloneViewImpl = transitionView?.makeView() {
                                    fixScale(layer: transitionCloneViewImpl.layer)
                                    transitionViewsImpl.append(transitionCloneViewImpl)
                                    
                                    transitionCloneMasterView.isUserInteractionEnabled = false
                                    let transitionCloneMasterGlobalFrame = transitionCloneMasterView.convert(transitionCloneMasterView.bounds, to: nil)
                                    insertCloneTransitionView(transitionCloneMasterView)
                                    if let newParentView = transitionCloneMasterView.superview {
                                        newParentView.frame = newParentView.convert(transitionCloneMasterGlobalFrame, from: nil)
                                    }
                                    
                                    self.transitionCloneContainerView.addSubview(transitionCloneViewImpl)
                                    
                                    transitionSourceContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, removeOnCompletion: false)
                                    self.transitionCloneContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                                    
                                    cleanups.append({ [weak transitionCloneMasterView] in
                                        transitionCloneMasterView?.removeFromSuperview()
                                    })
                                }
                            }
                            
                            let rightInfoSourceFrame = leftInfoView.convert(leftInfoView.bounds, to: self)
                            let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: sourceLocalFrame.center, to: rightInfoSourceFrame.center, elevation: 0.0, duration: 0.3, curve: .spring, reverse: true)
                            
                            for transitionViewImpl in transitionViewsImpl {
                                transitionViewImpl.frame = rightInfoSourceFrame
                                transitionViewImpl.alpha = 0.0
                                transitionView?.updateView(transitionViewImpl, StoryContainerScreen.TransitionState(
                                    sourceSize: rightInfoSourceFrame.size,
                                    destinationSize: sourceLocalFrame.size,
                                    progress: 0.0
                                ), .immediate)
                            }
                            
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            
                            for transitionViewImpl in transitionViewsImpl {
                                transitionViewImpl.alpha = 1.0
                                transitionViewImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                            }
                            
                            contentContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                            unclippedContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                            self.controlsContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                            self.controlsClippingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                            self.controlsNavigationClippingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                            
                            for transitionViewImpl in transitionViewsImpl {
                                transition.setFrame(view: transitionViewImpl, frame: sourceLocalFrame)
                            }
                            
                            for transitionViewImpl in transitionViewsImpl {
                                transitionViewImpl.layer.position = positionKeyframes[positionKeyframes.count - 1]
                                transitionViewImpl.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", removeOnCompletion: false, additive: false)
                                transitionViewImpl.layer.animateBounds(from: CGRect(origin: CGPoint(), size: rightInfoSourceFrame.size), to: CGRect(origin: CGPoint(), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                                
                                transitionView?.updateView(transitionViewImpl, StoryContainerScreen.TransitionState(
                                    sourceSize: rightInfoSourceFrame.size,
                                    destinationSize: sourceLocalFrame.size,
                                    progress: 1.0
                                ), transition)
                            }
                        }
                        
                        let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: innerSourceLocalFrame.center, to: leftInfoView.layer.position, elevation: 0.0, duration: 0.3, curve: .spring, reverse: true)
                        leftInfoView.layer.position = positionKeyframes[positionKeyframes.count - 1]
                        leftInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", removeOnCompletion: false, additive: false)
                        
                        leftInfoView.layer.animateScale(from: 1.0, to: innerSourceLocalFrame.width / leftInfoView.bounds.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                }
                
                contentContainerView.layer.animatePosition(from: contentContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                contentContainerView.layer.animateBounds(from: contentContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                contentContainerView.layer.animate(
                    from: contentContainerView.layer.cornerRadius as NSNumber,
                    to: transitionOut.destinationCornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                unclippedContainerView.layer.animatePosition(from: contentContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                unclippedContainerView.layer.animateBounds(from: contentContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                self.controlsContainerView.layer.animatePosition(from: self.controlsContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsContainerView.layer.animateBounds(from: self.controlsContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                self.controlsClippingView.layer.animatePosition(from: self.controlsClippingView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsClippingView.layer.animateBounds(from: self.controlsClippingView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsClippingView.layer.animate(
                    from: self.controlsClippingView.layer.cornerRadius as NSNumber,
                    to: transitionOut.destinationCornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                self.controlsNavigationClippingView.layer.animatePosition(from: self.controlsNavigationClippingView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsNavigationClippingView.layer.animateBounds(from: self.controlsNavigationClippingView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                self.overlayContainerView.clipsToBounds = true
                let overlayToFrame = sourceLocalFrame
                let overlayToBounds = CGRect(origin: CGPoint(x: overlayToFrame.minX, y: overlayToFrame.minY), size: overlayToFrame.size)
                self.overlayContainerView.layer.animatePosition(from: CGPoint(), to: overlayToFrame.center.offsetBy(dx: -self.overlayContainerView.center.x, dy: -self.overlayContainerView.center.y), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                self.overlayContainerView.layer.animateBounds(from: self.overlayContainerView.bounds, to: overlayToBounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                
                if !transitionOut.destinationIsAvatar {
                    let transitionView = transitionOut.transitionView
                    
                    var transitionViewsImpl: [UIView] = []
                    
                    if let transitionViewImpl = transitionView?.makeView() {
                        fixScale(layer: transitionViewImpl.layer)
                        transitionViewsImpl.append(transitionViewImpl)
                        
                        let transitionSourceContainerView = UIView(frame: self.bounds)
                        transitionSourceContainerView.isUserInteractionEnabled = false
                        self.componentContainerView.insertSubview(transitionSourceContainerView, belowSubview: self.itemsContainerView)
                        
                        transitionSourceContainerView.addSubview(transitionViewImpl)
                        
                        if let insertCloneTransitionView = transitionView?.insertCloneTransitionView {
                            if let transitionCloneViewImpl = transitionView?.makeView() {
                                fixScale(layer: transitionCloneViewImpl.layer)
                                transitionViewsImpl.append(transitionCloneViewImpl)
                                
                                transitionCloneMasterView.isUserInteractionEnabled = false
                                let transitionCloneMasterGlobalFrame = transitionCloneMasterView.convert(transitionCloneMasterView.bounds, to: nil)
                                insertCloneTransitionView(transitionCloneMasterView)
                                if let newParentView = transitionCloneMasterView.superview {
                                    transitionCloneMasterView.frame = newParentView.convert(transitionCloneMasterGlobalFrame, from: nil)
                                }
                                
                                self.transitionCloneContainerView.addSubview(transitionCloneViewImpl)
                                
                                transitionSourceContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, removeOnCompletion: false)
                                self.transitionCloneContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                                
                                cleanups.append({ [weak transitionCloneContainerView] in
                                    transitionCloneContainerView?.removeFromSuperview()
                                })
                            }
                        }
                        
                        for transitionViewImpl in transitionViewsImpl {
                            transitionViewImpl.frame = contentSourceFrame
                            transitionViewImpl.alpha = 0.0
                            transitionView?.updateView(transitionViewImpl, StoryContainerScreen.TransitionState(
                                sourceSize: contentSourceFrame.size,
                                destinationSize: sourceLocalFrame.size,
                                progress: 0.0
                            ), .immediate)
                        }
                        
                        let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                        
                        for transitionViewImpl in transitionViewsImpl {
                            transitionViewImpl.alpha = 1.0
                            transitionViewImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                        contentContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        unclippedContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        self.controlsContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        self.controlsClippingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        self.controlsNavigationClippingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        
                        for transitionViewImpl in transitionViewsImpl {
                            transition.setFrame(view: transitionViewImpl, frame: sourceLocalFrame)
                            transitionView?.updateView(transitionViewImpl, StoryContainerScreen.TransitionState(
                                sourceSize: contentSourceFrame.size,
                                destinationSize: sourceLocalFrame.size,
                                progress: 1.0
                            ), transition)
                        }
                    }
                }
                
                if let component = self.component, let visibleItemView = self.visibleItems[component.slice.item.id]?.view.view {
                    let innerScale = innerSourceLocalFrame.width / visibleItemView.bounds.width
                    
                    var adjustedInnerSourceLocalFrame = innerSourceLocalFrame
                    if !transitionOut.destinationIsAvatar {
                        let innerSourceSize = visibleItemView.bounds.size.aspectFilled(adjustedInnerSourceLocalFrame.size)
                        adjustedInnerSourceLocalFrame.origin.y += (adjustedInnerSourceLocalFrame.height - innerSourceSize.height) * 0.5
                        adjustedInnerSourceLocalFrame.size.height = innerSourceSize.height
                    }
                    
                    let innerFromFrame = CGRect(origin: CGPoint(x: adjustedInnerSourceLocalFrame.minX, y: adjustedInnerSourceLocalFrame.minY), size: CGSize(width: adjustedInnerSourceLocalFrame.width, height: visibleItemView.bounds.height * innerScale))
                    
                    visibleItemView.layer.animatePosition(
                        from: visibleItemView.layer.position,
                        to: CGPoint(
                            x: innerFromFrame.midX,
                            y: innerFromFrame.midY
                        ),
                        duration: 0.3,
                        timingFunction: kCAMediaTimingFunctionSpring,
                        removeOnCompletion: false
                    )
                    visibleItemView.layer.animateScale(from: 1.0, to: innerScale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            }
            
            self.closeButton.layer.animateScale(from: 1.0, to: 0.001, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                for cleanup in cleanups {
                    cleanup()
                }
                cleanups.removeAll()
                completion()
            })
        }
        
        func maybeDisplayReactionTooltip() {
            guard let component = self.component else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, let likeButtonView = inputPanelView.likeButtonView else {
                return
            }
            if inputPanelView.isHidden || inputPanelView.alpha == 0.0 {
                return
            }
            if !likeButtonView.isDescendant(of: self) {
                return
            }
            if likeButtonView.isHidden {
                return
            }
            if likeButtonView.alpha == 0.0 {
                return
            }
            if component.slice.effectivePeer.isService {
                return
            } else if case .unsupported = component.slice.item.storyItem.media {
                return
            }
            
            let tooltipScreen = TooltipScreen(
                account: component.context.account,
                sharedContext: component.context.sharedContext,
                text: .markdown(text: component.strings.Story_LongTapForMoreReactions),
                balancedTextLayout: true,
                style: .customBlur(component.theme.rootController.navigationBar.blurredBackgroundColor, 0.0),
                arrowStyle: .small,
                location: TooltipScreen.Location.point(likeButtonView.convert(likeButtonView.bounds, to: nil).offsetBy(dx: 0.0, dy: 0.0), .bottom),
                displayDuration: .infinite,
                inset: 5.0,
                shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: true)
                }
            )
            tooltipScreen.willBecomeDismissed = { [weak self] _ in
                guard let self else {
                    return
                }
                self.sendMessageContext.tooltipScreen = nil
                self.updateIsProgressPaused()
            }
            self.sendMessageContext.tooltipScreen?.dismiss()
            self.sendMessageContext.tooltipScreen = tooltipScreen
            self.updateIsProgressPaused()
            component.controller()?.present(tooltipScreen, in: .current)
            
            let _ = ApplicationSpecificNotice.setDisplayStoryReactionTooltip(accountManager: component.context.sharedContext.accountManager).startStandalone()
        }
        
        func saveDraft() {
            guard let component = self.component else {
                return
            }
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                let previousInput = inputPanelView.getSendMessageInput()
                switch previousInput {
                case let .text(value):
                    component.storyItemSharedState.replyDrafts[component.slice.item.id] = value
                }
            }
        }
        
        func update(component: StoryItemSetContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdatingComponent = true
            defer {
                self.isUpdatingComponent = false
            }
            
            let isFirstTime = self.component == nil
            
            let startTime1 = CFAbsoluteTimeGetCurrent()
                        
            if self.component == nil {
                self.sendMessageContext.setup(context: component.context, view: self, inputPanelExternalState: self.inputPanelExternalState, keyboardInputData: component.keyboardInputData)
                
                /*#if DEBUG
                class Target: NSObject {
                    let f: () -> Void
                    
                    init(_ f: @escaping () -> Void) {
                        self.f = f
                    }
                    
                    @objc func event() {
                        self.f()
                    }
                }
                let displayLink = CADisplayLink(target: Target { [weak self] in
                    self?.state?.updated(transition: .easeInOut(duration: 0.3))
                }, selector: #selector(Target.event))
                displayLink.add(to: .main, forMode: .common)
                #endif*/
            }
            
            let previousComponent = self.component
            
            var isFirstItem = false
            var itemChanged = false
            var resetInputContents: MessageInputPanelComponent.SendMessageInput?
            if self.component?.slice.item.id != component.slice.item.id {
                isFirstItem = self.component == nil
                itemChanged = self.component != nil
                self.initializedOffset = false
                
                resetInputContents = .text(NSAttributedString())
                
                self.saveDraft()
                if let draft = component.storyItemSharedState.replyDrafts[component.slice.item.id] {
                    resetInputContents = .text(draft)
                }
                component.storyItemSharedState.replyDrafts.removeValue(forKey: component.slice.item.id)
                
                if let tooltipScreen = self.sendMessageContext.tooltipScreen {
                    if let tooltipScreen = tooltipScreen as? UndoOverlayController, let tag = tooltipScreen.tag as? String, tag == "no_auto_dismiss" {
                    } else {
                        tooltipScreen.dismiss()
                    }
                }
                
                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                    self.standaloneReactionAnimation = nil
                    standaloneReactionAnimation.view.removeFromSuperview()
                }
                self.displayLikeReactions = false
                if let reactionContextNode = self.reactionContextNode {
                    self.reactionContextNode = nil
                    
                    let reactionTransition = ComponentTransition.immediate
                    reactionTransition.setAlpha(view: reactionContextNode.view, alpha: 0.0, completion: { [weak reactionContextNode] _ in
                        reactionContextNode?.view.removeFromSuperview()
                    })
                }
                if let disappearingReactionContextNode = self.disappearingReactionContextNode {
                    self.disappearingReactionContextNode = nil
                    disappearingReactionContextNode.view.removeFromSuperview()
                }
            }
            var itemsTransition = transition
            var resetScrollingOffsetWithItemTransition = false
            if let animateNextNavigationId = self.animateNextNavigationId, animateNextNavigationId == component.slice.item.id {
                self.animateNextNavigationId = nil
                self.viewListPanState = nil
                self.isCompletingViewListPan = true
                itemsTransition = transition.withAnimation(.curve(duration: 0.3, curve: .spring))
                itemsTransition.attachAnimation(view: self, id: "isCompletingViewListPan", completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    if self.isCompletingViewListPan {
                        self.isCompletingViewListPan = false
                        self.state?.updated(transition: .immediate)
                    }
                })
                resetScrollingOffsetWithItemTransition = true
            }
            
            if let awaitingSwitchToId = self.awaitingSwitchToId, awaitingSwitchToId.to == component.slice.item.id {
                self.awaitingSwitchToId = nil
                self.viewListPanState = nil
                self.isCompletingViewListPan = true
                itemsTransition = transition.withAnimation(.curve(duration: 0.3, curve: .spring))
                itemsTransition.attachAnimation(view: self, id: "isCompletingViewListPan", completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    if self.isCompletingViewListPan {
                        self.isCompletingViewListPan = false
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            if self.bottomContentGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 10
                let baseAlpha: CGFloat = 0.7
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.5)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.bottomContentGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
                self.bottomContentGradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                
                self.bottomContentGradientLayer.locations = locations
                self.bottomContentGradientLayer.colors = colors
                self.bottomContentGradientLayer.type = .axial
                
                self.contentDimView.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
            }
            
            let wasPanning = self.component?.isPanning ?? false
            self.component = component
            self.state = state
            
            var dismissPanOffset: CGFloat = 0.0
            var dismissPanScale: CGFloat = 1.0
            var verticalPanFraction: CGFloat = 0.0
            var dismissFraction: CGFloat = 0.0
            
            if let verticalPanState = self.verticalPanState, self.viewListDisplayState == .hidden {
                dismissFraction = max(0.0, min(1.0, verticalPanState.fraction))
                verticalPanFraction = max(0.0, min(1.0, -verticalPanState.fraction))
                
                dismissPanOffset = dismissFraction * availableSize.height
                dismissPanScale = 1.0 * (1.0 - dismissFraction) + 0.6 * dismissFraction
            }
            
            component.externalState.dismissFraction = dismissFraction
            
            let startTime2 = CFAbsoluteTimeGetCurrent()
            
            transition.setPosition(view: self.componentContainerView, position: CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5 + dismissPanOffset))
            transition.setBounds(view: self.componentContainerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            transition.setScale(view: self.componentContainerView, scale: dismissPanScale)
            
            transition.setPosition(view: self.transitionCloneContainerView, position: CGRect(origin: CGPoint(), size: availableSize).center.offsetBy(dx: 0.0, dy: dismissPanOffset))
            transition.setBounds(view: self.transitionCloneContainerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            transition.setPosition(view: self.overlayContainerView, position: CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5 + dismissPanOffset))
            transition.setBounds(view: self.overlayContainerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            transition.setScale(view: self.overlayContainerView, scale: dismissPanScale)
            
            let startTime21 = CFAbsoluteTimeGetCurrent()
            
            var bottomContentInset: CGFloat
            if !component.safeInsets.bottom.isZero {
                bottomContentInset = component.safeInsets.bottom + 1.0
            } else {
                bottomContentInset = 0.0
            }
                        
            var inputPanelAvailableWidth = availableSize.width
            var inputPanelTransition = transition
            if case .regular = component.metrics.widthClass {
                if (self.inputPanelExternalState.isEditing || self.inputPanelExternalState.hasText) {
                    if wasPanning != component.isPanning {
                        inputPanelTransition = .easeInOut(duration: 0.25)
                    }
                    if !component.isPanning {
                        inputPanelAvailableWidth += 200.0
                    }
                }
            }
            if itemChanged {
                inputPanelTransition = .immediate
            }
            
            var canBypassRestrictions = false
            if let appliedBoosts = component.slice.additionalPeerData.appliedBoosts, let boostsToUnrestrict = component.slice.additionalPeerData.boostsToUnrestrict {
                canBypassRestrictions = appliedBoosts >= boostsToUnrestrict
            }
                        
            var isChannel = false
            var isGroup = false
            var showMessageInputPanel = true
            var isGroupCommentRestricted = false
            if case let .channel(channel) = component.slice.effectivePeer {
                switch channel.info {
                case .broadcast:
                    isChannel = true
                    showMessageInputPanel = false
                case .group:
                    if let bannedSendText = channel.hasBannedPermission(.banSendText, ignoreDefault: canBypassRestrictions) {
                        if bannedSendText.1 || component.slice.additionalPeerData.boostsToUnrestrict == nil {
                            showMessageInputPanel = false
                        } else {
                            isGroupCommentRestricted = true
                        }
                    }
                    isGroup = true
                }
            } else {
                showMessageInputPanel = component.slice.effectivePeer.id != component.context.account.peerId
            }
            if case let .user(user) = component.slice.peer, let _ = user.botInfo {
                showMessageInputPanel = false
            }
            
            var isUnsupported = false
            var disabledPlaceholder: MessageInputPanelComponent.DisabledPlaceholder?
            
            if isGroupCommentRestricted {
                disabledPlaceholder = .boostRequired(title: component.strings.Story_GroupCommentingRestrictedPlaceholder, subtitle: component.strings.Story_GroupCommentingRestrictedPlaceholderAction, action: { [weak self] in
                    self?.presentBoostToUnrestrict()
                })
            } else if component.slice.additionalPeerData.isPremiumRequiredForMessaging {
                disabledPlaceholder = .premiumRequired(title: component.strings.Story_MessagingRestrictedPlaceholder(component.slice.effectivePeer.compactDisplayTitle).string, subtitle: component.strings.Story_MessagingRestrictedPlaceholderAction, action: { [weak self] in
                    self?.presentPremiumRequiredForMessaging()
                })
            } else if component.slice.effectivePeer.isService {
                disabledPlaceholder = .text(component.strings.Story_FooterReplyUnavailable)
            } else if case .unsupported = component.slice.item.storyItem.media {
                isUnsupported = true
                disabledPlaceholder = .text(component.strings.Story_FooterReplyUnavailable)
            }
            
            let inputPlaceholder: MessageInputPanelComponent.Placeholder
            if let stealthModeTimeout = component.stealthModeTimeout {
                let minutes = Int(stealthModeTimeout / 60)
                let seconds = Int(stealthModeTimeout % 60)
                
                let rawString = component.strings.Story_StealthModePlaceholder
                var items: [MessageInputPanelComponent.Placeholder.CounterItem] = []
                var startIndex = rawString.startIndex
                while true {
                    if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                        if range.lowerBound != startIndex {
                            items.append(MessageInputPanelComponent.Placeholder.CounterItem(id: items.count, content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                        }
                        
                        startIndex = range.upperBound
                        if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                            let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                            if controlString == "m" {
                                items.append(MessageInputPanelComponent.Placeholder.CounterItem(id: items.count, content: .number(minutes, minDigits: 2)))
                            } else if controlString == "s" {
                                items.append(MessageInputPanelComponent.Placeholder.CounterItem(id: items.count, content: .number(seconds, minDigits: 2)))
                            }
                            
                            startIndex = endRange.upperBound
                        }
                    } else {
                        break
                    }
                }
                if startIndex != rawString.endIndex {
                    items.append(MessageInputPanelComponent.Placeholder.CounterItem(id: items.count, content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
                }
                
                inputPlaceholder = .counter(items)
            } else {
                if let sendPaidMessageStars = component.slice.additionalPeerData.sendPaidMessageStars {
                    let dateTimeFormat = component.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat
                    inputPlaceholder = .plain(component.strings.Chat_InputTextPaidMessagePlaceholder(" # \(presentationStringsFormattedNumber(Int32(sendPaidMessageStars.value), dateTimeFormat.groupingSeparator))").string)
                } else {
                    inputPlaceholder = .plain(isGroup ? component.strings.Story_InputPlaceholderReplyInGroup : component.strings.Story_InputPlaceholderReplyPrivately)
                }
            }
            
            let startTime22 = CFAbsoluteTimeGetCurrent()
            
            var currentHasFirstResponder = false
            if let reactionContextNode = self.reactionContextNode {
                if hasFirstResponder(reactionContextNode.view) {
                    currentHasFirstResponder = true
                }
            }
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                if inputPanelView.hasFirstResponder() {
                    currentHasFirstResponder = true
                }
            }
             
            var keyboardHeight = component.deviceMetrics.standardInputHeight(inLandscape: false)
            let keyboardWasHidden = self.inputPanelExternalState.isKeyboardHidden
            let inputNodeVisible = self.sendMessageContext.currentInputMode == .media || currentHasFirstResponder
            self.inputPanel.parentState = state
            var inputPanelSize: CGSize?
            
            let startTime23 = CFAbsoluteTimeGetCurrent()
                        
            if showMessageInputPanel {
                var haveLikeOptions = false
                if case .user = component.slice.effectivePeer {
                    haveLikeOptions = true
                    
                    if component.slice.effectivePeer.isService {
                        haveLikeOptions = false
                    }
                }
                
                inputPanelSize = self.inputPanel.update(
                    transition: inputPanelTransition,
                    component: AnyComponent(MessageInputPanelComponent(
                        externalState: self.inputPanelExternalState,
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        style: .story,
                        placeholder: inputPlaceholder,
                        sendPaidMessageStars: component.slice.additionalPeerData.sendPaidMessageStars,
                        maxLength: 4096,
                        queryTypes: [.mention, .hashtag, .emoji],
                        alwaysDarkWhenHasText: component.metrics.widthClass == .regular,
                        resetInputContents: resetInputContents,
                        nextInputMode: { [weak self] hasText in
                            if case .media = self?.sendMessageContext.currentInputMode {
                                return .text
                            } else {
                                return hasText ? .emoji : .stickers
                            }
                        },
                        areVoiceMessagesAvailable: component.slice.additionalPeerData.areVoiceMessagesAvailable,
                        presentController: { [weak self] c in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.presentController(c, nil)
                        },
                        presentInGlobalOverlay: { [weak self] c in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.presentInGlobalOverlay(c, nil)
                        },
                        sendMessageAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.performSendMessageAction(view: self)
                        },
                        sendMessageOptionsAction: { [weak self] sourceView, gesture in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.presentSendMessageOptions(view: self, sourceView: sourceView, gesture: gesture)
                        },
                        sendStickerAction: { [weak self] sticker in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.performSendStickerAction(view: self, fileReference: .standalone(media: sticker))
                        },
                        setMediaRecordingActive: { [weak self] isActive, isVideo, sendAction, _ in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.setMediaRecordingActive(view: self, isActive: isActive, isVideo: isVideo, sendAction: sendAction)
                        },
                        lockMediaRecording: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.lockMediaRecording()
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                        },
                        stopAndPreviewMediaRecording: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.stopMediaRecording(view: self)
                        },
                        discardMediaRecordingPreview: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.videoRecorderValue?.dismissVideo()
                            self.sendMessageContext.discardMediaRecordingPreview(view: self)
                        },
                        attachmentAction: component.slice.effectivePeer.isService ? nil : { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.presentAttachmentMenu(view: self, subject: .default)
                        },
                        attachmentButtonMode: component.slice.effectivePeer.isService ? nil : .attach,
                        myReaction: component.slice.item.storyItem.myReaction.flatMap { value -> MessageInputPanelComponent.MyReaction? in
                            var centerAnimation: TelegramMediaFile?
                            var animationFileId: Int64?
                            
                            switch value {
                            case .builtin:
                                if let availableReactions = component.availableReactions {
                                    for availableReaction in availableReactions.reactionItems {
                                        if availableReaction.reaction.rawValue == value {
                                            centerAnimation = availableReaction.listAnimation._parse()
                                            break
                                        }
                                    }
                                }
                            case let .custom(fileId):
                                animationFileId = fileId
                            case .stars:
                                if let availableReactions = component.availableReactions {
                                    for availableReaction in availableReactions.reactionItems {
                                        if availableReaction.reaction.rawValue == value {
                                            centerAnimation = availableReaction.listAnimation._parse()
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if animationFileId == nil && centerAnimation == nil {
                                return nil
                            }
                            
                            return MessageInputPanelComponent.MyReaction(reaction: value, file: centerAnimation, animationFileId: animationFileId)
                        },
                        likeAction: component.slice.effectivePeer.isService ? nil : { [weak self] in
                            guard let self else {
                                return
                            }
                            self.performLikeAction()
                        },
                        likeOptionsAction: !haveLikeOptions ? nil : { [weak self] sourceView, gesture in
                            guard let self else {
                                gesture?.cancel()
                                return
                            }
                            self.performLikeOptionsAction(sourceView: sourceView, gesture: gesture)
                        },
                        inputModeAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.toggleInputMode()
                            if !hasFirstResponder(self) {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            } else {
                                self.state?.updated(transition: .immediate)
                            }
                        },
                        timeoutAction: nil,
                        forwardAction: component.slice.item.storyItem.isPublic && !component.slice.item.storyItem.isForwardingDisabled ? { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.performShareAction(view: self)
                        } : nil,
                        moreAction: { [weak self] sourceView, gesture in
                            guard let self else {
                                return
                            }
                            self.performMoreAction(sourceView: sourceView, gesture: gesture)
                        },
                        presentCaptionPositionTooltip: nil,
                        presentVoiceMessagesUnavailableTooltip: { [weak self] view in
                            guard let self, let component = self.component, self.voiceMessagesRestrictedTooltipController == nil else {
                                return
                            }
                            let rect = view.convert(view.bounds, to: nil)
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            let text = presentationData.strings.Conversation_VoiceMessagesRestricted(component.slice.effectivePeer.compactDisplayTitle).string
                            let controller = TooltipController(content: .text(text), baseFontSize: presentationData.listsFontSize.baseDisplaySize, isBlurred: true, padding: 2.0)
                            controller.dismissed = { [weak self] _ in
                                if let self {
                                    self.voiceMessagesRestrictedTooltipController = nil
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                                }
                            }
                            component.presentController(controller, TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                                if let self {
                                    return (self, rect)
                                }
                                return nil
                            }))
                            self.voiceMessagesRestrictedTooltipController = controller
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                        },
                        presentTextLengthLimitTooltip: nil,
                        presentTextFormattingTooltip: nil,
                        paste: { [weak self] data in
                            guard let self else {
                                return
                            }
                            switch data {
                            case let .images(images):
                                self.sendMessageContext.presentMediaPasteboard(view: self, subjects: images.map { .image($0) })
                            case let .video(data):
                                let tempFilePath = NSTemporaryDirectory() + "\(Int64.random(in: 0...Int64.max)).mp4"
                                let url = NSURL(fileURLWithPath: tempFilePath) as URL
                                try? data.write(to: url)
                                self.sendMessageContext.presentMediaPasteboard(view: self, subjects: [.video(url)])
                            case let .gif(data):
                                self.sendMessageContext.enqueueGifData(view: self, data: data)
                            case let .sticker(image, isMemoji):
                                self.sendMessageContext.enqueueStickerImage(view: self, image: image, isMemoji: isMemoji)
                            case .text:
                                break
                            }
                        },
                        audioRecorder: self.sendMessageContext.audioRecorderValue,
                        videoRecordingStatus: !self.sendMessageContext.hasRecordedVideoPreview ? self.sendMessageContext.videoRecorderValue?.audioStatus : nil,
                        isRecordingLocked: self.sendMessageContext.isMediaRecordingLocked,
                        hasRecordedVideo: false,
                        recordedAudioPreview: self.sendMessageContext.recordedAudioPreview,
                        hasRecordedVideoPreview: self.sendMessageContext.hasRecordedVideoPreview,
                        wasRecordingDismissed: self.sendMessageContext.wasRecordingDismissed,
                        timeoutValue: nil,
                        timeoutSelected: false,
                        displayGradient: false,
                        bottomInset: component.inputHeight != 0.0 || inputNodeVisible ? 0.0 : bottomContentInset,
                        isFormattingLocked: false,
                        hideKeyboard: self.sendMessageContext.currentInputMode == .media,
                        customInputView: nil,
                        forceIsEditing: self.sendMessageContext.currentInputMode == .media,
                        disabledPlaceholder: disabledPlaceholder,
                        header: nil,
                        isChannel: isChannel,
                        storyItem: component.slice.item.storyItem,
                        chatLocation: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: inputPanelAvailableWidth, height: 200.0)
                )
            }
            
            let startTime3 = CFAbsoluteTimeGetCurrent()
            
            var inputPanelInset: CGFloat = component.containerInsets.bottom
            var inputHeight = component.inputHeight
            
            var needInputBackground = true
            if self.viewListDisplayState != .hidden {
                needInputBackground = false
            }
            if self.inputPanelExternalState.isEditing {
                if self.sendMessageContext.currentInputMode == .media || (inputHeight.isZero && keyboardWasHidden) {
                    inputHeight = component.deviceMetrics.standardInputHeight(inLandscape: false)
                }
            }

            let inputMediaNodeHeight = self.sendMessageContext.updateInputMediaNode(view: self, availableSize: availableSize, bottomInset: component.safeInsets.bottom, bottomContainerInset: component.containerInsets.bottom, inputHeight: component.inputHeight, effectiveInputHeight: inputHeight, metrics: component.metrics, deviceMetrics: component.deviceMetrics, transition: transition)
            if inputMediaNodeHeight > 0.0 {
                inputHeight = inputMediaNodeHeight
                inputPanelInset = 0.0
            }
            keyboardHeight = inputHeight
            
            let hasRecordingBlurBackground = self.sendMessageContext.videoRecorderValue != nil || self.sendMessageContext.hasRecordedVideoPreview
            if hasRecordingBlurBackground {
                let videoRecordingBackgroundView: UIVisualEffectView
                if let current = self.videoRecordingBackgroundView {
                    videoRecordingBackgroundView = current
                } else {
                    videoRecordingBackgroundView = UIVisualEffectView(effect: nil)
                    UIView.animate(withDuration: 0.3, animations: {
                        videoRecordingBackgroundView.effect = UIBlurEffect(style: .dark)
                    })
                    if let inputPanelView = self.inputPanel.view {
                        inputPanelView.superview?.insertSubview(videoRecordingBackgroundView, belowSubview: inputPanelView)
                    }
                    self.videoRecordingBackgroundView = videoRecordingBackgroundView
                }
                transition.setFrame(view: videoRecordingBackgroundView, frame: CGRect(origin: .zero, size: availableSize))
            } else if let videoRecordingBackgroundView = self.videoRecordingBackgroundView {
                self.videoRecordingBackgroundView = nil
                UIView.animate(withDuration: 0.3, animations: {
                    videoRecordingBackgroundView.effect = nil
                }, completion: { _ in
                    videoRecordingBackgroundView.removeFromSuperview()
                })
            }
            
            let inputPanelBackgroundHeight = keyboardHeight + 60.0 - inputPanelInset
            let inputPanelBackgroundSize = self.inputPanelBackground.update(
                transition: transition,
                component: AnyComponent(BlurredGradientComponent(position: .bottom, dark: true, tag: nil)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: max(0.0, inputPanelBackgroundHeight))
            )
            if let inputPanelBackgroundView = self.inputPanelBackground.view {
                if inputPanelBackgroundView.superview == nil {
                    self.componentContainerView.addSubview(self.inputPanelContainer)
                    self.inputPanelContainer.insertSubview(inputPanelBackgroundView, at: 0)
                }
                let isVisible = inputHeight > 44.0 && !hasRecordingBlurBackground && needInputBackground
                transition.setFrame(view: inputPanelBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: isVisible ? availableSize.height - inputPanelBackgroundSize.height : availableSize.height), size: inputPanelBackgroundSize))
                transition.setAlpha(view: inputPanelBackgroundView, alpha: isVisible ? 1.0 : 0.0, delay: isVisible ? 0.0 : 0.4)
            }
            
            var viewListInset: CGFloat = 0.0
            
            var inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if inputHeight == 0.0 {
                inputPanelBottomInset = bottomContentInset
                if case .regular = component.metrics.widthClass {
                    bottomContentInset += 60.0
                } else if let inputPanelSize {
                    bottomContentInset += inputPanelSize.height
                }
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = inputHeight - inputPanelInset
                inputPanelIsOverlay = true
            }
            
            var minimizedBottomContentHeight: CGFloat = 0.0
            var maximizedBottomContentHeight: CGFloat = 0.0
            
            let minimizedHeight = max(100.0, availableSize.height - (325.0 + 12.0))
            let defaultHeight = 60.0 + component.safeInsets.bottom + 1.0
            
            let startTime4 = CFAbsoluteTimeGetCurrent()
            
            var validViewListIds: [StoryId] = []
            
            var displayViewLists = false
            if component.slice.effectivePeer.id == component.context.account.peerId {
                displayViewLists = true
            } else if case let .channel(channel) = component.slice.effectivePeer, channel.flags.contains(.isCreator) || component.slice.additionalPeerData.canViewStats {
                displayViewLists = true
            }
            
            var viewListHeightMidFraction: CGFloat = 0.0
            if displayViewLists, let currentIndex = component.slice.allItems.firstIndex(where: { $0.id == component.slice.item.id }) {
                var visibleViewListIds: [StoryId] = [component.slice.item.id]
                if self.viewListDisplayState != .hidden, let viewListPanState = self.viewListPanState {
                    if currentIndex != 0 {
                        if viewListPanState.fraction > 0.0 {
                            visibleViewListIds.append(component.slice.allItems[currentIndex - 1].id)
                        }
                    }
                    if currentIndex != component.slice.allItems.count - 1 {
                        if viewListPanState.fraction < 0.0 {
                            visibleViewListIds.append(component.slice.allItems[currentIndex + 1].id)
                        }
                    }
                }
                
                var preloadViewListIds: [(StoryId, EngineStoryItem.Views)] = []
                if let views = component.slice.item.storyItem.views {
                    preloadViewListIds.append((component.slice.item.id, views))
                }
                if currentIndex != 0, let views = component.slice.allItems[currentIndex - 1].storyItem.views {
                    preloadViewListIds.append((component.slice.allItems[currentIndex - 1].id, views))
                }
                if currentIndex != component.slice.allItems.count - 1, let views = component.slice.allItems[currentIndex + 1].storyItem.views {
                    preloadViewListIds.append((component.slice.allItems[currentIndex + 1].id, views))
                }
                
                for (id, views) in preloadViewListIds {
                    if component.sharedViewListsContext.viewLists[id] == nil {
                        let defaultSortMode: EngineStoryViewListContext.SortMode
                        if component.slice.effectivePeer.id.isGroupOrChannel {
                            defaultSortMode = .repostsFirst
                        } else {
                            defaultSortMode = .reactionsFirst
                        }
                        let viewList = component.context.engine.messages.storyViewList(peerId: component.slice.effectivePeer.id, id: id.id, views: views, listMode: .everyone, sortMode: defaultSortMode)
                        component.sharedViewListsContext.viewLists[id] = viewList
                    }
                }
                
                if self.viewListPanState != nil || self.isCompletingViewListPan {
                    for (id, _) in self.viewLists {
                        if !visibleViewListIds.contains(id) {
                            visibleViewListIds.append(id)
                        }
                    }
                }
                
                var viewListBaseOffsetX: CGFloat = 0.0
                if let viewListPanState = self.viewListPanState {
                    viewListBaseOffsetX = viewListPanState.fraction * availableSize.width
                }
                
                var fixedAnimationOffset: CGFloat = 0.0
                var applyFixedAnimationOffsetIds: [StoryId] = []
                
                let normalCollapsedContentAreaHeight: CGFloat = availableSize.height - minimizedHeight
                
                let minViewListHeight: CGFloat = 0.0
                let maxViewListHeight: CGFloat = availableSize.height - 60.0
                let midViewListHeight: CGFloat = availableSize.height - normalCollapsedContentAreaHeight
                
                var viewListHeight: CGFloat = 0.0
                
                switch self.viewListDisplayState {
                case .hidden:
                    viewListHeight = minViewListHeight
                case .half:
                    viewListHeight = midViewListHeight
                case .full:
                    viewListHeight = maxViewListHeight
                }
                
                if let verticalPanState = self.verticalPanState {
                    if verticalPanState.scrollView != nil {
                        viewListHeight += -verticalPanState.accumulatedOffset
                    } else {
                        viewListHeight += -verticalPanState.fraction * availableSize.height
                    }
                }
                
                viewListHeight = max(minViewListHeight, min(maxViewListHeight, viewListHeight))
                
                self.targetViewListDisplayStateIsFull = viewListHeight > midViewListHeight
                self.viewListMetrics = (midViewListHeight, maxViewListHeight, viewListHeight)
                
                viewListHeightMidFraction = max(0.0, min(1.0, viewListHeight / midViewListHeight))
                viewListInset = defaultHeight * (1.0 - viewListHeightMidFraction) + viewListHeightMidFraction * midViewListHeight
                viewListInset += max(0.0, viewListHeight - midViewListHeight)
                
                if showMessageInputPanel {
                    inputPanelBottomInset += (viewListInset - defaultHeight) * 1.04
                } else {
                    inputPanelBottomInset = viewListInset
                }
                minimizedBottomContentHeight = minimizedHeight
                maximizedBottomContentHeight = defaultHeight
                
                for id in visibleViewListIds {
                    guard let itemIndex = component.slice.allItems.firstIndex(where: { $0.id == id }) else {
                        continue
                    }
                    let item = component.slice.allItems[itemIndex]
                    validViewListIds.append(id)
                    
                    let viewList: ViewList
                    var viewListTransition = itemsTransition
                    if let current = self.viewLists[id] {
                        viewList = current
                    } else {
                        if !itemsTransition.animation.isImmediate {
                            viewListTransition = .immediate
                        }
                        viewList = ViewList()
                        self.viewLists[id] = viewList
                        applyFixedAnimationOffsetIds.append(id)
                    }
                    
                    var safeInsets = component.safeInsets
                    safeInsets.bottom = max(safeInsets.bottom, component.inputHeight)
                    
                    var hasPremium = false
                    if case let .user(user) = component.slice.effectivePeer {
                        hasPremium = user.isPremium
                    }
                    
                    viewList.view.parentState = state
                    let viewListSize = viewList.view.update(
                        transition: viewListTransition.withUserData(PeerListItemComponent.TransitionHint(
                            synchronousLoad: false
                        )).withUserData(StoryItemSetViewListComponent.AnimationHint(
                            synchronous: false
                        )),
                        component: AnyComponent(StoryItemSetViewListComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            sharedListsContext: component.sharedViewListsContext,
                            peerId: component.slice.effectivePeer.id,
                            safeInsets: safeInsets,
                            storyItem: item.storyItem,
                            hasPremium: hasPremium,
                            effectiveHeight: viewListHeight,
                            minHeight: midViewListHeight,
                            availableReactions: component.availableReactions,
                            isSearchActive: self.isSearchActive,
                            close: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.viewListDisplayState = .hidden
                                self.isSearchActive = false
                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            },
                            expandViewStats: {
                            },
                            deleteAction: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                
                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                let actionSheet = ActionSheetController(presentationData: presentationData)
                                
                                actionSheet.setItemGroups([
                                    ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: component.strings.Story_ContextDeleteStory, color: .destructive, action: { [weak self, weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                            
                                            guard let self, let component = self.component else {
                                                return
                                            }
                                            component.delete()
                                        })
                                    ]),
                                    ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                        })
                                    ])
                                ])
                                
                                actionSheet.dismissed = { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    self.sendMessageContext.actionSheet = nil
                                    self.updateIsProgressPaused()
                                }
                                self.sendMessageContext.actionSheet = actionSheet
                                self.updateIsProgressPaused()
                                
                                component.presentController(actionSheet, nil)
                            },
                            moreAction: { [weak self] sourceView, gesture in
                                guard let self else {
                                    return
                                }
                                self.performMoreAction(sourceView: sourceView, gesture: gesture)
                            },
                            openPeer: { [weak self] peer in
                                guard let self else {
                                    return
                                }
                                self.navigateToPeer(peer: peer, chat: false)
                            },
                            openMessage: { [weak self] peer, messageId in
                                guard let self else {
                                    return
                                }
                                self.navigateToPeer(peer: peer, chat: true, subject: .message(id: .id(messageId), highlight: nil, timecode: nil, setupReply: false))
                            },
                            peerContextAction: { [weak self] peer, sourceView, gesture in
                                guard let self, let component = self.component else {
                                    return
                                }
                                let _ = (component.context.engine.data.get(
                                    TelegramEngine.EngineData.Item.Peer.IsContact(id: peer.id),
                                    TelegramEngine.EngineData.Item.Peer.IsBlocked(id: peer.id),
                                    TelegramEngine.EngineData.Item.Peer.IsBlockedFromStories(id: peer.id)
                                ) |> deliverOnMainQueue).startStandalone(next: { [weak self] isContact, maybeIsBlocked, maybeIsBlockedFromStories in
                                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                    var itemList: [ContextMenuItem] = []
                                    
                                    var isBlocked = false
                                    if case let .known(value) = maybeIsBlocked {
                                        isBlocked = value
                                    }
                                    var isBlockedFromStories = false
                                    if case let .known(value) = maybeIsBlockedFromStories {
                                        isBlockedFromStories = value
                                    }
                                    
                                    if isBlockedFromStories {
                                        itemList.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextShowStoriesTo(peer.compactDisplayTitle).string, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Stories"), color: theme.contextMenu.primaryColor)
                                        }, action: { [weak self] _, f in
                                            f(.default)
                                            
                                            let _ = component.blockedPeers?.remove(peerId: peer.id).startStandalone()
                                            
                                            guard let self else {
                                                return
                                            }
                                            
                                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                            self.component?.presentController(UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .info(title: nil, text: component.strings.Story_ToastShowStoriesTo(peer.compactDisplayTitle).string, timeout: nil, customUndoText: nil),
                                                elevatedLayout: false,
                                                position: .top,
                                                animateInAsReplacement: false,
                                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                                action: { _ in return false }
                                            ), nil)
                                        })))
                                    } else if isContact {
                                        itemList.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextHideStoriesFrom(peer.compactDisplayTitle).string, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Stories"), color: theme.contextMenu.primaryColor)
                                        }, action: { [weak self] _, f in
                                            f(.default)
                                            let _ = component.blockedPeers?.add(peerId: peer.id).startStandalone()
                                            
                                            guard let self else {
                                                return
                                            }
                                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                            self.component?.presentController(UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .info(title: nil, text: component.strings.Story_ToastHideStoriesFrom(peer.compactDisplayTitle).string, timeout: nil, customUndoText: nil),
                                                elevatedLayout: false,
                                                position: .top,
                                                animateInAsReplacement: false,
                                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                                action: { _ in return false }
                                            ), nil)
                                        })))
                                    }

                                    if isContact {
                                        itemList.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextDeleteContact, textColor: .destructive, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                                        }, action: { [weak self] _, f in
                                            f(.default)
                                            
                                            let _ = component.context.engine.contacts.deleteContactPeerInteractively(peerId: peer.id).startStandalone()
                                            
                                            guard let self else {
                                                return
                                            }
                                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                            let animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
                                            self.component?.presentController(UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .universal(
                                                    animation: "anim_infotip",
                                                    scale: 1.0,
                                                    colors: [
                                                        "info1.info1.stroke": animationBackgroundColor,
                                                        "info2.info2.Fill": animationBackgroundColor
                                                    ],
                                                    title: nil,
                                                    text: component.strings.Story_ToastDeletedContact(peer.compactDisplayTitle).string,
                                                    customUndoText: component.strings.Undo_Undo,
                                                    timeout: nil
                                                ),
                                                elevatedLayout: false,
                                                position: .top,
                                                animateInAsReplacement: false,
                                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                                action: { [weak self] action in
                                                    guard let self, let component = self.component else {
                                                        return false
                                                    }
                                                    guard case let .user(user) = peer else {
                                                        return false
                                                    }
                                                    if case .undo = action {
                                                        let _ =  component.context.engine.contacts.addContactInteractively(peerId: peer.id, firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumber: user.phone ?? "", addToPrivacyExceptions: false).startStandalone()
                                                    }
                                                    return false
                                                }
                                            ), nil)
                                        })))
                                    } else {
                                        if isBlocked {
                                        } else {
                                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuBlock, textColor: .destructive, icon: { theme in
                                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.destructiveColor)
                                            }, action: { [weak self] _, f in
                                                f(.default)
                                                
                                                let _ = component.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).startStandalone()
                                                
                                                guard let self else {
                                                    return
                                                }
                                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                                let animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
                                                self.component?.presentController(UndoOverlayController(
                                                    presentationData: presentationData,
                                                    content: .universal(
                                                        animation: "anim_infotip",
                                                        scale: 1.0,
                                                        colors: [
                                                            "info1.info1.stroke": animationBackgroundColor,
                                                            "info2.info2.Fill": animationBackgroundColor
                                                        ],
                                                        title: nil,
                                                        text: component.strings.Story_ToastUserBlocked(peer.compactDisplayTitle).string,
                                                        customUndoText: component.strings.Undo_Undo,
                                                        timeout: nil
                                                    ),
                                                    elevatedLayout: false,
                                                    position: .top,
                                                    animateInAsReplacement: false,
                                                    appearance: UndoOverlayController.Appearance(isBlurred: true),
                                                    action: { [weak self] action in
                                                        guard let self, let component = self.component else {
                                                            return false
                                                        }
                                                        if case .undo = action {
                                                            let _ = component.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: false).startStandalone()
                                                        }
                                                        return false
                                                    }
                                                ), nil)
                                            })))
                                        }
                                    }
                                    
                                    let items = ContextController.Items(content: .list(itemList))
                                    
                                    let controller = ContextController(
                                        presentationData: presentationData,
                                        source: .extracted(ListContextExtractedContentSource(contentView: sourceView)),
                                        items: .single(items),
                                        recognizer: nil,
                                        gesture: gesture
                                    )
                                    component.presentInGlobalOverlay(controller, nil)
                                })
                            },
                            openPeerStories: { [weak self] peer, avatarNode in
                                guard let self else {
                                    return
                                }
                                self.openPeerStories(peer: peer, avatarNode: avatarNode)
                            },
                            openReposts: { [weak self] peer, id, sourceView in
                                guard let self else {
                                    return
                                }
                                self.openReposts(peer: peer, id: id, sourceView: sourceView)
                            },
                            openPremiumIntro: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.presentStoriesUpgradeScreen(source: .storiesPermanentViews)
                            },
                            setIsSearchActive: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                if value != self.isSearchActive {
                                    self.isSearchActive = value
                                    
                                    if self.isSearchActive {
                                        self.viewListDisplayState = .full
                                    } else {
                                        self.viewListDisplayState = .half
                                    }
                                    
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.5, curve: .spring)))
                                }
                            },
                            controller: { [weak self] in
                                return self?.component?.controller()
                            }
                        )),
                        environment: {},
                        containerSize: availableSize
                    )
                    
                    var viewListFrame = CGRect(origin: CGPoint(x: viewListBaseOffsetX, y: availableSize.height - viewListSize.height), size: viewListSize)
                    let indexDistance = CGFloat(max(-1, min(1, itemIndex - currentIndex)))
                    viewListFrame.origin.x += indexDistance * (availableSize.width + 20.0)
                    
                    if let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                        var animateIn = false
                        if viewListView.superview == nil {
                            self.viewListsContainer.addSubview(viewListView)
                            animateIn = true
                        } else {
                            fixedAnimationOffset = viewListFrame.minX - viewListView.frame.minX
                        }
                        viewListTransition.setFrame(view: viewListView, frame: viewListFrame)
                        viewListTransition.setAlpha(view: viewListView, alpha: component.hideUI || self.isEditingStory ? 0.0 : 1.0)
                        
                        if animateIn, !transition.animation.isImmediate {
                            viewListView.animateIn(transition: transition)
                        }
                    }
                    /*if id == component.slice.item.id {
                        viewListInset = minimizedHeight * viewList.externalState.minimizationFraction + defaultHeight * (1.0 - viewList.externalState.minimizationFraction)
                        inputPanelBottomInset = viewListInset
                        minimizedBottomContentHeight = minimizedHeight
                        maximizedBottomContentHeight = defaultHeight
                        minimizedBottomContentFraction = viewList.externalState.minimizationFraction
                    }*/
                }
                
                if fixedAnimationOffset == 0.0 {
                    for (id, viewList) in self.viewLists {
                        if let viewListView = viewList.view.view, !visibleViewListIds.contains(id), let itemIndex = component.slice.allItems.firstIndex(where: { $0.id == id }) {
                            let viewListSize = viewListView.bounds.size
                            var viewListFrame = CGRect(origin: CGPoint(x: viewListBaseOffsetX, y: availableSize.height - viewListSize.height), size: viewListSize)
                            let indexDistance = CGFloat(max(-1, min(1, itemIndex - currentIndex)))
                            viewListFrame.origin.x += indexDistance * availableSize.width
                            
                            fixedAnimationOffset = viewListFrame.minX - viewListView.frame.minX
                        }
                    }
                }
                
                if fixedAnimationOffset != 0.0 {
                    for id in applyFixedAnimationOffsetIds {
                        if let viewListView = self.viewLists[id]?.view.view {
                            itemsTransition.animatePosition(view: viewListView, from: CGPoint(x: -fixedAnimationOffset, y: 0.0), to: CGPoint(), additive: true)
                        }
                    }
                }
            } else {
                self.viewListMetrics = nil
            }
            var removeViewListIds: [StoryId] = []
            for (id, viewList) in self.viewLists {
                if !validViewListIds.contains(id) {
                    removeViewListIds.append(id)
                    viewList.view.view?.removeFromSuperview()
                }
            }
            for id in removeViewListIds {
                self.viewLists.removeValue(forKey: id)
            }
            
            let startTime5 = CFAbsoluteTimeGetCurrent()
            
            let itemSize = CGSize(width: availableSize.width, height: ceil(availableSize.width * 1.77778))
            let contentDefaultBottomInset: CGFloat = bottomContentInset
            
            let contentVisualMaxBottomInset: CGFloat = max(contentDefaultBottomInset, maximizedBottomContentHeight)
            let contentVisualMinBottomInset: CGFloat = max(contentDefaultBottomInset, minimizedBottomContentHeight)
            
            var contentVisualBottomInset: CGFloat = max(contentDefaultBottomInset, viewListInset)
            let contentBottomInsetOverflow = max(0.0, contentVisualBottomInset - contentVisualMinBottomInset)
            contentVisualBottomInset = min(contentVisualMinBottomInset, contentVisualBottomInset)
            contentVisualBottomInset = max(contentVisualMaxBottomInset, contentVisualBottomInset)
            
            let contentOverflowFraction: CGFloat = max(0.0, min(1.0, contentBottomInsetOverflow / (availableSize.height - contentVisualMinBottomInset - 60.0)))
            
            let contentVisualMaxHeight = min(itemSize.height, availableSize.height - component.containerInsets.top - contentVisualMaxBottomInset)
            let contentSize = CGSize(width: itemSize.width, height: contentVisualMaxHeight)
            let contentVisualMinHeight = min(contentSize.height, availableSize.height - component.containerInsets.top - contentVisualMinBottomInset)
            
            let contentVisualHeight = min(contentSize.height, availableSize.height - component.containerInsets.top - contentVisualBottomInset)
            
            let contentVisualScale = min(1.0, contentVisualHeight / contentSize.height)
            
            let contentMaxScale = min(1.0, contentVisualMaxHeight / contentSize.height)
            let contentMinScale = min(1.0, contentVisualMinHeight / contentSize.height)
            
            let contentScaleFraction: CGFloat
            if abs(contentMaxScale - contentMinScale) < CGFloat.ulpOfOne {
                contentScaleFraction = 0.0
            } else {
                contentScaleFraction = 1.0 - (contentVisualScale - contentMinScale) / (contentMaxScale - contentMinScale)
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: component.containerInsets.top - (contentSize.height - contentVisualHeight) * 0.5 - contentBottomInsetOverflow), size: contentSize)
            
            transition.setFrame(view: self.viewListsContainer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: 0.0), size: CGSize(width: contentSize.width, height: availableSize.height)))
            let viewListsRadius: CGFloat
            if component.metrics.widthClass == .regular {
                viewListsRadius = 10.0
            } else {
                viewListsRadius = 0.0
            }
            transition.setCornerRadius(layer: self.viewListsContainer.layer, cornerRadius: viewListsRadius)
            
            transition.setFrame(view: self.inputPanelContainer, frame: CGRect(origin: .zero, size: availableSize))
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                contentFrame: contentFrame,
                contentMinScale: contentMinScale,
                contentScaleFraction: contentScaleFraction,
                contentOverflowFraction: contentOverflowFraction
            )
            self.itemLayout = itemLayout
            
            let itemsContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: component.containerInsets.top + floor(contentVisualHeight)))
            transition.setPosition(view: self.itemsContainerView, position: CGPoint(x: itemsContainerFrame.center.x, y: itemsContainerFrame.center.y))
            transition.setBounds(view: self.itemsContainerView, bounds: CGRect(origin: .zero, size: itemsContainerFrame.size))
            
            transition.setPosition(view: self.controlsContainerView, position: contentFrame.center)
            transition.setBounds(view: self.controlsContainerView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            transition.setPosition(view: self.controlsClippingView, position: contentFrame.center)
            transition.setBounds(view: self.controlsClippingView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            transition.setPosition(view: self.controlsNavigationClippingView, position: contentFrame.center)
            transition.setBounds(view: self.controlsNavigationClippingView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            var transform = CATransform3DMakeScale(contentVisualScale, contentVisualScale, 1.0)
            if let pinchState = component.pinchState {
                let pinchOffset = CGPoint(
                    x: pinchState.location.x - contentFrame.width / 2.0,
                    y: pinchState.location.y - contentFrame.height / 2.0
                )
                transform = CATransform3DTranslate(
                    transform,
                    pinchState.offset.x - pinchOffset.x * (pinchState.scale - 1.0),
                    pinchState.offset.y - pinchOffset.y * (pinchState.scale - 1.0),
                    0.0
                )
                transform = CATransform3DScale(transform, pinchState.scale, pinchState.scale, 0.0)
            }
            transition.setTransform(view: self.controlsContainerView, transform: transform)
            transition.setTransform(view: self.controlsClippingView, transform: transform)
            transition.setTransform(view: self.controlsNavigationClippingView, transform: transform)
            
            transition.setCornerRadius(layer: self.controlsClippingView.layer, cornerRadius: 12.0 * (1.0 / contentVisualScale))
            
            var headerRightOffset: CGFloat = availableSize.width
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Stories/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonCollapsedFrame = CGRect(origin: CGPoint(x: contentFrame.minX + headerRightOffset - 50.0, y: component.containerInsets.top + 2.0), size: CGSize(width: 50.0, height: 64.0))
                let closeButtonExpandedFrame = CGRect(origin: CGPoint(x: contentFrame.minX + headerRightOffset - 50.0, y: component.containerInsets.top - 15.0), size: CGSize(width: 50.0, height: 64.0))
                var closeButtonFrame = closeButtonCollapsedFrame.interpolate(to: closeButtonExpandedFrame, amount: itemLayout.contentScaleFraction)
                closeButtonFrame.origin.y -= contentBottomInsetOverflow
                
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setAlpha(view: self.closeButton, alpha: (component.hideUI || self.isEditingStory) ? 0.0 : 1.0)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
                headerRightOffset -= 51.0
            }
            
            var moreButtonSize: CGSize?
            if case let .user(user) = component.slice.peer, let botInfo = user.botInfo, !botInfo.flags.contains(.canEdit) {
            } else {
                moreButtonSize = self.moreButton.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: "anim_story_more"
                            ),
                            color: .white,
                            startingPosition: .end,
                            size: CGSize(width: 30.0, height: 30.0)
                        )),
                        effectAlignment: .center,
                        minSize: CGSize(width: 33.0, height: 64.0),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            guard let moreButtonView = self.moreButton.view else {
                                return
                            }
                            if let animationView = (moreButtonView as? PlainButtonComponent.View)?.contentView as? LottieComponent.View {
                                animationView.playOnce()
                            }
                            self.performMoreAction(sourceView: moreButtonView, gesture: nil)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 33.0, height: 64.0)
                )
            }
            if let moreButtonSize, let moreButtonView = self.moreButton.view {
                if moreButtonView.superview == nil {
                    self.controlsClippingView.addSubview(moreButtonView)
                }
                moreButtonView.isUserInteractionEnabled = !component.slice.item.storyItem.isPending
                transition.setFrame(view: moreButtonView, frame: CGRect(origin: CGPoint(x: headerRightOffset - moreButtonSize.width, y: 2.0), size: moreButtonSize))
                transition.setAlpha(view: moreButtonView, alpha: component.slice.item.storyItem.isPending ? 0.5 : 1.0)
                headerRightOffset -= moreButtonSize.width + 12.0
            }
            
            var isSilentVideo = false
            var isVideo = false
            var soundAlpha: CGFloat = 0.0
            if case let .file(file) = component.slice.item.storyItem.media {
                isVideo = true
                soundAlpha = 1.0
                for attribute in file.attributes {
                    if case let .Video(_, _, flags, _, _, _) = attribute {
                        if flags.contains(.isSilent) {
                            isSilentVideo = true
                            soundAlpha = 0.5
                        }
                    }
                }
            }
            
            let startTime6 = CFAbsoluteTimeGetCurrent()
            
            let soundButtonState = isSilentVideo || component.isAudioMuted
            let soundButtonSize = self.soundButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "anim_storymute",
                            frameRange: soundButtonState ? (0.0 ..< 0.5) : (0.5 ..< 1.0)
                        ),
                        color: .white,
                        startingPosition: .end,
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 33.0, height: 64.0),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        var isSilentVideo = false
                        if case let .file(file) = component.slice.item.storyItem.media {
                            for attribute in file.attributes {
                                if case let .Video(_, _, flags, _, _, _) = attribute {
                                    if flags.contains(.isSilent) {
                                        isSilentVideo = true
                                    }
                                }
                            }
                        }
                        
                        if isSilentVideo {
                            self.displayMutedVideoTooltip()
                        } else {
                            component.toggleAmbientMode()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 33.0, height: 64.0)
            )
            
            if let soundButtonView = self.soundButton.view {
                if soundButtonView.superview == nil {
                    self.controlsClippingView.addSubview(soundButtonView)
                }
                transition.setFrame(view: soundButtonView, frame: CGRect(origin: CGPoint(x: headerRightOffset - soundButtonSize.width, y: 2.0), size: soundButtonSize))
                transition.setAlpha(view: soundButtonView, alpha: soundAlpha)
                
                if isVideo {
                    headerRightOffset -= soundButtonSize.width + 13.0
                }
                
                if let currentSoundButtonState = self.currentSoundButtonState, currentSoundButtonState != soundButtonState {
                    if let lottieView = (soundButtonView as? PlainButtonComponent.View)?.contentView as? LottieComponent.View {
                        lottieView.playOnce()
                    }
                }
                self.currentSoundButtonState = soundButtonState
            }
            
            if isVideo && !isSilentVideo && component.isAudioMuted && (isFirstItem || itemChanged) {
                if isFirstItem {
                    Queue.mainQueue().after(0.4) {
                        self.maybeDisplayUnmuteVideoTooltip()
                    }
                } else {
                    self.maybeDisplayUnmuteVideoTooltip()
                }
            }
            
            let storyPrivacyIcon: StoryPrivacyIconComponent.Privacy?
            if case .user = component.slice.effectivePeer {
                if component.slice.item.storyItem.isCloseFriends {
                    storyPrivacyIcon = .closeFriends
                } else if component.slice.item.storyItem.isContacts {
                    storyPrivacyIcon = .contacts
                } else if component.slice.item.storyItem.isSelectedContacts {
                    storyPrivacyIcon = .selectedContacts
                } else if component.slice.effectivePeer.id == component.context.account.peerId {
                    storyPrivacyIcon = .everyone
                } else {
                    storyPrivacyIcon = nil
                }
            } else {
                storyPrivacyIcon = nil
            }
            
            if let storyPrivacyIcon {
                let privacyIcon: ComponentView<Empty>
                var privacyIconTransition: ComponentTransition = itemChanged ? .immediate : .easeInOut(duration: 0.2)
                if let current = self.privacyIcon {
                    privacyIcon = current
                } else {
                    privacyIconTransition = .immediate
                    privacyIcon = ComponentView()
                    self.privacyIcon = privacyIcon
                }
                let privacyIconSize = privacyIcon.update(
                    transition: privacyIconTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(
                            StoryPrivacyIconComponent(
                                privacy: storyPrivacyIcon,
                                isEditable: component.slice.effectivePeer.id == component.context.account.peerId
                            )
                        ),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            if component.slice.effectivePeer.id == component.context.account.peerId {
                                self.openItemPrivacySettings()
                                return
                            }
                            guard let closeFriendIconView = self.privacyIcon?.view else {
                                return
                            }
                            let tooltipText: String
                            switch storyPrivacyIcon {
                            case .closeFriends:
                                tooltipText = component.strings.Story_TooltipPrivacyCloseFriends2(component.slice.effectivePeer.compactDisplayTitle).string
                            case .contacts:
                                tooltipText = component.strings.Story_TooltipPrivacyContacts(component.slice.effectivePeer.compactDisplayTitle).string
                            case .selectedContacts:
                                tooltipText = component.strings.Story_TooltipPrivacySelectedContacts(component.slice.effectivePeer.compactDisplayTitle).string
                            case .everyone:
                                tooltipText = ""
                            }
                            
                            let tooltipScreen = TooltipScreen(
                                account: component.context.account,
                                sharedContext: component.context.sharedContext,
                                text: .markdown(text: tooltipText),
                                balancedTextLayout: true,
                                style: .default,
                                location: TooltipScreen.Location.point(closeFriendIconView.convert(closeFriendIconView.bounds, to: nil).offsetBy(dx: 1.0, dy: 6.0), .top), displayDuration: .infinite, shouldDismissOnTouch: { _, _ in
                                    return .dismiss(consume: true)
                                }
                            )
                            tooltipScreen.willBecomeDismissed = { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.sendMessageContext.tooltipScreen = nil
                                self.updateIsProgressPaused()
                            }
                            self.sendMessageContext.tooltipScreen?.dismiss()
                            self.sendMessageContext.tooltipScreen = tooltipScreen
                            self.updateIsProgressPaused()
                            component.controller()?.present(tooltipScreen, in: .current)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let closeFriendIconFrame = CGRect(origin: CGPoint(x: headerRightOffset - privacyIconSize.width - 8.0, y: 22.0), size: privacyIconSize)
                if let closeFriendIconView = privacyIcon.view {
                    if closeFriendIconView.superview == nil {
                        self.controlsClippingView.addSubview(closeFriendIconView)
                    }
                    
                    privacyIconTransition.setFrame(view: closeFriendIconView, frame: closeFriendIconFrame)
                    headerRightOffset -= 44.0
                }
            } else if let closeFriendIcon = self.privacyIcon {
                self.privacyIcon = nil
                closeFriendIcon.view?.removeFromSuperview()
            }
            
            let controlsContainerAlpha = (component.hideUI || self.isEditingStory || self.viewListDisplayState != .hidden) ? 0.0 : 1.0
            transition.setAlpha(view: self.controlsContainerView, alpha: controlsContainerAlpha)
            transition.setAlpha(view: self.controlsClippingView, alpha: controlsContainerAlpha)
            transition.setAlpha(view: self.controlsNavigationClippingView, alpha: self.isEditingStory || self.viewListDisplayState != .hidden ? 0.0 : 1.0)
            
            let focusedItem: StoryContentItem? = component.slice.item
            
            var currentLeftInfoItem: InfoItem?
            if focusedItem != nil {
                let leftInfoComponent = AnyComponent(StoryAvatarInfoComponent(context: component.context, peer: component.slice.effectivePeer))
                if let leftInfoItem = self.leftInfoItem, leftInfoItem.component == leftInfoComponent {
                    currentLeftInfoItem = leftInfoItem
                } else {
                    currentLeftInfoItem = InfoItem(component: leftInfoComponent)
                }
            }
            
            if let leftInfoItem = self.leftInfoItem, currentLeftInfoItem?.component != leftInfoItem.component {
                self.leftInfoItem = nil
                if let view = leftInfoItem.view.view {
                    view.layer.animateScale(from: 1.0, to: 0.5, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                }
            }
            
            var currentCenterInfoItem: InfoItem?
            if let focusedItem {
                var counters: StoryAuthorInfoComponent.Counters?
                if focusedItem.dayCounters != nil, let position = focusedItem.position {
                    counters = StoryAuthorInfoComponent.Counters(
                        position: position,
                        totalCount: component.slice.totalCount
                    )
                }
                
                let centerInfoComponent = AnyComponent(StoryAuthorInfoComponent(
                    context: component.context,
                    strings: component.strings,
                    peer: component.slice.effectivePeer,
                    forwardInfo: component.slice.item.storyItem.forwardInfo,
                    author: component.slice.item.storyItem.author,
                    timestamp: component.slice.item.storyItem.timestamp,
                    counters: counters,
                    isEdited: component.slice.item.storyItem.isEdited
                ))
                if let centerInfoItem = self.centerInfoItem, centerInfoItem.component == centerInfoComponent {
                    currentCenterInfoItem = centerInfoItem
                } else {
                    currentCenterInfoItem = InfoItem(component: centerInfoComponent)
                }
            }
            
            if let centerInfoItem = self.centerInfoItem, currentCenterInfoItem?.component != centerInfoItem.component {
                self.centerInfoItem = nil
                if let view = centerInfoItem.view.view {
                    view.removeFromSuperview()
                }
            }
            
            if let currentCenterInfoItem {
                self.centerInfoItem = currentCenterInfoItem
                
                let centerInfoItemSize = currentCenterInfoItem.view.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(content: currentCenterInfoItem.component, effectAlignment: .center, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let forwardInfo = component.slice.item.storyItem.forwardInfo, case let .known(peer, _, _) = forwardInfo {
                            if peer.id == component.context.account.peerId {
                                self.navigateToMyStories()
                            } else {
                                self.navigateToPeer(peer: peer, chat: false)
                            }
                        } else if let author = component.slice.item.storyItem.author {
                            if author.id == component.context.account.peerId {
                                self.navigateToMyStories()
                            } else {
                                self.navigateToPeer(peer: author, chat: false)
                            }
                        } else {
                            if component.slice.effectivePeer.id == component.context.account.peerId {
                                self.navigateToMyStories()
                            } else {
                                self.navigateToPeer(peer: component.slice.effectivePeer, chat: false)
                            }
                        }
                    })),
                    environment: {},
                    containerSize: CGSize(width: headerRightOffset - 34.0, height: 44.0)
                )
                if let view = currentCenterInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.controlsClippingView.insertSubview(view, belowSubview: self.closeButton)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: centerInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        //view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    
                    transition.setAlpha(view: view, alpha: self.isEditingStory ? 0.0 : 1.0)
                }
            }
            
            if let currentLeftInfoItem, !self.isAnimatingOut {
                self.leftInfoItem = currentLeftInfoItem
                
                let leftInfoItemSize = currentLeftInfoItem.view.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(content: currentLeftInfoItem.component, effectAlignment: .center, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        if component.slice.effectivePeer.id == component.context.account.peerId {
                            self.navigateToMyStories()
                        } else {
                            self.navigateToPeer(peer: component.slice.effectivePeer, chat: false)
                        }
                    })),
                    environment: {},
                    containerSize: CGSize(width: 32.0, height: 32.0)
                )
                if let view = currentLeftInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.controlsClippingView.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 12.0, y: 18.0), size: leftInfoItemSize))
                    
                    if animateIn, !isFirstTime, !transition.animation.isImmediate {
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        view.layer.animateScale(from: 0.5, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    
                    transition.setAlpha(view: view, alpha: self.isEditingStory ? 0.0 : 1.0)
                }
            }
            
            let startTime7 = CFAbsoluteTimeGetCurrent()
            
            let topGradientHeight: CGFloat = 90.0
            let topContentGradientRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentFrame.width, height: topGradientHeight))
            transition.setPosition(view: self.topContentGradientView, position: topContentGradientRect.center)
            transition.setBounds(view: self.topContentGradientView, bounds: CGRect(origin: CGPoint(), size: topContentGradientRect.size))
            
            var inputPanelFrameValue: CGRect?
            if let inputPanelSize {
                let inputPanelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - inputPanelSize.width) / 2.0), y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
                inputPanelFrameValue = inputPanelFrame
                var inputPanelAlpha: CGFloat = (component.slice.effectivePeer.id == component.context.account.peerId || component.hideUI || self.isEditingStory || component.slice.item.storyItem.isPending) ? 0.0 : 1.0
                if case .regular = component.metrics.widthClass {
                    inputPanelAlpha *= component.visibilityFraction
                }
                inputPanelAlpha *= (1.0 - min(1.0, viewListHeightMidFraction * 1.3))
                let inputPanelScale = (1.0 - viewListHeightMidFraction * 0.45)
                if let inputPanelView = self.inputPanel.view {
                    if inputPanelView.superview == nil {
                        self.componentContainerView.addSubview(inputPanelView)
                    }
                    
                    var inputPanelOffset: CGFloat = 0.0
                    if component.slice.effectivePeer.id != component.context.account.peerId && !self.inputPanelExternalState.isEditing {
                        let bandingOffset = scrollingRubberBandingOffset(offset: verticalPanFraction * availableSize.height, bandingStart: 0.0, range: 10.0)
                        inputPanelOffset = -max(0.0, min(10.0, bandingOffset))
                    }
                    
                    let finalInputPanelFrame = inputPanelFrame.offsetBy(dx: 0.0, dy: inputPanelOffset)
                    inputPanelTransition.setPosition(view: inputPanelView, position: finalInputPanelFrame.center)
                    inputPanelTransition.setBounds(view: inputPanelView, bounds: CGRect(origin: .zero, size: finalInputPanelFrame.size))
                    inputPanelTransition.setScale(view: inputPanelView, scale: inputPanelScale)
                    transition.setAlpha(view: inputPanelView, alpha: inputPanelAlpha)
                }
            }
            
            if let captionItem = self.captionItem, captionItem.itemId != component.slice.item.id {
                self.captionItem = nil
                if let captionItemView = captionItem.view.view {
                    captionItemView.removeFromSuperview()
                }
            }
            
            if !isUnsupported, !component.slice.item.storyItem.text.isEmpty || component.slice.item.storyItem.forwardInfo != nil {
                var captionItemTransition = transition
                let captionItem: CaptionItem
                if let current = self.captionItem {
                    captionItem = current
                } else {
                    if !transition.animation.isImmediate {
                        captionItemTransition = .immediate
                    }
                    captionItem = CaptionItem(itemId: component.slice.item.id)
                    self.captionItem = captionItem
                }
                
                var enableEntities = true
                if case .user = component.slice.effectivePeer {
                    if !component.slice.effectivePeer.isService && !component.slice.effectivePeer.isPremium {
                        enableEntities = false
                    }
                }
                var forwardInfoStory: Signal<EngineStoryItem?, NoError>? = nil
                if let forwardInfo = component.slice.item.storyItem.forwardInfo, case let .known(peer, id, _) = forwardInfo {
                    forwardInfoStory = component.slice.forwardInfoStories[StoryId(peerId: peer.id, id: id)]?.get()
                }
                let captionSize = captionItem.view.update(
                    transition: captionItemTransition,
                    component: AnyComponent(StoryContentCaptionComponent(
                        externalState: captionItem.externalState,
                        context: component.context,
                        strings: component.strings,
                        theme: component.theme,
                        text: component.slice.item.storyItem.text,
                        author: component.slice.effectivePeer,
                        forwardInfo: component.slice.item.storyItem.forwardInfo,
                        forwardInfoStory: forwardInfoStory,
                        entities: enableEntities ? component.slice.item.storyItem.entities : [],
                        entityFiles: component.slice.item.entityFiles,
                        action: { [weak self] action in
                            guard let self, let component = self.component else {
                                return
                            }
                            switch action {
                            case let .url(url, concealed):
                                let _ = openUserGeneratedUrl(context: component.context, peerId: component.slice.effectivePeer.id, url: url, concealed: concealed, skipUrlAuth: false, skipConcealedAlert: false, forceDark: true, present: { [weak self] c in
                                    guard let self, let component = self.component, let controller = component.controller() else {
                                        return
                                    }
                                    controller.present(c, in: .window(.root))
                                }, openResolved: { [weak self] resolved in
                                    guard let self else {
                                        return
                                    }
                                    self.sendMessageContext.openResolved(view: self, result: resolved, forceExternal: false, concealed: concealed)
                                }, alertDisplayUpdated: { [weak self] alertController in
                                    guard let self else {
                                        return
                                    }
                                    self.sendMessageContext.statusController = alertController
                                    self.updateIsProgressPaused()
                                })
                            case let .textMention(value):
                                self.sendMessageContext.openPeerMention(view: self, name: value)
                            case let .peerMention(peerId, _):
                                self.sendMessageContext.openPeerMention(view: self, peerId: peerId)
                            case let .hashtag(username, value):
                                self.sendMessageContext.openHashtag(view: self, hashtag: value, peerName: username)
                            case .bankCard:
                                break
                            case .customEmoji:
                                break
                            }
                        },
                        longTapAction: { [weak self] action in
                            guard let self, let component = self.component else {
                                return
                            }
                            self.sendMessageContext.presentTextEntityActions(view: self, action: action, openUrl: { [weak self] url, concealed in
                                let _ = openUserGeneratedUrl(context: component.context, peerId: component.slice.effectivePeer.id, url: url, concealed: concealed, skipUrlAuth: false, skipConcealedAlert: false, present: { [weak self] c in
                                    guard let self, let component = self.component, let controller = component.controller() else {
                                        return
                                    }
                                    controller.present(c, in: .window(.root))
                                }, openResolved: { [weak self] resolved in
                                    guard let self else {
                                        return
                                    }
                                    self.sendMessageContext.openResolved(view: self, result: resolved, forceExternal: false, concealed: concealed)
                                })
                            })
                        },
                        textSelectionAction: { [weak self] text, action in
                            guard let self, let component = self.component else {
                                return
                            }
                            switch action {
                            case .copy:
                                storeAttributedTextInPasteboard(text)
                                
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                let undoController = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, appearance: UndoOverlayController.Appearance(isBlurred: true), action: { _ in true })
                                self.sendMessageContext.tooltipScreen?.dismiss()
                                self.sendMessageContext.tooltipScreen = undoController
                                component.controller()?.present(undoController, in: .current)
                            case .share:
                                self.sendMessageContext.performShareTextAction(view: self, text: text.string)
                            case .lookup:
                                self.sendMessageContext.performLookupTextAction(view: self, text: text.string)
                            case .speak:
                                if let speechHolder = speakText(context: component.context, text: text.string) {
                                    speechHolder.completion = { [weak self, weak speechHolder] in
                                        guard let self else {
                                            return
                                        }
                                        if self.sendMessageContext.currentSpeechHolder === speechHolder {
                                            self.sendMessageContext.currentSpeechHolder = nil
                                        }
                                    }
                                    self.sendMessageContext.currentSpeechHolder = speechHolder
                                }
                            case .translate:
                                self.sendMessageContext.performTranslateTextAction(view: self, text: text.string, entities: [])
                            case .quote:
                                break
                            }
                        },
                        controller: { [weak self] in
                            guard let self, let component = self.component else {
                                return nil
                            }
                            return component.controller()
                        },
                        openStory: { [weak self] peer, story in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let story {
                                let context = component.context
                                let peerId = component.slice.effectivePeer.id
                                let currentResult: ResolvedUrl = .story(peerId: peerId, id: component.slice.item.storyItem.id)
                                
                                self.sendMessageContext.openResolved(view: self, result: .story(peerId: peer.id, id: story.id), completion: { [weak self] in
                                    guard let self, let controller = self.component?.controller() as? StoryContainerScreen else {
                                        return
                                    }
                                    if let nextController = controller.navigationController?.viewControllers.last as? StoryContainerScreen {
                                        nextController.customBackAction = { [weak nextController] in
                                            context.sharedContext.openResolvedUrl(
                                                currentResult,
                                                context: context,
                                                urlContext: .generic,
                                                navigationController: nextController?.navigationController as? NavigationController,
                                                forceExternal: false,
                                                forceUpdate: false,
                                                openPeer: { _, _ in
                                                },
                                                sendFile: nil,
                                                sendSticker: nil,
                                                sendEmoji: nil,
                                                requestMessageActionUrlAuth: nil,
                                                joinVoiceChat: nil,
                                                present: { _, _ in
                                                },
                                                dismissInput: {
                                                },
                                                contentContext: nil,
                                                progress: nil,
                                                completion: { [weak nextController] in
                                                    Queue.mainQueue().after(0.5) {
                                                        nextController?.dismissWithoutTransitionOut()
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    Queue.mainQueue().after(0.5) {
                                        controller.dismissWithoutTransitionOut()
                                    }
                                })
                            } else {
                                for mediaArea in component.slice.item.storyItem.mediaAreas {
                                    if case .channelMessage = mediaArea {
                                        self.sendMessageContext.activateMediaArea(view: self, mediaArea: mediaArea, immediate: true)
                                        break
                                    }
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: contentFrame.height - 60.0)
                )
                captionItem.view.parentState = state
                let captionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.height - captionSize.height), size: captionSize)
                if let captionItemView = captionItem.view.view {
                    if captionItemView.superview == nil {
                        if case .regular = component.metrics.widthClass {
                            self.topContentGradientView.layer.cornerRadius = 12.0
                            self.topContentGradientView.clipsToBounds = true
                            captionItemView.layer.cornerRadius = 12.0
                            captionItemView.clipsToBounds = true
                        }
                        self.controlsContainerView.insertSubview(captionItemView, aboveSubview: self.contentDimView)
                    }
                    captionItemTransition.setFrame(view: captionItemView, frame: captionFrame)
                    
                    var captionAlpha: CGFloat = (component.hideUI || self.isEditingStory || self.inputPanelExternalState.isEditing) ? 0.0 : 1.0
                    captionAlpha *= (1.0 - itemLayout.contentScaleFraction)
                    captionItemTransition.setAlpha(view: captionItemView, alpha: captionAlpha)
                }
            }
            
            let reactionsAnchorRect: CGRect
            
            if self.inputPanelExternalState.isEditing, let inputPanelFrameValue {
                reactionsAnchorRect = CGRect(origin: CGPoint(x: inputPanelFrameValue.maxX - 40.0, y: inputPanelFrameValue.minY + 9.0), size: CGSize(width: 32.0, height: 32.0)).insetBy(dx: -4.0, dy: -4.0)
            } else if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, let likeButtonView = inputPanelView.likeButtonView {
                var likeRect = likeButtonView.convert(likeButtonView.bounds, to: self)
                likeRect.origin.y -= 15.0
                likeRect.size.height += 15.0
                likeRect.origin.x -= 30.0
                reactionsAnchorRect = likeRect
            } else {
                reactionsAnchorRect = CGRect()
            }
            
            var effectiveDisplayReactions = false
            if self.inputPanelExternalState.isEditing && !self.inputPanelExternalState.hasText {
                effectiveDisplayReactions = true
            }
            if self.displayLikeReactions {
                effectiveDisplayReactions = true
            }
            if self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil {
                effectiveDisplayReactions = false
            }
            if self.sendMessageContext.recordedAudioPreview != nil {
                effectiveDisplayReactions = false
            }
            if self.sendMessageContext.hasRecordedVideoPreview {
                effectiveDisplayReactions = false
            }
            if self.voiceMessagesRestrictedTooltipController != nil {
                effectiveDisplayReactions = false
            }
            if self.sendMessageContext.currentInputMode != .text {
                effectiveDisplayReactions = false
            }
            
            if let reactionContextNode = self.reactionContextNode, self.willDismissReactionContextNode !== reactionContextNode, (reactionContextNode.isReactionSearchActive && !reactionContextNode.isAnimatingOutToReaction && !reactionContextNode.isAnimatingOut) {
                effectiveDisplayReactions = true
            }
            
            if let reactionItems = component.availableReactions?.reactionItems, effectiveDisplayReactions {
                let reactionContextNode: ReactionContextNode
                var reactionContextNodeTransition = transition
                if let current = self.reactionContextNode {
                    reactionContextNode = current
                } else {
                    reactionContextNodeTransition = .immediate
                    reactionContextNode = ReactionContextNode(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        presentationData: component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme),
                        items: reactionItems.map { ReactionContextItem.reaction(item: $0, icon: .none) },
                        selectedItems: component.slice.item.storyItem.myReaction.flatMap { Set([$0]) } ?? Set(),
                        title: self.displayLikeReactions ? nil : (isGroup ? component.strings.Story_SendReactionAsGroupMessage : component.strings.Story_SendReactionAsMessage),
                        reactionsLocked: false,
                        alwaysAllowPremiumReactions: false,
                        allPresetReactionsAreAvailable: false,
                        getEmojiContent: { [weak self] animationCache, animationRenderer in
                            guard let self, let component = self.component else {
                                preconditionFailure()
                            }
                            
                            let mappedReactionItems: [EmojiComponentReactionItem] = reactionItems.map { reaction -> EmojiComponentReactionItem in
                                return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                            }
                            
                            var selectedItems: Set<AnyHashable> = Set()
                            if let myReaction = component.slice.item.storyItem.myReaction {
                                switch myReaction {
                                case .builtin, .stars:
                                    if let availableReactions = component.availableReactions {
                                        for availableReaction in availableReactions.reactionItems {
                                            if availableReaction.reaction.rawValue == myReaction {
                                                selectedItems.insert(AnyHashable(availableReaction.stillAnimation.fileId))
                                                break
                                            }
                                        }
                                    }
                                case let .custom(fileId):
                                    selectedItems.insert(AnyHashable(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)))
                                }
                            }
                            
                            return EmojiPagerContentComponent.emojiInputData(
                                context: component.context,
                                animationCache: animationCache,
                                animationRenderer: animationRenderer,
                                isStandalone: false,
                                subject: .reaction(onlyTop: false),
                                hasTrending: false,
                                topReactionItems: mappedReactionItems,
                                areUnicodeEmojiEnabled: false,
                                areCustomEmojiEnabled: true,
                                chatPeerId: component.context.account.peerId,
                                selectedItems: selectedItems,
                                premiumIfSavedMessages: false
                            )
                        },
                        isExpandedUpdated: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: ComponentTransition(transition))
                        },
                        requestLayout: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: ComponentTransition(transition))
                        },
                        requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: ComponentTransition(transition))
                        }
                    )
                    reactionContextNode.displayTail = self.displayLikeReactions
                    reactionContextNode.forceTailToRight = self.displayLikeReactions
                    reactionContextNode.forceDark = true
                    self.reactionContextNode = reactionContextNode
                    
                    if let tempReactionsGesture = self.tempReactionsGesture {
                        tempReactionsGesture.externalUpdated = { [weak self] view, point in
                            guard let self, let view, let reactionContextNode = self.reactionContextNode else {
                                return
                            }
                            let presentationPoint = view.convert(point, to: reactionContextNode.view)
                            reactionContextNode.highlightGestureMoved(location: presentationPoint, hover: false)
                        }
                        tempReactionsGesture.externalEnded = { [weak self] viewAndPoint in
                            guard let self, let viewAndPoint, let reactionContextNode = self.reactionContextNode else {
                                return
                            }
                            let _ = viewAndPoint
                            /*let (view, point) = viewAndPoint
                            let presentationPoint = view.convert(point, to: reactionContextNode.view)
                            let _ = presentationPoint*/
                            reactionContextNode.highlightGestureFinished(performAction: true)
                        }
                    }
                    
                    reactionContextNode.reactionSelected = { [weak self, weak reactionContextNode] updateReaction, _ in
                        guard let self, let reactionContextNode else {
                            return
                        }
                        let action: () -> Void = { [weak self, weak reactionContextNode] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            if self.displayLikeReactions {
                                if component.slice.item.storyItem.myReaction == updateReaction.reaction {
                                    let _ = component.context.engine.messages.setStoryReaction(peerId: component.slice.effectivePeer.id, id: component.slice.item.storyItem.id, reaction: nil).startStandalone()
                                    self.displayLikeReactions = false
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                                } else {
                                    if hasFirstResponder(self) {
                                        self.sendMessageContext.currentInputMode = .text
                                        self.endEditing(true)
                                    }
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                                    
                                    self.waitingForReactionAnimateOutToLike = updateReaction.reaction
                                    let _ = component.context.engine.messages.setStoryReaction(peerId: component.slice.effectivePeer.id, id: component.slice.item.id.id, reaction: updateReaction.reaction).startStandalone()
                                }
                            } else {
                                let _ = (component.context.engine.stickers.availableReactions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { [weak self, weak reactionContextNode] availableReactions in
                                    guard let self, let component = self.component, let availableReactions else {
                                        return
                                    }
                                    
                                    var animation: TelegramMediaFile?
                                    for reaction in availableReactions.reactions {
                                        if reaction.value == updateReaction.reaction {
                                            animation = reaction.centerAnimation?._parse()
                                            break
                                        }
                                    }
                                                                
                                    let targetView = UIView(frame: CGRect(origin: CGPoint(x: floor((self.bounds.width - 100.0) * 0.5), y: floor((self.bounds.height - 100.0) * 0.5)), size: CGSize(width: 100.0, height: 100.0)))
                                    targetView.isUserInteractionEnabled = false
                                    self.addSubview(targetView)
                                    
                                    if let reactionContextNode {
                                        reactionContextNode.willAnimateOutToReaction(value: updateReaction.reaction)
                                        reactionContextNode.animateOutToReaction(value: updateReaction.reaction, targetView: targetView, hideNode: false, animateTargetContainer: nil, addStandaloneReactionAnimation: "".isEmpty ? nil : { [weak self] standaloneReactionAnimation in
                                            guard let self else {
                                                return
                                            }
                                            
                                            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                                self.standaloneReactionAnimation = nil
                                                standaloneReactionAnimation.view.removeFromSuperview()
                                            }
                                            self.standaloneReactionAnimation = standaloneReactionAnimation
                                            
                                            standaloneReactionAnimation.frame = self.bounds
                                            self.addSubview(standaloneReactionAnimation.view)
                                        }, onHit: nil, completion: { [weak targetView, weak reactionContextNode] in
                                            targetView?.removeFromSuperview()
                                            if let reactionContextNode {
                                                reactionContextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak reactionContextNode] _ in
                                                    reactionContextNode?.view.removeFromSuperview()
                                                })
                                            }
                                        })
                                    }
                                    
                                    if hasFirstResponder(self) {
                                        self.sendMessageContext.currentInputMode = .text
                                        self.endEditing(true)
                                    }
                                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                                                                
                                    var text = ""
                                    var messageAttributes: [MessageAttribute] = []
                                    var inlineStickers: [MediaId : Media] = [:]
                                    switch updateReaction {
                                    case let .builtin(textValue):
                                        text = textValue
                                    case let .custom(fileId, file):
                                        if let file {
                                            animation = file
                                            loop: for attribute in file.attributes {
                                                switch attribute {
                                                case let .CustomEmoji(_, _, displayText, _):
                                                    text = displayText
                                                    let length = (text as NSString).length
                                                    messageAttributes = [TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< length, type: .CustomEmoji(stickerPack: nil, fileId: fileId))])]
                                                    inlineStickers = [file.fileId: file]
                                                    break loop
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    case .stars:
                                        break
                                    }
                                    
                                    if let sendPaidMessageStars = component.slice.additionalPeerData.sendPaidMessageStars {
                                        messageAttributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
                                    }

                                    let message: EnqueueMessage = .message(
                                        text: text,
                                        attributes: messageAttributes,
                                        inlineStickers: inlineStickers,
                                        mediaReference: nil,
                                        threadId: nil,
                                        replyToMessageId: nil,
                                        replyToStoryId: component.slice.item.id,
                                        localGroupingKey: nil,
                                        correlationId: nil,
                                        bubbleUpEmojiOrStickersets: []
                                    )
                                    
                                    let context = component.context
                                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                    let presentController = component.presentController
                                    let peer = component.slice.effectivePeer
                                    
                                    let _ = (enqueueMessages(account: context.account, peerId: peer.id, messages: [message])
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] messageIds in
                                        if let animation, let self, let component = self.component {
                                            let controller = UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .sticker(context: context, file: animation, loop: false, title: nil, text: component.strings.Story_ToastReactionSent, undoText: component.strings.Story_ToastViewInChat, customAction: { [weak self] in
                                                    if let messageId = messageIds.first, let self {
                                                        self.navigateToPeer(peer: peer, chat: true, subject: messageId.flatMap { .message(id: .id($0), highlight: nil, timecode: nil, setupReply: false) })
                                                    }
                                                }),
                                                elevatedLayout: false,
                                                animateInAsReplacement: false,
                                                action: { [weak self] _ in
                                                    self?.sendMessageContext.tooltipScreen = nil
                                                    self?.updateIsProgressPaused()
                                                    return false
                                                }
                                            )
                                            self.sendMessageContext.tooltipScreen?.dismiss()
                                            self.sendMessageContext.tooltipScreen = controller
                                            self.updateIsProgressPaused()
                                            presentController(controller, nil)
                                        }
                                    })
                                })
                            }
                        }
                        if self.displayLikeReactions {
                            if component.slice.item.storyItem.myReaction == updateReaction.reaction {
                                action()
                            } else {
                                self.sendMessageContext.performWithPossibleStealthModeConfirmation(view: self, action: {
                                    action()
                                })
                            }
                        } else {
                            self.sendMessageContext.performWithPossibleStealthModeConfirmation(view: self, action: {
                                self.sendMessageContext.presentPaidMessageAlertIfNeeded(view: self, completion: {
                                    action()
                                })
                            })
                        }
                    }
                    
                    reactionContextNode.premiumReactionsSelected = { [weak self] file in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        guard let file else {
                            let context = component.context
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, forceDark: true, action: {
                                let controller = PremiumIntroScreen(context: context, source: .reactions)
                                replaceImpl?(controller)
                            })
                            controller.disposed = { [weak self] in
                                self?.updateIsProgressPaused()
                            }
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            component.controller()?.push(controller)
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: component.context, file: file, loop: true, title: nil, text: presentationData.strings.Chat_PremiumReactionToastTitle, undoText: presentationData.strings.Chat_PremiumReactionToastAction, customAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let context = component.context
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, forceDark: true, action: {
                                let controller = PremiumIntroScreen(context: context, source: .reactions)
                                replaceImpl?(controller)
                            })
                            controller.disposed = { [weak self] in
                                self?.updateIsProgressPaused()
                            }
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            component.controller()?.push(controller)
                        }), elevatedLayout: false, animateInAsReplacement: false, appearance: UndoOverlayController.Appearance(isBlurred: true), action: { _ in true })
                        component.controller()?.present(undoController, in: .current)
                    }
                }
                
                var animateReactionsIn = false
                if reactionContextNode.view.superview == nil {
                    animateReactionsIn = true
                    self.componentContainerView.addSubnode(reactionContextNode)
                }
                
                if reactionContextNode.isAnimatingOutToReaction {
                    if !reactionContextNode.isAnimatingOut {
                        reactionContextNode.animateOut(to: reactionsAnchorRect, animatingOutToReaction: true)
                    }
                } else {
                    reactionContextNodeTransition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                    reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: !self.displayLikeReactions, isCoveredByInput: false, isAnimatingOut: false, transition: reactionContextNodeTransition.containedViewLayoutTransition)
                    
                    if animateReactionsIn {
                        reactionContextNode.animateIn(from: reactionsAnchorRect)
                    }
                }
                
                if let waitingReaction = self.waitingForReactionAnimateOutToLike, component.slice.item.storyItem.myReaction == waitingReaction {
                    self.waitingForReactionAnimateOutToLike = nil
                        
                    if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, let likeButtonView = inputPanelView.likeIconView {
                        reactionContextNode.willAnimateOutToReaction(value: waitingReaction)
                        reactionContextNode.animateOutToReaction(value: waitingReaction, targetView: likeButtonView, hideNode: true, animateTargetContainer: nil, addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                            guard let self else {
                                return
                            }
                            
                            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                self.standaloneReactionAnimation = nil
                                standaloneReactionAnimation.view.removeFromSuperview()
                            }
                            self.standaloneReactionAnimation = standaloneReactionAnimation
                            
                            standaloneReactionAnimation.frame = self.bounds
                            self.componentContainerView.addSubview(standaloneReactionAnimation.view)
                        }, onHit: nil, completion: { [weak reactionContextNode] in
                            if let reactionContextNode {
                                reactionContextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak reactionContextNode] _ in
                                    reactionContextNode?.view.removeFromSuperview()
                                })
                            }
                        })
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }
                        self.displayLikeReactions = false
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                }
            } else {
                if let reactionContextNode = self.reactionContextNode {
                    if let disappearingReactionContextNode = self.disappearingReactionContextNode {
                        disappearingReactionContextNode.view.removeFromSuperview()
                    }
                    self.disappearingReactionContextNode = reactionContextNode
                    
                    self.reactionContextNode = nil
                    if reactionContextNode.isAnimatingOutToReaction {
                        if !reactionContextNode.isAnimatingOut {
                            reactionContextNode.animateOut(to: reactionsAnchorRect, animatingOutToReaction: true)
                        }
                    } else {
                        let reactionTransition = ComponentTransition.easeInOut(duration: 0.25)
                        reactionTransition.setAlpha(view: reactionContextNode.view, alpha: 0.0, completion: { [weak reactionContextNode] _ in
                            reactionContextNode?.view.removeFromSuperview()
                        })
                    }
                }
            }
            if let reactionContextNode = self.disappearingReactionContextNode {
                if !reactionContextNode.isAnimatingOutToReaction {
                    transition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                    reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: reactionContextNode.centerAligned, isCoveredByInput: false, isAnimatingOut: false, transition: transition.containedViewLayoutTransition)
                }
            }
            
            let bottomGradientHeight = (inputPanelSize?.height ?? 0.0) + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            //transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: 0.0)
            
            var topGradientAlpha: CGFloat = (self.viewListDisplayState != .hidden || self.isEditingStory) ? 0.0 : 1.0
            var normalDimAlpha: CGFloat = 0.0
            var forceDimAnimation = false
            if let captionItem = self.captionItem {
                if captionItem.externalState.isExpanded {
                    topGradientAlpha = 0.0
                }
                normalDimAlpha = captionItem.externalState.isExpanded ? 1.0 : 0.0
                if transition.animation.isImmediate && transition.userData(StoryContentCaptionComponent.TransitionHint.self)?.kind == .isExpandedUpdated {
                    forceDimAnimation = true
                }
            }
            var dimAlpha: CGFloat = (inputPanelIsOverlay || self.inputPanelExternalState.isEditing) ? 1.0 : normalDimAlpha
            if component.hideUI || self.viewListDisplayState != .hidden || self.isEditingStory {
                dimAlpha = 0.0
            }
            
            transition.setFrame(view: self.contentDimView, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            if transition.animation.isImmediate && forceDimAnimation && self.topContentGradientView.alpha != topGradientAlpha {
                ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)).setAlpha(view: self.topContentGradientView, alpha: topGradientAlpha)
            } else {
                transition.setAlpha(view: self.topContentGradientView, alpha: topGradientAlpha)
            }
            
            if transition.animation.isImmediate && forceDimAnimation && self.contentDimView.alpha != dimAlpha {
                ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)).setAlpha(view: self.contentDimView, alpha: dimAlpha)
            } else {
                transition.setAlpha(view: self.contentDimView, alpha: dimAlpha)
            }
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scroller, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.scroller.contentSize = CGSize(width: itemLayout.fullItemScrollDistance * CGFloat(max(0, component.slice.allItems.count - 1)) + availableSize.width, height: availableSize.height)
            self.scroller.isScrollEnabled = itemLayout.contentScaleFraction >= 1.0 - 0.0001
            
            if let centralIndex = component.slice.allItems.firstIndex(where: { $0.id == component.slice.item.id }) {
                let centralX = itemLayout.fullItemScrollDistance * CGFloat(centralIndex)
                if itemLayout.contentScaleFraction <= 0.0001 {
                    if abs(self.scroller.contentOffset.x - centralX) > CGFloat.ulpOfOne {
                        self.scroller.contentOffset = CGPoint(x: centralX, y: 0.0)
                    }
                } else if resetScrollingOffsetWithItemTransition {
                    let deltaX = centralX - self.scroller.contentOffset.x
                    if abs(deltaX) > CGFloat.ulpOfOne {
                        self.scroller.contentOffset = CGPoint(x: centralX, y: 0.0)
                        //itemsTransition.animateBoundsOrigin(view: self.itemsContainerView, from: CGPoint(x: deltaX, y: 0.0), to: CGPoint(), additive: true)
                    }
                }
            }
            
            let startTime8 = CFAbsoluteTimeGetCurrent()
            
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: itemsTransition)
            
            let startTime9 = CFAbsoluteTimeGetCurrent()
            
            let navigationStripSideInset: CGFloat = 8.0
            let navigationStripTopInset: CGFloat = 8.0
            if let focusedItem, let visibleItem = self.visibleItems[focusedItem.id], let index = focusedItem.position {
                var index = max(0, min(index, component.slice.totalCount - 1))
                var count = component.slice.totalCount
                if let dayCounters = focusedItem.dayCounters {
                    index = dayCounters.position
                    count = dayCounters.totalCount
                }
                
                let isSeeking = component.isProgressPaused && component.hideUI && isVideo
                
                var navigationStripTransition = transition
                if let previousComponent, (previousComponent.isProgressPaused && component.hideUI) != isSeeking {
                    navigationStripTransition = .easeInOut(duration: 0.3)
                }
                let navigationStripSize = self.navigationStrip.update(
                    transition: navigationStripTransition,
                    component: AnyComponent(MediaNavigationStripComponent(
                        index: index,
                        count: count,
                        isSeeking: isSeeking
                    )),
                    environment: {
                        MediaNavigationStripComponent.EnvironmentType(
                            currentProgress: visibleItem.currentProgress,
                            currentIsBuffering: visibleItem.isBuffering
                        )
                    },
                    containerSize: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 6.0)
                )
                if let navigationStripView = self.navigationStrip.view {
                    if navigationStripView.superview == nil {
                        navigationStripView.isUserInteractionEnabled = false
                        self.controlsNavigationClippingView.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: navigationStripSideInset, y: navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: navigationStripSize.height)))
                    
                    let hideUI = component.hideUI && !isVideo
                    transition.setAlpha(view: navigationStripView, alpha: self.isEditingStory || hideUI ? 0.0 : 1.0)
                }
                
                let seekLabelSize = self.seekLabel.update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: component.strings.Story_SlideToSeek, font: Font.semibold(14.0), color: .white)),
                    environment: {},
                    containerSize: availableSize
                )
                if let seekLabelView = self.seekLabel.view {
                    if seekLabelView.superview == nil {
                        seekLabelView.alpha = 0.0
                        seekLabelView.isUserInteractionEnabled = false
                        self.controlsNavigationClippingView.addSubview(seekLabelView)
                    }
                    seekLabelView.bounds = CGRect(origin: .zero, size: seekLabelSize)
                    navigationStripTransition.setPosition(view: seekLabelView, position: CGPoint(x: availableSize.width / 2.0, y: navigationStripTopInset + 22.0 + 6.0 - (!isSeeking ? 12.0 : 0.0)))
                    navigationStripTransition.setAlpha(view: seekLabelView, alpha: isSeeking ? 1.0 : 0.0)
                    navigationStripTransition.setScale(view: seekLabelView, scale: isSeeking ? 1.0 : 0.02)
                }
            }
            
            component.externalState.derivedMediaSize = contentFrame.size
            if component.slice.effectivePeer.id == component.context.account.peerId {
                component.externalState.derivedBottomInset = availableSize.height - itemsContainerFrame.maxY
            } else if let inputPanelFrameValue {
                component.externalState.derivedBottomInset = availableSize.height - min(inputPanelFrameValue.minY, contentFrame.maxY)
            } else {
                component.externalState.derivedBottomInset = availableSize.height - itemsContainerFrame.maxY
            }
            
            if !"".isEmpty {
                print("inner update time:\n" +
                      "  1: \((CFAbsoluteTimeGetCurrent() - startTime1) * 1000.0) ms\n" +
                      "  2: \((CFAbsoluteTimeGetCurrent() - startTime2) * 1000.0) ms\n" +
                      "  2.1: \((CFAbsoluteTimeGetCurrent() - startTime21) * 1000.0) ms\n" +
                      "  2.2: \((CFAbsoluteTimeGetCurrent() - startTime22) * 1000.0) ms\n" +
                      "  2.3: \((CFAbsoluteTimeGetCurrent() - startTime23) * 1000.0) ms\n" +
                      "  3: \((CFAbsoluteTimeGetCurrent() - startTime3) * 1000.0) ms\n" +
                      "  4: \((CFAbsoluteTimeGetCurrent() - startTime4) * 1000.0) ms\n" +
                      "  5: \((CFAbsoluteTimeGetCurrent() - startTime5) * 1000.0) ms\n" +
                      "  6: \((CFAbsoluteTimeGetCurrent() - startTime6) * 1000.0) ms\n" +
                      "  7: \((CFAbsoluteTimeGetCurrent() - startTime7) * 1000.0) ms\n" +
                      "  8: \((CFAbsoluteTimeGetCurrent() - startTime8) * 1000.0) ms\n" +
                      "  9: \((CFAbsoluteTimeGetCurrent() - startTime9) * 1000.0) ms\n"
                )
            }
            
            if let scheduledStoryUnpinnedUndoOverlay = self.scheduledStoryUnpinnedUndoOverlay {
                self.scheduledStoryUnpinnedUndoOverlay = nil
                if !self.isAnimatingOut && !component.isDismissed {
                    component.presentController(scheduledStoryUnpinnedUndoOverlay, nil)
                }
            }
            
            return contentSize
        }
        
        private func presentPrivacyTooltip(privacy: EngineStoryPrivacy) {
            guard let component = self.component else {
                return
            }
            
            let text: String
            if privacy.base == .contacts {
                text = component.strings.Story_PrivacyTooltipContacts
            } else if privacy.base == .closeFriends {
                text = component.strings.Story_PrivacyTooltipCloseFriends
            } else if privacy.base == .nobody {
                if !privacy.additionallyIncludePeers.isEmpty {
                    let value = component.strings.Story_PrivacyTooltipSelectedContacts_Contacts(Int32(privacy.additionallyIncludePeers.count))
                    text = component.strings.Story_PrivacyTooltipSelectedContactsFull(value).string
                } else {
                    text = component.strings.Story_PrivacyTooltipNobody
                }
            } else {
                text = component.strings.Story_PrivacyTooltipEveryone
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let controller = UndoOverlayController(
                presentationData: presentationData,
                content: .info(title: nil, text: text, timeout: nil, customUndoText: nil),
                elevatedLayout: false,
                animateInAsReplacement: false,
                appearance: UndoOverlayController.Appearance(isBlurred: true),
                action: { _ in return false }
            )
            self.sendMessageContext.tooltipScreen = controller
            self.component?.presentController(controller, nil)
        }
        
        private func openItemPrivacySettings(updatedPrivacy: EngineStoryPrivacy? = nil) {
            guard let component = self.component else {
                return
            }
            
            let context = component.context
            let currentPrivacy = component.slice.item.storyItem.privacy ?? EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: [])
            
            if component.slice.item.storyItem.privacy == nil {
                Logger.shared.log("EditStoryPrivacy", "Story privacy is unknown")
            }
            
            let privacy = updatedPrivacy ?? component.slice.item.storyItem.privacy
            guard let privacy else {
                return
            }
            
            var selectedPeers: [EngineStoryPrivacy.Base: [EnginePeer.Id]] = [:]
            selectedPeers[currentPrivacy.base] = currentPrivacy.additionallyIncludePeers
            if let updatedPrivacy {
                selectedPeers[updatedPrivacy.base] = updatedPrivacy.additionallyIncludePeers
            }
            
            let stateContext = ShareWithPeersScreen.StateContext(
                context: context,
                subject: .stories(editing: true),
                editing: true,
                initialSelectedPeers: selectedPeers,
                closeFriends: component.closeFriends.get(),
                blockedPeersContext: component.blockedPeers
            )
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let controller = ShareWithPeersScreen(
                    context: context,
                    initialPrivacy: privacy,
                    stateContext: stateContext,
                    completion: { [weak self] _, privacy, _, _, _, completed in
                        guard let self, let component = self.component, completed else {
                            return
                        }
                        if component.slice.item.storyItem.privacy == privacy {
                            self.privacyController = nil
                            self.updateIsProgressPaused()
                            return
                        }
                        let _ = component.context.engine.messages.editStoryPrivacy(id: component.slice.item.storyItem.id, privacy: privacy).startStandalone()
                        
                        self.presentPrivacyTooltip(privacy: privacy)
                        
                        self.privacyController = nil
                        self.rewindCurrentItem()
                        self.updateIsProgressPaused()
                    },
                    editCategory: { [weak self] privacy, _, _ in
                        guard let self else {
                            return
                        }
                        self.openItemPrivacyCategory(privacy: privacy, blockedPeers: false, completion: { [weak self] privacy in
                            guard let self else {
                                return
                            }
                            self.openItemPrivacySettings(updatedPrivacy: privacy)
                        })
                    },
                    editBlockedPeers: { [weak self] privacy, _, _ in
                        guard let self else {
                            return
                        }
                        self.openItemPrivacyCategory(privacy: privacy, blockedPeers: true, completion: { [weak self] privacy in
                            guard let self else {
                                return
                            }
                            self.openItemPrivacySettings(updatedPrivacy: privacy)
                        })
                    }
                )
                controller.dismissed = { [weak self] in
                    if let self {
                        self.privacyController = nil
                        self.updateIsProgressPaused()
                    }
                }
                self.component?.controller()?.push(controller)
                
                self.privacyController = controller
                self.updateIsProgressPaused()
            })
        }
        
        private func openItemPrivacyCategory(privacy: EngineStoryPrivacy, blockedPeers: Bool, completion: @escaping (EngineStoryPrivacy) -> Void) {
            guard let component = self.component else {
                return
            }
            let context = component.context
            let subject: ShareWithPeersScreen.StateContext.Subject
            if blockedPeers {
                subject = .chats(blocked: true)
            } else if privacy.base == .nobody {
                subject = .chats(blocked: false)
            } else {
                subject = .contacts(base: privacy.base)
            }
            let stateContext = ShareWithPeersScreen.StateContext(
                context: context,
                subject: subject,
                editing: true,
                initialPeerIds: Set(privacy.additionallyIncludePeers),
                blockedPeersContext: component.blockedPeers
            )
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let controller = ShareWithPeersScreen(
                    context: context,
                    initialPrivacy: privacy,
                    stateContext: stateContext,
                    completion: { [weak self] _, result, _, _, peers, completed in
                        guard completed else {
                            return
                        }
                        if blockedPeers, let blockedPeers = self?.component?.blockedPeers {
                            let _ = blockedPeers.updatePeerIds(result.additionallyIncludePeers).startStandalone()
                            completion(privacy)
                        } else if case .closeFriends = privacy.base {
                            let _ = context.engine.privacy.updateCloseFriends(peerIds: result.additionallyIncludePeers).startStandalone()
                            if let component = self?.component {
                                component.closeFriends.set(.single(peers))
                            }
                            completion(EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []))
                        } else {
                            completion(result)
                        }
                    },
                    editCategory: { _, _, _ in },
                    editBlockedPeers: { _, _, _ in }
                )
                controller.dismissed = { [weak self] in
                    if let self {
                        self.privacyController = nil
                        self.updateIsProgressPaused()
                    }
                }
                self.component?.controller()?.push(controller)
                
                self.privacyController = controller
                self.updateIsProgressPaused()
            })
        }
        
        func navigateToMyStories() {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() as? StoryContainerScreen else {
                return
            }
            guard let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            
            let targetController = component.context.sharedContext.makeMyStoriesController(context: component.context, isArchive: false)
            
            if "".isEmpty {
                navigationController.pushViewController(targetController)
            } else {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.firstIndex(where: { $0 === controller }) {
                    viewControllers.insert(targetController, at: index)
                } else {
                    viewControllers.append(targetController)
                }
                navigationController.setViewControllers(viewControllers, animated: true)
            }
            self.updateIsProgressPaused()
        }
        
        func navigateToPeer(peer: EnginePeer, chat: Bool, subject: ChatControllerSubject? = nil) {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() as? StoryContainerScreen else {
                return
            }
            guard let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            
            var chat = chat
            switch peer {
            case .channel, .legacyGroup:
                chat = true
            default:
                break
            }
            
            if subject != nil || chat {
                if let index = navigationController.viewControllers.firstIndex(where: { c in
                    if let c = c as? ChatController, case .peer(peer.id) = c.chatLocation {
                        return true
                    } else {
                        return false
                    }
                }) {
                    var viewControllers = navigationController.viewControllers
                    for i in ((index + 1) ..< viewControllers.count).reversed() {
                        if viewControllers[i] !== controller {
                            viewControllers.remove(at: i)
                        }
                    }
                    navigationController.setViewControllers(viewControllers, animated: true)
                    
                    controller.dismissWithoutTransitionOut()
                } else {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peer), subject: subject, keepStack: .always, animated: true, pushController: { [weak controller, weak navigationController] chatController, animated, completion in
                        guard let controller, let navigationController else {
                            return
                        }
                        if "".isEmpty {
                            navigationController.pushViewController(chatController)
                        } else {
                            var viewControllers = navigationController.viewControllers
                            if let index = viewControllers.firstIndex(where: { $0 === controller }) {
                                viewControllers.insert(chatController, at: index)
                            } else {
                                viewControllers.append(chatController)
                            }
                            navigationController.setViewControllers(viewControllers, animated: animated)
                        }
                    }))
                }
            } else {
                var currentViewControllers = navigationController.viewControllers
                if let index = currentViewControllers.firstIndex(where: { c in
                    if let c = c as? PeerInfoScreen, c.peerId == peer.id {
                        return true
                    }
                    return false
                }) {
                    if let controller = component.controller() as? StoryContainerScreen {
                        controller.dismiss()
                    }
                    for i in (index + 1 ..< currentViewControllers.count).reversed() {
                        if currentViewControllers[i] !== component.controller() {
                            currentViewControllers.remove(at: i)
                        }
                    }
                    navigationController.setViewControllers(currentViewControllers, animated: true)
                } else {
                    guard let chatController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                        return
                    }
                    
                    navigationController.pushViewController(chatController)
                }
            }
        }
        
        func openPeerStories(peer: EnginePeer, avatarNode: AvatarNode?) {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() else {
                return
            }
            
            StoryContainerScreen.openPeerStories(context: component.context, peerId: peer.id, parentController: controller, avatarNode: avatarNode)
        }
        
        func openReposts(peer: EnginePeer, id: Int32, sourceView: UIView) {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() else {
                return
            }
            
            let storyId = StoryId(peerId: peer.id, id: id)
            
            guard let viewList = self.viewLists[component.slice.item.id], let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View, let viewListContext = viewListView.currentViewList else {
                return
            }
            
            let context = component.context
            let storyContent = RepostStoriesContentContextImpl(context: context, originalPeerId: component.slice.effectivePeer.id, originalStory: component.slice.item.storyItem, focusedStoryId: storyId, viewListContext: viewListContext, readGlobally: false)
            let _ = (storyContent.state
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak controller, weak viewListView, weak sourceView] _ in
                guard let controller, let sourceView else {
                    return
                }
                let transitionIn = StoryContainerScreen.TransitionIn(
                    sourceView: sourceView,
                    sourceRect: sourceView.bounds,
                    sourceCornerRadius: sourceView.bounds.width * 0.5,
                    sourceIsAvatar: false
                )
            
                let storyContainerScreen = StoryContainerScreen(
                    context: context,
                    content: storyContent,
                    transitionIn: transitionIn,
                    transitionOut: { [weak sourceView, weak viewListView] peerId, storyIdValue in
                        var destinationView: UIView?
                        if let view = viewListView?.sourceView(storyId: StoryId(peerId: peerId, id: storyIdValue as? Int32 ?? 0)) {
                            destinationView = view
                        } else {
                            destinationView = sourceView
                        }
                        if let destinationView {
                            return StoryContainerScreen.TransitionOut(
                                destinationView: destinationView,
                                transitionView: StoryContainerScreen.TransitionView(
                                    makeView: { [weak destinationView] in
                                        let parentView = UIView()
                                        if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                            parentView.addSubview(copyView)
                                        }
                                        return parentView
                                    },
                                    updateView: { copyView, state, transition in
                                        guard let view = copyView.subviews.first else {
                                            return
                                        }
                                        let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                        transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                        transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                    },
                                    insertCloneTransitionView: nil
                                ),
                                destinationRect: destinationView.bounds,
                                destinationCornerRadius: destinationView.bounds.width * 0.5,
                                destinationIsAvatar: false,
                                completed: { [weak sourceView] in
                                    guard let sourceView else {
                                        return
                                    }
                                    sourceView.isHidden = false
                                }
                            )
                        } else {
                            return nil
                        }
                    }
                )
                viewListView?.setPreviewedItem(signal: storyContainerScreen.focusedItem)
                controller.push(storyContainerScreen)
            })
        }
        
        private let updateDisposable = MetaDisposable()
        func openStoryEditing(repost: Bool = false, cover: Bool = false) {
            guard let component = self.component else {
                return
            }
        
            self.isEditingStory = true
            self.updateIsProgressPaused()
            self.state?.updated(transition: .easeInOut(duration: 0.2))
            
            var videoPlaybackPosition: Double?
            if let visibleItem = self.visibleItems[component.slice.item.id], let view = visibleItem.view.view as? StoryItemContentComponent.View {
                if cover {
                    if case let .file(file) = component.slice.item.storyItem.media {
                        for attribute in file.attributes {
                            if case let .Video(_, _, _, _, coverTime, _) = attribute {
                                videoPlaybackPosition = coverTime
                            }
                        }
                    }
                } else {
                    videoPlaybackPosition = view.videoPlaybackPosition
                }
            }
            
            guard let controller = MediaEditorScreenImpl.makeEditStoryController(
                context: component.context,
                peer: component.slice.effectivePeer,
                storyItem: component.slice.item.storyItem,
                videoPlaybackPosition: videoPlaybackPosition,
                cover: cover,
                repost: repost,
                transitionIn: .noAnimation,
                transitionOut: nil,
                completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.component?.controller()?.dismiss(animated: false)
                },
                willDismiss: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isEditingStory = false
                    self.rewindCurrentItem()
                    self.updateIsProgressPaused()
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                },
                update: { [weak self] disposable in
                    guard let self else {
                        return
                    }
                    self.updateDisposable.set(disposable)
                }
            ) else {
                return
            }
            self.component?.controller()?.push(controller)
        }
        
        private func presentSaveUpgradeScreen() {
            guard let component = self.component else {
                return
            }
            
            self.dismissAllTooltips()
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            let animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
            component.presentController(UndoOverlayController(
                presentationData: presentationData,
                content: .universal(
                    animation: "anim_infotip",
                    scale: 1.0,
                    colors: [
                        "info1.info1.stroke": animationBackgroundColor,
                        "info2.info2.Fill": animationBackgroundColor
                    ],
                    title: nil,
                    text: component.strings.Story_ToastPremiumSaveToGallery,
                    customUndoText: nil,
                    timeout: nil
                ),
                elevatedLayout: false,
                animateInAsReplacement: false,
                appearance: UndoOverlayController.Appearance(isBlurred: true),
                action: { [weak self] action in
                    guard let self else {
                        return false
                    }
                    switch action {
                    case .info:
                        self.presentStoriesUpgradeScreen(source: .storiesDownload)
                        return true
                    default:
                        break
                    }
                    return false
                }
            ), nil)
        }
        
        private func presentQualityUpgradeScreen() {
            self.sendMessageContext.presentQualityUpgrade(view: self, action: { [weak self] in
                guard let self else {
                    return
                }
                self.presentStoriesUpgradeScreen(source: .storiesHigherQuality)
            })
        }
        
        private func presentStealthModeUpgradeScreen() {
            self.sendMessageContext.presentStealthModeUpgrade(view: self, action: { [weak self] in
                guard let self else {
                    return
                }
                self.presentStoriesUpgradeScreen(source: .storiesStealthMode)
            })
        }
        
        private func presentPremiumRequiredForMessaging() {
            guard let component = self.component else {
                return
            }

            let controller = PremiumIntroScreen(context: component.context, source: .settings, forceDark: true)
            self.sendMessageContext.actionSheet = controller
            controller.wasDismissed = { [weak self, weak controller] in
                guard let self else {
                    return
                }
                
                if self.sendMessageContext.actionSheet === controller {
                    self.sendMessageContext.actionSheet = nil
                }
                self.updateIsProgressPaused()
            }
            
            self.updateIsProgressPaused()
            component.controller()?.push(controller)
        }
        
        private func presentBoostToUnrestrict() {
            guard let component = self.component, let boostsToUnrestrict = component.slice.additionalPeerData.boostsToUnrestrict else {
                return
            }
            
            HapticFeedback().impact()
            
            let _ = combineLatest(queue: Queue.mainQueue(),
                component.context.engine.peers.getChannelBoostStatus(peerId: component.slice.effectivePeer.id),
                component.context.engine.peers.getMyBoostStatus()
            ).startStandalone(next: { [weak self] boostStatus, myBoostStatus in
                guard let self, let component = self.component, let boostStatus, let myBoostStatus else {
                    return
                }
                let boostController = PremiumBoostLevelsScreen(
                    context: component.context,
                    peerId: component.slice.effectivePeer.id,
                    mode: .user(mode: .unrestrict(Int(boostsToUnrestrict))),
                    status: boostStatus,
                    myBoostStatus: myBoostStatus,
                    forceDark: true
                )
                boostController.disposed = { [weak self, weak boostController] in
                    guard let self else {
                        return
                    }
                    
                    if self.sendMessageContext.actionSheet === boostController {
                        self.sendMessageContext.actionSheet = nil
                    }
                    self.updateIsProgressPaused()
                }
                self.sendMessageContext.actionSheet = boostController
                
                self.updateIsProgressPaused()
                component.controller()?.push(boostController)
            })
        }
        
        private func presentStoriesUpgradeScreen(source: PremiumIntroSource) {
            guard let component = self.component else {
                return
            }
            
            let context = component.context
            var replaceImpl: ((ViewController) -> Void)?
            var dismissedImpl: (() -> Void)?
            let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .stories, forceDark: true, action: { [weak self] in
                guard let self else {
                    return
                }
                
                var dismissedImpl: (() -> Void)?
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: source, forceDark: true, dismissed: {
                    dismissedImpl?()
                })
                self.sendMessageContext.actionSheet = controller
                replaceImpl?(controller)
                
                dismissedImpl = { [weak self, weak controller] in
                    guard let self else {
                        return
                    }
                    
                    if self.sendMessageContext.actionSheet === controller {
                        self.sendMessageContext.actionSheet = nil
                    }
                    self.updateIsProgressPaused()
                }
            }, dismissed: {
                dismissedImpl?()
            })
            dismissedImpl = { [weak self, weak controller] in
                guard let self else {
                    return
                }
                
                if self.sendMessageContext.actionSheet === controller {
                    self.sendMessageContext.actionSheet = nil
                }
                self.updateIsProgressPaused()
            }
            replaceImpl = { [weak self, weak controller] c in
                controller?.dismiss(animated: true, completion: {
                    guard let self, let component = self.component else {
                        return
                    }
                    component.controller()?.push(c)
                })
            }
            self.sendMessageContext.actionSheet = controller
            self.updateIsProgressPaused()
            
            component.controller()?.push(controller)
        }
        
        private func requestSave() {
            guard let component = self.component, let peerReference = PeerReference(component.slice.effectivePeer._asPeer()) else {
                return
            }
            
            let saveScreen = SaveProgressScreen(context: component.context, content: .progress(component.strings.Story_TooltipSaving, 0.0))
            component.controller()?.present(saveScreen, in: .current)
            
            let stringSaving = component.strings.Story_TooltipSaving
            let stringSaved = component.strings.Story_TooltipSaved
            
            let disposable = (saveToCameraRoll(context: component.context, postbox: component.context.account.postbox, userLocation: .peer(peerReference.id), customUserContentType: .story, mediaReference: .story(peer: peerReference, id: component.slice.item.storyItem.id, media: component.slice.item.storyItem.media._asMedia()))
            |> deliverOnMainQueue).start(next: { [weak saveScreen] progress in
                guard let saveScreen else {
                    return
                }
                saveScreen.content = .progress(stringSaving, progress)
            }, completed: { [weak saveScreen] in
                guard let saveScreen else {
                    return
                }
                saveScreen.content = .completion(stringSaved)
                Queue.mainQueue().after(3.0, { [weak saveScreen] in
                    saveScreen?.dismiss()
                })
            })
            
            saveScreen.cancelled = {
                disposable.dispose()
            }
        }
        
        private func performMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            if self.isAnimatingOut {
                return
            }
            
            guard let component = self.component else {
                return
            }
            if component.slice.effectivePeer.id == component.context.account.peerId {
                self.performMyMoreAction(sourceView: sourceView, gesture: gesture)
            } else if case let .channel(channel) = component.slice.effectivePeer {
                var canPerformStoryActions = false
                
                if channel.hasPermission(.editStories) {
                    canPerformStoryActions = true
                } else if component.slice.item.storyItem.isMy && channel.hasPermission(.postStories) {
                    canPerformStoryActions = true
                }
                
                if channel.hasPermission(.deleteStories) {
                    canPerformStoryActions = true
                } else if component.slice.item.storyItem.isMy && channel.hasPermission(.postStories) {
                    canPerformStoryActions = true
                }
                    
                if canPerformStoryActions {
                    self.performMyChannelMoreAction(sourceView: sourceView, gesture: gesture)
                } else {
                    self.performOtherMoreAction(sourceView: sourceView, gesture: gesture)
                }
            } else {
                self.performOtherMoreAction(sourceView: sourceView, gesture: gesture)
            }
        }
        
        private func performDeleteAction() {
            guard let component = self.component else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            let actionSheet = ActionSheetController(presentationData: presentationData)
            
            let deleteTitle: String
            if case let .user(user) = component.slice.peer, user.botInfo != nil {
                deleteTitle = component.strings.BotPreview_ViewContextDelete
            } else {
                deleteTitle = component.strings.Story_ContextDeleteStory
            }
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: deleteTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        component.delete()
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            
            actionSheet.dismissed = { [weak self] _ in
                guard let self else {
                    return
                }
                self.sendMessageContext.actionSheet = nil
                self.updateIsProgressPaused()
            }
            self.sendMessageContext.actionSheet = actionSheet
            self.updateIsProgressPaused()
            
            component.presentController(actionSheet, nil)
        }
        
        private func performReorderAction() {
            guard let component = self.component else {
                return
            }
            
            component.reorder()
        }
        
        private func performLikeAction() {
            guard let component = self.component else {
                return
            }
            
            let action: () -> Void = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                
                var likeButtonView: UIView?
                var addTracingOffset: ((UIView) -> Void)?
                
                if let visibleItem = self.visibleItems[component.slice.item.id], let footerPanelView = visibleItem.footerPanel?.view as? StoryFooterPanelComponent.View {
                    likeButtonView = footerPanelView.likeButtonView
                    addTracingOffset = { [weak footerPanelView] view in
                        footerPanelView?.setLikeButtonTracingOffset(view: view)
                    }
                } else {
                    guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                        return
                    }
                    likeButtonView = inputPanelView.likeButtonView
                }
                
                guard let likeButtonView else {
                    return
                }
                
                let _ = component.context.engine.messages.setStoryReaction(peerId: component.slice.effectivePeer.id, id: component.slice.item.id.id, reaction: component.slice.item.storyItem.myReaction == nil ? .builtin("❤") : nil).startStandalone()
                
                if component.slice.item.storyItem.myReaction != nil {
                    return
                }
                
                var reactionItem: ReactionItem?
                guard let availableReactions = component.availableReactions else {
                    return
                }
                for item in availableReactions.reactionItems {
                    if case .builtin("❤") = item.reaction.rawValue {
                        reactionItem = item
                        break
                    }
                }
                
                guard let reactionItem else {
                    return
                }
                
                let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: nil, useDirectRendering: false)
                self.componentContainerView.addSubview(standaloneReactionAnimation.view)
                
                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                    self.standaloneReactionAnimation = nil
                    standaloneReactionAnimation.view.removeFromSuperview()
                }
                self.standaloneReactionAnimation = standaloneReactionAnimation
                
                standaloneReactionAnimation.frame = self.bounds
                standaloneReactionAnimation.animateReactionSelection(
                    context: component.context,
                    theme: component.theme,
                    animationCache: component.context.animationCache,
                    reaction: reactionItem,
                    avatarPeers: [],
                    playHaptic: true,
                    isLarge: false,
                    hideCenterAnimation: true,
                    targetView: likeButtonView,
                    addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                        guard let self else {
                            return
                        }
                        
                        if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                            self.standaloneReactionAnimation = nil
                            standaloneReactionAnimation.view.removeFromSuperview()
                        }
                        self.standaloneReactionAnimation = standaloneReactionAnimation
                        
                        standaloneReactionAnimation.frame = self.bounds
                        self.componentContainerView.addSubview(standaloneReactionAnimation.view)
                    },
                    completion: { [weak standaloneReactionAnimation] in
                        standaloneReactionAnimation?.view.removeFromSuperview()
                    }
                )
                
                addTracingOffset?(standaloneReactionAnimation.view)
            }
            
            if component.slice.item.storyItem.myReaction != nil {
                action()
            } else {
                self.sendMessageContext.performWithPossibleStealthModeConfirmation(view: self, action: {
                    action()
                })
            }
        }
        
        private func performLikeOptionsAction(sourceView: UIView, gesture: ContextGesture?) {
            HapticFeedback().tap()
            
            self.displayLikeReactions = true
            self.tempReactionsGesture = gesture
            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
            self.updateIsProgressPaused()
            self.tempReactionsGesture = nil
        }
        
        func dismissAllTooltips() {
            guard let component = self.component, let controller = component.controller() else {
                return
            }
            
            controller.forEachController { c in
                if let c = c as? UndoOverlayController {
                    c.dismiss()
                } else if let c = c as? TooltipScreen {
                    c.dismiss()
                } else if let c = c as? TooltipController {
                    c.dismiss()
                }
                return true
            }
        }
        
        private func getLinkedStickerPacks() -> (ContextController.Tip?, Signal<ContextController.Tip?, NoError>?) {
            guard let component = self.component else {
                return (nil, nil)
            }
            var tip: ContextController.Tip?
            var tipSignal: Signal<ContextController.Tip?, NoError>?
            
            var hasLinkedStickers = false
            let media = component.slice.item.storyItem.media._asMedia()
            if let image = media as? TelegramMediaImage {
                hasLinkedStickers = image.flags.contains(.hasStickers)
            } else if let file = media as? TelegramMediaFile {
                hasLinkedStickers = file.hasLinkedStickers
            }
            
            var emojiFileIds: [Int64] = []
            for entity in component.slice.item.storyItem.entities {
                if case let .CustomEmoji(_, fileId) = entity.type {
                    emojiFileIds.append(fileId)
                }
            }
            
            for mediaArea in component.slice.item.storyItem.mediaAreas {
                if case let .reaction(_, reaction, _) = mediaArea, case let .custom(fileId) = reaction {
                    emojiFileIds.append(fileId)
                }
            }
            
            if !emojiFileIds.isEmpty || hasLinkedStickers, let peerReference = PeerReference(component.slice.effectivePeer._asPeer()) {
                let context = component.context
                
                tip = .animatedEmoji(text: nil, arguments: nil, file: nil, action: nil)
                
                let packsPromise = Promise<[StickerPackReference]>()
                if hasLinkedStickers {
                    packsPromise.set(context.engine.stickers.stickerPacksAttachedToMedia(media: .story(peer: peerReference, id: component.slice.item.id.id, media: media)))
                } else {
                    packsPromise.set(.single([]))
                }
                
                let customEmojiPacksPromise = Promise<[StickerPackReference]>()
                if !emojiFileIds.isEmpty {
                    customEmojiPacksPromise.set( context.engine.stickers.resolveInlineStickers(fileIds: emojiFileIds)
                    |> map { files -> [StickerPackReference] in
                        var packReferences: [StickerPackReference] = []
                        var existingIds = Set<Int64>()
                        for (_, file) in files {
                        loop: for attribute in file.attributes {
                                if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                                    if case let .id(id, _) = packReference, !existingIds.contains(id) {
                                        packReferences.append(packReference)
                                        existingIds.insert(id)
                                    }
                                    break loop
                                }
                            }
                        }
                        return packReferences
                    })
                } else {
                    customEmojiPacksPromise.set(.single([]))
                }
                
                let action: () -> Void = { [weak self] in
                    if let self {
                        let combinedPacks = combineLatest(packsPromise.get(), customEmojiPacksPromise.get())
                        |> map { embeddedPackReferences, customEmojiPackReferences in
                            var packReferences: [StickerPackReference] = []
                            for packReference in embeddedPackReferences {
                                packReferences.append(packReference)
                            }
                            for packReference in customEmojiPackReferences {
                                if !packReferences.contains(packReference) {
                                    packReferences.append(packReference)
                                }
                            }
                            return packReferences
                        }
                        self.sendMessageContext.openAttachedStickers(view: self, packs: combinedPacks |> take(1))
                    }
                }
                tipSignal = combineLatest(packsPromise.get(), customEmojiPacksPromise.get())
                |> mapToSignal { embeddedPackReferences, customEmojiPackReferences -> Signal<ContextController.Tip?, NoError> in
                    var packReferences: [StickerPackReference] = []
                    for packReference in embeddedPackReferences {
                        packReferences.append(packReference)
                    }
                    for packReference in customEmojiPackReferences {
                        if !packReferences.contains(packReference) {
                            packReferences.append(packReference)
                        }
                    }
                    if packReferences.count > 1 {
                        let valueText = component.strings.Story_Context_EmbeddedStickersValue(Int32(packReferences.count))
                        return .single(.animatedEmoji(text: component.strings.Story_Context_EmbeddedStickers(valueText).string, arguments: nil, file: nil, action: action))
                    } else if let reference = packReferences.first {
                        return context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false)
                        |> filter { result in
                            if case .result = result {
                                return true
                            } else {
                                return false
                            }
                        }
                        |> mapToSignal { result -> Signal<ContextController.Tip?, NoError> in
                            if case let .result(info, items, _) = result {
                                let isEmoji = info.flags.contains(.isEmoji)
                                let tip: ContextController.Tip = .animatedEmoji(
                                    text: isEmoji ? component.strings.Story_Context_EmbeddedEmojiPack(info.title).string : component.strings.Story_Context_EmbeddedStickerPack(info.title).string,
                                    arguments: TextNodeWithEntities.Arguments(
                                        context: context,
                                        cache: context.animationCache,
                                        renderer: context.animationRenderer,
                                        placeholderColor: .clear,
                                        attemptSynchronous: true
                                    ),
                                    file: items.first?.file._parse(),
                                    action: action)
                                return .single(tip)
                            } else {
                                return .complete()
                            }
                        }
                    } else {
                        return .complete()
                    }
                }
            }
            
            return (tip, tipSignal)
        }
        
        private func contextMenuSpeedItems(value: ValuePromise<Double>) -> Signal<[ContextMenuItem], NoError> {
            guard let component = self.component else {
                return .single([])
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            
            let baseRate = component.storyItemSharedState.baseRate
            let valuePromise = ValuePromise<Double?>(nil)
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
            }, iconPosition: .left, action: { c, _ in
                c?.popItems()
            })))

            items.append(.custom(SliderContextItem(minValue: 0.2, maxValue: 2.5, value: baseRate, valueChanged: { [weak self] newValue, done in
                guard let self, let component = self.component else {
                    return
                }
                func normalizeValue(_ value: CGFloat) -> CGFloat {
                    return round(value * 10.0) / 10.0
                }
                
                let rate = normalizeValue(newValue)
                if let visibleItem = self.visibleItems[component.slice.item.id], let view = visibleItem.view.view as? StoryItemContentComponent.View {
                    view.setBaseRate(rate)
                }
                
                component.storyItemSharedState.baseRate = rate
                valuePromise.set(rate)
                
                if done {
                    value.set(rate)
                }
            }), true))
            
            items.append(.separator)
            
            for (text, _, rate) in speedList(strings: presentationData.strings) {
                let isSelected = abs(baseRate - rate) < 0.01
                items.append(.action(ContextMenuActionItem(text: text, icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: CGSize(width: 24.0, height: 24.0), signal: valuePromise.get()
                |> map { value in
                    if isSelected && value == nil {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)
                    } else {
                        return nil
                    }
                }), action: { [weak self] _, f in
                    f(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    if let visibleItem = self.visibleItems[component.slice.item.id], let view = visibleItem.view.view as? StoryItemContentComponent.View {
                        view.setBaseRate(rate)
                    }
                    component.storyItemSharedState.baseRate = rate
                })))
            }

            return .single(items)
        }

        private func performMyMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            guard let component = self.component, let controller = component.controller() else {
                return
            }
            
            self.dismissAllTooltips()
            
            let baseRatePromise = ValuePromise<Double>(component.storyItemSharedState.baseRate)
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            
            let contextItems = baseRatePromise.get()
            |> mapToSignal { [weak self, weak component] baseRate -> Signal<ContextController.Items , NoError> in
                guard let self, let component else {
                    return .complete()
                }
                
                var items: [ContextMenuItem] = []
                
                if case .file = component.slice.item.storyItem.media {
                    var speedValue: String = presentationData.strings.PlaybackSpeed_Normal
                    var speedIconText: String = "1x"
                    var didSetSpeedValue = false
                    for (text, iconText, speed) in speedList(strings: presentationData.strings) {
                        if abs(speed - baseRate) < 0.01 {
                            speedValue = text
                            speedIconText = iconText
                            didSetSpeedValue = true
                            break
                        }
                    }
                    if !didSetSpeedValue && baseRate != 1.0 {
                        speedValue = String(format: "%.1fx", baseRate)
                        speedIconText = speedValue
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PlaybackSpeed_Title, textLayout: .secondLineWithValue(speedValue), icon: { theme in
                        return optionsRateImage(rate: speedIconText, isLarge: false, color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        guard let self else {
                            c?.dismiss(completion: nil)
                            return
                        }

                        c?.pushItems(items: self.contextMenuSpeedItems(value: baseRatePromise) |> map { ContextController.Items(content: .list($0)) })
                    })))
                    items.append(.separator)
                }
                                        
                let additionalCount = component.slice.item.storyItem.privacy?.additionallyIncludePeers.count ?? 0
                let privacyText: String
                switch component.slice.item.storyItem.privacy?.base {
                case .closeFriends:
                    privacyText = component.strings.Story_ContextPrivacy_LabelCloseFriends
                case .contacts:
                    if additionalCount != 0 {
                        privacyText = component.strings.Story_ContextPrivacy_LabelContactsExcept("\(additionalCount)").string
                    } else {
                        privacyText = component.strings.Story_ContextPrivacy_LabelContacts
                    }
                case .nobody:
                    if additionalCount != 0 {
                        privacyText = component.strings.Story_ContextPrivacy_LabelOnlySelected(Int32(additionalCount))
                    } else {
                        privacyText = component.strings.Story_ContextPrivacy_LabelOnlyMe
                    }
                default:
                    privacyText = component.strings.Story_ContextPrivacy_LabelEveryone
                }
                
                items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Privacy, textLayout: .secondLineWithValue(privacyText), icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    self.openItemPrivacySettings()
                })))
                
                items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Edit, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    self.openStoryEditing()
                })))
                
                if case .file = component.slice.item.storyItem.media, component.slice.item.storyItem.isPinned {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_EditCover, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Stories/Context Menu/EditCover"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self else {
                            return
                        }
                        self.openStoryEditing(cover: true)
                    })))
                }
                
                items.append(.separator)

                items.append(.action(ContextMenuActionItem(text: component.slice.item.storyItem.isPinned ? component.strings.Story_Context_RemoveFromProfile : component.strings.Story_Context_SaveToProfile, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: component.slice.item.storyItem.isPinned ? "Stories/Context Menu/Unpin" : "Stories/Context Menu/Pin"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = component.context.engine.messages.updateStoriesArePinned(peerId: component.slice.effectivePeer.id, ids: [component.slice.item.storyItem.id: component.slice.item.storyItem], isPinned: !component.slice.item.storyItem.isPinned).startStandalone()
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                    if component.slice.item.storyItem.isPinned {
                        self.component?.presentController(UndoOverlayController(
                            presentationData: presentationData,
                            content: .info(title: nil, text: component.strings.Story_ToastRemovedFromProfileText, timeout: nil, customUndoText: nil),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            appearance: UndoOverlayController.Appearance(isBlurred: true),
                            action: { _ in return false }
                        ), nil)
                    } else {
                        self.component?.presentController(UndoOverlayController(
                            presentationData: presentationData,
                            content: .info(title: component.strings.Story_ToastSavedToProfileTitle, text: component.strings.Story_ToastSavedToProfileText, timeout: nil, customUndoText: nil),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            appearance: UndoOverlayController.Appearance(isBlurred: true),
                            action: { _ in return false }
                        ), nil)
                    }
                })))
                
                let saveText: String = component.strings.Story_Context_SaveToGallery
                items.append(.action(ContextMenuActionItem(text: saveText, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    self.requestSave()
                })))
                
                if case let .user(accountUser) = component.slice.effectivePeer {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextStealthMode, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: accountUser.isPremium ? "Chat/Context Menu/Eye" : "Chat/Context Menu/EyeLocked"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self else {
                            return
                        }
                        if accountUser.isPremium {
                            self.sendMessageContext.requestStealthMode(view: self)
                        } else {
                            self.presentStealthModeUpgradeScreen()
                        }
                    })))
                }
                
                if component.slice.item.storyItem.isPublic && (component.slice.effectivePeer.addressName != nil || !component.slice.effectivePeer._asPeer().usernames.isEmpty) && (component.slice.item.storyItem.expirationTimestamp > Int32(Date().timeIntervalSince1970) || component.slice.item.storyItem.isPinned) {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_CopyLink, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = (component.context.engine.messages.exportStoryLink(peerId: component.slice.effectivePeer.id, id: component.slice.item.storyItem.id)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] link in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let link {
                                UIPasteboard.general.string = link
                                
                                component.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .linkCopied(title: nil, text: component.strings.Story_ToastLinkCopied),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    appearance: UndoOverlayController.Appearance(isBlurred: true),
                                    action: { _ in return false }
                                ), nil)
                            }
                        })
                    })))
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Share, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                    }, action: {  [weak self] _, a in
                        a(.default)
                        
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.performShareAction(view: self)
                    })))
                }
                
                let (tip, tipSignal) = self.getLinkedStickerPacks()
                
                return .single(ContextController.Items(id: 0, content: .list(items), tip: tip, tipSignal: tipSignal))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .bottom)), items: contextItems, gesture: gesture)
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.contextController = nil
                self.updateIsProgressPaused()
            }
            self.contextController = contextController
            self.updateIsProgressPaused()
            controller.present(contextController, in: .window(.root))
        }
        
        private func performMyChannelMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            guard let component = self.component, let controller = component.controller() else {
                return
            }
            guard case let .channel(channel) = component.slice.effectivePeer else {
                return
            }
            
            self.dismissAllTooltips()
            
            let baseRatePromise = ValuePromise<Double>(component.storyItemSharedState.baseRate)
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)

            let contextItems = baseRatePromise.get()
            |> mapToSignal { [weak self, weak component] baseRate -> Signal<ContextController.Items , NoError> in
                guard let self, let component else {
                    return .complete()
                }

                var items: [ContextMenuItem] = []
                if case .file = component.slice.item.storyItem.media {
                    var speedValue: String = presentationData.strings.PlaybackSpeed_Normal
                    var speedIconText: String = "1x"
                    var didSetSpeedValue = false
                    for (text, iconText, speed) in speedList(strings: presentationData.strings) {
                        if abs(speed - baseRate) < 0.01 {
                            speedValue = text
                            speedIconText = iconText
                            didSetSpeedValue = true
                            break
                        }
                    }
                    if !didSetSpeedValue && baseRate != 1.0 {
                        speedValue = String(format: "%.1fx", baseRate)
                        speedIconText = speedValue
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PlaybackSpeed_Title, textLayout: .secondLineWithValue(speedValue), icon: { theme in
                        return optionsRateImage(rate: speedIconText, isLarge: false, color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        guard let self else {
                            c?.dismiss(completion: nil)
                            return
                        }

                        c?.pushItems(items: self.contextMenuSpeedItems(value: baseRatePromise) |> map { ContextController.Items(content: .list($0)) })
                    })))
                    items.append(.separator)
                }
                
                if (component.slice.item.storyItem.isMy && channel.hasPermission(.postStories)) || channel.hasPermission(.editStories) {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Edit, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self else {
                            return
                        }
                        self.openStoryEditing()
                    })))
                    
                    if case .file = component.slice.item.storyItem.media, component.slice.item.storyItem.isPinned {
                        items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_EditCover, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Stories/Context Menu/EditCover"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self else {
                                return
                            }
                            self.openStoryEditing(cover: true)
                        })))
                    }
                }
                
                if !items.isEmpty {
                    items.append(.separator)
                }
                
                if channel.hasPermission(.editStories) {
                    items.append(.action(ContextMenuActionItem(text: component.slice.item.storyItem.isPinned ? component.strings.Story_Context_RemoveFromChannel : component.strings.Story_Context_SaveToChannel, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: component.slice.item.storyItem.isPinned ? "Stories/Context Menu/Unpin" : "Stories/Context Menu/Pin"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = component.context.engine.messages.updateStoriesArePinned(peerId: component.slice.effectivePeer.id, ids: [component.slice.item.storyItem.id: component.slice.item.storyItem], isPinned: !component.slice.item.storyItem.isPinned).startStandalone()
                        
                        var isGroup = false
                        if case let .channel(channel) = component.slice.effectivePeer, case .group = channel.info {
                            isGroup = true
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                        if component.slice.item.storyItem.isPinned {
                            self.scheduledStoryUnpinnedUndoOverlay = UndoOverlayController(
                                presentationData: presentationData,
                                content: .info(title: nil, text: isGroup ? presentationData.strings.Story_ToastRemovedFromGroupText : presentationData.strings.Story_ToastRemovedFromChannelText, timeout: nil, customUndoText: nil),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                action: { _ in return false }
                            )
                        } else {
                            self.component?.presentController(UndoOverlayController(
                                presentationData: presentationData,
                                content: .info(title: isGroup ? presentationData.strings.Story_ToastSavedToGroupTitle : presentationData.strings.Story_ToastSavedToChannelTitle, text: isGroup ? presentationData.strings.Story_ToastSavedToGroupText : presentationData.strings.Story_ToastSavedToChannelText, timeout: nil, customUndoText: nil),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                action: { _ in return false }
                            ), nil)
                        }
                    })))
                }
                
                if component.slice.additionalPeerData.canViewStats {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_ViewStats, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
                        let statsController = component.context.sharedContext.makeStoryStatsController(
                            context: component.context,
                            updatedPresentationData: (presentationData, .single(presentationData)),
                            peerId: component.slice.effectivePeer.id,
                            storyId: component.slice.item.storyItem.id,
                            storyItem: component.slice.item.storyItem,
                            fromStory: true
                        )
                        component.controller()?.push(statsController)
                    })))
                }
                
                let saveText: String = component.strings.Story_Context_SaveToGallery
                items.append(.action(ContextMenuActionItem(text: saveText, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    self.requestSave()
                })))
                
                if component.slice.item.storyItem.isPublic && (component.slice.effectivePeer.addressName != nil || !component.slice.effectivePeer._asPeer().usernames.isEmpty) && (component.slice.item.storyItem.expirationTimestamp > Int32(Date().timeIntervalSince1970) || component.slice.item.storyItem.isPinned) {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_CopyLink, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = (component.context.engine.messages.exportStoryLink(peerId: component.slice.effectivePeer.id, id: component.slice.item.storyItem.id)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] link in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let link {
                                UIPasteboard.general.string = link
                                
                                component.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .linkCopied(title: nil, text: component.strings.Story_ToastLinkCopied),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    appearance: UndoOverlayController.Appearance(isBlurred: true),
                                    action: { _ in return false }
                                ), nil)
                            }
                        })
                    })))
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Share, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                    }, action: {  [weak self] _, a in
                        a(.default)
                        
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.performShareAction(view: self)
                    })))
                }
                
                var isHidden = false
                if case let .channel(channel) = component.slice.effectivePeer, let storiesHidden = channel.storiesHidden {
                    isHidden = storiesHidden
                }
                items.append(.action(ContextMenuActionItem(text: isHidden ? component.strings.StoryFeed_ContextUnarchive : component.strings.StoryFeed_ContextArchive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isHidden ? "Chat/Context Menu/Unarchive" : "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.effectivePeer.id, isHidden: !isHidden)
                    
                    let text = !isHidden ? component.strings.StoryFeed_TooltipArchive(component.slice.effectivePeer.compactDisplayTitle).string : component.strings.StoryFeed_TooltipUnarchive(component.slice.effectivePeer.compactDisplayTitle).string
                    let tooltipScreen = TooltipScreen(
                        context: component.context,
                        account: component.context.account,
                        sharedContext: component.context.sharedContext,
                        text: .markdown(text: text),
                        style: .customBlur(UIColor(rgb: 0x1c1c1c), 0.0),
                        icon: .peer(peer: component.slice.effectivePeer, isStory: true),
                        action: TooltipScreen.Action(
                            title: component.strings.Undo_Undo,
                            action: {
                                component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.effectivePeer.id, isHidden: isHidden)
                            }
                        ),
                        location: .bottom,
                        shouldDismissOnTouch: { _, _ in return .dismiss(consume: false) }
                    )
                    tooltipScreen.willBecomeDismissed = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.tooltipScreen = nil
                        self.updateIsProgressPaused()
                    }
                    self.sendMessageContext.tooltipScreen?.dismiss()
                    self.sendMessageContext.tooltipScreen = tooltipScreen
                    self.updateIsProgressPaused()
                    component.controller()?.present(tooltipScreen, in: .current)
                })))
                
                if (component.slice.item.storyItem.isMy && channel.hasPermission(.postStories)) || channel.hasPermission(.deleteStories) {
                    items.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextDeleteStory, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak self] _, a in
                        a(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: component.strings.Story_ContextDeleteStory, color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.delete()
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        
                        actionSheet.dismissed = { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.actionSheet = nil
                            self.updateIsProgressPaused()
                        }
                        self.sendMessageContext.actionSheet = actionSheet
                        self.updateIsProgressPaused()
                        
                        component.presentController(actionSheet, nil)
                    })))
                }
                
                let (tip, tipSignal) = self.getLinkedStickerPacks()
                return .single(ContextController.Items(id: 0, content: .list(items), tip: tip, tipSignal: tipSignal))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .bottom)), items: contextItems, gesture: gesture)
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.contextController = nil
                self.updateIsProgressPaused()
            }
            self.contextController = contextController
            self.updateIsProgressPaused()
            controller.present(contextController, in: .window(.root))
        }
        
        private func performOtherMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            guard let component = self.component else {
                return
            }
            
            let baseRatePromise = ValuePromise<Double>(component.storyItemSharedState.baseRate)
            
            let translationSettings = component.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
            |> map { sharedData -> TranslationSettings in
                let translationSettings: TranslationSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                    translationSettings = current
                } else {
                    translationSettings = TranslationSettings.defaultSettings
                }
                return translationSettings
            }
            
            let _ = (combineLatest(
                queue: Queue.mainQueue(),
                component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: component.slice.effectivePeer.id),
                    TelegramEngine.EngineData.Item.NotificationSettings.Global(),
                    TelegramEngine.EngineData.Item.Contacts.Top(),
                    TelegramEngine.EngineData.Item.Peer.IsContact(id: component.slice.effectivePeer.id),
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                ),
                translationSettings,
                baseRatePromise.get()
            )
            |> take(1)).startStandalone(next: { [weak self] result, translationSettings, baseRate in
                guard let self, let component = self.component, let controller = component.controller() else {
                    return
                }
                
                let (settings, globalSettings, topSearchPeers, isContact, accountPeer) = result
                
                guard case let .user(accountUser) = accountPeer else {
                    return
                }
                
                self.dismissAllTooltips()
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                var items: [ContextMenuItem] = []
                
                if case let .user(user) = component.slice.peer, let botInfo = user.botInfo {
                    if botInfo.flags.contains(.canEdit) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.BotPreviews_MenuReorder, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            component.reorder()
                        })))
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Delete, textColor: .destructive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self else {
                                return
                            }
                            self.performDeleteAction()
                        })))
                    }
                } else {
                    if case .file = component.slice.item.storyItem.media {
                        var speedValue: String = presentationData.strings.PlaybackSpeed_Normal
                        var speedIconText: String = "1x"
                        var didSetSpeedValue = false
                        for (text, iconText, speed) in speedList(strings: presentationData.strings) {
                            if abs(speed - baseRate) < 0.01 {
                                speedValue = text
                                speedIconText = iconText
                                didSetSpeedValue = true
                                break
                            }
                        }
                        if !didSetSpeedValue && baseRate != 1.0 {
                            speedValue = String(format: "%.1fx", baseRate)
                            speedIconText = speedValue
                        }
                        
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.PlaybackSpeed_Title, textLayout: .secondLineWithValue(speedValue), icon: { theme in
                            return optionsRateImage(rate: speedIconText, isLarge: false, color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, _ in
                            guard let self else {
                                c?.dismiss(completion: nil)
                                return
                            }
                            
                            c?.pushItems(items: self.contextMenuSpeedItems(value: baseRatePromise) |> map { ContextController.Items(content: .list($0)) })
                        })))
                        items.append(.separator)
                    }
                    
                    let isMuted = resolvedAreStoriesMuted(globalSettings: globalSettings._asGlobalNotificationSettings(), peer: component.slice.effectivePeer._asPeer(), peerSettings: settings._asNotificationSettings(), topSearchPeers: topSearchPeers)
                    
                    if !component.slice.effectivePeer.isService && isContact {
                        items.append(.action(ContextMenuActionItem(text: isMuted ? component.strings.StoryFeed_ContextNotifyOn : component.strings.StoryFeed_ContextNotifyOff, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: component.slice.additionalPeerData.isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let _ = component.context.engine.peers.togglePeerStoriesMuted(peerId: component.slice.effectivePeer.id).startStandalone()
                            
                            let iconColor = UIColor.white
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            if isMuted {
                                self.component?.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                                        "Middle.Group 1.Fill 1": iconColor,
                                        "Top.Group 1.Fill 1": iconColor,
                                        "Bottom.Group 1.Fill 1": iconColor,
                                        "EXAMPLE.Group 1.Fill 1": iconColor,
                                        "Line.Group 1.Stroke 1": iconColor
                                    ], title: nil, text: component.strings.StoryFeed_TooltipNotifyOn(component.slice.effectivePeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string, customUndoText: nil, timeout: nil),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    appearance: UndoOverlayController.Appearance(isBlurred: true),
                                    action: { _ in return false }
                                ), nil)
                            } else {
                                self.component?.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                        "Middle.Group 1.Fill 1": iconColor,
                                        "Top.Group 1.Fill 1": iconColor,
                                        "Bottom.Group 1.Fill 1": iconColor,
                                        "EXAMPLE.Group 1.Fill 1": iconColor,
                                        "Line.Group 1.Stroke 1": iconColor
                                    ], title: nil, text: component.strings.StoryFeed_TooltipNotifyOff(component.slice.effectivePeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string, customUndoText: nil, timeout: nil),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    appearance: UndoOverlayController.Appearance(isBlurred: true),
                                    action: { _ in return false }
                                ), nil)
                            }
                        })))
                    }
                    
                    if !component.slice.effectivePeer.isService && component.slice.item.storyItem.isPublic && (component.slice.effectivePeer.addressName != nil || !component.slice.effectivePeer._asPeer().usernames.isEmpty) {
                        items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_CopyLink, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let _ = (component.context.engine.messages.exportStoryLink(peerId: component.slice.effectivePeer.id, id: component.slice.item.storyItem.id)
                                     |> deliverOnMainQueue).startStandalone(next: { [weak self] link in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if let link {
                                    UIPasteboard.general.string = link
                                    
                                    component.presentController(UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .linkCopied(title: nil, text: component.strings.Story_ToastLinkCopied),
                                        elevatedLayout: false,
                                        animateInAsReplacement: false,
                                        appearance: UndoOverlayController.Appearance(isBlurred: true),
                                        action: { _ in return false }
                                    ), nil)
                                }
                            })
                        })))
                    }
                    
                    if !component.slice.item.storyItem.isMy, case let .file(file) = component.slice.item.storyItem.media, file.isVideo {
                        let isHq = component.slice.additionalPeerData.preferHighQualityStories
                        items.append(.action(ContextMenuActionItem(text: isHq ? component.strings.Story_ContextMenuSD : component.strings.Story_ContextMenuHD, icon: { theme in
                            if isHq {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QualitySd"), color: theme.contextMenu.primaryColor)
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: accountUser.isPremium ? "Chat/Context Menu/QualityHd" : "Chat/Context Menu/QualityHdLocked"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component, let controller = component.controller() else {
                                return
                            }
                            
                            if !component.slice.additionalPeerData.preferHighQualityStories && !accountUser.isPremium {
                                self.presentQualityUpgradeScreen()
                                
                                return
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            let title: String
                            let text: String
                            if component.slice.additionalPeerData.preferHighQualityStories {
                                title = component.strings.Story_ToastQualitySD_Title
                                text = component.strings.Story_ToastQualitySD_Text
                            } else {
                                title = component.strings.Story_ToastQualityHD_Title
                                text = component.strings.Story_ToastQualityHD_Text
                            }
                            controller.present(UndoOverlayController(
                                presentationData: presentationData,
                                content: .info(title: title, text: text, timeout: nil, customUndoText: nil),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                appearance: UndoOverlayController.Appearance(isBlurred: true),
                                action: { _ in return false }
                            ), in: .current)
                            
                            let _ = updateMediaDownloadSettingsInteractively(accountManager: component.context.sharedContext.accountManager, { settings in
                                var settings = settings
                                settings.highQualityStories = !isHq
                                return settings
                            }).startStandalone()
                        })))
                    }
                    
                    var isHidden = false
                    if case let .user(user) = component.slice.effectivePeer, let storiesHidden = user.storiesHidden {
                        isHidden = storiesHidden
                    } else if case let .channel(channel) = component.slice.effectivePeer, let storiesHidden = channel.storiesHidden {
                        isHidden = storiesHidden
                    }
                    
                    var canArchive = false
                    if isHidden {
                        canArchive = true
                    } else {
                        if case .user = component.slice.effectivePeer, !component.slice.effectivePeer.isService {
                            canArchive = true
                        } else if case .channel = component.slice.effectivePeer {
                            canArchive = true
                        }
                    }
                    
                    if canArchive {
                        items.append(.action(ContextMenuActionItem(text: isHidden ? component.strings.StoryFeed_ContextUnarchive : component.strings.StoryFeed_ContextArchive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: isHidden ? "Chat/Context Menu/Unarchive" : "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let _ = component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.effectivePeer.id, isHidden: !isHidden)
                            
                            let text = !isHidden ? component.strings.StoryFeed_TooltipArchive(component.slice.effectivePeer.compactDisplayTitle).string : component.strings.StoryFeed_TooltipUnarchive(component.slice.effectivePeer.compactDisplayTitle).string
                            let tooltipScreen = TooltipScreen(
                                context: component.context,
                                account: component.context.account,
                                sharedContext: component.context.sharedContext,
                                text: .markdown(text: text),
                                style: .customBlur(UIColor(rgb: 0x1c1c1c), 0.0),
                                icon: .peer(peer: component.slice.effectivePeer, isStory: true),
                                action: TooltipScreen.Action(
                                    title: component.strings.Undo_Undo,
                                    action: {
                                        component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.effectivePeer.id, isHidden: isHidden)
                                    }
                                ),
                                location: .bottom,
                                shouldDismissOnTouch: { _, _ in return .dismiss(consume: false) }
                            )
                            tooltipScreen.willBecomeDismissed = { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.sendMessageContext.tooltipScreen = nil
                                self.updateIsProgressPaused()
                            }
                            self.sendMessageContext.tooltipScreen?.dismiss()
                            self.sendMessageContext.tooltipScreen = tooltipScreen
                            self.updateIsProgressPaused()
                            component.controller()?.present(tooltipScreen, in: .current)
                        })))
                    }
                    
                    if !component.slice.item.storyItem.isForwardingDisabled {
                        let saveText: String = component.strings.Story_Context_SaveToGallery
                        items.append(.action(ContextMenuActionItem(text: saveText, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: accountUser.isPremium ? "Chat/Context Menu/Download" : "Chat/Context Menu/DownloadLocked"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self else {
                                return
                            }
                            
                            if accountUser.isPremium {
                                self.requestSave()
                            } else {
                                self.presentSaveUpgradeScreen()
                            }
                        })))
                    }
                    
                    if case .user = component.slice.effectivePeer {
                        items.append(.action(ContextMenuActionItem(text: component.strings.Story_ContextStealthMode, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: accountUser.isPremium ? "Chat/Context Menu/Eye" : "Chat/Context Menu/EyeLocked"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self else {
                                return
                            }
                            if accountUser.isPremium {
                                self.sendMessageContext.requestStealthMode(view: self)
                            } else {
                                self.presentStealthModeUpgradeScreen()
                            }
                        })))
                    }
                    
                    if component.slice.additionalPeerData.canViewStats {
                        items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_ViewStats, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
                            let statsController = component.context.sharedContext.makeStoryStatsController(
                                context: component.context,
                                updatedPresentationData: (presentationData, .single(presentationData)),
                                peerId: component.slice.effectivePeer.id,
                                storyId: component.slice.item.storyItem.id,
                                storyItem: component.slice.item.storyItem,
                                fromStory: true
                            )
                            component.controller()?.push(statsController)
                        })))
                    }
                    
                    if !component.slice.item.storyItem.text.isEmpty {
                        let (canTranslate, _) = canTranslateText(context: component.context, text: component.slice.item.storyItem.text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
                        if canTranslate {
                            items.append(.action(ContextMenuActionItem(text: component.strings.Conversation_ContextMenuTranslate, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                f(.default)
                                
                                guard let self, let component = self.component else {
                                    return
                                }
                                self.sendMessageContext.performTranslateTextAction(view: self, text: component.slice.item.storyItem.text, entities: component.slice.item.storyItem.entities)
                            })))
                        }
                    }
                    
                    if !component.slice.effectivePeer.isService {
                        items.append(.action(ContextMenuActionItem(text: component.strings.Story_Context_Report, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            guard let self, let component = self.component, let controller = component.controller() else {
                                return
                            }
                            
                            f(.default)
                            
                            self.isReporting = true
                            self.updateIsProgressPaused()
                            
                            component.context.sharedContext.makeContentReportScreen(
                                context: component.context,
                                subject: .stories(component.slice.effectivePeer.id, [component.slice.item.storyItem.id]),
                                forceDark: true,
                                present: { c in
                                    controller.push(c)
                                },
                                completion: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.isReporting = false
                                    self.updateIsProgressPaused()
                                },
                                requestSelectMessages: nil
                            )
                        })))
                    }
                }
                
                let (tip, tipSignal) = self.getLinkedStickerPacks()
                
                let contextItems = ContextController.Items(id: 0, content: .list(items), tip: tip, tipSignal: tipSignal)
                                
                let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .bottom)), items: .single(contextItems), gesture: gesture)
                contextController.dismissed = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.contextController = nil
                    self.updateIsProgressPaused()
                }
                self.contextController = contextController
                self.updateIsProgressPaused()
                controller.present(contextController, in: .window(.root))
            })
        }
        
        func displayMutedVideoTooltip() {
            guard let component = self.component else {
                return
            }
            guard let soundButtonView = self.soundButton.view else {
                return
            }
            let tooltipScreen = TooltipScreen(
                account: component.context.account,
                sharedContext: component.context.sharedContext,
                text: .plain(text: component.strings.Story_TooltipVideoHasNoSound), style: .default, location: TooltipScreen.Location.point(soundButtonView.convert(soundButtonView.bounds, to: nil).offsetBy(dx: 1.0, dy: -10.0), .top), displayDuration: .infinite, shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: true)
                }
            )
            tooltipScreen.willBecomeDismissed = { [weak self] _ in
                guard let self else {
                    return
                }
                self.sendMessageContext.tooltipScreen = nil
                self.updateIsProgressPaused()
            }
            self.sendMessageContext.tooltipScreen?.dismiss()
            self.sendMessageContext.tooltipScreen = tooltipScreen
            self.updateIsProgressPaused()
            component.controller()?.present(tooltipScreen, in: .current)
        }
        
        func maybeDisplayUnmuteVideoTooltip() {
            guard let component = self.component, component.visibilityFraction == 1.0 && !component.isProgressPaused else {
                return
            }
            guard let soundButtonView = self.soundButton.view else {
                return
            }
            
            let _ = (ApplicationSpecificNotice.displayStoryUnmuteTooltip(accountManager: component.context.sharedContext.accountManager)
            |> delay(0.3, queue: .mainQueue())
            |> deliverOnMainQueue).startStandalone(next: { [weak self] value in
                guard let self, let component = self.component else {
                    return
                }
                if !value {
                    let tooltipScreen = TooltipScreen(
                        account: component.context.account,
                        sharedContext: component.context.sharedContext,
                        text: .plain(text: component.strings.Story_TooltipUnmuteVideoSound), style: .default, location: TooltipScreen.Location.point(soundButtonView.convert(soundButtonView.bounds, to: nil).offsetBy(dx: 1.0, dy: -10.0), .top), displayDuration: .default, shouldDismissOnTouch: { _, _ in
                            return .dismiss(consume: false)
                        }
                    )
                    component.controller()?.present(tooltipScreen, in: .current)
                    
                    let _ = ApplicationSpecificNotice.setDisplayStoryUnmuteTooltip(accountManager: component.context.sharedContext.accountManager).startStandalone()
                }
            })
        }
        
        func updateModalTransitionFactor(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
            guard let component = self.component, case .compact = component.metrics.widthClass else {
                return
            }
            
            let statusBarHeight = component.statusBarHeight
            let size = self.bounds.size
            let progress = 1.0 - value
            let maxScale = (size.width - 16.0 * 2.0) / size.width
            
            let topInset: CGFloat = statusBarHeight + 5.0
            let targetTopInset = ceil(statusBarHeight - (size.height - size.height * maxScale) / 2.0)
            let deltaOffset = (targetTopInset - topInset)
            
            let scale = 1.0 * progress + (1.0 - progress) * maxScale
            let offset = (1.0 - progress) * deltaOffset
            transition.updateSublayerTransformScaleAndOffset(layer: self.layer, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    private let position: ContextControllerReferenceViewInfo.ActionsPosition
    var keepInPlace: Bool {
        return true
    }

    init(controller: ViewController, sourceView: UIView, position: ContextControllerReferenceViewInfo.ActionsPosition) {
        self.controller = controller
        self.sourceView = sourceView
        self.position = position
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.position)
    }
}

final class ListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
        
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}


private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat, duration: Double, curve: ComponentTransition.Animation.Curve, reverse: Bool) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    let numPoints: Int = Int(ceil(Double(UIScreen.main.maximumFramesPerSecond) * duration))
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
        for rawI in 0 ..< numPoints {
            let i = reverse ? (numPoints - 1 - rawI) : rawI
            let ks = CGFloat(i) / CGFloat(numPoints - 1)
            var k = curve.solve(at: reverse ? (1.0 - ks) : ks)
            if reverse {
                k = 1.0 - k
            }
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for rawI in 0 ..< numPoints {
            let i = reverse ? (numPoints - 1 - rawI) : rawI
            
            let ks = CGFloat(i) / CGFloat(numPoints - 1)
            var k = curve.solve(at: reverse ? (1.0 - ks) : ks)
            if reverse {
                k = 1.0 - k
            }
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}

private func speedList(strings: PresentationStrings) -> [(String, String, Double)] {
    return [
        ("0.5x", "0.5x", 0.5),
        (strings.PlaybackSpeed_Normal, "1x", 1.0),
        ("1.5x", "1.5x", 1.5),
        ("2x", "2x", 2.0)
    ]
}

private func optionsRateImage(rate: String, isLarge: Bool, color: UIColor = .white) -> UIImage? {
    return generateImage(isLarge ? CGSize(width: 30.0, height: 30.0) : CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
        UIGraphicsPushContext(context)

        context.clear(CGRect(origin: CGPoint(), size: size))

        if let image = generateTintedImage(image: UIImage(bundleImageName: isLarge ? "Chat/Context Menu/Playspeed30" : "Chat/Context Menu/Playspeed24"), color: .white) {
            image.draw(at: CGPoint(x: 0.0, y: 0.0))
        }

        let string = NSMutableAttributedString(string: rate, font: Font.with(size: isLarge ? 11.0 : 10.0, design: .round, weight: .semibold), textColor: color)

        var offset = CGPoint(x: 1.0, y: 0.0)
        if rate.count >= 3 {
            if rate == "0.5x" {
                string.addAttribute(.kern, value: -0.8 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.5
            } else {
                string.addAttribute(.kern, value: -0.5 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.3
            }
        } else {
            offset.x += -0.3
        }

        if !isLarge {
            offset.x *= 0.5
            offset.y *= 0.5
        }

        let boundingRect = string.boundingRect(with: size, options: [], context: nil)
        string.draw(at: CGPoint(x: offset.x + floor((size.width - boundingRect.width) / 2.0), y: offset.y + floor((size.height - boundingRect.height) / 2.0)))

        UIGraphicsPopContext()
    })
}
