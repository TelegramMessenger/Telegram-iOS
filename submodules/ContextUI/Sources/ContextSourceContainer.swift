import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SwiftSignalKit
import TelegramCore
import ReactionSelectionNode
import ComponentFlow
import TabSelectorComponent
import PlainButtonComponent
import MultilineTextComponent
import ComponentDisplayAdapters
import AccountContext

final class ContextSourceContainer: ASDisplayNode {
    final class Source {
        weak var controller: ContextController?
        
        let id: AnyHashable
        let title: String
        let footer: String?
        let context: AccountContext?
        let source: ContextContentSource
        let closeActionTitle: String?
        let closeAction: (() -> Void)?
        
        private var _presentationNode: ContextControllerPresentationNode?
        var presentationNode: ContextControllerPresentationNode {
            return self._presentationNode!
        }
        
        var currentPresentationStateTransition: ContextControllerPresentationNodeStateTransition?
        
        var validLayout: ContainerViewLayout?
        var presentationData: PresentationData?
        var delayLayoutUpdate: Bool = false
        var isAnimatingOut: Bool = false
        
        var itemsDisposables = DisposableSet()
        
        let ready = Promise<Bool>()
        private let contentReady = Promise<Bool>()
        private let actionsReady = Promise<Bool>()
        
        init(
            controller: ContextController,
            id: AnyHashable,
            title: String,
            footer: String?,
            context: AccountContext?,
            source: ContextContentSource,
            items: Signal<ContextController.Items, NoError>,
            closeActionTitle: String? = nil,
            closeAction: (() -> Void)? = nil
        ) {
            self.controller = controller
            self.id = id
            self.title = title
            self.footer = footer
            self.context = context
            self.source = source
            self.closeActionTitle = closeActionTitle
            self.closeAction = closeAction
            
            self.ready.set(combineLatest(queue: .mainQueue(), self.contentReady.get(), self.actionsReady.get())
            |> map { a, b -> Bool in
                return a && b
            }
            |> distinctUntilChanged)
            
            switch source {
            case let .location(source):
                self.contentReady.set(.single(true))
                
                let presentationNode = ContextControllerExtractedPresentationNode(
                    context: self.context,
                    getController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.controller
                    },
                    requestUpdate: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.update(transition: transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if let controller = self.controller {
                            controller.overlayWantsToBeBelowKeyboardUpdated(transition: transition)
                        }
                    },
                    requestDismiss: { [weak self] result in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.dismissedForCancel?()
                        controller.controllerNode.beginDismiss(result)
                    },
                    requestAnimateOut: { [weak self] result, completion in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.animateOut(result: result, completion: completion)
                    },
                    source: .location(source)
                )
                self._presentationNode = presentationNode
            case let .reference(source):
                self.contentReady.set(.single(true))
                
                let presentationNode = ContextControllerExtractedPresentationNode(
                    context: self.context,
                    getController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.controller
                    },
                    requestUpdate: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.update(transition: transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if let controller = self.controller {
                            controller.overlayWantsToBeBelowKeyboardUpdated(transition: transition)
                        }
                    },
                    requestDismiss: { [weak self] result in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.dismissedForCancel?()
                        controller.controllerNode.beginDismiss(result)
                    },
                    requestAnimateOut: { [weak self] result, completion in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.animateOut(result: result, completion: completion)
                    },
                    source: .reference(source)
                )
                self._presentationNode = presentationNode
            case let .extracted(source):
                self.contentReady.set(.single(true))
                
                let presentationNode = ContextControllerExtractedPresentationNode(
                    context: self.context,
                    getController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.controller
                    },
                    requestUpdate: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.update(transition: transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if let controller = self.controller {
                            controller.overlayWantsToBeBelowKeyboardUpdated(transition: transition)
                        }
                    },
                    requestDismiss: { [weak self] result in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        if let _ = self.closeActionTitle {
                        } else {
                            controller.controllerNode.dismissedForCancel?()
                            controller.controllerNode.beginDismiss(result)
                        }
                    },
                    requestAnimateOut: { [weak self] result, completion in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.animateOut(result: result, completion: completion)
                    },
                    source: .extracted(source)
                )
                self._presentationNode = presentationNode
            case let .controller(source):
                self.contentReady.set(source.controller.ready.get())
                
