import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import GlassBarButtonComponent
import ButtonComponent
import PresentationDataUtils
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import ListTextFieldItemComponent
import ListItemComponentAdaptor
import GlassBackgroundComponent
import ItemListAvatarAndNameInfoItem
import ItemListUI
import PeerInfoUI
import UndoUI
import RankChatPreviewItem

private let rankFieldTag = GenericComponentViewTag()
private let rankMaxLength: Int32 = 16

private final class ChatParticipantRightsContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: ChatParticipantRightsScreen.Subject
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        subject: ChatParticipantRightsScreen.Subject,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
    }
    
    static func ==(lhs: ChatParticipantRightsContent, rhs: ChatParticipantRightsContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let subject: ChatParticipantRightsScreen.Subject
        
        var disposable: Disposable?
        var peer: EnginePeer?
        var presence: EnginePeer.Presence?
        
        var rank: String?
        var initialRank: String?
        
        weak var controller: ViewController?
        
        init(context: AccountContext, subject: ChatParticipantRightsScreen.Subject) {
            self.context = context
            self.subject = subject
                        
            super.init()
            
            let participantId: EnginePeer.Id
            switch subject {
            case let .rank(_, participantIdValue, rankValue, _):
                participantId = participantIdValue
                self.rank = rankValue
                self.initialRank = rankValue
            }
            
            self.disposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: participantId),
                TelegramEngine.EngineData.Item.Peer.Presence(id: participantId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer, presence in
                guard let self else {
                    return
                }
                self.peer = peer
                self.presence = presence
                self.updated()
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func animateError() {
            guard let controller = self.controller as? ChatParticipantRightsScreen else {
                return
            }
            controller.animateError()
        }
        
        func complete() {
            guard let controller = self.controller as? ChatParticipantRightsScreen else {
                return
            }
            controller.complete(rank: self.rank)
        }
    } 
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(MultilineTextComponent.self)
        let rankSection = Child(ListSectionComponent.self)
        let doneButton = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller()
            }
                        
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { _ in
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
                        
            var contentHeight: CGFloat = 38.0
            
            let titleString: String
            switch component.subject {
            case .rank:
                titleString = strings.EditRank_Title
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight))
            )
            contentHeight += 44.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let listItemParams = ListViewItemLayoutParams(width: context.availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            let peer: EnginePeer
            if let current = state.peer {
                peer = current
            } else {
                peer = EnginePeer.user(TelegramUser(id: component.subject.participantId, accessHash: nil, firstName: " ", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            }
            
            var rankPreviewPlaceholder = ""
            var rankFooterString = ""
            var rankRole: ChatRankInfoScreenRole = .member
            switch component.subject {
            case let .rank(_, _, _, role):
                if peer.id == component.context.account.peerId {
                    rankFooterString = strings.EditRank_InfoYou
                } else {
                    rankFooterString = strings.EditRank_Info(peer.compactDisplayTitle).string
                }
                switch role {
                case .creator:
                    rankPreviewPlaceholder = strings.Conversation_Owner
                case .admin:
                    rankPreviewPlaceholder = strings.Conversation_Admin
                case .member:
                    rankPreviewPlaceholder = "0️⃣"
                }
                rankRole = role
            }
            
            let rankValue = state.rank ?? ""
            let messageItem = RankChatPreviewItem.MessageItem(
                peer: peer,
                text: "Reinhardt, we need to find you some new tunes.",
                entities: nil,
                media: [],
                rank: rankValue.isEmpty ? rankPreviewPlaceholder : rankValue,
                rankRole: rankRole
            )
            
            var rankSectionItems: [AnyComponentWithIdentity<Empty>] = []
            rankSectionItems.append(
                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                    itemGenerator: RankChatPreviewItem(
                        context: component.context,
                        theme: environment.theme,
                        componentTheme: theme,
                        strings: strings,
                        sectionId: 0,
                        fontSize: presentationData.chatFontSize,
                        chatBubbleCorners: presentationData.chatBubbleCorners,
                        wallpaper: presentationData.chatWallpaper,
                        dateTimeFormat: environment.dateTimeFormat,
                        nameDisplayOrder: presentationData.nameDisplayOrder,
                        messageItems: [messageItem]
                    ),
                    params: listItemParams
                )))
            )
            rankSectionItems.append(
                AnyComponentWithIdentity(id: 1, component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass,
                    theme: theme,
                    initialText: state.initialRank ?? "",
                    resetText: nil,
                    placeholder: strings.EditRank_Placeholder,
                    characterLimit: Int(rankMaxLength),
                    autocapitalizationType: .sentences,
                    autocorrectionType: .default,
                    returnKeyType: .done,
                    contentInsets: .zero,
                    updated: { [weak state] value in
                        guard let state else {
                            return
                        }
                        state.rank = value
                        state.updated(transition: .easeInOut(duration: 0.2))
                    },
                    shouldUpdateText: { [weak state] text in
                        if text.containsEmoji {
                            state?.animateError()
                            return false
                        }
                        return true
                    },
                    onReturn: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.complete()
                    },
                    tag: rankFieldTag
                )))
            )
            
            let rankSection = rankSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: rankFooterString,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: rankSectionItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(rankSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + rankSection.size.height / 2.0))
            )
            contentHeight += rankSection.size.height
            
            contentHeight += 24.0
            
            let buttonTitle: String
            switch component.subject {
            case let .rank(_, _, initialRank, _):
                if (initialRank ?? "").isEmpty && (state.rank ?? "").isEmpty {
                    buttonTitle = strings.EditRank_AddLater
                } else if (initialRank ?? "").isEmpty && !(state.rank ?? "").isEmpty {
                    buttonTitle = strings.EditRank_AddTag
                } else if !(initialRank ?? "").isEmpty && (state.rank ?? "").isEmpty {
                    buttonTitle = strings.EditRank_RemoveTag
                } else {
                    buttonTitle = strings.EditRank_EditTag
                }
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let doneButton = doneButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonTitle),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.complete()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                transition: context.transition
            )
            context.add(doneButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + doneButton.size.height / 2.0))
            )
            contentHeight += doneButton.size.height
            
            if environment.inputHeight > 0.0 {
                contentHeight += 15.0
                contentHeight += max(environment.inputHeight, environment.safeInsets.bottom)
            } else {
                contentHeight += buttonInsets.bottom
            }
          
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class ChatParticipantRightsComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: ChatParticipantRightsScreen.Subject
    
    init(
        context: AccountContext,
        subject: ChatParticipantRightsScreen.Subject
    ) {
        self.context = context
        self.subject = subject
    }
    
    static func ==(lhs: ChatParticipantRightsComponent, rhs: ChatParticipantRightsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(ChatParticipantRightsContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        cancel: { animate in
                            if animate {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: false,
                    clipsContent: true,
                    isScrollEnabled: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public class ChatParticipantRightsScreen: ViewControllerComponentContainer {
    public enum Subject {
        case rank(peerId: EnginePeer.Id, participantId: EnginePeer.Id, rank: String?, role: ChatRankInfoScreenRole)
        
        var peerId: EnginePeer.Id {
            switch self {
            case let .rank(peerId, _, _, _):
                return peerId
            }
        }
        
        var participantId: EnginePeer.Id {
            switch self {
            case let .rank(_, participantId, _, _):
                return participantId
            }
        }
    }
    
    private let context: AccountContext
    private let subject: Subject
    
    public init(
        context: AccountContext,
        subject: Subject
    ) {
        self.context = context
        self.subject = subject
        
        super.init(
            context: context,
            component: ChatParticipantRightsComponent(
                context: context,
                subject: subject
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    fileprivate func complete(rank: String?) {
        var rank = rank
        if rank?.isEmpty == true {
            rank = nil
        }
        
        if let rank, rank.count > rankMaxLength {
            if let view = self.node.hostView.findTaggedView(tag: rankFieldTag) as? ListTextFieldItemComponent.View {
                view.animateError()
                HapticFeedback().error()
            }
            return
        }
        
        let _ = self.context.peerChannelMemberCategoriesContextsManager.updateMemberRank(engine: self.context.engine, peerId: self.subject.peerId, memberId: self.subject.participantId, rank: rank).start()
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let navigationController = self.navigationController as? NavigationController {
            Queue.mainQueue().after(0.5) {
                var hadRank = false
                if case let .rank(_, _, rank, _) = self.subject, !(rank ?? "").isEmpty {
                    hadRank = true
                }
                
                var title: String?
                var text: String?
                if let rank {
                    title = hadRank ? presentationData.strings.Chat_TagUpdated_Edited : presentationData.strings.Chat_TagUpdated_Added
                    text = rank
                } else if hadRank {
                    text = presentationData.strings.Chat_TagUpdated_Removed
                }
                if let text {
                    let toastController = UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: title, text: text, cancel: nil, destructive: false), appearance: .init(isNarrow: true), action: { _ in return true})
                    (navigationController.topViewController as? ViewController)?.present(toastController, in: .current)
                }
            }
        }
        
        self.dismissAnimated()
    }
    
    fileprivate func animateError() {
        if let view = self.node.hostView.findTaggedView(tag: rankFieldTag) as? ListTextFieldItemComponent.View {
            view.animateError()
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let view = self.node.hostView.findTaggedView(tag: rankFieldTag) as? ListTextFieldItemComponent.View {
            Queue.mainQueue().after(0.01) {
                view.activateInput()
                view.selectAll()
            }
        }
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
