import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import ComponentDisplayAdapters
import ReactionSelectionNode
import EntityKeyboard
import StoryFooterPanelComponent
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
    }
    
    public let context: AccountContext
    public let externalState: ExternalState
    public let slice: StoryContentContextState.FocusedSlice
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let containerInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let inputHeight: CGFloat
    public let metrics: LayoutMetrics
    public let isProgressPaused: Bool
    public let hideUI: Bool
    public let visibilityFraction: CGFloat
    public let isPanning: Bool
    public let presentController: (ViewController) -> Void
    public let close: () -> Void
    public let navigate: (NavigationDirection) -> Void
    public let delete: () -> Void
    public let controller: () -> ViewController?
    
    public init(
        context: AccountContext,
        externalState: ExternalState,
        slice: StoryContentContextState.FocusedSlice,
        theme: PresentationTheme,
        strings: PresentationStrings,
        containerInsets: UIEdgeInsets,
        safeInsets: UIEdgeInsets,
        inputHeight: CGFloat,
        metrics: LayoutMetrics,
        isProgressPaused: Bool,
        hideUI: Bool,
        visibilityFraction: CGFloat,
        isPanning: Bool,
        presentController: @escaping (ViewController) -> Void,
        close: @escaping () -> Void,
        navigate: @escaping (NavigationDirection) -> Void,
        delete: @escaping () -> Void,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.externalState = externalState
        self.slice = slice
        self.theme = theme
        self.strings = strings
        self.containerInsets = containerInsets
        self.safeInsets = safeInsets
        self.inputHeight = inputHeight
        self.metrics = metrics
        self.isProgressPaused = isProgressPaused
        self.hideUI = hideUI
        self.visibilityFraction = visibilityFraction
        self.isPanning = isPanning
        self.presentController = presentController
        self.close = close
        self.navigate = navigate
        self.delete = delete
        self.controller = controller
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
        return true
    }
    
    final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    struct ItemLayout {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    final class VisibleItem {
        let externalState = StoryContentItem.ExternalState()
        let view = ComponentView<StoryContentItem.Environment>()
        var currentProgress: Double = 0.0
        var requestedNext: Bool = false
        
        init() {
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
    
    public final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let sendMessageContext: StoryItemSetContainerSendMessage
        
        let scrollView: ScrollView
        
        let contentContainerView: UIView
        let topContentGradientLayer: SimpleGradientLayer
        let bottomContentGradientLayer: SimpleGradientLayer
        let contentDimLayer: SimpleLayer
        
        let closeButton: HighlightableButton
        let closeButtonIconView: UIImageView
        
        let navigationStrip = ComponentView<MediaNavigationStripComponent.EnvironmentType>()
        let inlineActions = ComponentView<Empty>()
        
        var centerInfoItem: InfoItem?
        var rightInfoItem: InfoItem?
        
        var captionItem: CaptionItem?
        
        let inputPanel = ComponentView<Empty>()
        let footerPanel = ComponentView<Empty>()
        let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        var displayViewList: Bool = false
        var viewList: ViewList?
        
        var itemLayout: ItemLayout?
        var ignoreScrolling: Bool = false
        
        var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        var preloadContexts: [AnyHashable: Disposable] = [:]
        
        var displayReactions: Bool = false
        var reactionItems: [ReactionItem]?
        var reactionContextNode: ReactionContextNode?
        weak var disappearingReactionContextNode: ReactionContextNode?
        
        weak var actionSheet: ActionSheetController?
        weak var contextController: ContextController?
        
        var component: StoryItemSetContainerComponent?
        weak var state: EmptyComponentState?
        
        private var audioRecorderDisposable: Disposable?
        private var audioRecorderStatusDisposable: Disposable?
        private var videoRecorderDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.sendMessageContext = StoryItemSetContainerSendMessage()
            
            self.scrollView = ScrollView()
            
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            
            self.topContentGradientLayer = SimpleGradientLayer()
            self.bottomContentGradientLayer = SimpleGradientLayer()
            self.contentDimLayer = SimpleLayer()
            
            self.closeButton = HighlightableButton()
            self.closeButtonIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.contentContainerView)
            self.contentContainerView.layer.addSublayer(self.contentDimLayer)
            self.contentContainerView.layer.addSublayer(self.topContentGradientLayer)
            self.layer.addSublayer(self.bottomContentGradientLayer)
            
            self.closeButton.addSubview(self.closeButtonIconView)
            self.contentContainerView.addSubview(self.closeButton)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.delegate = self
            self.contentContainerView.addGestureRecognizer(tapRecognizer)
            
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
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.frame.contains(point) {
                    return false
                }
            }
            
            if self.contentContainerView.frame.contains(point) {
                return true
            }
            
            return false
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
        
        @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let component = self.component, let itemLayout = self.itemLayout {
                if hasFirstResponder(self) {
                    self.displayReactions = false
                    self.endEditing(true)
                } else if self.displayReactions {
                    self.displayReactions = false
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                } else if self.displayViewList {
                    self.displayViewList = false
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                } else if let captionItem = self.captionItem, captionItem.externalState.expandFraction > 0.0 {
                    if let captionItemView = captionItem.view.view as? StoryContentCaptionComponent.View {
                        captionItemView.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                    }
                } else {
                    let point = recognizer.location(in: self)
                    
                    var direction: NavigationDirection?
                    if point.x < itemLayout.size.width * 0.25 {
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
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds: [AnyHashable] = []
            let focusedItem = component.slice.item
            
            validIds.append(focusedItem.id)
                
            var itemTransition = transition
            let visibleItem: VisibleItem
            if let current = self.visibleItems[focusedItem.id] {
                visibleItem = current
            } else {
                itemTransition = .immediate
                visibleItem = VisibleItem()
                self.visibleItems[focusedItem.id] = visibleItem
            }
            
            let _ = visibleItem.view.update(
                transition: itemTransition,
                component: focusedItem.component,
                environment: {
                    StoryContentItem.Environment(
                        externalState: visibleItem.externalState,
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
                        }
                    )
                },
                containerSize: itemLayout.size
            )
            if let view = visibleItem.view.view {
                if view.superview == nil {
                    view.isUserInteractionEnabled = false
                    self.contentContainerView.insertSubview(view, at: 0)
                }
                itemTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: itemLayout.size))
                
                if let view = view as? StoryContentItem.View {
                    view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.displayReactions || self.actionSheet != nil || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil || self.displayViewList)
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let view = visibleItem.view.view {
                        view.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func updateIsProgressPaused() {
            guard let component = self.component else {
                return
            }
            for (_, visibleItem) in self.visibleItems {
                if let view = visibleItem.view.view {
                    if let view = view as? StoryContentItem.View {
                        view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.displayReactions || self.actionSheet != nil || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil || self.displayViewList)
                    }
                }
            }
        }
        
        func animateIn(transitionIn: StoryContainerScreen.TransitionIn) {
            self.closeButton.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, delay: 0.12, timingFunction: kCAMediaTimingFunctionSpring)
            
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
            if let footerPanelView = self.footerPanel.view {
                footerPanelView.layer.animatePosition(
                    from: CGPoint(x: 0.0, y: self.bounds.height - footerPanelView.frame.minY),
                    to: CGPoint(),
                    duration: 0.3,
                    timingFunction: kCAMediaTimingFunctionSpring,
                    additive: true
                )
                footerPanelView.layer.animateAlpha(from: 0.0, to: footerPanelView.alpha, duration: 0.28)
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
            
            if let sourceView = transitionIn.sourceView {
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.contentContainerView.frame.minX, y: sourceLocalFrame.minY - self.contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                
                if let rightInfoView = self.rightInfoItem?.view.view {
                    if transitionIn.sourceCornerRadius != 0.0 {
                        let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: CGPoint(x: innerSourceLocalFrame.center.x - rightInfoView.layer.position.x, y: innerSourceLocalFrame.center.y - rightInfoView.layer.position.y), to: CGPoint(), elevation: 0.0, duration: 0.3, curve: .spring, reverse: false)
                        rightInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", additive: true)
                        
                        rightInfoView.layer.animateScale(from: innerSourceLocalFrame.width / rightInfoView.bounds.width, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
                
                self.contentContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.contentContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.contentContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.contentContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.contentContainerView.layer.animate(
                    from: transitionIn.sourceCornerRadius as NSNumber,
                    to: self.contentContainerView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
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
            }
        }
        
        func animateOut(transitionOut: StoryContainerScreen.TransitionOut, completion: @escaping () -> Void) {
            self.closeButton.layer.animateScale(from: 1.0, to: 0.001, duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
            
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
            if let footerPanelView = self.footerPanel.view {
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
            
            if let sourceView = transitionOut.destinationView {
                let sourceLocalFrame = sourceView.convert(transitionOut.destinationRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.contentContainerView.frame.minX, y: sourceLocalFrame.minY - self.contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                if let centerInfoView = self.centerInfoItem?.view.view {
                    centerInfoView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                }
                
                if let rightInfoView = self.rightInfoItem?.view.view {
                    if transitionOut.destinationIsAvatar {
                        let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: innerSourceLocalFrame.center, to: rightInfoView.layer.position, elevation: 0.0, duration: 0.3, curve: .spring, reverse: true)
                        rightInfoView.layer.position = positionKeyframes[positionKeyframes.count - 1]
                        rightInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", removeOnCompletion: false, additive: false)
                        
                        rightInfoView.layer.animateScale(from: 1.0, to: innerSourceLocalFrame.width / rightInfoView.bounds.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                }
                
                self.contentContainerView.layer.animatePosition(from: self.contentContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.contentContainerView.layer.animateBounds(from: self.contentContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.contentContainerView.layer.animate(
                    from: self.contentContainerView.layer.cornerRadius as NSNumber,
                    to: transitionOut.destinationCornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
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
        }
        
        func update(component: StoryItemSetContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            if self.component == nil {
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
                    if self.displayReactions {
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                })
            }
            
            if self.component?.slice.item.storyItem.id != component.slice.item.storyItem.id {
                let _ = component.context.engine.messages.markStoryAsSeen(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id).start()
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
                
                self.contentDimLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.3).cgColor
            }
            
            //self.updatePreloads()
            
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
                    presentController: { [weak self] c in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.presentController(c)
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
                    reactionAction: { [weak self] sourceView in
                        guard let self, let component = self.component else {
                            return
                        }
                        
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
                            
                            self.displayReactions = !self.displayReactions
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                        })
                    },
                    timeoutAction: nil,
                    audioRecorder: self.sendMessageContext.audioRecorderValue,
                    videoRecordingStatus: self.sendMessageContext.videoRecorderValue?.audioStatus,
                    isRecordingLocked: self.sendMessageContext.isMediaRecordingLocked,
                    recordedAudioPreview: self.sendMessageContext.recordedAudioPreview,
                    wasRecordingDismissed: self.sendMessageContext.wasRecordingDismissed,
                    timeoutValue: nil,
                    timeoutSelected: false,
                    displayGradient: component.inputHeight != 0.0 && component.metrics.widthClass != .regular,
                    bottomInset: component.inputHeight != 0.0 ? 0.0 : bottomContentInset
                )),
                environment: {},
                containerSize: CGSize(width: inputPanelAvailableWidth, height: 200.0)
            )
            
            var currentItem: StoryContentItem?
            currentItem = component.slice.item
            
            let footerPanelSize = self.footerPanel.update(
                transition: transition,
                component: AnyComponent(StoryFooterPanelComponent(
                    context: component.context,
                    storyItem: currentItem?.storyItem,
                    expandViewStats: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        if !self.displayViewList {
                            self.displayViewList = true
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
                                ActionSheetButtonItem(title: "Delete", color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.delete()
                                    
                                    /*if let currentSlice = self.currentSlice, let index = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                                        let item = currentSlice.items[index]
                                        
                                        if currentSlice.items.count == 1 {
                                            component.navigateToItemSet(.next)
                                        } else {
                                            var nextIndex: Int = index + 1
                                            if nextIndex >= currentSlice.items.count {
                                                nextIndex = currentSlice.items.count - 1
                                            }
                                            self.focusedItemId = currentSlice.items[nextIndex].id
                                            
                                            currentSlice.items[nextIndex].markAsSeen?()
                                            
                                            self.state?.updated(transition: .immediate)
                                        }
                                        
                                        item.delete?()
                                    }*/
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
                            self.actionSheet = nil
                            self.updateIsProgressPaused()
                        }
                        self.actionSheet = actionSheet
                        self.updateIsProgressPaused()
                        
                        component.presentController(actionSheet)
                    },
                    moreAction: { [weak self] sourceView, gesture in
                        guard let self, let component = self.component, let controller = component.controller() else {
                            return
                        }
                        
                        var items: [ContextMenuItem] = []
                        
                        let additionalCount = component.slice.item.storyItem.privacy?.additionallyIncludePeers.count ?? 0
                        
                        let privacyText: String
                        switch component.slice.item.storyItem.privacy?.base {
                        case .closeFriends:
                            if additionalCount != 0 {
                                privacyText = "Close Friends (+\(additionalCount)"
                            } else {
                                privacyText = "Close Friends"
                            }
                        case .contacts:
                            if additionalCount != 0 {
                                privacyText = "Contacts (+\(additionalCount)"
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
                        
                        items.append(.separator)
                        
                        component.controller()?.forEachController { c in
                            if let c = c as? UndoOverlayController {
                                c.dismiss()
                            }
                            return true
                        }
                        
                        items.append(.action(ContextMenuActionItem(text: component.slice.item.storyItem.isPinned ? "Remove from profile" : "Save to profile", icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: component.slice.item.storyItem.isPinned ? "Chat/Context Menu/Check" : "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let _ = component.context.engine.messages.updateStoryIsPinned(id: component.slice.item.storyItem.id, isPinned: !component.slice.item.storyItem.isPinned).start()
                            
                            if component.slice.item.storyItem.isPinned {
                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                self.component?.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .info(title: nil, text: "Story removed from your profile", timeout: nil),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in return false }
                                ))
                            } else {
                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                self.component?.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .info(title: "Story saved to your profile", text: "Saved stories can be viewed by others on your profile until you remove them.", timeout: nil),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in return false }
                                ))
                            }
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Save image", icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor)
                        }, action: { _, a in
                            a(.default)
                        })))
                        
                        if component.slice.item.storyItem.isPublic {
                            items.append(.action(ContextMenuActionItem(text: "Copy link", icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                            }, action: { _, a in
                                a(.default)
                            })))
                            items.append(.action(ContextMenuActionItem(text: "Share", icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                            }, action: { _, a in
                                a(.default)
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
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let bottomContentInsetWithoutInput = bottomContentInset
            var viewListInset: CGFloat = 0.0
            
            var inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if component.inputHeight == 0.0 {
                inputPanelBottomInset = bottomContentInset
                if case .regular = component.metrics.widthClass {
                    bottomContentInset += 60.0
                } else {
                    bottomContentInset += inputPanelSize.height
                }
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = component.inputHeight - component.containerInsets.bottom
                inputPanelIsOverlay = true
            }
            
            if self.displayViewList {
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
                
                let viewListSize = viewList.view.update(
                    transition: viewListTransition,
                    component: AnyComponent(StoryItemSetViewListComponent(
                        externalState: viewList.externalState,
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        safeInsets: component.safeInsets,
                        storyItem: component.slice.item.storyItem,
                        close: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.displayViewList = false
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let viewListFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - viewListSize.height), size: viewListSize)
                if let viewListView = viewList.view.view {
                    var animateIn = false
                    if viewListView.superview == nil {
                        self.addSubview(viewListView)
                        animateIn = true
                    }
                    viewListTransition.setFrame(view: viewListView, frame: viewListFrame)
                    
                    if animateIn, !transition.animation.isImmediate {
                        transition.animatePosition(view: viewListView, from: CGPoint(x: 0.0, y: viewListFrame.height), to: CGPoint(), additive: true)
                    }
                }
                viewListInset = viewListFrame.height
                inputPanelBottomInset = viewListInset
            } else if let viewList = self.viewList {
                self.viewList = nil
                if let viewListView = viewList.view.view {
                    transition.setPosition(view: viewListView, position: CGPoint(x: viewListView.center.x, y: availableSize.height + viewListView.bounds.height * 0.5), completion: { [weak viewListView] _ in
                        viewListView?.removeFromSuperview()
                    })
                }
            }
            
            let contentDefaultBottomInset: CGFloat = bottomContentInset
            let contentSize = CGSize(width: availableSize.width, height: availableSize.height - component.containerInsets.top - contentDefaultBottomInset)
            
            let contentVisualBottomInset: CGFloat
            if self.displayViewList {
                contentVisualBottomInset = viewListInset + 12.0
            } else {
                contentVisualBottomInset = contentDefaultBottomInset
            }
            let contentVisualHeight = availableSize.height - component.containerInsets.top - contentVisualBottomInset
            let contentVisualScale = contentVisualHeight / contentSize.height
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: component.containerInsets.top - (contentSize.height - contentVisualHeight) * 0.5), size: contentSize)
            
            transition.setPosition(view: self.contentContainerView, position: contentFrame.center)
            transition.setBounds(view: self.contentContainerView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            transition.setScale(view: self.contentContainerView, scale: contentVisualScale)
            transition.setCornerRadius(layer: self.contentContainerView.layer, cornerRadius: 10.0 * (1.0 / contentVisualScale))
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Media Gallery/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 50.0, height: 64.0))
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
                transition.setAlpha(view: self.closeButton, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
            }
            
            let focusedItem: StoryContentItem? = component.slice.item
            let _ = focusedItem
            /*if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                focusedItem = item
            }*/
            
            var currentRightInfoItem: InfoItem?
            if let focusedItem {
                if let rightInfoComponent = focusedItem.rightInfoComponent {
                    if let rightInfoItem = self.rightInfoItem, rightInfoItem.component == focusedItem.rightInfoComponent {
                        currentRightInfoItem = rightInfoItem
                    } else {
                        currentRightInfoItem = InfoItem(component: rightInfoComponent)
                    }
                }
            }
            
            if let rightInfoItem = self.rightInfoItem, currentRightInfoItem?.component != rightInfoItem.component {
                self.rightInfoItem = nil
                if let view = rightInfoItem.view.view {
                    view.layer.animateScale(from: 1.0, to: 0.5, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                }
            }
            
            var currentCenterInfoItem: InfoItem?
            if let focusedItem {
                if let centerInfoComponent = focusedItem.centerInfoComponent {
                    if let centerInfoItem = self.centerInfoItem, centerInfoItem.component == focusedItem.centerInfoComponent {
                        currentCenterInfoItem = centerInfoItem
                    } else {
                        currentCenterInfoItem = InfoItem(component: centerInfoComponent)
                    }
                }
            }
            
            if let centerInfoItem = self.centerInfoItem, currentCenterInfoItem?.component != centerInfoItem.component {
                self.centerInfoItem = nil
                if let view = centerInfoItem.view.view {
                    view.removeFromSuperview()
                }
            }
            
            if let currentRightInfoItem {
                self.rightInfoItem = currentRightInfoItem
                
                let rightInfoItemSize = currentRightInfoItem.view.update(
                    transition: .immediate,
                    component: currentRightInfoItem.component,
                    environment: {},
                    containerSize: CGSize(width: 36.0, height: 36.0)
                )
                if let view = currentRightInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.contentContainerView.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentFrame.width - 6.0 - rightInfoItemSize.width, y: 14.0), size: rightInfoItemSize))
                    
                    if animateIn, !isFirstTime, !transition.animation.isImmediate {
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        view.layer.animateScale(from: 0.5, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    
                    transition.setAlpha(view: view, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
                }
            }
            
            if let currentCenterInfoItem {
                self.centerInfoItem = currentCenterInfoItem
                
                let centerInfoItemSize = currentCenterInfoItem.view.update(
                    transition: .immediate,
                    component: currentCenterInfoItem.component,
                    environment: {},
                    containerSize: CGSize(width: contentFrame.width, height: 44.0)
                )
                if let view = currentCenterInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        view.isUserInteractionEnabled = false
                        self.contentContainerView.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: centerInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        //view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    
                    transition.setAlpha(view: view, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
                }
            }
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            transition.setAlpha(layer: self.topContentGradientLayer, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
            
            let itemLayout = ItemLayout(size: CGSize(width: contentFrame.width, height: availableSize.height - component.containerInsets.top - 44.0 - bottomContentInsetWithoutInput))
            self.itemLayout = itemLayout
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - inputPanelSize.width) / 2.0), y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
            var inputPanelAlpha: CGFloat = focusedItem?.isMy == true ? 0.0 : 1.0
            if case .regular = component.metrics.widthClass {
                inputPanelAlpha *= component.visibilityFraction
            }
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                inputPanelTransition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                transition.setAlpha(view: inputPanelView, alpha: inputPanelAlpha)
            }
            
            if let captionItem = self.captionItem, captionItem.itemId != component.slice.item.storyItem.id {
                self.captionItem = nil
                if let captionItemView = captionItem.view.view {
                    captionItemView.removeFromSuperview()
                }
            }
            
            if !component.slice.item.storyItem.text.isEmpty {
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
                        text: component.slice.item.storyItem.text
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: contentFrame.height)
                )
                captionItem.view.parentState = state
                let captionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.maxY - captionSize.height), size: captionSize)
                if let captionItemView = captionItem.view.view {
                    if captionItemView.superview == nil {
                        self.addSubview(captionItemView)
                    }
                    captionItemTransition.setFrame(view: captionItemView, frame: captionFrame)
                    captionItemTransition.setAlpha(view: captionItemView, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
                }
            }
            
            let reactionsAnchorRect = CGRect(origin: CGPoint(x: inputPanelFrame.maxX - 40.0, y: inputPanelFrame.minY + 9.0), size: CGSize(width: 32.0, height: 32.0)).insetBy(dx: -4.0, dy: -4.0)
            
            var effectiveDisplayReactions = self.displayReactions
            if self.inputPanelExternalState.isEditing && !self.inputPanelExternalState.hasText {
                effectiveDisplayReactions = true
            }
            if self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil {
                effectiveDisplayReactions = false
            }
            if self.sendMessageContext.recordedAudioPreview != nil {
                effectiveDisplayReactions = false
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
                                selectedItems: Set()
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
                            
                            var selectedReaction: AvailableReactions.Reaction?
                            for reaction in availableReactions.reactions {
                                if reaction.value == updateReaction.reaction {
                                    selectedReaction = reaction
                                    break
                                }
                            }
                            
                            guard let reaction = selectedReaction else {
                                return
                            }
                            
                            let targetView = UIView(frame: CGRect(origin: CGPoint(x: floor((self.bounds.width - 100.0) * 0.5), y: floor((self.bounds.height - 100.0) * 0.5)), size: CGSize(width: 100.0, height: 100.0)))
                            targetView.isUserInteractionEnabled = false
                            self.addSubview(targetView)
                            
                            reactionContextNode.willAnimateOutToReaction(value: updateReaction.reaction)
                            reactionContextNode.animateOutToReaction(value: updateReaction.reaction, targetView: targetView, hideNode: false, animateTargetContainer: nil, addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
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
                            
                            self.displayReactions = false
                            if hasFirstResponder(self) {
                                self.endEditing(true)
                            }
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                            
                            if let centerAnimation = reaction.centerAnimation {
                                /*let file = centerAnimation
                                
                                var text = "."
                                loop: for attribute in file.attributes {
                                    switch attribute {
                                    case let .CustomEmoji(_, _, displayText, _):
                                        text = displayText
                                        break loop
                                    default:
                                        break
                                    }
                                }*/
                                
                                let message: EnqueueMessage = .message(
                                    text: "",
                                    attributes: [
                                        //TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 1, type: .CustomEmoji(stickerPack: nil, fileId: centerAnimation.fileId.id))])
                                    ],
                                    inlineStickers: [:],//[centerAnimation.fileId: centerAnimation],
                                    mediaReference: AnyMediaReference.standalone(media: reaction.activateAnimation),
                                    replyToMessageId: nil,
                                    replyToStoryId: StoryId(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id),
                                    localGroupingKey: nil,
                                    correlationId: nil,
                                    bubbleUpEmojiOrStickersets: []
                                )
                                let _ = enqueueMessages(account: component.context.account, peerId: component.slice.peer.id, messages: [message]).start()
                                
                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                                component.presentController(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .sticker(context: component.context, file: centerAnimation, loop: false, title: nil, text: "Reaction Sent.", undoText: "View in Chat", customAction: {
                                    }),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in return false }
                                ))
                            }
                        })
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
                    reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, isCoveredByInput: false, isAnimatingOut: false, transition: reactionContextNodeTransition.containedViewLayoutTransition)
                    
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
            
            var footerPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - footerPanelSize.height), size: footerPanelSize)
            var footerPanelAlpha: CGFloat = (focusedItem?.isMy == true && !self.displayViewList) ? 1.0 : 0.0
            if case .regular = component.metrics.widthClass {
                footerPanelAlpha *= component.visibilityFraction
            }
            if self.displayViewList {
                footerPanelFrame.origin.y += footerPanelSize.height
            }
            if let footerPanelView = self.footerPanel.view {
                if footerPanelView.superview == nil {
                    self.addSubview(footerPanelView)
                }
                transition.setFrame(view: footerPanelView, frame: footerPanelFrame)
                transition.setAlpha(view: footerPanelView, alpha: footerPanelAlpha)
            }
            
            let bottomGradientHeight = inputPanelSize.height + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - component.inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            //transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: 0.0)
            
            var normalDimAlpha: CGFloat = 0.0
            if let captionItem = self.captionItem {
                normalDimAlpha = captionItem.externalState.expandFraction
            }
            var dimAlpha: CGFloat = (inputPanelIsOverlay || self.inputPanelExternalState.isEditing) ? 1.0 : normalDimAlpha
            if component.hideUI || self.displayViewList {
                dimAlpha = 0.0
            }
            
            transition.setFrame(layer: self.contentDimLayer, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            transition.setAlpha(layer: self.contentDimLayer, alpha: dimAlpha)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let scrollContentSize = availableSize
            if scrollContentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            if let focusedItem, let visibleItem = self.visibleItems[focusedItem.storyItem.id] {
                let navigationStripSideInset: CGFloat = 8.0
                let navigationStripTopInset: CGFloat = 8.0
                
                let index = focusedItem.position
                
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
                        self.contentContainerView.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: navigationStripSideInset, y: navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)))
                    transition.setAlpha(view: navigationStripView, alpha: (component.hideUI || self.displayViewList) ? 0.0 : 1.0)
                }
                
                var items: [StoryActionsComponent.Item] = []
                let _ = focusedItem
                items.append(StoryActionsComponent.Item(
                    kind: .share,
                    isActivated: false
                ))
                
                let inlineActionsSize = self.inlineActions.update(
                    transition: transition,
                    component: AnyComponent(StoryActionsComponent(
                        items: items,
                        action: { [weak self] item in
                            guard let self else {
                                return
                            }
                            self.sendMessageContext.performInlineAction(view: self, item: item)
                        }
                    )),
                    environment: {},
                    containerSize: contentFrame.size
                )
                if let inlineActionsView = self.inlineActions.view {
                    if inlineActionsView.superview == nil {
                        //self.contentContainerView.addSubview(inlineActionsView)
                    }
                    transition.setFrame(view: inlineActionsView, frame: CGRect(origin: CGPoint(x: contentFrame.width - 10.0 - inlineActionsSize.width, y: contentFrame.height - 20.0 - inlineActionsSize.height), size: inlineActionsSize))
                    
                    var inlineActionsAlpha: CGFloat = inputPanelIsOverlay ? 0.0 : 1.0
                    if self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil {
                        inlineActionsAlpha = 0.0
                    }
                    if self.displayReactions {
                        inlineActionsAlpha = 0.0
                    }
                    if component.hideUI || self.displayViewList {
                        inlineActionsAlpha = 0.0
                    }
                    
                    transition.setAlpha(view: inlineActionsView, alpha: inlineActionsAlpha)
                }
            }
            
            component.externalState.derivedMediaSize = contentFrame.size
            component.externalState.derivedBottomInset = availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY)
            
            return contentSize
        }
        
        private func openItemPrivacySettings() {
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
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .top)
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
