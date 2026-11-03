import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import AppBundle
import AlertComponent
import AvatarComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import PhoneNumberFormat
import UndoUI
import WalletContext

private final class GiftMovePathAlertComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment

    let text: NSAttributedString
    let topInset: CGFloat

    init(text: NSAttributedString, topInset: CGFloat) {
        self.text = text
        self.topInset = topInset
    }

    static func ==(lhs: GiftMovePathAlertComponent, rhs: GiftMovePathAlertComponent) -> Bool {
        return lhs.text.isEqual(to: rhs.text) && lhs.topInset == rhs.topInset
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()

        func update(component: GiftMovePathAlertComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: nil,
                    animationCache: nil,
                    animationRenderer: nil,
                    placeholderColor: nil,
                    text: .plain(component.text),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0), y: component.topInset), size: textSize))
            }
            return CGSize(width: availableSize.width, height: textSize.height + component.topInset)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class GiftMoveAddressAlertComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment

    let address: String

    init(address: String) {
        self.address = address
    }

    static func ==(lhs: GiftMoveAddressAlertComponent, rhs: GiftMoveAddressAlertComponent) -> Bool {
        return lhs.address == rhs.address
    }

    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let text = ComponentView<Empty>()

        func update(component: GiftMoveAddressAlertComponent, availableSize: CGSize, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            let theme = environment[AlertComponentEnvironment.self].theme
            let addressInset: CGFloat = -14.0
            let contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 13.0, right: 16.0)
            let topSpacing: CGFloat = 2.0
            let bottomSpacing: CGFloat = 6.0

            let addressText = NSMutableAttributedString()
            let addressFont = Font.monospace(18.0)
            var index = component.address.startIndex
            var groupIndex = 0
            while index < component.address.endIndex {
                let row = groupIndex / 4
                let column = groupIndex % 4
                let color = (row + column).isMultiple(of: 2) ? theme.actionSheet.primaryTextColor : theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.32)
                if groupIndex != 0 {
                    addressText.append(NSAttributedString(string: column == 0 ? "\n" : " ", font: addressFont, textColor: color))
                }
                let endIndex = component.address.index(index, offsetBy: 4, limitedBy: component.address.endIndex) ?? component.address.endIndex
                addressText.append(NSAttributedString(string: String(component.address[index ..< endIndex]), font: addressFont, textColor: color))
                index = endIndex
                groupIndex += 1
            }

            let width = availableSize.width - addressInset * 2.0
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(addressText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: width - contentInsets.left - contentInsets.right, height: .greatestFiniteMagnitude)
            )
            let backgroundFrame = CGRect(x: addressInset, y: topSpacing, width: width, height: contentInsets.top + textSize.height + contentInsets.bottom)
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1),
                    cornerRadius: 14.0
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.isAccessibilityElement = true
                textView.accessibilityLabel = component.address
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0), y: backgroundFrame.minY + contentInsets.top), size: textSize))
            }
            return CGSize(width: availableSize.width, height: backgroundFrame.maxY + bottomSpacing)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class GiftMovePeerAlertComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment

    let context: AccountContext
    let peer: EnginePeer
    let subtitle: String?

    init(context: AccountContext, peer: EnginePeer, subtitle: String?) {
        self.context = context
        self.peer = peer
        self.subtitle = subtitle
    }

    static func ==(lhs: GiftMovePeerAlertComponent, rhs: GiftMovePeerAlertComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.subtitle == rhs.subtitle
    }

    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()

        func update(component: GiftMovePeerAlertComponent, availableSize: CGSize, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            let theme = environment[AlertComponentEnvironment.self].theme
            let strings = environment[AlertComponentEnvironment.self].strings
            let backgroundInset: CGFloat = -14.0
            let topSpacing: CGFloat = 2.0
            let bottomSpacing: CGFloat = 6.0
            let contentInset: CGFloat = 12.0
            let avatarSize = CGSize(width: 40.0, height: 40.0)
            let textSpacing: CGFloat = 12.0

            let width = availableSize.width - backgroundInset * 2.0
            let textLeft = backgroundInset + contentInset + avatarSize.width + textSpacing
            let textWidth = max(1.0, backgroundInset + width - contentInset - textLeft)

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.displayTitle(strings: strings, displayOrder: .firstLast), font: Font.semibold(17.0), textColor: theme.actionSheet.primaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )
            var subtitleSize: CGSize = .zero
            if let subtitle = component.subtitle {
                subtitleSize = self.subtitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor)),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: textWidth, height: 100.0)
                )
            }
            let textHeight = titleSize.height + (subtitleSize.height > 0.0 ? 1.0 + subtitleSize.height : 0.0)
            let backgroundFrame = CGRect(x: backgroundInset, y: topSpacing, width: width, height: max(avatarSize.height, textHeight) + contentInset * 2.0)

            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1),
                    cornerRadius: 14.0
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }

            let _ = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: theme,
                    peer: component.peer
                )),
                environment: {},
                containerSize: avatarSize
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + contentInset, y: backgroundFrame.minY + floorToScreenPixels((backgroundFrame.height - avatarSize.height) / 2.0)), size: avatarSize))
            }

            let textY = backgroundFrame.minY + floorToScreenPixels((backgroundFrame.height - textHeight) / 2.0)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textLeft, y: textY), size: titleSize))
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                subtitleView.isHidden = component.subtitle == nil
                transition.setFrame(view: subtitleView, frame: CGRect(origin: CGPoint(x: textLeft, y: textY + titleSize.height + 1.0), size: subtitleSize))
            }

            return CGSize(width: availableSize.width, height: backgroundFrame.maxY + bottomSpacing)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private func giftMovePathIcon(_ name: String, color: UIColor?, side: CGFloat) -> UIImage? {
    guard let image = color.flatMap({ generateTintedImage(image: UIImage(bundleImageName: name), color: $0) }) ?? UIImage(bundleImageName: name) else {
        return nil
    }
    let scale = min(side / max(1.0, image.size.width), side / max(1.0, image.size.height))
    return generateScaledImage(image: image, size: CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale)), opaque: false)
}

