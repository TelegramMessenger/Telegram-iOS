import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class SettingsThemeWallpaperNode: ASDisplayNode {
    private var wallpaper: TelegramWallpaper?
    
    let buttonNode = HighlightTrackingButtonNode()
    let backgroundNode = ASDisplayNode()
    let imageNode = TransformImageNode()
    
    var pressed: (() -> Void)?
    
    override init() {
        self.imageNode.contentAnimations = [.subsequentUpdates]
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func setWallpaper(account: Account, wallpaper: TelegramWallpaper, size: CGSize) {
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        
        if self.wallpaper != wallpaper {
            self.wallpaper = wallpaper
            switch wallpaper {
                case .builtin:
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    self.imageNode.setSignal(settingsBuiltinWallpaperImage(account: account))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .color(color):
                    self.imageNode.isHidden = true
                    self.backgroundNode.isHidden = false
                    self.backgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: color))
                case let .image(representations):
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource)) })
                    self.imageNode.setSignal(chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations, autoFetchFullSize: true))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    
                    var convertedRepresentations: [ImageRepresentationWithReference] = []
                    for representation in file.file.previewRepresentations {
                        convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .standalone(resource: representation.resource)))
                    }
                    let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .standalone(resource: file.file.resource)))
                    self.imageNode.setSignal(chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations, autoFetchFullSize: true))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
            }
        } else if let wallpaper = self.wallpaper {
            switch wallpaper {
                case .builtin:
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case .color:
                    break
                case let .image(representations):
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    var convertedRepresentations: [ImageRepresentationWithReference] = []
                    for representation in file.file.previewRepresentations {
                        convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .standalone(resource: representation.resource)))
                    }
                    let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .standalone(resource: file.file.resource)))
                    self.imageNode.setSignal(chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations, autoFetchFullSize: true))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
            }
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}
