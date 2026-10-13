import UIKit
import AccountContext
import SwiftSignalKit
import LottieBinding
import TelegramCore
import WalletContext
import WalletCollectibleHeaderComponent

public struct WalletGiftStickerFrame {
    public let image: UIImage
    public let art: UIImage
    public let silhouette: UIImage
}

/// One serial renderer per gift. Only the first frame and the requested playback
/// frame are retained; long animations never allocate an array of full bitmaps.
public final class WalletGiftStickerMedia {
    private let queue = DispatchQueue(label: "WalletGiftStickerMedia", qos: .userInitiated)
    private var instance: LottieInstance? // queue-confined
    private let disposables = DisposableSet()
    private var requestedPattern: Data?
    private var busy = false // main queue
    public private(set) var first: WalletGiftStickerFrame?
    public private(set) var uniqueGift: StarGift.UniqueGift?
    private var renderRequested = true
    private var pendingModel: TelegramMediaFile?
    private var loadingModelId: String?
    public private(set) var style: WalletContext.CardGiftStyle?
    public private(set) var modelFile: Data?
    public private(set) var patternImage: UIImage?
    private static let renderSide = 320
    private static let renderPadding = Int(Double(renderSide) * 0.035)
    public static let contentFraction = CGFloat(renderSide - renderPadding * 2) / CGFloat(renderSide)
    public private(set) var duration: Double = 0
    public var updated: (() -> Void)?

