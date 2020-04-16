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

private func rollingAnimationItem(emoji: String) -> ManagedAnimationItem? {
    switch emoji {
        case "🎲":
            return ManagedAnimationItem(source: .local("Dice_Rolling"), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 60), duration: 1.0, loop: true)
        case "🎯":
            return ManagedAnimationItem(source: .local("Darts_Aiming"), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 90), duration: 1.5, loop: true)
        default:
            return nil
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
        
        let frameCount: Int
        let duration: Double
        
        switch dice.emoji {
            case "🎲":
                frameCount = 180
                duration = 3.0
            case "🎯":
                frameCount = 100
                duration = 1.6
            default:
                frameCount = 180
                duration = 1.6
        }
        
        let context = self.context
        if let previousState = previousState {
            switch previousState {
                case .rolling:
                    switch diceState {
                        case let .value(value, _):
                            let animationItem: Signal<ManagedAnimationItem, NoError> = self.emojis.get()
                            |> mapToSignal { emojis -> Signal<ManagedAnimationItem, NoError> in
                                guard emojis.count > value else {
                                    return .complete()
                                }
                                let file = emojis[Int(value) - 1]
                                let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                                let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))

                                let fetched = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file))
                                let animationItem = Signal<ManagedAnimationItem, NoError> { subscriber in
                                    let fetchedDisposable = fetched.start()
                                    let resourceDisposable = (chatMessageAnimationData(postbox: context.account.postbox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                                    |> filter { data in
                                        return data.complete
                                    }).start(next: { next in
                                        subscriber.putNext(ManagedAnimationItem(source: .resource(context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: frameCount), duration: duration))
                                    })

                                    return ActionDisposable {
                                        fetchedDisposable.dispose()
                                        resourceDisposable.dispose()
                                    }
                                }
                                return animationItem
                            }
                            
                            self.disposable.set((animationItem |> deliverOnMainQueue).start(next: { [weak self] item in
                                if let strongSelf = self {
                                    strongSelf.trackTo(item: item)
                                }
                            }))
                        case .rolling:
                            break
                    }
                case .value:
                    switch diceState {
                        case .rolling:
                            if let item = rollingAnimationItem(emoji: self.dice.emoji) {
                                self.trackTo(item: item)
                            }
                        case .value:
                            break
                    }
            }
        } else {
            switch diceState {
                case let .value(value, immediate):
                    let animationItem: Signal<ManagedAnimationItem, NoError> = self.emojis.get()
                    |> mapToSignal { emojis -> Signal<ManagedAnimationItem, NoError> in
                        guard emojis.count > value else {
                            return .complete()
                        }
                        let file = emojis[Int(value) - 1]
                        
                        if let _ = context.account.postbox.mediaBox.completedResourcePath(file.resource) {
                            if immediate {
                                return .single(ManagedAnimationItem(source: .resource(context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: frameCount, endFrame: frameCount), duration: 0.0))
                            } else {
                                return .single(ManagedAnimationItem(source: .resource(context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: frameCount), duration: duration))
                            }
                        } else {
                            self.setState(.rolling)
                            
                            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                            let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))
                            
                            let fetched = freeMediaFileInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file))
                            let animationItem = Signal<ManagedAnimationItem, NoError> { subscriber in
                                let fetchedDisposable = fetched.start()
                                let resourceDisposable = (chatMessageAnimationData(postbox: self.context.account.postbox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                                    |> filter { data in
                                        return data.complete
                                    }).start(next: { next in
                                        subscriber.putNext(ManagedAnimationItem(source: .resource(context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: frameCount), duration: duration))
                                    })
                                
                                return ActionDisposable {
                                    fetchedDisposable.dispose()
                                    resourceDisposable.dispose()
                                }
                            }
                            return animationItem
                        }
                    }
                    
                    self.disposable.set((animationItem |> deliverOnMainQueue).start(next: { [weak self] item in
                        if let strongSelf = self {
                            strongSelf.trackTo(item: item)
                        }
                    }))
                case .rolling:
                    if let item = rollingAnimationItem(emoji: self.dice.emoji) {
                        self.trackTo(item: item)
                    }
            }
        }
    }
}
