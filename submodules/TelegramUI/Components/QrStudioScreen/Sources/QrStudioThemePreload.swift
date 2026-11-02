import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import AnimationCache
import EmojiTextAttachmentView

public extension QrStudioScreen {
    static func preloadTheme(context: AccountContext, peerId: EnginePeer.Id) -> Disposable {
        let disposables = DisposableSet()
        disposables.add(context.engine.peers.preloadShareTheme(peerId: peerId).startStrict())
        let framesDisposable = MetaDisposable()
        disposables.add(framesDisposable)
        disposables.add((context.engine.peers.localShareTheme(peerId: peerId)
        |> deliverOnMainQueue).startStrict(next: { theme in
            guard let theme, case let .gift(gift) = theme, case let .unique(uniqueGift) = gift else {
                framesDisposable.set(nil)
                return
            }
            var model: TelegramMediaFile?
            var pattern: TelegramMediaFile?
            for attribute in uniqueGift.attributes {
                switch attribute {
                case let .model(_, file, _, _):
                    model = file
                case let .pattern(_, file, _):
                    pattern = file
                default:
                    break
                }
            }
            framesDisposable.set(qrStudioWarmGiftFrames(context: context, model: model, pattern: pattern))
        }))
        return disposables
    }
}

private func qrStudioWarmGiftFrames(context: AccountContext, model: TelegramMediaFile?, pattern: TelegramMediaFile?) -> Disposable {
    let disposables = DisposableSet()
    if let model {
        let side = floor(QrStudioGiftPatternView.modelSide * UIScreenScale)
        let size = CGSize(width: side, height: side)
        let sourceId = model.resource.id.stringRepresentation
        if context.animationCache.getFirstFrameSynchronously(sourceId: sourceId, size: size) == nil {
            let fetch = animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: model), resource: model.resource), type: AnimationCacheAnimationType(file: model), keyframeOnly: true, customColor: model.isCustomTemplateEmoji ? .white : nil)
            disposables.add((context.animationCache.get(sourceId: sourceId, size: size, fetch: fetch)
            |> filter { $0.isFinal }
            |> take(1)).startStrict())
        }
    }
    if let pattern {
        disposables.add(context.animationRenderer.loadFirstFrameAsImage(
            cache: context.animationCache,
            itemId: pattern.resource.id.stringRepresentation,
            size: CGSize(width: 96.0, height: 96.0),
            fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: pattern), resource: pattern.resource), type: AnimationCacheAnimationType(file: pattern), keyframeOnly: false, customColor: .white),
            completion: { _ in }
        ))
    }
    return disposables
}