private func giftMovePathString(items: [(String, String, Bool)], theme: PresentationTheme) -> NSAttributedString {
    let accentColor = theme.actionSheet.controlAccentColor
    let font = Font.regular(13.0)
    let textColor = theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.5)
    let result = NSMutableAttributedString()
    result.append(NSAttributedString(string: " "))
    for (i, item) in items.enumerated() {
        if i != 0 {
            if let chevron = giftMovePathIcon("Item List/InlineTextRightArrow", color: textColor, side: 10.0) {
                result.append(NSAttributedString(string: "\u{00A0}", font: font, textColor: textColor))
                result.append(NSAttributedString(string: ">", attributes: [.attachment: chevron, .font: font, .foregroundColor: textColor]))
                result.append(NSAttributedString(string: "\u{00A0} ", font: font, textColor: textColor))
            } else {
                result.append(NSAttributedString(string: "\u{00A0}> ", font: font, textColor: textColor))
            }
        }
        if let icon = giftMovePathIcon(item.0, color: item.2 ? textColor : accentColor, side: 16.0) {
            result.append(NSAttributedString(string: "#", attributes: [.attachment: icon, .font: font, .foregroundColor: item.2 ? textColor : accentColor, .baselineOffset: 1.0]))
            result.append(NSAttributedString(string: "\u{00A0}\u{00A0}", font: font, textColor: textColor))
        }
        result.append(NSAttributedString(string: item.1.replacingOccurrences(of: " ", with: "\u{00A0}"), font: font, textColor: textColor))
    }
    return result
}

public func giftMoveToWalletAlertController(
    context: AccountContext,
    address: String,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Gift_MoveToWallet_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_MoveToWallet_Text))
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "address",
        component: AnyComponent(
            GiftMoveAddressAlertComponent(address: address)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "location",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_MoveToWallet_Location), alignment: .center)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "path",
        component: AnyComponent(
            GiftMovePathAlertComponent(text: giftMovePathString(items: [
                ("Wallet/PathSettings", strings.Settings_Title, true),
                ("Wallet/PathGram", strings.Settings_Money, false),
                ("Wallet/PathGift", strings.Wallet_Collectibles, true)
            ], theme: presentationData.theme), topInset: -6.0)
        )
    ))

    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Gift_MoveToWallet_Move, type: .default, action: {
                commit()
            })
        ]
    )
}

