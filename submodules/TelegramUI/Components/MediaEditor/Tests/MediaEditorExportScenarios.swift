import Foundation
import UIKit
import AVFoundation
import Display
import Postbox
import TelegramCore
@testable import MediaEditor

private final class MediaEditorExportFixturesBundleMarker {
}

enum MediaEditorExportFixtures {
    static let bundle = Bundle(for: MediaEditorExportFixturesBundleMarker.self)
    static let resourcesURL = bundle.resourceURL!.appendingPathComponent("Tests/Resources")

    static let storyDimensions = CGSize(width: 1080.0, height: 1920.0)
    static let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    static func url(_ name: String) -> URL {
        return resourcesURL.appendingPathComponent(name)
    }

    static func data(_ name: String) -> Data {
        return try! Data(contentsOf: url(name))
    }

    static let photo: UIImage = UIImage(cgImage: UIImage(data: data("photo.png"))!.cgImage!, scale: 1.0, orientation: .up)

    static let storyPhoto: UIImage = {
        let photo = MediaEditorExportFixtures.photo
        return renderImage(size: storyDimensions, opaque: true) { context, size in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            let fitted = photo.size.aspectFitted(size)
            photo.draw(in: CGRect(x: (size.width - fitted.width) / 2.0, y: (size.height - fitted.height) / 2.0, width: fitted.width, height: fitted.height))
        }
    }()

    static let stickerImage: UIImage = renderImage(size: CGSize(width: 512.0, height: 512.0), opaque: false) { context, size in
        context.setFillColor(UIColor(rgb: 0xe0287a).cgColor)
        context.fillEllipse(in: CGRect(x: 40.0, y: 40.0, width: 432.0, height: 432.0))
        context.setFillColor(UIColor(rgb: 0xffd60a).cgColor)
        context.fill(CGRect(x: 176.0, y: 96.0, width: 160.0, height: 320.0))
    }

    static let textImage: UIImage = renderImage(size: CGSize(width: 520.0, height: 180.0), opaque: false) { context, size in
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 36.0).cgPath)
        context.fillPath()
        let text = NSAttributedString(string: "Export 42", attributes: [.font: UIFont.boldSystemFont(ofSize: 96.0), .foregroundColor: UIColor.black])
        let bounds = text.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil)
        text.draw(at: CGPoint(x: (size.width - bounds.width) / 2.0, y: (size.height - bounds.height) / 2.0))
    }

    static func drawingImage(size: CGSize) -> UIImage {
        return renderImage(size: size, opaque: false) { context, size in
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(size.width * 0.02)
            context.setStrokeColor(UIColor(rgb: 0x34c759).cgColor)
            context.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.15))
            context.addCurve(to: CGPoint(x: size.width * 0.9, y: size.height * 0.2), control1: CGPoint(x: size.width * 0.3, y: size.height * 0.05), control2: CGPoint(x: size.width * 0.6, y: size.height * 0.35))
            context.strokePath()
            context.setStrokeColor(UIColor(rgb: 0x0a84ff).withAlphaComponent(0.7).cgColor)
            context.move(to: CGPoint(x: size.width * 0.15, y: size.height * 0.85))
            context.addLine(to: CGPoint(x: size.width * 0.85, y: size.height * 0.75))
            context.strokePath()
        }
    }

    static func renderImage(size: CGSize, opaque: Bool, draw: (CGContext, CGSize) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext, size)
        }
    }

    static let tgsFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 1), partialReference: nil, resource: LocalFileMediaResource(fileId: 1), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: Int64(data("sticker.tgs").count), attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: nil, maskData: nil), .ImageSize(size: PixelDimensions(width: 512, height: 512))], alternativeRepresentations: [])

    static let webmFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 2), partialReference: nil, resource: LocalFileMediaResource(fileId: 2), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/webm", size: Int64(data("sticker.webm").count), attributes: [.FileName(fileName: "sticker.webm"), .Sticker(displayText: "", packReference: nil, maskData: nil), .Video(duration: 3.0, size: PixelDimensions(width: 512, height: 512), flags: [], preloadSize: nil, coverTime: nil, videoCodec: "vp9")], alternativeRepresentations: [])

    static let templateEmojiFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 3), partialReference: nil, resource: LocalFileMediaResource(fileId: 1), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: Int64(data("sticker.tgs").count), attributes: [.FileName(fileName: "sticker.tgs"), .CustomEmoji(isPremium: false, isSingleColor: true, alt: "*", packReference: .id(id: 1, accessHash: 0)), .ImageSize(size: PixelDimensions(width: 512, height: 512))], alternativeRepresentations: [])

    static let squareVideoFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 4), partialReference: nil, resource: LocalFileMediaResource(fileId: 3), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: Int64(data("video-square.mp4").count), attributes: [.FileName(fileName: "video-square.mp4"), .Video(duration: 2.0, size: PixelDimensions(width: 512, height: 512), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])

    private static var storedMediaBoxPaths = Set<String>()

    static func storeIfNeeded(in postbox: Postbox) {
        guard !storedMediaBoxPaths.contains(postbox.mediaBox.basePath) else {
            return
        }
        storedMediaBoxPaths.insert(postbox.mediaBox.basePath)
        postbox.mediaBox.storeResourceData(tgsFile.resource.id, data: data("sticker.tgs"), synchronous: true)
        postbox.mediaBox.storeResourceData(webmFile.resource.id, data: data("sticker.webm"), synchronous: true)
        postbox.mediaBox.storeResourceData(squareVideoFile.resource.id, data: data("video-square.mp4"), synchronous: true)
    }

    static func videoFrameCount(_ asset: AVAsset) -> Int {
        guard let track = asset.tracks(withMediaType: .video).first, let reader = try? AVAssetReader(asset: asset) else {
            return 0
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sampleBuffer = output.copyNextSampleBuffer() {
            count += CMSampleBufferGetNumSamples(sampleBuffer)
        }
        return count
    }
}

