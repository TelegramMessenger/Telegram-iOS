import Foundation
import UIKit
import Metal
import MetalKit
import Vision
import Photos
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData

public final class MediaEditor {
    public enum Subject {
        case image(UIImage, PixelDimensions)
        case video(String, PixelDimensions)
        case asset(PHAsset)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, dimensions):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            }
        }
    }

    private let subject: Subject
    private var player: AVPlayer?
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    
    private weak var previewView: MediaEditorPreviewView?

    public var values: MediaEditorValues {
        didSet {
            self.updateRenderChain()
        }
    }
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    private let histogramCalculationPass = HistogramCalculationPass()
    
    private var textureSourceDisposable: Disposable?
    
    private let gradientColorsPromise = Promise<(UIColor, UIColor)?>()
    public var gradientColors: Signal<(UIColor, UIColor)?, NoError> {
        return self.gradientColorsPromise.get()
    }
    private var gradientColorsValue: (UIColor, UIColor)? {
        didSet {
            self.gradientColorsPromise.set(.single(self.gradientColorsValue))
        }
    }
    
    private let histogramPromise = Promise<Data>()
    public var histogram: Signal<Data, NoError> {
        return self.histogramPromise.get()
    }

    private var textureCache: CVMetalTextureCache!
    
    public var hasPortraitMask: Bool {
        return self.renderChain.blurPass.maskTexture != nil
    }
    
    public var resultIsVideo: Bool {
        let hasAnimatedEntities = false
        return self.player != nil || hasAnimatedEntities
    }
    
    public var resultImage: UIImage? {
        return self.renderer.finalRenderedImage()
    }
    
    public init(subject: Subject, values: MediaEditorValues? = nil, hasHistogram: Bool = false) {
        self.subject = subject
        if let values {
            self.values = values
        } else {
            self.values = MediaEditorValues(
                originalDimensions: subject.dimensions,
                cropOffset: .zero,
                cropSize: nil,
                cropScale: 1.0,
                cropRotation: 0.0,
                cropMirroring: false,
                gradientColors: nil,
                videoTrimRange: nil,
                videoIsMuted: false,
                drawing: nil,
                entities: [],
                toolValues: [:]
            )
        }

        self.renderer.addRenderChain(self.renderChain)
        if hasHistogram {
            self.renderer.addRenderPass(self.histogramCalculationPass)
        }
        
        self.histogramCalculationPass.updated = { [weak self] data in
            if let self {
                self.histogramPromise.set(.single(data))
            }
        }
    }
    
    deinit {
        self.textureSourceDisposable?.dispose()
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
    }
    
    private func setupSource() {
        guard let renderTarget = self.previewView else {
            return
        }
        
        if let device = renderTarget.mtlDevice, CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache) != kCVReturnSuccess {
            print("error")
        }
        
        func gradientColors(from image: UIImage) -> (UIColor, UIColor) {
            let context = DrawingContext(size: CGSize(width: 1.0, height: 4.0), scale: 1.0, clear: false)!
            context.withFlippedContext({ context in
                if let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 4.0))
                }
            })
            return (context.colorAt(CGPoint(x: 0.0, y: 0.0)), context.colorAt(CGPoint(x: 0.0, y: 3.0)))
        }
        
        let textureSource: Signal<(TextureSource, UIImage?, AVPlayer?, UIColor, UIColor), NoError>
        switch subject {
        case let .image(image, _):
            let colors = gradientColors(from: image)
            textureSource = .single((ImageTextureSource(image: image, renderTarget: renderTarget), image, nil, colors.0, colors.1))
        case let .video(path, _):
            textureSource = Signal { subscriber in
                let url = URL(fileURLWithPath: path)
                let asset = AVURLAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0, preferredTimescale: CMTimeScale(30.0)))]) { _, image, _, _, _ in
                    let playerItem = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: playerItem)
                    if let image {
                        let colors = gradientColors(from: UIImage(cgImage: image))
                        subscriber.putNext((VideoTextureSource(player: player, renderTarget: renderTarget), nil, player, colors.0, colors.1))
                    } else {
                        subscriber.putNext((VideoTextureSource(player: player, renderTarget: renderTarget), nil, player, .black, .black))
                    }
                }
                return ActionDisposable {
                    imageGenerator.cancelAllCGImageGeneration()
                }
            }
        case let .asset(asset):
            textureSource = Signal { subscriber in
                if asset.mediaType == .video {
                    let requestId = PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 128.0, height: 128.0), contentMode: .aspectFit, options: nil, resultHandler: { image, info in
                        if let image {
                            var degraded = false
                            if let info {
                                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                    return
                                }
                                if let degradedValue = info[PHImageResultIsDegradedKey] as? Bool, degradedValue {
                                    degraded = true
                                }
                            }
                            if !degraded {
                                let colors = gradientColors(from: image)
                                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil, resultHandler: { asset, _, _ in
                                    if let asset {
                                        let playerItem = AVPlayerItem(asset: asset)
                                        let player = AVPlayer(playerItem: playerItem)
                                        subscriber.putNext((VideoTextureSource(player: player, renderTarget: renderTarget), nil, player, colors.0, colors.1))
                                        subscriber.putCompletion()
                                    }
                                })
                            }
                        }
                    })
                    return ActionDisposable {
                        PHImageManager.default().cancelImageRequest(requestId)
                    }
                } else {
                    let requestId = PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1920.0, height: 1920.0), contentMode: .aspectFit, options: nil, resultHandler: { image, info in
                        if let image {
                            var degraded = false
                            if let info {
                                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                    return
                                }
                                if let degradedValue = info[PHImageResultIsDegradedKey] as? Bool, degradedValue {
                                    degraded = true
                                }
                            }
                            if !degraded {
                                let colors = gradientColors(from: image)
                                subscriber.putNext((ImageTextureSource(image: image, renderTarget: renderTarget), image, nil, colors.0, colors.1))
                                subscriber.putCompletion()
                            }
                        }
                    })
                    return ActionDisposable {
                        PHImageManager.default().cancelImageRequest(requestId)
                    }
                }
            }
        }
        
        self.textureSourceDisposable = (textureSource
        |> deliverOnMainQueue).start(next: { [weak self] sourceAndColors in
            if let self {
                let (source, image, player, topColor, bottomColor) = sourceAndColors
                self.renderer.textureSource = source
                self.player = player
                self.gradientColorsValue = (topColor, bottomColor)
                self.setGradientColors([topColor, bottomColor])
                
                self.maybeGeneratePersonSegmentation(image)
               
                if let player {
                    self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil, using: { [weak self] notification in
                        if let strongSelf = self {
                            strongSelf.player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 30))
                            strongSelf.player?.play()
                        }
                    })
                } else {
                    self.didPlayToEndTimeObserver = nil
                }
            }
        })
    }
    
    public func attachPreviewView(_ previewView: MediaEditorPreviewView) {
        self.previewView?.renderer = nil
        
        self.previewView = previewView
        previewView.renderer = self.renderer
        
        self.setupSource()
    }
    
    public func setCrop(offset: CGPoint, scale: CGFloat, rotation: CGFloat, mirroring: Bool) {
        self.values = self.values.withUpdatedCrop(offset: offset, scale: scale, rotation: rotation, mirroring: mirroring)
    }
    
    public func getToolValue(_ key: EditorToolKey) -> Any? {
        return self.values.toolValues[key]
    }
    
    public func setToolValue(_ key: EditorToolKey, value: Any) {
        var updatedToolValues = self.values.toolValues
        updatedToolValues[key] = value
        self.values = self.values.withUpdatedToolValues(updatedToolValues)
        self.updateRenderChain()
    }
    
    public func setVideoIsMuted(_ videoIsMuted: Bool) {
        self.player?.isMuted = videoIsMuted
        self.values = self.values.withUpdatedVideoIsMuted(videoIsMuted)
    }
    
    public func setDrawingAndEntities(data: Data?, image: UIImage?, entities: [CodableDrawingEntity]) {
        self.values = self.values.withUpdatedDrawingAndEntities(drawing: image, entities: entities)
    }
    
    public func setGradientColors(_ gradientColors: [UIColor]) {
        self.values = self.values.withUpdatedGradientColors(gradientColors: gradientColors)
    }
    
    private func updateRenderChain() {
        self.renderChain.update(values: self.values)
        if let player = self.player, player.rate > 0.0 {
        } else {
            self.previewView?.scheduleFrame()
        }
    }
    
    private func maybeGeneratePersonSegmentation(_ image: UIImage?) {
        if #available(iOS 15.0, *), let cgImage = image?.cgImage {
            let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
                guard let _ = request.results?.first as? VNFaceObservation else { return }
                
                let personRequest = VNGeneratePersonSegmentationRequest(completionHandler: { [weak self] request, error in
                    if let self, let result = (request as? VNGeneratePersonSegmentationRequest)?.results?.first {
                        Queue.mainQueue().async {
                            self.renderChain.blurPass.maskTexture = pixelBufferToMTLTexture(pixelBuffer: result.pixelBuffer, textureCache: self.textureCache)
                        }
                    }
                })
                personRequest.qualityLevel = .accurate
                personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([personRequest])
                } catch {
                    print(error)
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([faceRequest])
            } catch {
                print(error)
            }
        }
    }
}

