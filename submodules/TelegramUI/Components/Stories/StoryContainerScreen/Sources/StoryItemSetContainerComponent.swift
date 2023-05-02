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
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecorder: InstantVideoController?
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
        audioRecorder: ManagedAudioRecorder?,
        videoRecorder: InstantVideoController?,
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
        self.audioRecorder = audioRecorder
        self.videoRecorder = videoRecorder
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
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecorder !== rhs.videoRecorder {
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
        let externalState = StoryContentItem.ExternalState()
        let view = ComponentView<StoryContentItem.Environment>()
        var currentProgress: Double = 0.0
        var requestedNext: Bool = false
        
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
    
    public final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private let contentContainerView: UIView
        private let topContentGradientLayer: SimpleGradientLayer
        private let bottomContentGradientLayer: SimpleGradientLayer
        private let contentDimLayer: SimpleLayer
        
        private let closeButton: HighlightableButton
        private let closeButtonIconView: UIImageView
        
        private let navigationStrip = ComponentView<MediaNavigationStripComponent.EnvironmentType>()
        private let inlineActions = ComponentView<Empty>()
        
        private var centerInfoItem: InfoItem?
        private var rightInfoItem: InfoItem?
        
        private let inputPanel = ComponentView<Empty>()
        private let footerPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var focusedItemId: AnyHashable?
        private var currentSlice: StoryContentItemSlice?
        private var currentSliceDisposable: Disposable?
        
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        private var preloadContexts: [AnyHashable: Disposable] = [:]
        
        private var reactionItems: [ReactionItem]?
        private var reactionContextNode: ReactionContextNode?
        
        private weak var actionSheet: ActionSheetController?
        private weak var contextController: ContextController?
        
        private var component: StoryItemSetContainerComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            
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
            
            self.contentContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            
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
                    self.reactionItems = nil
                    self.endEditing(true)
                } else if self.reactionItems != nil {
                    self.reactionItems = nil
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
                        self.contentContainerView.addSubview(view)
                    }
                    itemTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: itemLayout.size))
                    
                    if let view = view as? StoryContentItem.View {
                        view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.reactionItems != nil || self.actionSheet != nil || self.contextController != nil)
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
        
        private func updateIsProgressPaused() {
            guard let component = self.component else {
                return
            }
            for (_, visibleItem) in self.visibleItems {
                if let view = visibleItem.view.view {
                    if let view = view as? StoryContentItem.View {
                        view.setIsProgressPaused(self.inputPanelExternalState.isEditing || component.isProgressPaused || self.reactionItems != nil || self.actionSheet != nil || self.contextController != nil)
                    }
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
            
            //self.updatePreloads()
            
            self.component = component
            self.state = state
            
            var bottomContentInset: CGFloat
            if !component.safeInsets.bottom.isZero {
                bottomContentInset = component.safeInsets.bottom + 5.0
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
                        let _ = self
                        //self.performSendMessageAction()
                    },
                    setMediaRecordingActive: { [weak self] isActive, isVideo, sendAction in
                        guard let self else {
                            return
                        }
                        let _ = self
                        //self.setMediaRecordingActive(isActive: isActive, isVideo: isVideo, sendAction: sendAction)
                    },
                    attachmentAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        let _ = self
                        //self.presentAttachmentMenu(subject: .default)
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
                            
                            self.reactionItems = reactionItems
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                        })
                    },
                    audioRecorder: component.audioRecorder,
                    videoRecordingStatus: component.videoRecorder?.audioStatus
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let footerPanelSize = self.footerPanel.update(
                transition: transition,
                component: AnyComponent(StoryFooterPanelComponent(
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
                        }, action: { _, a in
                            a(.default)
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
                        controller.presentInGlobalOverlay(contextController)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let bottomContentInsetWithoutInput = bottomContentInset
            
            let inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if component.inputHeight < bottomContentInset + inputPanelSize.height {
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
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            
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
            
            if let reactionItems = self.reactionItems {
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
                    self.reactionContextNode = reactionContextNode
                    
                    reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.reactionItems = nil
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                        component.presentController(UndoOverlayController(
                            presentationData: presentationData,
                            content: .succeed(text: "Reaction Sent"),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ))
                    }
                }
                
                var animateReactionsIn = false
                if reactionContextNode.view.superview == nil {
                    animateReactionsIn = true
                    self.addSubnode(reactionContextNode)
                }
                
                let anchorRect = CGRect(origin: CGPoint(x: inputPanelFrame.maxX - 44.0 - 32.0, y: inputPanelFrame.minY), size: CGSize(width: 32.0, height: 32.0)).insetBy(dx: -4.0, dy: -4.0)
                reactionContextNodeTransition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                reactionContextNode.updateLayout(size: availableSize, insets: UIEdgeInsets(), anchorRect: anchorRect, isCoveredByInput: false, isAnimatingOut: false, transition: reactionContextNodeTransition.containedViewLayoutTransition)
                
                if animateReactionsIn {
                    reactionContextNode.animateIn(from: anchorRect)
                }
            } else {
                if let reactionContextNode = self.reactionContextNode {
                    self.reactionContextNode = nil
                    transition.setAlpha(view: reactionContextNode.view, alpha: 0.0, completion: { [weak reactionContextNode] _ in
                        reactionContextNode?.view.removeFromSuperview()
                    })
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
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            
            transition.setFrame(layer: self.contentDimLayer, frame: contentFrame)
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
                        self.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: contentFrame.minX + navigationStripSideInset, y: contentFrame.minY + navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)))
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
                                let _ = self
                                //self.performInlineAction(item: item)
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
                        
                        var inlineActionsAlpha: CGFloat = inputPanelIsOverlay ? 0.0 : 1.0
                        if component.audioRecorder != nil || component.videoRecorder != nil {
                            inlineActionsAlpha = 0.0
                        }
                        if self.reactionItems != nil {
                            inlineActionsAlpha = 0.0
                        }
                        
                        transition.setAlpha(view: inlineActionsView, alpha: inlineActionsAlpha)
                    }
                }
            }
            
            component.externalState.derivedBottomInset = availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY)
            
            return contentSize
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
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
