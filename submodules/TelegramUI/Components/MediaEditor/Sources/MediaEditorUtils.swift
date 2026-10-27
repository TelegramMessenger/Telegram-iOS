import Foundation
import UIKit
import Display
import AVFoundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramPresentationData

extension AVPlayer {
    func fadeVolume(from: Float, to: Float, duration: Float, completion: (() -> Void)? = nil) -> SwiftSignalKit.Timer? {
        self.volume = from
        guard from != to else { return nil }
        
        let interval: Float = 0.1
        let range = to - from
        let step = (range * interval) / duration
        
        func reachedTarget() -> Bool {
            guard self.volume >= 0, self.volume <= 1 else {
                self.volume = to
                return true
            }
            
            if to > from {
                return self.volume >= to
            }
            return self.volume <= to
        }
        
        var invalidateImpl: (() -> Void)?
        let timer = SwiftSignalKit.Timer(timeout: Double(interval), repeat: true, completion: { [weak self] in
            if let self, !reachedTarget() {
                self.volume += step
            } else {
                invalidateImpl?()
                completion?()
            }
        }, queue: Queue.mainQueue())
        invalidateImpl = { [weak timer] in
            timer?.invalidate()
        }
        timer.start()
        return timer
    }
}

func textureRotatonForAVAsset(_ asset: AVAsset, mirror: Bool = false) -> TextureRotation {
    for track in asset.tracks {
        if track.mediaType == .video {
            let t = track.preferredTransform
            if t.a == -1.0 && t.d == -1.0 {
                return .rotate180Degrees
            } else if t.a == 1.0 && t.d == 1.0 {
                return .rotate0Degrees
            } else if t.b == -1.0 && t.c == 1.0 {
                return .rotate270Degrees
            }  else if t.a == -1.0 && t.d == 1.0 {
                return .rotate270Degrees
            } else if t.a == 1.0 && t.d == -1.0  {
                return .rotate180Degrees
            } else {
                return mirror ? .rotate90DegreesMirrored : .rotate90Degrees
            }
        }
    }
    return .rotate0Degrees
}

/// The audio track to export. Videos recorded with Spatial Audio carry an AAC stereo track next to the APAC
/// one, and after a trim in Photos the APAC one comes first. Exporting from the AAC track skips rendering the
/// APAC one to stereo, so an AAC track is taken when there is one; other tracks are still exported (see
/// `linearPCMAudioSettings(matching:)`).
func preferredAudioTrack(in asset: AVAsset) -> AVAssetTrack? {
    let tracks = asset.tracks(withMediaType: .audio)
    let aacTrack = tracks.first(where: { track in
        guard let description = track.formatDescriptions.first else {
            return false
        }
        return CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription) == kAudioFormatMPEG4AAC
    })
    return aacTrack ?? tracks.first
}

/// Reader settings that decode audio straight to the channel count of the AAC encoder (`encoderSettings`).
/// The encoder only takes decoded audio with its own channel count, and it may be mono. Decoding straight
/// to it lets Core Audio downmix or render the source first: PCM tracks (ProRes), 5.1 and other
/// multichannel tracks, and Spatial Audio's ambisonic APAC track all fail otherwise.
func linearPCMAudioSettings(matching encoderSettings: [String: Any]) -> [String: Any]? {
    guard let channels = (encoderSettings[AVNumberOfChannelsKey] as? NSNumber)?.intValue, channels == 1 || channels == 2 else {
        return nil
    }
    var layout = AudioChannelLayout()
    layout.mChannelLayoutTag = channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
    return [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVNumberOfChannelsKey: channels,
        AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
    ]
}

func loadTexture(image: UIImage, device: MTLDevice) -> MTLTexture? {
    func dataForImage(_ image: UIImage) -> UnsafeMutablePointer<UInt8> {
        let imageRef = image.cgImage
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        let bytePerPixel = 4
        let bytesPerRow = bytePerPixel * Int(width)
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        if let context = CGContext(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(imageRef!, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return rawData
    }
    
    let width = Int(image.size.width * image.scale)
    let height = Int(image.size.height * image.scale)
    let bytePerPixel = 4
    let bytesPerRow = bytePerPixel * width
    
    var texture : MTLTexture?
    let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    texture = device.makeTexture(descriptor: textureDescriptor)
    
    let data = dataForImage(image)
    texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
    data.deallocate()
    
    return texture
}

func pixelBufferToMTLTexture(pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache) -> MTLTexture? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    let format: MTLPixelFormat = .r8Unorm
    var textureRef : CVMetalTexture?
    let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, format, width, height, 0, &textureRef)
    if status == kCVReturnSuccess {
        return CVMetalTextureGetTexture(textureRef!)
    }

    return nil
}

