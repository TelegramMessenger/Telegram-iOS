import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SwiftSignalKit
import AppBundle
import MessageInputPanelComponent
import ShareController
import TelegramCore
import Postbox
import UndoUI
import ReactionSelectionNode
import EntityKeyboard
import AsyncDisplayKit
import AttachmentUI
import simd
import VolumeButtons
import TooltipUI
import ChatEntityKeyboardInputNode
import notify
import TelegramNotices

func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}

private final class MuteMonitor {
    private let updated: (Bool) -> Void
    
    private var token: Int32 = NOTIFY_TOKEN_INVALID
    private(set) var currentValue: Bool = false
    
    init(updated: @escaping (Bool) -> Void) {
        self.updated = updated
        
        func encodeText(string: String, key: Int16) -> String {
            let nsString = string as NSString
            let result = NSMutableString()
            for i in 0 ..< nsString.length {
                var c: unichar = nsString.character(at: i)
                c = unichar(Int16(c) + key)
                result.append(NSString(characters: &c, length: 1) as String)
            }
            return result as String
        }
        
        let keyString = encodeText(string: "dpn/bqqmf/tqsjohcpbse/sjohfstubuf", key: -1)
        let status = notify_register_dispatch(keyString, &self.token, DispatchQueue.main, { [weak self] value in
            guard let self else {
                return
            }
            let value = self.refresh()
            if self.currentValue != value {
                self.currentValue = value
                self.updated(value)
            }
        })
        let _ = status
        //print("Notify status: \(status)")
        
        self.currentValue = self.refresh()
    }
    
    private func refresh() -> Bool {
        var state: UInt64 = 0
        if self.token != NOTIFY_TOKEN_INVALID {
            let status = notify_get_state(self.token, &state)
            let _ = status
            //print("Notify refresh status: \(status)")
        }
        
        return state != 0
    }
    
    deinit {
        if self.token != NOTIFY_TOKEN_INVALID {
            notify_cancel(self.token)
        }
    }
}

private final class StoryLongPressRecognizer: UILongPressGestureRecognizer {
    var shouldBegin: ((UITouch) -> Bool)?
    var updateIsTracking: ((CGPoint?) -> Void)?
    var updatePanMove: ((CGPoint, CGPoint) -> Void)?
    var updatePanEnded: (() -> Void)?
    
    override var state: UIGestureRecognizer.State {
        didSet {
            /*switch self.state {
            case .cancelled, .ended, .failed:
                if self.isTracking {
                    self.isTracking = false
                    self.updateIsTracking?(self.isTracking)
                }
            default:
                break
            }*/
        }
    }
    
    private var isTracking: Bool = false
    private var isValidated: Bool = false
    
    private var initialLocation: CGPoint?
    
