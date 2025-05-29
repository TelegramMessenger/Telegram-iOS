import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import ItemListUI
import AccountContext
import PresentationDataUtils
import ListSectionComponent
import ListItemComponentAdaptor
import TelegramStringFormatting
import UndoUI
import ChatMessagePaymentAlertController

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let botName: String
    let botAddress: String
    let preparedMessage: PreparedInlineMessage
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        botName: String,
        botAddress: String,
        preparedMessage: PreparedInlineMessage,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.botName = botName
        self.botAddress = botAddress
        self.preparedMessage = preparedMessage
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let amountSection = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            
            let controller = environment.controller
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: theme.actionSheet.controlAccentColor)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 120.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: closeButton.size.width / 2.0 + sideInset, y: 28.0))
            )
                    
            let title = title.update(
                component: Text(text: environment.strings.WebApp_ShareMessage_Title, font: Font.bold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 40.0
                        
            let amountFont = Font.regular(13.0)
            let amountTextColor = theme.list.freeTextColor
            let amountMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: amountFont, textColor: amountTextColor), bold: MarkdownAttributeSet(font: amountFont, textColor: amountTextColor), link: MarkdownAttributeSet(font: amountFont, textColor: theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })

            let amountInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.WebApp_ShareMessage_Info(component.botName).string, attributes: amountMarkdownAttributes, textAlignment: .natural))
            let amountFooter = AnyComponent(MultilineTextComponent(
                text: .plain(amountInfoString),
                maximumNumberOfLines: 0,
                highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                highlightAction: { attributes in
                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                    } else {
                        return nil
                    }
                },
                tapAction: { attributes, _ in
                    if let controller = controller() as? WebAppMessagePreviewScreen, let navigationController = controller.navigationController as? NavigationController {
                        component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_PaidContent_AmountInfo_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                    }
                }
            ))
                        
            var text: String = ""
            var entities: TextEntitiesMessageAttribute?
            var media: [Media] = []
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            switch component.preparedMessage.result {
            case let .internalReference(reference):
                switch reference.message {
                case let .auto(textValue, entitiesValue, replyMarkupValue):
                    text = textValue
                    entities = entitiesValue
                    if let file = reference.file {
                        media = [file]
                    } else if let image = reference.image {
                        media = [image]
                    }
                    replyMarkup = replyMarkupValue
                case let .text(textValue, entitiesValue, disableUrlPreview, previewParameters, replyMarkupValue):
                    text = textValue
                    entities = entitiesValue
                    let _ = disableUrlPreview
                    let _ = previewParameters
                    replyMarkup = replyMarkupValue
                case let .contact(contact, replyMarkupValue):
                    media = [contact]
                    replyMarkup = replyMarkupValue
                case let .mapLocation(map, replyMarkupValue):
                    media = [map]
                    replyMarkup = replyMarkupValue
                case let .invoice(invoice, replyMarkupValue):
                    media = [invoice]
                    replyMarkup = replyMarkupValue
                default:
                    break
                }
            case let .externalReference(reference):
                switch reference.message {
                case let .auto(textValue, entitiesValue, replyMarkupValue):
                    text = textValue
                    entities = entitiesValue
                    if let content = reference.content {
                        media = [content]
                    }
                    replyMarkup = replyMarkupValue
                case let .text(textValue, entitiesValue, disableUrlPreview, previewParameters, replyMarkupValue):
                    text = textValue
                    entities = entitiesValue
                    let _ = disableUrlPreview
                    let _ = previewParameters
                    replyMarkup = replyMarkupValue
                case let .contact(contact, replyMarkupValue):
                    media = [contact]
                    replyMarkup = replyMarkupValue
                case let .mapLocation(map, replyMarkupValue):
                    media = [map]
                    replyMarkup = replyMarkupValue
                case let .invoice(invoice, replyMarkupValue):
                    media = [invoice]
                    replyMarkup = replyMarkupValue
                default:
                    break
                }
            }
            
            let messageItem = PeerNameColorChatPreviewItem.MessageItem(
                text: text,
                entities: entities,
                media: media,
                replyMarkup: replyMarkup,
                botAddress: component.botAddress
            )
                     
            let listItemParams = ListViewItemLayoutParams(width: context.availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            let amountSection = amountSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.WebApp_ShareMessage_PreviewTitle.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: amountFooter,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: PeerNameColorChatPreviewItem(
                                context: component.context,
                                theme: environment.theme,
                                componentTheme: environment.theme,
                                strings: environment.strings,
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
                    ]
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(amountSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + amountSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += amountSection.size.height
            contentSize.height += 32.0
            
            let buttonString: String = environment.strings.WebApp_ShareMessage_Share
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        if let controller = controller() as? WebAppMessagePreviewScreen {
                            controller.proceed()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            contentSize.height += 15.0
            
            contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)

            return contentSize
        }
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
}

