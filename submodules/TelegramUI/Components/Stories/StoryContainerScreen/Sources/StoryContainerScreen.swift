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

private final class StoryContainerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialFocusedId: AnyHashable?
    let initialContent: [StoryContentItemSlice]
    let transitionIn: StoryContainerScreen.TransitionIn?
    let transitionOut: (EnginePeer.Id) -> StoryContainerScreen.TransitionOut?
    
    init(
        context: AccountContext,
        initialFocusedId: AnyHashable?,
        initialContent: [StoryContentItemSlice],
        transitionIn: StoryContainerScreen.TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id) -> StoryContainerScreen.TransitionOut?
    ) {
        self.context = context
        self.initialFocusedId = initialFocusedId
        self.initialContent = initialContent
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
    }
    
    static func ==(lhs: StoryContainerScreenComponent, rhs: StoryContainerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
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
        
        private var focusedItemSet: AnyHashable?
        private var itemSets: [StoryContentItemSlice] = []
        private var visibleItemSetViews: [AnyHashable: ItemSetView] = [:]
        
        private var itemSetPanState: ItemSetPanState?
        private var dismissPanState: ItemSetPanState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .black
            
            let horizontalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let focusedItemSet = self.focusedItemSet, let itemSetView = self.visibleItemSetViews[focusedItemSet], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return []
                }
                if !itemSetComponentView.isPointInsideContentArea(point: self.convert(point, to: itemSetComponentView)) {
                    return []
                }
                return [.left, .right]
            })
            self.addGestureRecognizer(horizontalPanRecognizer)
            
            let verticalPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.dismissPanGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let focusedItemSet = self.focusedItemSet, let itemSetView = self.visibleItemSetViews[focusedItemSet], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                    return []
                }
                if !itemSetComponentView.isPointInsideContentArea(point: self.convert(point, to: itemSetComponentView)) {
                    return []
                }
                
                return [.down]
            })
            self.addGestureRecognizer(verticalPanRecognizer)
            
            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
            longPressRecognizer.delegate = self
            self.addGestureRecognizer(longPressRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let focusedItemSet = self.focusedItemSet, let itemSetView = self.visibleItemSetViews[focusedItemSet], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View else {
                return true
            }
            
            if !itemSetComponentView.isPointInsideContentArea(point: touch.location(in: itemSetComponentView)) {
                return false
            }
            
            return true
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.layer.removeAnimation(forKey: "panState")
                
                if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                } else {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                    self.state?.updated(transition: .immediate)
                }
            case .changed:
                if var itemSetPanState = self.itemSetPanState, self.bounds.width > 0.0, let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                    var translation = recognizer.translation(in: self)
                    
                    func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                        let bandedOffset = offset - bandingStart
                        let range: CGFloat = 600.0
                        let coefficient: CGFloat = 0.4
                        return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                    }
                    
                    if translation.x > 0.0 && focusedIndex == 0 {
                        translation.x = rubberBandingOffset(offset: translation.x, bandingStart: 0.0)
                    } else if translation.x < 0.0 && focusedIndex == self.itemSets.count - 1 {
                        translation.x = -rubberBandingOffset(offset: -translation.x, bandingStart: 0.0)
                    }
                    
                    var fraction = translation.x / self.bounds.width
                    fraction = -max(-1.0, min(1.0, fraction))
                    
                    itemSetPanState.fraction = fraction
                    self.itemSetPanState = itemSetPanState
                    
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if var itemSetPanState = self.itemSetPanState {
                    if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                        let velocity = recognizer.velocity(in: self)
                        
                        var switchToIndex = focusedIndex
                        if abs(velocity.x) > 10.0 {
                            if velocity.x < 0.0 {
                                switchToIndex += 1
                            } else {
                                switchToIndex -= 1
                            }
                        }
                        
                        switchToIndex = max(0, min(switchToIndex, self.itemSets.count - 1))
                        if switchToIndex != focusedIndex {
                            self.focusedItemSet = self.itemSets[switchToIndex].id
                            
                            if switchToIndex < focusedIndex {
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
                    })
                }
            default:
                break
            }
        }
        
        @objc private func dismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.dismissPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                self.state?.updated(transition: .immediate)
            case .changed:
                let translation = recognizer.translation(in: self)
                self.dismissPanState = ItemSetPanState(fraction: max(0.0, min(1.0, translation.y / self.bounds.height)), didBegin: true)
                self.state?.updated(transition: .immediate)
            case .cancelled, .ended:
                let translation = recognizer.translation(in: self)
                let velocity = recognizer.velocity(in: self)
                
                self.dismissPanState = nil
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                
                if translation.y > 100.0 || velocity.y > 10.0 {
                    self.environment?.controller()?.dismiss()
                }
            default:
                break
            }
        }
        
        @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
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
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.isHidden || subview.alpha == 0.0 {
                    continue
                }
                if subview is ItemSetView {
                    if let result = subview.hitTest(point, with: event) {
                        return result
                    }
                } else {
                    if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                        return result
                    }
                }
            }
            
            return nil
        }
        
        func animateIn() {
            if let transitionIn = self.component?.transitionIn, transitionIn.sourceView != nil {
                self.layer.animate(from: UIColor.black.withAlphaComponent(0.0).cgColor, to: self.layer.backgroundColor ?? UIColor.black.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.28)
                
                if let transitionIn = self.component?.transitionIn, let focusedItemSet = self.focusedItemSet, let itemSetView = self.visibleItemSetViews[focusedItemSet] {
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
            if let component = self.component, let focusedItemSet = self.focusedItemSet, let peerId = focusedItemSet.base as? EnginePeer.Id, let itemSetView = self.visibleItemSetViews[focusedItemSet], let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View, let transitionOut = component.transitionOut(peerId) {
                let currentBackgroundColor = self.layer.presentation()?.backgroundColor ?? self.layer.backgroundColor
                self.layer.animate(from: currentBackgroundColor ?? UIColor.black.cgColor, to: UIColor.black.withAlphaComponent(0.0).cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.25, removeOnCompletion: false)
                
                itemSetComponentView.animateOut(transitionOut: transitionOut, completion: completion)
            } else {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    completion()
                })
            }
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
            let isFirstTime = self.component == nil
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if isFirstTime {
                if let initialFocusedId = component.initialFocusedId, component.initialContent.contains(where: { $0.id == initialFocusedId }) {
                    self.focusedItemSet = initialFocusedId
                } else {
                    self.focusedItemSet = component.initialContent.first?.id
                }
                self.itemSets = component.initialContent
            }
            
            var isProgressPaused = false
            if self.itemSetPanState != nil {
                isProgressPaused = true
            }
            if self.dismissPanState != nil {
                isProgressPaused = true
            }
            
            var dismissPanOffset: CGFloat = 0.0
            var dismissPanScale: CGFloat = 1.0
            var dismissAlphaScale: CGFloat = 1.0
            if let dismissPanState = self.dismissPanState {
                dismissPanOffset = dismissPanState.fraction * availableSize.height
                dismissPanScale = 1.0 * (1.0 - dismissPanState.fraction) + 0.6 * dismissPanState.fraction
                dismissAlphaScale = 1.0 * (1.0 - dismissPanState.fraction) + 0.2 * dismissPanState.fraction
            }
            
            transition.setBackgroundColor(view: self, color: UIColor.black.withAlphaComponent(max(0.5, dismissAlphaScale)))
            
            var contentDerivedBottomInset: CGFloat = environment.safeInsets.bottom
            
            var validIds: [AnyHashable] = []
            if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                for i in max(0, focusedIndex - 1) ... min(focusedIndex + 1, self.itemSets.count - 1) {
                    var isItemVisible = false
                    if i == focusedIndex {
                        isItemVisible = true
                    }
                    
                    let itemSet = self.itemSets[i]
                    
                    if let itemSetPanState = self.itemSetPanState {
                        if self.visibleItemSetViews[itemSet.id] != nil {
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
                        validIds.append(itemSet.id)
                        
                        let itemSetView: ItemSetView
                        var itemSetTransition = transition
                        if let current = self.visibleItemSetViews[itemSet.id] {
                            itemSetView = current
                        } else {
                            itemSetTransition = .immediate
                            itemSetView = ItemSetView()
                            self.visibleItemSetViews[itemSet.id] = itemSetView
                        }
                        let _ = itemSetView.view.update(
                            transition: itemSetTransition,
                            component: AnyComponent(StoryItemSetContainerComponent(
                                context: component.context,
                                externalState: itemSetView.externalState,
                                initialItemSlice: itemSet,
                                theme: environment.theme,
                                strings: environment.strings,
                                containerInsets: UIEdgeInsets(top: environment.statusBarHeight + 12.0, left: 0.0, bottom: environment.inputHeight, right: 0.0),
                                safeInsets: environment.safeInsets,
                                inputHeight: environment.inputHeight,
                                isProgressPaused: isProgressPaused || i != focusedIndex,
                                hideUI: i == focusedIndex && self.itemSetPanState?.didBegin == false,
                                presentController: { [weak self] c in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    if c is UndoOverlayController {
                                        environment.controller()?.present(c, in: .current)
                                    } else {
                                        environment.controller()?.present(c, in: .window(.root))
                                    }
                                },
                                close: { [weak self] in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    environment.controller()?.dismiss()
                                },
                                navigateToItemSet: { [weak self] direction in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    
                                    if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                                        var switchToIndex = focusedIndex
                                        switch direction {
                                        case .previous:
                                            switchToIndex -= 1
                                        case .next:
                                            switchToIndex += 1
                                        }
                                        
                                        switchToIndex = max(0, min(switchToIndex, self.itemSets.count - 1))
                                        if switchToIndex != focusedIndex {
                                            var itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                                            
                                            self.focusedItemSet = self.itemSets[switchToIndex].id
                                            
                                            if switchToIndex < focusedIndex {
                                                itemSetPanState.fraction = 1.0 + itemSetPanState.fraction
                                            } else {
                                                itemSetPanState.fraction = itemSetPanState.fraction - 1.0
                                            }
                                            self.itemSetPanState = itemSetPanState
                                            self.state?.updated(transition: .immediate)
                                            
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
                                            })
                                        } else if switchToIndex == self.itemSets.count - 1 {
                                            environment.controller()?.dismiss()
                                        }
                                    } else {
                                        environment.controller()?.dismiss()
                                    }
                                },
                                controller: { [weak self] in
                                    return self?.environment?.controller()
                                }
                            )),
                            environment: {},
                            containerSize: availableSize
                        )
                        
                        if i == focusedIndex {
                            contentDerivedBottomInset = itemSetView.externalState.derivedBottomInset
                        }
                        
                        let itemFrame = CGRect(origin: CGPoint(), size: availableSize)
                        if let itemSetComponentView = itemSetView.view.view {
                            if itemSetView.superview == nil {
                                self.addSubview(itemSetView)
                            }
                            if itemSetComponentView.superview == nil {
                                itemSetComponentView.layer.isDoubleSided = false
                                itemSetView.addSubview(itemSetComponentView)
                                itemSetView.layer.addSublayer(itemSetView.tintLayer)
                            }
                            
                            itemSetTransition.setPosition(view: itemSetView, position: itemFrame.center.offsetBy(dx: 0.0, dy: dismissPanOffset))
                            itemSetTransition.setBounds(view: itemSetView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            itemSetTransition.setSublayerTransform(view: itemSetView, transform: CATransform3DMakeScale(dismissPanScale, dismissPanScale, 1.0))
                            
                            itemSetTransition.setPosition(view: itemSetComponentView, position: CGRect(origin: CGPoint(), size: itemFrame.size).center)
                            itemSetTransition.setBounds(view: itemSetComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            itemSetTransition.setPosition(layer: itemSetView.tintLayer, position: CGRect(origin: CGPoint(), size: itemFrame.size).center)
                            itemSetTransition.setBounds(layer: itemSetView.tintLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            let perspectiveConstant: CGFloat = 500.0
                            let width = itemFrame.width
                            
                            let sideDistance: CGFloat = 40.0
                            
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
                            }
                            
                            Transition.immediate.setTransform(view: itemSetComponentView, transform: faceTransform)
                            Transition.immediate.setTransform(layer: itemSetView.tintLayer, transform: faceTransform)
                            
                            if let previousRotationFraction = itemSetView.rotationFraction {
                                let fromT = previousRotationFraction
                                let toT = panFraction
                                itemSetTransition.setTransformAsKeyframes(view: itemSetView, transform: { sourceT in
                                    let t = fromT * (1.0 - sourceT) + toT * sourceT
                                    if abs((t + cubeAdditionalRotationFraction) - 0.0) < 0.0001 {
                                        return CATransform3DIdentity
                                    }
                                    
                                    return calculateCubeTransform(rotationFraction: t + cubeAdditionalRotationFraction, sideAngle: sideAngle, cubeSize: itemFrame.size)
                                })
                            } else {
                                if panFraction == 0.0 {
                                    itemSetTransition.setTransform(view: itemSetView, transform: CATransform3DIdentity)
                                } else {
                                    itemSetTransition.setTransform(view: itemSetView, transform: calculateCubeTransform(rotationFraction: panFraction + cubeAdditionalRotationFraction, sideAngle: sideAngle, cubeSize: itemFrame.size))
                                }
                            }
                            itemSetView.rotationFraction = panFraction
                            
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
            var removedIds: [AnyHashable] = []
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
    public final class TransitionIn {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceCornerRadius: CGFloat
        
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceCornerRadius: CGFloat
        ) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.sourceCornerRadius = sourceCornerRadius
        }
    }
    
    public final class TransitionOut {
        public weak var destinationView: UIView?
        public let destinationRect: CGRect
        public let destinationCornerRadius: CGFloat
        
        public init(
            destinationView: UIView,
            destinationRect: CGRect,
            destinationCornerRadius: CGFloat
        ) {
            self.destinationView = destinationView
            self.destinationRect = destinationRect
            self.destinationCornerRadius = destinationCornerRadius
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialFocusedId: AnyHashable?,
        initialContent: [StoryContentItemSlice],
        transitionIn: TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id) -> TransitionOut?
    ) {
        self.context = context
        
        super.init(context: context, component: StoryContainerScreenComponent(
            context: context,
            initialFocusedId: initialFocusedId,
            initialContent: initialContent,
            transitionIn: transitionIn,
            transitionOut: transitionOut
        ), navigationBarAppearance: .none, theme: .dark)
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        
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

