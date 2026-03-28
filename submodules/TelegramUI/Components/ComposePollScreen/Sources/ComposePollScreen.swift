import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
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
import GlassBarButtonComponent
import ChatScheduleTimeController
import ContextUI
import StickerPeekUI
import EdgeEffect
import LocationUI

public final class ComposedPoll {
    public struct Text {
        public let string: String
        public let entities: [MessageTextEntity]
        
        public init(string: String, entities: [MessageTextEntity]) {
            self.string = string
            self.entities = entities
        }
    }
    
    public let publicity: TelegramMediaPollPublicity
    public let kind: TelegramMediaPollKind
    
    public let openAnswers: Bool
    public let revotingDisabled: Bool
    public let shuffleAnswers: Bool
    public let hideResultsUntilClose: Bool

    public let text: Text
    public let description: Text
    public let media: AnyMediaReference?
    public let options: [TelegramMediaPollOption]
    public let correctAnswers: [Data]?
    public let results: TelegramMediaPollResults
    public let deadlineTimeout: Int32?
    public let deadlineDate: Int32?
    public let usedCustomEmojiFiles: [Int64: TelegramMediaFile]

    public init(
        publicity: TelegramMediaPollPublicity,
        kind: TelegramMediaPollKind,
        openAnswers: Bool,
        revotingDisabled: Bool,
        shuffleAnswers: Bool,
        hideResultsUntilClose: Bool,
        text: Text,
        description: Text,
        media: AnyMediaReference?,
        options: [TelegramMediaPollOption],
        correctAnswers: [Data]?,
        results: TelegramMediaPollResults,
        deadlineTimeout: Int32?,
        deadlineDate: Int32?,
        usedCustomEmojiFiles: [Int64: TelegramMediaFile]
    ) {
        self.publicity = publicity
        self.kind = kind
        self.openAnswers = openAnswers
        self.revotingDisabled = revotingDisabled
        self.shuffleAnswers = shuffleAnswers
        self.hideResultsUntilClose = hideResultsUntilClose
        self.text = text
        self.description = description
        self.media = media
        self.options = options
        self.correctAnswers = correctAnswers
        self.results = results
        self.deadlineTimeout = deadlineTimeout
        self.deadlineDate = deadlineDate
        self.usedCustomEmojiFiles = usedCustomEmojiFiles
    }
}

