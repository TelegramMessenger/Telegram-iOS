import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import AvatarNode
import CheckNode
import Markdown
import TextFormat
import StarsBalanceOverlayComponent
import AlertComponent
import AlertCheckComponent

public class ChatMessagePaymentAlertController: AlertScreen {
    private let context: AccountContext?
    private let presentationData: PresentationData
    private weak var parentNavigationController: NavigationController?
    private let chatPeerId: EnginePeer.Id
    private let showBalance: Bool
    private let animateBalanceOverlay: Bool
    
    private var didUpdateCurrency = false
    
    private var initialCurrency: CurrencyAmount.Currency?
    public var currency: CurrencyAmount.Currency?
    private var currencyDisposable: Disposable?
    
    private let balance = ComponentView<Empty>()
    
    private var didAppear = false
        
    public init(
        context: AccountContext?,
        presentationData: PresentationData,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        configuration: Configuration = AlertScreen.Configuration(),
        contentSignal: Signal<[AnyComponentWithIdentity<AlertComponentEnvironment>], NoError>,
        actionsSignal: Signal<[AlertScreen.Action], NoError>,
        navigationController: NavigationController?,
        chatPeerId: EnginePeer.Id,
        showBalance: Bool = true,
        currencySignal: Signal<CurrencyAmount.Currency, NoError> = .single(.stars),
        animateBalanceOverlay: Bool = true
    ) {
        self.context = context
        self.presentationData = presentationData
        self.parentNavigationController = navigationController
        self.chatPeerId = chatPeerId
        self.showBalance = showBalance
        self.animateBalanceOverlay = animateBalanceOverlay
        
        var effectiveUpdatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
        if let updatedPresentationData {
            effectiveUpdatedPresentationData = updatedPresentationData
        } else {
            effectiveUpdatedPresentationData = (initial: presentationData, signal: .single(presentationData))
        }
            
        super.init(
            configuration: configuration,
            contentSignal: contentSignal,
            actionsSignal: actionsSignal,
            updatedPresentationData: effectiveUpdatedPresentationData
        )
        
        self.currencyDisposable = (currencySignal
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] currency in
            guard let self else {
                return
            }
            if self.currency == nil {
                self.initialCurrency = currency
            }
            self.currency = currency
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.25, curve: .easeInOut))
            }
        })
    }
    
    public convenience init(
        context: AccountContext?,
        presentationData: PresentationData,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        configuration: Configuration = AlertScreen.Configuration(),
        content: [AnyComponentWithIdentity<AlertComponentEnvironment>],
        actions: [AlertScreen.Action],
        navigationController: NavigationController?,
        chatPeerId: EnginePeer.Id,
        showBalance: Bool = true,
        currency: CurrencyAmount.Currency = .stars,
        animateBalanceOverlay: Bool = true
    ) {
        self.init(
            context: context,
            presentationData: presentationData,
            updatedPresentationData: updatedPresentationData,
            configuration: configuration,
            contentSignal: .single(content),
            actionsSignal: .single(actions),
            navigationController: navigationController,
            chatPeerId: chatPeerId,
            showBalance: showBalance,
            currencySignal: .single(currency),
            animateBalanceOverlay: animateBalanceOverlay
        )
    }
        
    required public init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
        
        self.animateOut()
    }
    
    private func animateOut() {
        if !self.animateBalanceOverlay {
            if case .ton = self.currency, let initialCurrency, initialCurrency != self.currency {
                self.currency = .stars
                if let layout = self.validLayout {
                    self.containerLayoutUpdated(layout, transition: .animated(duration: 0.25, curve: .easeInOut))
                }
            }
        } else {
            if let view = self.balance.view {
                view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false)
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
        }
    }
        
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
                
        if !self.didAppear {
            self.didAppear = true
            if !layout.metrics.isTablet && layout.size.width > layout.size.height {
                Queue.mainQueue().after(0.1) {
                    self.view.window?.endEditing(true)
                }
            }
        }
        
        if let context = self.context, let _ = self.parentNavigationController, self.showBalance, let currency = self.currency {
            let insets = layout.insets(options: .statusBar)
            var balanceTransition = ComponentTransition(transition)
            if self.balance.view == nil {
                balanceTransition = .immediate
            }
            
            let balanceSize = self.balance.update(
                transition: balanceTransition,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: context,
                        peerId: self.chatPeerId.namespace == Namespaces.Peer.CloudChannel ? self.chatPeerId : context.account.peerId,
                        theme: self.presentationData.theme,
                        currency: currency,
                        action: { [weak self] in
                            guard let self, let starsContext = context.starsContext, let navigationController = self.parentNavigationController, let currency = self.currency else {
                                return
                            }
                            switch currency {
                            case .stars:
                                let _ = (context.engine.payments.starsTopUpOptions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { options in
                                    let controller = context.sharedContext.makeStarsPurchaseScreen(
                                        context: context,
                                        starsContext: starsContext,
                                        options: options,
                                        purpose: .generic,
                                        targetPeerId: nil,
                                        customTheme: nil,
                                        completion: { _ in }
                                    )
                                    navigationController.pushViewController(controller)
                                })
                            case .ton:
                                var fragmentUrl = "https://fragment.com/ads/topup"
                                if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                                    fragmentUrl = value
                                }
                                context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                            }
                            self.dismiss(completion: nil)
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            if let view = self.balance.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                    
                    if self.animateBalanceOverlay {
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        view.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
                balanceTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - balanceSize.width) / 2.0), y: insets.top + 5.0), size: balanceSize))
            }
        }
    }
}

