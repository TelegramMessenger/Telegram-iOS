import Foundation
import TelegramCore
import Display
import SwiftSignalKit
import Postbox

final class ChatBackgroundNode: ASDisplayNode {
    let contentNode: ASDisplayNode
    
    var parallaxEnabled: Bool = false {
        didSet {
            if oldValue != self.parallaxEnabled {
                if self.parallaxEnabled {
                    let amount = 16.0
                    
                    let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                    horizontal.minimumRelativeValue = -amount
                    horizontal.maximumRelativeValue = amount
                    
                    let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                    vertical.minimumRelativeValue = -amount
                    vertical.maximumRelativeValue = amount
                    
                    let group = UIMotionEffectGroup()
                    group.motionEffects = [horizontal, vertical]
                    
                    self.contentNode.view.addMotionEffect(group)
                } else {
                    for effect in self.contentNode.view.motionEffects {
                        self.contentNode.view.removeMotionEffect(effect)
                    }
                }
            }
        }
    }
    
    var image: UIImage? {
        didSet {
            self.contentNode.contents = self.image?.cgImage
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
        self.contentNode.frame = self.bounds
    }
}

private var backgroundImageForWallpaper: (TelegramWallpaper, UIImage)?
private var serviceBackgroundColorForWallpaper: (TelegramWallpaper, UIColor)?

func chatControllerBackgroundImage(wallpaper: TelegramWallpaper, mode: PresentationWallpaperMode = .still, postbox: Postbox) -> UIImage? {
    var backgroundImage: UIImage?
    if wallpaper == backgroundImageForWallpaper?.0 {
        backgroundImage = backgroundImageForWallpaper?.1
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
            case let .image(representations):
                if let largest = largestImageRepresentation(representations) {
                    if case .blurred = mode {
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
                if case .blurred = mode {
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
        if let backgroundImage = backgroundImage {
            backgroundImageForWallpaper = (wallpaper, backgroundImage)
        }
    }
    return backgroundImage
}

private func serviceColor(for data: Signal<MediaResourceData, NoError>) -> Signal<UIColor, NoError> {
    return data
    |> mapToSignal { data -> Signal<UIColor, NoError> in
        if data.complete {
            let image = UIImage(contentsOfFile: data.path)
            let context = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, clear: false)
            context.withFlippedContext({ context in
                if let cgImage = image?.cgImage {
                    context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                }
            })
            var color = context.colorAt(CGPoint())
            
            var hue:  CGFloat = 0.0
            var saturation: CGFloat = 0.0
            var brightness: CGFloat = 0.0
            var alpha: CGFloat = 0.0
            if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
                saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
                brightness = max(0.0, brightness * 0.65)
                alpha = 0.4
                color = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
            }
            return .single(color)
        }
        return .complete()
    }
}

func chatServiceBackgroundColor(wallpaper: TelegramWallpaper, postbox: Postbox) -> Signal<UIColor, NoError> {
    if wallpaper == serviceBackgroundColorForWallpaper?.0, let color = serviceBackgroundColorForWallpaper?.1 {
        return .single(color)
    } else {
        switch wallpaper {
            case .builtin, .color:
                return .single(UIColor(rgb: 0x000000, alpha: 0.3))
            case let .image(representations):
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

func chatBackgroundContrastColor(wallpaper: TelegramWallpaper, postbox: Postbox) -> Signal<UIColor, NoError> {
   // if wallpaper == serviceBackgroundColorForWallpaper?.0, let color = serviceBackgroundColorForWallpaper?.1 {
    //    return .single(color)
   // } else {
        switch wallpaper {
            case .builtin:
                return .single(UIColor(rgb: 0x888f96))
            case let .color(color):
                return .single(contrastingColor(for: UIColor(rgb: UInt32(bitPattern: color))))
            case let .image(representations):
                if let largest = largestImageRepresentation(representations) {
                    return Signal<UIColor, NoError> { subscriber in
                        let fetch = postbox.mediaBox.fetchedResource(largest.resource, parameters: nil).start()
                        let data = backgroundContrastColor(for: postbox.mediaBox.resourceData(largest.resource)).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        return ActionDisposable {
                            fetch.dispose()
                            data.dispose()
                        }
                    }
                     //   |> afterNext { color in
                    //        serviceBackgroundColorForWallpaper = (wallpaper, color)
                    //}
                } else {
                    return .single(.white)
                }
        case let .file(file):
            return Signal<UIColor, NoError> { subscriber in
                let fetch = postbox.mediaBox.fetchedResource(file.file.resource, parameters: nil).start()
                let data = backgroundContrastColor(for: postbox.mediaBox.resourceData(file.file.resource)).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                })
                return ActionDisposable {
                    fetch.dispose()
                    data.dispose()
                }
                }
           // |> afterNext { color in
            //        serviceBackgroundColorForWallpaper = (wallpaper, color)
            //}
        }
  //  }
}

private func backgroundContrastColor(for data: Signal<MediaResourceData, NoError>) -> Signal<UIColor, NoError> {
    return data
    |> mapToSignal { data -> Signal<UIColor, NoError> in
        if data.complete {
            let image = UIImage(contentsOfFile: data.path)
            let context = DrawingContext(size: CGSize(width: 128.0, height: 32.0), scale: 1.0, clear: false)
            context.withFlippedContext({ context in
                if let image = image, let cgImage = image.cgImage {
                    let size = image.size.aspectFilled(CGSize(width: 128.0, height: 128.0))
                    context.draw(cgImage, in: CGRect(x: floor((128.0 - size.width) / 2.0), y: 0.0, width: size.width, height: size.height))
                }
            })
            let finalContext = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, clear: false)
            finalContext.withFlippedContext({ c in
                if let cgImage = context.generateImage()?.cgImage {
                    c.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                }
            })
            let color = finalContext.colorAt(CGPoint())
            return .single(contrastingColor(for: color))
        }
        return .complete()
    }
}

private func contrastingColor(for color: UIColor) -> UIColor {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var luminance: CGFloat = 0.0
    var alpha: CGFloat = 0.0;
    
    if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
    } else if color.getWhite(&luminance, alpha: &alpha) {
    }
    
    if luminance > 0.6 {
        return .black
    } else {
        return .white
    }
}
