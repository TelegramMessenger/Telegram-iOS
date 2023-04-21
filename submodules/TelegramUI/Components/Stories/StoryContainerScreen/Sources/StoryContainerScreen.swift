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
import UndoUI

private func hasFirstResponder(_ view: UIView) -> Bool {
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
    let initialContent: StoryContentItemSlice
    
    init(
        context: AccountContext,
        initialContent: StoryContentItemSlice
    ) {
        self.context = context
        self.initialContent = initialContent
    }
    
    static func ==(lhs: StoryContainerScreenComponent, rhs: StoryContainerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialContent !== rhs.initialContent {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct ItemLayout {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    private final class VisibleItem {
        let view = ComponentView<Empty>()
        
        init() {
        }
    }
    
    private final class InfoItem {
        let component: AnyComponent<Empty>
        let view = ComponentView<Empty>()
        
        init(component: AnyComponent<Empty>) {
            self.component = component
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private let contentContainerView: UIView
        private let topContentGradientLayer: SimpleGradientLayer
        private let bottomContentGradientLayer: SimpleGradientLayer
        private let contentDimLayer: SimpleLayer
        
        private let closeButton: HighlightableButton
        private let closeButtonIconView: UIImageView
        
        private let navigationStrip = ComponentView<Empty>()
        private let inlineActions = ComponentView<Empty>()
        
        private var centerInfoItem: InfoItem?
        private var rightInfoItem: InfoItem?
        
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private var component: StoryContainerScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var focusedItemId: AnyHashable?
        private var currentSlice: StoryContentItemSlice?
        private var currentSliceDisposable: Disposable?
        
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        private var preloadContexts: [AnyHashable: Disposable] = [:]
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            self.contentContainerView.isUserInteractionEnabled = false
            
            self.topContentGradientLayer = SimpleGradientLayer()
            self.bottomContentGradientLayer = SimpleGradientLayer()
            self.contentDimLayer = SimpleLayer()
            
            self.closeButton = HighlightableButton()
            self.closeButtonIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.backgroundColor = .black
            
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
            self.layer.addSublayer(self.contentDimLayer)
            self.layer.addSublayer(self.topContentGradientLayer)
            self.layer.addSublayer(self.bottomContentGradientLayer)
            
            self.closeButton.addSubview(self.closeButtonIconView)
            self.addSubview(self.closeButton)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.currentSliceDisposable?.dispose()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }), let itemLayout = self.itemLayout {
                if hasFirstResponder(self) {
                    self.endEditing(true)
                } else {
                    let point = recognizer.location(in: self)
                    
                    var nextIndex: Int
                    if point.x < itemLayout.size.width * 0.5 {
                        nextIndex = currentIndex + 1
                    } else {
                        nextIndex = currentIndex - 1
                    }
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let focusedItemId = currentSlice.items[nextIndex].id
                        self.focusedItemId = focusedItemId
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
                    }
                }
            }
        }
        
        @objc private func closePressed() {
            guard let environment = self.environment, let controller = environment.controller() else {
                return
            }
            controller.dismiss()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let itemLayout = self.itemLayout else {
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
                    environment: {},
                    containerSize: itemLayout.size
                )
                if let view = visibleItem.view.view {
                    if view.superview == nil {
                        self.contentContainerView.addSubview(view)
                    }
                    itemTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: itemLayout.size))
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
        
        func animateIn() {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.layer.allowsGroupOpacity = false
            })
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }
        
        private func performSendMessageAction() {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                if !text.isEmpty {
                    component.context.engine.messages.enqueueOutgoingMessage(
                        to: targetMessageId.peerId,
                        replyTo: targetMessageId,
                        content: .text(text)
                    )
                    inputPanelView.clearSendMessageInput()
                    
                    if let controller = self.environment?.controller() {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(UndoOverlayController(
                            presentationData: presentationData,
                            content: .succeed(text: "Message Sent"),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ), in: .current)
                    }
                }
            }
        }
        
        private func performInlineAction(item: StoryActionsComponent.Item) {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            
            switch item.kind {
            case .like:
                if item.isActivated {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                        ]
                    )
                } else {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                            .builtin("❤")
                        ]
                    )
                }
            case .share:
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] message in
                    guard let self, let message, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    let shareController = ShareController(
                        context: component.context,
                        subject: .messages([message._asMessage()]),
                        externalShare: false,
                        immediateExternalShare: false,
                        updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }),
                        component.context.sharedContext.presentationData)
                    )
                    controller.present(shareController, in: .window(.root))
                })
            }
        }
        
        private func updatePreloads() {
            var validIds: [AnyHashable] = []
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                for i in 0 ..< 2 {
                    var nextIndex: Int = currentIndex - 1 - i
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
            }
        }
        
        func update(component: StoryContainerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.component == nil {
                self.focusedItemId = component.initialContent.focusedItemId
                self.currentSlice = component.initialContent
                
                self.currentSliceDisposable?.dispose()
                self.currentSliceDisposable = (component.initialContent.update(
                    component.initialContent,
                    component.initialContent.focusedItemId
                )
                |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                    guard let self else {
                        return
                    }
                    self.currentSlice = contentSlice
                    self.state?.updated(transition: .immediate)
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
                    }
                } else {
                    self.focusedItemId = nil
                }
            }
            
            self.updatePreloads()
            
            self.component = component
            self.state = state
            self.environment = environment
            
            var bottomContentInset: CGFloat
            if !environment.safeInsets.bottom.isZero {
                bottomContentInset = environment.safeInsets.bottom + 5.0
            } else {
                bottomContentInset = 0.0
            }
            
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    sendMessageAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.performSendMessageAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let bottomContentInsetWithoutInput = bottomContentInset
            
            let inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if environment.inputHeight < bottomContentInset + inputPanelSize.height {
                inputPanelBottomInset = bottomContentInset
                bottomContentInset += inputPanelSize.height
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = environment.inputHeight
                inputPanelIsOverlay = true
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.statusBarHeight), size: CGSize(width: availableSize.width, height: availableSize.height - environment.statusBarHeight - bottomContentInset))
            transition.setFrame(view: self.contentContainerView, frame: contentFrame)
            transition.setCornerRadius(layer: self.contentContainerView.layer, cornerRadius: 14.0)
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Media Gallery/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: 50.0, height: 64.0))
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
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
                        self.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 6.0 - rightInfoItemSize.width, y: contentFrame.minY + 14.0), size: rightInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        view.layer.animateScale(from: 0.5, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
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
                        self.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY + 10.0), size: centerInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        //view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            if let currentSlice = self.currentSlice {
                let navigationStripSideInset: CGFloat = 8.0
                let navigationStripTopInset: CGFloat = 8.0
                
                let index = currentSlice.items.first(where: { $0.id == self.focusedItemId })?.position ?? 0
                
                let _ = self.navigationStrip.update(
                    transition: transition,
                    component: AnyComponent(MediaNavigationStripComponent(
                        index: max(0, min(currentSlice.totalCount - 1 - index, currentSlice.totalCount - 1)),
                        count: currentSlice.totalCount
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)
                )
                if let navigationStripView = self.navigationStrip.view {
                    if navigationStripView.superview == nil {
                        self.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: contentFrame.minX + navigationStripSideInset, y: contentFrame.minY + navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)))
                }
                
                if let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                    let inlineActionsSize = self.inlineActions.update(
                        transition: transition,
                        component: AnyComponent(StoryActionsComponent(
                            items: [
                                StoryActionsComponent.Item(
                                    kind: .like,
                                    isActivated: focusedItem.hasLike
                                ),
                                StoryActionsComponent.Item(
                                    kind: .share,
                                    isActivated: false
                                )
                            ],
                            action: { [weak self] item in
                                guard let self else {
                                    return
                                }
                                self.performInlineAction(item: item)
                            }
                        )),
                        environment: {},
                        containerSize: contentFrame.size
                    )
                    if let inlineActionsView = self.inlineActions.view {
                        if inlineActionsView.superview == nil {
                            self.addSubview(inlineActionsView)
                        }
                        transition.setFrame(view: inlineActionsView, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 10.0 - inlineActionsSize.width, y: contentFrame.maxY - 20.0 - inlineActionsSize.height), size: inlineActionsSize))
                        transition.setAlpha(view: inlineActionsView, alpha: inputPanelIsOverlay ? 0.0 : 1.0)
                    }
                }
            }
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            
            let itemLayout = ItemLayout(size: CGSize(width: contentFrame.width, height: availableSize.height - environment.statusBarHeight - 44.0 - bottomContentInsetWithoutInput))
            self.itemLayout = itemLayout
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
            }
            let bottomGradientHeight = inputPanelSize.height + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - environment.inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY), right: 0.0),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            transition.setFrame(layer: self.contentDimLayer, frame: contentFrame)
            transition.setAlpha(layer: self.contentDimLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = availableSize
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
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
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialContent: StoryContentItemSlice
    ) {
        self.context = context
        
        super.init(context: context, component: StoryContainerScreenComponent(
            context: context,
            initialContent: initialContent
        ), navigationBarAppearance: .none)
        
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
