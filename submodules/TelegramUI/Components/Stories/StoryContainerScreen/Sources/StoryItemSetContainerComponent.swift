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

public final class StoryItemSetContainerComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var derivedBottomInset: CGFloat = 0.0
        public fileprivate(set) var derivedMediaSize: CGSize = .zero
        
        public init() {
        }
    }
    
    public enum NavigationDirection {
        case previous
        case next
        case id(Int32)
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
    public let slice: StoryContentContextState.FocusedSlice
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let containerInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let inputHeight: CGFloat
    public let metrics: LayoutMetrics
    public let deviceMetrics: DeviceMetrics
    public let isProgressPaused: Bool
    public let hideUI: Bool
    public let visibilityFraction: CGFloat
    public let isPanning: Bool
    public let verticalPanFraction: CGFloat
    public let pinchState: PinchState?
    public let presentController: (ViewController, Any?) -> Void
    public let close: () -> Void
    public let navigate: (NavigationDirection) -> Void
    public let delete: () -> Void
    public let markAsSeen: (StoryId) -> Void
    public let controller: () -> ViewController?
    public let toggleAmbientMode: () -> Void
    
    public init(
        context: AccountContext,
        externalState: ExternalState,
        storyItemSharedState: StoryContentItem.SharedState,
        slice: StoryContentContextState.FocusedSlice,
        theme: PresentationTheme,
        strings: PresentationStrings,
        containerInsets: UIEdgeInsets,
        safeInsets: UIEdgeInsets,
        inputHeight: CGFloat,
        metrics: LayoutMetrics,
        deviceMetrics: DeviceMetrics,
        isProgressPaused: Bool,
        hideUI: Bool,
        visibilityFraction: CGFloat,
        isPanning: Bool,
        verticalPanFraction: CGFloat,
        pinchState: PinchState?,
        presentController: @escaping (ViewController, Any?) -> Void,
        close: @escaping () -> Void,
        navigate: @escaping (NavigationDirection) -> Void,
        delete: @escaping () -> Void,
        markAsSeen: @escaping (StoryId) -> Void,
        controller: @escaping () -> ViewController?,
        toggleAmbientMode: @escaping () -> Void
    ) {
        self.context = context
        self.externalState = externalState
        self.storyItemSharedState = storyItemSharedState
        self.slice = slice
        self.theme = theme
        self.strings = strings
        self.containerInsets = containerInsets
        self.safeInsets = safeInsets
        self.inputHeight = inputHeight
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.isProgressPaused = isProgressPaused
        self.hideUI = hideUI
        self.visibilityFraction = visibilityFraction
        self.isPanning = isPanning
        self.verticalPanFraction = verticalPanFraction
        self.pinchState = pinchState
        self.presentController = presentController
        self.close = close
        self.navigate = navigate
        self.delete = delete
        self.markAsSeen = markAsSeen
        self.controller = controller
        self.toggleAmbientMode = toggleAmbientMode
    }
    
    public static func ==(lhs: StoryItemSetContainerComponent, rhs: StoryItemSetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
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
        if lhs.hideUI != rhs.hideUI {
            return false
        }
        if lhs.visibilityFraction != rhs.visibilityFraction {
            return false
        }
        if lhs.isPanning != rhs.isPanning {
            return false
        }
        if lhs.verticalPanFraction != rhs.verticalPanFraction {
            return false
        }
        if lhs.pinchState != rhs.pinchState {
            return false
        }
        return true
    }
    
    struct ItemLayout {
        var containerSize: CGSize
        var contentFrame: CGRect
        var contentVisualScale: CGFloat
        
        init(
            containerSize: CGSize,
            contentFrame: CGRect,
            contentVisualScale: CGFloat
        ) {
            self.containerSize = containerSize
            self.contentFrame = contentFrame
            self.contentVisualScale = contentVisualScale
        }
    }
    
    final class VisibleItem {
        let externalState = StoryContentItem.ExternalState()
        let contentContainerView: UIView
        let view = ComponentView<StoryContentItem.Environment>()
        var currentProgress: Double = 0.0
        var requestedNext: Bool = false
        
        init() {
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.contentContainerView.layer.cornerCurve = .continuous
            }
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
        let itemId: Int32
        let externalState = StoryContentCaptionComponent.ExternalState()
        let view = ComponentView<Empty>()
        
        init(itemId: Int32) {
            self.itemId = itemId
        }
    }
    
    final class ViewList {
        let externalState = StoryItemSetViewListComponent.ExternalState()
        let view = ComponentView<Empty>()
        
        init() {
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
    
    public final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let sendMessageContext: StoryItemSetContainerSendMessage
        
        private let scroller: Scroller
        
        let itemsContainerView: UIView
        let controlsContainerView: UIView
        let topContentGradientLayer: SimpleGradientLayer
        let bottomContentGradientLayer: SimpleGradientLayer
        let contentDimView: UIView
        
        let closeButton: HighlightableButton
        let closeButtonIconView: UIImageView
        
        let navigationStrip = ComponentView<MediaNavigationStripComponent.EnvironmentType>()
        
        var centerInfoItem: InfoItem?
        var leftInfoItem: InfoItem?
        
        let moreButton = ComponentView<Empty>()
        let soundButton = ComponentView<Empty>()
        var closeFriendIcon: ComponentView<Empty>?
        
        var captionItem: CaptionItem?
        
        let inputBackground = ComponentView<Empty>()
        let inputPanel = ComponentView<Empty>()
        let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        private let inputPanelBackground = ComponentView<Empty>()
        
        var preparingToDisplayViewList: Bool = false
        var displayViewList: Bool = false
        var viewList: ViewList?
        
        var isEditingStory: Bool = false
        
        var itemLayout: ItemLayout?
        var ignoreScrolling: Bool = false
        
        var visibleItems: [Int32: VisibleItem] = [:]
        var trulyValidIds: [Int32] = []
        var scrollingOffsetX: CGFloat = 0.0
        var scrollingCenterX: CGFloat = 0.0
        
        var reactionItems: [ReactionItem]?
        var reactionContextNode: ReactionContextNode?
        weak var disappearingReactionContextNode: ReactionContextNode?
        
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
        
        private var awaitingSwitchToId: (from: Int32, to: Int32)?
        private var animateNextNavigationId: Int32?
        private var initializedOffset: Bool = false
        
        override init(frame: CGRect) {
            self.sendMessageContext = StoryItemSetContainerSendMessage()
            
            self.itemsContainerView = UIView()
            
            self.scroller = Scroller()
            self.scroller.alwaysBounceHorizontal = true
            self.scroller.showsVerticalScrollIndicator = false
            self.scroller.showsHorizontalScrollIndicator = false
            self.scroller.decelerationRate = .fast
            
            self.controlsContainerView = SparseContainerView()
            self.controlsContainerView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.controlsContainerView.layer.cornerCurve = .continuous
            }
            
            self.topContentGradientLayer = SimpleGradientLayer()
            self.bottomContentGradientLayer = SimpleGradientLayer()
            
            self.contentDimView = UIView()
            self.contentDimView.isUserInteractionEnabled = false
            
            self.closeButton = HighlightableButton()
            self.closeButtonIconView = UIImageView()
            
            self.transitionCloneContainerView = UIView()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            
            self.itemsContainerView.addSubview(self.scroller)
            self.scroller.delegate = self
            self.itemsContainerView.addGestureRecognizer(self.scroller.panGestureRecognizer)
            
            self.addSubview(self.itemsContainerView)
            self.addSubview(self.controlsContainerView)
            
            self.controlsContainerView.addSubview(self.contentDimView)
            self.controlsContainerView.layer.addSublayer(self.topContentGradientLayer)
            self.layer.addSublayer(self.bottomContentGradientLayer)
            
            self.closeButton.addSubview(self.closeButtonIconView)
            self.controlsContainerView.addSubview(self.closeButton)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.delegate = self
            self.itemsContainerView.addGestureRecognizer(tapRecognizer)
            
            self.audioRecorderDisposable = (self.sendMessageContext.audioRecorder.get()
            |> deliverOnMainQueue).start(next: { [weak self] audioRecorder in
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
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            guard let self else {
                                return
                            }
                            if case .stopped = value {
                                self.sendMessageContext.stopMediaRecording(view: self)
                            }
                        })
                    }
                    
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            })
            
            self.videoRecorderDisposable = (self.sendMessageContext.videoRecorder.get()
            |> deliverOnMainQueue).start(next: { [weak self] videoRecorder in
                guard let self else {
                    return
                }
                if self.sendMessageContext.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = self.sendMessageContext.videoRecorderValue
                    self.sendMessageContext.videoRecorderValue = videoRecorder
                    
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
                            //TODO:editing
                        }
                        self.component?.controller()?.present(videoRecorder, in: .window(.root))
                        
                        if self.sendMessageContext.isMediaRecordingLocked {
                            videoRecorder.lockVideo()
                        }
                    }
                    
                    if let previousVideoRecorderValue {
                        previousVideoRecorderValue.dismissVideo()
                    }
                    
                    self.state?.updated(transition: .immediate)
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
        }
        
        func isPointInsideContentArea(point: CGPoint) -> Bool {
            if let inputPanelView = self.inputPanel.view, inputPanelView.alpha != 0.0 {
                if inputPanelView.frame.contains(point) {
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
            
            if self.controlsContainerView.frame.contains(point) {
                return true
            }
            
            return false
        }
        
        func allowsInteractiveGestures() -> Bool {
            if self.displayViewList {
                return false
            }
            return true
        }
        
        func rewindCurrentItem() {
            guard let component = self.component else {
                return
            }
            guard let visibleItem = self.visibleItems[component.slice.item.storyItem.id] else {
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
            guard let visibleItem = self.visibleItems[component.slice.item.storyItem.id] else {
                return
            }
            if let itemView = visibleItem.view.view as? StoryContentItem.View {
                itemView.leaveAmbientMode()
            }
            
            self.state?.updated(transition: .immediate)
        }
        
        func enterAmbientMode() {
            guard let component = self.component else {
                return
            }
            guard let visibleItem = self.visibleItems[component.slice.item.storyItem.id] else {
                return
            }
            if let itemView = visibleItem.view.view as? StoryContentItem.View {
                itemView.enterAmbientMode()
            }
            
            self.state?.updated(transition: .immediate)
        }
        
        @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let component = self.component, let itemLayout = self.itemLayout {
                if hasFirstResponder(self) {
                    self.sendMessageContext.currentInputMode = .text
                    self.endEditing(true)
                } else if self.displayViewList {
                    let point = recognizer.location(in: self)
                    
                    for (id, visibleItem) in self.visibleItems {
                        if visibleItem.contentContainerView.convert(visibleItem.contentContainerView.bounds, to: self).contains(point) {
                            if id == component.slice.item.storyItem.id {
                                self.displayViewList = false
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else {
                                self.animateNextNavigationId = id
                                component.navigate(.id(id))
                            }
                            
                            break
                        }
                    }
                } else if let captionItem = self.captionItem, captionItem.externalState.isExpanded {
                    if let captionItemView = captionItem.view.view as? StoryContentCaptionComponent.View {
                        captionItemView.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                    }
                } else {
                    let point = recognizer.location(in: self)
                    
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
        
        @objc private func closePressed() {
            guard let component = self.component else {
                return
            }
            component.close()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let inputView = self.inputPanel.view, let inputViewHitTest = inputView.hitTest(self.convert(point, to: inputView), with: event) {
                return inputViewHitTest
            }
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result === self.scroller {
                return self.itemsContainerView
            }
            return result
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.scrollingOffsetX = scrollView.contentOffset.x
                
                self.adjustScroller()
                self.updateScrolling(transition: .immediate)
            }
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
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
            self.scroller.setContentOffset(CGPoint(x: self.scrollingCenterX, y: 0.0), animated: true)
        }
        
        private func adjustScroller() {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            self.ignoreScrolling = true
            
            self.scroller.isScrollEnabled = self.displayViewList
            
            let itemSpacing: CGFloat = 12.0
            let centralVisibleItemWidth = itemLayout.contentFrame.width * itemLayout.contentVisualScale
            let sideVisibleItemWidth = centralVisibleItemWidth - 30.0
            let fullItemScrollDistance = centralVisibleItemWidth * 0.5 + itemSpacing + sideVisibleItemWidth * 0.5
            
            var additionalInitializationDistance: CGFloat = 0.0
            if let (switchFromId, switchToId) = self.awaitingSwitchToId {
                if component.slice.item.storyItem.id == switchToId {
                    self.awaitingSwitchToId = nil
                    
                    if let previousIndex = component.slice.allItems.firstIndex(where: { $0.storyItem.id == switchFromId }), let centralIndex = component.slice.allItems.firstIndex(where: { $0.storyItem.id == switchToId }) {
                        let fractionDistance = CGFloat(previousIndex - centralIndex)
                        
                        let currentOffset = self.scrollingCenterX - self.scrollingOffsetX
                        additionalInitializationDistance = -(currentOffset - fractionDistance * fullItemScrollDistance)
                    }
                    
                    self.initializedOffset = false
                } else {
                    self.ignoreScrolling = false
                    return
                }
            }
            
            if let centralIndex = component.slice.allItems.firstIndex(where: { $0.storyItem.id == component.slice.item.storyItem.id }) {
                var leftWidth: CGFloat = 0.0
                var rightWidth: CGFloat = 0.0
                if centralIndex != 0 {
                    leftWidth = 600.0
                }
                if centralIndex != component.slice.allItems.count - 1 {
                    rightWidth = 600.0
                }
                
                self.scrollingCenterX = leftWidth
                self.scroller.contentSize = CGSize(width: leftWidth + itemLayout.containerSize.width + rightWidth, height: 1.0)
                
                if !self.initializedOffset {
                    self.initializedOffset = true
                    self.scrollingOffsetX = leftWidth + additionalInitializationDistance
                    self.scroller.contentOffset = CGPoint(x: self.scrollingOffsetX, y: 0.0)
                }
                
                var lowestFraction: (Int, CGFloat)?
                
                for index in 0 ..< component.slice.allItems.count {
                    let offsetFraction: CGFloat = (self.scrollingCenterX - self.scrollingOffsetX) / fullItemScrollDistance
                    let centerFraction: CGFloat = CGFloat(index - centralIndex)
                    
                    let combinedFraction = abs(offsetFraction + centerFraction)
                    
                    if let (_, lowestValue) = lowestFraction {
                        if combinedFraction < lowestValue {
                            lowestFraction = (index, combinedFraction)
                        }
                    } else {
                        lowestFraction = (index, combinedFraction)
                    }
                }
                
                if let (index, _) = lowestFraction, index != centralIndex {
                    let fixedId = component.slice.allItems[index].storyItem.id
                    component.navigate(.id(fixedId))
                    self.awaitingSwitchToId = (component.slice.item.storyItem.id, fixedId)
                }
            }
            
            self.ignoreScrolling = false
        }
        
        private func isProgressPaused() -> Bool {
            guard let component = self.component else {
                return false
            }
            if component.pinchState != nil {
                return true
            }
            if self.inputPanelExternalState.isEditing || component.isProgressPaused || self.sendMessageContext.actionSheet != nil || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil || self.displayViewList {
                return true
            }
            if let reactionContextNode = self.reactionContextNode, reactionContextNode.isReactionSearchActive {
                return true
            }
            if self.privacyController != nil {
                return true
            }
            if self.isReporting {
                return true
            }
            if self.isEditingStory {
                return true
            }
            if self.sendMessageContext.attachmentController != nil {
                return true
            }
            if self.sendMessageContext.shareController != nil {
                return true
            }
            if self.sendMessageContext.tooltipScreen != nil {
                return true
            }
            if let navigationController = component.controller()?.navigationController as? NavigationController {
                let topViewController = navigationController.topViewController
                if !(topViewController is StoryContainerScreen) && !(topViewController is MediaEditorScreen) && !(topViewController is ShareWithPeersScreen) && !(topViewController is AttachmentController) {
                    return true
                }
            }
            if let captionItem = self.captionItem, captionItem.externalState.isExpanded {
                return true
            }
            return false
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds: [Int32] = []
            var trulyValidIds: [Int32] = []
            
            let centralItemFrame = itemLayout.contentFrame.center.offsetBy(dx: 0.0, dy: 0.0)
            
            let centralVisibleItemWidth = itemLayout.contentFrame.width * itemLayout.contentVisualScale
            let sideVisibleItemWidth = centralVisibleItemWidth - 30.0
            let sideVisibleItemScale = itemLayout.contentVisualScale * (sideVisibleItemWidth / centralVisibleItemWidth)
            
            let itemSpacing: CGFloat = 12.0
            
            let fullItemScrollDistance = centralVisibleItemWidth * 0.5 + itemSpacing + sideVisibleItemWidth * 0.5
            let halfItemScrollDistance = sideVisibleItemWidth * 0.5 + itemSpacing + sideVisibleItemWidth * 0.5
            
            if let centralIndex = component.slice.allItems.firstIndex(where: { $0.storyItem.id == component.slice.item.storyItem.id }) {
                for index in 0 ..< component.slice.allItems.count {
                    let item = component.slice.allItems[index]
                    
                    let offsetFraction: CGFloat = (self.scrollingCenterX - self.scrollingOffsetX) / fullItemScrollDistance
                    let centerIndexOffset = index - centralIndex
                    let centerFraction: CGFloat = CGFloat(centerIndexOffset)
                    
                    let combinedFraction = offsetFraction + centerFraction
                    let combinedFractionSign: CGFloat = combinedFraction < 0.0 ? -1.0 : 1.0
                    
                    let fractionDistanceToCenter: CGFloat = min(1.0, abs(combinedFraction))
                    
                    var itemPosition = centralItemFrame
                    itemPosition.x += min(1.0, abs(combinedFraction)) * combinedFractionSign * fullItemScrollDistance
                    itemPosition.x += max(0.0, abs(combinedFraction) - 1.0) * combinedFractionSign * halfItemScrollDistance
                    
                    var itemVisible = true
                    if abs(centerIndexOffset) > 2 {
                        itemVisible = false
                    }
                    if itemLayout.contentVisualScale >= 1.0 - 0.001 && !self.preparingToDisplayViewList {
                        if index != centralIndex {
                            itemVisible = false
                        }
                    }
                    var reevaluateVisibilityOnCompletion = false
                    if !itemVisible {
                        if transition.animation.isImmediate {
                            continue
                        } else {
                            if self.visibleItems[item.storyItem.id] == nil {
                                continue
                            } else {
                                reevaluateVisibilityOnCompletion = true
                            }
                        }
                    }
                    
                    let scaleFraction: CGFloat = abs(max(-1.0, min(1.0, combinedFraction)))
                    let itemScale = itemLayout.contentVisualScale * (1.0 - scaleFraction) + sideVisibleItemScale * scaleFraction
                    
                    validIds.append(item.storyItem.id)
                    if itemVisible {
                        trulyValidIds.append(item.storyItem.id)
                    }
                    
                    var itemTransition = transition
                    let visibleItem: VisibleItem
                    if let current = self.visibleItems[item.storyItem.id] {
                        visibleItem = current
                    } else {
                        itemTransition = .immediate
                        visibleItem = VisibleItem()
                        self.visibleItems[item.storyItem.id] = visibleItem
                    }
                    
                    let itemEnvironment = StoryContentItem.Environment(
                        externalState: visibleItem.externalState,
                        sharedState: component.storyItemSharedState,
                        theme: component.theme,
                        presentationProgressUpdated: { [weak self, weak visibleItem] progress, canSwitch in
                            guard let self = self, let component = self.component else {
                                return
                            }
                            guard let visibleItem else {
                                return
                            }
                            visibleItem.currentProgress = progress
                            
                            if let navigationStripView = self.navigationStrip.view as? MediaNavigationStripComponent.View {
                                navigationStripView.updateCurrentItemProgress(value: progress, transition: .immediate)
                            }
                            if progress >= 1.0 && canSwitch && !visibleItem.requestedNext {
                                visibleItem.requestedNext = true
                                
                                component.navigate(.next)
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
                            synchronousLoad: index == centralIndex
                        )),
                        component: AnyComponent(StoryItemContentComponent(
                            context: component.context,
                            peer: component.slice.peer,
                            item: item.storyItem
                        )),
                        environment: {
                            itemEnvironment
                        },
                        containerSize: itemLayout.contentFrame.size
                    )
                    if let view = visibleItem.view.view {
                        if visibleItem.contentContainerView.superview == nil {
                            self.itemsContainerView.addSubview(visibleItem.contentContainerView)
                            visibleItem.contentContainerView.addSubview(view)
                        }
                        
                        itemTransition.setPosition(view: view, position: CGPoint(x: itemLayout.contentFrame.size.width * 0.5, y: itemLayout.contentFrame.size.height * 0.5))
                        itemTransition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
                        let itemId = item.storyItem.id
                        itemTransition.setPosition(view: visibleItem.contentContainerView, position: itemPosition, completion: { [weak self] _ in
                            guard reevaluateVisibilityOnCompletion, let self else {
                                return
                            }
                            if !self.trulyValidIds.contains(itemId), let visibleItem = self.visibleItems[itemId] {
                                self.visibleItems.removeValue(forKey: itemId)
                                visibleItem.contentContainerView.removeFromSuperview()
                            }
                        })
                        itemTransition.setBounds(view: visibleItem.contentContainerView, bounds: CGRect(origin: CGPoint(), size: itemLayout.contentFrame.size))
                        
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
                        itemTransition.setAlpha(view: visibleItem.contentContainerView, alpha: 1.0 * (1.0 - fractionDistanceToCenter) + 0.75 * fractionDistanceToCenter)
                        
                        var itemProgressPaused = self.isProgressPaused()
                        if index != centralIndex {
                            itemProgressPaused = true
                        }

                        if let view = view as? StoryContentItem.View {
                            view.setIsProgressPaused(itemProgressPaused)
                        }
                    }
                }
            }
            
            self.trulyValidIds = trulyValidIds
            
            var removeIds: [Int32] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    visibleItem.contentContainerView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func updateIsProgressPaused() {
            let isProgressPaused = self.isProgressPaused()
            var centralId: Int32?
            if let component = self.component {
                centralId = component.slice.item.storyItem.id
            }
            
            for (id, visibleItem) in self.visibleItems {
                if let view = visibleItem.view.view {
                    if let view = view as? StoryContentItem.View {
                        view.setIsProgressPaused(isProgressPaused || id != centralId)
                    }
                }
            }
        }
        
        func activateInput() -> Bool {
            guard let component = self.component else {
                return false
            }
            if component.slice.peer.id == component.context.account.peerId {
                if let views = component.slice.item.storyItem.views, !views.seenPeers.isEmpty {
                    self.displayViewList = true
                    if component.verticalPanFraction == 0.0 {
                        self.preparingToDisplayViewList = true
                        self.updateScrolling(transition: .immediate)
                        self.preparingToDisplayViewList = false
                    }
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                    return true
                }
            } else {
                if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                    inputPanelView.activateInput()
                    return false
                }
            }
            return false
        }
        
        func activateInputWhileDragging() -> (() -> Void)? {
            guard let component = self.component else {
                return nil
            }
            if component.slice.peer.id == component.context.account.peerId {
            } else {
                if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                    return { [weak inputPanelView] in
                        inputPanelView?.activateInput()
                    }
                }
            }
            
            return nil
        }
        
        func animateIn(transitionIn: StoryContainerScreen.TransitionIn) {
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
            if let viewListView = self.viewList?.view.view {
                viewListView.layer.animatePosition(
                    from: CGPoint(x: 0.0, y: self.bounds.height - self.controlsContainerView.frame.maxY),
                    to: CGPoint(),
                    duration: 0.3,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    additive: true
                )
                viewListView.layer.animateAlpha(from: 0.0, to: viewListView.alpha, duration: 0.28)
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
            
            if let component = self.component, let sourceView = transitionIn.sourceView, let contentContainerView = self.visibleItems[component.slice.item.storyItem.id]?.contentContainerView {
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                if let moreButtonView = self.moreButton.view {
                    moreButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                if let soundButtonView = self.soundButton.view {
                    soundButtonView.layer.animateAlpha(from: 0.0, to: soundButtonView.alpha, duration: 0.25)
                }
                if let closeFriendIcon = self.closeFriendIcon?.view {
                    closeFriendIcon.layer.animateAlpha(from: 0.0, to: closeFriendIcon.alpha, duration: 0.25)
                }
                self.closeButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                
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
                
                self.controlsContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.controlsContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.controlsContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.controlsContainerView.layer.animate(
                    from: transitionIn.sourceCornerRadius as NSNumber,
                    to: self.controlsContainerView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
                if let component = self.component, let visibleItemView = self.visibleItems[component.slice.item.storyItem.id]?.view.view {
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
            }
        }
        
        func animateOut(transitionOut: StoryContainerScreen.TransitionOut, transitionCloneMasterView: UIView, completion: @escaping () -> Void) {
            var cleanups: [() -> Void] = []
            
            self.sendMessageContext.animateOut(bounds: self.bounds)
            
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
            if let viewListView = self.viewList?.view.view {
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
            
            if let component = self.component, let sourceView = transitionOut.destinationView, let contentContainerView = self.visibleItems[component.slice.item.storyItem.id]?.contentContainerView {
                let sourceLocalFrame = sourceView.convert(transitionOut.destinationRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - contentContainerView.frame.minX, y: sourceLocalFrame.minY - contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                let contentSourceFrame = contentContainerView.frame
                
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let moreButtonView = self.moreButton.view {
                    moreButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let soundButtonView = self.soundButton.view {
                    soundButtonView.layer.animateAlpha(from: soundButtonView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                if let closeFriendIconView = self.closeFriendIcon?.view {
                    closeFriendIconView.layer.animateAlpha(from: closeFriendIconView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                self.closeButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                
                if let leftInfoView = self.leftInfoItem?.view.view {
                    if transitionOut.destinationIsAvatar {
                        let transitionView = transitionOut.transitionView
                        
                        var transitionViewsImpl: [UIView] = []
                        
                        if let transitionViewImpl = transitionView?.makeView() {
                            transitionViewsImpl.append(transitionViewImpl)
                            
                            let transitionSourceContainerView = UIView(frame: self.bounds)
                            transitionSourceContainerView.isUserInteractionEnabled = false
                            self.insertSubview(transitionSourceContainerView, aboveSubview: self.itemsContainerView)
                            
                            transitionSourceContainerView.addSubview(transitionViewImpl)
                            
                            if let insertCloneTransitionView = transitionView?.insertCloneTransitionView {
                                if let transitionCloneViewImpl = transitionView?.makeView() {
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
                            
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            
                            for transitionViewImpl in transitionViewsImpl {
                                transitionViewImpl.alpha = 1.0
                                transitionViewImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                            }
                            
                            leftInfoView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                            
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
                
                self.controlsContainerView.layer.animatePosition(from: self.controlsContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsContainerView.layer.animateBounds(from: self.controlsContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.controlsContainerView.layer.animate(
                    from: self.controlsContainerView.layer.cornerRadius as NSNumber,
                    to: transitionOut.destinationCornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                if !transitionOut.destinationIsAvatar {
                    let transitionView = transitionOut.transitionView
                    
                    var transitionViewsImpl: [UIView] = []
                    
                    if let transitionViewImpl = transitionView?.makeView() {
                        transitionViewsImpl.append(transitionViewImpl)
                        
                        let transitionSourceContainerView = UIView(frame: self.bounds)
                        transitionSourceContainerView.isUserInteractionEnabled = false
                        self.insertSubview(transitionSourceContainerView, belowSubview: self.itemsContainerView)
                        
                        transitionSourceContainerView.addSubview(transitionViewImpl)
                        
                        if let insertCloneTransitionView = transitionView?.insertCloneTransitionView {
                            if let transitionCloneViewImpl = transitionView?.makeView() {
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
                        
                        let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                        
                        for transitionViewImpl in transitionViewsImpl {
                            transitionViewImpl.alpha = 1.0
                            transitionViewImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                        contentContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        self.controlsContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        
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
                
                if let component = self.component, let visibleItemView = self.visibleItems[component.slice.item.storyItem.id]?.view.view {
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
        
        func update(component: StoryItemSetContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), case .textFocusChanged = hint.kind, !hasFirstResponder(self) {
                self.sendMessageContext.currentInputMode = .text
            }
            
            if self.component == nil {
                self.sendMessageContext.setup(context: component.context, view: self, inputPanelExternalState: self.inputPanelExternalState)
                
                let _ = (allowedStoryReactions(context: component.context)
                |> deliverOnMainQueue).start(next: { [weak self] reactionItems in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    component.controller()?.forEachController { c in
                        if let c = c as? UndoOverlayController {
                            c.dismiss()
                        }
                        return true
                    }
                    
                    self.reactionItems = reactionItems
                })
            }
            
            if self.component?.slice.item.storyItem.id != component.slice.item.storyItem.id {
                component.markAsSeen(StoryId(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id))
                self.initializedOffset = false
            }
            var itemsTransition = transition
            if let animateNextNavigationId = self.animateNextNavigationId, animateNextNavigationId == component.slice.item.storyItem.id {
                self.animateNextNavigationId = nil
                itemsTransition = transition.withAnimation(.curve(duration: 0.3, curve: .spring))
            }
            
            if self.topContentGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 4
                let baseAlpha: CGFloat = 0.5
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.5)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.topContentGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                self.topContentGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
                
                self.topContentGradientLayer.locations = locations
                self.topContentGradientLayer.colors = colors
                self.topContentGradientLayer.type = .axial
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
                
                self.contentDimView.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
            }
            
            let wasPanning = self.component?.isPanning ?? false
            self.component = component
            self.state = state
            
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
            
            var isUnsupported = false
            var disabledPlaceholder: String?
            if component.slice.peer.isService {
                disabledPlaceholder = "You can't reply to this story"
            } else if case .unsupported = component.slice.item.storyItem.media {
                isUnsupported = true
                disabledPlaceholder = "You can't reply to this story"
            }
             
            let keyboardWasHidden = self.inputPanelExternalState.isKeyboardHidden
            let inputNodeVisible = self.sendMessageContext.currentInputMode == .media || hasFirstResponder(self)
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: inputPanelTransition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    style: .story,
                    placeholder: "Reply Privately...",
                    alwaysDarkWhenHasText: component.metrics.widthClass == .regular,
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
                    sendMessageAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.performSendMessageAction(view: self)
                    },
                    setMediaRecordingActive: { [weak self] isActive, isVideo, sendAction in
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
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
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
                        self.sendMessageContext.discardMediaRecordingPreview(view: self)
                    },
                    attachmentAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.presentAttachmentMenu(view: self, subject: .default)
                    },
                    inputModeAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.toggleInputMode()
                        self.state?.updated(transition: .immediate)
                    },
                    timeoutAction: nil,
                    forwardAction: component.slice.item.storyItem.isPublic ? { [weak self] in
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
                    presentVoiceMessagesUnavailableTooltip: { [weak self] view in
                        guard let self, let component = self.component, self.voiceMessagesRestrictedTooltipController == nil else {
                            return
                        }
                        let rect = view.convert(view.bounds, to: nil)
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let text = presentationData.strings.Conversation_VoiceMessagesRestricted(component.slice.peer.compactDisplayTitle).string
                        let controller = TooltipController(content: .text(text), baseFontSize: presentationData.listsFontSize.baseDisplaySize, padding: 2.0)
                        controller.dismissed = { [weak self] _ in
                            if let self {
                                self.voiceMessagesRestrictedTooltipController = nil
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                            }
                        }
                        component.presentController(controller, TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                            if let self {
                                return (self, rect)
                            }
                            return nil
                        }))
                        self.voiceMessagesRestrictedTooltipController = controller
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                    },
                    audioRecorder: self.sendMessageContext.audioRecorderValue,
                    videoRecordingStatus: self.sendMessageContext.videoRecorderValue?.audioStatus,
                    isRecordingLocked: self.sendMessageContext.isMediaRecordingLocked,
                    recordedAudioPreview: self.sendMessageContext.recordedAudioPreview,
                    wasRecordingDismissed: self.sendMessageContext.wasRecordingDismissed,
                    timeoutValue: nil,
                    timeoutSelected: false,
                    displayGradient: false, //(component.inputHeight != 0.0 || inputNodeVisible) && component.metrics.widthClass != .regular,
                    bottomInset: component.inputHeight != 0.0 || inputNodeVisible ? 0.0 : bottomContentInset,
                    hideKeyboard: self.sendMessageContext.currentInputMode == .media,
                    disabledPlaceholder: disabledPlaceholder
                )),
                environment: {},
                containerSize: CGSize(width: inputPanelAvailableWidth, height: 200.0)
            )
            
            var inputHeight = component.inputHeight
            if self.inputPanelExternalState.isEditing {
                if self.sendMessageContext.currentInputMode == .media || (inputHeight.isZero && keyboardWasHidden) {
                    inputHeight = component.deviceMetrics.standardInputHeight(inLandscape: false)
                }
            }
            
            let inputPanelBackgroundSize = self.inputPanelBackground.update(
                transition: transition,
                component: AnyComponent(BlurredGradientComponent(position: .bottom, dark: true, tag: nil)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: component.deviceMetrics.standardInputHeight(inLandscape: false) + 100.0)
            )
            if let inputPanelBackgroundView = self.inputPanelBackground.view {
                if inputPanelBackgroundView.superview == nil {
                    self.addSubview(inputPanelBackgroundView)
                }
                let isVisible = inputHeight > 44.0
                transition.setFrame(view: inputPanelBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: isVisible ? availableSize.height - inputPanelBackgroundSize.height : availableSize.height), size: inputPanelBackgroundSize))
                transition.setAlpha(view: inputPanelBackgroundView, alpha: isVisible ? 1.0 : 0.0, delay: isVisible ? 0.0 : 0.4)
            }
            
            self.sendMessageContext.updateInputMediaNode(inputPanel: self.inputPanel, availableSize: availableSize, bottomInset: component.safeInsets.bottom, inputHeight: component.inputHeight, effectiveInputHeight: inputHeight, metrics: component.metrics, deviceMetrics: component.deviceMetrics, transition: transition)
            
            var viewListInset: CGFloat = 0.0
            
            var inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if inputHeight == 0.0 {
                inputPanelBottomInset = bottomContentInset
                if case .regular = component.metrics.widthClass {
                    bottomContentInset += 60.0
                } else {
                    bottomContentInset += inputPanelSize.height
                }
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = inputHeight - component.containerInsets.bottom
                inputPanelIsOverlay = true
            }
            
            if component.slice.peer.id == component.context.account.peerId {
                let viewList: ViewList
                var viewListTransition = transition
                if let current = self.viewList {
                    viewList = current
                } else {
                    if !transition.animation.isImmediate {
                        viewListTransition = .immediate
                    }
                    viewList = ViewList()
                    self.viewList = viewList
                }
                
                let outerExpansionFraction: CGFloat
                if self.displayViewList {
                    outerExpansionFraction = 1.0
                } else if let views = component.slice.item.storyItem.views, !views.seenPeers.isEmpty {
                    outerExpansionFraction = component.verticalPanFraction
                } else {
                    outerExpansionFraction = 0.0
                }
                
                viewList.view.parentState = state
                let viewListSize = viewList.view.update(
                    transition: viewListTransition.withUserData(PeerListItemComponent.TransitionHint(
                        synchronousLoad: false
                    )),
                    component: AnyComponent(StoryItemSetViewListComponent(
                        externalState: viewList.externalState,
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        safeInsets: component.safeInsets,
                        storyItem: component.slice.item.storyItem,
                        outerExpansionFraction: outerExpansionFraction,
                        close: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.displayViewList = false
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        },
                        expandViewStats: { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            if !self.displayViewList {
                                self.displayViewList = true
                                
                                self.preparingToDisplayViewList = true
                                self.updateScrolling(transition: .immediate)
                                self.preparingToDisplayViewList = false
                                
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                            }
                        },
                        deleteAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            let actionSheet = ActionSheetController(presentationData: presentationData)
                            
                            actionSheet.setItemGroups([
                                ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: "Delete Story", color: .destructive, action: { [weak self, weak actionSheet] in
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
                            self.navigateToPeer(peer: peer)
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let viewListFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - viewListSize.height), size: viewListSize)
                if let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                    var animateIn = false
                    if viewListView.superview == nil {
                        self.addSubview(viewListView)
                        animateIn = true
                    }
                    viewListTransition.setFrame(view: viewListView, frame: viewListFrame)
                    viewListTransition.setAlpha(view: viewListView, alpha: component.hideUI || self.isEditingStory ? 0.0 : 1.0)
                    
                    if animateIn, !transition.animation.isImmediate {
                        viewListView.animateIn(transition: transition)
                    }
                }
                viewListInset = viewList.externalState.effectiveHeight
                inputPanelBottomInset = viewListInset
            } else if let viewList = self.viewList {
                self.viewList = nil
                if let viewListView = viewList.view.view as? StoryItemSetViewListComponent.View {
                    viewListView.animateOut(transition: transition, completion: { [weak viewListView] in
                        viewListView?.removeFromSuperview()
                    })
                }
            }
            
            let itemSize = CGSize(width: availableSize.width, height: ceil(availableSize.width * 1.77778))
            let contentDefaultBottomInset: CGFloat = bottomContentInset
            let contentSize = itemSize
            
            let contentVisualBottomInset: CGFloat = max(contentDefaultBottomInset, viewListInset)
            
            var contentVisualHeight = min(contentSize.height, availableSize.height - component.containerInsets.top - contentVisualBottomInset)
            if contentVisualHeight < contentSize.height && contentVisualHeight >= contentSize.height - 5 {
                contentVisualHeight = contentSize.height
            }
            let contentVisualScale = min(1.0, contentVisualHeight / contentSize.height)
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: component.containerInsets.top - (contentSize.height - contentVisualHeight) * 0.5), size: contentSize)
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                contentFrame: contentFrame,
                contentVisualScale: contentVisualScale
            )
            self.itemLayout = itemLayout
            
            transition.setFrame(view: self.itemsContainerView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: component.containerInsets.top + floor(contentVisualHeight))))
            
            transition.setPosition(view: self.controlsContainerView, position: contentFrame.center)
            transition.setBounds(view: self.controlsContainerView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
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
            
            transition.setCornerRadius(layer: self.controlsContainerView.layer, cornerRadius: 12.0 * (1.0 / contentVisualScale))
            
            var headerRightOffset: CGFloat = availableSize.width
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Stories/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonFrame = CGRect(origin: CGPoint(x: headerRightOffset - 50.0, y: 2.0), size: CGSize(width: 50.0, height: 64.0))
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
                headerRightOffset -= 51.0
            }
            
            let moreButtonSize = self.moreButton.update(
                transition: transition,
                component: AnyComponent(MessageInputActionButtonComponent(
                    mode: .more,
                    action: { _, _, _ in
                    },
                    switchMediaInputMode: {
                    },
                    updateMediaCancelFraction: { _ in
                    },
                    lockMediaRecording: {
                    },
                    stopAndPreviewMediaRecording: {
                    },
                    moreAction: { [weak self] view, gesture in
                        guard let self else {
                            return
                        }
                        self.performMoreAction(sourceView: view, gesture: gesture)
                    },
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    presentController: { [weak self] c in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.presentController(c, nil)
                    },
                    audioRecorder: nil,
                    videoRecordingStatus: nil
                )),
                environment: {},
                containerSize: CGSize(width: 33.0, height: 64.0)
            )
            if let moreButtonView = self.moreButton.view {
                if moreButtonView.superview == nil {
                    self.controlsContainerView.addSubview(moreButtonView)
                }
                transition.setFrame(view: moreButtonView, frame: CGRect(origin: CGPoint(x: headerRightOffset - moreButtonSize.width, y: 2.0), size: moreButtonSize))
                headerRightOffset -= moreButtonSize.width + 15.0
            }
            
            var isSilentVideo = false
            var isVideo = false
            var soundAlpha: CGFloat = 0.0
            if case let .file(file) = component.slice.item.storyItem.media {
                isVideo = true
                soundAlpha = 1.0
                for attribute in file.attributes {
                    if case let .Video(_, _, flags, _) = attribute {
                        if flags.contains(.isSilent) {
                            isSilentVideo = true
                            soundAlpha = 0.5
                        }
                    }
                }
            }
            
            let soundImage: String
            if isSilentVideo || component.storyItemSharedState.useAmbientMode {
                soundImage = "Stories/SoundOff"
            } else {
                soundImage = "Stories/SoundOn"
            }
            
            let soundButtonSize = self.soundButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: soundImage,
                        tintColor: .white,
                        maxSize: nil
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
                                if case let .Video(_, _, flags, _) = attribute {
                                    if flags.contains(.isSilent) {
                                        isSilentVideo = true
                                    }
                                }
                            }
                        }
                        
                        if isSilentVideo {
                            guard let soundButtonView = self.soundButton.view else {
                                return
                            }
                            let tooltipScreen = TooltipScreen(
                                account: component.context.account,
                                sharedContext: component.context.sharedContext,
                                text: .plain(text: "This video has no sound"), style: .default, location: TooltipScreen.Location.point(soundButtonView.convert(soundButtonView.bounds, to: self).offsetBy(dx: 1.0, dy: -10.0), .top), displayDuration: .manual(true), shouldDismissOnTouch: { _ in
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
                            self.sendMessageContext.tooltipScreen = tooltipScreen
                            self.updateIsProgressPaused()
                            component.controller()?.present(tooltipScreen, in: .current)
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
                    self.controlsContainerView.addSubview(soundButtonView)
                }
                transition.setFrame(view: soundButtonView, frame: CGRect(origin: CGPoint(x: headerRightOffset - soundButtonSize.width, y: 2.0), size: soundButtonSize))
                transition.setAlpha(view: soundButtonView, alpha: soundAlpha)
                
                if isVideo {
                    headerRightOffset -= soundButtonSize.width + 16.0
                }
            }
            
            if component.slice.item.storyItem.isCloseFriends && component.slice.peer.id != component.context.account.peerId {
                let closeFriendIcon: ComponentView<Empty>
                var closeFriendIconTransition = transition
                if let current = self.closeFriendIcon {
                    closeFriendIcon = current
                } else {
                    closeFriendIconTransition = .immediate
                    closeFriendIcon = ComponentView()
                    self.closeFriendIcon = closeFriendIcon
                }
                let closeFriendIconSize = closeFriendIcon.update(
                    transition: closeFriendIconTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Stories/CloseStoryIcon",
                            tintColor: nil,
                            maxSize: nil
                        )),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let closeFriendIconView = self.closeFriendIcon?.view else {
                                return
                            }
                            let tooltipScreen = TooltipScreen(
                                account: component.context.account,
                                sharedContext: component.context.sharedContext,
                                text: .plain(text: "You are seeing this story because you have\nbeen added to \(component.slice.peer.compactDisplayTitle)'s list of close friends."), style: .default, location: TooltipScreen.Location.point(closeFriendIconView.convert(closeFriendIconView.bounds, to: self).offsetBy(dx: 1.0, dy: 6.0), .top), displayDuration: .manual(true), shouldDismissOnTouch: { _ in
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
                            self.sendMessageContext.tooltipScreen = tooltipScreen
                            self.updateIsProgressPaused()
                            component.controller()?.present(tooltipScreen, in: .current)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let closeFriendIconFrame = CGRect(origin: CGPoint(x: headerRightOffset - closeFriendIconSize.width - 8.0, y: 23.0), size: closeFriendIconSize)
                if let closeFriendIconView = closeFriendIcon.view {
                    if closeFriendIconView.superview == nil {
                        self.controlsContainerView.addSubview(closeFriendIconView)
                    }
                    
                    closeFriendIconTransition.setFrame(view: closeFriendIconView, frame: closeFriendIconFrame)
                    headerRightOffset -= 44.0
                }
            } else if let closeFriendIcon = self.closeFriendIcon {
                self.closeFriendIcon = nil
                closeFriendIcon.view?.removeFromSuperview()
            }
            
            transition.setAlpha(view: self.controlsContainerView, alpha: (component.hideUI || self.isEditingStory || self.displayViewList) ? 0.0 : 1.0)
            
            let focusedItem: StoryContentItem? = component.slice.item
            let _ = focusedItem
            
            var currentLeftInfoItem: InfoItem?
            if focusedItem != nil {
                let leftInfoComponent = AnyComponent(StoryAvatarInfoComponent(context: component.context, peer: component.slice.peer))
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
            if focusedItem != nil {
                let centerInfoComponent = AnyComponent(StoryAuthorInfoComponent(context: component.context, peer: component.slice.peer, timestamp: component.slice.item.storyItem.timestamp))
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
                        self.navigateToPeer(peer: component.slice.peer)
                    })),
                    environment: {},
                    containerSize: CGSize(width: contentFrame.width, height: 44.0)
                )
                if let view = currentCenterInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.controlsContainerView.insertSubview(view, belowSubview: self.closeButton)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: centerInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        //view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    
                    transition.setAlpha(view: view, alpha: self.isEditingStory ? 0.0 : 1.0)
                }
            }
            
            if let currentLeftInfoItem {
                self.leftInfoItem = currentLeftInfoItem
                
                let leftInfoItemSize = currentLeftInfoItem.view.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(content: currentLeftInfoItem.component, effectAlignment: .center, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.navigateToPeer(peer: component.slice.peer)
                    })),
                    environment: {},
                    containerSize: CGSize(width: 32.0, height: 32.0)
                )
                if let view = currentLeftInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.controlsContainerView.addSubview(view)
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
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            transition.setAlpha(layer: self.topContentGradientLayer, alpha: (component.hideUI || self.displayViewList || self.isEditingStory) ? 0.0 : 1.0)
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - inputPanelSize.width) / 2.0), y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
            var inputPanelAlpha: CGFloat = component.slice.peer.id == component.context.account.peerId || component.hideUI || self.isEditingStory ? 0.0 : 1.0
            if case .regular = component.metrics.widthClass {
                inputPanelAlpha *= component.visibilityFraction
            }
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                
                var inputPanelOffset: CGFloat = 0.0
                if component.slice.peer.id != component.context.account.peerId && !self.inputPanelExternalState.isEditing {
                    let bandingOffset = scrollingRubberBandingOffset(offset: component.verticalPanFraction * availableSize.height, bandingStart: 0.0, range: 10.0)
                    inputPanelOffset = -max(0.0, min(10.0, bandingOffset))
                }
                
                inputPanelTransition.setFrame(view: inputPanelView, frame: inputPanelFrame.offsetBy(dx: 0.0, dy: inputPanelOffset))
                transition.setAlpha(view: inputPanelView, alpha: inputPanelAlpha)
            }
            
            if let captionItem = self.captionItem, captionItem.itemId != component.slice.item.storyItem.id {
                self.captionItem = nil
                if let captionItemView = captionItem.view.view {
                    captionItemView.removeFromSuperview()
                }
            }
            
            if !isUnsupported, !component.slice.item.storyItem.text.isEmpty {
                var captionItemTransition = transition
                let captionItem: CaptionItem
                if let current = self.captionItem {
                    captionItem = current
                } else {
                    if !transition.animation.isImmediate {
                        captionItemTransition = .immediate
                    }
                    captionItem = CaptionItem(itemId: component.slice.item.storyItem.id)
                    self.captionItem = captionItem
                }
                
                let captionSize = captionItem.view.update(
                    transition: captionItemTransition,
                    component: AnyComponent(StoryContentCaptionComponent(
                        externalState: captionItem.externalState,
                        context: component.context,
                        text: component.slice.item.storyItem.text,
                        entities: component.slice.item.storyItem.entities,
                        action: { [weak self] action in
                            guard let self, let component = self.component else {
                                return
                            }
                            switch action {
                            case let .url(url, concealed):
                                openUserGeneratedUrl(context: component.context, peerId: component.slice.peer.id, url: url, concealed: concealed, skipUrlAuth: false, skipConcealedAlert: false, present: { [weak self] c in
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
                            case let .textMention(value):
                                self.sendMessageContext.openPeerMention(view: self, name: value)
                            case let .peerMention(peerId, _):
                                self.sendMessageContext.openPeerMention(view: self, peerId: peerId)
                            case let .hashtag(username, value):
                                self.sendMessageContext.openHashtag(view: self, hashtag: value, peerName: username)
                            case let .bankCard(value):
                                let _ = value
                            case .customEmoji:
                                break
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: contentFrame.height)
                )
                captionItem.view.parentState = state
                let captionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.height - captionSize.height), size: captionSize)
                if let captionItemView = captionItem.view.view {
                    if captionItemView.superview == nil {
                        self.controlsContainerView.insertSubview(captionItemView, aboveSubview: self.contentDimView)
                    }
                    captionItemTransition.setFrame(view: captionItemView, frame: captionFrame)
                    captionItemTransition.setAlpha(view: captionItemView, alpha: (component.hideUI || self.displayViewList || self.isEditingStory || self.inputPanelExternalState.isEditing) ? 0.0 : 1.0)
                }
            }
            
            let reactionsAnchorRect = CGRect(origin: CGPoint(x: inputPanelFrame.maxX - 40.0, y: inputPanelFrame.minY + 9.0), size: CGSize(width: 32.0, height: 32.0)).insetBy(dx: -4.0, dy: -4.0)
            
            var effectiveDisplayReactions = false
            if self.inputPanelExternalState.isEditing && !self.inputPanelExternalState.hasText  {
                effectiveDisplayReactions = true
            }
            if self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil {
                effectiveDisplayReactions = false
            }
            if self.sendMessageContext.recordedAudioPreview != nil {
                effectiveDisplayReactions = false
            }
            if self.voiceMessagesRestrictedTooltipController != nil {
                effectiveDisplayReactions = false
            }
//            if self.sendMessageContext.currentInputMode != .text {
//                effectiveDisplayReactions = false
//            }
            
            if let reactionContextNode = self.reactionContextNode, reactionContextNode.isReactionSearchActive {
                effectiveDisplayReactions = true
            }
            
            if let reactionItems = self.reactionItems, effectiveDisplayReactions {
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
                        items: reactionItems.map(ReactionContextItem.reaction),
                        selectedItems: Set(),
                        getEmojiContent: { [weak self] animationCache, animationRenderer in
                            guard let self, let component = self.component else {
                                preconditionFailure()
                            }
                            
                            let mappedReactionItems: [EmojiComponentReactionItem] = reactionItems.map { reaction -> EmojiComponentReactionItem in
                                return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                            }
                            
                            return EmojiPagerContentComponent.emojiInputData(
                                context: component.context,
                                animationCache: animationCache,
                                animationRenderer: animationRenderer,
                                isStandalone: false,
                                isStatusSelection: false,
                                isReactionSelection: true,
                                isEmojiSelection: false,
                                hasTrending: false,
                                topReactionItems: mappedReactionItems,
                                areUnicodeEmojiEnabled: false,
                                areCustomEmojiEnabled: true,
                                chatPeerId: component.context.account.peerId,
                                selectedItems: Set(),
                                premiumIfSavedMessages: false
                            )
                        },
                        isExpandedUpdated: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: Transition(transition))
                        },
                        requestLayout: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: Transition(transition))
                        },
                        requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            self.state?.updated(transition: Transition(transition))
                        }
                    )
                    reactionContextNode.displayTail = false
                    self.reactionContextNode = reactionContextNode
                    
                    reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = (component.context.engine.stickers.availableReactions()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] availableReactions in
                            guard let self, let component = self.component, let availableReactions else {
                                return
                            }
                            
                            var animation: TelegramMediaFile?
                            for reaction in availableReactions.reactions {
                                if reaction.value == updateReaction.reaction {
                                    animation = reaction.centerAnimation
                                    break
                                }
                            }
                                                        
                            let targetView = UIView(frame: CGRect(origin: CGPoint(x: floor((self.bounds.width - 100.0) * 0.5), y: floor((self.bounds.height - 100.0) * 0.5)), size: CGSize(width: 100.0, height: 100.0)))
                            targetView.isUserInteractionEnabled = false
                            self.addSubview(targetView)
                            
                            reactionContextNode.willAnimateOutToReaction(value: updateReaction.reaction)
                            reactionContextNode.animateOutToReaction(value: updateReaction.reaction, targetView: targetView, hideNode: false, animateTargetContainer: nil, addStandaloneReactionAnimation: "".isEmpty ? nil : { [weak self] standaloneReactionAnimation in
                                guard let self else {
                                    return
                                }
                                standaloneReactionAnimation.frame = self.bounds
                                self.addSubview(standaloneReactionAnimation.view)
                            }, completion: { [weak targetView, weak reactionContextNode] in
                                targetView?.removeFromSuperview()
                                if let reactionContextNode {
                                    reactionContextNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.3, removeOnCompletion: false)
                                    reactionContextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak reactionContextNode] _ in
                                        reactionContextNode?.view.removeFromSuperview()
                                    })
                                }
                            })
    
                            
                            if hasFirstResponder(self) {
                                self.sendMessageContext.currentInputMode = .text
                                self.endEditing(true)
                            }
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                                                        
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
                            }

                            let message: EnqueueMessage = .message(
                                text: text,
                                attributes: messageAttributes,
                                inlineStickers: inlineStickers,
                                mediaReference: nil,
                                replyToMessageId: nil,
                                replyToStoryId: StoryId(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id),
                                localGroupingKey: nil,
                                correlationId: nil,
                                bubbleUpEmojiOrStickersets: []
                            )
                            
                            let context = component.context
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            let presentController = component.presentController
                            let peer = component.slice.peer
                            
                            let _ = (enqueueMessages(account: context.account, peerId: peer.id, messages: [message])
                            |> deliverOnMainQueue).start(next: { [weak self] messageIds in
                                if let animation {
                                    presentController(UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .sticker(context: context, file: animation, loop: false, title: nil, text: "Reaction Sent.", undoText: "View in Chat", customAction: { [weak self] in
                                            if let messageId = messageIds.first, let self {
                                                self.navigateToPeer(peer: peer, messageId: messageId)
                                            }
                                        }),
                                        elevatedLayout: false,
                                        animateInAsReplacement: false,
                                        action: { _ in return false }
                                    ), nil)
                                }
                            })
                        })
                    }
                    
                    reactionContextNode.premiumReactionsSelected = { [weak self] file in
                        guard let self, let file, let component = self.component else {
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: component.context, file: file, loop: true, title: nil, text: presentationData.strings.Chat_PremiumReactionToastTitle, undoText: presentationData.strings.Chat_PremiumReactionToastAction, customAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let context = component.context
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, action: {
                                let controller = PremiumIntroScreen(context: context, source: .reactions)
                                replaceImpl?(controller)
                            })
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            component.controller()?.push(controller)
                        }), elevatedLayout: false, animateInAsReplacement: false, action: { _ in true })
                        //strongSelf.currentUndoController = undoController
                        component.controller()?.present(undoController, in: .current)
                    }
                }
                
                var animateReactionsIn = false
                if reactionContextNode.view.superview == nil {
                    animateReactionsIn = true
                    self.addSubnode(reactionContextNode)
                }
                
                if reactionContextNode.isAnimatingOutToReaction {
                    if !reactionContextNode.isAnimatingOut {
                        reactionContextNode.animateOut(to: reactionsAnchorRect, animatingOutToReaction: true)
                    }
                } else {
                    reactionContextNodeTransition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                    reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: true, isCoveredByInput: false, isAnimatingOut: false, transition: reactionContextNodeTransition.containedViewLayoutTransition)
                    
                    if animateReactionsIn {
                        reactionContextNode.animateIn(from: reactionsAnchorRect)
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
                        transition.setAlpha(view: reactionContextNode.view, alpha: 0.0, completion: { [weak reactionContextNode] _ in
                            reactionContextNode?.view.removeFromSuperview()
                        })
                    }
                }
            }
            if let reactionContextNode = self.disappearingReactionContextNode {
                if !reactionContextNode.isAnimatingOutToReaction {
                    transition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                    reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, isCoveredByInput: false, isAnimatingOut: false, transition: transition.containedViewLayoutTransition)
                }
            }
            
            let bottomGradientHeight = inputPanelSize.height + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            //transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: 0.0)
            
            var normalDimAlpha: CGFloat = 0.0
            var forceDimAnimation = false
            if let captionItem = self.captionItem {
                normalDimAlpha = captionItem.externalState.isExpanded ? 1.0 : 0.0
                if transition.animation.isImmediate && transition.userData(StoryContentCaptionComponent.TransitionHint.self)?.kind == .isExpandedUpdated {
                    forceDimAnimation = true
                }
            }
            var dimAlpha: CGFloat = (inputPanelIsOverlay || self.inputPanelExternalState.isEditing) ? 1.0 : normalDimAlpha
            if component.hideUI || self.displayViewList || self.isEditingStory {
                dimAlpha = 0.0
            }
            
            transition.setFrame(view: self.contentDimView, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            if transition.animation.isImmediate && forceDimAnimation && self.contentDimView.alpha != dimAlpha {
                Transition(animation: .curve(duration: 0.25, curve: .easeInOut)).setAlpha(view: self.contentDimView, alpha: dimAlpha)
            } else {
                transition.setAlpha(view: self.contentDimView, alpha: dimAlpha)
            }
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scroller, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.ignoreScrolling = false
            
            self.adjustScroller()
            self.updateScrolling(transition: itemsTransition)
            
            if let focusedItem, let visibleItem = self.visibleItems[focusedItem.storyItem.id], let index = focusedItem.position {
                let navigationStripSideInset: CGFloat = 8.0
                let navigationStripTopInset: CGFloat = 8.0
                
                let _ = self.navigationStrip.update(
                    transition: transition,
                    component: AnyComponent(MediaNavigationStripComponent(
                        index: max(0, min(index, component.slice.totalCount - 1)),
                        count: component.slice.totalCount
                    )),
                    environment: {
                        MediaNavigationStripComponent.EnvironmentType(
                            currentProgress: visibleItem.currentProgress
                        )
                    },
                    containerSize: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)
                )
                if let navigationStripView = self.navigationStrip.view {
                    if navigationStripView.superview == nil {
                        navigationStripView.isUserInteractionEnabled = false
                        self.controlsContainerView.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: navigationStripSideInset, y: navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)))
                    transition.setAlpha(view: navigationStripView, alpha: self.isEditingStory ? 0.0 : 1.0)
                }
            }
            
            component.externalState.derivedMediaSize = contentFrame.size
            if component.slice.peer.id == component.context.account.peerId {
                component.externalState.derivedBottomInset = availableSize.height - contentFrame.maxY
            } else {
                component.externalState.derivedBottomInset = availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY)
            }
            
            return contentSize
        }
        
        private func openItemPrivacySettings(initialPrivacy: EngineStoryPrivacy? = nil) {
            guard let context = self.component?.context else {
                return
            }
            
            let privacy = initialPrivacy ?? self.component?.slice.item.storyItem.privacy
            guard let privacy else {
                return
            }
            
            let stateContext = ShareWithPeersScreen.StateContext(context: context, subject: .stories(editing: true), initialPeerIds: Set(privacy.additionallyIncludePeers))
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let controller = ShareWithPeersScreen(
                    context: context,
                    initialPrivacy: privacy,
                    stateContext: stateContext,
                    completion: { [weak self] privacy, _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component.context.engine.messages.editStoryPrivacy(id: component.slice.item.storyItem.id, privacy: privacy).start()
                        
                        self.privacyController = nil
                        self.updateIsProgressPaused()
                    },
                    editCategory: { [weak self] privacy, _, _ in
                        guard let self else {
                            return
                        }
                        self.openItemPrivacyCategory(privacy: privacy, completion: { [weak self] privacy in
                            guard let self else {
                                return
                            }
                            self.openItemPrivacySettings(initialPrivacy: privacy)
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
        
        private func openItemPrivacyCategory(privacy: EngineStoryPrivacy, completion: @escaping (EngineStoryPrivacy) -> Void) {
            guard let context = self.component?.context else {
                return
            }
        
            let stateContext = ShareWithPeersScreen.StateContext(context: context, subject: .contacts(privacy.base), initialPeerIds: Set(privacy.additionallyIncludePeers))
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let controller = ShareWithPeersScreen(
                    context: context,
                    initialPrivacy: privacy,
                    stateContext: stateContext,
                    completion: { result, _, _ in
                        if case .closeFriends = privacy.base {
                            let _ = context.engine.privacy.updateCloseFriends(peerIds: result.additionallyIncludePeers).start()
                            completion(EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []))
                        } else {
                            completion(result)
                        }
                    },
                    editCategory: { _, _, _ in }
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
        
        func navigateToPeer(peer: EnginePeer, messageId: EngineMessage.Id? = nil) {
            guard let component = self.component else {
                return
            }
            guard let controller = component.controller() as? StoryContainerScreen else {
                return
            }
            guard let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            if let messageId {
                component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: false, timecode: nil), keepStack: .always, animated: true, pushController: { [weak controller, weak navigationController] chatController, animated, completion in
                    guard let controller, let navigationController else {
                        return
                    }
                    var viewControllers = navigationController.viewControllers
                    if let index = viewControllers.firstIndex(where: { $0 === controller }) {
                        viewControllers.insert(chatController, at: index)
                    } else {
                        viewControllers.append(chatController)
                    }
                    navigationController.setViewControllers(viewControllers, animated: animated)
                }))
            } else {
                guard let chatController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                    return
                }
                
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.firstIndex(where: { $0 === controller }) {
                    viewControllers.insert(chatController, at: index)
                } else {
                    viewControllers.append(chatController)
                }
                navigationController.setViewControllers(viewControllers, animated: true)
            }
            
            controller.dismissWithoutTransitionOut()
        }
        
        private func openStoryEditing() {
            guard let component = self.component, let peerReference = PeerReference(component.slice.peer._asPeer()) else {
                return
            }
            let context = component.context
            let item = component.slice.item.storyItem
            let id = item.id
        
            self.isEditingStory = true
            self.updateIsProgressPaused()
            self.state?.updated(transition: .easeInOut(duration: 0.2))
            
            var videoPlaybackPosition: Double?
            if let visibleItem = self.visibleItems[component.slice.item.storyItem.id], let view = visibleItem.view.view as? StoryItemContentComponent.View {
                videoPlaybackPosition = view.videoPlaybackPosition
            }
            
            let subject: Signal<MediaEditorScreen.Subject?, NoError>
//            if let source {
//                subject = .single(.draft(source, Int64(id)))
//            } else {
            
            var duration: Double?
            let media = item.media._asMedia()
            if let file = media as? TelegramMediaFile {
                duration = file.duration
            }
            subject = fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: .story(peer: peerReference, id: item.id, media: media))
            |> mapToSignal { (value, isImage) -> Signal<MediaEditorScreen.Subject?, NoError> in
                guard case let .data(data) = value, data.complete else {
                    return .complete()
                }
                if let image = UIImage(contentsOfFile: data.path) {
                    return .single(nil)
                    |> then(
                        .single(.image(image, PixelDimensions(image.size), nil, .bottomRight))
                        |> delay(0.1, queue: Queue.mainQueue())
                    )
                } else {
                    let symlinkPath = data.path + ".mp4"
                    if fileSize(symlinkPath) == nil {
                        let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                    }
                    return .single(nil)
                    |> then(
                        .single(.video(symlinkPath, nil, false, nil, nil, PixelDimensions(width: 720, height: 1280), duration ?? 0.0, [], .bottomRight))
                        |> delay(0.1, queue: Queue.mainQueue())
                    )
                }
            }
                        
            var updateProgressImpl: ((Float) -> Void)?
            let controller = MediaEditorScreen(
                context: context,
                subject: subject,
                isEditing: true,
                initialCaption: chatInputStateStringWithAppliedEntities(item.text, entities: item.entities),
                initialPrivacy: item.privacy,
                initialVideoPosition: videoPlaybackPosition,
                transitionIn: nil,
                transitionOut: { _, _ in return nil },
                completion: { [weak self] _, mediaResult, caption, privacy, commit in
                    guard let self else {
                        return
                    }
                    let entities = generateChatInputTextEntities(caption)
                    var updatedText: String?
                    var updatedEntities: [MessageTextEntity]?
                    var updatedPrivacy: EngineStoryPrivacy?
                    if caption.string != item.text || entities != item.entities {
                        updatedText = caption.string
                        updatedEntities = entities
                    }
                    if privacy.privacy != item.privacy {
                        updatedPrivacy = privacy.privacy
                    }
           
                    if let mediaResult {
                        switch mediaResult {
                        case let .image(image, dimensions):
                            updateProgressImpl?(0.0)
                            
                            if let imageData = compressImageToJPEG(image, quality: 0.7) {
                                let _ = (context.engine.messages.editStory(media: .image(dimensions: dimensions, data: imageData), id: id, text: updatedText, entities: updatedEntities, privacy: updatedPrivacy)
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let self else {
                                        return
                                    }
                                    switch result {
                                    case let .progress(progress):
                                        updateProgressImpl?(progress)
                                    case .completed:
                                        Queue.mainQueue().after(0.1) {
                                            self.isEditingStory = false
                                            self.rewindCurrentItem()
                                            self.updateIsProgressPaused()
                                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                                            
                                            commit({})
                                        }
                                    }
                                })
                            }
                        case let .video(content, firstFrameImage, values, duration, dimensions):
                            updateProgressImpl?(0.0)
                            
                            if let valuesData = try? JSONEncoder().encode(values) {
                                let data = MemoryBuffer(data: valuesData)
                                let digest = MemoryBuffer(data: data.md5Digest())
                                let adjustments = VideoMediaResourceAdjustments(data: data, digest: digest, isStory: true)
                             
                                let resource: TelegramMediaResource
                                switch content {
                                case let .imageFile(path):
                                    resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                case let .videoFile(path):
                                    resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                case let .asset(localIdentifier):
                                    resource = VideoLibraryMediaResource(localIdentifier: localIdentifier, conversion: .compress(adjustments))
                                }
                                
                                let firstFrameImageData = firstFrameImage.flatMap { compressImageToJPEG($0, quality: 0.6) }
                                let _ = (context.engine.messages.editStory(media: .video(dimensions: dimensions, duration: duration, resource: resource, firstFrameImageData: firstFrameImageData), id: id, text: updatedText, entities: updatedEntities, privacy: updatedPrivacy)
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let self else {
                                        return
                                    }
                                    switch result {
                                    case let .progress(progress):
                                        updateProgressImpl?(progress)
                                    case .completed:
                                        Queue.mainQueue().after(0.1) {
                                            self.isEditingStory = false
                                            self.rewindCurrentItem()
                                            self.updateIsProgressPaused()
                                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                                            
                                            commit({})
                                        }
                                    }
                                })
                            }
                        }
                    } else if updatedText != nil || updatedPrivacy != nil {
                        let _ = (context.engine.messages.editStory(media: nil, id: id, text: updatedText, entities: updatedEntities, privacy: updatedPrivacy)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            switch result {
                            case .completed:
                                Queue.mainQueue().after(0.1) {
                                    if let self {
                                        self.isEditingStory = false
                                        self.rewindCurrentItem()
                                        self.updateIsProgressPaused()
                                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                                    }
                                    commit({})
                                }
                            default:
                                break
                            }
                        })
                    } else {
                        self.isEditingStory = false
                        self.rewindCurrentItem()
                        self.updateIsProgressPaused()
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                        
                        commit({})
                    }
                    
                }
            )
            controller.willDismiss = { [weak self] in
                self?.isEditingStory = false
                self?.rewindCurrentItem()
                self?.updateIsProgressPaused()
                self?.state?.updated(transition: .easeInOut(duration: 0.2))
            }
            self.component?.controller()?.push(controller)
            updateProgressImpl = { [weak controller] progress in
                controller?.updateEditProgress(progress)
            }
        }
        
        private func requestSave() {
            guard let component = self.component, let peerReference = PeerReference(component.slice.peer._asPeer()) else {
                return
            }
            
            let saveScreen = SaveProgressScreen(context: component.context, content: .progress("Saving", 0.0))
            component.controller()?.present(saveScreen, in: .current)
            
            let disposable = (saveToCameraRoll(context: component.context, postbox: component.context.account.postbox, userLocation: .other, mediaReference: .story(peer: peerReference, id: component.slice.item.storyItem.id, media: component.slice.item.storyItem.media._asMedia()))
            |> deliverOnMainQueue).start(next: { [weak saveScreen] progress in
                guard let saveScreen else {
                    return
                }
                saveScreen.content = .progress("Saving", progress)
            }, completed: { [weak saveScreen] in
                guard let saveScreen else {
                    return
                }
                saveScreen.content = .completion("Saved")
                Queue.mainQueue().after(3.0, { [weak saveScreen] in
                    saveScreen?.dismiss()
                })
            })
            
            saveScreen.cancelled = {
                disposable.dispose()
            }
        }
        
        private func performMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            guard let component = self.component else {
                return
            }
            if component.slice.peer.id == component.context.account.peerId {
                self.performMyMoreAction(sourceView: sourceView, gesture: gesture)
            } else {
                self.performOtherMoreAction(sourceView: sourceView, gesture: gesture)
            }
        }
        
        private func performMyMoreAction(sourceView: UIView, gesture: ContextGesture?) {
            guard let component = self.component, let controller = component.controller() else {
                return
            }
            
            component.controller()?.forEachController { c in
                if let c = c as? UndoOverlayController {
                    c.dismiss()
                }
                return true
            }
            
            var items: [ContextMenuItem] = []
            
            let additionalCount = component.slice.item.storyItem.privacy?.additionallyIncludePeers.count ?? 0
            
            let privacyText: String
            switch component.slice.item.storyItem.privacy?.base {
            case .closeFriends:
                privacyText = "Close Friends"
            case .contacts:
                if additionalCount != 0 {
                    privacyText = "Contacts (-\(additionalCount))"
                } else {
                    privacyText = "Contacts"
                }
            case .nobody:
                if additionalCount != 0 {
                    if additionalCount == 1 {
                        privacyText = "\(additionalCount) Person"
                    } else {
                        privacyText = "\(additionalCount) People"
                    }
                } else {
                    privacyText = "Only Me"
                }
            default:
                privacyText = "Everyone"
            }
            
            items.append(.action(ContextMenuActionItem(text: "Who can see", textLayout: .secondLineWithValue(privacyText), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self else {
                    return
                }
                self.openItemPrivacySettings()
            })))
            
            items.append(.action(ContextMenuActionItem(text: "Edit Story", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self else {
                    return
                }
                self.openStoryEditing()
            })))
            
            items.append(.separator)
                                        
            items.append(.action(ContextMenuActionItem(text: component.slice.item.storyItem.isPinned ? "Remove from Profile" : "Save to Profile", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: component.slice.item.storyItem.isPinned ? "Chat/Context Menu/Check" : "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self, let component = self.component else {
                    return
                }
                
                let _ = component.context.engine.messages.updateStoriesArePinned(ids: [component.slice.item.storyItem.id: component.slice.item.storyItem], isPinned: !component.slice.item.storyItem.isPinned).start()
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                if component.slice.item.storyItem.isPinned {
                    self.component?.presentController(UndoOverlayController(
                        presentationData: presentationData,
                        content: .info(title: nil, text: "Story removed from your profile", timeout: nil),
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in return false }
                    ), nil)
                } else {
                    self.component?.presentController(UndoOverlayController(
                        presentationData: presentationData,
                        content: .info(title: "Story saved to your profile", text: "Saved stories can be viewed by others on your profile until you remove them.", timeout: nil),
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in return false }
                    ), nil)
                }
            })))
            
            let saveText: String
            if case .file = component.slice.item.storyItem.media {
                saveText = "Save Video"
            } else {
                saveText = "Save Image"
            }
            items.append(.action(ContextMenuActionItem(text: saveText, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self else {
                    return
                }
                self.requestSave()
            })))
            
            if component.slice.item.storyItem.isPublic && (component.slice.peer.addressName != nil || !component.slice.peer._asPeer().usernames.isEmpty) {
                items.append(.action(ContextMenuActionItem(text: "Copy Link", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = (component.context.engine.messages.exportStoryLink(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id)
                    |> deliverOnMainQueue).start(next: { [weak self] link in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let link {
                            UIPasteboard.general.string = link
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            component.presentController(UndoOverlayController(
                                presentationData: presentationData,
                                content: .linkCopied(text: "Link copied."),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                action: { _ in return false }
                            ), nil)
                        }
                    })
                })))
                items.append(.action(ContextMenuActionItem(text: "Share", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                }, action: {  [weak self] _, a in
                    a(.default)
                    
                    guard let self else {
                        return
                    }
                    self.sendMessageContext.performShareAction(view: self)
                })))
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            let contextController = ContextController(account: component.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
            let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: component.slice.peer.id))
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self, let component = self.component, let controller = component.controller() else {
                    return
                }
                
                component.controller()?.forEachController { c in
                    if let c = c as? UndoOverlayController {
                        c.dismiss()
                    }
                    return true
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                var items: [ContextMenuItem] = []
                
                let isMuted = settings.storiesMuted == true
                items.append(.action(ContextMenuActionItem(text: isMuted ? "Notify" : "Don't Notify", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: component.slice.additionalPeerData.isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = component.context.engine.peers.togglePeerStoriesMuted(peerId: component.slice.peer.id).start()
                    
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
                            ], title: nil, text: "You will now get a notification whenever **\(component.slice.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))** posts a story.", customUndoText: nil, timeout: nil),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
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
                            ], title: nil, text: "You will no longer receive a notification when **\(component.slice.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))** posts a story.", customUndoText: nil, timeout: nil),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ), nil)
                    }
                })))
                
                var isHidden = false
                if case let .user(user) = component.slice.peer, let storiesHidden = user.storiesHidden {
                    isHidden = storiesHidden
                }
                
                items.append(.action(ContextMenuActionItem(text: isHidden ? "Unhide \(component.slice.peer.compactDisplayTitle)" : "Hide \(component.slice.peer.compactDisplayTitle)", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isHidden ? "Chat/Context Menu/MoveToChats" : "Chat/Context Menu/MoveToContacts"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    a(.default)
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let _ = component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.peer.id, isHidden: !isHidden)
                    
                    let text = isHidden ? "Stories from **\(component.slice.peer.compactDisplayTitle)** will now be shown in Chats, not Contacts." : "Stories from **\(component.slice.peer.compactDisplayTitle)** will now be shown in Contacts, not Chats."
                    let tooltipScreen = TooltipScreen(
                        context: component.context,
                        account: component.context.account,
                        sharedContext: component.context.sharedContext,
                        text: .markdown(text: text),
                        style: .customBlur(UIColor(rgb: 0x1c1c1c)),
                        icon: .peer(peer: component.slice.peer, isStory: true),
                        action: TooltipScreen.Action(
                            title: "Undo",
                            action: {
                                component.context.engine.peers.updatePeerStoriesHidden(id: component.slice.peer.id, isHidden: isHidden)
                            }
                        ),
                        location: .bottom,
                        shouldDismissOnTouch: { _ in return .dismiss(consume: false) }
                    )
                    tooltipScreen.willBecomeDismissed = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.sendMessageContext.tooltipScreen = nil
                        self.updateIsProgressPaused()
                    }
                    self.sendMessageContext.tooltipScreen = tooltipScreen
                    self.updateIsProgressPaused()
                    component.controller()?.present(tooltipScreen, in: .current)
                })))
                
                items.append(.action(ContextMenuActionItem(text: "Report", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, a in
                    guard let self, let component = self.component, let controller = component.controller() else {
                        return
                    }
                    
                    let options: [PeerReportOption] = [.spam, .violence, .pornography, .childAbuse, .copyright, .illegalDrugs, .personalDetails, .other]
                    presentPeerReportOptions(
                        context: component.context,
                        parent: controller,
                        contextController: c,
                        backAction: { _ in },
                        subject: .story(component.slice.peer.id, component.slice.item.storyItem.id),
                        options: options,
                        passthrough: true,
                        forceTheme: defaultDarkPresentationTheme,
                        isDetailedReportingVisible: { [weak self] isReporting in
                            guard let self else {
                                return
                            }
                            self.isReporting = isReporting
                            self.updateIsProgressPaused()
                        },
                        completion: { [weak self] reason, _ in
                            guard let self, let component = self.component, let controller = component.controller(), let reason else {
                                return
                            }
                            let _ = component.context.engine.peers.reportPeerStory(peerId: component.slice.peer.id, storyId: component.slice.item.storyItem.id, reason: reason, message: "").start()
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                        }
                    )
                })))
                
                let contextController = ContextController(account: component.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    var keepInPlace: Bool {
        return true
    }

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .bottom)
    }
}

private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat, duration: Double, curve: Transition.Animation.Curve, reverse: Bool) -> [CGPoint] {
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
