import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SyncCore
import TelegramCore
import SwiftSignalKit
import AccountContext
import StickerResources
import ManagedAnimationNode

enum ManagedDiceAnimationState: Equatable {
    case rolling
    case value(Int32, Bool)
}

private func animationItem(account: Account, emojis: Signal<[TelegramMediaFile], NoError>, emoji: String, value: Int32?, immediate: Bool = false, roll: Bool = false, loop: Bool = false) -> Signal<ManagedAnimationItem?, NoError> {
    return emojis
    |> mapToSignal { diceEmojis -> Signal<ManagedAnimationItem?, NoError> in
        if let value = value, value >= diceEmojis.count {
            return .complete()
        }
        let file = diceEmojis[Int(value ?? 0)]
        
        if let _ = account.postbox.mediaBox.completedResourcePath(file.resource) {
            if immediate {
                return .single(ManagedAnimationItem(source: .resource(account.postbox.mediaBox, file.resource), frames: .still(.end), duration: 0))
            } else {
                return .single(ManagedAnimationItem(source: .resource(account.postbox.mediaBox, file.resource), loop: loop))
            }
        } else {
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))

            let fetched = freeMediaFileInteractiveFetched(account: account, fileReference: .standalone(media: file))
            let animationItem = Signal<ManagedAnimationItem?, NoError> { subscriber in
                let fetchedDisposable = fetched.start()
                let resourceDisposable = (chatMessageAnimationData(postbox: account.postbox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                |> filter { data in
                    return data.complete
                }).start(next: { next in
                    subscriber.putNext(ManagedAnimationItem(source: .resource(account.postbox.mediaBox, file.resource), loop: loop))
                })

                return ActionDisposable {
                    fetchedDisposable.dispose()
                    resourceDisposable.dispose()
                }
            }
            
            if roll {
                return rollingAnimationItem(account: account, emojis: emojis, emoji: emoji) |> then(animationItem)
            } else {
                return animationItem
            }
        }
    }
}

private func rollingAnimationItem(account: Account, emojis: Signal<[TelegramMediaFile], NoError>, emoji: String) -> Signal<ManagedAnimationItem?, NoError> {
    switch emoji {
        case "🎲":
            return .single(ManagedAnimationItem(source: .local("Dice_Rolling"), loop: true))
        case "🎯":
            return .single(ManagedAnimationItem(source: .local("Darts_Aiming"), loop: true))
        default:
            return animationItem(account: account, emojis: emojis, emoji: emoji, value: nil, loop: true)
    }
}

final class ManagedDiceAnimationNode: ManagedAnimationNode, GenericAnimatedStickerNode {
    private let context: AccountContext
    private let dice: TelegramMediaDice
    
    private var diceState: ManagedDiceAnimationState? = nil
    private let disposable = MetaDisposable()
    
    private let emojis = Promise<[TelegramMediaFile]>()
    
    init(context: AccountContext, dice: TelegramMediaDice) {
        self.context = context
        self.dice = dice
        
        self.emojis.set(loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: .dice(dice.emoji), forceActualized: false)
        |> mapToSignal { stickerPack -> Signal<[TelegramMediaFile], NoError> in
            switch stickerPack {
                case let .result(_, items, _):
                    var emojiStickers: [TelegramMediaFile] = []
                    for case let item as StickerPackItem in items {
                        emojiStickers.append(item.file)
                    }
                    return .single(emojiStickers)
                default:
                    return .complete()
            }
        })
        
        super.init(size: CGSize(width: 184.0, height: 184.0))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func setState(_ diceState: ManagedDiceAnimationState) {
        let previousState = self.diceState
        self.diceState = diceState
        
        var item: Signal<ManagedAnimationItem?, NoError>? = nil
        
        let context = self.context
        if let previousState = previousState {
            switch previousState {
                case .rolling:
                    switch diceState {
                        case let .value(value, _):
                            item = animationItem(account: context.account, emojis: self.emojis.get(), emoji: self.dice.emoji, value: value)
                        case .rolling:
                            break
                    }
                case .value:
                    switch diceState {
                        case .rolling:
                            item = rollingAnimationItem(account: context.account, emojis: self.emojis.get(), emoji: self.dice.emoji)
                        case .value:
                            break
                    }
            }
        } else {
            switch diceState {
                case let .value(value, immediate):
                    item = animationItem(account: context.account, emojis: self.emojis.get(), emoji: self.dice.emoji, value: value, immediate: immediate, roll: true)
                case .rolling:
                    item = rollingAnimationItem(account: context.account, emojis: self.emojis.get(), emoji: self.dice.emoji)
            }
        }
        
        if let item = item {
            self.disposable.set((item |> deliverOnMainQueue).start(next: { [weak self] item in
                if let strongSelf = self, let item = item {
                    strongSelf.trackTo(item: item)
                }
            }))
        }
    }
}
