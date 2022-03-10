import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import StickerResources
import ManagedAnimationNode

enum ManagedDiceAnimationState: Equatable {
    case rolling
    case value(Int32, Bool)
}

private func animationItem(account: Account, emojis: Signal<[TelegramMediaFile], NoError>, configuration: Signal<InteractiveEmojiConfiguration?, NoError> = .single(nil), emoji: String, value: Int32?, immediate: Bool = false, roll: Bool = false, loop: Bool = false, successCallback: (() -> Void)? = nil) -> Signal<ManagedAnimationItem?, NoError> {
    return combineLatest(emojis, configuration)
    |> mapToSignal { diceEmojis, configuration -> Signal<ManagedAnimationItem?, NoError> in
        if let value = value, value >= diceEmojis.count {
            return .complete()
        }
        let file = diceEmojis[Int(value ?? 0)]
        
        var callbacks: [(Int, () -> Void)] = []
        
        if !loop, let successCallback = successCallback, let value = value, let configuration = configuration, let success = configuration.successParameters[emoji], value == success.value {
            callbacks.append((success.frame, successCallback))
        }
        
        if let _ = account.postbox.mediaBox.completedResourcePath(file.resource) {
            if immediate {
                return .single(ManagedAnimationItem(source: .resource(account, EngineMediaResource(file.resource)), frames: .still(.end), duration: 0))
            } else {
                return .single(ManagedAnimationItem(source: .resource(account, EngineMediaResource(file.resource)), loop: loop, callbacks: callbacks))
            }
        } else {
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))

            let fetched = freeMediaFileInteractiveFetched(account: account, fileReference: .standalone(media: file))
            let animationItem = Signal<ManagedAnimationItem?, NoError> { subscriber in
                let fetchedDisposable = fetched.start()
                let resourceDisposable = (chatMessageAnimationData(mediaBox: account.postbox.mediaBox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                |> filter { data in
                    return data.complete
                }).start(next: { next in
                    subscriber.putNext(ManagedAnimationItem(source: .resource(account, EngineMediaResource(file.resource)), loop: loop, callbacks: callbacks))
                    subscriber.putCompletion()
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
        case "🏀":
            return .single(ManagedAnimationItem(source: .local("Basketball_Bouncing"), loop: true))
        case "⚽":
            return .single(ManagedAnimationItem(source: .local("Football_Bouncing"), loop: true))
        case "🎳":
            return .single(ManagedAnimationItem(source: .local("Bowling_Aiming"), loop: true))
        default:
            return animationItem(account: account, emojis: emojis, emoji: emoji, value: nil, loop: true)
    }
}

private struct InteractiveEmojiSuccessParameters {
    let value: Int
    let frame: Int
}

public struct InteractiveEmojiConfiguration {
    static var defaultValue: InteractiveEmojiConfiguration {
        return InteractiveEmojiConfiguration(emojis: [], successParameters: [:])
    }
    
    public let emojis: [String]
    fileprivate let successParameters: [String: InteractiveEmojiSuccessParameters]
    
    fileprivate init(emojis: [String], successParameters: [String: InteractiveEmojiSuccessParameters]) {
        self.emojis = emojis
        self.successParameters = successParameters
    }
    
    static func with(appConfiguration: AppConfiguration) -> InteractiveEmojiConfiguration {
        if let data = appConfiguration.data, let emojis = data["emojies_send_dice"] as? [String] {
            var successParameters: [String: InteractiveEmojiSuccessParameters] = [:]
            if let success = data["emojies_send_dice_success"] as? [String: [String: Double]] {
                for (key, dict) in success {
                    if let successValue = dict["value"], let successFrame = dict["frame_start"] {
                        successParameters[key] = InteractiveEmojiSuccessParameters(value: Int(successValue), frame: Int(successFrame))
                    }
                }
            }
            return InteractiveEmojiConfiguration(emojis: emojis, successParameters: successParameters)
        } else {
            return .defaultValue
        }
    }
}

final class ManagedDiceAnimationNode: ManagedAnimationNode, GenericAnimatedStickerNode {
    private let context: AccountContext
    private let emoji: String
    
    private var diceState: ManagedDiceAnimationState? = nil
    private let disposable = MetaDisposable()
    
    private let configuration = Promise<InteractiveEmojiConfiguration?>()
    private let emojis = Promise<[TelegramMediaFile]>()
    
    var success: (() -> Void)?
    
    init(context: AccountContext, emoji: String) {
        self.context = context
        self.emoji = emoji
        
        self.configuration.set(self.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { preferencesView -> InteractiveEmojiConfiguration? in
            let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
            return InteractiveEmojiConfiguration.with(appConfiguration: appConfiguration)
        })
        self.emojis.set(context.engine.stickers.loadedStickerPack(reference: .dice(emoji), forceActualized: false)
        |> mapToSignal { stickerPack -> Signal<[TelegramMediaFile], NoError> in
            switch stickerPack {
                case let .result(_, items, _):
                    var emojiStickers: [TelegramMediaFile] = []
                    for item in items {
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
                            item = animationItem(account: context.account, emojis: self.emojis.get(), configuration: self.configuration.get(), emoji: self.emoji, value: value, successCallback: { [weak self] in
                                self?.success?()
                            })
                        case .rolling:
                            break
                    }
                case .value:
                    switch diceState {
                        case .rolling:
                            item = rollingAnimationItem(account: context.account, emojis: self.emojis.get(), emoji: self.emoji)
                        case .value:
                            break
                    }
            }
        } else {
            switch diceState {
                case let .value(value, immediate):
                    item = animationItem(account: context.account, emojis: self.emojis.get(), configuration: self.configuration.get(), emoji: self.emoji, value: value, immediate: immediate, roll: true, successCallback: { [weak self] in
                        self?.success?()
                    })
                case .rolling:
                    item = rollingAnimationItem(account: context.account, emojis: self.emojis.get(), emoji: self.emoji)
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
    
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
    }

    func setFrameIndex(_ frameIndex: Int) {
    }

    var currentFrameIndex: Int {
        return 0
    }
}