                let presentationNode = ContextControllerExtractedPresentationNode(
                    context: self.context,
                    getController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.controller
                    },
                    requestUpdate: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.update(transition: transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if let controller = self.controller {
                            controller.overlayWantsToBeBelowKeyboardUpdated(transition: transition)
                        }
                    },
                    requestDismiss: { [weak self] result in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.dismissedForCancel?()
                        controller.controllerNode.beginDismiss(result)
                    },
                    requestAnimateOut: { [weak self] result, completion in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        controller.controllerNode.animateOut(result: result, completion: completion)
                    },
                    source: .controller(source)
                )
                self._presentationNode = presentationNode
            }
            
            self.itemsDisposables.add((items |> deliverOnMainQueue).start(next: { [weak self] items in
                guard let self else {
                    return
                }
                
                self.setItems(items: items, animated: nil)
                self.actionsReady.set(.single(true))
            }))
        }
        
        deinit {
            self.itemsDisposables.dispose()
        }
        
        func animateIn() {
            self.currentPresentationStateTransition = .animateIn
            self.update(transition: .animated(duration: 0.5, curve: .spring))
        }
        
        func animateOut(result: ContextMenuActionResult, completion: @escaping () -> Void) {
            self.currentPresentationStateTransition = .animateOut(result: result, completion: completion)
            if let _ = self.validLayout {
                if case let .custom(transition) = result {
                    self.delayLayoutUpdate = true
                    Queue.mainQueue().after(0.1) {
                        self.delayLayoutUpdate = false
                        self.update(transition: transition)
                        self.isAnimatingOut = true
                    }
                } else {
                    self.update(transition: .animated(duration: 0.35, curve: .easeInOut))
                }
            }
        }
        
        func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
            self.presentationNode.addRelativeContentOffset(offset, transition: transition)
        }
        
        func cancelReactionAnimation() {
            self.presentationNode.cancelReactionAnimation()
        }
        
        func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, onHit: (() -> Void)?, completion: @escaping () -> Void) {
            self.presentationNode.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, reducedCurve: reducedCurve, onHit: onHit, completion: completion)
        }
        
        func setItems(items: Signal<ContextController.Items, NoError>, animated: Bool) {
            self.itemsDisposables.dispose()
            self.itemsDisposables = DisposableSet()
            self.itemsDisposables.add((items
            |> deliverOnMainQueue).start(next: { [weak self] items in
                guard let self else {
                    return
                }
                self.setItems(items: items, animated: animated)
            }))
        }
        
        func setItems(items: ContextController.Items, animated: Bool?) {
            self.presentationNode.replaceItems(items: items, animated: animated)
        }
        
        func pushItems(items: Signal<ContextController.Items, NoError>) {
            self.itemsDisposables.add((items
            |> deliverOnMainQueue).start(next: { [weak self] items in
                guard let self else {
                    return
                }
                self.presentationNode.pushItems(items: items)
            }))
        }
        
        func popItems() {
            self.itemsDisposables.removeLast()
            self.presentationNode.popItems()
        }
        
        func update(transition: ContainedViewLayoutTransition) {
            guard let validLayout = self.validLayout else {
                return
            }
            guard let presentationData = self.presentationData else {
                return
            }
            self.update(presentationData: presentationData, layout: validLayout, transition: transition)
        }
        
        func update(
            presentationData: PresentationData,
            layout: ContainerViewLayout,
            transition: ContainedViewLayoutTransition
        ) {
            if self.isAnimatingOut || self.delayLayoutUpdate {
                return
            }
            
            self.validLayout = layout
            self.presentationData = presentationData
            
            let presentationStateTransition = self.currentPresentationStateTransition
            self.currentPresentationStateTransition = .none
            
            self.presentationNode.update(
                presentationData: presentationData,
                layout: layout,
                transition: transition,
                stateTransition: presentationStateTransition
            )
        }
    }
    
    private struct PanState {
        var fraction: CGFloat
        
        init(fraction: CGFloat) {
            self.fraction = fraction
        }
    }
    
    private weak var controller: ContextController?
    
    private let backgroundNode: NavigationBackgroundNode
    
    var sources: [Source] = []
    var activeIndex: Int = 0
    
    private var tabSelector: ComponentView<Empty>?
    private var footer: ComponentView<Empty>?
    private var closeButton: ComponentView<Empty>?
    
    private var presentationData: PresentationData?
    private var validLayout: ContainerViewLayout?
    private var panState: PanState?
    
    let ready = Promise<Bool>()
    
    var activeSource: Source? {
        if self.activeIndex >= self.sources.count {
            return nil
        }
        return self.sources[self.activeIndex]
    }
    
    var overlayWantsToBeBelowKeyboard: Bool {
        return self.activeSource?.presentationNode.wantsDisplayBelowKeyboard() ?? false
    }
    
    init(controller: ContextController, configuration: ContextController.Configuration, context: AccountContext?) {
        self.controller = controller
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: false)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        for i in 0 ..< configuration.sources.count {
            let source = configuration.sources[i]
            
            let mappedSource = Source(
                controller: controller,
                id: source.id,
                title: source.title,
                footer: source.footer,
                context: context,
                source: source.source,
                items: source.items,
                closeActionTitle: source.closeActionTitle,
                closeAction: source.closeAction
            )
            self.sources.append(mappedSource)
            self.addSubnode(mappedSource.presentationNode)
            
            if source.id == configuration.initialId {
                self.activeIndex = i
            }
        }
        
        self.ready.set(self.sources[self.activeIndex].ready.get())
        
        self.view.addGestureRecognizer(InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let self else {
                return []
            }
            if self.sources.count <= 1 {
                return []
            }
            return [.left, .right]
        }))
    }
    
    @objc private func panGesture(_ recognizer: InteractiveTransitionGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            if let validLayout = self.validLayout {
                var translationX = recognizer.translation(in: self.view).x
                if self.activeIndex == 0 && translationX > 0.0 {
                    translationX = scrollingRubberBandingOffset(offset: abs(translationX), bandingStart: 0.0, range: 20.0)
                } else if self.activeIndex == self.sources.count - 1 && translationX < 0.0 {
                    translationX = -scrollingRubberBandingOffset(offset: abs(translationX), bandingStart: 0.0, range: 20.0)
                }
                
                self.panState = PanState(fraction: translationX / validLayout.size.width)
                self.update(transition: .immediate)
            }
        case .cancelled, .ended:
            if let panState = self.panState {
                self.panState = nil
                
                let velocity = recognizer.velocity(in: self.view)
                
                var nextIndex = self.activeIndex
                if panState.fraction < -0.4 {
                    nextIndex += 1
                } else if panState.fraction > 0.4 {
                    nextIndex -= 1
                } else if abs(velocity.x) >= 200.0 {
                    if velocity.x < 0.0 {
                        nextIndex += 1
                    } else {
                        nextIndex -= 1
                    }
                }
                if nextIndex < 0 {
                    nextIndex = 0
                }
                if nextIndex > self.sources.count - 1 {
                    nextIndex = self.sources.count - 1
                }
                if nextIndex != self.activeIndex {
                    self.activeIndex = nextIndex
                }
                
                self.update(transition: .animated(duration: 0.4, curve: .spring))
            }
        default:
            break
        }
    }
    
    func animateIn() {
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
//        if let activeSource = self.activeSource {
//            activeSource.animateIn()
//        }
        for source in self.sources {
            source.animateIn()
        }
        if let footerView = self.footer?.view {
            footerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        if let tabSelectorView = self.tabSelector?.view {
            tabSelectorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        if let closeButtonView = self.closeButton?.view {
            closeButtonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    func animateOut(result: ContextMenuActionResult, completion: @escaping () -> Void) {
        let delayDismissal = self.activeSource?.closeAction != nil
        let delay: Double = delayDismissal ? 0.2 : 0.0
        let duration: Double = delayDismissal ? 0.35 : 0.2
        
        self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, delay: delay, removeOnCompletion: false, completion: { _ in
            if delayDismissal {
                Queue.mainQueue().after(0.55) {
                    completion()
                }
            }
        })
        
        if let footerView = self.footer?.view {
            footerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, delay: delay, removeOnCompletion: false)
        }
        if let tabSelectorView = self.tabSelector?.view {
            tabSelectorView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, delay: delay, removeOnCompletion: false)
        }
        if let closeButtonView = self.closeButton?.view {
            closeButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, delay: delay, removeOnCompletion: false)
        }
        
        for source in self.sources {
            if source !== self.activeSource {
                source.animateOut(result: result, completion: {})
            }
        }
        
        if let activeSource = self.activeSource {
            activeSource.animateOut(result: result, completion: delayDismissal ? {} : completion)
        } else {
            completion()
        }
    }
    
    func highlightGestureMoved(location: CGPoint, hover: Bool) {
        if self.activeIndex >= self.sources.count {
            return
        }
        self.sources[self.activeIndex].presentationNode.highlightGestureMoved(location: location, hover: hover)
    }
    
    func highlightGestureFinished(performAction: Bool) {
        if self.activeIndex >= self.sources.count {
            return
        }
        self.sources[self.activeIndex].presentationNode.highlightGestureFinished(performAction: performAction)
    }
    
    func performHighlightedAction() {
        self.activeSource?.presentationNode.highlightGestureFinished(performAction: true)
    }
    
    func decreaseHighlightedIndex() {
        self.activeSource?.presentationNode.decreaseHighlightedIndex()
    }
    
    func increaseHighlightedIndex() {
        self.activeSource?.presentationNode.increaseHighlightedIndex()
    }
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if let activeSource = self.activeSource {
            activeSource.addRelativeContentOffset(offset, transition: transition)
        }
    }
    
    func cancelReactionAnimation() {
        if let activeSource = self.activeSource {
            activeSource.cancelReactionAnimation()
        }
    }
    
    func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, onHit: (() -> Void)?, completion: @escaping () -> Void) {
        if let activeSource = self.activeSource {
            activeSource.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, reducedCurve: reducedCurve, onHit: onHit, completion: completion)
        } else {
            completion()
        }
    }
    
    func setItems(items: Signal<ContextController.Items, NoError>, animated: Bool) {
        if let activeSource = self.activeSource {
            activeSource.setItems(items: items, animated: animated)
        }
    }
    
    func pushItems(items: Signal<ContextController.Items, NoError>) {
        if let activeSource = self.activeSource {
            activeSource.pushItems(items: items)
        }
    }
    
    func popItems() {
        if let activeSource = self.activeSource {
            activeSource.popItems()
        }
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let presentationData = self.presentationData, let validLayout = self.validLayout {
            self.update(presentationData: presentationData, layout: validLayout, transition: transition)
        }
    }
    
    func update(
        presentationData: PresentationData,
        layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition
    ) {
        self.presentationData = presentationData
        self.validLayout = layout
        
        var childLayout = layout
        
        if let activeSource = self.activeSource {
            switch activeSource.source {
            case .location, .reference:
                self.backgroundNode.updateColor(
                    color: .clear,
                    enableBlur: false,
                    forceKeepBlur: false,
                    transition: .immediate
                )
            case .extracted:
                self.backgroundNode.updateColor(
                    color: presentationData.theme.contextMenu.dimColor,
                    enableBlur: true,
                    forceKeepBlur: true,
                    transition: .immediate
                )
            case .controller:
                if case .regular = layout.metrics.widthClass {
                    self.backgroundNode.updateColor(
                        color: UIColor(white: 0.0, alpha: 0.4),
                        enableBlur: false,
                        forceKeepBlur: false,
                        transition: .immediate
                    )
                } else {
                    self.backgroundNode.updateColor(
                        color: presentationData.theme.contextMenu.dimColor,
                        enableBlur: true,
                        forceKeepBlur: true,
                        transition: .immediate
                    )
                }
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        self.backgroundNode.update(size: layout.size, transition: transition)
        
        if self.sources.count > 1 {
            let tabSelector: ComponentView<Empty>
            if let current = self.tabSelector {
                tabSelector = current
            } else {
                tabSelector = ComponentView()
                self.tabSelector = tabSelector
            }
            let mappedItems = self.sources.map { source -> TabSelectorComponent.Item in
                return TabSelectorComponent.Item(id: source.id, title: source.title)
            }
            let tabSelectorSize = tabSelector.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(TabSelectorComponent(
                    colors: TabSelectorComponent.Colors(
                        foreground: presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.8),
                        selection: presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.1)
                    ),
                    customLayout: TabSelectorComponent.CustomLayout(
                        font: Font.medium(14.0),
                        spacing: 9.0
                    ),
                    items: mappedItems,
                    selectedId: self.activeSource?.id,
                    setSelectedId: { [weak self] id in
                        guard let self else {
                            return
                        }
                        if let index = self.sources.firstIndex(where: { $0.id == id }) {
                            self.activeIndex = index
                            self.update(transition: .animated(duration: 0.4, curve: .spring))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width, height: 44.0)
            )
            childLayout.intrinsicInsets.bottom += 30.0
            
            if let footerText = self.activeSource?.footer {
                var footerTransition = transition
                let footer: ComponentView<Empty>
                if let current = self.footer {
                    footer = current
                } else {
                    footerTransition = .immediate
                    footer = ComponentView()
                    self.footer = footer
                }
                
                let footerSize = footer.update(
                    transition: ComponentTransition(footerTransition),
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4))),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: layout.size.width, height: 144.0)
                )
                
                let spacing: CGFloat = 20.0
                childLayout.intrinsicInsets.bottom += footerSize.height + spacing
                
                if let footerView = footer.view {
                    if footerView.superview == nil {
                        self.view.addSubview(footerView)
                        
                        footerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                    footerTransition.updateFrame(view: footerView, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - footerSize.width) * 0.5), y: layout.size.height - layout.intrinsicInsets.bottom - tabSelectorSize.height - footerSize.height - spacing), size: footerSize))
                }
            } else if let footer = self.footer {
                self.footer = nil
                footer.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    footer.view?.removeFromSuperview()
                })
            }
            
            if let tabSelectorView = tabSelector.view {
                if tabSelectorView.superview == nil {
                    self.view.addSubview(tabSelectorView)
                }
                transition.updateFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - tabSelectorSize.width) * 0.5), y: layout.size.height - layout.intrinsicInsets.bottom - tabSelectorSize.height), size: tabSelectorSize))
            }
        } else if let source = self.sources.first, let closeActionTitle = source.closeActionTitle {
            let closeButton: ComponentView<Empty>
            if let current = self.closeButton {
                closeButton = current
            } else {
                closeButton = ComponentView()
                self.closeButton = closeButton
            }
            
            let closeButtonSize = closeButton.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(
                        CloseButtonComponent(
                            backgroundColor: presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.1),
                            text: closeActionTitle
                        )
                    ),
                    effectAlignment: .center,
                    action: { [weak self, weak source] in
                        guard let self else {
                            return
                        }
                        if let source, let closeAction = source.closeAction {
                            closeAction()
                        } else {
                            self.controller?.dismiss(result: .dismissWithoutContent, completion: nil)
                        }
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width, height: 44.0)
            )
            childLayout.intrinsicInsets.bottom += 30.0
            
            if let closeButtonView = closeButton.view {
                if closeButtonView.superview == nil {
                    self.view.addSubview(closeButtonView)
                }
                transition.updateFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - closeButtonSize.width) * 0.5), y: layout.size.height - layout.intrinsicInsets.bottom - closeButtonSize.height - 10.0), size: closeButtonSize))
            }
        } else if let tabSelector = self.tabSelector {
            self.tabSelector = nil
            tabSelector.view?.removeFromSuperview()
        }
        
        for i in 0 ..< self.sources.count {
            var itemFrame = CGRect(origin: CGPoint(), size: childLayout.size)
            itemFrame.origin.x += CGFloat(i - self.activeIndex) * childLayout.size.width
            if let panState = self.panState {
                itemFrame.origin.x += panState.fraction * childLayout.size.width
            }
            
            let itemTransition = transition
            itemTransition.updateFrame(node: self.sources[i].presentationNode, frame: itemFrame)
            self.sources[i].update(
                presentationData: presentationData,
                layout: childLayout,
                transition: itemTransition
            )
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let tabSelectorView = self.tabSelector?.view {
            if let result = tabSelectorView.hitTest(self.view.convert(point, to: tabSelectorView), with: event) {
                return result
            }
        }
        if let closeButtonView = self.closeButton?.view {
            if let result = closeButtonView.hitTest(self.view.convert(point, to: closeButtonView), with: event) {
                return result
            }
        }
        
        guard let activeSource = self.activeSource else {
            return nil
        }
        return activeSource.presentationNode.view.hitTest(point, with: event)
    }
}


private final class CloseButtonComponent: CombinedComponent {
    let backgroundColor: UIColor
    let text: String

    init(
        backgroundColor: UIColor,
        text: String
    ) {
        self.backgroundColor = backgroundColor
        self.text = text
    }

    static func ==(lhs: CloseButtonComponent, rhs: CloseButtonComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let text = Child(Text.self)

        return { context in
            let text = text.update(
                component: Text(
                    text: "\(context.component.text)",
                    font: Font.regular(17.0),
                    color: .white
                ),
                availableSize: CGSize(width: 200.0, height: 100.0),
                transition: .immediate
            )

            let backgroundSize = CGSize(width: text.size.width + 34.0, height: 36.0)
            let background = background.update(
                component: RoundedRectangle(color: context.component.backgroundColor, cornerRadius: 18.0),
                availableSize: backgroundSize,
                transition: .immediate
            )

            context.add(background
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: backgroundSize.width / 2.0, y: backgroundSize.height / 2.0))
            )

            return backgroundSize
        }
    }
}