private final class WebAppMessagePreviewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let botName: String
    private let botAddress: String
    private let preparedMessage: PreparedInlineMessage
    
    init(
        context: AccountContext,
        botName: String,
        botAddress: String,
        preparedMessage: PreparedInlineMessage
    ) {
        self.context = context
        self.botName = botName
        self.botAddress = botAddress
        self.preparedMessage = preparedMessage
    }
    
    static func ==(lhs: WebAppMessagePreviewSheetComponent, rhs: WebAppMessagePreviewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
        
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        botName: context.component.botName,
                        botAddress: context.component.botAddress,
                        preparedMessage: context.component.preparedMessage,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() as? WebAppMessagePreviewScreen {
                                    controller.completeWithResult(false)
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.blocksBackgroundColor),
                    followContentSizeChanges: false,
                    clipsContent: true,
                    isScrollEnabled: false,
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
                                    if let controller = controller() as? WebAppMessagePreviewScreen {
                                        controller.completeWithResult(false)
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() as? WebAppMessagePreviewScreen {
                                    controller.completeWithResult(false)
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

public final class WebAppMessagePreviewScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let preparedMessage: PreparedInlineMessage
    fileprivate let completion: (Bool) -> Void
        
    public init(
        context: AccountContext,
        botName: String,
        botAddress: String,
        preparedMessage: PreparedInlineMessage,
        completion: @escaping (Bool) -> Void
    ) {
        self.context = context
        self.preparedMessage = preparedMessage
        self.completion = completion
        
        super.init(
            context: context,
            component: WebAppMessagePreviewSheetComponent(
                context: context,
                botName: botName,
                botAddress: botAddress,
                preparedMessage: preparedMessage
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func presentPaidMessageAlertIfNeeded(peers: [EnginePeer], requiresStars: [EnginePeer.Id: Int64], completion: @escaping () -> Void) {
        
    }
    
    fileprivate func complete(peers: [EnginePeer], controller: ViewController?) {
        let _ = (self.context.engine.data.get(
            EngineDataMap(
                peers.map { TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars.init(id: $0.id) }
            ),
            EngineDataList(
                peers.map { TelegramEngine.EngineData.Item.Peer.RenderedPeer.init(id: $0.id) }
            )
        )
        |> deliverOnMainQueue).start(next: { [weak self] sendPaidMessageStars, renderedPeers in
            guard let self else {
                return
            }
            let renderedPeers = renderedPeers.compactMap({ $0 })
            var totalAmount: StarsAmount = .zero
            var chargingPeers: [EngineRenderedPeer] = []
            for peer in renderedPeers {
                if let maybeAmount = sendPaidMessageStars[peer.peerId], let amount = maybeAmount {
                    totalAmount = totalAmount + amount
                    chargingPeers.append(peer)
                }
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let proceed = { [weak self] in
                guard let self else {
                    return
                }
                
                for peer in peers {
                    var starsAmount: StarsAmount?
                    if let maybeAmount = sendPaidMessageStars[peer.id], let amount = maybeAmount {
                        starsAmount = amount
                    }
                    let _ = self.context.engine.messages.enqueueOutgoingMessage(
                        to: peer.id,
                        replyTo: nil,
                        storyId: nil,
                        content: .preparedInlineMessage(self.preparedMessage),
                        sendPaidMessageStars: starsAmount
                    ).start()
                }
                
                let text: String
                if peers.count == 1, let peer = peers.first {
                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                    let firstPeerName = firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    let secondPeerName = secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                } else if let peer = peers.first {
                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                } else {
                    text = ""
                }
                
                if let navigationController = self.navigationController as? NavigationController {
                    Queue.mainQueue().after(1.0) {
                        guard let lastController = navigationController.viewControllers.last as? ViewController else {
                            return
                        }
                        lastController.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: text), elevatedLayout: false, position: .top, animateInAsReplacement: true, action: { action in
                            return false
                        }), in: .window(.root))
                    }
                }
                
                self.completeWithResult(true)
                self.dismiss()
                controller?.dismiss()
            }
            
            if totalAmount.value > 0 {
                let controller = chatMessagePaymentAlertController(
                    context: nil,
                    presentationData: presentationData,
                    updatedPresentationData: nil,
                    peers: chargingPeers,
                    count: 1,
                    amount: totalAmount,
                    totalAmount: totalAmount,
                    hasCheck: false,
                    navigationController: self.navigationController as? NavigationController,
                    completion: { _ in
                        proceed()
                    }
                )
                self.present(controller, in: .window(.root))
            } else {
                proceed()
            }
        })
    }
        
    private var completed = false
    fileprivate func completeWithResult(_ result: Bool) {
        guard !self.completed else {
            return
        }
        self.completion(result)
    }
    
    fileprivate func proceed() {
        let peerTypes = self.preparedMessage.peerTypes
        var types: [ReplyMarkupButtonRequestPeerType] = []
        if peerTypes.contains(.users) {
            types.append(.user(.init(isBot: false, isPremium: nil)))
        }
        if peerTypes.contains(.bots) {
            types.append(.user(.init(isBot: true, isPremium: nil)))
        }
        if peerTypes.contains(.channels) {
            types.append(.channel(.init(isCreator: false, hasUsername: nil, userAdminRights: TelegramChatAdminRights(rights: [.canPostMessages]), botAdminRights: nil)))
        }
        if peerTypes.contains(.groups) {
            types.append(.group(.init(isCreator: false, hasUsername: nil, isForum: nil, botParticipant: false, userAdminRights: nil, botAdminRights: nil)))
        }
        
        let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: types, hasContactSelector: false, multipleSelection: true, selectForumThreads: true, immediatelyActivateMultipleSelection: true))
        
        controller.multiplePeersSelected = { [weak self, weak controller] peers, _, _, _, _, _ in
            guard let self else {
                return
            }
            self.complete(peers: peers, controller: controller)
        }
        
        self.push(controller)
    }
    
    public func dismissAnimated() {
        self.completeWithResult(false)
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