    override func reset() {
        super.reset()
        
        self.isValidated = false
        if self.isTracking {
            self.isTracking = false
            self.updateIsTracking?(nil)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if !self.isValidated, let touch = touches.first {
            if let shouldBegin = self.shouldBegin, shouldBegin(touch) {
                self.isValidated = true
            } else {
                return
            }
        }
        
        if self.isValidated {
            super.touchesBegan(touches, with: event)
            
            if !self.isTracking {
                self.isTracking = true
                self.initialLocation = touches.first?.location(in: self.view)
                self.updateIsTracking?(initialLocation)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.isValidated {
            super.touchesMoved(touches, with: event)
            
            if let location = touches.first?.location(in: self.view), let initialLocation = self.initialLocation {
                self.updatePanMove?(initialLocation, CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y))
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.updatePanEnded?()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.updatePanEnded?()
    }
}

private final class StoryPinchGesture: UIPinchGestureRecognizer {
    private final class Target {
        var updated: (() -> Void)?

        @objc func onGesture(_ gesture: UIPinchGestureRecognizer) {
            self.updated?()
        }
    }

    private let target: Target

    private(set) var currentTransform: (CGFloat, CGPoint, CGPoint)?

    var shouldBegin: ((CGPoint) -> Bool)?
    var began: (() -> Void)?
    var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?
    var ended: (() -> Void)?

    private var initialLocation: CGPoint?
    private var pinchLocation = CGPoint()
    private var currentOffset = CGPoint()

    private var currentNumberOfTouches = 0

    init() {
        self.target = Target()

        super.init(target: self.target, action: #selector(self.target.onGesture(_:)))

        self.target.updated = { [weak self] in
            self?.gestureUpdated()
        }
    }

    override func reset() {
        super.reset()

        self.currentNumberOfTouches = 0
        self.initialLocation = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first, let shouldBegin = self.shouldBegin, !shouldBegin(touch.location(in: self.view)) {
            self.state = .failed
            return
        }
        
        super.touchesBegan(touches, with: event)

        //self.currentTouches.formUnion(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
    }

    private func gestureUpdated() {
        switch self.state {
        case .began:
            self.currentOffset = CGPoint()

            let pinchLocation = self.location(in: self.view)
            self.pinchLocation = pinchLocation
            self.initialLocation = pinchLocation
            let scale = max(1.0, self.scale)
            self.currentTransform = (scale, self.pinchLocation, self.currentOffset)

            self.currentNumberOfTouches = self.numberOfTouches

            self.began?()
        case .changed:
            let locationSum = self.location(in: self.view)

            if self.numberOfTouches < 2 && self.currentNumberOfTouches >= 2 {
                self.initialLocation = CGPoint(x: locationSum.x - self.currentOffset.x, y: locationSum.y - self.currentOffset.y)
            }
            self.currentNumberOfTouches = self.numberOfTouches

            if let initialLocation = self.initialLocation {
                self.currentOffset = CGPoint(x: locationSum.x - initialLocation.x, y: locationSum.y - initialLocation.y)
            }
            if let (scale, pinchLocation, _) = self.currentTransform {
                self.currentTransform = (scale, pinchLocation, self.currentOffset)
                self.updated?(scale, pinchLocation, self.currentOffset)
            }

            let scale = max(1.0, self.scale)
            self.currentTransform = (scale, self.pinchLocation, self.currentOffset)
            self.updated?(scale, self.pinchLocation, self.currentOffset)
        case .ended, .cancelled:
            self.ended?()
        default:
            break
        }
    }
}

private final class StoryContainerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let content: StoryContentContext
    let focusedItemPromise: Promise<StoryId?>
    let transitionIn: StoryContainerScreen.TransitionIn?
    let transitionOut: (EnginePeer.Id, Int32) -> StoryContainerScreen.TransitionOut?
    
    init(
        context: AccountContext,
        content: StoryContentContext,
        focusedItemPromise: Promise<StoryId?>,
        transitionIn: StoryContainerScreen.TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id, Int32) -> StoryContainerScreen.TransitionOut?
    ) {
        self.context = context
        self.content = content
        self.focusedItemPromise = focusedItemPromise
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
    }
    
    static func ==(lhs: StoryContainerScreenComponent, rhs: StoryContainerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content !== rhs.content {
            return false
        }
        return true
    }
    
    private final class ItemSetView: UIView {
        let view = ComponentView<Empty>()
        let externalState = StoryItemSetContainerComponent.ExternalState()
        
        let tintLayer = SimpleGradientLayer()
        
        var rotationFraction: CGFloat?
        
        override static var layerClass: AnyClass {
            return CATransformLayer.self
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.tintLayer.opacity = 0.0
            
            let colors: [CGColor] = [
                UIColor.black.withAlphaComponent(1.0).cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor,
                UIColor.black.withAlphaComponent(0.5).cgColor
            ]
            
            self.tintLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            self.tintLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
            self.tintLayer.colors = colors
            self.tintLayer.type = .axial
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let componentView = self.view.view else {
                return nil
            }
            return componentView.hitTest(point, with: event)
        }
    }
    
    private struct ItemSetPanState: Equatable {
        var fraction: CGFloat
        var didBegin: Bool
        
        init(fraction: CGFloat, didBegin: Bool) {
            self.fraction = fraction
            self.didBegin = didBegin
        }
    }

    final class View: UIView, UIGestureRecognizerDelegate {
        private var component: StoryContainerScreenComponent? {
            didSet {
                if self.component != nil {
                    self.isComponentReadyPromise.set(true)
                }
            }
        }
        private let isComponentReadyPromise = ValuePromise(false, ignoreRepeated: true)
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private let backgroundLayer: SimpleLayer
        private let backgroundEffectView: BlurredBackgroundView
        
        private let focusedItem = ValuePromise<StoryId?>(nil, ignoreRepeated: true)
        private var stateValue: StoryContentContextState?
        private var contentUpdatedDisposable: Disposable?
        
        private var stealthModeActiveUntilTimestamp: Int32?
        private var stealthModeDisposable: Disposable?
        private var stealthModeTimer: Foundation.Timer?
        
        private let storyItemSharedState = StoryContentItem.SharedState()
        private var visibleItemSetViews: [EnginePeer.Id: ItemSetView] = [:]
        
        private var itemSetPinchState: StoryItemSetContainerComponent.PinchState?
        private var itemSetPanState: ItemSetPanState?
        private var isHoldingTouch: Bool = false
        
        private var transitionCloneMasterView: UIView
        
        private var volumeButtonsListener: VolumeButtonsListener?
        private let contentWantsVolumeButtonMonitoring = ValuePromise<Bool>(false, ignoreRepeated: true)
        private let isMuteSwitchOnPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
        private let volumeButtonsListenerShouldBeActive = Promise<Bool>()
        private var volumeButtonsListenerShouldBeActiveDisposable: Disposable?
        
        private var isMuteSwitchOn: Bool = false
        private var muteMonitor: MuteMonitor?
        
        private var headphonesDisposable: Disposable?
        private var areHeadphonesConnected: Bool = false
        
        private var audioMode: StoryContentItem.AudioMode = .ambient {
            didSet {
                self.audioModePromise.set(self.audioMode)
            }
        }
        private let audioModePromise = ValuePromise<StoryContentItem.AudioMode>(.ambient, ignoreRepeated: true)
        
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private let closeFriendsPromise = Promise<[EnginePeer]>()
        private var blockedPeers: BlockedPeersContext?
        
        private var availableReactions: StoryAvailableReactions?
        
        private let sharedViewListsContext = StoryItemSetViewListComponent.SharedListsContext()
        
        private var didAnimateIn: Bool = false
        
        private var isAnimatingOut: Bool = false
        private var didAnimateOut: Bool = false
        private var isDismissedExlusively: Bool = false
        
        var dismissWithoutTransitionOut: Bool = false
        
        var longPressRecognizer: StoryLongPressRecognizer?
        
        private var pendingNavigationToItemId: StoryId?
                
        private let interactionGuide = ComponentView<Empty>()
        private var isDisplayingInteractionGuide: Bool = false
        private var displayInteractionGuideDisposable: Disposable?
        
        private var previousSeekTime: Double?
        private var initialSeekTimestamp: Double?
        
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.backgroundColor = UIColor.black.cgColor
            self.backgroundLayer.zPosition = -1000.0
            
            self.backgroundEffectView = BlurredBackgroundView(color: UIColor(rgb: 0x000000, alpha: 0.9), enableBlur: true)
            self.backgroundEffectView.layer.zPosition = -1001.0
            
            let transitionCloneMasterView = UIView()
            transitionCloneMasterView.isHidden = true
            transitionCloneMasterView.isUserInteractionEnabled = false
            self.transitionCloneMasterView = transitionCloneMasterView
            
            super.init(frame: frame)
            
            self.addSubview(transitionCloneMasterView)
            
            self.layer.addSublayer(self.backgroundLayer)
            
            let horizontalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return []
                }
                if self.isDisplayingInteractionGuide {
                    return []
                }
                if let environment = self.environment, case .regular = environment.metrics.widthClass {
                } else {
                    if !itemSetComponentView.isPointInsideContentArea(point: self.convert(point, to: itemSetComponentView)) {
                        return []
                    }
                }
                if !itemSetComponentView.allowsInteractiveGestures() {
                    return []
                }
                return [.left, .right]
            })
            self.addGestureRecognizer(horizontalPanRecognizer)
            
            let longPressRecognizer = StoryLongPressRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
            longPressRecognizer.delegate = self
            longPressRecognizer.updateIsTracking = { [weak self] point in
                guard let self else {
                    return
                }
                guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return
                }
                
                var point = point
                if let pointValue = point {
                    if !itemSetComponentView.allowsInstantPauseOnTouch(point: self.convert(pointValue, to: itemSetComponentView)) {
                        point = nil
                    }
                }
                
                if point != nil {
                    if !self.isHoldingTouch {
                        self.isHoldingTouch = true
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        if self.isHoldingTouch {
                            self.isHoldingTouch = false
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    }
                }
            }
            longPressRecognizer.updatePanMove = { [weak self] initialLocation, translation in
                guard let self, self.itemSetPanState?.didBegin == false else {
                    return
                }
                guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return
                }
                guard let visibleItemView = itemSetComponentView.visibleItems[slice.item.id]?.view.view as? StoryItemContentComponent.View else {
                    return
                }
                
                var apply = true
                let currentTime = CACurrentMediaTime()
                if let previousTime = self.previousSeekTime, currentTime - previousTime < 0.15 {
                    apply = false
                }
                if apply {
                    self.previousSeekTime = currentTime
                }
                
                let initialSeekTimestamp: Double
                if let current = self.initialSeekTimestamp {
                    initialSeekTimestamp = current
                } else {
                    initialSeekTimestamp = visibleItemView.effectiveTimestamp
                    self.initialSeekTimestamp = initialSeekTimestamp
                }
                
                let duration = visibleItemView.effectiveDuration
                let timestamp: Double
                if translation.x > 0.0 {
                    let fraction = translation.x / (self.bounds.width / 2.0)
                    timestamp = initialSeekTimestamp + duration * fraction
                } else {
                    let fraction = translation.x / (self.bounds.width / 2.0)
                    timestamp = initialSeekTimestamp + duration * fraction
                }
                visibleItemView.seekTo(max(0.0, min(duration, timestamp)), apply: apply)
            }
            longPressRecognizer.updatePanEnded = { [weak self] in
                guard let self else {
                    return
                }
                self.initialSeekTimestamp = nil
                self.previousSeekTime = nil
                
                guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return
                }
                guard let visibleItemView = itemSetComponentView.visibleItems[slice.item.id]?.view.view as? StoryItemContentComponent.View else {
                    return
                }
                visibleItemView.seekEnded()
            }
            longPressRecognizer.shouldBegin = { [weak self] touch in
                guard let self else {
                    return false
                }
                guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return false
                }
                if !itemSetComponentView.allowsExternalGestures(point: touch.location(in: itemSetComponentView)) {
                    return false
                }
                if !itemSetComponentView.isPointInsideContentArea(point: touch.location(in: itemSetComponentView)) {
                    return false
                }
                return true
            }
            self.longPressRecognizer = longPressRecognizer
            self.addGestureRecognizer(longPressRecognizer)
            
            let pinchRecognizer = StoryPinchGesture()
            pinchRecognizer.delegate = self
            pinchRecognizer.shouldBegin = { [weak self] pinchLocation in
                guard let self else {
                    return false
                }
                if self.isDisplayingInteractionGuide {
                    return false
                }
                if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                    if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        let itemLocation = self.convert(pinchLocation, to: itemSetComponentView)
                        if itemSetComponentView.allowsExternalGestures(point: itemLocation) {
                            return true
                        } else {
                            return false
                        }
                    }
                }
                
                return false
            }
            pinchRecognizer.updated = { [weak self] scale, pinchLocation, offset in
                guard let self else {
                    return
                }
                var pinchLocation = pinchLocation
                if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                    if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        pinchLocation = self.convert(pinchLocation, to: itemSetComponentView)
                    }
                }
                self.itemSetPinchState = StoryItemSetContainerComponent.PinchState(scale: scale, location: pinchLocation, offset: offset)
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }
            }
            pinchRecognizer.ended = { [weak self] in
                guard let self else {
                    return
                }
                self.itemSetPinchState = nil
                if !self.isUpdating {
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                }
            }
            self.addGestureRecognizer(pinchRecognizer)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.backgroundEffectView.addGestureRecognizer(tapGestureRecognizer)
            
            let muteMonitor = MuteMonitor(updated: { [weak self] isMuteSwitchOn in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    if self.isMuteSwitchOn != isMuteSwitchOn {
                        let changedToOff = self.isMuteSwitchOn && !isMuteSwitchOn
                        let changedToOn = !self.isMuteSwitchOn && isMuteSwitchOn
                        
                        self.isMuteSwitchOn = isMuteSwitchOn
                        
                        self.isMuteSwitchOnPromise.set(self.isMuteSwitchOn)
                        
                        if changedToOff {
                            switch self.audioMode {
                            case .on:
                                if self.isMuteSwitchOn || self.areHeadphonesConnected {
                                    self.audioMode = .off
                                    for (_, itemSetView) in self.visibleItemSetViews {
                                        if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                            componentView.enterAmbientMode(ambient: false)
                                        }
                                    }
                                } else {
                                    self.audioMode = .ambient
                                    for (_, itemSetView) in self.visibleItemSetViews {
                                        if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                            componentView.enterAmbientMode(ambient: !(self.isMuteSwitchOn || self.areHeadphonesConnected))
                                        }
                                    }
                                }
                            case .ambient:
                                if self.areHeadphonesConnected {
                                    self.audioMode = .off
                                    for (_, itemSetView) in self.visibleItemSetViews {
                                        if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                            componentView.enterAmbientMode(ambient: false)
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        } else if changedToOn {
                            switch self.audioMode {
                            case .off:
                                self.audioMode = .on
                                for (_, itemSetView) in self.visibleItemSetViews {
                                    if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                        componentView.leaveAmbientMode()
                                    }
                                }
                            default:
                                break
                            }
                        }
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                }
            })
            self.muteMonitor = muteMonitor
            self.isMuteSwitchOn = muteMonitor.currentValue
            self.isMuteSwitchOnPromise.set(self.isMuteSwitchOn)
            
            self.volumeButtonsListenerShouldBeActiveDisposable = (combineLatest(queue: .mainQueue(),
                self.contentWantsVolumeButtonMonitoring.get(),
                self.isMuteSwitchOnPromise.get(),
                self.audioModePromise.get(),
                self.isComponentReadyPromise.get()
            )
            |> map { contentWantsVolumeButtonMonitoring, isMuteSwitchOn, audioMode, isComponentReady -> Bool in
                if !isComponentReady {
                    return false
                }
                if !contentWantsVolumeButtonMonitoring {
                    return false
                }
                switch audioMode {
                case .ambient:
                    if isMuteSwitchOn {
                        return false
                    } else {
                        return true
                    }
                case .on:
                    return false
                case .off:
                    return true
                }
            }
            |> distinctUntilChanged).start(next: { [weak self] enable in
                guard let self else {
                    return
                }
                self.volumeButtonsListenerShouldBeActive.set(.single(enable))
                self.updateVolumeButtonMonitoring()
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentUpdatedDisposable?.dispose()
            self.volumeButtonsListenerShouldBeActiveDisposable?.dispose()
            self.headphonesDisposable?.dispose()
            self.stealthModeDisposable?.dispose()
            self.stealthModeTimer?.invalidate()
            self.displayInteractionGuideDisposable?.dispose()
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is StoryPinchGesture {
                return !hasFirstResponder(self)
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                return false
            }
            
            if let environment = self.environment, case .regular = environment.metrics.widthClass {
                
            } else {
                if !itemSetComponentView.isPointInsideContentArea(point: touch.location(in: itemSetComponentView)) {
                    return false
                }
            }
            
            return true
        }
        
        private func beginHorizontalPan(translation: CGPoint) {
            self.dismissAllTooltips()
            
            if self.layer.animation(forKey: "panState") != nil {
                self.layer.removeAnimation(forKey: "panState")
            }
            
            let updateImmediately = abs(translation.x) > 0.0
            
            if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                if !updateImmediately {
                    if !self.isUpdating {
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                }
            } else {
                self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                if !updateImmediately {
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                }
            }
            
            if updateImmediately {
                self.updateHorizontalPan(translation: translation)
            }
        }
        
        private func updateHorizontalPan(translation: CGPoint) {
            var translation = translation
            
            if var itemSetPanState = self.itemSetPanState, self.bounds.width > 0.0, let stateValue = self.stateValue, let _ = stateValue.slice {
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    let range: CGFloat = 600.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
                
                if translation.x > 0.0 && stateValue.previousSlice == nil {
                    translation.x = rubberBandingOffset(offset: translation.x, bandingStart: 0.0)
                } else if translation.x < 0.0 && stateValue.nextSlice == nil {
                    translation.x = -rubberBandingOffset(offset: -translation.x, bandingStart: 0.0)
                }
                
                var fraction = translation.x / self.bounds.width
                fraction = -max(-1.0, min(1.0, fraction))
                
                itemSetPanState.fraction = fraction
                self.itemSetPanState = itemSetPanState
                
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }
            }
        }
        
        private func commitHorizontalPan(velocity: CGPoint) {
            if var itemSetPanState = self.itemSetPanState {
                var shouldDismiss = false
                
                if let component = self.component, let stateValue = self.stateValue, let _ = stateValue.slice {
                    var direction: StoryContentContextNavigation.PeerDirection?
                    var mayDismiss = false
                    if itemSetPanState.fraction <= -0.3 {
                        direction = .previous
                    } else if itemSetPanState.fraction >= 0.3 {
                        direction = .next
                    } else if abs(velocity.x) >= 100.0 {
                        if velocity.x < 0.0 {
                            if stateValue.nextSlice != nil {
                                direction = .next
                            } else {
                                mayDismiss = true
                            }
                        } else {
                            if stateValue.previousSlice != nil {
                                direction = .previous
                            } else {
                                mayDismiss = true
                            }
                        }
                    }
                    
                    if let direction {
                        component.content.navigate(navigation: .peer(direction))
                        
                        if case .previous = direction {
                            itemSetPanState.fraction = 1.0 + itemSetPanState.fraction
                        } else {
                            itemSetPanState.fraction = itemSetPanState.fraction - 1.0
                        }
                        self.itemSetPanState = itemSetPanState
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    } else {
                        shouldDismiss = mayDismiss
                    }
                }
                
                itemSetPanState.fraction = 0.0
                self.itemSetPanState = itemSetPanState
                
                let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
                if !self.isUpdating {
                    self.state?.updated(transition: transition)
                }
                
                transition.attachAnimation(view: self, id: "panState", completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    self.itemSetPanState = nil
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                    
                    /*if let component = self.component {
                        component.content.resetSideStates()
                    }*/
                })
                
                if shouldDismiss {
                    self.environment?.controller()?.dismiss()
                }
            }
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                //print("began: \(CFAbsoluteTimeGetCurrent())")
                self.beginHorizontalPan(translation: recognizer.translation(in: self))
            case .changed:
                self.updateHorizontalPan(translation: recognizer.translation(in: self))
            case .cancelled, .ended:
                self.commitHorizontalPan(velocity: recognizer.velocity(in: self))
            default:
                break
            }
        }
        
        @objc private func longPressGesture(_ recognizer: StoryLongPressRecognizer) {
            switch recognizer.state {
            case .began:
                if self.itemSetPanState == nil {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: false)
                    if !self.isUpdating {
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                }
            case .cancelled, .ended:
                if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                    self.itemSetPanState = nil
                    if !self.isUpdating {
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                }
            default:
                break
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard case .recognized = recognizer.state else {
                return
            }
            let location = recognizer.location(in: recognizer.view)
            if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let currentItemView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                if currentItemView.hasActiveDeactivateableInput() {
                    currentItemView.deactivateInput()
                } else {
                    let itemViewFrame = currentItemView.convert(currentItemView.bounds, to: self)
                    if location.x < itemViewFrame.minX {
                        self.navigate(direction: .previous)
                    } else if location.x > itemViewFrame.maxX {
                        self.navigate(direction: .next)
                    }
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.isHidden || subview.alpha == 0.0 {
                    continue
                }
                
                if subview is ItemSetView {
                    if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], itemSetView === subview {
                        if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                            return result
                        }
                    }
                } else {
                    if let result = subview.hitTest(self.convert(self.convert(point, to: subview), to: subview), with: event) {
                        if let environment = self.environment, case .regular = environment.metrics.widthClass {
                            if result.isDescendant(of: self.backgroundEffectView) {
                                if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                                    return itemSetView.view.view
                                }
                            }
                        }
                        return result
                    }
                }
            }
            
            return nil
        }
        
        private func dismissAllTooltips() {
            guard let controller = self.environment?.controller() else {
                return
            }
            controller.forEachController { controller in
                if let controller = controller as? UndoOverlayController {
                    if let tag = controller.tag as? String, tag == "no_auto_dismiss" {
                    } else {
                        controller.dismissWithCommitAction()
                    }
                } else if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            }
        }
        
        func animateIn() {
            if let component = self.component {
                component.focusedItemPromise.set(self.focusedItem.get())
            }
            
            if let transitionIn = self.component?.transitionIn, transitionIn.sourceView != nil {
                self.backgroundLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.28, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.backgroundEffectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.28, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                
                if let transitionIn = self.component?.transitionIn, let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                    if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        itemSetComponentView.animateIn(transitionIn: transitionIn, completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            self.didAnimateIn = true
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                        })
                    } else {
                        self.didAnimateIn = true
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                } else {
                    self.didAnimateIn = true
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                }
            } else {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    
                    self.layer.allowsGroupOpacity = false
                    
                    self.didAnimateIn = true
                    self.state?.updated(transition: .immediate)
                })
            }
            
            Queue.mainQueue().after(0.4, { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                
                let _ = (ApplicationSpecificNotice.displayStoryReactionTooltip(accountManager: component.context.sharedContext.accountManager)
                |> delay(1.0, queue: .mainQueue())
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    if !value && !self.isDisplayingInteractionGuide {
                        if let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let currentItemView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                            currentItemView.maybeDisplayReactionTooltip()
                        }
                    }
                })
            })
        }
                
        func animateOut(completion: @escaping () -> Void) {
            self.isAnimatingOut = true
            
            if !self.dismissWithoutTransitionOut, let component = self.component, let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View, let transitionOut = component.transitionOut(slice.peer.id, slice.item.storyItem.id) {
                self.state?.updated(transition: .immediate)
                
                let transition = ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut))
                transition.setAlpha(layer: self.backgroundLayer, alpha: 0.0)
                transition.setAlpha(view: self.backgroundEffectView, alpha: 0.0)
                
                let transitionOutCompleted = transitionOut.completed
                let focusedItemPromise = component.focusedItemPromise
                
                let transitionCloneMasterView = self.transitionCloneMasterView
                transitionCloneMasterView.isHidden = false
                self.transitionCloneMasterView = UIView()
                
                itemSetComponentView.animateOut(transitionOut: transitionOut, transitionCloneMasterView: transitionCloneMasterView, completion: {
                    completion()
                    transitionOutCompleted()
                    focusedItemPromise.set(.single(nil))
                })
            } else {
                if let component = self.component, let stateValue = self.stateValue, let slice = stateValue.slice, let transitionOut = component.transitionOut(slice.peer.id, slice.item.storyItem.id) {
                    transitionOut.completed()
                }
                
                let transition: ComponentTransition
                if self.dismissWithoutTransitionOut {
                    transition = ComponentTransition(animation: .curve(duration: 0.5, curve: .spring))
                } else {
                    transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                
                self.isDismissedExlusively = true
                self.state?.updated(transition: transition)
                
                let focusedItemPromise = self.component?.focusedItemPromise
                
                transition.setAlpha(layer: self.backgroundLayer, alpha: 0.0, completion: { _ in
                    completion()
                    focusedItemPromise?.set(.single(nil))
                })
                transition.setAlpha(view: self.backgroundEffectView, alpha: 0.0)
            }
            
            self.didAnimateOut = true
        }
        
        private func updateVolumeButtonMonitoring() {
            guard self.volumeButtonsListener == nil, let component = self.component else {
                return
            }
            let buttonAction = { [weak self] in
                guard let self else {
                    return
                }
                guard let slice = self.stateValue?.slice else {
                    return
                }
                var isSilentVideo = false
                if case let .file(file) = slice.item.storyItem.media {
                    for attribute in file.attributes {
                        if case let .Video(_, _, flags, _, _, _) = attribute {
                            if flags.contains(.isSilent) {
                                isSilentVideo = true
                            }
                        }
                    }
                }
                
                if isSilentVideo {
                    if let slice = self.stateValue?.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let currentItemView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        currentItemView.displayMutedVideoTooltip()
                    }
                } else {
                    switch self.audioMode {
                    case .off, .ambient:
                        break
                    case .on:
                        return
                    }
                    self.audioMode = .on
                    
                    for (_, itemSetView) in self.visibleItemSetViews {
                        if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                            componentView.leaveAmbientMode()
                        }
                    }
                    
                    self.state?.updated(transition: .immediate)
                }
            }
            self.volumeButtonsListener = VolumeButtonsListener(
                sharedContext: component.context.sharedContext,
                isCameraSpecific: false,
                shouldBeActive: self.volumeButtonsListenerShouldBeActive.get(),
                upPressed: buttonAction,
                downPressed: buttonAction
            )
        }
        
        private var previousBackNavigationTime: Double?
        private func navigate(direction: StoryItemSetContainerComponent.NavigationDirection) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() as? StoryContainerScreen else {
                return
            }
            
            if let stateValue = self.stateValue, let slice = stateValue.slice {
                if case .next = direction, slice.nextItemId == nil, (slice.item.position == nil || slice.item.position == slice.totalCount - 1) {
                    if stateValue.nextSlice == nil {
                        controller.dismiss()
                    } else {
                        self.beginHorizontalPan(translation: CGPoint())
                        self.updateHorizontalPan(translation: CGPoint())
                        self.commitHorizontalPan(velocity: CGPoint(x: -200.0, y: 0.0))
                    }
                } else if case .previous = direction, slice.previousItemId == nil {
                    if stateValue.previousSlice == nil {
                        if let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                            if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                if let customBackAction = controller.customBackAction {
                                    let currentTime = CACurrentMediaTime()
                                    if let previousBackNavigationTime = self.previousBackNavigationTime, currentTime - previousBackNavigationTime < 1.0 {
                                        customBackAction()
                                    } else {
                                        self.previousBackNavigationTime = CACurrentMediaTime()
                                        componentView.rewindCurrentItem()
                                    }
                                } else {
                                    componentView.rewindCurrentItem()
                                }
                            }
                        }
                    } else {
                        self.beginHorizontalPan(translation: CGPoint())
                        self.updateHorizontalPan(translation: CGPoint())
                        self.commitHorizontalPan(velocity: CGPoint(x: 200.0, y: 0.0))
                    }
                } else {
                    var mappedId: StoryId?
                    switch direction {
                    case .previous:
                        mappedId = slice.previousItemId
                    case .next:
                        mappedId = slice.nextItemId
                    case let .id(id):
                        mappedId = id
                    }
                    if let mappedId {
                        self.pendingNavigationToItemId = mappedId
                        component.content.navigate(navigation: .item(.id(mappedId)))
                    }
                }
            }
        }
        
        func presentExternalTooltip(_ tooltipScreen: UndoOverlayController) {
            guard let stateValue = self.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                return
            }
            itemSetComponentView.sendMessageContext.tooltipScreen = tooltipScreen
            itemSetComponentView.updateIsProgressPaused()
            
            self.environment?.controller()?.present(tooltipScreen, in: .current)
        }
        
        func update(component: StoryContainerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            if self.didAnimateOut {
                return availableSize
            }
            
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            if self.component == nil {
                self.areHeadphonesConnected = component.context.sharedContext.mediaManager.audioSession.getIsHeadsetPluggedIn()
                var update = false
                self.headphonesDisposable = (component.context.sharedContext.mediaManager.audioSession.headsetConnected()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    if self.areHeadphonesConnected != value {
                        self.areHeadphonesConnected = value
                        if update {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                })
                
                self.stealthModeDisposable = (component.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState()
                )
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    if self.stealthModeActiveUntilTimestamp != state.stealthModeState.activeUntilTimestamp {
                        self.stealthModeActiveUntilTimestamp = state.stealthModeState.activeUntilTimestamp
                        if update {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                })
                
                let accountManager = component.context.sharedContext.accountManager
                self.displayInteractionGuideDisposable = (ApplicationSpecificNotice.displayStoryInteractionGuide(accountManager: accountManager)
                |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    if !value {
                        self.isDisplayingInteractionGuide = true
                        if update {
                            self.state?.updated(transition: .immediate)
                        }
                        
                        let _ = ApplicationSpecificNotice.setDisplayStoryInteractionGuide(accountManager: accountManager).startStandalone()
                    }
                })
                
                update = true
            }
            
            if self.component?.content !== component.content {
                if self.component == nil {
                    var update = false
                    let _ = (allowedStoryReactions(context: component.context)
                    |> deliverOnMainQueue).start(next: { [weak self] reactionItems in
                        guard let self else {
                            return
                        }
                        
                        self.availableReactions = StoryAvailableReactions(reactionItems: reactionItems)
                        if update {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                    update = true
                    
                    self.inputMediaNodeDataPromise.set(
                        ChatEntityKeyboardInputNode.inputData(
                            context: component.context,
                            chatPeerId: nil,
                            areCustomEmojiEnabled: true,
                            hasTrending: true,
                            hasSearch: true,
                            hideBackground: true,
                            sendGif: nil
                        )
                    )
                    
                    self.closeFriendsPromise.set(
                        component.context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.CloseFriends())
                    )
                    
                    self.blockedPeers = BlockedPeersContext(account: component.context.account, subject: .stories)
                }
                
                var update = false
                
                let contentUpdated: (StoryContainerScreenComponent) -> Void = { [weak self] component in
                    guard let self else {
                        return
                    }
                    if self.isAnimatingOut || self.didAnimateOut {
                        return
                    }
                    
                    let stateValue = component.content.stateValue
                    
                    var focusedItemId: StoryId?
                    var isVideo = false
                    if let slice = stateValue?.slice {
                        focusedItemId = StoryId(peerId: slice.peer.id, id: slice.item.storyItem.id)
                        if case .file = slice.item.storyItem.media {
                            isVideo = true
                        }
                    }
                    self.focusedItem.set(focusedItemId)
                    self.contentWantsVolumeButtonMonitoring.set(isVideo)
                    
                    var hasItems = false
                    if let stateValue {
                        if stateValue.slice != nil {
                            hasItems = true
                        }
                    }
                    
                    if !hasItems {
                        self.dismissWithoutTransitionOut = true
                        environment.controller()?.dismiss()
                    } else {
                        self.stateValue = stateValue
                        
                        if update {
                            if self.stateValue?.slice == nil {
                                self.environment?.controller()?.dismiss()
                            } else {
                                if !self.isUpdating {
                                    self.state?.updated(transition: .immediate)
                                }
                            }
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    }
                }
                
                self.contentUpdatedDisposable?.dispose()
                self.stateValue = component.content.stateValue
                self.contentUpdatedDisposable = (component.content.updated
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    contentUpdated(component)
                })
                if component.content.stateValue?.slice != nil {
                    contentUpdated(component)
                }
                update = true
            }
            
            self.component = component
            self.state = state
            
            var stealthModeTimeout: Int32?
            if let stealthModeActiveUntilTimestamp = self.stealthModeActiveUntilTimestamp {
                let timestamp = Int32(Date().timeIntervalSince1970)
                if stealthModeActiveUntilTimestamp > timestamp {
                    stealthModeTimeout = stealthModeActiveUntilTimestamp - timestamp
                    
                    if self.stealthModeTimer == nil {
                        self.stealthModeTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                            self?.state?.updated(transition: .immediate)
                        })
                    }
                } else {
                    stealthModeTimeout = nil
                    if let stealthModeTimer = self.stealthModeTimer {
                        self.stealthModeTimer = nil
                        stealthModeTimer.invalidate()
                    }
                }
            } else {
                stealthModeTimeout = nil
                if let stealthModeTimer = self.stealthModeTimer {
                    self.stealthModeTimer = nil
                    stealthModeTimer.invalidate()
                }
            }
            
            if let pendingNavigationToItemId = self.pendingNavigationToItemId {
                if let slice = self.stateValue?.slice, slice.peer.id == pendingNavigationToItemId.peerId {
                    if slice.item.storyItem.id == pendingNavigationToItemId.id {
                        self.pendingNavigationToItemId = nil
                    }
                } else {
                    self.pendingNavigationToItemId = nil
                }
            }
            
            transition.setFrame(view: self.transitionCloneMasterView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.backgroundEffectView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            if case .regular = environment.metrics.widthClass {
                self.backgroundLayer.isHidden = true
                self.backgroundEffectView.update(size: availableSize, transition: transition.containedViewLayoutTransition)
                self.insertSubview(self.backgroundEffectView, at: 0)
                
            } else {
                self.backgroundLayer.isHidden = false
                self.backgroundEffectView.removeFromSuperview()
            }
            
            var isProgressPaused = false
            if self.itemSetPanState != nil {
                isProgressPaused = true
            }
            if self.isAnimatingOut {
                isProgressPaused = true
            }
            if self.isHoldingTouch {
                isProgressPaused = true
            }
            if !environment.isVisible {
                isProgressPaused = true
            }
            if self.pendingNavigationToItemId != nil {
                isProgressPaused = true
            }
            if self.isDisplayingInteractionGuide {
                isProgressPaused = true
            }
            
            var contentDerivedBottomInset: CGFloat = environment.safeInsets.bottom
            
            var validIds: [AnyHashable] = []
            
            var currentSlices: [StoryContentContextState.FocusedSlice] = []
            var focusedIndex: Int?
            if let stateValue = self.stateValue {
                if let previousSlice = stateValue.previousSlice {
                    currentSlices.append(previousSlice)
                }
                if let slice = stateValue.slice {
                    focusedIndex = currentSlices.count
                    currentSlices.append(slice)
                }
                if let nextSlice = stateValue.nextSlice {
                    currentSlices.append(nextSlice)
                }
            }
            
            var dismissPanOffset: CGFloat = 0.0
            if self.isDismissedExlusively {
                dismissPanOffset = availableSize.height
            }
            
            var centerDismissFraction: CGFloat = 0.0
            
            var presentationContextInsets = UIEdgeInsets()
            if !currentSlices.isEmpty, let focusedIndex {
                for i in max(0, focusedIndex - 1) ... min(focusedIndex + 1, currentSlices.count - 1) {
                    var isItemVisible = false
                    if i == focusedIndex {
                        isItemVisible = true
                    }
                    
                    let slice = currentSlices[i]
                    
                    let cubeAdditionalRotationFraction: CGFloat
                    if i == focusedIndex {
                        cubeAdditionalRotationFraction = 0.0
                    } else if i < focusedIndex {
                        cubeAdditionalRotationFraction = -1.0
                    } else {
                        cubeAdditionalRotationFraction = 1.0
                    }
                    
                    var panFraction: CGFloat = 0.0
                    if let itemSetPanState = self.itemSetPanState {
                        panFraction = -itemSetPanState.fraction
                        
                        if self.visibleItemSetViews[slice.peer.id] != nil {
                            isItemVisible = true
                        }
                        if itemSetPanState.fraction < 0.0 && i == focusedIndex - 1 {
                            isItemVisible = true
                        }
                        if itemSetPanState.fraction > 0.0 && i == focusedIndex + 1 {
                            isItemVisible = true
                        }
                    }
                    
                    if self.didAnimateIn && self.itemSetPanState == nil {
                        if i == focusedIndex - 1 {
                            isItemVisible = true
                        }
                        if i == focusedIndex + 1 {
                            isItemVisible = true
                        }
                    }
                    
                    if isItemVisible {
                        validIds.append(slice.peer.id)
                        
                        let itemSetView: ItemSetView
                        var itemSetTransition = transition
                        if let current = self.visibleItemSetViews[slice.peer.id] {
                            itemSetView = current
                        } else {
                            itemSetTransition = transition.withAnimation(.none).withUserData(StoryItemSetContainerComponent.TransitionHint(
                                allowSynchronousLoads: !self.visibleItemSetViews.isEmpty
                            ))
                            itemSetView = ItemSetView()
                            self.visibleItemSetViews[slice.peer.id] = itemSetView
                        }
                        
                        var itemSetContainerSize = availableSize
                        var itemSetContainerInsets = UIEdgeInsets(top: environment.statusBarHeight + 5.0, left: 0.0, bottom: 0.0, right: 0.0)
                        var itemSetContainerSafeInsets = environment.safeInsets
                        if case .regular = environment.metrics.widthClass {
                            let availableHeight = min(1080.0, availableSize.height - max(45.0, environment.safeInsets.bottom) * 2.0)
                            let mediaHeight = availableHeight - 60.0
                            let mediaWidth = floor(mediaHeight * 0.5625)
                            itemSetContainerSize = CGSize(width: mediaWidth, height: availableHeight)
                            itemSetContainerInsets.top = 0.0
                            itemSetContainerInsets.bottom = floorToScreenPixels((availableSize.height - itemSetContainerSize.height) / 2.0)
                            itemSetContainerSafeInsets.bottom = 0.0
                            
                            presentationContextInsets.left =  floorToScreenPixels((availableSize.width - itemSetContainerSize.width) / 2.0)
                            presentationContextInsets.right = presentationContextInsets.left
                            presentationContextInsets.bottom = itemSetContainerInsets.bottom
                        }
                        
                        itemSetView.view.parentState = self.state
                        
                        let _ = itemSetView.view.update(
                            transition: itemSetTransition,
                            component: AnyComponent(StoryItemSetContainerComponent(
                                context: component.context,
                                externalState: itemSetView.externalState,
                                storyItemSharedState: self.storyItemSharedState,
                                availableReactions: self.availableReactions,
                                slice: slice,
                                theme: environment.theme,
                                strings: environment.strings,
                                containerInsets: itemSetContainerInsets,
                                safeInsets: itemSetContainerSafeInsets,
                                statusBarHeight: environment.statusBarHeight,
                                inputHeight: environment.inputHeight,
                                metrics: environment.metrics,
                                deviceMetrics: environment.deviceMetrics,
                                isProgressPaused: isProgressPaused || i != focusedIndex,
                                isAudioMuted: self.audioMode == .off || (self.audioMode == .ambient && !(self.isMuteSwitchOn || self.areHeadphonesConnected)),
                                audioMode: self.audioMode,
                                hideUI: (i == focusedIndex && (self.itemSetPanState?.didBegin == false || self.itemSetPinchState != nil)),
                                visibilityFraction: 1.0 - abs(panFraction + cubeAdditionalRotationFraction),
                                isPanning: self.itemSetPanState?.didBegin == true,
                                pinchState: self.itemSetPinchState,
                                presentController: { [weak self] c, a in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    if c is UndoOverlayController || c is TooltipScreen {
                                        environment.controller()?.present(c, in: .current)
                                    } else {
                                        environment.controller()?.present(c, in: .window(.root), with: a)
                                    }
                                },
                                presentInGlobalOverlay: { [weak self] c, a in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    environment.controller()?.presentInGlobalOverlay(c, with: a)
                                },
                                close: { [weak self] in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    environment.controller()?.dismiss()
                                },
                                navigate: { [weak self] direction in
                                    guard let self else {
                                        return
                                    }
                                    
                                    self.navigate(direction: direction)
                                },
                                delete: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    if let stateValue = self.stateValue, let slice = stateValue.slice {
                                        if slice.nextItemId != nil {
                                            component.content.navigate(navigation: .item(.next))
                                        } else if slice.previousItemId != nil {
                                            component.content.navigate(navigation: .item(.previous))
                                        } else if let environment = self.environment {
                                            if let sourceIsAvatar = component.transitionIn?.sourceIsAvatar, sourceIsAvatar {
                                            } else {
                                                self.dismissWithoutTransitionOut = true
                                            }
                                            environment.controller()?.dismiss()
                                        }
                                        
                                        if case let .user(user) = slice.peer, user.botInfo != nil {
                                            //TODO:release
                                            let _ = component.context.engine.messages.deleteBotPreviews(peerId: slice.peer.id, language: nil, media: [slice.item.storyItem.media._asMedia()]).startStandalone()
                                        } else {
                                            let _ = component.context.engine.messages.deleteStories(peerId: slice.peer.id, ids: [slice.item.storyItem.id]).startStandalone()
                                        }
                                    }
                                },
                                markAsSeen: { [weak self] id in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.content.markAsSeen(id: id)
                                },
                                reorder: { [weak self] in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    var performReorderAction: (() -> Void)?
                                    if let controller = environment.controller() as? StoryContainerScreen {
                                        performReorderAction = controller.performReorderAction
                                    }
                                    environment.controller()?.dismiss(completion: {
                                        performReorderAction?()
                                    })
                                },
                                controller: { [weak self] in
                                    return self?.environment?.controller()
                                },
                                toggleAmbientMode: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    
                                    switch self.audioMode {
                                    case .ambient:
                                        if self.isMuteSwitchOn || self.areHeadphonesConnected {
                                            self.audioMode = .off
                                            
                                            for (_, itemSetView) in self.visibleItemSetViews {
                                                if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                                    componentView.enterAmbientMode(ambient: !(self.isMuteSwitchOn || self.areHeadphonesConnected))
                                                }
                                            }
                                        } else {
                                            self.audioMode = .on
                                            
                                            for (_, itemSetView) in self.visibleItemSetViews {
                                                if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                                    componentView.leaveAmbientMode()
                                                }
                                            }
                                        }
                                    case .on:
                                        self.audioMode = .off
                                        for (_, itemSetView) in self.visibleItemSetViews {
                                            if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                                componentView.enterAmbientMode(ambient: !(self.isMuteSwitchOn || self.areHeadphonesConnected))
                                            }
                                        }
                                    case .off:
                                        self.audioMode = .on
                                        for (_, itemSetView) in self.visibleItemSetViews {
                                            if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                                componentView.leaveAmbientMode()
                                            }
                                        }
                                    }
                                    
                                    self.state?.updated(transition: .immediate)
                                },
                                keyboardInputData: self.inputMediaNodeDataPromise.get(),
                                closeFriends: self.closeFriendsPromise,
                                blockedPeers: self.blockedPeers,
                                sharedViewListsContext: self.sharedViewListsContext,
                                stealthModeTimeout: stealthModeTimeout,
                                isDismissed: self.isDismissedExlusively
                            )),
                            environment: {},
                            containerSize: itemSetContainerSize
                        )
                        
                        if i == focusedIndex {
                            contentDerivedBottomInset = itemSetView.externalState.derivedBottomInset
                            centerDismissFraction = itemSetView.externalState.dismissFraction
                        }
                        
                        let itemFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - itemSetContainerSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - itemSetContainerSize.height) / 2.0)), size: itemSetContainerSize)
                        if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                            if itemSetView.superview == nil {
                                self.addSubview(itemSetView)
                                //print("init time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                            }
                            if itemSetComponentView.superview == nil {
                                itemSetView.tintLayer.isDoubleSided = false
                                itemSetComponentView.layer.isDoubleSided = false
                                itemSetView.addSubview(itemSetComponentView)
                                itemSetView.layer.addSublayer(itemSetView.tintLayer)
                                
                                self.transitionCloneMasterView.addSubview(itemSetComponentView.transitionCloneContainerView)
                            }
                            
                            itemSetTransition.setPosition(view: itemSetView, position: itemFrame.center.offsetBy(dx: 0.0, dy: dismissPanOffset))
                            itemSetTransition.setBounds(view: itemSetView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            itemSetTransition.setPosition(view: itemSetComponentView, position: CGRect(origin: CGPoint(), size: itemFrame.size).center)
                            itemSetTransition.setBounds(view: itemSetComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            let itemTintSize: CGSize
                            if case .regular = environment.metrics.widthClass {
                                itemTintSize = itemSetView.externalState.derivedMediaSize
                            } else {
                                itemTintSize = itemFrame.size
                            }
                            
                            itemSetTransition.setPosition(layer: itemSetView.tintLayer, position: CGRect(origin: CGPoint(), size: itemTintSize).center)
                            itemSetTransition.setBounds(layer: itemSetView.tintLayer, bounds: CGRect(origin: CGPoint(), size: itemTintSize))
                            
                            let perspectiveConstant: CGFloat = 500.0
                            let width = itemFrame.width
                            
                            let sideDistance: CGFloat
                            if case .regular = environment.metrics.widthClass {
                                sideDistance = 0.0
                            } else {
                                sideDistance = 40.0
                            }
                            
                            let sideAngle_d: CGFloat = -pow(perspectiveConstant, 2)*pow(sideDistance, 2)
                            let sideAngle_e: CGFloat = pow(perspectiveConstant, 2)*pow(width, 2)
                            let sideAngle_f: CGFloat = pow(sideDistance, 2)*pow(width, 2)
                            let sideAngle_c: CGFloat = sqrt(sideAngle_d + sideAngle_e + sideAngle_f + sideDistance*pow(width, 3) + 0.25*pow(width, 4))
                            let sideAngle_a: CGFloat = (2.0*perspectiveConstant*width - 2.0*sideAngle_c)
                            let sideAngle_b: CGFloat = (-2.0*perspectiveConstant*sideDistance + 2.0*sideDistance*width + pow(width, 2))
                            
                            let sideAngle: CGFloat = 2.0*atan(sideAngle_a / sideAngle_b)
                            
                            let faceTransform = CATransform3DMakeTranslation(0, 0, itemFrame.width * 0.5)
                            
                            func calculateCubeTransform(rotationFraction: CGFloat, sideAngle: CGFloat, cubeSize: CGSize) -> CATransform3D {
                                let t = rotationFraction
                                let absT = abs(rotationFraction)
                                let currentAngle = t * (CGFloat.pi * 0.5 + sideAngle)
                                let width = cubeSize.width
                                
                                let cubeDistance_a: CGFloat = -1.4142135623731*absT*cos(sideAngle + 0.785398163397448)
                                let cubeDistance_b: CGFloat = sin(sideAngle*absT + 1.5707963267949*absT + 0.785398163397448)
                                var cubeDistance: CGFloat = 0.5*width*(cubeDistance_a + absT + 1.4142135623731*cubeDistance_b - 1.0)
                                cubeDistance *= 1.0
                                
                                let backDistance_a = sqrt(pow(width, 2.0))
                                let backDistance_b = tan(sideAngle) / 2.0
                                let backDistance_c = sqrt(pow(width, 2.0))
                                let backDistance_d = (2*cos(sideAngle))
                                let backDistance: CGFloat = width / 2.0 + backDistance_a * backDistance_b - backDistance_c / backDistance_d
                                
                                var perspective = CATransform3DIdentity
                                perspective.m34 = -1 / perspectiveConstant
                                let initialCubeTransform = CATransform3DTranslate(perspective, 0.0, 0.0, -cubeSize.width * 0.5)
                                
                                var targetTransform = initialCubeTransform
                                targetTransform = CATransform3DTranslate(targetTransform, 0.0, 0.0, -cubeDistance + backDistance)
                                targetTransform = CATransform3DConcat(CATransform3DMakeRotation(currentAngle, 0, 1, 0), targetTransform)
                                targetTransform = CATransform3DTranslate(targetTransform, 0.0, 0.0, -backDistance)
                                
                                return targetTransform
                            }
                                                        
                            ComponentTransition.immediate.setTransform(view: itemSetComponentView, transform: faceTransform)
                            ComponentTransition.immediate.setTransform(layer: itemSetView.tintLayer, transform: faceTransform)
                            
                            if let previousRotationFraction = itemSetView.rotationFraction, !itemSetTransition.animation.isImmediate {
                                let fromT = previousRotationFraction
                                let toT = panFraction + cubeAdditionalRotationFraction
                                itemSetTransition.setTransformAsKeyframes(view: itemSetView, transform: { sourceT, isFinal in
                                    let t = fromT * (1.0 - sourceT) + toT * sourceT
                                    if isFinal {
                                        if abs(t - 0.0) <= 0.0001 {
                                            return CATransform3DIdentity
                                        }
                                    }
                                    
                                    return calculateCubeTransform(rotationFraction: t, sideAngle: sideAngle, cubeSize: itemFrame.size)
                                })
                            } else {
                                let updatedTransform: CATransform3D
                                if abs(panFraction + cubeAdditionalRotationFraction) <= 0.0001 {
                                    updatedTransform = CATransform3DIdentity
                                } else {
                                    updatedTransform = calculateCubeTransform(rotationFraction: panFraction + cubeAdditionalRotationFraction, sideAngle: sideAngle, cubeSize: itemFrame.size)
                                }
                                itemSetTransition.setTransform(view: itemSetView, transform: updatedTransform)
                            }
                            itemSetView.rotationFraction = panFraction + cubeAdditionalRotationFraction
                            
                            var alphaFraction = panFraction + cubeAdditionalRotationFraction
                            
                            if alphaFraction != 0.0 {
                                if alphaFraction < 0.0 {
                                    itemSetView.tintLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                                    itemSetView.tintLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
                                } else {
                                    itemSetView.tintLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
                                    itemSetView.tintLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                                }
                            }
                            
                            alphaFraction *= 1.3
                            alphaFraction = max(-1.0, min(1.0, alphaFraction))
                            alphaFraction = abs(alphaFraction)
                                                        
                            itemSetTransition.setAlpha(layer: itemSetView.tintLayer, alpha: alphaFraction)
                        }
                    }
                }
            }
            var removedIds: [EnginePeer.Id] = []
            for (id, itemSetView) in self.visibleItemSetViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemSetView.view.parentState = nil
                    itemSetView.removeFromSuperview()
                    
                    if let view = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        view.saveDraft()
                        view.transitionCloneContainerView.removeFromSuperview()
                    }
                }
            }
            for id in removedIds {
                self.visibleItemSetViews.removeValue(forKey: id)
            }
            
            let dismissAlphaScale = 1.0 * (1.0 - centerDismissFraction) + 0.2 * centerDismissFraction
            transition.setAlpha(layer: self.backgroundLayer, alpha: max(0.5, min(1.0, dismissAlphaScale)))
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: environment.statusBarHeight, left: 0.0, bottom: contentDerivedBottomInset + presentationContextInsets.bottom, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: presentationContextInsets.left, bottom: 0.0, right: presentationContextInsets.right),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            if self.isDisplayingInteractionGuide {
                let _ = self.interactionGuide.update(
                    transition: .immediate,
                    component: AnyComponent(
                        StoryInteractionGuideComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            action: { [weak self] in
                                self?.isDisplayingInteractionGuide = false
                                self?.state?.updated()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.interactionGuide.view as? StoryInteractionGuideComponent.View {
                    if view.superview == nil {
                        self.addSubview(view)
                        
                        view.animateIn()
                    }
                    view.layer.zPosition = 1000.0
                    view.frame = CGRect(origin: .zero, size: availableSize)
                }
            } else if let view = self.interactionGuide.view as? StoryInteractionGuideComponent.View, view.superview != nil {
                view.animateOut(completion: {
                    view.removeFromSuperview()
                })
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StoryContainerScreen: ViewControllerComponentContainer {
    public struct TransitionState: Equatable {
        public var sourceSize: CGSize
        public var destinationSize: CGSize
        public var progress: CGFloat
        
        public init(
            sourceSize: CGSize,
            destinationSize: CGSize,
            progress: CGFloat
        ) {
            self.sourceSize = sourceSize
            self.destinationSize = destinationSize
            self.progress = progress
        }
    }
    
    public final class TransitionView {
        public let makeView: () -> UIView
        public let updateView: (UIView, TransitionState, ComponentTransition) -> Void
        public let insertCloneTransitionView: ((UIView) -> Void)?
        
        public init(
            makeView: @escaping () -> UIView,
            updateView: @escaping (UIView, TransitionState, ComponentTransition) -> Void,
            insertCloneTransitionView: ((UIView) -> Void)?
        ) {
            self.makeView = makeView
            self.updateView = updateView
            self.insertCloneTransitionView = insertCloneTransitionView
        }
    }
    
    public final class TransitionIn {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceCornerRadius: CGFloat
        public let sourceIsAvatar: Bool
        
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceCornerRadius: CGFloat,
            sourceIsAvatar: Bool
        ) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.sourceCornerRadius = sourceCornerRadius
            self.sourceIsAvatar = sourceIsAvatar
        }
    }
    
    public final class TransitionOut {
        public weak var destinationView: UIView?
        public let transitionView: TransitionView?
        public let destinationRect: CGRect
        public let destinationCornerRadius: CGFloat
        public let destinationIsAvatar: Bool
        public let completed: () -> Void
        
        public init(
            destinationView: UIView,
            transitionView: TransitionView?,
            destinationRect: CGRect,
            destinationCornerRadius: CGFloat,
            destinationIsAvatar: Bool,
            completed: @escaping () -> Void
        ) {
            self.destinationView = destinationView
            self.transitionView = transitionView
            self.destinationRect = destinationRect
            self.destinationCornerRadius = destinationCornerRadius
            self.destinationIsAvatar = destinationIsAvatar
            self.completed = completed
        }
    }
    
    private let context: AccountContext
    private var didAnimateIn: Bool = false
    private var isDismissed: Bool = false
    
    private let focusedItemPromise = Promise<StoryId?>()
    public var focusedItem: Signal<StoryId?, NoError> {
        return self.focusedItemPromise.get()
    }
    
    public var customBackAction: (() -> Void)?
    public var performReorderAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        content: StoryContentContext,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id, AnyHashable) -> TransitionOut?
    ) {
        self.context = context
        
        super.init(context: context, component: StoryContainerScreenComponent(
            context: context,
            content: content,
            focusedItemPromise: self.focusedItemPromise,
            transitionIn: transitionIn,
            transitionOut: transitionOut
        ), navigationBarAppearance: .none, theme: .dark)
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .standaloneFlatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: [.portrait])
        
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(true))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(false))
        self.focusedItemPromise.set(.single(nil))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didAnimateIn {
            self.didAnimateIn = true
            
            if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    public func presentExternalTooltip(_ tooltipScreen: UndoOverlayController) {
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.presentExternalTooltip(tooltipScreen)
        }
    }
    
    func dismissWithoutTransitionOut(completion: (() -> Void)? = nil) {
        self.focusedItemPromise.set(.single(nil))
        
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.dismissWithoutTransitionOut = true
        }
        self.dismiss(completion: completion)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
            
            if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
                componentView.endEditing(true)
                
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                completion?()
                self.dismiss(animated: false)
            }
        }
    }
}

