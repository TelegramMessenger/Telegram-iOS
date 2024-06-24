import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
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
import AvatarNode
import TextFormat
import TelegramStringFormatting
import UndoUI
import StarsImageComponent
import GalleryUI

private final class StarsTransactionSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: StarsTransactionScreen.Subject
    let action: () -> Void
    let cancel: (Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let openMedia: ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void
    let copyTransactionId: (String) -> Void
    
    init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        action: @escaping () -> Void,
        cancel: @escaping  (Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        openMedia: @escaping ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void,
        copyTransactionId: @escaping (String) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.action = action
        self.cancel = cancel
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.openMedia = openMedia
        self.copyTransactionId = copyTransactionId
    }
    
    static func ==(lhs: StarsTransactionSheetContent, rhs: StarsTransactionSheetContent) -> Bool {
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
        
        init(context: AccountContext, subject: StarsTransactionScreen.Subject) {
            self.context = context
            
            super.init()
            
            var peerIds: [EnginePeer.Id] = []
            switch subject {
            case let .transaction(transaction, _):
                if case let .peer(peer) = transaction.peer {
                    peerIds.append(peer.id)
                }
            case let .receipt(receipt):
                peerIds.append(receipt.botPaymentId)
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
        let star = Child(StarsImageComponent.self)
        let amount = Child(BalancedTextComponent.self)
        let amountStar = Child(BundleIconComponent.self)
        let description = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let additional = Child(BalancedTextComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        let refundBackgound = Child(RoundedRectangle.self)
        let refundText = Child(MultilineTextComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let controller = environment.controller
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
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
            let amountText: String
            let descriptionText: String
            let additionalText: String
            let buttonText: String
            
            let count: Int64
            let transactionId: String?
            let date: Int32
            let via: String?
            let messageId: EngineMessage.Id?
            let toPeer: EnginePeer?
            let transactionPeer: StarsContext.State.Transaction.Peer?
            let media: [Media]
            let photo: TelegramMediaWebFile?
            let isRefund: Bool
            
            var delayedCloseOnOpenPeer = true
            switch subject {
            case let .transaction(transaction, parentPeer):
                switch transaction.peer {
                case let .peer(peer):
                    if !transaction.media.isEmpty {
                        titleText = strings.Stars_Transaction_MediaPurchase
                    } else {
                        titleText = transaction.title ?? peer.compactDisplayTitle
                    }
                    via = nil
                case .appStore:
                    titleText = strings.Stars_Transaction_AppleTopUp_Title
                    via = strings.Stars_Transaction_AppleTopUp_Subtitle
                case .playMarket:
                    titleText = strings.Stars_Transaction_GoogleTopUp_Title
                    via = strings.Stars_Transaction_GoogleTopUp_Subtitle
                case .premiumBot:
                    titleText = strings.Stars_Transaction_PremiumBotTopUp_Title
                    via = strings.Stars_Transaction_PremiumBotTopUp_Subtitle
                case .fragment:
                    if parentPeer.id == component.context.account.peerId {
                        titleText = strings.Stars_Transaction_FragmentTopUp_Title
                        via = strings.Stars_Transaction_FragmentTopUp_Subtitle
                    } else {
                        titleText = strings.Stars_Transaction_FragmentWithdrawal_Title
                        via = strings.Stars_Transaction_FragmentWithdrawal_Subtitle
                    }
                case .ads:
                    titleText = strings.Stars_Transaction_TelegramAds_Title
                    via = strings.Stars_Transaction_TelegramAds_Subtitle
                case .unsupported:
                    titleText = strings.Stars_Transaction_Unsupported_Title
                    via = nil
                }
                if !transaction.media.isEmpty {
                    var description: String = ""
                    var photoCount: Int32 = 0
                    var videoCount: Int32 = 0
                    for media in transaction.media {
                        if let _ = media as? TelegramMediaFile {
                            videoCount += 1
                        } else {
                            photoCount += 1
                        }
                    }
                    if photoCount > 0 && videoCount > 0 {
                        description += strings.Stars_Transaction_MediaAnd(strings.Stars_Transaction_Photos(photoCount), strings.Stars_Transaction_Videos(videoCount)).string
                    } else if photoCount > 0 {
                        if photoCount > 1 {
                            description += strings.Stars_Transaction_Photos(photoCount)
                        } else {
                            description += strings.Stars_Transaction_SinglePhoto
                        }
                    } else if videoCount > 0 {
                        if videoCount > 1 {
                            description += strings.Stars_Transaction_Videos(videoCount)
                        } else {
                            description += strings.Stars_Transaction_SingleVideo
                        }
                    }
                    descriptionText = description
                } else {
                    descriptionText = transaction.description ?? ""
                }
                
                messageId = transaction.paidMessageId

                count = transaction.count
                transactionId = transaction.id
                date = transaction.date
                if case let .peer(peer) = transaction.peer {
                    toPeer = peer
                } else {
                    toPeer = nil
                }
                transactionPeer = transaction.peer
                media = transaction.media
                photo = transaction.photo
                isRefund = transaction.flags.contains(.isRefund)
            case let .receipt(receipt):
                titleText = receipt.invoiceMedia.title
                descriptionText = receipt.invoiceMedia.description
                count = (receipt.invoice.prices.first?.amount ?? receipt.invoiceMedia.totalAmount) * -1
                via = nil
                messageId = nil
                transactionId = receipt.transactionId
                date = receipt.date
                if let peer = state.peerMap[receipt.botPaymentId] {
                    toPeer = peer
                } else {
                    toPeer = nil
                }
                transactionPeer = nil
                media = []
                photo = receipt.invoiceMedia.photo
                isRefund = false
                delayedCloseOnOpenPeer = false
            }
            
            let formattedAmount = presentationStringsFormattedNumber(abs(Int32(count)), dateTimeFormat.groupingSeparator)
            if count < 0 {
                amountText = "- \(formattedAmount)"
            } else {
                amountText = "+ \(formattedAmount)"
            }
            additionalText = strings.Stars_Transaction_Terms
            buttonText = strings.Common_OK
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(25.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let imageSubject: StarsImageComponent.Subject
            if !media.isEmpty {
                imageSubject = .media(media)
            } else if let photo {
                imageSubject = .photo(photo)
            } else if let transactionPeer {
                imageSubject = .transactionPeer(transactionPeer)
            } else if let toPeer {
                imageSubject = .transactionPeer(.peer(toPeer))
            } else {
                imageSubject = .none
            }
            let star = star.update(
                component: StarsImageComponent(
                    context: component.context,
                    subject: imageSubject,
                    theme: theme,
                    diameter: 90.0,
                    backgroundColor: theme.actionSheet.opaqueItemBackgroundColor,
                    action: !media.isEmpty ? { transitionNode, addToTransitionSurface in
                        component.openMedia(media, transitionNode, addToTransitionSurface)
                    } : nil
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 200.0),
                transition: .immediate
            )
            
            let amountAttributedText = NSMutableAttributedString(string: amountText, font: Font.semibold(17.0), textColor: amountText.hasPrefix("-") ? theme.list.itemDestructiveColor : theme.list.itemDisclosureActions.constructive.fillColor)
            let amount = amount.update(
                component: BalancedTextComponent(
                    text: .plain(amountAttributedText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let amountStar = amountStar.update(
                component: BundleIconComponent(
                    name: "Premium/Stars/StarMedium",
                    tintColor: nil
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            var tableItems: [TableComponent.Item] = []
                        
            if let toPeer {
                tableItems.append(.init(
                    id: "to",
                    title: count < 0 ? strings.Stars_Transaction_To : strings.Stars_Transaction_From,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                PeerCellComponent(
                                    context: component.context,
                                    textColor: tableLinkColor,
                                    peer: toPeer
                                )
                            ),
                            action: {
                                if delayedCloseOnOpenPeer {
                                    component.openPeer(toPeer)
                                    Queue.mainQueue().after(1.0, {
                                        component.cancel(false)
                                    })
                                } else {
                                    if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                        chatController.playShakeAnimation()
                                    }
                                    component.cancel(true)
                                }
                            }
                        )
                    )
                ))
            } else if let via {
                tableItems.append(.init(
                    id: "via",
                    title: strings.Stars_Transaction_Via,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: via, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            if let messageId {
                let peerName: String
                if case let .transaction(_, parentPeer) = component.subject {
                    if parentPeer.id == component.context.account.peerId {
                        if let toPeer {
                            peerName = toPeer.addressName ?? "c/\(toPeer.id.id._internalGetInt64Value())"
                        } else {
                            peerName = ""
                        }
                    } else {
                        peerName = parentPeer.addressName ?? "c/\(parentPeer.id.id._internalGetInt64Value())"
                    }
                } else {
                    peerName = ""
                }
                tableItems.append(.init(
                    id: "media",
                    title: strings.Stars_Transaction_Media,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: "t.me/\(peerName)/\(messageId.id)", font: tableFont, textColor: tableLinkColor)))
                            ),
                            action: {
                                component.openMessage(messageId)
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        )
                    )
                ))
            }

            if let transactionId {
                tableItems.append(.init(
                    id: "transaction",
                    title: strings.Stars_Transaction_Id,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                TransactionCellComponent(
                                    textColor: tableTextColor,
                                    accentColor: tableLinkColor,
                                    transactionId: transactionId
                                )
                            ),
                            action: {
                                component.copyTransactionId(transactionId)
                            }
                        )
                    ),
                    insets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 5.0)
                ))
            }
            
            tableItems.append(.init(
                id: "date",
                title: strings.Stars_Transaction_Date,
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
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
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
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_Transaction_Terms_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
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
                    gloss: false,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    isLoading: state.inProgress,
                    action: {
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 31.0 + 125.0))
            )
            
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: star.size.height / 2.0 - 19.0))
            )
            
            var originY: CGFloat = 0.0
            originY += star.size.height - 23.0
            
            if !descriptionText.isEmpty {
                let description = description.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: descriptionText,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 3
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(description
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + description.size.height / 2.0))
                )
                originY += description.size.height + 10.0
            }
            
            let amountSpacing: CGFloat = 3.0
            var totalAmountWidth: CGFloat = amount.size.width + amountSpacing + amountStar.size.width
            var amountOriginX: CGFloat = floor(context.availableSize.width - totalAmountWidth) / 2.0
            if isRefund {
                let refundText = refundText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Stars_Transaction_Refund,
                            font: Font.medium(14.0),
                            textColor: theme.list.itemDisclosureActions.constructive.fillColor
                        ))
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                let refundBackground = refundBackgound.update(
                    component: RoundedRectangle(
                        color: theme.list.itemDisclosureActions.constructive.fillColor.withAlphaComponent(0.1),
                        cornerRadius: 6.0
                    ),
                    availableSize: CGSize(width: refundText.size.width + 10.0, height: refundText.size.height + 4.0),
                    transition: .immediate
                )
                totalAmountWidth += amountSpacing * 2.0 + refundBackground.size.width
                amountOriginX = floor(context.availableSize.width - totalAmountWidth) / 2.0
                
                context.add(refundBackground
                    .position(CGPoint(x: amountOriginX + amount.size.width + amountSpacing + amountStar.size.width + amountSpacing * 2.0 + refundBackground.size.width / 2.0, y: originY + refundBackground.size.height / 2.0))
                )
                context.add(refundText
                    .position(CGPoint(x: amountOriginX + amount.size.width + amountSpacing + amountStar.size.width + amountSpacing * 2.0 + refundBackground.size.width / 2.0, y: originY + refundBackground.size.height / 2.0))
                )
            }
            
            context.add(amount
                .position(CGPoint(x: amountOriginX + amount.size.width / 2.0, y: originY + amount.size.height / 2.0))
            )
            context.add(amountStar
                .position(CGPoint(x: amountOriginX + amount.size.width + amountSpacing + amountStar.size.width / 2.0, y: originY + amountStar.size.height / 2.0))
            )
            
            originY += amount.size.height + 20.0
                        
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