final class ComposePollScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let overNavigationContainer: UIView
    let peer: EnginePeer
    let isQuiz: Bool?
    let initialData: ComposePollScreen.InitialData
    let completion: (ComposedPoll) -> Void

    init(
        context: AccountContext,
        overNavigationContainer: UIView,
        peer: EnginePeer,
        isQuiz: Bool?,
        initialData: ComposePollScreen.InitialData,
        completion: @escaping (ComposedPoll) -> Void
    ) {
        self.context = context
        self.overNavigationContainer = overNavigationContainer
        self.peer = peer
        self.isQuiz = isQuiz
        self.initialData = initialData
        self.completion = completion
    }

    static func ==(lhs: ComposePollScreenComponent, rhs: ComposePollScreenComponent) -> Bool {
        return true
    }
    
    final class AttachedMedia {
        var media: AnyMediaReference
        var progress: CGFloat?
        var uploadDisposable: Disposable?
        
        init(media: AnyMediaReference) {
            self.media = media
        }
        
        var requiresUpload: Bool {
            if let image = self.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations), !(largest.resource is CloudPhotoSizeMediaResource) {
                return true
            }
            if let file = self.media.media as? TelegramMediaFile, !(file.resource is CloudDocumentMediaResource) {
                return true
            }
            return false
        }
    }
    
    private final class PollOption {
        let id: Int
        let textInputState = TextFieldComponent.ExternalState()
        let textFieldTag = NSObject()
        var resetText: String?
        var media: AttachedMedia?
        
        init(id: Int) {
            self.id = id
        }
    }
    
    private enum TimeLimit {
        case duration(Int32)
        case deadline(Int32)
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private var topEdgeEffectView: EdgeEffectView
        private var bottomEdgeEffectView: EdgeEffectView
         
        private var reactionInput: ComponentView<Empty>?
        private let pollTextSection = ComponentView<Empty>()
        private let quizAnswerSection = ComponentView<Empty>()
        
        private let pollOptionsSectionHeader = ComponentView<Empty>()
        private let pollOptionsSectionFooterContainer = UIView()
        private var pollOptionsSectionFooter = ComponentView<Empty>()
        private var pollOptionsSectionContainer: ListSectionContentView
        
        private let pollSettingsSection = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        
        private var reactionSelectionControl: ComponentView<Empty>?
        
        private var isUpdating: Bool = false
        private var previousHadInputHeight: Bool = false
        
        private var component: ComposePollScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let pollTextInputState = TextFieldComponent.ExternalState()
        private let pollTextFieldTag = NSObject()
        private var resetPollText: String?
        
        private let pollDescriptionInputState = TextFieldComponent.ExternalState()
        private let pollDescriptionFieldTag = NSObject()
        private var pollDescriptionMedia: AttachedMedia?
        
        private var quizAnswerTextInputState = TextFieldComponent.ExternalState()
        private let quizAnswerTextInputTag = NSObject()
        private var resetQuizAnswerText: String?
        private var quizAnswerMedia: AttachedMedia?
        
        private var nextPollOptionId: Int = 0
        private var pollOptions: [PollOption] = []
        private var currentPollOptionsLimitReached: Bool = false
        
        private var isAnonymous: Bool = true
        private var isMultiAnswer: Bool?
        private var canAddOptions: Bool = false
        private var canRevote: Bool = false
        private var shuffleOptions: Bool = false
        private var isQuiz: Bool = false
        private var selectedQuizOptionIds = Set<Int>()
        private var limitDuration: Bool = false
        private var timeLimit: TimeLimit = .duration(24 * 60 * 60)
        private var hideResults: Bool = false
        
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
        
        private var cachedViewIcon: UIImage?
        private var cachedMultipleIcon: UIImage?
        private var cachedAddIcon: UIImage?
        private var cachedRevoteIcon: UIImage?
        private var cachedShuffleIcon: UIImage?
        private var cachedQuizIcon: UIImage?
        private var cachedDurationIcon: UIImage?
        private var cachedEmptyIcon: UIImage?
        
        private var reorderRecognizer: ReorderGestureRecognizer?
        private var reorderingItem: (id: AnyHashable, snapshotView: UIView, backgroundView: UIView, initialPosition: CGPoint, position: CGPoint)?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.topEdgeEffectView = EdgeEffectView()
            self.bottomEdgeEffectView = EdgeEffectView()
            
            self.pollOptionsSectionContainer = ListSectionContentView(frame: CGRect())
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addSubview(self.topEdgeEffectView)
            self.addSubview(self.bottomEdgeEffectView)
            
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
            self.pollDescriptionMedia?.uploadDisposable?.dispose()
            self.quizAnswerMedia?.uploadDisposable?.dispose()
            for option in self.pollOptions {
                option.media?.uploadDisposable?.dispose()
            }
            self.inputMediaNodeDataDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        private func item(at point: CGPoint) -> (AnyHashable, ComponentView<Empty>)? {
            if self.scrollView.isDragging || self.scrollView.isDecelerating {
                return nil
            }
            
            let localPoint = self.pollOptionsSectionContainer.convert(point, from: self)
            for (id, itemView) in self.pollOptionsSectionContainer.itemViews {
                if let view = itemView.contents.view as? ListComposePollOptionComponent.View, !view.isRevealed && !view.currentText.isEmpty {
                    let viewFrame = view.convert(view.bounds, to: self.pollOptionsSectionContainer)
                    let iconFrame = CGRect(origin: CGPoint(x: viewFrame.minX, y: viewFrame.minY), size: CGSize(width: viewFrame.height, height: viewFrame.height))
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
            for (id, itemView) in self.pollOptionsSectionContainer.itemViews {
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
                    backgroundView.frame = wrapperView.bounds.insetBy(dx: -16.0, dy: -16.0)
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
                        for (itemId, itemView) in self.pollOptionsSectionContainer.itemViews {
                            if itemId == reorderingItem.id, let view = itemView.contents.view {
                                let viewFrame = view.convert(view.bounds, to: self.scrollView)
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
                
                let localPoint = self.pollOptionsSectionContainer.convert(targetPosition, from: self.scrollView)
                for (itemId, itemView) in self.pollOptionsSectionContainer.itemViews {
                    if itemId == id {
                        continue
                    }
                    if let view = itemView.contents.view {
                        let viewFrame = view.convert(view.bounds, to: self.pollOptionsSectionContainer)
                        if viewFrame.contains(localPoint) {
                            if let targetIndex = self.pollOptions.firstIndex(where: { AnyHashable($0.id) == itemId }), let reorderingItem = self.pollOptions.first(where: { AnyHashable($0.id) == id }) {
                                self.reorderIfPossible(item: reorderingItem, toIndex: targetIndex)
                            }
                            break
                        }
                    }
                }
            }
        }
        
        private func reorderIfPossible(item: PollOption, toIndex: Int) {
            let targetItem = self.pollOptions[toIndex]
            guard targetItem.textInputState.hasText else {
                return
            }
            if let fromIndex = self.pollOptions.firstIndex(where: { $0.id == item.id }) {
                self.pollOptions[toIndex] = item
                self.pollOptions[fromIndex] = targetItem
                
                HapticFeedback().tap()
                
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        private var effectiveIsMultiAnswer: Bool {
            return self.isMultiAnswer ?? false
        }
        
        enum ValidatedInput {
            case ready(ComposedPoll)
            case isUploading
        }
        
        var hasAnyData: Bool {
            if self.pollTextInputState.hasText {
                return true
            }
            if self.pollDescriptionInputState.hasText {
                return true
            }
            if self.pollDescriptionMedia != nil {
                return true
            }
            for pollOption in self.pollOptions {
                if pollOption.textInputState.text.length > 0 {
                    return true
                }
            }
            if self.quizAnswerTextInputState.hasText {
                return true
            }
            if self.quizAnswerMedia != nil {
                return true
            }
            return false
        }
        
        func validatedInput() -> ValidatedInput? {
            if self.pollTextInputState.text.length == 0 {
                return nil
            }
            
            let mappedKind: TelegramMediaPollKind
            if self.isQuiz {
                mappedKind = .quiz(multipleAnswers: self.effectiveIsMultiAnswer)
            } else {
                mappedKind = .poll(multipleAnswers: self.effectiveIsMultiAnswer)
            }
            
            var mappedOptions: [TelegramMediaPollOption] = []
            var selectedQuizOptions: [Data] = []
            for pollOption in self.pollOptions {
                if pollOption.textInputState.text.length == 0 {
                    continue
                }
                let optionData = "\(mappedOptions.count)".data(using: .utf8)!
                if self.selectedQuizOptionIds.contains(pollOption.id) {
                    selectedQuizOptions.append(optionData)
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
                
                if let media = pollOption.media, media.requiresUpload {
                    return .isUploading
                }
                
                mappedOptions.append(TelegramMediaPollOption(
                    text: pollOption.textInputState.text.string,
                    entities: entities,
                    opaqueIdentifier: optionData,
                    media: pollOption.media?.media.media,
                    date: nil,
                    addedBy: nil
                ))
            }
            
            if mappedOptions.count < 2 {
                return nil
            }
            
            var mappedCorrectAnswers: [Data]?
            if self.isQuiz {
                if !selectedQuizOptions.isEmpty {
                    mappedCorrectAnswers = selectedQuizOptions
                } else {
                    return nil
                }
            }
            
            var mappedSolution: (String, [MessageTextEntity], AnyMediaReference?)?
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
                
                if let media = self.quizAnswerMedia, media.requiresUpload {
                    return .isUploading
                }
                
                mappedSolution = (self.quizAnswerTextInputState.text.string, solutionTextEntities, self.quizAnswerMedia?.media)
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
            
            var descriptionEntities: [MessageTextEntity] = []
            for entity in generateChatInputTextEntities(self.pollDescriptionInputState.text) {
                switch entity.type {
                case .CustomEmoji:
                    descriptionEntities.append(entity)
                default:
                    break
                }
            }
            
            let usedCustomEmojiFiles: [Int64: TelegramMediaFile] = [:]
            
            var deadlineTimeout: Int32?
            var deadlineDate: Int32?
            if self.limitDuration {
                switch self.timeLimit {
                case let .duration(duration):
                    deadlineTimeout = duration
                case let .deadline(deadline):
                    deadlineDate = deadline
                }
            }
            
            if let media = self.pollDescriptionMedia, media.requiresUpload {
                return .isUploading
            }
            
            return .ready(ComposedPoll(
                publicity: self.isAnonymous ? .anonymous : .public,
                kind: mappedKind,
                openAnswers: self.canAddOptions,
                revotingDisabled: !self.canRevote,
                shuffleAnswers: self.shuffleOptions,
                hideResultsUntilClose: self.hideResults,
                text: ComposedPoll.Text(string: self.pollTextInputState.text.string, entities: textEntities),
                description: ComposedPoll.Text(string: self.pollDescriptionInputState.text.string, entities: descriptionEntities),
                media: self.pollDescriptionMedia?.media,
                options: mappedOptions,
                correctAnswers: mappedCorrectAnswers,
                results: TelegramMediaPollResults(
                    voters: nil,
                    totalVoters: nil,
                    recentVoters: [],
                    solution: mappedSolution.flatMap { mappedSolution in
                        return TelegramMediaPollResults.Solution(
                            text: mappedSolution.0,
                            entities: mappedSolution.1,
                            media: mappedSolution.2?.media
                        )
                    },
                    hasUnseenVotes: false
                ),
                deadlineTimeout: deadlineTimeout,
                deadlineDate: deadlineDate,
                usedCustomEmojiFiles: usedCustomEmojiFiles
            ))
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            
            let _ = component
            
            return true
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.deactivateInput()
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
            if case .emoji = self.currentInputMode, var inputData = self.inputMediaNodeData {
                if let updatedTag = self.collectTextInputStates().first(where: { $1.isEditing })?.view.currentTag {
                    self.inputMediaNodeTargetTag = updatedTag
                }
                
                inputData.stickers = nil
                
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
                        updatedInputData: self.inputMediaNodeDataPromise.get()
                        |> map { inputData in
                            var inputData = inputData
                            inputData.stickers = nil
                            return inputData
                        },
                        defaultToEmojiTab: true,
                        opaqueTopPanelBackground: false,
                        useOpaqueTheme: false, //true,
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
                    preferredGlassType: .default,
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
                    threadData: nil,
                    isGeneralThreadClosed: nil,
                    replyMessage: nil,
                    accountPeerColor: nil,
                    businessIntro: nil
                )
                
                //self.inputMediaNodeBackground.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor.cgColor
                
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
            if let textInputView = self.pollTextSection.findTaggedView(tag: self.pollDescriptionFieldTag) as? ListComposePollOptionComponent.View {
                textInputStates.append((textInputView, self.pollDescriptionInputState))
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
        
        private enum MediaAttachSubject {
            case description
            case quizAnswer
            case pollOption(PollOption)
        }

        private func attachedMedia(for subject: MediaAttachSubject) -> AttachedMedia? {
            switch subject {
            case .description:
                return self.pollDescriptionMedia
            case .quizAnswer:
                return self.quizAnswerMedia
            case let .pollOption(pollOption):
                return pollOption.media
            }
        }

        private func setAttachedMedia(_ media: AttachedMedia?, for subject: MediaAttachSubject) {
            switch subject {
            case .description:
                self.pollDescriptionMedia = media
            case .quizAnswer:
                self.quizAnswerMedia = media
            case let .pollOption(pollOption):
                pollOption.media = media
            }
        }
        
        private func openAttachedMedia(subject: MediaAttachSubject, replace: Bool = false) {
            guard let component = self.component else {
                return
            }
            
            self.deactivateInput()
            
            guard replace || !self.openAttachMediaContextMenu(subject: subject) else {
                return
            }
            
            var availableButtons: [AttachmentButtonType]
            switch subject {
            case .description, .quizAnswer:
                availableButtons = [.gallery, .file, .location]
            default:
                availableButtons = [.gallery, .sticker, .location]
            }
            
            let pollAttachmentSubject: PollAttachmentSubject
            switch subject {
            case .description:
                pollAttachmentSubject = .description
            case .quizAnswer:
                pollAttachmentSubject = .quizAnswer
            case .pollOption:
                pollAttachmentSubject = .option
            }
            
            presentPollAttachmentScreen(
                context: component.context,
                updatedPresentationData: nil,
                subject: pollAttachmentSubject,
                availableButtons: availableButtons,
                inputMediaNodeData: self.inputMediaNodeDataPromise.get() |> map(Optional.init),
                present: { [weak self] c, push in
                    guard let parentController = (self?.environment?.controller() as? ComposePollScreen)?.parentController() else {
                        return
                    }
                    if push {
                        parentController.push(c)
                    } else {
                        parentController.present(c, in: .window(.root))
                    }
                },
                completion: { [weak self] media in
                guard let self else {
                    return
                }
                let attachedMedia = AttachedMedia(media: media)
                self.setAttachedMedia(attachedMedia, for: subject)
                self.uploadAttachedMediaIfNeeded(attachedMedia)
                self.state?.updated(transition: .easeInOut(duration: 0.2))
            })
        }
        
        private func uploadAttachedMediaIfNeeded(_ media: AttachedMedia) {
            guard let component = self.component, media.requiresUpload, media.uploadDisposable == nil else {
                return
            }
            media.progress = 0.0
            
            if let image = media.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                media.uploadDisposable = (standaloneUploadedImage(
                    postbox: component.context.account.postbox,
                    network: component.context.account.network,
                    peerId: component.peer.id,
                    text: "",
                    source: .resource(media.media.resourceReference(largest.resource)),
                    dimensions: largest.dimensions
                )
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self, let component = self.component else {
                        return
                    }
                    var transition: ComponentTransition = .immediate
                    switch value {
                    case let .progress(progress):
                        media.progress = CGFloat(progress)
                    case let .result(result):
                        switch result {
                        case let .media(resultMedia):
                            if let resultImage = resultMedia.media as? TelegramMediaImage, let resultLargest = largestImageRepresentation(resultImage.representations) {
                                component.context.account.postbox.mediaBox.moveResourceData(from: largest.resource.id, to: resultLargest.resource.id, synchronous: true)
                            }
                            
                            media.media = resultMedia
                            media.progress = nil
                            media.uploadDisposable?.dispose()
                            media.uploadDisposable = nil
                            transition = .easeInOut(duration: 0.2)
                        }
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: transition)
                    }
                })
            }
            if let file = media.media.media as? TelegramMediaFile {
                media.uploadDisposable = (standaloneUploadedFile(
                    postbox: component.context.account.postbox,
                    network: component.context.account.network,
                    peerId: component.peer.id,
                    text: "",
                    source: .resource(media.media.resourceReference(file.resource)),
                    thumbnailData: file.immediateThumbnailData,
                    mimeType: file.mimeType,
                    attributes: file.attributes,
                    hintFileIsLarge: false
                )
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    var transition: ComponentTransition = .immediate
                    switch value {
                    case let .progress(progress):
                        media.progress = CGFloat(progress)
                    case let .result(result):
                        switch result {
                        case let .media(resultMedia):
                            if let resultFile = resultMedia.media as? TelegramMediaFile {
                                component.context.account.postbox.mediaBox.moveResourceData(from: file.resource.id, to: resultFile.resource.id, synchronous: true)
                            }
                            media.media = resultMedia
                            media.progress = nil
                            media.uploadDisposable?.dispose()
                            media.uploadDisposable = nil
                            transition = .easeInOut(duration: 0.2)
                        }
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: transition)
                    }
                })
            }
        }
        
        private func openAttachMediaContextMenu(subject: MediaAttachSubject) -> Bool {
            guard let component = self.component, let media = self.attachedMedia(for: subject) else {
                return false
            }
            if media.progress != nil {
                media.uploadDisposable?.dispose()
                self.setAttachedMedia(nil, for: subject)
                self.state?.updated(transition: .easeInOut(duration: 0.25))
            } else {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                if let file = media.media.media as? TelegramMediaFile, file.isSticker || file.isCustomEmoji {
                    var items: [ContextMenuItem] = []
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.CreatePoll_Media_Replace, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.openAttachedMedia(subject: subject, replace: true)
                    })))
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.CreatePoll_Media_Delete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.setAttachedMedia(nil, for: subject)
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                    })))
                    
                    let peekController = makePeekController(
                        presentationData: presentationData,
                        content: StickerPreviewPeekContent(
                            context: component.context,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            item: .pack(file),
                            isCreating: false,
                            menu: items,
                            openPremiumIntro: {}
                        ),
                        sourceView: {
                            return nil
                        },
                        activateImmediately: true
                    )
                    self.environment?.controller()?.presentInGlobalOverlay(peekController)
                } else {
                    var items: [ContextMenuItem] = []
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.CreatePoll_Media_Replace, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.openAttachedMedia(subject: subject, replace: true)
                    })))
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.CreatePoll_Media_Delete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.setAttachedMedia(nil, for: subject)
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                    })))
                    
                    let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(0)), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [media.media.media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                    
                    let source: ContextContentSource
                    
                    if let _ = media.media.media as? TelegramMediaMap {
                        let controller = LocationViewController(
                            context: component.context,
                            subject: EngineMessage(message),
                            isPreview: true,
                            params: LocationViewParams(
                                sendLiveLocation: { _ in },
                                stopLiveLocation: { _ in },
                                openUrl: { _ in },
                                openPeer: { _ in }
                            )
                        )
                        source = .controller(ComposePollContextControllerContentSource(controller: controller, sourceView: nil, sourceRect: .zero))
                    } else {
                        let gallery = component.context.sharedContext.makeGalleryController(context: component.context, source: .standaloneMessage(message, nil), streamSingleVideo: true, isPreview: true)
                        source = .controller(ComposePollContextControllerContentSource(controller: gallery, sourceView: nil, sourceRect: .zero))
                    }
                    
                    let contextController = makeContextController(
                        presentationData: presentationData,
                        source: source,
                        items: .single(ContextController.Items(content: .list(items))),
                        gesture: nil
                    )
                    self.environment?.controller()?.presentInGlobalOverlay(contextController)
                }
            }
            return true
        }
        
        private func presentTimeLimitOptions(sourceView: UIView) {
            guard let component = self.component else {
                return
            }
            
            var sourceView = sourceView
            if let itemView = sourceView as? ListActionItemComponent.View, let iconView = itemView.iconView {
                sourceView = iconView
            }
            
            var subItems: [ContextMenuItem] = []
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let presetValues: [Int32] = [
                1 * 60 * 60,
                3 * 60 * 60,
                8 * 60 * 60,
                24 * 60 * 60,
                72 * 60 * 60
            ]
            
            for value in presetValues {
                let optionText = timeIntervalString(strings: presentationData.strings, value: value)
                subItems.append(.action(ContextMenuActionItem(text: optionText, icon: { theme in
                    return nil
                }, action: { [weak self] _, f in
                    f(.default)
                    guard let self else {
                        return
                    }
                    self.timeLimit = .duration(value)
                    self.state?.updated()
                })))
            }
            
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.CreatePoll_TimeLimit_Custom, icon: { theme in
                return nil
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.openCustomTimePicker()
            })))
                
            let items: Signal<ContextController.Items, NoError> = .single(ContextController.Items(content: .list(subItems)))
            let source: ContextContentSource = .reference(ComposePollContextReferenceContentSource(sourceView: sourceView))
            
            let contextController = makeContextController(
                presentationData: presentationData,
                source: source,
                items: items,
                gesture: nil
            )
            self.environment?.controller()?.presentInGlobalOverlay(contextController)
        }
        
        private func openCustomTimePicker() {
            guard let component = self.component else {
                return
            }
            
            var currentTime: Int32?
            switch self.timeLimit {
            case let .duration(duration):
                currentTime = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) + duration
            case let .deadline(deadline):
                currentTime = deadline
            }
            
            let controller = ChatScheduleTimeScreen(
                context: component.context,
                mode: .poll,
                currentTime: currentTime,
                currentRepeatPeriod: nil,
                minimalTime: nil,
                isDark: false,
                completion: { [weak self] result in
                    guard let self else {
                        return
                    }
                    self.timeLimit = .deadline(result.time)
                    self.state?.updated()
                }
            )
            (self.environment?.controller() as? ComposePollScreen)?.parentController()?.push(controller)
        }
        
        func deactivateInput() {
            self.currentInputMode = .keyboard
            if hasFirstResponder(self) {
                self.endEditing(true)
            } else {
                self.state?.updated(transition: .spring(duration: 0.4).withUserData(TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))))
            }
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
            
            let theme = environment.theme.withModalBlocksBackground()
            
            var isChannel = false
            if case let .channel(channel) = component.peer, case .broadcast = channel.info {
                isChannel = true
            }
            
            if self.component == nil {
                self.isQuiz = component.isQuiz ?? false
                if !self.isQuiz {
                    self.isMultiAnswer = true
                }
                if !isChannel {
                    self.isAnonymous = false
                    if !self.isQuiz {
                        self.canAddOptions = true
                    }
                } else {
                    self.shuffleOptions = true
                }
                self.canRevote = true
                
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
                        hasStickers: true,
                        hasGifs: false,
                        hideBackground: true,
                        maskEdge: .clip,
                        sendGif: nil
                    )
                )
                self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    var inputData = value
                    inputData.stickers = nil
                    self.inputMediaNodeData = inputData
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
                    editGif: { _, _ in
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
                
                
                self.cachedViewIcon = renderSettingsIcon(name: "Item List/Icons/View", backgroundColors: [UIColor(rgb: 0x0A84FF)])
                self.cachedMultipleIcon = renderSettingsIcon(name: "Item List/Icons/Multiple", backgroundColors: [UIColor(rgb: 0xFF9F0A)])
                self.cachedAddIcon = renderSettingsIcon(name: "Item List/Icons/Add", backgroundColors: [UIColor(rgb: 0x32ADE6)])
                self.cachedRevoteIcon = renderSettingsIcon(name: "Item List/Icons/Update", backgroundColors: [UIColor(rgb: 0x5E5CE6)])
                self.cachedShuffleIcon = renderSettingsIcon(name: "Item List/Icons/Shuffle", backgroundColors: [UIColor(rgb: 0xAF52DE)])
                self.cachedQuizIcon = renderSettingsIcon(name: "Item List/Icons/Checkbox", backgroundColors: [UIColor(rgb: 0x34C759)])
                self.cachedDurationIcon = renderSettingsIcon(name: "Item List/Icons/Timer", backgroundColors: [UIColor(rgb: 0xFF453A)])
                
                self.cachedEmptyIcon = generateSingleColorImage(size: CGSize(width: 30.0, height: 30.0), color: .clear)
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 16.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 30.0
            
            if themeUpdated {
                self.backgroundColor = theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            var pollTextSectionItems: [AnyComponentWithIdentity<Empty>] = []
            pollTextSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListComposePollOptionComponent(
                externalState: self.pollTextInputState,
                context: component.context,
                style: .glass,
                theme: theme,
                strings: environment.strings,
                resetText: self.resetPollText.flatMap { resetText in
                    return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                },
                assumeIsEditing: self.inputMediaNodeTargetTag === self.pollTextFieldTag,
                characterLimit: component.initialData.maxPollTextLength,
                emptyLineHandling: .allowed,
                returnKeyAction: {
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
            
            var pollDescriptionAttachment: ListComposePollOptionComponent.Attachment
            pollDescriptionAttachment = .init(media: self.pollDescriptionMedia?.media, progress: self.pollDescriptionMedia?.progress, alwaysDisplayAttachButton: true)
            
            pollTextSectionItems.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ListComposePollOptionComponent(
                externalState: self.pollDescriptionInputState,
                context: component.context,
                style: .glass,
                theme: theme,
                strings: environment.strings,
                resetText: nil,
                assumeIsEditing: self.inputMediaNodeTargetTag === self.pollDescriptionFieldTag,
                characterLimit: 1024,
                attachment: pollDescriptionAttachment,
                emptyLineHandling: .allowed,
                returnKeyType: .default,
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
                attachAction: { [weak self] in
                    self?.openAttachedMedia(subject: .description)
                },
                tag: self.pollDescriptionFieldTag
            ))))
            
            let pollTextSectionSize = self.pollTextSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_TextHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
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
                if let itemView = pollTextSectionView.itemView(id: 1) as? ListComposePollOptionComponent.View {
                    itemView.updateCustomPlaceholder(value: environment.strings.CreatePoll_DescriptionPlaceholder, size: itemView.bounds.size, transition: .immediate)
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
                    optionSelection = ListComposePollOptionComponent.Selection(
                        isSelected: self.selectedQuizOptionIds.contains(optionId),
                        isMultiSelection: self.effectiveIsMultiAnswer,
                        isQuiz: self.isQuiz,
                        toggle: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.effectiveIsMultiAnswer {
                                if self.selectedQuizOptionIds.contains(optionId) {
                                    self.selectedQuizOptionIds.remove(optionId)
                                } else {
                                    self.selectedQuizOptionIds.insert(optionId)
                                }
                            } else {
                                if self.selectedQuizOptionIds.contains(optionId) {
                                    self.selectedQuizOptionIds.remove(optionId)
                                } else {
                                    self.selectedQuizOptionIds.removeAll()
                                    self.selectedQuizOptionIds.insert(optionId)
                                }
                            }
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                    )
                }
                
                var canDelete = true
                if i == self.pollOptions.count - 1 {
                    canDelete = false
                }
                
                var pollOptionAttachment: ListComposePollOptionComponent.Attachment
                pollOptionAttachment = .init(media: pollOption.media?.media, progress: pollOption.media?.progress, alwaysDisplayAttachButton: false)
                
                pollOptionsSectionItems.append(AnyComponentWithIdentity(id: pollOption.id, component: AnyComponent(ListComposePollOptionComponent(
                    externalState: pollOption.textInputState,
                    context: component.context,
                    style: .glass,
                    theme: theme,
                    strings: environment.strings,
                    resetText: pollOption.resetText.flatMap { resetText in
                        return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                    },
                    assumeIsEditing: self.inputMediaNodeTargetTag === pollOption.textFieldTag,
                    characterLimit: component.initialData.maxPollOptionLength,
                    hasLeftInset: true,
                    canReorder: true,
                    canAdd: i != 0 && i < component.initialData.maxPollAnswersCount,
                    attachment: pollOptionAttachment,
                    emptyLineHandling: .notAllowed,
                    returnKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let index = self.pollOptions.firstIndex(where: { $0.id == optionId }) {
                            if index == self.pollOptions.count - 1 {
                                self.deactivateInput()
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
                    attachAction: { [weak self] in
                        self?.openAttachedMedia(subject: .pollOption(pollOption))
                    },
                    deleteAction: canDelete ? { [weak self] in
                        guard let self else {
                            return
                        }
                        self.pollOptions.removeAll(where: { $0.id == optionId })
                        self.state?.updated(transition: .spring(duration: 0.4))
                    } : nil,
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
                
                var isReordering = false
                if let reorderingItem = self.reorderingItem, itemId == reorderingItem.id {
                    isReordering = true
                }
                itemView.contents.view?.isHidden = isReordering
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
                    theme: theme,
                    style: .glass,
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
                        string: environment.strings.CreatePoll_OptionsTitle,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
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
                    text: .plain(NSAttributedString(string: environment.strings.CreatePoll_AllOptionsAdded, font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor)),
                    maximumNumberOfLines: 0
                ))
            } else {
                var filledOptionsCount = 0
                for option in self.pollOptions {
                    if option.textInputState.hasText {
                        filledOptionsCount += 1
                    }
                }
                let remainingCount = component.initialData.maxPollAnswersCount - filledOptionsCount
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
                    color: theme.list.freeTextColor,
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
                        
            var pollSettingsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if !isChannel {
                pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "anonymous", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_ShowWhoVoted,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 2
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_ShowWhoVotedInfo,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 3,
                            lineSpacing: 0.1
                        )))
                    ], alignment: .left, spacing: 4.0)),
                    verticalAlignment: .middle,
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        Image(image: self.cachedViewIcon, size: CGSize(width: 30.0, height: 30.0))
                    )), false),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: !self.isAnonymous, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isAnonymous = !self.isAnonymous
                        if self.isAnonymous {
                            self.canAddOptions = false
                        }
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
            }
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "multiAnswer", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_MultiAnswer,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 2
                    ))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_MultiAnswerInfo,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )))
                ], alignment: .left, spacing: 4.0)),
                verticalAlignment: .middle,
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    Image(image: self.cachedMultipleIcon, size: CGSize(width: 30.0, height: 30.0))
                )), false),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.effectiveIsMultiAnswer, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isMultiAnswer = !self.effectiveIsMultiAnswer
                    
                    if self.isMultiAnswer == false {
                        for option in self.pollOptions {
                            if self.selectedQuizOptionIds.contains(option.id) {
                                self.selectedQuizOptionIds.removeAll()
                                self.selectedQuizOptionIds.insert(option.id)
                                break
                            }
                        }
                    }
                    
                    self.state?.updated(transition: .spring(duration: 0.4).withUserData(MultilineTextComponent.CrossfadeTransition()))
                })),
                action: nil
            ))))
            
            if !isChannel {
                pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "adding", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_AddingOptions,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 2
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_AddingOptionsInfo,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 3,
                            lineSpacing: 0.1
                        )))
                    ], alignment: .left, spacing: 4.0)),
                    verticalAlignment: .middle,
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        Image(image: self.cachedAddIcon, size: CGSize(width: 30.0, height: 30.0))
                    )), false),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: self.isQuiz ? .lock : .regular, isOn: self.canAddOptions, isInteractive: !self.isQuiz, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if !self.canAddOptions && self.isAnonymous {
                            self.isAnonymous = false
                        }
                        self.canAddOptions = !self.canAddOptions
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
            }
            
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "revoting", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_Revoting,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 2
                    ))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_RevotingInfo,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )))
                ], alignment: .left, spacing: 4.0)),
                verticalAlignment: .middle,
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    Image(image: self.cachedRevoteIcon, size: CGSize(width: 30.0, height: 30.0))
                )), false),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.canRevote, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.canRevote = !self.canRevote
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "shuffle", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ShuffleOptions,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 2
                    ))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ShuffleOptionsInfo,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )))
                ], alignment: .left, spacing: 4.0)),
                verticalAlignment: .middle,
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    Image(image: self.cachedShuffleIcon, size: CGSize(width: 30.0, height: 30.0))
                )), false),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.shuffleOptions, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.shuffleOptions = !self.shuffleOptions
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "quiz", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_EnableQuiz,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 2
                    ))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.effectiveIsMultiAnswer ? environment.strings.CreatePoll_EnableQuizMultiInfo : environment.strings.CreatePoll_EnableQuizInfo,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )))
                ], alignment: .left, spacing: 4.0)),
                verticalAlignment: .middle,
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    Image(image: self.cachedQuizIcon, size: CGSize(width: 30.0, height: 30.0))
                )), false),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isQuiz, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isQuiz = !self.isQuiz
                    if self.isQuiz {
                        if self.canAddOptions {
                            self.canAddOptions = false
                        }
                        self.canRevote = false
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "limitDuration", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_LimitDuration,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 2
                    ))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_LimitDurationInfo,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )))
                ], alignment: .left, spacing: 4.0)),
                verticalAlignment: .middle,
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    Image(image: self.cachedDurationIcon, size: CGSize(width: 30.0, height: 30.0))
                )), false),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.limitDuration, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.limitDuration = !self.limitDuration
                    self.state?.updated(transition: .spring(duration: 0.4))
                    
                    if self.limitDuration {
                        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.scrollView.contentSize.height - self.scrollView.bounds.size.height), animated: true)
                    }
                })),
                action: nil
            ))))
            
            var pollSettingsFooter: AnyComponent<Empty>? = nil
            if self.limitDuration {
                let title: String
                let value: String
                
                switch self.timeLimit {
                case let .duration(duration):
                    title = environment.strings.CreatePoll_LimitDuration_Duration
                    value = timeIntervalString(strings: environment.strings, value: duration)
                case let .deadline(deadline):
                    title = environment.strings.CreatePoll_LimitDuration_PollEnds
                    value = stringForMediumCompactDate(timestamp: deadline, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, withTime: true)
                }
                
                pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "duration", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: title,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 2
                        )))
                    ], alignment: .left, spacing: 4.0)),
                    verticalAlignment: .middle,
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        Image(image: self.cachedEmptyIcon, size: CGSize(width: 30.0, height: 30.0))
                    )), false),
                    icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: value,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )))),
                    accessory: .expandArrows,
                    action: { [weak self] view in
                        guard let self else {
                            return
                        }
                        self.presentTimeLimitOptions(sourceView: view)
                    }
                ))))
                
                pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "hideResults", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.CreatePoll_LimitDuration_HideResults,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 2
                        )))
                    ], alignment: .left, spacing: 4.0)),
                    verticalAlignment: .middle,
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        Image(image: self.cachedEmptyIcon, size: CGSize(width: 30.0, height: 30.0))
                    )), false),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.hideResults, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.hideResults = !self.hideResults
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
                
                pollSettingsFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.CreatePoll_LimitDuration_HideResultsInfo,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                ))
            }
                    
            let pollSettingsSectionSize = self.pollSettingsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_SettingsTitle,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: pollSettingsFooter,
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
            
            var quizAnswerAttachment: ListComposePollOptionComponent.Attachment
            quizAnswerAttachment = .init(media: self.quizAnswerMedia?.media, progress: self.quizAnswerMedia?.progress, alwaysDisplayAttachButton: true)
            
            var quizAnswerSectionHeight: CGFloat = 0.0
            quizAnswerSectionHeight += sectionSpacing
            let quizAnswerSectionSize = self.quizAnswerSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ExplanationHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreatePoll_ExplanationInfo,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListComposePollOptionComponent(
                            externalState: self.quizAnswerTextInputState,
                            context: component.context,
                            style: .glass,
                            theme: theme,
                            strings: environment.strings,
                            resetText: self.resetQuizAnswerText.flatMap { resetText in
                                return ListComposePollOptionComponent.ResetText(value: NSAttributedString(string: resetText))
                            },
                            assumeIsEditing: self.inputMediaNodeTargetTag === self.quizAnswerTextInputTag,
                            characterLimit: component.initialData.maxPollTextLength,
                            attachment: quizAnswerAttachment,
                            emptyLineHandling: .allowed,
                            returnKeyAction: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.deactivateInput()
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
                            attachAction: { [weak self] in
                                self?.openAttachedMedia(subject: .quizAnswer)
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
            
            contentHeight += 24.0
            
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
            
            let title = self.isQuiz ? environment.strings.CreatePoll_QuizTitle : environment.strings.CreatePoll_Title
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: title,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 40.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    component.overNavigationContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? ComposePollScreen else {
                            return
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    component.overNavigationContainer.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let validatedInput = self.validatedInput()
            var isValid = false
            var isUploading = false
            if case .ready = validatedInput {
                isValid = true
            } else if case .isUploading = validatedInput {
                isUploading = true
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: nil,
                    backgroundColor: isValid ? environment.theme.list.itemCheckColors.fillColor : environment.theme.list.itemCheckColors.fillColor.desaturated().withMultipliedAlpha(0.5),
                    isDark: environment.theme.overallDarkAppearance,
                    state: .tintedGlass,
                    isEnabled: isValid || isUploading,
                    component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                        Text(text: environment.strings.MediaPicker_Send, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? ComposePollScreen else {
                            return
                        }
                        controller.sendPressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: barButtonSize.height)
            )
            let doneButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - doneButtonSize.width, y: 16.0), size: doneButtonSize)
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    component.overNavigationContainer.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
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
            
            if isEditing {
                if let controller = environment.controller() as? ComposePollScreen {
                    DispatchQueue.main.async { [weak controller] in
                        controller?.requestAttachmentMenuExpansion()
                    }
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
            
            let edgeEffectHeight: CGFloat = 88.0
            let topEdgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: transition)
            
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - edgeEffectHeight - environment.additionalInsets.bottom), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
            
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
    fileprivate let completion: (ComposedPoll) -> Void
    private var isDismissed: Bool = false
    
    private let overNavigationContainer: UIView
    
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
        
        self.overNavigationContainer = SparseContainerView()
        
        super.init(context: context, component: ComposePollScreenComponent(
            context: context,
            overNavigationContainer: self.overNavigationContainer,
            peer: peer,
            isQuiz: isQuiz,
            initialData: initialData,
            completion: completion
        ), navigationBarAppearance: .transparent, theme: .default)
        
        self._hasGlassStyle = true
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
        if self._hasGlassStyle {
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: UIView()), animated: false)
        } else {
            self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        }
        
        let sendButtonItem = UIBarButtonItem(title: presentationData.strings.CreatePoll_Create, style: .done, target: self, action: #selector(self.sendPressed))
        self.sendButtonItem = sendButtonItem
        if self._hasGlassStyle {
        
        } else {
            self.navigationItem.setRightBarButton(sendButtonItem, animated: false)
        }
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
        
        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(self.overNavigationContainer, at: 0)
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
            maxPollTextLength: 200,
            maxPollOptionLength: 100,
            maxPollAnwsersCount: maxPollAnwsersCount
        )
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc fileprivate func sendPressed() {
        guard let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
            return
        }
        let validatedInput = componentView.validatedInput()
        if case let .ready(poll) = validatedInput {
            self.completion(poll)
            self.dismiss()
        } else if case .isUploading = validatedInput {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let controller = UndoOverlayController(
                presentationData: presentationData,
                content: .info(title: presentationData.strings.CreatePoll_MediaUploading_Title, text: presentationData.strings.CreatePoll_MediaUploading_Text, timeout: nil, customUndoText: nil),
                position: .top,
                action: { _ in
                    return false
                }
            )
            self.present(controller, in: .current)
        }
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
        guard let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if componentView.hasAnyData {
            let controller = textAlertController(context: self.context, title: nil, text: presentationData.strings.CreatePoll_DiscardPoll, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Attachment_CancelSelectionAlertNo, action: {
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Attachment_CancelSelectionAlertYes, action: {
                completion()
            })])
            self.present(controller, in: .window(.root))
        } else {
            completion()
        }
    }
    
    public func shouldDismissImmediately() -> Bool {
        guard let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
            return true
        }
        if componentView.hasAnyData {
            return false
        } else {
            return true
        }
    }
}

private final class ComposePollContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}

private final class ComposePollContextControllerContentSource: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceView: UIView?
    let sourceRect: CGRect
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceView: UIView?, sourceRect: CGRect) {
        self.controller = controller
        self.sourceView = sourceView
        self.sourceRect = sourceRect
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceView] in
            if let sourceView = sourceView {
                return (sourceView, sourceRect)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        if let controller = self.controller as? GalleryControllerProtocol {
            controller.viewDidAppear(false)
        }
    }
}

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
