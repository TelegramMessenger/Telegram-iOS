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

final class ComposePollScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let isQuiz: Bool?
    let completion: (ComposedPoll) -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        isQuiz: Bool?,
        completion: @escaping (ComposedPoll) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.isQuiz = isQuiz
        self.completion = completion
    }

    static func ==(lhs: ComposePollScreenComponent, rhs: ComposePollScreenComponent) -> Bool {
        return true
    }
    
    private final class PollOption {
        let id: Int
        let textInputState = ListComposePollOptionComponent.ExternalState()
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
        private let pollOptionsSectionFooter = ComponentView<Empty>()
        private var pollOptionsSectionContainer: ListSectionContentView
        
        private let pollSettingsSection = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private var reactionSelectionControl: ComponentView<Empty>?
        
        private var isUpdating: Bool = false
        
        private var component: ComposePollScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var emojiContent: EmojiPagerContentComponent?
        private var emojiContentDisposable: Disposable?
        
        private let pollTextInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let pollTextFieldTag = NSObject()
        private var resetPollText: String?
        
        private var quizAnswerTextInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private var resetQuizAnswerText: String?
        
        private var nextPollOptionId: Int = 0
        private var pollOptions: [PollOption] = []
        
        private var isAnonymous: Bool = true
        private var isMultiAnswer: Bool = false
        private var isQuiz: Bool = false
        private var selectedQuizOptionId: Int?
        
        private var displayInput: Bool = false
        
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
            self.emojiContentDisposable?.dispose()
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
                mappedOptions.append(TelegramMediaPollOption(
                    text: pollOption.textInputState.text.string,
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
            
            var mappedSolution: String?
            if self.isQuiz && self.quizAnswerTextInputState.text.length != 0 {
                mappedSolution = self.quizAnswerTextInputState.text.string
            }
            
            return ComposedPoll(
                publicity: self.isAnonymous ? .anonymous : .public,
                kind: mappedKind,
                text: self.pollTextInputState.text.string,
                options: mappedOptions,
                correctAnswers: mappedCorrectAnswers,
                results: TelegramMediaPollResults(
                    voters: nil,
                    totalVoters: nil,
                    recentVoters: [],
                    solution: mappedSolution.flatMap { mappedSolution in
                        return TelegramMediaPollResults.Solution(text: mappedSolution, entities: [])
                    }
                ),
                deadlineTimeout: nil
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
            self.updateScrolling(transition: .immediate)
        }
        
        private func updateScrolling(transition: Transition) {
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, self.scrollView.contentOffset.y / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
        }
        
        func update(component: ComposePollScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            if self.component == nil {
                self.pollOptions.append(ComposePollScreenComponent.PollOption(
                    id: self.nextPollOptionId
                ))
                self.nextPollOptionId += 1
                self.pollOptions.append(ComposePollScreenComponent.PollOption(
                    id: self.nextPollOptionId
                ))
                self.nextPollOptionId += 1
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            if self.emojiContentDisposable == nil {
                let emojiContent = EmojiPagerContentComponent.emojiInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    isStandalone: false,
                    subject: .emoji,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: nil,
                    selectedItems: Set(),
                    backgroundIconColor: nil,
                    hasSearch: false,
                    forceHasPremium: true
                )
                self.emojiContentDisposable = (emojiContent
                |> deliverOnMainQueue).start(next: { [weak self] emojiContent in
                    guard let self else {
                        return
                    }
                    self.emojiContent = emojiContent
                    
                    emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                        performItemAction: { [weak self] _, item, _, _, _, _ in
                            guard let self else {
                                return
                            }
                            guard let itemFile = item.itemFile else {
                                return
                            }
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            let _ = itemFile
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.25))
                            }
                        },
                        deleteBackwards: {
                        },
                        openStickerSettings: {
                        },
                        openFeatured: {
                        },
                        openSearch: {
                        },
                        addGroupAction: { _, _, _ in
                        },
                        clearGroup: { _ in
                        },
                        editAction: { _ in
                        },
                        pushController: { c in
                        },
                        presentController: { c in
                        },
                        presentGlobalOverlayController: { c in
                        },
                        navigationController: {
                            return nil
                        },
                        requestUpdate: { _ in
                        },
                        updateSearchQuery: { _ in
                        },
                        updateScrollingToItemGroup: {
                        },
                        onScroll: {},
                        chatPeerId: nil,
                        peekBehavior: nil,
                        customLayout: nil,
                        externalBackground: nil,
                        externalExpansionView: nil,
                        customContentView: nil,
                        useOpaqueTheme: true,
                        hideBackground: false,
                        stateContext: nil,
                        addImage: nil
                    )
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            var pollTextSectionItems: [AnyComponentWithIdentity<Empty>] = []
            pollTextSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.pollTextInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetPollText.flatMap { resetPollText in
                    return ListMultilineTextFieldItemComponent.ResetText(value: resetPollText)
                },
                placeholder: "Enter Question",
                autocapitalizationType: .none,
                autocorrectionType: .no,
                characterLimit: 256,
                emptyLineHandling: .oneConsecutive,
                updated: { _ in
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.pollTextFieldTag
            ))))
            self.resetPollText = nil
            
            //TODO:localize
            let pollTextSectionSize = self.pollTextSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "QUESTION",
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
            if let pollTextSectionView = self.pollTextSection.view {
                if pollTextSectionView.superview == nil {
                    self.scrollView.addSubview(pollTextSectionView)
                    self.pollTextSection.parentState = state
                }
                transition.setFrame(view: pollTextSectionView, frame: pollTextSectionFrame)
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
                        return ListComposePollOptionComponent.ResetText(value: resetText)
                    },
                    characterLimit: 256,
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
                            if index != 0 {
                                if let pollOptionView = self.pollOptionsSectionContainer.itemViews[self.pollOptions[index - 1].id] {
                                    if let pollOptionComponentView = pollOptionView.contents.view as? ListComposePollOptionComponent.View {
                                        pollOptionComponentView.activateInput()
                                    }
                                }
                            }
                        }
                    },
                    selection: optionSelection
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
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
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
            
            if self.pollOptions.count < 10, let lastOption = self.pollOptions.last {
                if lastOption.textInputState.text.length != 0 {
                    self.pollOptions.append(PollOption(id: self.nextPollOptionId))
                    self.nextPollOptionId += 1
                    processPollOptionItem(self.pollOptions.count - 1)
                }
            }
            
            for i in 0 ..< pollOptionsSectionReadyItems.count {
                let placeholder: String
                if i == pollOptionsSectionReadyItems.count - 1 {
                    placeholder = "Add an Option"
                } else {
                    placeholder = "Option"
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
                readyItems: pollOptionsSectionReadyItems,
                transition: transition
            )
            
            let sectionHeaderSideInset: CGFloat = 16.0
            let pollOptionsSectionHeaderSize = self.pollOptionsSectionHeader.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "POLL OPTIONS",
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
            var pollOptionsFooterItems: [AnimatedTextComponent.Item] = []
            if self.pollOptions.count >= 10, !"".isEmpty {
                pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                    id: 3,
                    isUnbreakable: true,
                    content: .text("You have added the maximum number of options.")
                ))
            } else {
                pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                    id: 0,
                    isUnbreakable: true,
                    content: .text("You can add ")
                ))
                pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                    id: 1,
                    isUnbreakable: true,
                    content: .number(10 - self.pollOptions.count, minDigits: 1)
                ))
                pollOptionsFooterItems.append(AnimatedTextComponent.Item(
                    id: 2,
                    isUnbreakable: true,
                    content: .text(" more options.")
                ))
            }
            let pollOptionsSectionFooterSize = self.pollOptionsSectionFooter.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                    color: environment.theme.list.freeTextColor,
                    items: pollOptionsFooterItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - sectionHeaderSideInset * 2.0, height: 1000.0)
            )
            let pollOptionsSectionFooterFrame = CGRect(origin: CGPoint(x: sideInset + sectionHeaderSideInset, y: contentHeight), size: pollOptionsSectionFooterSize)
            if let pollOptionsSectionFooterView = self.pollOptionsSectionFooter.view {
                if pollOptionsSectionFooterView.superview == nil {
                    pollOptionsSectionFooterView.layer.anchorPoint = CGPoint()
                    self.scrollView.addSubview(pollOptionsSectionFooterView)
                }
                transition.setPosition(view: pollOptionsSectionFooterView, position: pollOptionsSectionFooterFrame.origin)
                pollOptionsSectionFooterView.bounds = CGRect(origin: CGPoint(), size: pollOptionsSectionFooterFrame.size)
            }
            contentHeight += pollOptionsSectionFooterSize.height
            contentHeight += sectionSpacing
            
            var pollSettingsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "anonymous", component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Anonymous Voting",
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
            pollSettingsSectionItems.append(AnyComponentWithIdentity(id: "multiAnswer", component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Multiple Answers",
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
                            string: "Quiz Mode",
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
                            string: "Polls in Quiz Mode have one correct answer. Users can't revoke their answers.",
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
                            string: "EXPLANATION",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Users will see this comment after choosing a wrong answer, good for educational purposes.",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                            externalState: self.quizAnswerTextInputState,
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            initialText: "",
                            resetText: self.resetQuizAnswerText.flatMap { resetQuizAnswerText in
                                return ListMultilineTextFieldItemComponent.ResetText(value: resetQuizAnswerText)
                            },
                            placeholder: "Add a Comment (Optional)",
                            autocapitalizationType: .none,
                            autocorrectionType: .no,
                            characterLimit: 256,
                            emptyLineHandling: .oneConsecutive,
                            updated: { _ in
                            },
                            textUpdateTransition: .spring(duration: 0.4)
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let quizAnswerSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + quizAnswerSectionHeight), size: quizAnswerSectionSize)
            if let quizAnswerSectionView = self.quizAnswerSection.view {
                if quizAnswerSectionView.superview == nil {
                    self.scrollView.addSubview(quizAnswerSectionView)
                    self.quizAnswerSection.parentState = state
                }
                transition.setFrame(view: quizAnswerSectionView, frame: quizAnswerSectionFrame)
                transition.setAlpha(view: quizAnswerSectionView, alpha: self.isQuiz ? 1.0 : 0.0)
            }
            quizAnswerSectionHeight += pollTextSectionSize.height
            
            if self.isQuiz {
                contentHeight += quizAnswerSectionHeight
            }
            
            var inputHeight: CGFloat = 0.0
            if self.displayInput, let emojiContent = self.emojiContent {
                let reactionSelectionControl: ComponentView<Empty>
                var animateIn = false
                if let current = self.reactionSelectionControl {
                    reactionSelectionControl = current
                } else {
                    animateIn = true
                    reactionSelectionControl = ComponentView()
                    self.reactionSelectionControl = reactionSelectionControl
                }
                let reactionSelectionControlSize = reactionSelectionControl.update(
                    transition: animateIn ? .immediate : transition,
                    component: AnyComponent(EmojiSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        sideInset: environment.safeInsets.left,
                        bottomInset: environment.safeInsets.bottom,
                        deviceMetrics: environment.deviceMetrics,
                        emojiContent: emojiContent,
                        stickerContent: nil,
                        backgroundIconColor: nil,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        separatorColor: environment.theme.list.itemBlocksSeparatorColor,
                        backspace: { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.25))
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let reactionSelectionControlFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - reactionSelectionControlSize.height), size: reactionSelectionControlSize)
                if let reactionSelectionControlView = reactionSelectionControl.view {
                    if reactionSelectionControlView.superview == nil {
                        self.addSubview(reactionSelectionControlView)
                    }
                    if animateIn {
                        reactionSelectionControlView.frame = reactionSelectionControlFrame
                        transition.animatePosition(view: reactionSelectionControlView, from: CGPoint(x: 0.0, y: reactionSelectionControlFrame.height), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: reactionSelectionControlView, frame: reactionSelectionControlFrame)
                    }
                }
                inputHeight = reactionSelectionControlSize.height
            } else if let reactionSelectionControl = self.reactionSelectionControl {
                self.reactionSelectionControl = nil
                if let reactionSelectionControlView = reactionSelectionControl.view {
                    transition.setPosition(view: reactionSelectionControlView, position: CGPoint(x: reactionSelectionControlView.center.x, y: availableSize.height + reactionSelectionControlView.bounds.height * 0.5), completion: { [weak reactionSelectionControlView] _ in
                        reactionSelectionControlView?.removeFromSuperview()
                    })
                }
            }
            
            if self.displayInput {
                contentHeight += bottomInset + 8.0
                contentHeight += inputHeight
            } else {
                contentHeight += bottomInset
                contentHeight += environment.safeInsets.bottom
            }
            
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
            
            self.updateScrolling(transition: transition)
            
            if self.pollTextInputState.isEditing || self.pollOptions.contains(where: { $0.textInputState.isEditing }) {
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
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ComposePollScreen: ViewControllerComponentContainer, AttachmentContainable {
    private let context: AccountContext
    private let completion: (ComposedPoll) -> Void
    private var isDismissed: Bool = false
    
    fileprivate private(set) var sendButtonItem: UIBarButtonItem?
    
    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
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
    
    public init(
        context: AccountContext,
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
            completion: completion
        ), navigationBarAppearance: .default, theme: .default)
        
        //TODO:localize
        self.title = "New Poll"
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        let sendButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(self.sendPressed))
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