func getTextureImage(device: MTLDevice, texture: MTLTexture, mirror: Bool = false) -> UIImage? {
    let bitmapInfo: UInt32
    switch texture.pixelFormat {
    case .bgra8Unorm, .bgra8Unorm_srgb:
        bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    case .rgba8Unorm, .rgba8Unorm_srgb:
        bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    default:
        return nil
    }
    let width = texture.width
    let height = texture.height
    guard width > 0, height > 0 else {
        return nil
    }
    let bytesPerRow = width * 4
    guard let buffer = device.makeBuffer(length: bytesPerRow * height, options: .storageModeShared), let commandQueue = device.makeCommandQueue(), let commandBuffer = commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeBlitCommandEncoder() else {
        return nil
    }
    encoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: buffer, destinationOffset: 0, destinationBytesPerRow: bytesPerRow, destinationBytesPerImage: bytesPerRow * height)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
        return nil
    }
    var data = Data(bytes: buffer.contents(), count: bytesPerRow * height)
    if mirror {
        data.withUnsafeMutableBytes { bytes in
            let pixels = bytes.bindMemory(to: UInt32.self)
            for row in 0 ..< height {
                var left = row * width
                var right = left + width - 1
                while left < right {
                    pixels.swapAt(left, right)
                    left += 1
                    right -= 1
                }
            }
        }
    }
    guard let provider = CGDataProvider(data: data as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
        return nil
    }
    return UIImage(cgImage: image)
}

public func getChatWallpaperImage(context: AccountContext, peerId: EnginePeer.Id) -> Signal<(CGSize, UIImage?, UIImage?), NoError> {
    let themeSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
    |> map { sharedData -> PresentationThemeSettings in
        let themeSettings: PresentationThemeSettings
        if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        return themeSettings
    }
    
    let peerWallpaper = context.account.postbox.transaction { transaction -> TelegramWallpaper? in
        return (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData)?.wallpaper
    }
    
    return combineLatest(themeSettings, peerWallpaper)
    |> mapToSignal { themeSettings, peerWallpaper -> Signal<(TelegramWallpaper?, TelegramWallpaper?), NoError> in
        var currentColors = themeSettings.themeSpecificAccentColors[themeSettings.theme.index]
        if let colors = currentColors, colors.baseColor == .theme {
            currentColors = nil
        }
        
        let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeSettings.theme, accentColor: currentColors)] ?? themeSettings.themeSpecificChatWallpapers[themeSettings.theme.index])
        
        let dayWallpaper: TelegramWallpaper
        if let themeSpecificWallpaper = themeSpecificWallpaper {
            dayWallpaper = themeSpecificWallpaper
        } else {
            let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeSettings.theme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, preview: true) ?? defaultPresentationTheme
            dayWallpaper = theme.chat.defaultWallpaper
        }
        
        var nightWallpaper: TelegramWallpaper?
        
        let automaticTheme = themeSettings.automaticThemeSwitchSetting.theme
        let effectiveColors = themeSettings.themeSpecificAccentColors[automaticTheme.index]
        let nightThemeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: automaticTheme, accentColor: effectiveColors)] ?? themeSettings.themeSpecificChatWallpapers[automaticTheme.index])
        
        var preferredBaseTheme: TelegramBaseTheme?
        if let baseTheme = themeSettings.themePreferredBaseTheme[automaticTheme.index], [.night, .tinted].contains(baseTheme) {
            preferredBaseTheme = baseTheme
        } else {
            preferredBaseTheme = .night
        }
        
        let darkTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: automaticTheme, baseTheme: preferredBaseTheme, accentColor: effectiveColors?.color, bubbleColors: effectiveColors?.customBubbleColors ?? [], wallpaper: effectiveColors?.wallpaper, baseColor: effectiveColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
        
        if let nightThemeSpecificWallpaper = nightThemeSpecificWallpaper {
            nightWallpaper = nightThemeSpecificWallpaper
        } else {
            switch dayWallpaper {
            case .builtin, .color, .gradient:
                nightWallpaper = darkTheme.chat.defaultWallpaper
            case .file:
                if dayWallpaper.isPattern {
                    nightWallpaper = darkTheme.chat.defaultWallpaper
                } else {
                    nightWallpaper = nil
                }
            default:
                nightWallpaper = nil
            }
        }
        
        if let peerWallpaper {
            if case let .emoticon(emoticon) = peerWallpaper {
                return context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager)
                |> map { themes -> (TelegramWallpaper?, TelegramWallpaper?) in
                    if let theme = themes.first(where: { $0.emoticon?.strippedEmoji == emoticon.strippedEmoji }) {
                        if let dayMatch = theme.settings?.first(where: { $0.baseTheme == .classic || $0.baseTheme == .day }) {
                            if let peerDayWallpaper = dayMatch.wallpaper {
                                var peerNightWallpaper: TelegramWallpaper?
                                if let nightMatch = theme.settings?.first(where: { $0.baseTheme == .night || $0.baseTheme == .tinted }) {
                                    peerNightWallpaper = nightMatch.wallpaper
                                }
                                return (peerDayWallpaper, peerNightWallpaper)
                            } else {
                                return (dayWallpaper, nightWallpaper)
                            }
                        } else {
                            return (dayWallpaper, nightWallpaper)
                        }
                    } else {
                        return (dayWallpaper, nightWallpaper)
                    }
                }
            } else {
                return .single((peerWallpaper, nil))
            }
        } else {
            return .single((dayWallpaper, nightWallpaper))
        }
    }
    |> mapToSignal { dayWallpaper, nightWallpaper -> Signal<(CGSize, UIImage?, UIImage?), NoError> in
        return Signal { subscriber in
            Queue.mainQueue().async {
                let wallpaperRenderer = DrawingWallpaperRenderer(context: context, dayWallpaper: dayWallpaper, nightWallpaper: nightWallpaper)
                wallpaperRenderer.render { size, image, darkImage, mediaRect in
                    subscriber.putNext((size, image, darkImage))
                    subscriber.putCompletion()
                }
            }
            return EmptyDisposable
        }
    }
}

