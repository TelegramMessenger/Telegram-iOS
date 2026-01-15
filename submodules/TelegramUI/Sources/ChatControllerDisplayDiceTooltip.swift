import Foundation
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import UndoUI
import EmojiGameStakeScreen
import ChatPresentationInterfaceState
import TelegramStringFormatting

extension ChatControllerImpl {
    func presentEmojiGameStake() {
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.EmojiGame())
        |> deliverOnMainQueue).start(next: { [weak self] gameInfo in
            guard let self, case let .available(info) = gameInfo else {
                return
            }
            let controller = EmojiGameStakeScreen(
                context: self.context,
                gameInfo: info,
                completion: { [weak self] stake in
                    guard let self else {
                        return
                    }
                    self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                        guard let self else {
                            return
                        }
                        self.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: "🎲", tonAmount: stake.value > 0 ? stake.value : nil)), threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])], postpone: postpone)
                    })
                }
            )
            self.push(controller)
        })
    }
    
    func displayDiceTooltip(dice: TelegramMediaDice) {
        guard let _ = dice.value else {
            return
        }
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
        
        let emoji = dice.emoji.strippedEmoji
        
        
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.EmojiGame())
        |> deliverOnMainQueue).start(next: { [weak self] gameInfo in
            guard let self else {
                return
            }
            
            let canSendMessages = canSendMessagesToChat(self.presentationInterfaceState)
            let value: String?
            var changeAction: String?
            var tonAmount: Int64?
            if canSendMessages, emoji == "🎲", case let .available(info) = gameInfo {
                let currentStake = info.previousStake
                value = "\(self.presentationData.strings.Conversation_Dice_Stake)  $ \(formatTonAmountText(currentStake, dateTimeFormat: self.presentationData.dateTimeFormat))"
                changeAction = self.presentationData.strings.Conversation_Dice_Change
                tonAmount = info.previousStake
            } else {
                switch emoji {
                    case "🎲":
                        value = self.presentationData.strings.Conversation_Dice_u1F3B2
                    case "🎯":
                        value = self.presentationData.strings.Conversation_Dice_u1F3AF
                    case "🏀":
                        value = self.presentationData.strings.Conversation_Dice_u1F3C0
                    case "⚽":
                        value = self.presentationData.strings.Conversation_Dice_u26BD
                    case "🎰":
                        value = self.presentationData.strings.Conversation_Dice_u1F3B0
                    case "🎳":
                        value = self.presentationData.strings.Conversation_Dice_u1F3B3
                    default:
                        let emojiHex = emoji.unicodeScalars.map({ String(format:"%02x", $0.value) }).joined().uppercased()
                        let key = "Conversation.Dice.u\(emojiHex)"
                        if let string = self.presentationData.strings.primaryComponent.dict[key] {
                            value = string
                        } else if let string = self.presentationData.strings.secondaryComponent?.dict[key] {
                            value = string
                        } else {
                            value = nil
                        }
                }
            }
            if let value = value {
                self.present(UndoOverlayController(presentationData: self.presentationData, content: .dice(dice: dice, context: self.context, text: value, action: canSendMessages ? self.presentationData.strings.Conversation_SendDice : nil, changeAction: changeAction), elevatedLayout: false, action: { [weak self] action in
                    if let self, canSendMessagesToChat(self.presentationInterfaceState) {
                        switch action {
                        case .undo:
                            self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                guard let self else {
                                    return
                                }
                                self.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: dice.emoji, tonAmount: tonAmount)), threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])], postpone: postpone)
                            })
                        case .info:
                            if let _ = changeAction {
                                self.presentEmojiGameStake()
                            }
                        default:
                            break
                        }
                    }
                    return false
                }), in: .current)
            }
        })
    }
}
