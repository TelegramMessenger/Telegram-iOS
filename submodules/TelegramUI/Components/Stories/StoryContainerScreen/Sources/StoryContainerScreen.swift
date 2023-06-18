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

private final class StoryLongPressRecognizer: UILongPressGestureRecognizer {
    var updateIsTracking: ((Bool) -> Void)?
    
    override var state: UIGestureRecognizer.State {
        didSet {
            switch self.state {
            case .began, .cancelled, .ended, .failed:
                if self.isTracking {
                    self.isTracking = false
                    self.updateIsTracking?(false)
                }
            default:
                break
            }
        }
    }
    
    private var isTracking: Bool = false
    
    override func reset() {
        super.reset()
        
        if self.isTracking {
            self.isTracking = false
            self.updateIsTracking?(false)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if !self.isTracking {
            self.isTracking = true
            self.updateIsTracking?(true)
        }
    }
}

private final class StoryContainerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let content: StoryContentContext
    let focusedItemPromise: Promise<StoryId?>
    let transitionIn: StoryContainerScreen.TransitionIn?
    let transitionOut: (EnginePeer.Id, AnyHashable) -> StoryContainerScreen.TransitionOut?
    
    init(
        context: AccountContext,
        content: StoryContentContext,
        focusedItemPromise: Promise<StoryId?>,
        transitionIn: StoryContainerScreen.TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id, AnyHashable) -> StoryContainerScreen.TransitionOut?
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
    

    final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var component: StoryContainerScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private let backgroundLayer: SimpleLayer
        private let backgroundEffectView: BlurredBackgroundView
        
        private let focusedItem = ValuePromise<StoryId?>(nil, ignoreRepeated: true)
        private var contentUpdatedDisposable: Disposable?
        
        private let storyItemSharedState = StoryContentItem.SharedState()
        private var visibleItemSetViews: [EnginePeer.Id: ItemSetView] = [:]
        
        private var itemSetPinchState: StoryItemSetContainerComponent.PinchState?
        private var itemSetPanState: ItemSetPanState?
        private var verticalPanState: ItemSetPanState?
        private var isHoldingTouch: Bool = false
        
        private var isAnimatingOut: Bool = false
        private var didAnimateOut: Bool = false
        
        var dismissWithoutTransitionOut: Bool = false
        
