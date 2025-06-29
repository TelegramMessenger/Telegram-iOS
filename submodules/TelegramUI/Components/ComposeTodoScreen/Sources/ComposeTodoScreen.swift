import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import EntityKeyboard
import MultilineTextComponent
import UndoUI
import BundleIconComponent
import AnimatedTextComponent
import AudioToolbox
import ListSectionComponent
import PeerAllowedReactionsScreen
import AttachmentUI
import ListMultilineTextFieldItemComponent
import ListActionItemComponent
import ChatEntityKeyboardInputNode
import ChatPresentationInterfaceState
import EmojiSuggestionsComponent
import TextFormat
import TextFieldComponent
import ListComposePollOptionComponent
import Markdown
import PresentationDataUtils

final class ComposeTodoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let initialData: ComposeTodoScreen.InitialData
    let completion: (TelegramMediaTodo) -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        initialData: ComposeTodoScreen.InitialData,
        completion: @escaping (TelegramMediaTodo) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.initialData = initialData
        self.completion = completion
    }

    static func ==(lhs: ComposeTodoScreenComponent, rhs: ComposeTodoScreenComponent) -> Bool {
        return true
    }
    
    private final class TodoItem {
        let id: Int32
        let textInputState = TextFieldComponent.ExternalState()
        let textFieldTag = NSObject()
        var resetText: NSAttributedString?
        
        init(id: Int32) {
            self.id = id
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView

        private let todoTextSection = ComponentView<Empty>()
        
        private let todoItemsSectionHeader = ComponentView<Empty>()
        private let todoItemsSectionFooterContainer = UIView()
        private var todoItemsSectionFooter = ComponentView<Empty>()
        private var todoItemsSectionContainer: ListSectionContentView
        
        private let todoSettingsSection = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        private var previousHadInputHeight: Bool = false
        
        private var component: ComposeTodoScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let todoTextInputState = TextFieldComponent.ExternalState()
        private let todoTextFieldTag = NSObject()
        private var resetTodoText: NSAttributedString?
                
        private var nextTodoItemId: Int32 = 1
        private var todoItems: [TodoItem] = []
        private var currentTodoItemsLimitReached: Bool = false
                
        private var currentInputMode: ListComposePollOptionComponent.InputMode = .keyboard
        
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
        private var inputMediaNodeBackground = SimpleLayer()
        private var inputMediaNodeTargetTag: AnyObject?
        
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        
        private var currentEmojiSuggestionView: ComponentHostView<Empty>?
        
        private var currentEditingTag: AnyObject?
        
        private var reorderRecognizer: ReorderGestureRecognizer?
        private var reorderingItem: (id: AnyHashable, snapshotView: UIView, backgroundView: UIView, initialPosition: CGPoint, position: CGPoint)?
        
        var isAppendableByOthers = true
        var isCompletableByOthers = true
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.todoItemsSectionContainer = ListSectionContentView(frame: CGRect())
            self.todoItemsSectionContainer.automaticallyLayoutExternalContentBackgroundView = false
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            let reorderRecognizer = ReorderGestureRecognizer(
                shouldBegin: { [weak self] point in
                    guard let self, let (id, item) = self.item(at: point) else {
                        return (allowed: false, requiresLongPress: false, id: nil, item: nil)
                    }
                    return (allowed: true, requiresLongPress: false, id: id, item: item)
                },
                willBegin: { point in
                },
                began: { [weak self] item in
                    guard let self else {
                        return
                    }
                    self.setReorderingItem(item: item)
                },
                ended: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.setReorderingItem(item: nil)
                },
                moved: { [weak self] distance in
                    guard let self else {
                        return
                    }
                    self.moveReorderingItem(distance: distance)
                },
                isActiveUpdated: { _ in
                }
            )
            self.reorderRecognizer = reorderRecognizer
            self.addGestureRecognizer(reorderRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.inputMediaNodeDataDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        private func item(at point: CGPoint) -> (AnyHashable, ComponentView<Empty>)? {
            if self.scrollView.isDragging || self.scrollView.isDecelerating {
                return nil
            }
            
            let localPoint = self.todoItemsSectionContainer.convert(point, from: self)
            for (id, itemView) in self.todoItemsSectionContainer.itemViews {
                if let view = itemView.contents.view as? ListComposePollOptionComponent.View, !view.isRevealed && !view.currentText.isEmpty {
                    let viewFrame = view.convert(view.bounds, to: self.todoItemsSectionContainer)
                    let iconFrame = CGRect(origin: CGPoint(x: viewFrame.maxX - 40.0, y: viewFrame.minY), size: CGSize(width: viewFrame.height, height: viewFrame.height))
                    if iconFrame.contains(localPoint) {
                        return (id, itemView.contents)
                    }
                }
            }
            return nil
        }
        
        func setReorderingItem(item: AnyHashable?) {
            guard let environment = self.environment else {
                return
            }
            var mappedItem: (AnyHashable, ComponentView<Empty>)?
            for (id, itemView) in self.todoItemsSectionContainer.itemViews {
                if id == item {
                    mappedItem = (id, itemView.contents)
                    break
                }
            }
            if self.reorderingItem?.id != mappedItem?.0 {
                if let (id, visibleItem) = mappedItem, let view = visibleItem.view, !view.isHidden, let viewSuperview = view.superview, let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                    let mappedCenter = viewSuperview.convert(view.center, to: self.scrollView)
                    
                    let wrapperView = UIView()
                    wrapperView.alpha = 0.8
                    wrapperView.frame = CGRect(origin: mappedCenter.offsetBy(dx: -snapshotView.bounds.width / 2.0, dy: -snapshotView.bounds.height / 2.0), size: snapshotView.bounds.size)
                    
                    let theme = environment.theme.withModalBlocksBackground()
                    let backgroundView = UIImageView(image: generateReorderingBackgroundImage(backgroundColor: theme.list.itemBlocksBackgroundColor))
                    backgroundView.frame = wrapperView.bounds.insetBy(dx: -10.0, dy: -10.0)
                    snapshotView.frame = snapshotView.bounds
                    
                    wrapperView.addSubview(backgroundView)
                    wrapperView.addSubview(snapshotView)
                    
                    backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    wrapperView.transform = CGAffineTransformMakeScale(1.04, 1.04)
                    wrapperView.layer.animateScale(from: 1.0, to: 1.04, duration: 0.2)
                    
                    self.scrollView.addSubview(wrapperView)
                    self.reorderingItem = (id, wrapperView, backgroundView, mappedCenter, mappedCenter)
                    self.state?.updated()
                } else {
                    if let reorderingItem = self.reorderingItem {
                        self.reorderingItem = nil
                        for (itemId, itemView) in self.todoItemsSectionContainer.itemViews {
                            if itemId == reorderingItem.id, let view = itemView.contents.view {
                                let viewFrame = view.convert(view.bounds, to: self)
                                let transition = ComponentTransition.spring(duration: 0.3)
                                transition.setPosition(view: reorderingItem.snapshotView, position: viewFrame.center)
                                transition.setAlpha(view: reorderingItem.backgroundView, alpha: 0.0, completion: { _ in
                                    reorderingItem.snapshotView.removeFromSuperview()
                                    self.state?.updated()
                                })
                                transition.setScale(view: reorderingItem.snapshotView, scale: 1.0)
                                break
                            }
                        }
                    }
                }
            }
        }
        
        func moveReorderingItem(distance: CGPoint) {
            if let (id, snapshotView, backgroundView, initialPosition, _) = self.reorderingItem {
                let targetPosition = CGPoint(x: initialPosition.x + distance.x, y: initialPosition.y + distance.y)
                self.reorderingItem = (id, snapshotView, backgroundView, initialPosition, targetPosition)
                
                snapshotView.center = targetPosition
                
                for (itemId, itemView) in self.todoItemsSectionContainer.itemViews {
                    if itemId == id {
                        continue
                    }
                    if let view = itemView.contents.view {
                        let viewFrame = view.convert(view.bounds, to: self)
                        if viewFrame.contains(targetPosition) {
                            if let targetIndex = self.todoItems.firstIndex(where: { AnyHashable($0.id) == itemId }), let reorderingItem = self.todoItems.first(where: { AnyHashable($0.id) == id }) {
                                self.reorderIfPossible(item: reorderingItem, toIndex: targetIndex)
                            }
                            break
                        }
                    }
                }
            }
        }
        
        private func reorderIfPossible(item: TodoItem, toIndex: Int) {
            guard let component = self.component else {
                return
            }
            let targetItem = self.todoItems[toIndex]
            guard targetItem.textInputState.hasText else {
                return
            }
            var canEdit = true
            if let _ = component.initialData.existingTodo, !component.initialData.canEdit {
                canEdit = false
            }
            if !canEdit, let existingTodo = component.initialData.existingTodo, existingTodo.items.contains(where: { $0.id == targetItem.id }) {
                return
            }
            if let fromIndex = self.todoItems.firstIndex(where: { $0.id == item.id }) {
                self.todoItems[toIndex] = item
                self.todoItems[fromIndex] = targetItem
                
                HapticFeedback().tap()
                
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        func validatedInput() -> TelegramMediaTodo? {
            if self.todoTextInputState.text.string.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
                return nil
            }

            var mappedItems: [TelegramMediaTodo.Item] = []
            for todoItem in self.todoItems {
                if todoItem.textInputState.text.string.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
                    continue
                }
                var entities: [MessageTextEntity] = []
                for entity in generateChatInputTextEntities(todoItem.textInputState.text) {
                    switch entity.type {
                    case .CustomEmoji:
                        entities.append(entity)
                    default:
                        break
                    }
                }
                mappedItems.append(
                    TelegramMediaTodo.Item(
                        text: todoItem.textInputState.text.string,
                        entities: entities,
                        id: todoItem.id
                    )
                )
            }
            
            if mappedItems.count < 1 {
                return nil
            }
                
            var textEntities: [MessageTextEntity] = []
            for entity in generateChatInputTextEntities(self.todoTextInputState.text) {
                switch entity.type {
                case .CustomEmoji:
                    textEntities.append(entity)
                default:
                    break
                }
            }
            
            var flags: TelegramMediaTodo.Flags = []
            if self.isCompletableByOthers {
                flags.insert(.othersCanComplete)
                if self.isAppendableByOthers {
                    flags.insert(.othersCanAppend)
                }
            }
            
            return TelegramMediaTodo(
                flags: flags,
                text: self.todoTextInputState.text.string,
                textEntities: textEntities,
                items: mappedItems
            )
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            
            let _ = component
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.endEditing(true)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, self.scrollView.contentOffset.y / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
        }
        
        func isPanGestureEnabled() -> Bool {
            if self.inputMediaNode != nil {
                return false
            }
            
            for (_, state) in self.collectTextInputStates() {
                if state.isEditing {
                    return false
                }
            }
            
            return true
        }
        
        private func updateInputMediaNode(
            component: ComposeTodoScreenComponent,
            availableSize: CGSize,
            bottomInset: CGFloat,
            inputHeight: CGFloat,
            effectiveInputHeight: CGFloat,
            metrics: LayoutMetrics,
            deviceMetrics: DeviceMetrics,
            transition: ComponentTransition
        ) -> CGFloat {
            let bottomInset: CGFloat = bottomInset + 8.0
            let bottomContainerInset: CGFloat = 0.0
            let needsInputActivation: Bool = !"".isEmpty
            
            var height: CGFloat = 0.0
            if case .emoji = self.currentInputMode, let inputData = self.inputMediaNodeData {
                if let updatedTag = self.collectTextInputStates().first(where: { $1.isEditing })?.view.currentTag {
                    self.inputMediaNodeTargetTag = updatedTag
                }
                
                let inputMediaNode: ChatEntityKeyboardInputNode
                var inputMediaNodeTransition = transition
                var animateIn = false
                if let current = self.inputMediaNode {
                    inputMediaNode = current
                } else {
                    animateIn = true
                    inputMediaNodeTransition = inputMediaNodeTransition.withAnimation(.none)
                    inputMediaNode = ChatEntityKeyboardInputNode(
                        context: component.context,
                        currentInputData: inputData,
                        updatedInputData: self.inputMediaNodeDataPromise.get(),
                        defaultToEmojiTab: true,
                        opaqueTopPanelBackground: false,
                        useOpaqueTheme: true,
                        interaction: self.inputMediaInteraction,
                        chatPeerId: nil,
                        stateContext: self.inputMediaNodeStateContext
                    )
                    inputMediaNode.clipsToBounds = true
                    
                    inputMediaNode.externalTopPanelContainerImpl = nil
                    inputMediaNode.useExternalSearchContainer = true
                    if inputMediaNode.view.superview == nil {
                        self.inputMediaNodeBackground.removeAllAnimations()
                        self.layer.addSublayer(self.inputMediaNodeBackground)
                        self.addSubview(inputMediaNode.view)
                    }
                    self.inputMediaNode = inputMediaNode
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let presentationInterfaceState = ChatPresentationInterfaceState(
                    chatWallpaper: .builtin(WallpaperSettings()),
                    theme: presentationData.theme,
                    strings: presentationData.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    limitsConfiguration: component.context.currentLimitsConfiguration.with { $0 },
                    fontSize: presentationData.chatFontSize,
                    bubbleCorners: presentationData.chatBubbleCorners,
                    accountPeerId: component.context.account.peerId,
                    mode: .standard(.default),
                    chatLocation: .peer(id: component.context.account.peerId),
                    subject: nil,
                    peerNearbyData: nil,
                    greetingData: nil,
                    pendingUnpinnedAllMessages: false,
                    activeGroupCallInfo: nil,
                    hasActiveGroupCall: false,
                    importState: nil,
                    threadData: nil,
                    isGeneralThreadClosed: nil,
                    replyMessage: nil,
                    accountPeerColor: nil,
                    businessIntro: nil
                )
                
                self.inputMediaNodeBackground.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor.cgColor
                
                let heightAndOverflow = inputMediaNode.updateLayout(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, bottomInset: bottomInset, standardInputHeight: deviceMetrics.standardInputHeight(inLandscape: false), inputHeight: inputHeight < 100.0 ? inputHeight - bottomContainerInset : inputHeight, maximumHeight: availableSize.height, inputPanelHeight: 0.0, transition: .immediate, interfaceState: presentationInterfaceState, layoutMetrics: metrics, deviceMetrics: deviceMetrics, isVisible: true, isExpanded: false)
                let inputNodeHeight = heightAndOverflow.0
                let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputNodeHeight), size: CGSize(width: availableSize.width, height: inputNodeHeight))
                
                let inputNodeBackgroundFrame = CGRect(origin: CGPoint(x: inputNodeFrame.minX, y: inputNodeFrame.minY - 6.0), size: CGSize(width: inputNodeFrame.width, height: inputNodeFrame.height + 6.0))
                
                if needsInputActivation {
                    let inputNodeFrame = inputNodeFrame.offsetBy(dx: 0.0, dy: inputNodeHeight)
                    ComponentTransition.immediate.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    ComponentTransition.immediate.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                }
                
                if animateIn {
                    var targetFrame = inputNodeFrame
                    targetFrame.origin.y = availableSize.height
                    inputMediaNodeTransition.setFrame(layer: inputMediaNode.layer, frame: targetFrame)
                    
                    let inputNodeBackgroundTargetFrame = CGRect(origin: CGPoint(x: targetFrame.minX, y: targetFrame.minY - 6.0), size: CGSize(width: targetFrame.width, height: targetFrame.height + 6.0))
                    
                    inputMediaNodeTransition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundTargetFrame)
                    
                    transition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    transition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                } else {
                    inputMediaNodeTransition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    inputMediaNodeTransition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                }
                
                height = heightAndOverflow.0
            } else {
                self.inputMediaNodeTargetTag = nil
                
                if let inputMediaNode = self.inputMediaNode {
                    self.inputMediaNode = nil
                    var targetFrame = inputMediaNode.frame
                    targetFrame.origin.y = availableSize.height
                    transition.setFrame(view: inputMediaNode.view, frame: targetFrame, completion: { [weak inputMediaNode] _ in
                        if let inputMediaNode {
                            Queue.mainQueue().after(0.3) {
                                inputMediaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak inputMediaNode] _ in
                                    inputMediaNode?.view.removeFromSuperview()
                                })
                            }
                        }
                    })
                    transition.setFrame(layer: self.inputMediaNodeBackground, frame: targetFrame, completion: { [weak self] _ in
                        Queue.mainQueue().after(0.3) {
                            guard let self else {
                                return
                            }
                            if self.currentInputMode == .keyboard {
                                self.inputMediaNodeBackground.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak self] finished in
                                    guard let self else {
                                        return
                                    }
                                    
                                    if finished {
                                        self.inputMediaNodeBackground.removeFromSuperlayer()
                                    }
                                    self.inputMediaNodeBackground.removeAllAnimations()
                                })
                            }
                        }
                    })
                }
            }
            
            /*if needsInputActivation {
                needsInputActivation = false
                Queue.mainQueue().justDispatch {
                    inputPanelView.activateInput()
                }
            }*/
            
            if let controller = self.environment?.controller() as? ComposeTodoScreen {
                let isTabBarVisible = self.inputMediaNode == nil
                DispatchQueue.main.async { [weak controller] in
                    controller?.updateTabBarVisibility(isTabBarVisible, transition.containedViewLayoutTransition)
                }
            }
            
            return height
        }
        
        private func collectTextInputStates() -> [(view: ListComposePollOptionComponent.View, state: TextFieldComponent.ExternalState)] {
            var textInputStates: [(view: ListComposePollOptionComponent.View, state: TextFieldComponent.ExternalState)] = []
            if let textInputView = self.todoTextSection.findTaggedView(tag: self.todoTextFieldTag) as? ListComposePollOptionComponent.View {
                textInputStates.append((textInputView, self.todoTextInputState))
            }
            for todoItem in self.todoItems {
                if let textInputView = findTaggedComponentViewImpl(view: self.todoItemsSectionContainer, tag: todoItem.textFieldTag) as? ListComposePollOptionComponent.View {
                    textInputStates.append((textInputView, todoItem.textInputState))
                }
            }
            return textInputStates
        }
        
        func update(component: ComposeTodoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            var alphaTransition = transition
            if !transition.animation.isImmediate {
                alphaTransition = alphaTransition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let theme = environment.theme.withModalBlocksBackground()
            
            let isFirstTime = self.component == nil
            if self.component == nil {
                if let existingTodo = component.initialData.existingTodo {
                    self.resetTodoText = chatInputStateStringWithAppliedEntities(existingTodo.text, entities: existingTodo.textEntities)
                    
                    for item in existingTodo.items {
                        let todoItem = ComposeTodoScreenComponent.TodoItem(
                            id: item.id
                        )
                        todoItem.resetText = chatInputStateStringWithAppliedEntities(item.text, entities: item.entities)
                        self.todoItems.append(todoItem)
                    }
                    self.nextTodoItemId = (existingTodo.items.max(by: { $0.id < $1.id })?.id ?? 0) + 1
                    
                    self.isAppendableByOthers = existingTodo.flags.contains(.othersCanAppend)
                    self.isCompletableByOthers = existingTodo.flags.contains(.othersCanComplete)
                } else {
                    self.todoItems.append(ComposeTodoScreenComponent.TodoItem(
                        id: self.nextTodoItemId
                    ))
                    self.nextTodoItemId += 1
                    self.todoItems.append(ComposeTodoScreenComponent.TodoItem(
                        id: self.nextTodoItemId
                    ))
                    self.nextTodoItemId += 1
                }
                
                self.inputMediaNodeDataPromise.set(
                    ChatEntityKeyboardInputNode.inputData(
                        context: component.context,
                        chatPeerId: nil,
                        areCustomEmojiEnabled: true,
                        hasTrending: false,
                        hasSearch: true,
                        hasStickers: false,
                        hasGifs: false,
                        hideBackground: true,
                        sendGif: nil
                    )
                )
                self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.inputMediaNodeData = value
                })
                
                self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
                    sendSticker: { _, _, _, _, _, _, _, _, _ in
                        return false
                    },
                    sendEmoji: { _, _, _ in
                        let _ = self
                    },
                    sendGif: { _, _, _, _, _ in
                        return false
                    },
                    sendBotContextResultAsGif: { _, _ , _, _, _, _ in
                        return false
                    },
                    updateChoosingSticker: { _ in
                    },
                    switchToTextInput: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.currentInputMode = .keyboard
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    dismissTextInput: {
                    },
                    insertText: { [weak self] text in
                        guard let self else {
                            return
                        }
                        
                        var found = false
                        for (textInputView, externalState) in self.collectTextInputStates() {
                            if externalState.isEditing {
                                textInputView.insertText(text: text)
                                found = true
                                break
                            }
                        }
                        if !found, let inputMediaNodeTargetTag = self.inputMediaNodeTargetTag {
                            for (textInputView, _) in self.collectTextInputStates() {
                                if textInputView.currentTag === inputMediaNodeTargetTag {
                                    textInputView.insertText(text: text)
                                    found = true
                                    break
                                }
                            }
                        }
                    },
                    backwardsDeleteText: { [weak self] in
                        guard let self else {
                            return
                        }
                        var found = false
                        for (textInputView, externalState) in self.collectTextInputStates() {
                            if externalState.isEditing {
                                textInputView.backwardsDeleteText()
                                found = true
                                break
                            }
                        }
                        if !found, let inputMediaNodeTargetTag = self.inputMediaNodeTargetTag {
                            for (textInputView, _) in self.collectTextInputStates() {
                                if textInputView.currentTag === inputMediaNodeTargetTag {
                                    textInputView.backwardsDeleteText()
                                    found = true
                                    break
                                }
                            }
                        }
                    },
                    openStickerEditor: {
                    },
                    presentController: { [weak self] c, a in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    presentGlobalOverlayController: { [weak self] c, a in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.presentInGlobalOverlay(c, with: a)
                    },
                    getNavigationController: { [weak self] () -> NavigationController? in
                        guard let self else {
                            return nil
                        }
                        guard let controller = self.environment?.controller() as? ComposeTodoScreen else {
                            return nil
                        }
                        
                        if let navigationController = controller.navigationController as? NavigationController {
                            return navigationController
                        }
                        if let parentController = controller.parentController() {
                            return parentController.navigationController as? NavigationController
                        }
                        return nil
                    },
                    requestLayout: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: ComponentTransition(transition))
                        }
                    }
                )
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            if themeUpdated {
                self.backgroundColor = theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            var canEdit = true
            if let _ = component.initialData.existingTodo, !component.initialData.canEdit {
                canEdit = false
            }
            
            var todoTextSectionItems: [AnyComponentWithIdentity<Empty>] = []
            todoTextSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListComposePollOptionComponent(
                externalState: self.todoTextInputState,
                context: component.context,
                theme: theme,
                strings: environment.strings,
                isEnabled: canEdit,
                resetText: self.resetTodoText.flatMap { resetText in
                    return ListComposePollOptionComponent.ResetText(value: resetText)
                },
                assumeIsEditing: self.inputMediaNodeTargetTag === self.todoTextFieldTag,
                characterLimit: component.initialData.maxTodoTextLength,
                emptyLineHandling: .allowed,
                returnKeyAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    if !self.todoItems.isEmpty {
                        if let todoItemView = self.todoItemsSectionContainer.itemViews[self.todoItems[0].id] {
                            if let todoItemComponentView = todoItemView.contents.view as? ListComposePollOptionComponent.View {
                                todoItemComponentView.activateInput()
                            }
                        }
                    }
                },
                backspaceKeyAction: nil,
                selection: nil,
                inputMode: self.currentInputMode,
                toggleInputMode: { [weak self] in
                    guard let self else {
                        return
                    }
                    switch self.currentInputMode {
                    case .keyboard:
                        self.currentInputMode = .emoji
                    case .emoji:
                        self.currentInputMode = .keyboard
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                },
                tag: self.todoTextFieldTag
            ))))
            self.resetTodoText = nil
            
            let todoTextSectionSize = self.todoTextSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    header: nil,
                    footer: nil,
                    items: todoTextSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let todoTextSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: todoTextSectionSize)
            if let todoTextSectionView = self.todoTextSection.view as? ListSectionComponent.View {
                if todoTextSectionView.superview == nil {
                    self.scrollView.addSubview(todoTextSectionView)
                    self.todoTextSection.parentState = state
                }
                transition.setFrame(view: todoTextSectionView, frame: todoTextSectionFrame)
                
                if let itemView = todoTextSectionView.itemView(id: 0) as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: environment.strings.CreateTodo_TitlePlaceholder, size: itemView.bounds.size, transition: .immediate)
                }
            }
            contentHeight += todoTextSectionSize.height
            contentHeight += sectionSpacing
            
            var todoItemsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            var todoItemsSectionReadyItems: [ListSectionContentView.ReadyItem] = []
            
            let processTodoItemItem: (Int) -> Void = { i in
                let todoItem = self.todoItems[i]
                
                let optionId = todoItem.id
                
                var isEnabled = true
                if !canEdit, let existingTodo = component.initialData.existingTodo, existingTodo.items.contains(where: { $0.id == todoItem.id }) {
                    isEnabled = false
                }
                
                var canDelete = isEnabled
                if i == self.todoItems.count - 1 {
                    canDelete = false
                }
                
                todoItemsSectionItems.append(AnyComponentWithIdentity(id: todoItem.id, component: AnyComponent(ListComposePollOptionComponent(
                    externalState: todoItem.textInputState,
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    isEnabled: isEnabled,
                    resetText: todoItem.resetText.flatMap { resetText in
                        return ListComposePollOptionComponent.ResetText(value: resetText)
                    },
                    assumeIsEditing: self.inputMediaNodeTargetTag === todoItem.textFieldTag,
                    characterLimit: component.initialData.maxTodoItemLength,
                    canReorder: isEnabled,
                    emptyLineHandling: .notAllowed,
                    returnKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let index = self.todoItems.firstIndex(where: { $0.id == optionId }) {
                            if index == self.todoItems.count - 1 {
                                self.endEditing(true)
                            } else {
                                if let todoItemView = self.todoItemsSectionContainer.itemViews[self.todoItems[index + 1].id] {
                                    if let todoItemComponentView = todoItemView.contents.view as? ListComposePollOptionComponent.View {
                                        todoItemComponentView.activateInput()
                                    }
                                }
                            }
                        }
                    },
                    backspaceKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let index = self.todoItems.firstIndex(where: { $0.id == optionId }) {
                            if index == 0 {
                                if let textInputView = self.todoTextSection.findTaggedView(tag: self.todoTextFieldTag) as? ListComposePollOptionComponent.View {
                                    textInputView.activateInput()
                                }
                            } else {
                                if let todoItemView = self.todoItemsSectionContainer.itemViews[self.todoItems[index - 1].id] {
                                    if let todoItemComponentView = todoItemView.contents.view as? ListComposePollOptionComponent.View {
                                        todoItemComponentView.activateInput()
                                    }
                                }
                            }
                        }
                    },
                    selection: nil,
                    inputMode: self.currentInputMode,
                    toggleInputMode: { [weak self] in
                        guard let self else {
                            return
                        }
                        switch self.currentInputMode {
                        case .keyboard:
                            self.currentInputMode = .emoji
                        case .emoji:
                            self.currentInputMode = .keyboard
                        }
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    deleteAction: canDelete ? { [weak self] in
                        guard let self else {
                            return
                        }
                        self.todoItems.removeAll(where: { $0.id == optionId })
                        self.state?.updated(transition: .spring(duration: 0.4))
                    } : nil,
                    paste: { [weak self] data in
                        guard let self else {
                            return
                        }
                        if case let .text(text) = data {
                            let lines = text.string.components(separatedBy: "\n")
                            if !lines.isEmpty {
                                self.endEditing(true)
                                var i = 0
                                for line in lines {
                                    if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        continue
                                    }
                                    let line = String(line.prefix(component.initialData.maxTodoItemLength))
                                    if i < self.todoItems.count {
                                        self.todoItems[i].resetText = NSAttributedString(string: line)
                                    } else {
                                        if self.todoItems.count < component.initialData.maxTodoItemsCount {
                                            let todoItem = ComposeTodoScreenComponent.TodoItem(
                                                id: self.nextTodoItemId
                                            )
                                            todoItem.resetText = NSAttributedString(string: line)
                                            self.todoItems.append(todoItem)
                                            self.nextTodoItemId += 1
                                        }
                                    }
                                    i += 1
                                }
                                self.state?.updated()
                            }
                        }
                    },
                    tag: todoItem.textFieldTag
                ))))
                
                let item = todoItemsSectionItems[i]
                let itemId = item.id
                
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.todoItemsSectionContainer.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ListSectionContentView.ItemView()
                    self.todoItemsSectionContainer.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
            
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                
                todoItemsSectionReadyItems.append(ListSectionContentView.ReadyItem(
                    id: itemId,
                    itemView: itemView,
                    size: itemSize,
                    transition: itemTransition
                ))
                
                var isReordering = false
                if let reorderingItem = self.reorderingItem, itemId == reorderingItem.id {
                    isReordering = true
                }
                itemView.contents.view?.isHidden = isReordering
            }
            
            for i in 0 ..< self.todoItems.count {
                processTodoItemItem(i)
            }
            
            if self.todoItems.count > 2 {
                let lastOption = self.todoItems[self.todoItems.count - 1]
                let secondToLastOption = self.todoItems[self.todoItems.count - 2]
                
                if !lastOption.textInputState.isEditing && lastOption.textInputState.text.length == 0 && secondToLastOption.textInputState.text.length == 0 {
                    self.todoItems.removeLast()
                    todoItemsSectionItems.removeLast()
                    todoItemsSectionReadyItems.removeLast()
                }
            }
            
            if self.todoItems.count < component.initialData.maxTodoItemsCount, let lastOption = self.todoItems.last {
                if lastOption.textInputState.text.length != 0 {
                    self.todoItems.append(TodoItem(id: self.nextTodoItemId))
                    self.nextTodoItemId += 1
                    processTodoItemItem(self.todoItems.count - 1)
                }
            }
            
            var focusedIndex: Int?
            if isFirstTime, let focusedId = component.initialData.focusedId {
                focusedIndex = self.todoItems.firstIndex(where: { $0.id == focusedId })
            }
            
            for i in 0 ..< todoItemsSectionReadyItems.count {
                var activate = false
                let placeholder: String
                if i == todoItemsSectionReadyItems.count - 1 {
                    placeholder = environment.strings.CreateTodo_AddTaskPlaceholder
                    if isFirstTime, component.initialData.append {
                        activate = true
                    }
                } else {
                    placeholder = environment.strings.CreateTodo_TaskPlaceholder
                }
                
                if let focusedIndex, i == focusedIndex {
                    activate = true
                }
                
                if let itemView = todoItemsSectionReadyItems[i].itemView.contents.view as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: placeholder, size: todoItemsSectionReadyItems[i].size, transition: todoItemsSectionReadyItems[i].transition)
                    
                    if activate {
                        itemView.activateInput()
                    }
                }
            }
            
            let todoItemsSectionUpdateResult = self.todoItemsSectionContainer.update(
                configuration: ListSectionContentView.Configuration(
                    theme: theme,
                    displaySeparators: true,
                    extendsItemHighlightToSection: false,
                    background: .all
                ),
                width: availableSize.width - sideInset * 2.0,
                leftInset: 0.0,
                readyItems: todoItemsSectionReadyItems,
                transition: transition
            )
            
            let sectionHeaderSideInset: CGFloat = 16.0
            let todoItemsSectionHeaderSize = self.todoItemsSectionHeader.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.CreateTodo_TodoTitle,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sectionHeaderSideInset * 2.0, height: 1000.0)
            )
            let todoItemsSectionHeaderFrame = CGRect(origin: CGPoint(x: sideInset + sectionHeaderSideInset, y: contentHeight), size: todoItemsSectionHeaderSize)
            if let todoItemsSectionHeaderView = self.todoItemsSectionHeader.view {
                if todoItemsSectionHeaderView.superview == nil {
                    todoItemsSectionHeaderView.layer.anchorPoint = CGPoint()
                    self.scrollView.addSubview(todoItemsSectionHeaderView)
                }
                transition.setPosition(view: todoItemsSectionHeaderView, position: todoItemsSectionHeaderFrame.origin)
                todoItemsSectionHeaderView.bounds = CGRect(origin: CGPoint(), size: todoItemsSectionHeaderFrame.size)
            }
            contentHeight += todoItemsSectionHeaderSize.height
            contentHeight += 7.0
            
            let todoItemsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: todoItemsSectionUpdateResult.size)
            if self.todoItemsSectionContainer.superview == nil {
                self.scrollView.addSubview(self.todoItemsSectionContainer.externalContentBackgroundView)
                self.scrollView.addSubview(self.todoItemsSectionContainer)
            }
            transition.setFrame(view: self.todoItemsSectionContainer, frame: todoItemsSectionFrame)
            transition.setFrame(view: self.todoItemsSectionContainer.externalContentBackgroundView, frame: todoItemsSectionUpdateResult.backgroundFrame.offsetBy(dx: todoItemsSectionFrame.minX, dy: todoItemsSectionFrame.minY))
            contentHeight += todoItemsSectionUpdateResult.size.height
            
            contentHeight += 7.0
            
            let todoItemsLimitReached = self.todoItems.count >= component.initialData.maxTodoItemsCount
            var animateTodoItemsFooterIn = false
            var todoItemsFooterTransition = transition
            if self.currentTodoItemsLimitReached != todoItemsLimitReached {
                self.currentTodoItemsLimitReached = todoItemsLimitReached
                if let todoItemsSectionFooterView = self.todoItemsSectionFooter.view {
                    animateTodoItemsFooterIn = true
                    todoItemsFooterTransition = todoItemsFooterTransition.withAnimation(.none)
                    alphaTransition.setAlpha(view: todoItemsSectionFooterView, alpha: 0.0, completion: { [weak todoItemsSectionFooterView] _ in
                        todoItemsSectionFooterView?.removeFromSuperview()
                    })
                    self.todoItemsSectionFooter = ComponentView()
                }
            }
            
            let todoItemsComponent: AnyComponent<Empty>
            if todoItemsLimitReached {
                todoItemsFooterTransition = todoItemsFooterTransition.withAnimation(.none)

                let textFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
                let boldTextFont = Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize)
                let textColor = theme.list.freeTextColor
                todoItemsComponent = AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: environment.strings.CreateTodo_TaskCountLimitReached,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                            link: MarkdownAttributeSet(font: textFont, textColor: theme.list.itemAccentColor),
                            linkAttribute: { contents in
                                return (TelegramTextAttributes.URL, contents)
                            }
                        )
                    ),
                    maximumNumberOfLines: 0,
                    highlightColor: presentationData.theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let controller = component.context.sharedContext.makePremiumIntroController(
                            context: component.context,
                            source: .chatsPerFolder,
                            forceDark: false,
                            dismissed: nil
                        )
                        (self.environment?.controller() as? AttachmentContainable)?.parentController()?.push(controller)
                    }
                ))
            } else {
                let remainingCount = component.initialData.maxTodoItemsCount - self.todoItems.count
                let rawString = environment.strings.CreateTodo_TaskCountFooterFormat(Int32(remainingCount))
                
                var todoItemsFooterItems: [AnimatedTextComponent.Item] = []
                if let range = rawString.range(of: "{count}") {
                    if range.lowerBound != rawString.startIndex {
                        todoItemsFooterItems.append(AnimatedTextComponent.Item(
                            id: 0,
                            isUnbreakable: true,
                            content: .text(String(rawString[rawString.startIndex ..< range.lowerBound]))
                        ))
                    }
                    todoItemsFooterItems.append(AnimatedTextComponent.Item(
                        id: 1,
                        isUnbreakable: true,
                        content: .number(remainingCount, minDigits: 1)
                    ))
                    if range.upperBound != rawString.endIndex {
                        todoItemsFooterItems.append(AnimatedTextComponent.Item(
                            id: 2,
                            isUnbreakable: true,
                            content: .text(String(rawString[range.upperBound ..< rawString.endIndex]))
                        ))
                    }
                }
                
                todoItemsComponent = AnyComponent(AnimatedTextComponent(
                    font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                    color: theme.list.freeTextColor,
                    items: todoItemsFooterItems
                ))
            }
            
            let todoItemsSectionFooterSize = self.todoItemsSectionFooter.update(
                transition: todoItemsFooterTransition,
                component: todoItemsComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sectionHeaderSideInset * 2.0, height: 1000.0)
            )
            let todoItemsSectionFooterFrame = CGRect(origin: CGPoint(x: sideInset + sectionHeaderSideInset, y: contentHeight), size: todoItemsSectionFooterSize)
            
            if self.todoItemsSectionFooterContainer.superview == nil {
                self.scrollView.addSubview(self.todoItemsSectionFooterContainer)
            }
            transition.setFrame(view: self.todoItemsSectionFooterContainer, frame: todoItemsSectionFooterFrame)
            
            if let todoItemsSectionFooterView = self.todoItemsSectionFooter.view {
                if todoItemsSectionFooterView.superview == nil {
                    todoItemsSectionFooterView.layer.anchorPoint = CGPoint()
                    self.todoItemsSectionFooterContainer.addSubview(todoItemsSectionFooterView)
                }
                todoItemsFooterTransition.setPosition(view: todoItemsSectionFooterView, position: CGPoint())
                todoItemsSectionFooterView.bounds = CGRect(origin: CGPoint(), size: todoItemsSectionFooterFrame.size)
                if animateTodoItemsFooterIn && !transition.animation.isImmediate {
                    alphaTransition.animateAlpha(view: todoItemsSectionFooterView, from: 0.0, to: 1.0)
                }
            }
            contentHeight += todoItemsSectionFooterSize.height
            contentHeight += sectionSpacing
            
            var todoSettingsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if canEdit {
                todoSettingsSectionItems.append(AnyComponentWithIdentity(id: "completable", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreateTodo_AllowOthersToComplete,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isCompletableByOthers, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isCompletableByOthers = !self.isCompletableByOthers
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
                
                if self.isCompletableByOthers {
                    todoSettingsSectionItems.append(AnyComponentWithIdentity(id: "editable", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.CreateTodo_AllowOthersToAppend,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isAppendableByOthers, action: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.isAppendableByOthers = !self.isAppendableByOthers
                            self.state?.updated(transition: .spring(duration: 0.4))
                        })),
                        action: nil
                    ))))
                }
            }
            
            if !todoSettingsSectionItems.isEmpty {
                let todoSettingsSectionSize = self.todoSettingsSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        header: nil,
                        footer: nil,
                        items: todoSettingsSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let todoSettingsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: todoSettingsSectionSize)
                if let todoSettingsSectionView = self.todoSettingsSection.view {
                    if todoSettingsSectionView.superview == nil {
                        self.scrollView.addSubview(todoSettingsSectionView)
                        self.todoSettingsSection.parentState = state
                    }
                    transition.setFrame(view: todoSettingsSectionView, frame: todoSettingsSectionFrame)
                }
                contentHeight += todoSettingsSectionSize.height
            }
                      
            var inputHeight: CGFloat = 0.0
            inputHeight += self.updateInputMediaNode(
                component: component,
                availableSize: availableSize,
                bottomInset: environment.safeInsets.bottom,
                inputHeight: 0.0,
                effectiveInputHeight: environment.deviceMetrics.standardInputHeight(inLandscape: false),
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                transition: transition
            )
            if self.inputMediaNode == nil {
                inputHeight = environment.inputHeight
            }
            
            let textInputStates = self.collectTextInputStates()
            
            let previousEditingTag = self.currentEditingTag
            let isEditing: Bool
            if let index = textInputStates.firstIndex(where: { $0.state.isEditing }) {
                isEditing = true
                self.currentEditingTag = textInputStates[index].view.currentTag
            } else {
                isEditing = false
                self.currentEditingTag = nil
            }
            
            if let (_, suggestionTextInputState) = textInputStates.first(where: { $0.state.isEditing && $0.state.currentEmojiSuggestion != nil }), let emojiSuggestion = suggestionTextInputState.currentEmojiSuggestion, emojiSuggestion.disposable == nil {
                emojiSuggestion.disposable = (EmojiSuggestionsComponent.suggestionData(context: component.context, isSavedMessages: false, query: emojiSuggestion.position.value)
                |> deliverOnMainQueue).start(next: { [weak self, weak suggestionTextInputState, weak emojiSuggestion] result in
                    guard let self, let suggestionTextInputState, let emojiSuggestion, suggestionTextInputState.currentEmojiSuggestion === emojiSuggestion else {
                        return
                    }
                    
                    emojiSuggestion.value = result
                    self.state?.updated()
                })
            }
            
            for (_, suggestionTextInputState) in textInputStates {
                var hasTrackingView = suggestionTextInputState.hasTrackingView
                if let currentEmojiSuggestion = suggestionTextInputState.currentEmojiSuggestion, let value = currentEmojiSuggestion.value as? [TelegramMediaFile], value.isEmpty {
                    hasTrackingView = false
                }
                if !suggestionTextInputState.isEditing {
                    hasTrackingView = false
                }
                
                if !hasTrackingView {
                    if let currentEmojiSuggestion = suggestionTextInputState.currentEmojiSuggestion {
                        suggestionTextInputState.currentEmojiSuggestion = nil
                        currentEmojiSuggestion.disposable?.dispose()
                    }
                    
                    if let currentEmojiSuggestionView = self.currentEmojiSuggestionView {
                        self.currentEmojiSuggestionView = nil
                        
                        currentEmojiSuggestionView.alpha = 0.0
                        currentEmojiSuggestionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak currentEmojiSuggestionView] _ in
                            currentEmojiSuggestionView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if let (suggestionTextInputView, suggestionTextInputState) = textInputStates.first(where: { $0.state.isEditing && $0.state.currentEmojiSuggestion != nil }), let emojiSuggestion = suggestionTextInputState.currentEmojiSuggestion, let value = emojiSuggestion.value as? [TelegramMediaFile] {
                let currentEmojiSuggestionView: ComponentHostView<Empty>
                if let current = self.currentEmojiSuggestionView {
                    currentEmojiSuggestionView = current
                } else {
                    currentEmojiSuggestionView = ComponentHostView<Empty>()
                    self.currentEmojiSuggestionView = currentEmojiSuggestionView
                    self.addSubview(currentEmojiSuggestionView)
                    
                    currentEmojiSuggestionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            
                let globalPosition: CGPoint
                if let textView = suggestionTextInputView.textFieldView {
                    globalPosition = textView.convert(emojiSuggestion.localPosition, to: self)
                } else {
                    globalPosition = .zero
                }
                
                let sideInset: CGFloat = 7.0
                
                let viewSize = currentEmojiSuggestionView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiSuggestionsComponent(
                        context: component.context,
                        userLocation: .other,
                        theme: EmojiSuggestionsComponent.Theme(theme: theme, backgroundColor: theme.list.itemBlocksBackgroundColor),
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        files: value,
                        action: { [weak self, weak suggestionTextInputView, weak suggestionTextInputState] file in
                            guard let self, let suggestionTextInputView, let suggestionTextInputState, let textView = suggestionTextInputView.textFieldView, let currentEmojiSuggestion = suggestionTextInputState.currentEmojiSuggestion else {
                                return
                            }
                            
                            let _ = self
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            let inputState = textView.getInputState()
                            let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                            
                            var text: String?
                            var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                            loop: for attribute in file.attributes {
                                switch attribute {
                                case let .CustomEmoji(_, _, displayText, _):
                                    text = displayText
                                    emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            if let emojiAttribute = emojiAttribute, let text = text {
                                let replacementText = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute])
                                
                                let range = currentEmojiSuggestion.position.range
                                let previousText = inputText.attributedSubstring(from: range)
                                inputText.replaceCharacters(in: range, with: replacementText)
                                
                                var replacedUpperBound = range.lowerBound
                                while true {
                                    if inputText.attributedSubstring(from: NSRange(location: 0, length: replacedUpperBound)).string.hasSuffix(previousText.string) {
                                        let replaceRange = NSRange(location: replacedUpperBound - previousText.length, length: previousText.length)
                                        if replaceRange.location < 0 {
                                            break
                                        }
                                        let adjacentString = inputText.attributedSubstring(from: replaceRange)
                                        if adjacentString.string != previousText.string || adjacentString.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) != nil {
                                            break
                                        }
                                        inputText.replaceCharacters(in: replaceRange, with: NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: emojiAttribute.interactivelySelectedFromPackId, fileId: emojiAttribute.fileId, file: emojiAttribute.file)]))
                                        replacedUpperBound = replaceRange.lowerBound
                                    } else {
                                        break
                                    }
                                }
                                
                                let selectionPosition = range.lowerBound + (replacementText.string as NSString).length
                                textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                
                let viewFrame = CGRect(origin: CGPoint(x: min(availableSize.width - sideInset - viewSize.width, max(sideInset, floor(globalPosition.x - viewSize.width / 2.0))), y: globalPosition.y - 4.0 - viewSize.height), size: viewSize)
                currentEmojiSuggestionView.frame = viewFrame
                if let componentView = currentEmojiSuggestionView.componentView as? EmojiSuggestionsComponent.View {
                    componentView.adjustBackground(relativePositionX: floor(globalPosition.x + 10.0))
                }
            }
            
            let combinedBottomInset: CGFloat
            combinedBottomInset = bottomInset + max(environment.safeInsets.bottom, 8.0 + inputHeight)
            contentHeight += combinedBottomInset
            
            var recenterOnTag: AnyObject?
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let targetView = hint.view {
                var matches = false
                switch hint.kind {
                case .textChanged:
                    matches = true
                case let .textFocusChanged(isFocused):
                    if isFocused {
                        matches = true
                    }
                }
                
                if matches {
                    for (textView, _) in self.collectTextInputStates() {
                        if targetView.isDescendant(of: textView) {
                            recenterOnTag = textView.currentTag
                            break
                        }
                    }
                }
            }
            if recenterOnTag == nil && self.previousHadInputHeight != (inputHeight > 0.0) {
                for (textView, state) in self.collectTextInputStates() {
                    if state.isEditing {
                        recenterOnTag = textView.currentTag
                        break
                    }
                }
            }
            self.previousHadInputHeight = (inputHeight > 0.0)
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            if let recenterOnTag {
                if let targetView = self.collectTextInputStates().first(where: { $0.view.currentTag === recenterOnTag })?.view {
                    let caretRect = targetView.convert(targetView.bounds, to: self.scrollView)
                    var scrollViewBounds = self.scrollView.bounds
                    let minButtonDistance: CGFloat = 16.0
                    if -scrollViewBounds.minY + caretRect.maxY > availableSize.height - combinedBottomInset - minButtonDistance {
                        scrollViewBounds.origin.y = -(availableSize.height - combinedBottomInset - minButtonDistance - caretRect.maxY)
                        if scrollViewBounds.origin.y < 0.0 {
                            scrollViewBounds.origin.y = 0.0
                        }
                    }
                    if self.scrollView.bounds != scrollViewBounds {
                        self.scrollView.bounds = scrollViewBounds
                    }
                }
            }
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            if isEditing {
                if let controller = environment.controller() as? ComposeTodoScreen {
                    DispatchQueue.main.async { [weak controller] in
                        controller?.requestAttachmentMenuExpansion()
                    }
                }
            }
            
            let isValid = self.validatedInput() != nil
            if let controller = environment.controller() as? ComposeTodoScreen, let sendButtonItem = controller.sendButtonItem {
                if sendButtonItem.isEnabled != isValid {
                    sendButtonItem.isEnabled = isValid
                }
            }
            
            if let currentEditingTag = self.currentEditingTag, previousEditingTag !== currentEditingTag, self.currentInputMode != .keyboard {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    self.currentInputMode = .keyboard
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            }
            
            for i in 0 ..< self.todoItems.count {
                self.todoItems[i].resetText = nil
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ComposeTodoScreen: ViewControllerComponentContainer, AttachmentContainable {
    public final class InitialData {
        fileprivate let maxTodoTextLength: Int
        fileprivate let maxTodoItemLength: Int
        fileprivate let maxTodoItemsCount: Int
        fileprivate let existingTodo: TelegramMediaTodo?
        fileprivate let focusedId: Int32?
        fileprivate let append: Bool
        fileprivate let canEdit: Bool
        
        fileprivate init(
            maxTodoTextLength: Int,
            maxTodoItemLength: Int,
            maxTodoItemsCount: Int,
            existingTodo: TelegramMediaTodo?,
            focusedId: Int32?,
            append: Bool,
            canEdit: Bool
        ) {
            self.maxTodoTextLength = maxTodoTextLength
            self.maxTodoItemLength = maxTodoItemLength
            self.maxTodoItemsCount = maxTodoItemsCount
            self.existingTodo = existingTodo
            self.focusedId = focusedId
            self.append = append
            self.canEdit = canEdit
        }
    }
    
    private let context: AccountContext
    private let completion: (TelegramMediaTodo) -> Void
    private var isDismissed: Bool = false
    
    fileprivate private(set) var sendButtonItem: UIBarButtonItem?
    
    public var isMinimized: Bool = false
    
    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var cancelPanGesture: () -> Void = {
    }
    public var isContainerPanning: () -> Bool = {
        return false
    }
    public var isContainerExpanded: () -> Bool = {
        return false
    }
    public var mediaPickerContext: AttachmentMediaPickerContext?
    
    public var isPanGestureEnabled: (() -> Bool)? {
        return { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
                return true
            }
            return componentView.isPanGestureEnabled()
        }
    }
    
    public init(
        context: AccountContext,
        initialData: InitialData,
        peer: EnginePeer,
        completion: @escaping (TelegramMediaTodo) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(context: context, component: ComposeTodoScreenComponent(
            context: context,
            peer: peer,
            initialData: initialData,
            completion: completion
        ), navigationBarAppearance: .default, theme: .default)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if !initialData.canEdit && initialData.existingTodo != nil {
            self.title = presentationData.strings.CreateTodo_Title
        } else {
            self.title = initialData.existingTodo != nil ? presentationData.strings.CreateTodo_EditTitle : presentationData.strings.CreateTodo_Title
        }
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        let sendButtonItem = UIBarButtonItem(title: initialData.existingTodo != nil ? presentationData.strings.CreateTodo_Save : presentationData.strings.CreateTodo_Send, style: .done, target: self, action: #selector(self.sendPressed))
        self.sendButtonItem = sendButtonItem
        self.navigationItem.setRightBarButton(sendButtonItem, animated: false)
        sendButtonItem.isEnabled = false
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public static func initialData(context: AccountContext, existingTodo: TelegramMediaTodo? = nil, focusedId: Int32? = nil, append: Bool = false, canEdit: Bool = false) -> InitialData {
        var maxTodoTextLength: Int = 32
        var maxTodoItemLength: Int = 64
        var maxTodoItemsCount: Int = 30
        if let data = context.currentAppConfiguration.with({ $0 }).data {
            if let value = data["todo_title_length_max"] as? Double {
                maxTodoTextLength = Int(value)
            }
            if let value = data["todo_item_length_max"] as? Double {
                maxTodoItemLength = Int(value)
            }
            if let value = data["todo_items_max"] as? Double {
                maxTodoItemsCount = Int(value)
            }
        }
        return InitialData(
            maxTodoTextLength: maxTodoTextLength,
            maxTodoItemLength: maxTodoItemLength,
            maxTodoItemsCount: maxTodoItemsCount,
            existingTodo: existingTodo,
            focusedId: focusedId,
            append: append,
            canEdit: canEdit
        )
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func sendPressed() {
        guard let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
            return
        }
        if let input = componentView.validatedInput() {
            self.completion(input)
        }
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public func isContainerPanningUpdated(_ panning: Bool) {
    }
    
    public func resetForReuse() {
    }
    
    public func prepareForReuse() {
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        guard let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let input = componentView.validatedInput(), !input.text.isEmpty || !input.items.isEmpty {
            let text = presentationData.strings.Attachment_DiscardTodoAlertText
            let controller = textAlertController(context: self.context, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Attachment_CancelSelectionAlertNo, action: {
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Attachment_CancelSelectionAlertYes, action: {
                completion()
            })])
            self.present(controller, in: .window(.root))
        } else {
            completion()
        }
    }
    
    public func shouldDismissImmediately() -> Bool {
        guard let componentView = self.node.hostView.componentView as? ComposeTodoScreenComponent.View else {
            return true
        }
        if let input = componentView.validatedInput(), !input.text.isEmpty || !input.items.isEmpty {
            return false
        } else {
            return true
        }
    }
}