public func giftDepositNetworkFee(context: AccountContext, gift: StarGift.UniqueGift) -> Signal<Int64?, NoError> {
    guard let walletContext = context.walletContext,
          let address = walletContext.stateValue.collectibles.items.first(where: { $0.giftSlug == gift.slug })?.address else {
        return .single(nil)
    }
    return walletContext.estimateTransferFee(address: address, comment: .none)
    |> map { estimate -> Int64? in
        return estimate.fee
    }
    |> `catch` { _ -> Signal<Int64?, NoError> in
        return .single(nil)
    }
}

public func giftMoveToProfileAlertController(
    context: AccountContext,
    peer: EnginePeer,
    networkFee: Signal<Int64?, NoError> = .single(nil),
    commit: @escaping () -> Void
) -> ViewController {
    return giftMoveToProfileAlertController(context: context, peer: peer, networkFee: networkFee, commitWithProgress: { done in
        commit()
        done()
    })
}

public func giftMoveToProfileAlertController(
    context: AccountContext,
    peer: EnginePeer,
    networkFee: Signal<Int64?, NoError> = .single(nil),
    commitWithProgress: @escaping (@escaping () -> Void) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    var subtitle: String?
    if case let .user(user) = peer, let phone = user.phone, !phone.isEmpty {
        subtitle = formatPhoneNumber(context: context, number: phone)
    }

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Gift_MoveToGifts_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_MoveToGifts_Text))
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "peer",
        component: AnyComponent(
            GiftMovePeerAlertComponent(context: context, peer: peer, subtitle: subtitle)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "location",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_MoveToWallet_Location), alignment: .center)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "path",
        component: AnyComponent(
            GiftMovePathAlertComponent(text: giftMovePathString(items: [
                ("Wallet/PathUser", strings.Settings_MyProfile, true),
                ("Wallet/PathGift", strings.PeerInfo_PaneGifts, true)
            ], theme: presentationData.theme), topInset: -6.0)
        )
    ))

    let baseContent = content
    let contentSignal: Signal<[AnyComponentWithIdentity<AlertComponentEnvironment>], NoError> = .single(baseContent)
    |> then(networkFee
    |> take(1)
    |> map { fee -> [AnyComponentWithIdentity<AlertComponentEnvironment>] in
        guard let fee else {
            return baseContent
        }
        let feeText = formatTonAmountText(fee, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: 5, formatString: strings.Currency_Grams)
        return baseContent + [AnyComponentWithIdentity(
            id: "fee",
            component: AnyComponent(
                AlertTextComponent(content: .plain(strings.Wallet_Send_NetworkFee + " " + feeText), alignment: .center, color: .secondary, style: .plain(.small), insets: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 0.0, right: 0.0))
            )
        )]
    })

    let progressPromise = ValuePromise<Bool>(false)
    var isInProgress = false
    var dismissImpl: (() -> Void)?
    let actions: [AlertScreen.Action] = [
        .init(title: strings.Common_Cancel),
        .init(title: strings.Gift_MoveToWallet_Move, type: .default, action: {
            guard !isInProgress else {
                return
            }
            isInProgress = true
            progressPromise.set(true)
            commitWithProgress({
                dismissImpl?()
            })
        }, autoDismiss: false, progress: progressPromise.get())
    ]
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(),
        contentSignal: contentSignal,
        actionsSignal: .single(actions),
        updatedPresentationData: (presentationData, context.sharedContext.presentationData)
    )
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    return alertController
}