        override init(frame: CGRect) {
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.backgroundColor = UIColor.black.cgColor
            self.backgroundLayer.zPosition = -1000.0
            
            self.backgroundEffectView = BlurredBackgroundView(color: UIColor(rgb: 0x000000, alpha: 0.9), enableBlur: true)
            self.backgroundEffectView.layer.zPosition = -1001.0
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            
            let horizontalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return []
                }
                if !itemSetComponentView.isPointInsideContentArea(point: self.convert(point, to: itemSetComponentView)) {
                    return []
                }
                if !itemSetComponentView.allowsInteractiveGestures() {
                    return []
                }
                return [.left, .right]
            })
            self.addGestureRecognizer(horizontalPanRecognizer)
            
            let verticalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.dismissPanGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return []
                }
                if !itemSetComponentView.isPointInsideContentArea(point: self.convert(point, to: itemSetComponentView)) {
                    return []
                }
                if !itemSetComponentView.allowsInteractiveGestures() {
                    return []
                }
                
                return [.down]
            })
            self.addGestureRecognizer(verticalPanRecognizer)
            
            let longPressRecognizer = StoryLongPressRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
            longPressRecognizer.delegate = self
            longPressRecognizer.updateIsTracking = { [weak self] isTracking in
                guard let self else {
                    return
                }
                self.isHoldingTouch = isTracking
                self.state?.updated(transition: .immediate)
            }
            self.addGestureRecognizer(longPressRecognizer)
            
            let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchGesture(_:)))
            self.addGestureRecognizer(pinchRecognizer)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.backgroundEffectView.addGestureRecognizer(tapGestureRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentUpdatedDisposable?.dispose()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                return false
            }
            
            if !itemSetComponentView.isPointInsideContentArea(point: touch.location(in: itemSetComponentView)) {
                return false
            }
            
            return true
        }
        
        private func beginHorizontalPan(translation: CGPoint) {
            if self.layer.animation(forKey: "panState") != nil {
                self.layer.removeAnimation(forKey: "panState")
            }
            
            let updateImmediately = abs(translation.x) > 0.0
            
            if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                if !updateImmediately {
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                }
            } else {
                self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                if !updateImmediately {
                    self.state?.updated(transition: .immediate)
                }
            }
            
            if updateImmediately {
                self.updateHorizontalPan(translation: translation)
            }
        }
        
        private func updateHorizontalPan(translation: CGPoint) {
            var translation = translation
            
            if var itemSetPanState = self.itemSetPanState, self.bounds.width > 0.0, let component = self.component, let stateValue = component.content.stateValue, let _ = stateValue.slice {
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
                
                self.state?.updated(transition: .immediate)
            }
        }
        
        private func commitHorizontalPan(velocity: CGPoint) {
            if var itemSetPanState = self.itemSetPanState {
                if let component = self.component, let stateValue = component.content.stateValue, let _ = stateValue.slice {
                    var direction: StoryContentContextNavigation.Direction?
                    if abs(velocity.x) > 10.0 {
                        if velocity.x < 0.0 {
                            if stateValue.nextSlice != nil {
                                direction = .next
                            }
                        } else {
                            if stateValue.previousSlice != nil {
                                direction = .previous
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
                        self.state?.updated(transition: .immediate)
                    }
                }
                
                itemSetPanState.fraction = 0.0
                self.itemSetPanState = itemSetPanState
                
                let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
                self.state?.updated(transition: transition)
                
                transition.attachAnimation(view: self, id: "panState", completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    self.itemSetPanState = nil
                    self.state?.updated(transition: .immediate)
                    
                    /*if let component = self.component {
                        component.content.resetSideStates()
                    }*/
                })
            }
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.beginHorizontalPan(translation: recognizer.translation(in: self))
            case .changed:
                self.updateHorizontalPan(translation: recognizer.translation(in: self))
            case .cancelled, .ended:
                self.commitHorizontalPan(velocity: recognizer.velocity(in: self))
            default:
                break
            }
        }
        
        @objc private func dismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.verticalPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                self.state?.updated(transition: .immediate)
            case .changed:
                let translation = recognizer.translation(in: self)
                self.verticalPanState = ItemSetPanState(fraction: max(-1.0, min(1.0, translation.y / self.bounds.height)), didBegin: true)
                self.state?.updated(transition: .immediate)
            case .cancelled, .ended:
                let translation = recognizer.translation(in: self)
                let velocity = recognizer.velocity(in: self)
                
                self.verticalPanState = nil
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                
                if translation.y > 100.0 || velocity.y > 10.0 {
                    self.environment?.controller()?.dismiss()
                } else if translation.y < -100.0 || velocity.y < -40.0 {
                    if let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                        if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                            itemSetComponentView.activateInput()
                        }
                    }
                }
            default:
                break
            }
        }
        
        @objc private func longPressGesture(_ recognizer: StoryLongPressRecognizer) {
            switch recognizer.state {
            case .began:
                if self.itemSetPanState == nil {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: false)
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                }
            case .cancelled, .ended:
                if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                    self.itemSetPanState = nil
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                }
            default:
                break
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component, let environment = self.environment, let stateValue = component.content.stateValue, case .recognized = recognizer.state else {
                return
            }
        
            let location = recognizer.location(in: recognizer.view)
            if let currentItemView = self.visibleItemSetViews.first?.value {
                if location.x < currentItemView.frame.minX {
                    if stateValue.previousSlice == nil {
                            
                    } else {
                        self.beginHorizontalPan(translation: CGPoint())
                        self.commitHorizontalPan(velocity: CGPoint(x: 100.0, y: 0.0))
                    }
                } else if location.x > currentItemView.frame.maxX {
                    if stateValue.nextSlice == nil {
                        environment.controller()?.dismiss()
                    } else {
                        self.beginHorizontalPan(translation: CGPoint())
                        self.commitHorizontalPan(velocity: CGPoint(x: -100.0, y: 0.0))
                    }
                }
            }
        }
        
        @objc private func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                let location = recognizer.location(in: self)
                let scale = max(1.0, recognizer.scale)
                if let itemSetPinchState = self.itemSetPinchState {
                    let offset = CGPoint(x: location.x - itemSetPinchState.location.x , y: location.y - itemSetPinchState.location.y)
                    self.itemSetPinchState = StoryItemSetContainerComponent.PinchState(scale: scale, location: itemSetPinchState.location, offset: offset)
                } else {
                    self.itemSetPinchState = StoryItemSetContainerComponent.PinchState(scale: scale, location: location, offset: .zero)
                }
                self.state?.updated(transition: .immediate)
            case .cancelled, .ended:
                self.itemSetPinchState = nil
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
            default:
                break
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.isHidden || subview.alpha == 0.0 {
                    continue
                }
                
                if subview is ItemSetView {
                    if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                        return result
                    }
                } else {
                    if let result = subview.hitTest(self.convert(self.convert(point, to: subview), to: subview), with: event) {
                        return result
                    }
                }
            }
            
            return nil
        }
        
        func animateIn() {
            if let component = self.component {
                component.focusedItemPromise.set(self.focusedItem.get())
            }
            
            if let transitionIn = self.component?.transitionIn, transitionIn.sourceView != nil {
                self.backgroundLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.28, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.backgroundEffectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.28, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                
                if let transitionIn = self.component?.transitionIn, let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                    if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        itemSetComponentView.animateIn(transitionIn: transitionIn)
                    }
                }
            } else {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] _ in
                    self?.layer.allowsGroupOpacity = false
                })
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.isAnimatingOut = true
            
            if !self.dismissWithoutTransitionOut, let component = self.component, let stateValue = component.content.stateValue, let slice = stateValue.slice, let itemSetView = self.visibleItemSetViews[slice.peer.id], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View, let transitionOut = component.transitionOut(slice.peer.id, slice.item.id) {
                self.state?.updated(transition: .immediate)
                
                let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                transition.setAlpha(layer: self.backgroundLayer, alpha: 0.0)
                transition.setAlpha(view: self.backgroundEffectView, alpha: 0.0)
                
                let transitionOutCompleted = transitionOut.completed
                let focusedItemPromise = component.focusedItemPromise
                itemSetComponentView.animateOut(transitionOut: transitionOut, completion: {
                    completion()
                    transitionOutCompleted()
                    focusedItemPromise.set(.single(nil))
                })
            } else {
                let transition: Transition
                if self.dismissWithoutTransitionOut {
                    transition = Transition(animation: .curve(duration: 0.5, curve: .spring))
                } else {
                    transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                
                self.verticalPanState = ItemSetPanState(fraction: 1.0, didBegin: true)
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
        
        private func updatePreloads() {
            /*var validIds: [AnyHashable] = []
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                for i in 0 ..< 2 {
                    var nextIndex: Int = currentIndex + 1 + i
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let nextItem = currentSlice.items[nextIndex]
                        
                        validIds.append(nextItem.id)
                        if self.preloadContexts[nextItem.id] == nil {
                            if let signal = nextItem.preload {
                                self.preloadContexts[nextItem.id] = signal.start()
                            }
                        }
                    }
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, disposable) in self.preloadContexts {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    disposable.dispose()
                }
            }
            for id in removeIds {
                self.preloadContexts.removeValue(forKey: id)
            }*/
        }
        
        func update(component: StoryContainerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            if self.didAnimateOut {
                return availableSize
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            if self.component?.content !== component.content {
                self.contentUpdatedDisposable?.dispose()
                var update = false
                self.contentUpdatedDisposable = (component.content.updated
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    if update {
                        var focusedItemId: StoryId?
                        if let slice = component.content.stateValue?.slice {
                            focusedItemId = StoryId(peerId: slice.peer.id, id: slice.item.storyItem.id)
                        }
                        self.focusedItem.set(focusedItemId)
                        
                        if component.content.stateValue?.slice == nil {
                            self.environment?.controller()?.dismiss()
                        } else {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                })
                update = true
            }
            
            self.component = component
            self.state = state
            
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
            if self.verticalPanState != nil {
                isProgressPaused = true
            }
            if self.isAnimatingOut {
                isProgressPaused = true
            }
            if self.isHoldingTouch {
                isProgressPaused = true
            }
            
            var dismissPanOffset: CGFloat = 0.0
            var dismissPanScale: CGFloat = 1.0
            var dismissAlphaScale: CGFloat = 1.0
            var verticalPanFraction: CGFloat = 0.0
            if let verticalPanState = self.verticalPanState {
                let dismissFraction = max(0.0, verticalPanState.fraction)
                verticalPanFraction = max(0.0, min(1.0, -verticalPanState.fraction))
                
                dismissPanOffset = dismissFraction * availableSize.height
                dismissPanScale = 1.0 * (1.0 - dismissFraction) + 0.6 * dismissFraction
                dismissAlphaScale = 1.0 * (1.0 - dismissFraction) + 0.2 * dismissFraction
            }
            
            transition.setAlpha(layer: self.backgroundLayer, alpha: max(0.5, dismissAlphaScale))
            
            var contentDerivedBottomInset: CGFloat = environment.safeInsets.bottom
            
            var validIds: [AnyHashable] = []
            
            var currentSlices: [StoryContentContextState.FocusedSlice] = []
            var focusedIndex: Int?
            if let component = self.component, let stateValue = component.content.stateValue {
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
                    
                    if isItemVisible {
                        validIds.append(slice.peer.id)
                        
                        let itemSetView: ItemSetView
                        var itemSetTransition = transition
                        if let current = self.visibleItemSetViews[slice.peer.id] {
                            itemSetView = current
                        } else {
                            itemSetTransition = .immediate
                            itemSetView = ItemSetView()
                            self.visibleItemSetViews[slice.peer.id] = itemSetView
                        }
                        
                        var itemSetContainerSize = availableSize
                        var itemSetContainerInsets = UIEdgeInsets(top: environment.statusBarHeight + 12.0, left: 0.0, bottom: 0.0, right: 0.0)
                        var itemSetContainerSafeInsets = environment.safeInsets
                        if case .regular = environment.metrics.widthClass {
                            let availableHeight = min(1080.0, availableSize.height - max(45.0, environment.safeInsets.bottom) * 2.0)
                            let mediaHeight = availableHeight - 40.0
                            let mediaWidth = floor(mediaHeight * 0.5625)
                            itemSetContainerSize = CGSize(width: mediaWidth, height: availableHeight)
                            itemSetContainerInsets.top = 0.0
                            itemSetContainerInsets.bottom = floorToScreenPixels((availableSize.height - itemSetContainerSize.height) / 2.0)
                            itemSetContainerSafeInsets.bottom = 0.0
                        }
                                                
                        let _ = itemSetView.view.update(
                            transition: itemSetTransition,
                            component: AnyComponent(StoryItemSetContainerComponent(
                                context: component.context,
                                externalState: itemSetView.externalState,
                                storyItemSharedState: self.storyItemSharedState,
                                slice: slice,
                                theme: environment.theme,
                                strings: environment.strings,
                                containerInsets: itemSetContainerInsets,
                                safeInsets: itemSetContainerSafeInsets,
                                inputHeight: environment.inputHeight,
                                metrics: environment.metrics,
                                isProgressPaused: isProgressPaused || i != focusedIndex,
                                hideUI: (i == focusedIndex && (self.itemSetPanState?.didBegin == false || self.itemSetPinchState != nil)),
                                visibilityFraction: 1.0 - abs(panFraction + cubeAdditionalRotationFraction),
                                isPanning: self.itemSetPanState?.didBegin == true,
                                verticalPanFraction: verticalPanFraction,
                                pinchState: self.itemSetPinchState,
                                presentController: { [weak self] c, a in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    if c is UndoOverlayController {
                                        environment.controller()?.present(c, in: .current)
                                    } else {
                                        environment.controller()?.present(c, in: .window(.root), with: a)
                                    }
                                },
                                close: { [weak self] in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    environment.controller()?.dismiss()
                                },
                                navigate: { [weak self] direction in
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    
                                    if let stateValue = component.content.stateValue, let slice = stateValue.slice {
                                        if case .next = direction, slice.nextItemId == nil {
                                            if stateValue.nextSlice == nil {
                                                environment.controller()?.dismiss()
                                            } else {
                                                self.beginHorizontalPan(translation: CGPoint())
                                                self.updateHorizontalPan(translation: CGPoint())
                                                self.commitHorizontalPan(velocity: CGPoint(x: -100.0, y: 0.0))
                                            }
                                        } else if case .previous = direction, slice.previousItemId == nil {
                                            if stateValue.previousSlice == nil {
                                                if let itemSetView = self.visibleItemSetViews[slice.peer.id] {
                                                    if let componentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                                                        componentView.rewindCurrentItem()
                                                    }
                                                }
                                            } else {
                                                self.beginHorizontalPan(translation: CGPoint())
                                                self.updateHorizontalPan(translation: CGPoint())
                                                self.commitHorizontalPan(velocity: CGPoint(x: 100.0, y: 0.0))
                                            }
                                        } else {
                                            let mappedDirection: StoryContentContextNavigation.Direction
                                            switch direction {
                                            case .previous:
                                                mappedDirection = .previous
                                            case .next:
                                                mappedDirection = .next
                                            }
                                            component.content.navigate(navigation: .item(mappedDirection))
                                        }
                                    }
                                },
                                delete: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    if let stateValue = component.content.stateValue, let slice = stateValue.slice {
                                        if slice.nextItemId != nil {
                                            component.content.navigate(navigation: .item(.next))
                                        } else if slice.previousItemId != nil {
                                            component.content.navigate(navigation: .item(.previous))
                                        } else if let environment = self.environment {
                                            environment.controller()?.dismiss()
                                        }
                                        
                                        let _ = component.context.engine.messages.deleteStories(ids: [slice.item.storyItem.id]).start()
                                    }
                                },
                                markAsSeen: { [weak self] id in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.content.markAsSeen(id: id)
                                },
                                controller: { [weak self] in
                                    return self?.environment?.controller()
                                }
                            )),
                            environment: {},
                            containerSize: itemSetContainerSize
                        )
                        
                        if i == focusedIndex {
                            contentDerivedBottomInset = itemSetView.externalState.derivedBottomInset
                        }
                        
                        let itemFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - itemSetContainerSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - itemSetContainerSize.height) / 2.0)), size: itemSetContainerSize)
                        if let itemSetComponentView = itemSetView.view.view {
                            if itemSetView.superview == nil {
                                self.addSubview(itemSetView)
                            }
                            if itemSetComponentView.superview == nil {
                                itemSetView.tintLayer.isDoubleSided = false
                                itemSetComponentView.layer.isDoubleSided = false
                                itemSetView.addSubview(itemSetComponentView)
                                itemSetView.layer.addSublayer(itemSetView.tintLayer)
                            }
                            
                            itemSetTransition.setPosition(view: itemSetView, position: itemFrame.center.offsetBy(dx: 0.0, dy: dismissPanOffset))
                            itemSetTransition.setBounds(view: itemSetView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            itemSetTransition.setSublayerTransform(view: itemSetView, transform: CATransform3DMakeScale(dismissPanScale, dismissPanScale, 1.0))
                            
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
                                                        
                            Transition.immediate.setTransform(view: itemSetComponentView, transform: faceTransform)
                            Transition.immediate.setTransform(layer: itemSetView.tintLayer, transform: faceTransform)
                            
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
                    itemSetView.removeFromSuperview()
                }
            }
            for id in removedIds {
                self.visibleItemSetViews.removeValue(forKey: id)
            }
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: contentDerivedBottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
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
        public let updateView: (UIView, TransitionState, Transition) -> Void
        
        public init(
            makeView: @escaping () -> UIView,
            updateView: @escaping (UIView, TransitionState, Transition) -> Void
        ) {
            self.makeView = makeView
            self.updateView = updateView
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
    private var isDismissed: Bool = false
    
    private let focusedItemPromise = Promise<StoryId?>(nil)
    public var focusedItem: Signal<StoryId?, NoError> {
        return self.focusedItemPromise.get()
    }
    
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
        self.navigationPresentation = .flatModal
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
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    func dismissWithoutTransitionOut() {
        self.focusedItemPromise.set(.single(nil))
        
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.dismissWithoutTransitionOut = true
        }
        self.dismiss()
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

