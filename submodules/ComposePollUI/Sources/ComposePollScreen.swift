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

final class ComposePollScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let isQuiz: Bool?
    let initialData: ComposePollScreen.InitialData
    let completion: (ComposedPoll) -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        isQuiz: Bool?,
        initialData: ComposePollScreen.InitialData,
        completion: @escaping (ComposedPoll) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.isQuiz = isQuiz
        self.initialData = initialData
        self.completion = completion
    }

    static func ==(lhs: ComposePollScreenComponent, rhs: ComposePollScreenComponent) -> Bool {
        return true
    }
    
    private final class PollOption {
        let id: Int
        let textInputState = TextFieldComponent.ExternalState()
        let textFieldTag = NSObject()
        var resetText: String?
        
        init(id: Int) {
            self.id = id
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        private var reactionInput: ComponentView<Empty>?
        private let pollTextSection = ComponentView<Empty>()
        private let quizAnswerSection = ComponentView<Empty>()
        
        private let pollOptionsSectionHeader = ComponentView<Empty>()
        private let pollOptionsSectionFooterContainer = UIView()
        private var pollOptionsSectionFooter = ComponentView<Empty>()
        private var pollOptionsSectionContainer: ListSectionContentView
        
        private let pollSettingsSection = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private var reactionSelectionControl: ComponentView<Empty>?
        
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        private var previousHadInputHeight: Bool = false
        
        private var component: ComposePollScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let pollTextInputState = TextFieldComponent.ExternalState()
        private let pollTextFieldTag = NSObject()
        private var resetPollText: String?
        
        private var quizAnswerTextInputState = TextFieldComponent.ExternalState()
        private let quizAnswerTextInputTag = NSObject()
        private var resetQuizAnswerText: String?
        
        private var nextPollOptionId: Int = 0
        private var pollOptions: [PollOption] = []
        private var currentPollOptionsLimitReached: Bool = false
        
        private var isAnonymous: Bool = true
        private var isMultiAnswer: Bool = false
        private var isQuiz: Bool = false
        private var selectedQuizOptionId: Int?
        
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
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.pollOptionsSectionContainer = ListSectionContentView(frame: CGRect())
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
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
        
        func validatedInput() -> ComposedPoll? {
            if self.pollTextInputState.text.length == 0 {
                return nil
            }
            
            let mappedKind: TelegramMediaPollKind
            if self.isQuiz {
                mappedKind = .quiz
            } else {
                mappedKind = .poll(multipleAnswers: self.isMultiAnswer)
            }
            
            var mappedOptions: [TelegramMediaPollOption] = []
            var selectedQuizOption: Data?
            for pollOption in self.pollOptions {
                if pollOption.textInputState.text.length == 0 {
                    continue
                }
                let optionData = "\(mappedOptions.count)".data(using: .utf8)!
                if self.selectedQuizOptionId == pollOption.id {
                    selectedQuizOption = optionData
                }
                var entities: [MessageTextEntity] = []
                for entity in generateChatInputTextEntities(pollOption.textInputState.text) {
                    switch entity.type {
                    case .CustomEmoji:
                        entities.append(entity)
                    default:
                        break
                    }
                }
                
                mappedOptions.append(TelegramMediaPollOption(
                    text: pollOption.textInputState.text.string,
                    entities: entities,
                    opaqueIdentifier: optionData
                ))
            }
            
            if mappedOptions.count < 2 {
                return nil
            }
            
            var mappedCorrectAnswers: [Data]?
            if self.isQuiz {
                if let selectedQuizOption {
                    mappedCorrectAnswers = [selectedQuizOption]
                } else {
                    return nil
                }
            }
            
            var mappedSolution: (String, [MessageTextEntity])?
            if self.isQuiz && self.quizAnswerTextInputState.text.length != 0 {
                var solutionTextEntities: [MessageTextEntity] = []
                for entity in generateChatInputTextEntities(self.quizAnswerTextInputState.text) {
                    switch entity.type {
                    case .CustomEmoji:
                        solutionTextEntities.append(entity)
                    default:
                        break
                    }
                }
                
                mappedSolution = (self.quizAnswerTextInputState.text.string, solutionTextEntities)
            }
            
            var textEntities: [MessageTextEntity] = []
            for entity in generateChatInputTextEntities(self.pollTextInputState.text) {
                switch entity.type {
                case .CustomEmoji:
                    textEntities.append(entity)
                default:
                    break
                }
            }
            
            let usedCustomEmojiFiles: [Int64: TelegramMediaFile] = [:]
            
            return ComposedPoll(
                publicity: self.isAnonymous ? .anonymous : .public,
                kind: mappedKind,
                text: ComposedPoll.Text(string: self.pollTextInputState.text.string, entities: textEntities),
                options: mappedOptions,
                correctAnswers: mappedCorrectAnswers,
                results: TelegramMediaPollResults(
                    voters: nil,
                    totalVoters: nil,
                    recentVoters: [],
                    solution: mappedSolution.flatMap { mappedSolution in
                        return TelegramMediaPollResults.Solution(text: mappedSolution.0, entities: mappedSolution.1)
                    }
                ),
                deadlineTimeout: nil,
                usedCustomEmojiFiles: usedCustomEmojiFiles
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
            component: ComposePollScreenComponent,
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
            
            if let controller = self.environment?.controller() as? ComposePollScreen {
                let isTabBarVisible = self.inputMediaNode == nil
                DispatchQueue.main.async { [weak controller] in
                    controller?.updateTabBarVisibility(isTabBarVisible, transition.containedViewLayoutTransition)
                }
            }
            
            return height
        }
        
        private func collectTextInputStates() -> [(view: ListComposePollOptionComponent.View, state: TextFieldComponent.ExternalState)] {
            var textInputStates: [(view: ListComposePollOptionComponent.View, state: TextFieldComponent.ExternalState)] = []
            if let textInputView = self.pollTextSection.findTaggedView(tag: self.pollTextFieldTag) as? ListComposePollOptionComponent.View {
                textInputStates.append((textInputView, self.pollTextInputState))
            }
            for pollOption in self.pollOptions {
                if let textInputView = findTaggedComponentViewImpl(view: self.pollOptionsSectionContainer, tag: pollOption.textFieldTag) as? ListComposePollOptionComponent.View {
                    textInputStates.append((textInputView, pollOption.textInputState))
                }
            }
            if self.isQuiz {
                if let textInputView = self.quizAnswerSection.findTaggedView(tag: self.quizAnswerTextInputTag) as? ListComposePollOptionComponent.View {
                    textInputStates.append((textInputView, self.quizAnswerTextInputState))
                }
            }
            
            return textInputStates
        }
        
        func update(component: ComposePollScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
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
            
            if self.component == nil {
                self.isQuiz = component.isQuiz ?? false
                
                self.pollOptions.append(ComposePollScreenComponent.PollOption(
                    id: self.nextPollOptionId
                ))
                self.nextPollOptionId += 1
                self.pollOptions.append(ComposePollScreenComponent.PollOption(
                    id: self.nextPollOptionId
                ))
                self.nextPollOptionId += 1
                
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
                        guard let controller = self.environment?.controller() as? ComposePollScreen else {
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
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            var pollTextSectionItems: [AnyComponentWithIdentity<Empty>] = []
            pollTextSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListComposePollOptionComponent(
                externalState: self.pollTextInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                resetText: self.resetPollText.flatMap { resetText in
                    return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                },
                assumeIsEditing: self.inputMediaNodeTargetTag === self.pollTextFieldTag,
                characterLimit: component.initialData.maxPollTextLength,
                emptyLineHandling: .allowed,
                returnKeyAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    if !self.pollOptions.isEmpty {
                        if let pollOptionView = self.pollOptionsSectionContainer.itemViews[self.pollOptions[0].id] {
                            if let pollOptionComponentView = pollOptionView.contents.view as? ListComposePollOptionComponent.View {
                                pollOptionComponentView.activateInput()
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
                tag: self.pollTextFieldTag
            ))))
            self.resetPollText = nil
            
            let pollTextSectionSize = self.pollTextSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_TextHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: pollTextSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let pollTextSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: pollTextSectionSize)
            if let pollTextSectionView = self.pollTextSection.view as? ListSectionComponent.View {
                if pollTextSectionView.superview == nil {
                    self.scrollView.addSubview(pollTextSectionView)
                    self.pollTextSection.parentState = state
                }
                transition.setFrame(view: pollTextSectionView, frame: pollTextSectionFrame)
                
                if let itemView = pollTextSectionView.itemView(id: 0) as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: environment.strings.CreatePoll_TextPlaceholder, size: itemView.bounds.size, transition: .immediate)
                }
            }
            contentHeight += pollTextSectionSize.height
            contentHeight += sectionSpacing
            
            var pollOptionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            var pollOptionsSectionReadyItems: [ListSectionContentView.ReadyItem] = []
            
            let processPollOptionItem: (Int) -> Void = { i in
                let pollOption = self.pollOptions[i]
                
                let optionId = pollOption.id
                
                var optionSelection: ListComposePollOptionComponent.Selection?
                if self.isQuiz {
                    optionSelection = ListComposePollOptionComponent.Selection(isSelected: self.selectedQuizOptionId == optionId, toggle: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.selectedQuizOptionId = optionId
                        self.state?.updated(transition: .spring(duration: 0.35))
                    })
                }
                
                pollOptionsSectionItems.append(AnyComponentWithIdentity(id: pollOption.id, component: AnyComponent(ListComposePollOptionComponent(
                    externalState: pollOption.textInputState,
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    resetText: pollOption.resetText.flatMap { resetText in
                        return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                    },
                    assumeIsEditing: self.inputMediaNodeTargetTag === pollOption.textFieldTag,
                    characterLimit: component.initialData.maxPollOptionLength,
                    emptyLineHandling: .notAllowed,
                    returnKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let index = self.pollOptions.firstIndex(where: { $0.id == optionId }) {
                            if index == self.pollOptions.count - 1 {
                                self.endEditing(true)
                            } else {
                                if let pollOptionView = self.pollOptionsSectionContainer.itemViews[self.pollOptions[index + 1].id] {
                                    if let pollOptionComponentView = pollOptionView.contents.view as? ListComposePollOptionComponent.View {
                                        pollOptionComponentView.activateInput()
                                    }
                                }
                            }
                        }
                    },
                    backspaceKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let index = self.pollOptions.firstIndex(where: { $0.id == optionId }) {
                            if index == 0 {
                                if let textInputView = self.pollTextSection.findTaggedView(tag: self.pollTextFieldTag) as? ListComposePollOptionComponent.View {
                                    textInputView.activateInput()
                                }
                            } else {
                                if let pollOptionView = self.pollOptionsSectionContainer.itemViews[self.pollOptions[index - 1].id] {
                                    if let pollOptionComponentView = pollOptionView.contents.view as? ListComposePollOptionComponent.View {
                                        pollOptionComponentView.activateInput()
                                    }
                                }
                            }
                        }
                    },
                    selection: optionSelection,
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
                    tag: pollOption.textFieldTag
                ))))
                
                let item = pollOptionsSectionItems[i]
                let itemId = item.id
                
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.pollOptionsSectionContainer.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ListSectionContentView.ItemView()
                    self.pollOptionsSectionContainer.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                
                pollOptionsSectionReadyItems.append(ListSectionContentView.ReadyItem(
                    id: itemId,
                    itemView: itemView,
                    size: itemSize,
                    transition: itemTransition
                ))
            }
            
            for i in 0 ..< self.pollOptions.count {
                processPollOptionItem(i)
            }
            
            if self.pollOptions.count > 2 {
                let lastOption = self.pollOptions[self.pollOptions.count - 1]
                let secondToLastOption = self.pollOptions[self.pollOptions.count - 2]
                
                if !lastOption.textInputState.isEditing && lastOption.textInputState.text.length == 0 && secondToLastOption.textInputState.text.length == 0 {
                    self.pollOptions.removeLast()
                    pollOptionsSectionItems.removeLast()
                    pollOptionsSectionReadyItems.removeLast()
                }
            }
            
            if self.pollOptions.count < component.initialData.maxPollAnswersCount, let lastOption = self.pollOptions.last {
                if lastOption.textInputState.text.length != 0 {
                    self.pollOptions.append(PollOption(id: self.nextPollOptionId))
                    self.nextPollOptionId += 1
                    processPollOptionItem(self.pollOptions.count - 1)
                }
            }
            
            for i in 0 ..< pollOptionsSectionReadyItems.count {
                let placeholder: String
                if i == pollOptionsSectionReadyItems.count - 1 {
                    placeholder = environment.strings.CreatePoll_AddOption
                } else {
                    placeholder = environment.strings.CreatePoll_OptionPlaceholder
                }
                
                if let itemView = pollOptionsSectionReadyItems[i].itemView.contents.view as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: placeholder, size: pollOptionsSectionReadyItems[i].size, transition: pollOptionsSectionReadyItems[i].transition)
                }
            }
            
            let pollOptionsSectionUpdateResult = self.pollOptionsSectionContainer.update(
                configuration: ListSectionContentView.Configuration(
                    theme: environment.theme,
                    displaySeparators: true,
                    extendsItemHighlightToSection: false,
                    background: .all
                ),
                width: availableSize.width - sideInset * 2.0,
                leftInset: 0.0,
                readyItems: pollOptionsSectionReadyItems,
                transition: transition
            )
            
            let sectionHeaderSideInset: CGFloat = 16.0
            let pollOptionsSectionHeaderSize = self.pollOptionsSectionHeader.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.CreatePoll_OptionsHeader,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: environment.theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sectionHeaderSideInset * 2.0, height: 1000.0)
            )
            let pollOptionsSectionHeaderFrame = CGRect(origin: CGPoint(x: sideInset + sectionHeaderSideInset, y: contentHeight), size: pollOptionsSectionHeaderSize)
            if let pollOptionsSectionHeaderView = self.pollOptionsSectionHeader.view {
                if pollOptionsSectionHeaderView.superview == nil {
                    pollOptionsSectionHeaderView.layer.anchorPoint = CGPoint()
                    self.scrollView.addSubview(pollOptionsSectionHeaderView)
                }
                transition.setPosition(view: pollOptionsSectionHeaderView, position: pollOptionsSectionHeaderFrame.origin)
                pollOptionsSectionHeaderView.bounds = CGRect(origin: CGPoint(), size: pollOptionsSectionHeaderFrame.size)
            }
            contentHeight += pollOptionsSectionHeaderSize.height
            contentHeight += 7.0
            
            let pollOptionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: pollOptionsSectionUpdateResult.size)
            if self.pollOptionsSectionContainer.superview == nil {
                self.scrollView.addSubview(self.pollOptionsSectionContainer.externalContentBackgroundView)
                self.scrollView.addSubview(self.pollOptionsSectionContainer)
            }
            transition.setFrame(view: self.pollOptionsSectionContainer, frame: pollOptionsSectionFrame)
            transition.setFrame(view: self.pollOptionsSectionContainer.externalContentBackgroundView, frame: pollOptionsSectionUpdateResult.backgroundFrame.offsetBy(dx: pollOptionsSectionFrame.minX, dy: pollOptionsSectionFrame.minY))
            contentHeight += pollOptionsSectionUpdateResult.size.height
            
            contentHeight += 7.0
            
            let pollOptionsLimitReached = self.pollOptions.count >= component.initialData.maxPollAnswersCount
            var animatePollOptionsFooterIn = false
            var pollOptionsFooterTransition = transition
            if self.currentPollOptionsLimitReached != pollOptionsLimitReached {
                self.currentPollOptionsLimitReached = pollOptionsLimitReached
                if let pollOptionsSectionFooterView = self.pollOptionsSectionFooter.view {
                    animatePollOptionsFooterIn = true
                    pollOptionsFooterTransition = pollOptionsFooterTransition.withAnimation(.none)
                    alphaTransition.setAlpha(view: pollOptionsSectionFooterView, alpha: 0.0, completion: { [weak pollOptionsSectionFooterView] _ in
                        pollOptionsSectionFooterView?.removeFromSuperview()
                    })
                    self.pollOptionsSectionFooter = ComponentView()
                }
            }
            
            let pollOptionsComponent: AnyComponent<Empty>
            if pollOptionsLimitReached {
                pollOptionsFooterTransition = pollOptionsFooterTransition.withAnimation(.none)
                pollOptionsComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.CreatePoll_AllOptionsAdded, font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor)),
                    maximumNumberOfLines: 0
                ))
            } else {
                let remainingCount = component.initialData.maxPollAnswersCount - self.pollOptions.count
                let rawString = environment.strings.CreatePoll_OptionCountFooterFormat(Int32(remainingCount))
                
                var pollOptionsFooterItems: [AnimatedTextComponent.Item] = []
                if let range = rawString.range(of: "{count}") {
                    if range.lowerBound != rawString.startIndex {
                        pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                            id: 0,
                            isUnbreakable: true,
                            content: .text(String(rawString[rawString.startIndex ..< range.lowerBound]))
                        ))
                    }
                    pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                        id: 1,
                        isUnbreakable: true,
                        content: .number(remainingCount, minDigits: 1)
                    ))
                    if range.upperBound != rawString.endIndex {
                        pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                            id: 2,
                            isUnbreakable: true,
                            content: .text(String(rawString[range.upperBound ..< rawString.endIndex]))
                        ))
                    }
                }
                
                pollOptionsComponent = AnyComponent(AnimatedTextComponent(
                    font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                    color: environment.theme.list.freeTextColor,
                    items: pollOptionsFooterItems
                ))
            }
            
            let pollOptionsSectionFooterSize = self.pollOptionsSectionFooter.update(
                transition: pollOptionsFooterTransition,
                component: pollOptionsComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sectionHeaderSideInset * 2.0, height: 1000.0)
            )
            let pollOptionsSectionFooterFrame = CGRect(origin: CGPoint(x: sideInset + sectionHeaderSideInset, y: contentHeight), size: pollOptionsSectionFooterSize)
            
            if self.pollOptionsSectionFooterContainer.superview == nil {
                self.scrollView.addSubview(self.pollOptionsSectionFooterContainer)
            }
            transition.setFrame(view: self.pollOptionsSectionFooterContainer, frame: pollOptionsSectionFooterFrame)
            
            if let pollOptionsSectionFooterView = self.pollOptionsSectionFooter.view {
                if pollOptionsSectionFooterView.superview == nil {
                    pollOptionsSectionFooterView.layer.anchorPoint = CGPoint()
                    self.pollOptionsSectionFooterContainer.addSubview(pollOptionsSectionFooterView)
                }
                pollOptionsFooterTransition.setPosition(view: pollOptionsSectionFooterView, position: CGPoint())
                pollOptionsSectionFooterView.bounds = CGRect(origin: CGPoint(), size: pollOptionsSectionFooterFrame.size)
                if animatePollOptionsFooterIn && !transition.animation.isImmediate {
                    alphaTransition.animateAlpha(view: pollOptionsSectionFooterView, from: 0.0, to: 1.0)
                }
            }
            contentHeight += pollOptionsSectionFooterSize.height
            contentHeight += sectionSpacing
            
            var canBePublic = true
            if case let .channel(channel) = component.peer, case .broadcast = channel.info {
                canBePublic = false
            }
            
            var pollSettingsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if canBePublic {
                pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "anonymous", component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_Anonymous,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isAnonymous, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isAnonymous = !self.isAnonymous
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
            }
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "multiAnswer", component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_MultipleChoice,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isMultiAnswer, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isMultiAnswer = !self.isMultiAnswer
                    if self.isMultiAnswer {
                        self.isQuiz = false
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "quiz", component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_Quiz,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isQuiz, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isQuiz = !self.isQuiz
                    if self.isQuiz {
                        self.isMultiAnswer = false
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            let pollSettingsSectionSize = self.pollSettingsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_QuizInfo,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: pollSettingsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let pollSettingsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: pollSettingsSectionSize)
            if let pollSettingsSectionView = self.pollSettingsSection.view {
                if pollSettingsSectionView.superview == nil {
                    self.scrollView.addSubview(pollSettingsSectionView)
                    self.pollSettingsSection.parentState = state
                }
                transition.setFrame(view: pollSettingsSectionView, frame: pollSettingsSectionFrame)
            }
            contentHeight += pollSettingsSectionSize.height
            
            var quizAnswerSectionHeight: CGFloat = 0.0
            quizAnswerSectionHeight += sectionSpacing
            let quizAnswerSectionSize = self.quizAnswerSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ExplanationHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ExplanationInfo,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListComposePollOptionComponent(
                            externalState: self.quizAnswerTextInputState,
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            resetText: self.resetQuizAnswerText.flatMap { resetText in
                                return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                            },
                            assumeIsEditing: self.inputMediaNodeTargetTag === self.quizAnswerTextInputTag,
                            characterLimit: component.initialData.maxPollTextLength,
                            emptyLineHandling: .allowed,
                            returnKeyAction: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.endEditing(true)
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
                            tag: self.quizAnswerTextInputTag
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            self.resetQuizAnswerText = nil
            let quizAnswerSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + quizAnswerSectionHeight), size: quizAnswerSectionSize)
            if let quizAnswerSectionView = self.quizAnswerSection.view as? ListSectionComponent.View {
                if quizAnswerSectionView.superview == nil {
                    self.scrollView.addSubview(quizAnswerSectionView)
                    self.quizAnswerSection.parentState = state
                }
                transition.setFrame(view: quizAnswerSectionView, frame: quizAnswerSectionFrame)
                transition.setAlpha(view: quizAnswerSectionView, alpha: self.isQuiz ? 1.0 : 0.0)
                
                if let itemView = quizAnswerSectionView.itemView(id: 0) as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: environment.strings.CreatePoll_Explanation, size: itemView.bounds.size, transition: .immediate)
                }
            }
            quizAnswerSectionHeight += quizAnswerSectionSize.height
            
            if self.isQuiz {
                contentHeight += quizAnswerSectionHeight
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
                        theme: EmojiSuggestionsComponent.Theme(theme: environment.theme, backgroundColor: environment.theme.list.itemBlocksBackgroundColor),
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
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
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
                if let controller = environment.controller() as? ComposePollScreen {
                    DispatchQueue.main.async { [weak controller] in
                        controller?.requestAttachmentMenuExpansion()
                    }
                }
            }
            
            let isValid = self.validatedInput() != nil
            if let controller = environment.controller() as? ComposePollScreen, let sendButtonItem = controller.sendButtonItem {
                if sendButtonItem.isEnabled != isValid {
                    sendButtonItem.isEnabled = isValid
                }
                
                let controllerTitle = self.isQuiz ? presentationData.strings.CreatePoll_QuizTitle : presentationData.strings.CreatePoll_Title
                if controller.title != controllerTitle {
                    controller.title = controllerTitle
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

public class ComposePollScreen: ViewControllerComponentContainer, AttachmentContainable {
    public final class InitialData {
        fileprivate let maxPollTextLength: Int
        fileprivate let maxPollOptionLength: Int
        fileprivate let maxPollAnswersCount: Int
        
        fileprivate init(
            maxPollTextLength: Int,
            maxPollOptionLength: Int,
            maxPollAnwsersCount: Int
        ) {
            self.maxPollTextLength = maxPollTextLength
            self.maxPollOptionLength = maxPollOptionLength
            self.maxPollAnswersCount = maxPollAnwsersCount
        }
    }
    
    private let context: AccountContext
    private let completion: (ComposedPoll) -> Void
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
            guard let self, let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
                return true
            }
            return componentView.isPanGestureEnabled()
        }
    }
    
    public init(
        context: AccountContext,
        initialData: InitialData,
        peer: EnginePeer,
        isQuiz: Bool?,
        completion: @escaping (ComposedPoll) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(context: context, component: ComposePollScreenComponent(
            context: context,
            peer: peer,
            isQuiz: isQuiz,
            initialData: initialData,
            completion: completion
        ), navigationBarAppearance: .default, theme: .default)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.title = isQuiz == true ? presentationData.strings.CreatePoll_QuizTitle : presentationData.strings.CreatePoll_Title
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        let sendButtonItem = UIBarButtonItem(title: presentationData.strings.CreatePoll_Create, style: .done, target: self, action: #selector(self.sendPressed))
        self.sendButtonItem = sendButtonItem
        self.navigationItem.setRightBarButton(sendButtonItem, animated: false)
        sendButtonItem.isEnabled = false
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
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
    
    public static func initialData(context: AccountContext) -> InitialData {
        var maxPollAnwsersCount: Int = 10
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["poll_answers_max"] as? Double {
            maxPollAnwsersCount = Int(value)
        }
        return InitialData(
            maxPollTextLength: Int(200),
            maxPollOptionLength: 100,
            maxPollAnwsersCount: maxPollAnwsersCount
        )
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func sendPressed() {
        guard let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
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
        completion()
    }
    
    public func shouldDismissImmediately() -> Bool {
        return true
    }
}
