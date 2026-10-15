import UIKit
import AccountContext
import SwiftSignalKit
import TelegramCore
import WalletContext
import AnimationCache
import EmojiTextAttachmentView

public struct WalletGiftStickerFrame {
    public let image: UIImage
    public let art: UIImage
    public let silhouette: UIImage
}

/// Card sticker bitmaps for one gift, decoded through the shared animation cache.
/// Only the first frame and the requested playback frame are retained.
public final class WalletGiftStickerMedia {
    private static let queue = Queue(name: "WalletGiftStickerMedia", qos: .userInitiated)
    private static let renderSide = 320
    private static let renderPadding = Int(Double(renderSide) * 0.035)
    private static let contentSide = renderSide - renderPadding * 2
    public static let contentFraction = CGFloat(contentSide) / CGFloat(renderSide)

    private let context: AccountContext
    private let giftDisposable = MetaDisposable()
    private let modelDisposable = MetaDisposable()
    private let patternDisposable = MetaDisposable()
    private var renderRequested: Bool
    private var pendingModel: TelegramMediaFile?
    private var loadedModelId: String?
    private var requestedPattern: Data?
    private var player: AnimationCacheItem?
    private var playerPosition: Double = 0
    private var busy = false

    public private(set) var first: WalletGiftStickerFrame?
    public private(set) var uniqueGift: StarGift.UniqueGift?
    public private(set) var style: WalletContext.CardGiftStyle?
    public private(set) var modelFile: Data?
    public private(set) var patternImage: UIImage?
    public private(set) var duration: Double = 0
    public var updated: (() -> Void)?

    public init(context: AccountContext, gift: WalletContext.Collectible, modelFile: Data?, style: WalletContext.CardGiftStyle? = nil, prepareSticker: Bool = true) {
        self.context = context
        self.style = style
        self.renderRequested = prepareSticker
        if let style {
            self.loadPattern(style: style)
        }
        guard gift.kind == .gift else {
            return
        }
        if let file = Self.decodeFile(modelFile) {
            self.setModel(file)
        }
        if let unique = gift.nft?.gift {
            self.loadUniqueGift(unique)
        } else if self.style == nil || self.modelFile == nil, let slug = gift.giftSlug {
            self.giftDisposable.set((context.engine.payments.getUniqueStarGift(slug: slug)
            |> deliverOnMainQueue).start(next: { [weak self] gift in
                self?.loadUniqueGift(gift)
            }))
        }
    }

    deinit {
        self.giftDisposable.dispose()
        self.modelDisposable.dispose()
        self.patternDisposable.dispose()
    }

    public func updateGift(context: AccountContext, gift: WalletContext.Collectible) {
        if let unique = gift.nft?.gift, self.uniqueGift != unique {
            self.loadUniqueGift(unique)
        }
    }

    public func prepareForSticker(context: AccountContext, modelFile: Data? = nil) {
        self.renderRequested = true
        if let file = Self.decodeFile(modelFile), file.resource.id.stringRepresentation != self.loadedModelId {
            self.setModel(file)
        } else if let file = self.pendingModel {
            self.setModel(file)
        }
    }

    public var diagnosticState: String {
        if self.first != nil {
            return "ready"
        }
        if self.loadedModelId != nil {
            return "loading model"
        }
        if self.pendingModel != nil {
            return "preparation deferred"
        }
        return "missing model"
    }

    private func loadUniqueGift(_ gift: StarGift.UniqueGift) {
        self.uniqueGift = gift
        var pattern: Data?
        for case let .pattern(_, file, _) in gift.attributes {
            pattern = Self.encodeFile(file)
        }
        for case let .backdrop(_, _, inner, outer, color, _, _) in gift.attributes {
            self.style = WalletContext.CardGiftStyle(innerColor: inner, outerColor: outer, patternColor: color, patternFile: pattern)
        }
        if let style = self.style, self.patternImage == nil {
            self.loadPattern(style: style)
        }
        self.updated?()
        for case let .model(_, file, _, _) in gift.attributes {
            if self.modelFile == nil {
                self.setModel(file)
            }
            break
        }
    }