private final class StarsTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: StarsTransactionScreen.Subject
    let action: () -> Void
    let openPeer: (EnginePeer) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let openMedia: ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void
    let copyTransactionId: (String) -> Void
    
    init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        action: @escaping () -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        openMedia: @escaping ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void,
        copyTransactionId: @escaping (String) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.action = action
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.openMedia = openMedia
        self.copyTransactionId = copyTransactionId
    }
    
    static func ==(lhs: StarsTransactionSheetComponent, rhs: StarsTransactionSheetComponent) -> Bool {
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
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(StarsTransactionSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        action: context.component.action,
                        cancel: { animate in
                            if animate {
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { [weak controller] _ in
                                        controller?.dismiss(completion: nil)
                                    })
                                }
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        },
                        openPeer: context.component.openPeer,
                        openMessage: context.component.openMessage,
                        openMedia: context.component.openMedia,
                        copyTransactionId: context.component.copyTransactionId
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? StarsTransactionScreen {
                            controller.dismissAllTooltips()
                        }
                    }
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
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class StarsTransactionScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case transaction(StarsContext.State.Transaction, EnginePeer)
        case receipt(BotPaymentReceipt)
    }
    
    private let context: AccountContext
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        forceDark: Bool = false,
        action: @escaping () -> Void
    ) {
        self.context = context
        
        var openPeerImpl: ((EnginePeer) -> Void)?
        var openMessageImpl: ((EngineMessage.Id) -> Void)?
        var openMediaImpl: (([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void)?
        var copyTransactionIdImpl: ((String) -> Void)?
        super.init(
            context: context,
            component: StarsTransactionSheetComponent(
                context: context,
                subject: subject,
                action: action,
                openPeer: { peerId in
                    openPeerImpl?(peerId)
                },
                openMessage: { messageId in
                    openMessageImpl?(messageId)
                },
                openMedia: { media, transitionNode, addToTransitionSurface in
                    openMediaImpl?(media, transitionNode, addToTransitionSurface)
                },
                copyTransactionId: { transactionId in
                    copyTransactionIdImpl?(transactionId)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
        
        openPeerImpl = { [weak self] peer in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            self.dismissAllTooltips()
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer else {
                    return
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
            })
        }
        
        openMessageImpl = { [weak self] messageId in
            guard let self else {
                return
            }
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer = peer else {
                    return
                }
                if let navigationController = self.navigationController as? NavigationController {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
                }
            })
        }
        
        openMediaImpl = { [weak self] media, transitionNode, addToTransitionSurface in
            guard let self else {
                return
            }
        
            let message = Message(
                stableId: 0,
                stableVersion: 0,
                id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: 0,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: 0,
                flags: [],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: nil,
                text: "",
                attributes: [],
                media: [TelegramMediaPaidContent(amount: 0, extendedMedia: media.map { .full(media: $0) })],
                peers: SimpleDictionary(),
                associatedMessages: SimpleDictionary(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
            let gallery = GalleryController(context: self.context, source: .standaloneMessage(message, 0), replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                if let transitionNode = transitionNode(media) {
                    return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: addToTransitionSurface)
                }
                return nil
            }))
        }
        
        copyTransactionIdImpl = { [weak self] transactionId in
            guard let self else {
                return
            }
            UIPasteboard.general.string = transactionId
            
            self.dismissAllTooltips()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Stars_Transaction_CopiedId), elevatedLayout: false, position: .bottom, action: { _ in return true }), in: .current)
            
            HapticFeedback().tap()
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
        self.dismissAllTooltips()

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

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(id: IdType, title: String, component: AnyComponent<Empty>, insets: UIEdgeInsets? = nil) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
            self.insets = insets
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
            if lhs.insets != rhs.insets {
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
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
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
                
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: rightColumnWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
                
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
            for (titleChild, (valueChild, valueInsets)) in zip(updatedTitleChildren, updatedValueChildren) {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                let valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                
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

private final class TransactionCellComponent: Component {
    let textColor: UIColor
    let accentColor: UIColor
    let transactionId: String
    
    init(textColor: UIColor, accentColor: UIColor, transactionId: String) {
        self.textColor = textColor
        self.accentColor = accentColor
        self.transactionId = transactionId
    }

    static func ==(lhs: TransactionCellComponent, rhs: TransactionCellComponent) -> Bool {
        if lhs.textColor !== rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.transactionId != rhs.transactionId {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var component: TransactionCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TransactionCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let spacing: CGFloat = 6.0
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: component.accentColor)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: availableSize.height)
            )
            
            func brokenLine(_ string: String) -> String {
                if string.count > 30 {
                    return string
                }
                let middleIndex = string.index(string.startIndex, offsetBy: string.count / 2)
                var newString = string
                newString.insert("\n", at: middleIndex)
                return newString
            }
            
            let text: String
            if availableSize.width > 230.0 {
                text = component.transactionId
            } else {
                text = brokenLine(component.transactionId)
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: text,
                            font: Font.monospace(15.0),
                            textColor: component.textColor,
                            paragraphAlignment: .left
                        )),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: availableSize.width, height: textSize.height)
            
            let buttonFrame = CGRect(origin: CGPoint(x: availableSize.width - buttonSize.width - 2.0, y: floorToScreenPixels((size.height - buttonSize.height) / 2.0)), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            
            let textFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - textSize.height) / 2.0) + 1.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
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

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
