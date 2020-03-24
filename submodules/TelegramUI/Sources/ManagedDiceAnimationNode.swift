import Foundation
import Display
import AsyncDisplayKit
import SyncCore
import TelegramCore
import SwiftSignalKit
import AccountContext
import StickerResources
import ManagedAnimationNode

enum ManagedDiceAnimationState: Equatable {
    case rolling
    case value(Int32)
}

final class ManagedDiceAnimationNode: ManagedAnimationNode, GenericAnimatedStickerNode {
    private let context: AccountContext
    private let emojis: [TelegramMediaFile]
    
    private var diceState: ManagedDiceAnimationState? = nil
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, emojis: [TelegramMediaFile]) {
        self.context = context
        self.emojis = emojis
        
        super.init(size: CGSize(width: 184.0, height: 184.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("Dice_Rolling"), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 60), duration: 1.0, loop: true))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func setState(_ diceState: ManagedDiceAnimationState) {
        let previousState = self.diceState
        self.diceState = diceState
        
        if let previousState = previousState {
            switch previousState {
                case .rolling:
                    switch diceState {
                        case let .value(value):
                            guard self.emojis.count == 6 else {
                                return
                            }
                            let file = self.emojis[Int(value) - 1]
                            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                            let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))
                            
                            let fetched = freeMediaFileInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file))
                            let sticker = Signal<Void, NoError> { subscriber in
                                let fetchedDisposable = fetched.start()
                                let resourceDisposable = (chatMessageAnimationData(postbox: self.context.account.postbox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                                |> filter { data in
                                    return data.complete
                                }).start(next: { next in
                                    subscriber.putNext(Void())
                                })
                                    
                                return ActionDisposable {
                                    fetchedDisposable.dispose()
                                    resourceDisposable.dispose()
                                }
                            }

                            self.disposable.set(sticker.start(next: { [weak self] data in
                                if let strongSelf = self {
                                    strongSelf.trackTo(item: ManagedAnimationItem(source: .resource(strongSelf.context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 180), duration: 3.0))
                                }
                            }))
                        case .rolling:
                            break
                    }
                case let .value(currentValue):
                    switch diceState {
                        case .rolling:
                            self.trackTo(item: ManagedAnimationItem(source: .local("Dice_Rolling"), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 60), duration: 1.0, loop: true))
                        case let .value(value):
                            break
                    }
            }
        } else {
            switch diceState {
                case let .value(value):
                    guard self.emojis.count == 6 else {
                        return
                    }
                    let file = self.emojis[Int(value) - 1]
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedSize = dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0))
                    
                    let fetched = freeMediaFileInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file))
                    let sticker = Signal<Void, NoError> { subscriber in
                        let fetchedDisposable = fetched.start()
                        let resourceDisposable = (chatMessageAnimationData(postbox: self.context.account.postbox, resource: file.resource, fitzModifier: nil, width: Int(fittedSize.width), height: Int(fittedSize.height), synchronousLoad: false)
                            |> filter { data in
                                return data.complete
                            }).start(next: { next in
                                subscriber.putNext(Void())
                            })
                        
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            resourceDisposable.dispose()
                        }
                    }
                    
                    self.disposable.set(sticker.start(next: { [weak self] data in
                        if let strongSelf = self {
                            strongSelf.trackTo(item: ManagedAnimationItem(source: .resource(strongSelf.context.account.postbox.mediaBox, file.resource), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 180), duration: 3.0))
                        }
                    }))
                case .rolling:
                    self.trackTo(item: ManagedAnimationItem(source: .local("Dice_Rolling"), frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 60), duration: 1.0, loop: true))
            }
        }
    }
}