func allowedStoryReactions(context: AccountContext) -> Signal<[ReactionItem], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudTopReactions)
    let topReactions = context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> [RecentReactionItem] in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return view.items.compactMap { item -> RecentReactionItem? in
            return item.contents.get(RecentReactionItem.self)
        }
    }

    return combineLatest(
        context.engine.stickers.availableReactions(),
        topReactions
    )
    |> take(1)
    |> map { availableReactions, topReactions -> [ReactionItem] in
        guard let availableReactions = availableReactions else {
            return []
        }
        
        var result: [ReactionItem] = []
        
        var existingIds = Set<MessageReaction.Reaction>()
        
        for topReaction in topReactions {
            switch topReaction.content {
            case let .builtin(value):
                if let reaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if existingIds.contains(reaction.value) {
                        continue
                    }
                    existingIds.insert(reaction.value)
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ))
                } else {
                    continue
                }
            case let .custom(file):
                if existingIds.contains(.custom(file.fileId.id)) {
                    continue
                }
                existingIds.insert(.custom(file.fileId.id))
                
                result.append(ReactionItem(
                    reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                    appearAnimation: file,
                    stillAnimation: file,
                    listAnimation: file,
                    largeListAnimation: file,
                    applicationAnimation: nil,
                    largeApplicationAnimation: nil,
                    isCustom: true
                ))
            case .stars:
                break
            }
        }
        
        for reaction in availableReactions.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            if !reaction.isEnabled {
                continue
            }
            
            if existingIds.contains(reaction.value) {
                continue
            }
            existingIds.insert(reaction.value)
            
            result.append(ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ))
        }

        return result
    }
}
