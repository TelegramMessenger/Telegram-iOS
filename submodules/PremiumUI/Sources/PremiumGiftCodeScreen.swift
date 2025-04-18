import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import BalancedTextComponent
import ConfettiEffect
import AvatarNode
import TextFormat
import TelegramStringFormatting
import UndoUI
import InvisibleInkDustNode
import PremiumStarComponent

private final class PremiumGiftCodeSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumGiftCodeScreen.Subject
    let action: () -> Void
    let cancel: (Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let copyLink: (String) -> Void
    let shareLink: (String) -> Void
    let displayHiddenTooltip: () -> Void
    
    init(
        context: AccountContext,
        subject: PremiumGiftCodeScreen.Subject,
        action: @escaping () -> Void,
        cancel: @escaping  (Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        copyLink: @escaping (String) -> Void,
        shareLink: @escaping (String) -> Void,
        displayHiddenTooltip: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.action = action
        self.cancel = cancel
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.displayHiddenTooltip = displayHiddenTooltip
    }
    
    static func ==(lhs: PremiumGiftCodeSheetContent, rhs: PremiumGiftCodeSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private var disposable: Disposable?
        var initialized = false
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        
        init(context: AccountContext, subject: PremiumGiftCodeScreen.Subject) {
            self.context = context
            
            super.init()
            
            var peerIds: [EnginePeer.Id] = []
            switch subject {
            case let .giftCode(giftCode):
                if let fromPeerId = giftCode.fromPeerId {
                    peerIds.append(fromPeerId)
                }
                if let toPeerId = giftCode.toPeerId {
                    peerIds.append(toPeerId)
                }
            case let .boost(channelId, boost):
                peerIds.append(channelId)
                if let peerId = boost.peer?.id {
                    peerIds.append(peerId)
                }
            }
            
            self.disposable = (context.engine.data.get(
                EngineDataMap(
                    peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    }
                )
            ) |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                if let strongSelf = self {
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for peerId in peerIds {
                        if let maybePeer = peers[peerId], let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    strongSelf.peerMap = peersMap
                    strongSelf.initialized = true
                
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let title = Child(MultilineTextComponent.self)
        let star = Child(PremiumStarComponent.self)
        let description = Child(BalancedTextComponent.self)
        let linkButton = Child(Button.self)
        let table = Child(TableComponent.self)
        let additional = Child(BalancedTextComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            let accountContext = context.component.context
            
            let state = context.state
            let subject = component.subject
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: { [weak component] in
                        component?.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            
            let titleText: String
            let descriptionText: String
            let additionalText: String
            let buttonText: String
            
            let link: String?
            let date: Int32
            let fromPeer: EnginePeer?
            var toPeerId: EnginePeer.Id?
            let toPeer: EnginePeer?
            let months: Int32
            
            var gloss = false
            switch subject {
            case let .giftCode(giftCode):
                gloss = !giftCode.isUsed
                if let usedDate = giftCode.usedDate {
                    let dateString = stringForMediumDate(timestamp: usedDate, strings: strings, dateTimeFormat: dateTimeFormat)
                    titleText = strings.GiftLink_UsedTitle
                    descriptionText = strings.GiftLink_UsedDescription
                    additionalText = strings.GiftLink_UsedFooter(dateString).string
                    buttonText = strings.Common_OK
                } else {
                    titleText = strings.GiftLink_Title
                    descriptionText = strings.GiftLink_Description
                    additionalText = strings.GiftLink_Footer
                    buttonText = strings.GiftLink_UseLink
                }
                link = "https://t.me/giftcode/\(giftCode.slug)"
                date = giftCode.date
                if let fromPeerId = giftCode.fromPeerId {
                    fromPeer = state.peerMap[fromPeerId]
                } else {
                    fromPeer = nil
                }
                toPeerId = giftCode.toPeerId
                if let toPeerId = giftCode.toPeerId {
                    toPeer = state.peerMap[toPeerId]
                } else {
                    toPeer = nil
                }
                months = giftCode.months
            case let .boost(channelId, boost):
                titleText = strings.GiftLink_Title
                if let peer = boost.peer, !boost.flags.contains(.isUnclaimed) {
                    toPeer = boost.peer
                    if boost.slug == nil {
                        descriptionText = strings.GiftLink_PersonalDescription(peer.compactDisplayTitle).string
                    } else {
                        descriptionText = strings.GiftLink_PersonalUsedDescription(peer.compactDisplayTitle).string
                    }
                } else {
                    toPeer = nil
                    descriptionText = strings.GiftLink_UnclaimedDescription
                }
                if boost.flags.contains(.isUnclaimed) || boost.slug == nil {
                    additionalText = strings.GiftLink_NotUsedFooter
                } else {
                    additionalText = ""
                }
                buttonText = strings.Common_OK
                if let slug = boost.slug {
                    link = "https://t.me/giftcode/\(slug)"
                } else {
                    link = nil
                }
                date = boost.date
                if boost.flags.contains(.isUnclaimed) {
                    toPeerId = nil
                } else {
                    toPeerId = boost.peer?.id
                }
                fromPeer = state.peerMap[channelId]
                months = Int32(round(Float(boost.expires - boost.date) / (86400.0 * 30.0)))
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let star = star.update(
                component: PremiumStarComponent(
                    theme: theme,
                    isIntro: false,
                    isVisible: true,
                    hasIdleAnimations: true,
                    colors: [
                        UIColor(rgb: 0x6a94ff),
                        UIColor(rgb: 0x9472fd),
                        UIColor(rgb: 0xe26bd3)
                    ]
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 200.0),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let description = description.update(
                component: BalancedTextComponent(
                    text: .markdown(text: descriptionText, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let linkButton = linkButton.update(
                component: Button(
                    content: AnyComponent(
                        GiftLinkButtonContentComponent(theme: environment.theme, text: link)
                    ),
                    action: {
                        if let link {
                            component.copyLink(link)
                        } else {
                            component.displayHiddenTooltip()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: .immediate
            )
            
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            var tableItems: [TableComponent.Item] = []
                        
            tableItems.append(.init(
                id: "from",
                title: strings.GiftLink_From,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(PeerCellComponent(context: context.component.context, textColor: tableLinkColor, peer: fromPeer)),
                        action: {
                            if let peer = fromPeer, peer.id != accountContext.account.peerId {
                                component.openPeer(peer)
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        }
                    )
                )
            ))
            if let toPeer {
                tableItems.append(.init(
                    id: "to",
                    title: strings.GiftLink_To,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(PeerCellComponent(context: context.component.context, textColor: tableLinkColor, peer: toPeer)),
                            action: {
                                if toPeer.id != accountContext.account.peerId {
                                    component.openPeer(toPeer)
                                    Queue.mainQueue().after(1.0, {
                                        component.cancel(false)
                                    })
                                }
                            }
                        )
                    )
                ))
            } else if toPeerId == nil {
                tableItems.append(.init(
                    id: "to",
                    title: strings.GiftLink_To,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.GiftLink_NoRecipient, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            let giftTitle = strings.GiftLink_TelegramPremium(months)
            tableItems.append(.init(
                id: "gift",
                title: strings.GiftLink_Gift,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: giftTitle, font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            if case let .giftCode(giftCode) = component.subject {
                let giftReason: String
                if giftCode.toPeerId == nil {
                    giftReason = strings.GiftLink_Reason_Unclaimed
                } else {
                    giftReason = giftCode.isGiveaway ? strings.GiftLink_Reason_Giveaway : strings.GiftLink_Reason_Gift
                }
                tableItems.append(.init(
                    id: "reason",
                    title: strings.GiftLink_Reason,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: giftReason, font: tableFont, textColor: giftCode.messageId != nil ? tableLinkColor : tableTextColor)))),
                            automaticHighlight: giftCode.messageId != nil,
                            action: {
                                if let messageId = giftCode.messageId {
                                    component.openMessage(messageId)
                                    Queue.mainQueue().after(1.0) {
                                        component.cancel(false)
                                    }
                                }
                            }
                        )
                    )
                ))
            } else if case let .boost(_, boost) = component.subject {
                if boost.flags.contains(.isUnclaimed) {
                    let giftReason = strings.GiftLink_Reason_Unclaimed
                    tableItems.append(.init(
                        id: "reason",
                        title: strings.GiftLink_Reason,
                        component: AnyComponent(
                            Button(
                                content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: giftReason, font: tableFont, textColor: boost.giveawayMessageId != nil ? tableLinkColor : tableTextColor)))),
                                automaticHighlight: boost.giveawayMessageId != nil,
                                action: {
                                    if let messageId = boost.giveawayMessageId {
                                        component.openMessage(messageId)
                                        Queue.mainQueue().after(1.0) {
                                            component.cancel(false)
                                        }
                                    }
                                }
                            )
                        )
                    ))
                }
            }
            tableItems.append(.init(
                id: "date",
                title: strings.GiftLink_Date,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let additional = additional.update(
                component: BalancedTextComponent(
                    text: .markdown(text: additionalText, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    highlightColor: linkColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let link {
                            component.shareLink(link)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
          
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: buttonText,
                    theme: SolidRoundedButtonComponent.Theme(theme: theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: gloss,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    isLoading: state.inProgress,
                    action: { [weak state] in
                        if gloss {
                            component.action()
                            if let state {
                                state.inProgress = true
                                state.updated()
                            }
                        } else {
                            component.cancel(true)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 28.0))
            )
            
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: star.size.height / 2.0))
            )
            
            var originY: CGFloat = 0.0
            originY += star.size.height - 32.0
            
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + description.size.height / 2.0))
            )
            originY += description.size.height + 21.0
            
            context.add(linkButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + linkButton.size.height / 2.0))
            )
            originY += linkButton.size.height + 16.0
            
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
            )
            originY += table.size.height + 23.0
            
            context.add(additional
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + additional.size.height / 2.0))
            )
            originY += additional.size.height + 23.0
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + 5.0 + environment.safeInsets.bottom)
        
            return contentSize
        }
    }
}

