import Foundation
import UIKit
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
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CIContext(mtlDevice: device, options: [:])
    guard var ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace]) else {
        return nil
    }
    let transform: CGAffineTransform
    if mirror {
        transform = CGAffineTransform(-1.0, 0.0, 0.0, -1.0, ciImage.extent.width, ciImage.extent.height)
    } else {
        transform = CGAffineTransform(1.0, 0.0, 0.0, -1.0, 0.0, ciImage.extent.height)
    }
    ciImage = ciImage.transformed(by: transform)
    guard let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
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