public func mediaEditorAnimatedStickerDurations(accountContext: AccountContext, entities: [CodableDrawingEntity]) -> Signal<[Double], NoError> {
    return mediaEditorAnimatedStickerDurations(postbox: accountContext.account.postbox, entities: entities.map { $0.entity })
}

public func mediaEditorAnimatedStickerDurations(entities: [CodableDrawingEntity], fileDuration: @escaping (TelegramMediaFile) -> Signal<Double?, NoError>) -> Signal<[Double], NoError> {
    return mediaEditorAnimatedStickerDurations(entities: entities.map { $0.entity }, fileDuration: fileDuration)
}

public func makeChatEditorImageComposition(accountContext: AccountContext, input: MediaEditorCompositionInput, values: MediaEditorValues, time: CMTime, maxOutputSide: CGFloat, completion: @escaping (UIImage?) -> Void) {
    makeChatEditorImageComposition(postbox: accountContext.account.postbox, input: input, values: values, time: time, maxOutputSide: maxOutputSide, completion: completion)
}

public func storyPreviewBandPlacement(containerSize: CGSize, safeInsets: UIEdgeInsets) -> (x: CGFloat, size: CGSize)? {
    if safeInsets.left == safeInsets.right {
        return nil
    }
    let bandWidth = containerSize.width - safeInsets.left - safeInsets.right
    if bandWidth <= 0.0 {
        return nil
    }
    var size = CGSize(width: bandWidth, height: floorToScreenPixels(bandWidth * 1.77778))
    if size.height > containerSize.height {
        size = CGSize(width: floorToScreenPixels(containerSize.height / 1.77778), height: containerSize.height)
    }
    let screenCenteredX = floorToScreenPixels((containerSize.width - size.width) / 2.0)
    if screenCenteredX >= safeInsets.left && screenCenteredX + size.width <= containerSize.width - safeInsets.right {
        return (screenCenteredX, size)
    }
    return (safeInsets.left + floorToScreenPixels((bandWidth - size.width) / 2.0), size)
}

public func storyControlsBandLayout(_ layout: ContainerViewLayout) -> (layout: ContainerViewLayout, originX: CGFloat)? {
    if layout.metrics.isTablet {
        return nil
    }
    guard let placement = storyPreviewBandPlacement(containerSize: layout.size, safeInsets: layout.safeInsets) else {
        return nil
    }
    var bandLayout = layout
    bandLayout.size = CGSize(width: placement.size.width, height: layout.size.height)
    bandLayout.safeInsets.left = 0.0
    bandLayout.safeInsets.right = 0.0
    bandLayout.intrinsicInsets.left = 0.0
    bandLayout.intrinsicInsets.right = 0.0
    bandLayout.reservedCorners = .none
    return (bandLayout, placement.x)
}