enum MediaEditorExportInputs {
    case video(subject: MediaEditorVideoExport.Subject, configuration: MediaEditorVideoExport.Configuration, textScale: CGFloat, expectedFrameCount: Int, expectedDuration: Double)
    case photoStory(image: UIImage, values: MediaEditorValues, dimensions: CGSize, textScale: CGFloat)
    case photoChat(image: UIImage, values: MediaEditorValues, maxOutputSide: CGFloat)
    case unavailable(String)
}

struct MediaEditorExportScenario {
    enum Kind {
        case video
        case photoStory
        case photoChat
    }

    let id: String
    let kind: Kind
    let checksDecodedOutput: Bool
    let durationTolerance: Double?
    private let build: () -> MediaEditorExportInputs

    init(id: String, kind: Kind, checksDecodedOutput: Bool = true, durationTolerance: Double? = nil, build: @escaping () -> MediaEditorExportInputs) {
        self.id = id
        self.kind = kind
        self.checksDecodedOutput = checksDecodedOutput
        self.durationTolerance = durationTolerance
        self.build = build
    }

    func makeInputs(postbox: Postbox) -> MediaEditorExportInputs {
        MediaEditorExportFixtures.storeIfNeeded(in: postbox)
        return self.build()
    }
}

private enum Variant {
    case story
    case chat
}

private let storyGradientColors: [UIColor] = [UIColor(rgb: 0x1a2a6c), UIColor(rgb: 0xb21f1f)]
private let videoDimensions = PixelDimensions(width: 1080, height: 1920)
private let photoDimensions = PixelDimensions(width: 3024, height: 4032)

private func storyValues(originalDimensions: PixelDimensions, gradientColors: [UIColor] = storyGradientColors) -> MediaEditorValues {
    return MediaEditorValues(
        peerId: MediaEditorExportFixtures.peerId,
        originalDimensions: originalDimensions,
        cropOffset: .zero,
        cropRect: nil,
        cropScale: 1.0,
        cropRotation: 0.0,
        cropMirroring: false,
        cropOrientation: nil,
        cropPerspective: .zero,
        gradientColors: gradientColors,
        videoTrimRange: nil,
        videoBounce: false,
        videoIsMuted: false,
        videoIsFullHd: false,
        videoIsMirrored: false,
        videoVolume: 1.0,
        additionalVideoPath: nil,
        additionalVideoIsDual: false,
        additionalVideoMirroringChanges: [],
        additionalVideoPosition: nil,
        additionalVideoScale: nil,
        additionalVideoRotation: nil,
        additionalVideoPositionChanges: [],
        additionalVideoTrimRange: nil,
        additionalVideoOffset: nil,
        additionalVideoVolume: nil,
        collage: [],
        nightTheme: false,
        drawing: nil,
        maskDrawing: nil,
        entities: [],
        toolValues: [:],
        audioTrack: nil,
        audioTrackTrimRange: nil,
        audioTrackOffset: nil,
        audioTrackVolume: nil,
        audioTrackSamples: nil,
        collageTrackSamples: nil,
        coverImageTimestamp: nil,
        coverDimensions: nil,
        qualityPreset: nil
    )
}