private final class PremiumGiftCodeSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumGiftCodeScreen.Subject
    let action: () -> Void
    let openPeer: (EnginePeer) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let copyLink: (String) -> Void
    let shareLink: (String) -> Void
    let displayHiddenTooltip: () -> Void
    
    init(
        context: AccountContext,
        subject: PremiumGiftCodeScreen.Subject,
        action: @escaping () -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        copyLink: @escaping (String) -> Void,
        shareLink: @escaping (String) -> Void,
        displayHiddenTooltip: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.action = action
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.displayHiddenTooltip = displayHiddenTooltip
    }
    
    static func ==(lhs: PremiumGiftCodeSheetComponent, rhs: PremiumGiftCodeSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
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
                    content: AnyComponent<EnvironmentType>(PremiumGiftCodeSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        action: context.component.action,
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
                        },
                        openPeer: context.component.openPeer,
                        openMessage: context.component.openMessage,
                        copyLink: context.component.copyLink,
                        shareLink: context.component.shareLink,
                        displayHiddenTooltip: context.component.displayHiddenTooltip
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
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

public class PremiumGiftCodeScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case giftCode(PremiumGiftCodeInfo)
        case boost(EnginePeer.Id, ChannelBoostersContext.State.Boost)
    }
    
    private let context: AccountContext
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: PremiumGiftCodeScreen.Subject,
        forceDark: Bool = false,
        action: @escaping () -> Void,
        openPeer: @escaping (EnginePeer) -> Void = { _ in },
        openMessage: @escaping (EngineMessage.Id) -> Void = { _ in },
        shareLink: @escaping (String) -> Void = { _ in }
    ) {
        self.context = context
        
        var copyLinkImpl: ((String) -> Void)?
        var displayHiddenTooltipImpl: (() -> Void)?
        super.init(
            context: context,
            component: PremiumGiftCodeSheetComponent(
                context: context,
                subject: subject,
                action: action,
                openPeer: openPeer,
                openMessage: openMessage,
                copyLink: { link in
                    copyLinkImpl?(link)
                }, 
                shareLink: shareLink,
                displayHiddenTooltip: {
                    displayHiddenTooltipImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        
        copyLinkImpl = { [weak self] link in
            UIPasteboard.general.string = link
            
            guard let self else {
                return
            }
            self.dismissAllTooltips()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, position: .top, action: { _ in return true }), in: .window(.root))
        }
        
        displayHiddenTooltipImpl = { [weak self] in
            guard let self else {
                return
            }
            self.dismissAllTooltips()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.GiftLink_LinkHidden, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, action: { _ in return true }), in: .window(.root))
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
}