public func requestGiftMoveToWallet(
    context: AccountContext,
    reference: StarGiftReference,
    withdraw: ((StarGiftReference, String?) -> Signal<Never, WithdrawStarGiftError>)? = nil,
    present: @escaping (ViewController) -> Void,
    completion: @escaping () -> Void
) {
    let request: (String?) -> Signal<Void, RequestStarGiftWithdrawalError> = { password in
        let signal = withdraw?(reference, password) ?? context.engine.payments.withdrawStarGift(reference: reference, keepOnProfile: false, password: password)
        return signal
        |> mapError { error -> RequestStarGiftWithdrawalError in
            switch error {
            case .generic:
                return .generic
            case .twoStepAuthMissing:
                return .twoStepAuthMissing
            case let .twoStepAuthTooFresh(value):
                return .twoStepAuthTooFresh(value)
            case let .authSessionTooFresh(value):
                return .authSessionTooFresh(value)
            case .limitExceeded:
                return .limitExceeded
            case .requestPassword:
                return .requestPassword
            case .invalidPassword:
                return .invalidPassword
            case let .serverProvided(text):
                return .serverProvided(text: text)
            }
        }
        |> map { _ -> Void in }
        |> then(.single(Void()))
    }
    performGiftWithdrawalRequest(context: context, reference: reference, request: request, present: { c, _ in
        present(c)
    }, completion: { _ in
        completion()
    })
}

public func depositStarGiftFromWallet(context: AccountContext, gift: StarGift.UniqueGift, peerId: EnginePeer.Id, submitted: (() -> Void)? = nil) -> Signal<Never, TransferStarGiftError> {
    nonisolated(unsafe) let submitted = submitted
    guard let walletContext = context.walletContext else {
        return .fail(.generic)
    }
    return context.engine.payments.depositStarGift(peerId: peerId, slug: gift.slug, hideSender: false)
    |> mapError { _ -> TransferStarGiftError in
        return .generic
    }
    |> mapToSignal { payload -> Signal<Never, TransferStarGiftError> in
        let collectible = walletContext.stateValue.collectibles.items.first(where: { $0.giftSlug == gift.slug }) ?? WalletContext.Collectible(
            address: payload.nftAddress,
            name: "\(gift.title) #\(gift.number)",
            kind: .gift,
            giftSlug: gift.slug
        )
        return walletContext.prepareCollectibleDeposit(collectible: collectible, address: payload.nftAddress, payload: payload.payload, amount: payload.amount)
        |> mapToSignal { prepared in
            return walletContext.submitTransfer(prepared, stageUpdated: { stage in
                if stage == .submitted {
                    submitted?()
                }
            })
        }
        |> mapError { _ -> TransferStarGiftError in
            return .generic
        }
        |> ignoreValues
    }
}

public func presentGiftMovedToast(context: AccountContext, navigationController: NavigationController, gift: StarGift.UniqueGift, toWallet: Bool) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var animationFile: TelegramMediaFile?
    for attribute in gift.attributes {
        if case let .model(_, file, _, _) = attribute {
            animationFile = file
            break
        }
    }
    guard let lastController = navigationController.viewControllers.last as? ViewController, let animationFile else {
        return
    }
    let resultController = UndoOverlayController(
        presentationData: presentationData,
        content: .sticker(
            context: context,
            file: animationFile,
            loop: false,
            title: nil,
            text: toWallet ? presentationData.strings.Gift_MoveToWallet_Success : presentationData.strings.Gift_MoveToGifts_Success,
            undoText: presentationData.strings.Gift_Displayed_View,
            customAction: nil
        ),
        elevatedLayout: false,
        action: { [weak navigationController] action in
            guard case .undo = action, let navigationController else {
                return true
            }
            if toWallet {
                navigationController.pushViewController(context.sharedContext.makeWalletScreen(context: context, opensCollectibles: true), animated: true)
            } else {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                    guard let peer, let navigationController else {
                        return
                    }
                    if let controller = context.sharedContext.makePeerInfoController(
                        context: context,
                        updatedPresentationData: nil,
                        peer: peer,
                        mode: .myProfileGifts,
                        avatarInitiallyExpanded: false,
                        fromChat: false,
                        requestsContext: nil
                    ) {
                        navigationController.pushViewController(controller, animated: true)
                    }
                })
            }
            return true
        }
    )
    lastController.present(resultController, in: .current)
}
