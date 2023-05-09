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
import AvatarNode

public final class StoryItemSetContainerComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var derivedBottomInset: CGFloat = 0.0
        
        public init() {
        }
    }
    
    public enum NavigationDirection {
        case previous
        case next
    }
    
    public let context: AccountContext
    public let externalState: ExternalState
    public let initialItemSlice: StoryContentItemSlice
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let containerInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let inputHeight: CGFloat
    public let isProgressPaused: Bool
    public let hideUI: Bool
    public let presentController: (ViewController) -> Void
    public let close: () -> Void
    public let navigateToItemSet: (NavigationDirection) -> Void
    public let controller: () -> ViewController?
    
    public init(
        context: AccountContext,
        externalState: ExternalState,
        initialItemSlice: StoryContentItemSlice,
        theme: PresentationTheme,
        strings: PresentationStrings,
        containerInsets: UIEdgeInsets,
        safeInsets: UIEdgeInsets,
        inputHeight: CGFloat,
        isProgressPaused: Bool,
        hideUI: Bool,
        presentController: @escaping (ViewController) -> Void,
        close: @escaping () -> Void,
        navigateToItemSet: @escaping (NavigationDirection) -> Void,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.externalState = externalState
        self.initialItemSlice = initialItemSlice
        self.theme = theme
        self.strings = strings
        self.containerInsets = containerInsets
        self.safeInsets = safeInsets
        self.inputHeight = inputHeight
        self.isProgressPaused = isProgressPaused
        self.hideUI = hideUI
        self.presentController = presentController
        self.close = close
        self.navigateToItemSet = navigateToItemSet
        self.controller = controller
    }
    
    public static func ==(lhs: StoryItemSetContainerComponent, rhs: StoryItemSetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialItemSlice !== rhs.initialItemSlice {
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
        if lhs.isProgressPaused != rhs.isProgressPaused {
            return false
        }
        if lhs.hideUI != rhs.hideUI {
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
        
        let inputPanel = ComponentView<Empty>()
        let footerPanel = ComponentView<Empty>()
        let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        var itemLayout: ItemLayout?
        var ignoreScrolling: Bool = false
        
        var focusedItemId: AnyHashable?
        var currentSlice: StoryContentItemSlice?
        var currentSliceDisposable: Disposable?
        
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
                    
                    /*strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            let isLocked = strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId
                            if let audioRecorder = audioRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: isLocked))
                                }
                            } else {
                                if case .waitingForPreview = panelState.mediaRecordingState {
                                    return panelState
                                }
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })*/
                    
                    self.audioRecorderStatusDisposable?.dispose()
                    self.audioRecorderStatusDisposable = nil
                    
                    if let audioRecorder = audioRecorder {
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
                                self.sendMessageContext.stopMediaRecorder()
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
                        HapticFeedback().impact(.light)
                        
                        videoRecorder.onDismiss = { [weak self] isCancelled in
                            guard let self else {
                                return
                            }
                            //self?.chatDisplayNode.updateRecordedMediaDeleted(isCancelled)
                            //self?.beginMediaRecordingRequestId += 1
                            //self?.lockMediaRecordingRequestId = nil
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
                        
                        /*if strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId {
                            videoRecorder.lockVideo()
                        }*/
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
            self.currentSliceDisposable?.dispose()
            self.audioRecorderDisposable?.dispose()
            self.audioRecorderStatusDisposable?.dispose()
            self.audioRecorderStatusDisposable?.dispose()
        }
        
        func isPointInsideContentArea(point: CGPoint) -> Bool {
            return self.contentContainerView.frame.contains(point)
        }
        
        @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }), let itemLayout = self.itemLayout {
                if hasFirstResponder(self) {
                    self.displayReactions = false
                    self.endEditing(true)
                } else if self.displayReactions {
                    self.displayReactions = false
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                } else {
                    let point = recognizer.location(in: self)
                    
                    var nextIndex: Int
                    if point.x < itemLayout.size.width * 0.25 {
                        nextIndex = currentIndex - 1
                    } else {
                        nextIndex = currentIndex + 1
                    }
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let focusedItemId = currentSlice.items[nextIndex].id
                        self.focusedItemId = focusedItemId
                        
                        currentSlice.items[nextIndex].markAsSeen?()
                        
                        self.state?.updated(transition: .immediate)
                        
                        self.currentSliceDisposable?.dispose()
                        self.currentSliceDisposable = (currentSlice.update(
                            currentSlice,
                            focusedItemId
                        )
                        |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                            guard let self else {
                                return
                            }
                            self.currentSlice = contentSlice
                            self.state?.updated(transition: .immediate)
                        })
                    } else {
                        if point.x < itemLayout.size.width * 0.25 {
                            self.component?.navigateToItemSet(.previous)
                        } else {
                            self.component?.navigateToItemSet(.next)
                        }
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
            if let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                validIds.append(focusedItemId)
                
                var itemTransition = transition
                let visibleItem: VisibleItem
                if let current = self.visibleItems[focusedItemId] {
                    visibleItem = current
                } else {
                    itemTransition = .immediate
                    visibleItem = VisibleItem()
                    self.visibleItems[focusedItemId] = visibleItem
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: focusedItem.component,
                    environment: {
                        StoryContentItem.Environment(
                            externalState: visibleItem.externalState,
                            presentationProgressUpdated: { [weak self, weak visibleItem] progress in
                                guard let self = self else {
                                    return
                                }
                                guard let visibleItem else {
                                    return
                                }
                                visibleItem.currentProgress = progress
                                
                                if let navigationStripView = self.navigationStrip.view as? MediaNavigationStripComponent.View {
                                    navigationStripView.updateCurrentItemProgress(value: progress, transition: .immediate)
                                }
                                if progress >= 1.0 && !visibleItem.requestedNext {
                                    visibleItem.requestedNext = true
                                    
                                    if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                                        var nextIndex = currentIndex + 1
                                        nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                                        if nextIndex != currentIndex {
                                            let focusedItemId = currentSlice.items[nextIndex].id
                                            self.focusedItemId = focusedItemId
                                            
                                            currentSlice.items[nextIndex].markAsSeen?()
                                            
                                            self.state?.updated(transition: .immediate)
                                            
                                            self.currentSliceDisposable?.dispose()
                                            self.currentSliceDisposable = (currentSlice.update(
                                                currentSlice,
                                                focusedItemId
                                            )
                                            |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                                                guard let self else {
                                                    return
                                                }
                                                self.currentSlice = contentSlice
                                                self.state?.updated(transition: .immediate)
                                            })
                                        } else {
                                            self.component?.navigateToItemSet(.next)
                                        }
                                    }
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
                        view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.displayReactions || self.actionSheet != nil || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil)
                    }
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
                        view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.reactionItems != nil || self.actionSheet != nil || self.contextController != nil || self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil)
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
            
            if let sourceView = transitionIn.sourceView {
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.contentContainerView.frame.minX, y: sourceLocalFrame.minY - self.contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                if let rightInfoView = self.rightInfoItem?.view.view {
                    let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: CGPoint(x: innerSourceLocalFrame.center.x - rightInfoView.layer.position.x, y: innerSourceLocalFrame.center.y - rightInfoView.layer.position.y), to: CGPoint(), elevation: 0.0, duration: 0.3, curve: .spring, reverse: false)
                    rightInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", additive: true)
                    
                    rightInfoView.layer.animateScale(from: innerSourceLocalFrame.width / rightInfoView.bounds.width, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
                
                if let focusedItemId = self.focusedItemId, let visibleItemView = self.visibleItems[focusedItemId]?.view.view {
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
            
            if let sourceView = transitionOut.destinationView {
                let sourceLocalFrame = sourceView.convert(transitionOut.destinationRect, to: self)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.contentContainerView.frame.minX, y: sourceLocalFrame.minY - self.contentContainerView.frame.minY), size: sourceLocalFrame.size)
                
                if let rightInfoView = self.rightInfoItem?.view.view {
                    let positionKeyframes: [CGPoint] = generateParabollicMotionKeyframes(from: innerSourceLocalFrame.center, to: rightInfoView.layer.position, elevation: 0.0, duration: 0.3, curve: .spring, reverse: true)
                    rightInfoView.layer.position = positionKeyframes[positionKeyframes.count - 1]
                    rightInfoView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: 0.3, keyPath: "position", removeOnCompletion: false, additive: false)
                    
                    rightInfoView.layer.animateScale(from: 1.0, to: innerSourceLocalFrame.width / rightInfoView.bounds.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
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
                
                if let focusedItemId = self.focusedItemId, let visibleItemView = self.visibleItems[focusedItemId]?.view.view {
                    let innerScale = innerSourceLocalFrame.width / visibleItemView.bounds.width
                    let innerFromFrame = CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: CGSize(width: innerSourceLocalFrame.width, height: visibleItemView.bounds.height * innerScale))
                    
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
                self.focusedItemId = component.initialItemSlice.focusedItemId ?? component.initialItemSlice.items.first?.id
                self.currentSlice = component.initialItemSlice
                
                self.currentSliceDisposable?.dispose()
                if let focusedItemId = self.focusedItemId {
                    if let item = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                        item.markAsSeen?()
                    }
                    
                    self.currentSliceDisposable = (component.initialItemSlice.update(
                        component.initialItemSlice,
                        focusedItemId
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                        guard let self else {
                            return
                        }
                        self.currentSlice = contentSlice
                        self.state?.updated(transition: .immediate)
                    })
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
                    
                    self.reactionItems = reactionItems
                    if self.displayReactions {
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                })
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
            
            if let focusedItemId = self.focusedItemId {
                if let currentSlice = self.currentSlice {
                    if !currentSlice.items.contains(where: { $0.id == focusedItemId }) {
                        self.focusedItemId = currentSlice.items.first?.id
                        
                        currentSlice.items.first?.markAsSeen?()
                    }
                } else {
                    self.focusedItemId = nil
                }
            }
            
            //self.updatePreloads()
            
            self.component = component
            self.state = state
            
            var bottomContentInset: CGFloat
            if !component.safeInsets.bottom.isZero {
                bottomContentInset = component.safeInsets.bottom + 1.0
            } else {
                bottomContentInset = 0.0
            }
            
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
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
                            
                            self.displayReactions = true
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                        })
                    },
                    audioRecorder: self.sendMessageContext.audioRecorderValue,
                    videoRecordingStatus: self.sendMessageContext.videoRecorderValue?.audioStatus,
                    displayGradient: component.inputHeight != 0.0,
                    bottomInset: component.inputHeight != 0.0 ? 0.0 : bottomContentInset
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            var currentItem: StoryContentItem?
            if let focusedItemId = self.focusedItemId, let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == focusedItemId }) {
                currentItem = item
            }
            
            let footerPanelSize = self.footerPanel.update(
                transition: transition,
                component: AnyComponent(StoryFooterPanelComponent(
                    context: component.context,
                    storyItem: currentItem?.storyItem,
                    deleteAction: { [weak self] in
                        guard let self, let component = self.component, let focusedItemId = self.focusedItemId else {
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
                                    
                                    if let currentSlice = self.currentSlice, let index = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
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
                                            
                                            /*var updatedItems: [StoryContentItem] = []
                                            for item in currentSlice.items {
                                                if item.id != focusedItemId {
                                                    updatedItems.append(StoryContentItem(
                                                        id: item.id,
                                                        position: updatedItems.count,
                                                        component: item.component,
                                                        centerInfoComponent: item.centerInfoComponent,
                                                        rightInfoComponent: item.rightInfoComponent,
                                                        targetMessageId: item.targetMessageId,
                                                        preload: item.preload,
                                                        delete: item.delete,
                                                        hasLike: item.hasLike,
                                                        isMy: item.isMy
                                                    ))
                                                }
                                            }*/
                                            
                                            /*self.currentSlice = StoryContentItemSlice(
                                                id: currentSlice.id,
                                                focusedItemId: nil,
                                                items: updatedItems,
                                                totalCount: currentSlice.totalCount - 1,
                                                update: currentSlice.update
                                            )*/
                                            self.state?.updated(transition: .immediate)
                                        }
                                        
                                        item.delete?()
                                    }
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
                        
                        items.append(.action(ContextMenuActionItem(text: "Who can see", textLayout: .secondLineWithValue("Everyone"), icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self else {
                                return
                            }
                            self.openItemPrivacySettings()
                        })))
                        
                        items.append(.separator)
                        
                        items.append(.action(ContextMenuActionItem(text: "Save to profile", icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            a(.default)
                            
                            guard let self, let component = self.component else {
                                return
                            }
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            self.component?.presentController(UndoOverlayController(
                                presentationData: presentationData,
                                content: .info(title: "Story saved to your profile", text: "Saved stories can be viewed by others on your profile until you remove them.", timeout: nil),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                action: { _ in return false }
                            ))
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Save image", icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor)
                        }, action: { _, a in
                            a(.default)
                        })))
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
            
            let inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if component.inputHeight == 0.0 {
                inputPanelBottomInset = bottomContentInset
                bottomContentInset += inputPanelSize.height
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = component.inputHeight
                inputPanelIsOverlay = true
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: component.containerInsets.top), size: CGSize(width: availableSize.width, height: availableSize.height - component.containerInsets.top - bottomContentInset))
            transition.setFrame(view: self.contentContainerView, frame: contentFrame)
            transition.setCornerRadius(layer: self.contentContainerView.layer, cornerRadius: 10.0)
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Media Gallery/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 50.0, height: 64.0))
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
                transition.setAlpha(view: self.closeButton, alpha: component.hideUI ? 0.0 : 1.0)
            }
            
            var focusedItem: StoryContentItem?
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                focusedItem = item
            }
            
            var currentRightInfoItem: InfoItem?
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                if let rightInfoComponent = item.rightInfoComponent {
                    if let rightInfoItem = self.rightInfoItem, rightInfoItem.component == item.rightInfoComponent {
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
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                if let centerInfoComponent = item.centerInfoComponent {
                    if let centerInfoItem = self.centerInfoItem, centerInfoItem.component == item.centerInfoComponent {
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
                    /*view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })*/
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
                    
                    transition.setAlpha(view: view, alpha: component.hideUI ? 0.0 : 1.0)
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
                    
                    transition.setAlpha(view: view, alpha: component.hideUI ? 0.0 : 1.0)
                }
            }
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            transition.setAlpha(layer: self.topContentGradientLayer, alpha: component.hideUI ? 0.0 : 1.0)
            
            let itemLayout = ItemLayout(size: CGSize(width: contentFrame.width, height: availableSize.height - component.containerInsets.top - 44.0 - bottomContentInsetWithoutInput))
            self.itemLayout = itemLayout
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                transition.setAlpha(view: inputPanelView, alpha: focusedItem?.isMy == true ? 0.0 : 1.0)
            }
            
            let reactionsAnchorRect = CGRect(origin: CGPoint(x: inputPanelFrame.maxX - 40.0, y: inputPanelFrame.minY + 9.0), size: CGSize(width: 32.0, height: 32.0)).insetBy(dx: -4.0, dy: -4.0)
            
            if let reactionItems = self.reactionItems, (self.displayReactions || self.inputPanelExternalState.isEditing) {
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
            
            let footerPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - footerPanelSize.height), size: footerPanelSize)
            if let footerPanelView = self.footerPanel.view {
                if footerPanelView.superview == nil {
                    self.addSubview(footerPanelView)
                }
                transition.setFrame(view: footerPanelView, frame: footerPanelFrame)
                transition.setAlpha(view: footerPanelView, alpha: focusedItem?.isMy == true ? 1.0 : 0.0)
            }
            
            let bottomGradientHeight = inputPanelSize.height + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - component.inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            //transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: 0.0)
            
            transition.setFrame(layer: self.contentDimLayer, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            transition.setAlpha(layer: self.contentDimLayer, alpha: (inputPanelIsOverlay || self.inputPanelExternalState.isEditing) ? 1.0 : 0.0)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = availableSize
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let visibleItem = self.visibleItems[focusedItemId] {
                let navigationStripSideInset: CGFloat = 8.0
                let navigationStripTopInset: CGFloat = 8.0
                
                let index = currentSlice.items.first(where: { $0.id == self.focusedItemId })?.position ?? 0
                
                let _ = self.navigationStrip.update(
                    transition: transition,
                    component: AnyComponent(MediaNavigationStripComponent(
                        index: max(0, min(index, currentSlice.totalCount - 1)),
                        count: currentSlice.totalCount
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
                    transition.setAlpha(view: navigationStripView, alpha: component.hideUI ? 0.0 : 1.0)
                }
                
                if let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                    var items: [StoryActionsComponent.Item] = []
                    let _ = focusedItem
                    /*if !focusedItem.isMy {
                        items.append(StoryActionsComponent.Item(
                            kind: .like,
                            isActivated: focusedItem.hasLike
                        ))
                    }*/
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
                            self.contentContainerView.addSubview(inlineActionsView)
                        }
                        transition.setFrame(view: inlineActionsView, frame: CGRect(origin: CGPoint(x: contentFrame.width - 10.0 - inlineActionsSize.width, y: contentFrame.height - 20.0 - inlineActionsSize.height), size: inlineActionsSize))
                        
                        var inlineActionsAlpha: CGFloat = inputPanelIsOverlay ? 0.0 : 1.0
                        if self.sendMessageContext.audioRecorderValue != nil || self.sendMessageContext.videoRecorderValue != nil {
                            inlineActionsAlpha = 0.0
                        }
                        if self.reactionItems != nil {
                            inlineActionsAlpha = 0.0
                        }
                        if component.hideUI {
                            inlineActionsAlpha = 0.0
                        }
                        
                        transition.setAlpha(view: inlineActionsView, alpha: inlineActionsAlpha)
                    }
                }
            }
            
            component.externalState.derivedBottomInset = availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY)
            
            return contentSize
        }
        
        private func openItemPrivacySettings() {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let storyItem = focusedItem.storyItem else {
                return
            }
            
            enum AdditionalCategoryId: Int {
                case everyone
                case contacts
                case closeFriends
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            
            let additionalCategories: [ChatListNodeAdditionalCategory] = [
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.everyone.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), cornerRadius: nil, color: .blue),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
                    title: "Everyone",
                    appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                ),
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.contacts.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: .white), iconScale: 1.0 * 0.8, cornerRadius: nil, color: .yellow),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: .white), iconScale: 0.6 * 0.8, cornerRadius: 6.0, circleCorners: true, color: .yellow),
                    title: presentationData.strings.ChatListFolder_CategoryContacts,
                    appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                ),
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.closeFriends.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Call/StarHighlighted"), color: .white), iconScale: 1.0 * 0.6, cornerRadius: nil, color: .green),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Call/StarHighlighted"), color: .white), iconScale: 0.6 * 0.6, cornerRadius: 6.0, circleCorners: true, color: .green),
                    title: "Close Friends",
                    appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                )
            ]
            
            var selectedChats = Set<EnginePeer.Id>()
            var selectedCategories = Set<Int>()
            if let privacy = storyItem.privacy {
                selectedChats.formUnion(privacy.additionallyIncludePeers)
                switch privacy.base {
                case .everyone:
                    selectedCategories.insert(AdditionalCategoryId.everyone.rawValue)
                case .contacts:
                    selectedCategories.insert(AdditionalCategoryId.contacts.rawValue)
                case .closeFriends:
                    selectedCategories.insert(AdditionalCategoryId.closeFriends.rawValue)
                }
            }
            
            let selectionController = component.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: component.context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                title: "Share Story",
                searchPlaceholder: "Search contacts",
                selectedChats: selectedChats,
                additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
                chatListFilters: nil,
                displayPresence: true
            )), options: [], filters: [.excludeSelf], alwaysEnabled: true, limit: 1000, reachedLimit: { _ in
            }))
            component.controller()?.present(selectionController, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            
            let _ = (selectionController.result
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak selectionController] result in
                guard case let .result(peerIds, additionalCategoryIds) = result else {
                    selectionController?.dismiss()
                    return
                }
                
                let _ = peerIds
                let _ = additionalCategoryIds
                
                selectionController?.dismiss()
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