private func baseValues(_ variant: Variant, originalDimensions: PixelDimensions) -> MediaEditorValues {
    switch variant {
    case .story:
        return storyValues(originalDimensions: originalDimensions)
    case .chat:
        return chatMediaEditorValues(peerId: MediaEditorExportFixtures.peerId, originalDimensions: originalDimensions, qualityPreset: .compressedHigh)
    }
}

private func canvasSize(_ variant: Variant, originalDimensions: PixelDimensions) -> CGSize {
    switch variant {
    case .story:
        return MediaEditorExportFixtures.storyDimensions
    case .chat:
        return mediaEditorNonStoryCanvasSize(originalDimensions: originalDimensions)
    }
}

private func withEntities(_ values: MediaEditorValues, drawing: UIImage? = nil, _ entities: [DrawingEntity]) -> MediaEditorValues {
    return values.withUpdatedDrawingAndEntities(drawing: drawing, entities: entities.compactMap { CodableDrawingEntity(entity: $0) })
}

private func staticStickerEntity(canvas: CGSize) -> DrawingStickerEntity {
    let entity = DrawingStickerEntity(content: .image(MediaEditorExportFixtures.stickerImage, .sticker))
    entity.referenceDrawingSize = canvas
    entity.position = CGPoint(x: canvas.width * 0.7, y: canvas.height * 0.3)
    entity.scale = 1.2
    entity.rotation = 0.35
    return entity
}

private func textEntity(canvas: CGSize, color: UIColor = .white, subEntities: [DrawingEntity]? = nil) -> DrawingTextEntity {
    let entity = DrawingTextEntity(text: NSAttributedString(string: "Export 42"), style: .filled, animation: .none, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: DrawingColor(color: color))
    entity.referenceDrawingSize = canvas
    entity.position = CGPoint(x: canvas.width * 0.4, y: canvas.height * 0.65)
    entity.scale = 1.0
    entity.rotation = -0.2
    entity.renderImage = MediaEditorExportFixtures.textImage
    entity.renderSubEntities = subEntities
    return entity
}

private func fileStickerEntity(_ file: TelegramMediaFile, canvas: CGSize, position: CGPoint, scale: CGFloat, rotation: CGFloat) -> DrawingStickerEntity {
    let entity = DrawingStickerEntity(content: .file(.standalone(media: file), .sticker))
    entity.referenceDrawingSize = canvas
    entity.position = CGPoint(x: canvas.width * position.x, y: canvas.height * position.y)
    entity.scale = scale
    entity.rotation = rotation
    return entity
}

private func gifStickerEntity(canvas: CGSize) -> DrawingStickerEntity {
    let data = MediaEditorExportFixtures.data("animation.heics")
    let entity = DrawingStickerEntity(content: .animatedImage(data, UIImage(data: data)!))
    entity.referenceDrawingSize = canvas
    entity.position = CGPoint(x: canvas.width * 0.3, y: canvas.height * 0.55)
    entity.scale = 1.4
    entity.rotation = -0.3
    return entity
}

private func tintedEmojiTextEntity(canvas: CGSize) -> DrawingTextEntity {
    let emoji = fileStickerEntity(MediaEditorExportFixtures.templateEmojiFile, canvas: canvas, position: CGPoint(x: 0.62, y: 0.55), scale: 1.2, rotation: -0.2)
    return textEntity(canvas: canvas, color: UIColor(rgb: 0xff8a00), subEntities: [emoji])
}

private func adjustedToolValues() -> [EditorToolKey: Any] {
    return [
        .contrast: Float(0.35),
        .saturation: Float(0.3),
        .warmth: Float(0.25),
        .vignette: Float(0.5),
        .blur: BlurValue(mode: .radial, intensity: 0.6, position: CGPoint(x: 0.5, y: 0.5), size: 0.24, falloff: 0.12, rotation: 0.0)
    ]
}

private func videoAsset(_ name: String) -> AVURLAsset {
    return AVURLAsset(url: MediaEditorExportFixtures.url(name))
}

private func videoExport(_ variant: Variant, values: MediaEditorValues, configure: (inout MediaEditorVideoExport.Configuration) -> Void = { _ in }) -> MediaEditorExportInputs {
    let asset = videoAsset("video-portrait.mp4")
    var configuration = recommendedVideoExportConfiguration(values: values, duration: asset.duration.seconds, frameRate: 30.0)
    configure(&configuration)
    return .video(subject: .video(asset: asset, isStory: variant == .story), configuration: configuration, textScale: variant == .story ? 2.0 : 1.0, expectedFrameCount: MediaEditorExportFixtures.videoFrameCount(asset), expectedDuration: asset.duration.seconds)
}