public func chatMessagePaymentAlertController(
    context: AccountContext?,
    presentationData: PresentationData,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    peers: [EngineRenderedPeer],
    count: Int32,
    amount: StarsAmount,
    totalAmount: StarsAmount?,
    hasCheck: Bool = true,
    navigationController: NavigationController?,
    completion: @escaping (Bool) -> Void
) -> ViewController {
    let strings = presentationData.strings
    
    let messagesString = strings.Chat_PaidMessage_Confirm_Text_Messages(count)
    let text: String
    if peers.count == 1, let peer = peers.first {
        let amountString = strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(clamping: amount.value))
        let totalString = strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(clamping: amount.value * Int64(count)))
        if case let .channel(channel) = peer.chatOrMonoforumMainPeer, case .broadcast = channel.info {
            text = strings.Chat_PaidMessage_Confirm_SingleComment_Text(EnginePeer(channel).compactDisplayTitle, amountString, totalString, messagesString).string
        } else {
            text = strings.Chat_PaidMessage_Confirm_Single_Text(peer.chatOrMonoforumMainPeer?.compactDisplayTitle ?? " ", amountString, totalString, messagesString).string
        }
    } else {
        let amount = totalAmount ?? amount
        let usersString = strings.Chat_PaidMessage_Confirm_Text_Users(Int32(peers.count))
        let totalString = strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(clamping: amount.value * Int64(count)))
        text = strings.Chat_PaidMessage_Confirm_Multiple_Text(usersString, totalString, messagesString).string
    }
        
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Chat_PaidMessage_Confirm_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    if hasCheck {
        content.append(AnyComponentWithIdentity(
            id: "check",
            component: AnyComponent(
                AlertCheckComponent(title: strings.Chat_PaidMessage_Confirm_DontAskAgain, initialValue: false, externalState: checkState)
            )
        ))
    }
    
    let alertController = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        updatedPresentationData: updatedPresentationData,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical, allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Chat_PaidMessage_Confirm_PayForMessage(count), type: .default, action: {
                completion(checkState.value)
            }),
            .init(title: strings.Common_Cancel)
        ],
        navigationController: navigationController,
        chatPeerId: context?.account.peerId ?? peers[0].peerId
    )
    return alertController
}

public func chatMessageRemovePaymentAlertController(
    context: AccountContext? = nil,
    presentationData: PresentationData,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    peer: EnginePeer,
    chatPeer: EnginePeer,
    amount: StarsAmount?,
    navigationController: NavigationController?,
    completion: @escaping (Bool) -> Void
) -> ViewController {
    let strings = presentationData.strings
    
    let text: String
    if case .user = chatPeer {
        text = strings.Chat_PaidMessage_RemoveFee_Text(peer.compactDisplayTitle).string
    } else if let context, chatPeer.id != context.account.peerId {
        text = strings.Channel_RemoveFeeAlert_Text(peer.compactDisplayTitle).string
    } else {
        text = strings.Chat_PaidMessage_RemoveFee_Text(peer.compactDisplayTitle).string
    }
        
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Chat_PaidMessage_RemoveFee_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    if let amount {
        content.append(AnyComponentWithIdentity(
            id: "check",
            component: AnyComponent(
                AlertCheckComponent(title: strings.Chat_PaidMessage_RemoveFee_Refund(strings.Chat_PaidMessage_RemoveFee_Refund_Stars(Int32(clamping: amount.value))).string, initialValue: false, externalState: checkState)
            )
        ))
    }
    
    let alertController = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        updatedPresentationData: updatedPresentationData,
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Chat_PaidMessage_RemoveFee_Yes, type: .default, action: {
                completion(checkState.value)
            })
        ],
        navigationController: navigationController,
        chatPeerId: chatPeer.id
    )
    return alertController
}