final class GiftLinkButtonContentComponent: CombinedComponent {
    let theme: PresentationTheme
    let text: String?
    let isSeparateSection: Bool
    
    init(
        theme: PresentationTheme,
        text: String?,
        isSeparateSection: Bool = false
    ) {
        self.theme = theme
        self.text = text
        self.isSeparateSection = isSeparateSection
    }
    
    static func ==(lhs: GiftLinkButtonContentComponent, rhs: GiftLinkButtonContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isSeparateSection != rhs.isSeparateSection {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        let dust = Child(DustComponent.self)
        
        return { context in
            let component = context.component
            
            let sideInset: CGFloat = 38.0
            
            let background = background.update(
                component: RoundedRectangle(color: component.isSeparateSection ? component.theme.list.itemBlocksBackgroundColor : component.theme.list.itemInputField.backgroundColor, cornerRadius: 10.0),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let _ = component.text {
                let text = text.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: (component.text ?? "").replacingOccurrences(of: "https://", with: ""),
                            font: Font.regular(17.0),
                            textColor: component.theme.list.itemPrimaryTextColor,
                            paragraphAlignment: .natural
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset - sideInset, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                let icon = icon.update(
                    component: BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: component.theme.list.itemAccentColor),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(icon
                    .position(CGPoint(x: context.availableSize.width - icon.size.width / 2.0 - 14.0, y: context.availableSize.height / 2.0))
                )
                context.add(text
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                )
            } else {
                let dust = dust.update(
                    component: DustComponent(color: component.theme.list.itemSecondaryTextColor),
                    availableSize: CGSize(width: context.availableSize.width * 0.8, height: context.availableSize.height * 0.54),
                    transition: context.transition
                )
                context.add(dust
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                )
            }

            return context.availableSize
        }
    }
}

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String
        public let component: AnyComponent<Empty>

        public init<IdType: Hashable>(id: IdType, title: String, component: AnyComponent<Empty>) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [_UpdatedChildComponent] = []
            var updatedValueChildren: [_UpdatedChildComponent] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            for item in context.component.items {
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren.append(titleChild)
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            var i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            
            for item in context.component.items {
                let titleChild = updatedTitleChildren[i]
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: rightColumnWidth - horizontalPadding * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append(valueChild)
                
                let rowHeight = max(40.0, max(titleChild.size.height, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                i += 1
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: context.component.theme.list.itemInputField.backgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: totalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 5.0
                borderImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: totalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (titleChild, valueChild) in zip(updatedTitleChildren, updatedValueChildren) {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                let valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + horizontalPadding, y: originY + verticalPadding), size: valueChild.size)
                
                context.add(titleChild
                    .position(titleFrame.center)
                )
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}

private final class PeerCellComponent: Component {
    let context: AccountContext
    let textColor: UIColor
    let peer: EnginePeer?

    init(context: AccountContext, textColor: UIColor, peer: EnginePeer?) {
        self.context = context
        self.textColor = textColor
        self.peer = peer
    }

    static func ==(lhs: PeerCellComponent, rhs: PeerCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.textColor !== rhs.textColor {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let text = ComponentView<Empty>()
                
        private var component: PeerCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 13.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
            let avatarSize = CGSize(width: 22.0, height: 22.0)
            let spacing: CGFloat = 6.0
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.peer?.compactDisplayTitle ?? "", font: Font.regular(15.0), textColor: component.textColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: avatarSize.width + textSize.width + spacing, height: textSize.height)
            
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.frame = avatarFrame
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: avatarSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                transition.setFrame(view: view, frame: textFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class DustComponent: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: DustComponent, rhs: DustComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    final class View: UIView {
        private let dustView = InvisibleInkDustView(textNode: nil, enableAnimations: true)
                
        private var component: DustComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.dustView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: DustComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let rects: [CGRect] = [CGRect(origin: .zero, size: availableSize).insetBy(dx: 5.0, dy: 5.0)]
            self.dustView.update(size: availableSize, color: component.color, textColor: component.color, rects: rects, wordRects: rects)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