private func imageExport(_ variant: Variant, values: MediaEditorValues) -> MediaEditorExportInputs {
    let image = variant == .story ? MediaEditorExportFixtures.storyPhoto : MediaEditorExportFixtures.photo
    let configuration = recommendedVideoExportConfiguration(values: values, duration: 5.0, image: true, frameRate: 30.0)
    let duration = mediaEditorImageExportDuration(values: configuration.values)
    let frameCount = Int((duration * Double(configuration.frameRate)).rounded())
    return .video(subject: .image(image: image), configuration: configuration, textScale: variant == .story ? 2.0 : 1.0, expectedFrameCount: frameCount, expectedDuration: duration)
}

private func photoComposition(_ variant: Variant, values: MediaEditorValues) -> MediaEditorExportInputs {
    switch variant {
    case .story:
        return .photoStory(image: MediaEditorExportFixtures.storyPhoto, values: values, dimensions: MediaEditorExportFixtures.storyDimensions, textScale: 2.0)
    case .chat:
        return .photoChat(image: MediaEditorExportFixtures.photo, values: values, maxOutputSide: 2560.0)
    }
}

private func photoOriginalDimensions(_ variant: Variant) -> PixelDimensions {
    switch variant {
    case .story:
        return PixelDimensions(width: 1080, height: 1920)
    case .chat:
        return photoDimensions
    }
}

private func prefix(_ variant: Variant) -> String {
    switch variant {
    case .story:
        return "story"
    case .chat:
        return "chat"
    }
}

