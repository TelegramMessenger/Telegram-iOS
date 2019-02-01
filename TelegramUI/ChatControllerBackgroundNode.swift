import Foundation
import TelegramCore
import Display
import SwiftSignalKit
import Postbox

private let motionAmount: CGFloat = 32.0

final class ChatBackgroundNode: ASDisplayNode {
    let contentNode: ASDisplayNode
    
    var motionEnabled: Bool = false {
        didSet {
            if oldValue != self.motionEnabled {
                if self.motionEnabled {
                    let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                    horizontal.minimumRelativeValue = motionAmount
                    horizontal.maximumRelativeValue = -motionAmount
                    
                    let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                    vertical.minimumRelativeValue = motionAmount
                    vertical.maximumRelativeValue = -motionAmount
                    
                    let group = UIMotionEffectGroup()
                    group.motionEffects = [horizontal, vertical]
                    self.contentNode.view.addMotionEffect(group)
                } else {
                    for effect in self.contentNode.view.motionEffects {
                        self.contentNode.view.removeMotionEffect(effect)
                    }
                }
                self.updateScale()
            }
        }
    }
    
    var image: UIImage? {
        didSet {
            self.contentNode.contents = self.image?.cgImage
        }
    }
    
    func updateScale() {
        if self.motionEnabled {
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            self.contentNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
        } else {
            self.contentNode.transform = CATransform3DIdentity
        }
    }
    
    override init() {
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = .scaleAspectFill
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
    }
    
    override func layout() {
        super.layout()
        self.contentNode.bounds = self.bounds
        self.contentNode.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.updateScale()
    }
}

private var backgroundImageForWallpaper: (TelegramWallpaper, Bool, UIImage)?
private var serviceBackgroundColorForWallpaper: (TelegramWallpaper, UIColor)?

func chatControllerBackgroundImage(wallpaper: TelegramWallpaper, postbox: Postbox) -> UIImage? {
    var backgroundImage: UIImage?
    if wallpaper == backgroundImageForWallpaper?.0, (wallpaper.settings?.blur ?? false) == backgroundImageForWallpaper?.1 {
        backgroundImage = backgroundImageForWallpaper?.2
    } else {
        switch wallpaper {
            case .builtin:
                if let filePath = frameworkBundle.path(forResource: "ChatWallpaperBuiltin0", ofType: "jpg") {
                    backgroundImage = UIImage(contentsOfFile: filePath)?.precomposed()
                }
            case let .color(color):
                backgroundImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor(rgb: UInt32(bitPattern: color)).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })
            case let .image(representations, settings):
                if let largest = largestImageRepresentation(representations) {
                    if settings.blur {
                        var image: UIImage?
                        let _ = postbox.mediaBox.cachedResourceRepresentation(largest.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                            if data.complete {
                                image = UIImage(contentsOfFile: data.path)?.precomposed()
                            }
                        })
                        backgroundImage = image
                    }
                    if backgroundImage == nil, let path = postbox.mediaBox.completedResourcePath(largest.resource) {
                        backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                    }
                }
            case let .file(file):
                if file.isPattern, let color = file.settings.color, let intensity = file.settings.intensity {
                    var image: UIImage?
                    let _ = postbox.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPatternWallpaperRepresentation(color: color, intensity: intensity), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                        if data.complete {
                            image = UIImage(contentsOfFile: data.path)?.precomposed()
                        }
                    })
                    backgroundImage = image
                } else {
                    if file.settings.blur {
                        var image: UIImage?
                        let _ = postbox.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                            if data.complete {
                                image = UIImage(contentsOfFile: data.path)?.precomposed()
                            }
                        })
                        backgroundImage = image
                    }
                    if backgroundImage == nil, let path = postbox.mediaBox.completedResourcePath(file.file.resource) {
                        backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                    }
                }
        }
        if let backgroundImage = backgroundImage {
            backgroundImageForWallpaper = (wallpaper, (wallpaper.settings?.blur ?? false), backgroundImage)
        }
    }
    return backgroundImage
}

private func serviceColor(for data: Signal<MediaResourceData, NoError>) -> Signal<UIColor, NoError> {
    return data
    |> mapToSignal { data -> Signal<UIColor, NoError> in
        if data.complete, let image = UIImage(contentsOfFile: data.path) {
            return serviceColor(from: .single(image))
        }
        return .complete()
    }
}

func serviceColor(from image: Signal<UIImage?, NoError>) -> Signal<UIColor, NoError> {
    return image
    |> mapToSignal { image -> Signal<UIColor, NoError> in
        if let image = image {
            let context = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, clear: false)
            context.withFlippedContext({ context in
                if let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                }
            })
            return .single(serviceColor(with: context.colorAt(CGPoint())))
        }
        return .complete()
    }
}

func serviceColor(with color: UIColor) -> UIColor {
    var hue:  CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
        if saturation > 0.0 {
            saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
        }
        brightness = max(0.0, brightness * 0.65)
        alpha = 0.4
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    return color
}

func chatServiceBackgroundColor(wallpaper: TelegramWallpaper, postbox: Postbox) -> Signal<UIColor, NoError> {
    if wallpaper == serviceBackgroundColorForWallpaper?.0, let color = serviceBackgroundColorForWallpaper?.1 {
        return .single(color)
    } else {
        switch wallpaper {
            case .builtin:
                return .single(UIColor(rgb: 0x748391, alpha: 0.45))
            case let .color(color):
                return .single(serviceColor(with: UIColor(rgb: UInt32(bitPattern: color))))
            case let .image(representations, _):
                if let largest = largestImageRepresentation(representations) {
                    return Signal<UIColor, NoError> { subscriber in
                        let fetch = postbox.mediaBox.fetchedResource(largest.resource, parameters: nil).start()
                        let data = serviceColor(for: postbox.mediaBox.resourceData(largest.resource)).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        return ActionDisposable {
                            fetch.dispose()
                            data.dispose()
                        }
                    }
                    |> afterNext { color in
                        serviceBackgroundColorForWallpaper = (wallpaper, color)
                    }
                } else {
                    return .single(UIColor(rgb: 0x000000, alpha: 0.3))
                }
            case let .file(file):
                if file.isPattern {
                    if let color = file.settings.color {
                        return .single(serviceColor(with: UIColor(rgb: UInt32(bitPattern: color))))
                    } else {
                        return .single(UIColor(rgb: 0x000000, alpha: 0.3))
                    }
                } else {
                    return Signal<UIColor, NoError> { subscriber in
                        let fetch = postbox.mediaBox.fetchedResource(file.file.resource, parameters: nil).start()
                        let data = serviceColor(for: postbox.mediaBox.resourceData(file.file.resource)).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        return ActionDisposable {
                            fetch.dispose()
                            data.dispose()
                        }
                    }
                    |> afterNext { color in
                        serviceBackgroundColorForWallpaper = (wallpaper, color)
                    }
                }
        }
    }
}