    private func setModel(_ file: TelegramMediaFile) {
        self.modelFile = Self.encodeFile(file)
        self.pendingModel = file
        let id = file.resource.id.stringRepresentation
        guard self.renderRequested, self.loadedModelId != id else {
            return
        }
        self.loadedModelId = id
        self.player = nil
        let size = CGSize(width: Self.contentSide, height: Self.contentSide)
        if self.first == nil, let item = self.context.animationCache.getFirstFrameSynchronously(sourceId: id, size: size) {
            item.reset()
            if let advance = item.advance(advance: .frames(1), requestedFormat: .rgba) {
                self.first = Self.render(advance.frame)
            }
        }
        let fetch = animationCacheFetchFile(context: self.context, userLocation: .other, userContentType: .sticker,
            resource: .media(media: .standalone(media: file), resource: file.resource), type: .lottie, keyframeOnly: false, customColor: nil)
        self.modelDisposable.set((self.context.animationCache.get(sourceId: id, size: size, fetch: fetch)
        |> filter { $0.isFinal }
        |> take(1)
        |> deliverOn(Self.queue)
        |> map { result -> (AnimationCacheItem, WalletGiftStickerFrame?, Double)? in
            guard let item = result.item, item.numFrames > 0 else {
                return nil
            }
            item.reset()
            var first: WalletGiftStickerFrame?
            var duration: Double = 0
            for _ in 0 ..< item.numFrames {
                guard let advance = item.advance(advance: .frames(1), requestedFormat: .rgba) else {
                    break
                }
                duration = advance.frame.duration * Double(item.numFrames)
                first = autoreleasepool { Self.render(advance.frame) }
                if first != nil {
                    break
                }
            }
            item.reset()
            return (item, first, duration)
        }
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self, self.loadedModelId == id, let (item, first, duration) = result else {
                return
            }
            self.player = item
            self.playerPosition = 0
            self.duration = duration
            if let first {
                self.first = first
            }
            self.updated?()
        }))
        if self.first != nil {
            self.updated?()
        }
    }

    private func loadPattern(style: WalletContext.CardGiftStyle) {
        guard let data = style.patternFile, self.requestedPattern != data, let file = Self.decodeFile(data) else {
            return
        }
        self.requestedPattern = data
        let id = file.resource.id.stringRepresentation
        let size = CGSize(width: Self.renderSide, height: Self.renderSide)
        if let item = self.context.animationCache.getFirstFrameSynchronously(sourceId: id, size: size) {
            item.reset()
            if let advance = item.advance(advance: .frames(1), requestedFormat: .rgba), let image = Self.image(advance.frame) {
                self.patternImage = UIImage(cgImage: image)
                return
            }
        }
        let fetch = animationCacheFetchFile(context: self.context, userLocation: .other, userContentType: .sticker,
            resource: .media(media: .standalone(media: file), resource: file.resource), type: .lottie, keyframeOnly: true, customColor: nil)
        self.patternDisposable.set(self.context.animationCache.getFirstFrame(queue: Self.queue, sourceId: id, size: size, fetch: fetch, completion: { [weak self] result in
            guard result.isFinal, let item = result.item else {
                return
            }
            item.reset()
            guard let advance = item.advance(advance: .frames(1), requestedFormat: .rgba), let image = Self.image(advance.frame) else {
                return
            }
            Queue.mainQueue().async {
                guard let self, self.requestedPattern == data else {
                    return
                }
                self.patternImage = UIImage(cgImage: image)
                self.updated?()
            }
        }))
    }

    public func frame(at time: Double, completion: @escaping (WalletGiftStickerFrame?) -> Void) -> Bool {
        guard !self.busy, let player = self.player else {
            return false
        }
        self.busy = true
        let position = self.playerPosition
        Self.queue.async { [weak self] in
            var current = position
            if time < 0.0001 || time < current - 0.0001 {
                player.reset()
                current = 0
            }
            var frame: AnimationCacheItemFrame?
            repeat {
                guard let advance = player.advance(advance: .frames(1), requestedFormat: .rgba), !(advance.didLoop && frame != nil) else {
                    break
                }
                frame = advance.frame
                current += advance.frame.duration
            } while current <= time
            let rendered = frame.flatMap { frame in autoreleasepool { Self.render(frame) } }
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.busy = false
                if self.player === player {
                    self.playerPosition = current
                }
                completion(rendered)
            }
        }
        return true
    }

    public static func preload(context: AccountContext, card: WalletCard) -> Disposable {
        let disposables = DisposableSet()
        var seen = Set<String>()
        for sticker in card.stickers {
            for attribute in sticker.nft.gift?.attributes ?? [] {
                let file: TelegramMediaFile
                let side: Int
                let keyframeOnly: Bool
                switch attribute {
                case let .model(_, modelFile, _, _):
                    file = modelFile
                    side = Self.contentSide
                    keyframeOnly = false
                case let .pattern(_, patternFile, _):
                    file = patternFile
                    side = Self.renderSide
                    keyframeOnly = true
                default:
                    continue
                }
                let id = file.resource.id.stringRepresentation
                guard seen.insert(id).inserted else { continue }
                let size = CGSize(width: side, height: side)
                if context.animationCache.getFirstFrameSynchronously(sourceId: id, size: size) != nil {
                    continue
                }
                let fetch = animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker,
                    resource: .media(media: .standalone(media: file), resource: file.resource), type: .lottie, keyframeOnly: keyframeOnly, customColor: nil)
                disposables.add((context.animationCache.get(sourceId: id, size: size, fetch: fetch)
                |> filter { $0.isFinal }
                |> take(1)).start())
            }
        }
        return disposables
    }

    private static func decodeFile(_ data: Data?) -> TelegramMediaFile? {
        guard let data else {
            return nil
        }
        return EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaFile
    }

    private static func encodeFile(_ file: TelegramMediaFile) -> Data {
        let encoder = EnginePostboxEncoder()
        encoder.encodeRootObject(file)
        return encoder.makeData()
    }

    private static func image(_ frame: AnimationCacheItemFrame) -> CGImage? {
        guard case let .rgba(data, width, height, bytesPerRow) = frame.format, width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data else {
            return nil
        }
        data.withUnsafeBytes { source in
            if let base = source.baseAddress {
                memcpy(bytes, base, min(source.count, height * bytesPerRow))
            }
        }
        return context.makeImage()
    }

    private static func render(_ frame: AnimationCacheItemFrame) -> WalletGiftStickerFrame? {
        guard let source = Self.image(frame) else {
            return nil
        }
        let side = Self.renderSide
        let bytesPerRow = side * 4
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
            let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let pad = CGFloat(Self.renderPadding)
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: pad, y: pad, width: CGFloat(Self.contentSide), height: CGFloat(Self.contentSide)))
        guard stride(from: 3, to: side * bytesPerRow, by: 4).contains(where: { bytes[$0] != 0 }) else { return nil }
        guard let art = context.makeImage() else { return nil }
        guard walletGiftStickerCutout(bytes: bytes, side: side) else { return nil }
        guard let cut = context.makeImage() else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { renderer in
            renderer.cgContext.setShadow(offset: CGSize(width: 0, height: 2.5), blur: 5.5,
                color: UIColor.black.withAlphaComponent(0.34).cgColor)
            UIImage(cgImage: cut).draw(in: bounds)
            renderer.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIImage(cgImage: art).draw(in: bounds)
        }
        return WalletGiftStickerFrame(image: image, art: UIImage(cgImage: art), silhouette: UIImage(cgImage: cut))
    }
}