let mediaEditorExportScenarios: [MediaEditorExportScenario] = {
    var scenarios: [MediaEditorExportScenario] = []
    let variants: [Variant] = [.story, .chat]

    for variant in variants {
        let dimensions = photoOriginalDimensions(variant)
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-photo", kind: variant == .story ? .photoStory : .photoChat) {
            return photoComposition(variant, values: baseValues(variant, originalDimensions: dimensions))
        })
    }
    for variant in variants {
        let dimensions = photoOriginalDimensions(variant)
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-photo-drawing-text-sticker", kind: variant == .story ? .photoStory : .photoChat) {
            let canvas = canvasSize(variant, originalDimensions: dimensions)
            let values = withEntities(baseValues(variant, originalDimensions: dimensions), drawing: MediaEditorExportFixtures.drawingImage(size: canvas), [staticStickerEntity(canvas: canvas), textEntity(canvas: canvas)])
            return photoComposition(variant, values: values)
        })
    }
    for variant in variants {
        let dimensions = photoOriginalDimensions(variant)
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-photo-tgs", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: dimensions)
            let values = withEntities(baseValues(variant, originalDimensions: dimensions), [fileStickerEntity(MediaEditorExportFixtures.tgsFile, canvas: canvas, position: CGPoint(x: 0.5, y: 0.5), scale: 1.5, rotation: 0.2)])
            return imageExport(variant, values: values)
        })
    }
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-adjust", kind: .video) {
            let values = baseValues(variant, originalDimensions: videoDimensions).withUpdatedToolValues(adjustedToolValues())
            return videoExport(variant, values: values)
        })
    }
    scenarios.append(MediaEditorExportScenario(id: "chat-video-crop", kind: .video) {
        let values = baseValues(.chat, originalDimensions: videoDimensions).withUpdatedCrop(rect: CGRect(x: 100.0, y: 200.0, width: 800.0, height: 1200.0), rotation: 0.3, orientation: .right, mirroring: true, perspective: .zero)
        return videoExport(.chat, values: values)
    })
    scenarios.append(MediaEditorExportScenario(id: "chat-video-odd-crop", kind: .video) {
        let values = baseValues(.chat, originalDimensions: videoDimensions).withUpdatedCrop(rect: CGRect(x: 180.0, y: 318.0, width: 721.0, height: 1283.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        return videoExport(.chat, values: values, configure: { configuration in
            configuration.videoSettings[AVVideoWidthKey] = 721
            configuration.videoSettings[AVVideoHeightKey] = 1283
        })
    })
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-sticker-text", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: videoDimensions)
            let values = withEntities(baseValues(variant, originalDimensions: videoDimensions), [staticStickerEntity(canvas: canvas), textEntity(canvas: canvas)])
            return videoExport(variant, values: values)
        })
    }
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-tgs", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: videoDimensions)
            let values = withEntities(baseValues(variant, originalDimensions: videoDimensions), [fileStickerEntity(MediaEditorExportFixtures.tgsFile, canvas: canvas, position: CGPoint(x: 0.5, y: 0.45), scale: 1.5, rotation: 0.2)])
            return videoExport(variant, values: values)
        })
    }
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-webm", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: videoDimensions)
            let values = withEntities(baseValues(variant, originalDimensions: videoDimensions), [fileStickerEntity(MediaEditorExportFixtures.webmFile, canvas: canvas, position: CGPoint(x: 0.35, y: 0.4), scale: 1.3, rotation: -0.25)])
            return videoExport(variant, values: values)
        })
    }
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-gif", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: videoDimensions)
            let values = withEntities(baseValues(variant, originalDimensions: videoDimensions), [gifStickerEntity(canvas: canvas)])
            return videoExport(variant, values: values)
        })
    }
    for variant in variants {
        scenarios.append(MediaEditorExportScenario(id: "\(prefix(variant))-video-tinted-emoji", kind: .video) {
            let canvas = canvasSize(variant, originalDimensions: videoDimensions)
            let values = withEntities(baseValues(variant, originalDimensions: videoDimensions), [tintedEmojiTextEntity(canvas: canvas)])
            return videoExport(variant, values: values)
        })
    }
    scenarios.append(MediaEditorExportScenario(id: "sticker-export", kind: .video, checksDecodedOutput: false) {
        let values = storyValues(originalDimensions: PixelDimensions(width: 512, height: 512), gradientColors: [.clear, .clear])
        let configuration = recommendedVideoExportConfiguration(values: values, duration: 3.0, frameRate: 30.0, isSticker: true)
        let duration = configuration.preferredDuration ?? 3.0
        let frameCount = Int((duration * Double(configuration.frameRate)).rounded())
        return .video(subject: .sticker(file: MediaEditorExportFixtures.tgsFile), configuration: configuration, textScale: 2.0, expectedFrameCount: frameCount, expectedDuration: duration)
    })
    scenarios.append(MediaEditorExportScenario(id: "avatar-export", kind: .video) {
        let asset = videoAsset("video-portrait.mp4")
        let values = storyValues(originalDimensions: videoDimensions)
        let configuration = recommendedVideoExportConfiguration(values: values, duration: asset.duration.seconds, frameRate: 30.0, isAvatar: true)
        return .video(subject: .video(asset: asset, isStory: false), configuration: configuration, textScale: 2.0, expectedFrameCount: MediaEditorExportFixtures.videoFrameCount(asset), expectedDuration: asset.duration.seconds)
    })
    scenarios.append(MediaEditorExportScenario(id: "story-video-mediasticker", kind: .video) {
        let canvas = MediaEditorExportFixtures.storyDimensions
        let entity = DrawingStickerEntity(content: .video(MediaEditorExportFixtures.squareVideoFile))
        entity.referenceDrawingSize = canvas
        entity.position = CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.7)
        entity.scale = 1.0
        entity.rotation = 0.15
        let values = withEntities(baseValues(.story, originalDimensions: videoDimensions), [entity])
        return videoExport(.story, values: values)
    })
    return scenarios
}()

private let realisticSourceDimensions = PixelDimensions(width: Int32(MediaEditorRealisticSource.codedHeight), height: Int32(MediaEditorRealisticSource.codedWidth))

private var realisticSourceFrameCounts: [MediaEditorRealisticSource.Variant: Int] = [:]

private func realisticVideoExport(_ variant: Variant, source: MediaEditorRealisticSource.Variant, values: MediaEditorValues) -> MediaEditorExportInputs {
    guard let url = MediaEditorRealisticSource.url(source) else {
        return .unavailable("cannot generate the \(source.rawValue) source")
    }
    let asset = AVURLAsset(url: url)
    let frameCount: Int
    if let current = realisticSourceFrameCounts[source] {
        frameCount = current
    } else {
        frameCount = MediaEditorExportFixtures.videoFrameCount(asset)
        realisticSourceFrameCounts[source] = frameCount
    }
    let configuration: MediaEditorVideoExport.Configuration
    switch variant {
    case .story:
        configuration = recommendedVideoExportConfiguration(values: values, duration: asset.duration.seconds, forceFullHd: true, frameRate: 60.0)
    case .chat:
        configuration = recommendedVideoExportConfiguration(values: values, duration: asset.duration.seconds, frameRate: 30.0)
    }
    return .video(subject: .video(asset: asset, isStory: variant == .story), configuration: configuration, textScale: variant == .story ? 2.0 : 1.0, expectedFrameCount: frameCount, expectedDuration: asset.duration.seconds)
}

