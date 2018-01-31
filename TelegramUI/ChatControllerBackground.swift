import Foundation
import TelegramCore
import Display
import Postbox

private var backgroundImageForWallpaper: (TelegramWallpaper, UIImage)?

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
        }
        if let backgroundImage = backgroundImage {
            backgroundImageForWallpaper = (wallpaper, backgroundImage)
        }
    }
    return backgroundImage
}