    public init(context: AccountContext, gift: WalletContext.Collectible, modelFile: Data?, style: WalletContext.CardGiftStyle? = nil, prepareSticker: Bool = true) {
        self.style = style
        self.renderRequested = prepareSticker
        if let style { self.loadPattern(context: context, style: style) }
        guard gift.kind == .gift else { return }

        if let modelFile,
           let file = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: modelFile)).decodeRootObject() as? TelegramMediaFile {
            self.load(context: context, file: file)
        }
        if let unique = gift.nft?.gift {
            self.loadUniqueGift(context: context, gift: unique)
        } else if self.style == nil || self.modelFile == nil, let slug = gift.giftSlug {
            self.disposables.add((context.engine.payments.getUniqueStarGift(slug: slug)
            |> deliverOnMainQueue).start(next: { [weak self] gift in
                guard let self else { return }
                self.loadUniqueGift(context: context, gift: gift)
            }))
        }
    }

    private func loadUniqueGift(context: AccountContext, gift: StarGift.UniqueGift) {
        self.uniqueGift = gift
        var pattern: Data?
        for case let .pattern(_, file, _) in gift.attributes {
            let encoder = EnginePostboxEncoder(); encoder.encodeRootObject(file); pattern = encoder.makeData()
        }
        for case let .backdrop(_, _, inner, outer, color, _, _) in gift.attributes {
            self.style = WalletContext.CardGiftStyle(innerColor: inner, outerColor: outer, patternColor: color, patternFile: pattern)
        }
        if let style = self.style, self.patternImage == nil { self.loadPattern(context: context, style: style) }
        self.updated?()
        for case let .model(_, file, _, _) in gift.attributes {
            if self.modelFile == nil { self.load(context: context, file: file) }
            break
        }
    }

    private func loadPattern(context: AccountContext, style: WalletContext.CardGiftStyle) {
        guard let data = style.patternFile, self.requestedPattern != data,
              let file = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaFile else { return }
        self.requestedPattern = data
        let settings = context.lottieRenderingSettings
        self.disposables.add(context.engine.resources.fetch(
            reference: FileMediaReference.standalone(media: file).resourceReference(file.resource),
            userLocation: .other, userContentType: MediaResourceUserContentType(file: file)).start())
        self.disposables.add((context.engine.resources.data(resource: EngineMediaResource(file.resource))
        |> filter { $0.isComplete } |> take(1) |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { [weak self] resource in
            guard resource.availableSize <= 5 * 1024 * 1024, let bytes = try? Data(contentsOf: URL(fileURLWithPath: resource.path)),
                  let data = walletCollectibleLottieData(bytes), let self else { return }
            self.queue.async { [weak self] in
                guard let instance = makeLottieInstance(data: data, fitzModifier: .none, colorReplacements: nil,
                    cacheKey: file.resource.id.stringRepresentation, settings: settings), let image = Self.renderBackdrop(instance) else { return }
                DispatchQueue.main.async { [weak self] in self?.patternImage = image; self?.updated?() }
            }
        }))
    }

    private static func renderBackdrop(_ instance: LottieInstance) -> UIImage? {
        let side = 320
        guard instance.frameCount > 0,
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        instance.renderFrame(with: 0, into: bytes, width: Int32(side), height: Int32(side), bytesPerRow: Int32(side * 4))
        return context.makeImage().map { UIImage(cgImage: $0) }
    }

    public func prepareForSticker(context: AccountContext) {
        self.renderRequested = true
        if let file = self.pendingModel { self.load(context: context, file: file) }
    }

    private func load(context: AccountContext, file: TelegramMediaFile) {
        let encoder = EnginePostboxEncoder()
        encoder.encodeRootObject(file)
        self.modelFile = encoder.makeData()
        self.pendingModel = file
        guard self.renderRequested, self.loadingModelId != file.resource.id.stringRepresentation else { return }
        self.loadingModelId = file.resource.id.stringRepresentation
        let settings = context.lottieRenderingSettings
        // Fetch the model's own resource. The NFT lottie includes backdrop and pattern.
        self.disposables.add(context.engine.resources.fetch(
            reference: FileMediaReference.standalone(media: file).resourceReference(file.resource),
            userLocation: .other, userContentType: MediaResourceUserContentType(file: file)).start())
        self.disposables.add((context.engine.resources.data(resource: EngineMediaResource(file.resource))
        |> filter { $0.isComplete }
        |> take(1)
        |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { [weak self] resource in
            guard resource.availableSize <= 5 * 1024 * 1024,
                  let bytes = try? Data(contentsOf: URL(fileURLWithPath: resource.path), options: .mappedIfSafe),
                  let data = walletCollectibleLottieData(bytes), let self else { return }
            self.queue.async { [weak self] in
                guard let self, let instance = makeLottieInstance(data: data, fitzModifier: .none,
                    colorReplacements: nil, cacheKey: file.resource.id.stringRepresentation, settings: settings),
                    instance.frameCount > 0, instance.frameRate > 0 else { return }
                self.instance = instance
                let frame = Self.render(instance, index: 0)
                let duration = Double(instance.frameCount) / Double(instance.frameRate)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.first = frame
                    self.duration = duration
                    self.updated?()
                }
            }
        }))
    }

    deinit { self.disposables.dispose() }

    public func frame(at time: Double, completion: @escaping (WalletGiftStickerFrame?) -> Void) -> Bool {
        guard !self.busy else { return false }
        self.busy = true
        self.queue.async { [weak self] in
            guard let self else { return }
            let frame: WalletGiftStickerFrame?
            if let instance = self.instance {
                let index = min(instance.frameCount - 1, max(0, Int32(time * Double(instance.frameRate))))
                frame = Self.render(instance, index: index)
            } else {
                frame = nil
            }
            DispatchQueue.main.async { [weak self] in
                self?.busy = false
                completion(frame)
            }
        }
        return true
    }

    private static func render(_ instance: LottieInstance, index: Int32) -> WalletGiftStickerFrame? {
        let side = Self.renderSide
        let bytesPerRow = side * 4
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
            let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        // SendMoney 14 uses a 3.5% transparent margin around the model.
        let pad = Self.renderPadding
        let contentSide = side - pad * 2
        instance.renderFrame(with: index, into: bytes.advanced(by: pad * bytesPerRow + pad * 4),
            width: Int32(contentSide), height: Int32(contentSide), bytesPerRow: Int32(bytesPerRow))
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