private func realisticBaseValues(_ variant: Variant) -> MediaEditorValues {
    switch variant {
    case .story:
        return storyValues(originalDimensions: realisticSourceDimensions)
    case .chat:
        return chatMediaEditorValues(peerId: MediaEditorExportFixtures.peerId, originalDimensions: realisticSourceDimensions, qualityPreset: .compressedMedium)
    }
}

private func realisticSuffix(_ source: MediaEditorRealisticSource.Variant) -> String {
    switch source {
    case .sdr:
        return ""
    case .hlg:
        return "-hlg"
    }
}

let mediaEditorRealisticExportScenarios: [MediaEditorExportScenario] = {
    var scenarios: [MediaEditorExportScenario] = []
    for source in [MediaEditorRealisticSource.Variant.sdr, .hlg] {
        let suffix = realisticSuffix(source)
        scenarios.append(MediaEditorExportScenario(id: "chat-video-4k\(suffix)", kind: .video) {
            return realisticVideoExport(.chat, source: source, values: realisticBaseValues(.chat))
        })
        if source == .sdr {
            scenarios.append(MediaEditorExportScenario(id: "chat-video-4k-crop", kind: .video) {
                let values = realisticBaseValues(.chat).withUpdatedCrop(rect: CGRect(x: 0.0, y: 840.0, width: 2160.0, height: 2160.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
                return realisticVideoExport(.chat, source: source, values: values)
            })
            scenarios.append(MediaEditorExportScenario(id: "chat-video-4k-adjust", kind: .video) {
                let values = realisticBaseValues(.chat).withUpdatedToolValues([.contrast: Float(0.2), .saturation: Float(0.25), .warmth: Float(0.15)])
                return realisticVideoExport(.chat, source: source, values: values)
            })
        }
        scenarios.append(MediaEditorExportScenario(id: "story-video-4k-sticker-text\(suffix)", kind: .video) {
            let canvas = MediaEditorExportFixtures.storyDimensions
            let values = withEntities(realisticBaseValues(.story), [staticStickerEntity(canvas: canvas), textEntity(canvas: canvas)])
            return realisticVideoExport(.story, source: source, values: values)
        })
    }
    return scenarios
}()

let mediaEditorStreamingWriterExportScenarios: [MediaEditorExportScenario] = {
    let trimRange = 2.614 ..< 7.5
    let variants: [Variant] = [.story, .chat]
    return variants.map { variant -> MediaEditorExportScenario in
        return MediaEditorExportScenario(id: "\(prefix(variant))-video-variable-frame-rate-trimmed-streaming", kind: .video, durationTolerance: 0.1) {
            guard let url = MediaEditorVariableFrameRateSource.url() else {
                return .unavailable("cannot generate the variable frame rate source")
            }
            let asset = AVURLAsset(url: url)
            let values = baseValues(variant, originalDimensions: videoDimensions).withUpdatedVideoTrimRange(trimRange)
            var configuration = recommendedVideoExportConfiguration(values: values, duration: asset.duration.seconds, frameRate: 30.0)
            configuration.useStreamingWriter = true
            let frameCount = MediaEditorVariableFrameRateSource.frameTimes.filter { trimRange.contains($0) }.count
            return .video(subject: .video(asset: asset, isStory: variant == .story), configuration: configuration, textScale: variant == .story ? 2.0 : 1.0, expectedFrameCount: frameCount, expectedDuration: trimRange.upperBound - trimRange.lowerBound)
        }
    }
}()

func mediaEditorExportScenarios(only: String?) -> [MediaEditorExportScenario] {
    guard let only else {
        return mediaEditorExportScenarios
    }
    let all = mediaEditorExportScenarios + mediaEditorRealisticExportScenarios + mediaEditorStreamingWriterExportScenarios
    var result: [MediaEditorExportScenario] = []
    for name in only.components(separatedBy: ",") {
        let selected = name == "realistic" ? mediaEditorRealisticExportScenarios : all.filter { $0.id == name }
        for scenario in selected where !result.contains(where: { $0.id == scenario.id }) {
            result.append(scenario)
        }
    }
    return result
}