final class MediaEditorRenderChain {
    fileprivate let enhancePass = EnhanceRenderPass()
    fileprivate let sharpenPass = SharpenRenderPass()
    fileprivate let blurPass = BlurRenderPass()
    fileprivate let adjustmentsPass = AdjustmentsRenderPass()
    
    var renderPasses: [RenderPass] {
        return [
            self.enhancePass,
            self.sharpenPass,
            self.blurPass,
            self.adjustmentsPass
        ]
    }
    
    func update(values: MediaEditorValues) {
        for (key, value) in values.toolValues {
            switch key {
            case .enhance:
                if let value = value as? Float {
                    self.enhancePass.value = value
                } else {
                    self.enhancePass.value = 0.0
                }
            case .brightness:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.exposure = value
                } else {
                    self.adjustmentsPass.adjustments.exposure = 0.0
                }
            case .contrast:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.contrast = value
                } else {
                    self.adjustmentsPass.adjustments.contrast = 0.0
                }
            case .saturation:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.saturation = value
                } else {
                    self.adjustmentsPass.adjustments.saturation = 0.0
                }
            case .warmth:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.warmth = value
                } else {
                    self.adjustmentsPass.adjustments.warmth = 0.0
                }
            case .fade:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.fade = value
                } else {
                    self.adjustmentsPass.adjustments.fade = 0.0
                }
            case .highlights:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.highlights = value
                } else {
                    self.adjustmentsPass.adjustments.highlights = 0.0
                }
            case .shadows:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.shadows = value
                } else {
                    self.adjustmentsPass.adjustments.shadows = 0.0
                }
            case .vignette:
                if let value = value as? Float {
                    self.adjustmentsPass.adjustments.vignette = value
                } else {
                    self.adjustmentsPass.adjustments.vignette = 0.0
                }
            case .grain:
                break
            case .sharpen:
                if let value = value as? Float {
                    self.sharpenPass.value = value
                } else {
                    self.sharpenPass.value = 0.0
                }
            case .shadowsTint:
                if let value = value as? TintValue {
                    let (red, green, blue, _) = value.color.components
                    self.adjustmentsPass.adjustments.shadowsTintColor = simd_float3(Float(red), Float(green), Float(blue))
                    self.adjustmentsPass.adjustments.shadowsTintIntensity = value.intensity
                }
            case .highlightsTint:
                if let value = value as? TintValue {
                    let (red, green, blue, _) = value.color.components
                    self.adjustmentsPass.adjustments.shadowsTintColor = simd_float3(Float(red), Float(green), Float(blue))
                    self.adjustmentsPass.adjustments.highlightsTintIntensity = value.intensity
                }
            case .blur:
                if let value = value as? BlurValue {
                    switch value.mode {
                    case .off:
                        self.blurPass.mode = .off
                    case .linear:
                        self.blurPass.mode = .linear
                    case .radial:
                        self.blurPass.mode = .radial
                    case .portrait:
                        self.blurPass.mode = .portrait
                    }
                    self.blurPass.intensity = value.intensity
                    self.blurPass.value.size = Float(value.size)
                    self.blurPass.value.position = simd_float2(Float(value.position.x), Float(value.position.y))
                    self.blurPass.value.falloff = Float(value.falloff)
                    self.blurPass.value.rotation = Float(value.rotation)
                }
            case .curves:
                var value = (value as? CurvesValue) ?? CurvesValue.initial
                let allDataPoints = value.all.dataPoints
                let redDataPoints = value.red.dataPoints
                let greenDataPoints = value.green.dataPoints
                let blueDataPoints = value.blue.dataPoints
                
                self.adjustmentsPass.allCurve = allDataPoints
                self.adjustmentsPass.redCurve = redDataPoints
                self.adjustmentsPass.greenCurve = greenDataPoints
                self.adjustmentsPass.blueCurve = blueDataPoints
            }
        }
    }
}
