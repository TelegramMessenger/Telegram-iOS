import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PresentationDataUtils
import TelegramStringFormatting
import BalanceNeededScreen
import GiftSetupScreen

public func buyStarGiftImpl(
    context: AccountContext,
    recipientPeerId: EnginePeer.Id,
    uniqueGift: StarGift.UniqueGift,
    showAttributes: Bool,
    acceptedPrice: CurrencyAmount? = nil,
    skipConfirmation: Bool = false,
    message: GiftMessageScreen.Result? = nil,
    starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>,
    buyGift: ((String, EnginePeer.Id, CurrencyAmount?, Bool, String?, [MessageTextEntity]?) -> Signal<Never, BuyStarGiftError>)?,
    getController: @escaping () -> ViewController?,
    updateProgress: @escaping (Bool) -> Void,
    updateIsBalanceVisible: @escaping (Bool) -> Void,
    completion: @escaping () -> Void
) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
    let action: (CurrencyAmount.Currency, GiftMessageScreen.Result, @escaping () -> Void) -> Void = { currency, message, beforeCompletion in
        guard let resellAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == currency }) else {
            guard let controller = getController() else {
                return
            }
            let alertController = textAlertController(
                context: context,
                title: nil,
                text: presentationData.strings.Gift_Buy_ErrorUnknown,
                actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})],
                parseMarkdown: true
            )
            controller.present(alertController, in: .window(.root))
            
            beforeCompletion()
            return
        }
        
        let proceed: () -> Void = {
            updateProgress(true)
            
            let buyGiftImpl: ((String, EnginePeer.Id, CurrencyAmount?, Bool, String?, [MessageTextEntity]?) -> Signal<Never, BuyStarGiftError>)
            if let buyGift {
                buyGiftImpl = { slug, peerId, price, hideName, text, entities in
                    return buyGift(slug, peerId, price, hideName, text, entities)
                }
            } else {
                buyGiftImpl = { slug, peerId, price, hideName, text, entities in
                    return context.engine.payments.buyStarGift(slug: slug, peerId: peerId, price: price, hideName: hideName, text: text, entities: entities)
                }
            }
            
            let finalPrice = acceptedPrice ?? resellAmount
            let _ = (buyGiftImpl(uniqueGift.slug, recipientPeerId, finalPrice, message.hideName, message.text, message.entities)
            |> deliverOnMainQueue).start(error: { error in
                guard let controller = getController() else {
                    return
                }
                beforeCompletion()
                updateProgress(false)
                
                HapticFeedback().error()
                
                switch error {
                case .serverProvided:
                    return
                case let .priceChanged(newPrice):
                    let errorTitle = presentationData.strings.Gift_Buy_ErrorPriceChanged_Title
                    let originalPriceString: String
                    switch resellAmount.currency {
                    case .stars:
                        originalPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(clamping: resellAmount.amount.value))
                    case .ton:
                        originalPriceString = formatTonAmountText(resellAmount.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil, formatString: presentationData.strings.Currency_Grams)
                    }
                    
                    let newPriceString: String
                    let buttonText: String
                    switch newPrice.currency {
                    case .stars:
                        newPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(clamping: newPrice.amount.value))
                        buttonText = presentationData.strings.Gift_Buy_Confirm_BuyFor(Int32(newPrice.amount.value))
                    case .ton:
                        let tonValueString = formatTonAmountText(newPrice.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil)
                        newPriceString = formatTonAmountText(newPrice.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil, formatString: presentationData.strings.Currency_Grams)
                        buttonText = presentationData.strings.Gift_Buy_Confirm_BuyForTon(tonValueString).string
                    }
                    let errorText = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text(originalPriceString, newPriceString).string
                    
                    let alertController = textAlertController(
                        context: context,
                        title: errorTitle,
                        text: errorText,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: buttonText, action: {
                                buyStarGiftImpl(
                                    context: context,
                                    recipientPeerId: recipientPeerId,
                                    uniqueGift: uniqueGift,
                                    showAttributes: showAttributes,
                                    acceptedPrice: newPrice,
                                    skipConfirmation: true,
                                    message: message,
                                    starsTopUpOptions: starsTopUpOptions,
                                    buyGift: buyGift,
                                    getController: getController,
                                    updateProgress: updateProgress,
                                    updateIsBalanceVisible: updateIsBalanceVisible,
                                    completion: completion
                                )
                            }),
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
                        ],
                        actionLayout: .vertical,
                        parseMarkdown: true
                    )
                    controller.present(alertController, in: .window(.root))
                default:
                    let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.Gift_Buy_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                    controller.present(alertController, in: .window(.root))
                }
            },
            completed: {
                beforeCompletion()
                completion()

                Queue.mainQueue().after(2.5) {
                    switch finalPrice.currency {
                    case .stars:
                        context.starsContext?.load(force: true)
                    case .ton:
                        context.tonContext?.load(force: true)
                    }
                }
            })
        }
        
        if resellAmount.currency == .stars, let starsContext = context.starsContext, let starsState = context.starsContext?.currentState, starsState.balance < resellAmount.amount {
            let _ = (starsTopUpOptions
             |> filter { $0 != nil }
             |> take(1)
             |> deliverOnMainQueue).startStandalone(next: { options in
                guard let controller = getController() else {
                    return
                }
                let purchaseController = context.sharedContext.makeStarsPurchaseScreen(
                    context: context,
                    starsContext: starsContext,
                    options: options ?? [],
                    purpose: .buyStarGift(requiredStars: resellAmount.amount.value),
                    targetPeerId: nil,
                    customTheme: nil,
                    completion: { stars in
                        guard let starsContext = context.starsContext else {
                            return
                        }
                        updateProgress(true)
                        
                        starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                        let _ = (starsContext.onUpdate
                        |> deliverOnMainQueue).start(next: {
                            Queue.mainQueue().after(0.1, {
                                guard let starsContext = context.starsContext, let starsState = starsContext.currentState else {
                                    return
                                }
                                if starsState.balance < resellAmount.amount {
                                    updateProgress(false)
                                    
                                    buyStarGiftImpl(
                                        context: context,
                                        recipientPeerId: recipientPeerId,
                                        uniqueGift: uniqueGift,
                                        showAttributes: showAttributes,
                                        acceptedPrice: acceptedPrice,
                                        skipConfirmation: true,
                                        message: message,
                                        starsTopUpOptions: starsTopUpOptions,
                                        buyGift: buyGift,
                                        getController: getController,
                                        updateProgress: updateProgress,
                                        updateIsBalanceVisible: updateIsBalanceVisible,
                                        completion: completion
                                    )
                                } else {
                                    proceed()
                                }
                            });
                        })
                    }
                )
                controller.push(purchaseController)
            })
        } else if resellAmount.currency == .ton, let tonState = context.tonContext?.currentState, tonState.balance < resellAmount.amount {
            guard let controller = getController() else {
                return
            }
            let needed = resellAmount.amount - tonState.balance
            var fragmentUrl = "https://fragment.com/ads/topup"
            if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                fragmentUrl = value
            }
            controller.push(BalanceNeededScreen(
                context: context,
                amount: needed,
                buttonAction: {
                    context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                }
            ))
            
            beforeCompletion()
        } else {
            proceed()
        }
    }
    
    if skipConfirmation {
        action(acceptedPrice?.currency ?? .stars, message ?? GiftMessageScreen.Result(hideName: true, text: nil, entities: nil), {})
    } else {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: recipientPeerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer, let controller = getController() else {
                return
            }
            let presentConfirmation: (GiftMessageScreen.Result, GiftMessageScreen?) -> Void = { message, messageController in
                var dismissImpl: (() -> Void)?
                let alertController = giftPurchaseAlertController(
                    context: context,
                    gift: uniqueGift,
                    showAttributes: showAttributes,
                    peer: peer,
                    animateBalanceOverlay: showAttributes,
                    autoDismissOnCommit: false,
                    navigationController: controller.navigationController as? NavigationController,
                    commit: { currency in
                        dismissImpl?()
                        if let messageController {
                            messageController.dismiss(completion: {
                                action(currency, message, {})
                            })
                        } else {
                            action(currency, message, {})
                        }
                    },
                    dismissed: {
                        updateIsBalanceVisible(true)
                    }
                )
                controller.present(alertController, in: .window(.root))

                dismissImpl = { [weak alertController] in
                    alertController?.dismiss(completion: nil)
                }

                updateIsBalanceVisible(false)
            }

            weak var messageController: GiftMessageScreen?
            let messageScreen = GiftMessageScreen(
                context: context,
                peer: peer,
                gift: uniqueGift,
                dismissOnCompletion: false,
                completion: { message in
                    guard let messageController else {
                        return
                    }
                    presentConfirmation(message, messageController)
                }
            )
            messageController = messageScreen
            controller.push(messageScreen)
        })
    }
}
