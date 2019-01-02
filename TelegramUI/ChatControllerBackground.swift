import Foundation
import TelegramCore
import Display
import SwiftSignalKit
import Postbox

private var backgroundImageForWallpaper: (TelegramWallpaper, UIImage)?
private var serviceBackgroundColorForWallpaper: (TelegramWallpaper, UIColor)?

func chatControllerBackgroundImage(wallpaper: TelegramWallpaper, postbox: Postbox) -> UIImage? {
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
                    if let path = postbox.mediaBox.completedResourcePath(largest.resource) {
                        backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                    }
                }
            case let .file(file):
                if let path = postbox.mediaBox.completedResourcePath(file.file.resource) {
                    backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                }
        }
        if let backgroundImage = backgroundImage {
            backgroundImageForWallpaper = (wallpaper, backgroundImage)
        }
    }
    return backgroundImage
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
                        let data = (postbox.mediaBox.resourceData(largest.resource)
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
                        }).start(next: { next in
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
                    let data = (postbox.mediaBox.resourceData(file.file.resource)
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
                    }).start(next: { next in
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
