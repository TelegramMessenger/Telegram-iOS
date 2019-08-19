import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import WallpaperResources

private func whiteColorImage(theme: PresentationTheme) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single({ arguments in
        let context = DrawingContext(size: arguments.drawingSize, clear: true)
        
        context.withFlippedContext { c in
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(origin: CGPoint(), size: arguments.drawingSize))
            
            let lineWidth: CGFloat = 1.0
            c.setLineWidth(lineWidth)
            c.setStrokeColor(theme.list.controlSecondaryColor.cgColor)
            c.stroke(CGRect(origin: CGPoint(), size: arguments.drawingSize).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
        }
        
        return context
    })
}

final class SettingsThemeWallpaperNode: ASDisplayNode {
    private var wallpaper: TelegramWallpaper?
    private var color: UIColor?
    
    let buttonNode = HighlightTrackingButtonNode()
    let backgroundNode = ASDisplayNode()
    let imageNode = TransformImageNode()
    private let statusNode: RadialStatusNode
    
    var pressed: (() -> Void)?
    
    init(overlayBackgroundColor: UIColor = UIColor(white: 0.0, alpha: 0.3)) {
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: overlayBackgroundColor)
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.statusNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        let state: RadialStatusNodeState = selected ? .check(.white) : .none
        self.statusNode.transitionToState(state, animated: animated, completion: {})
    }
    
    func setWallpaper(context: AccountContext, wallpaper: TelegramWallpaper, selected: Bool, size: CGSize, cornerRadius: CGFloat = 0.0, synchronousLoad: Bool = false) {
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let state: RadialStatusNodeState = selected ? .check(.white) : .none
        self.statusNode.transitionToState(state, animated: false, completion: {})
        
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - progressDiameter) / 2.0), y: floorToScreenPixels((size.height - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
        
        let corners = ImageCorners(radius: cornerRadius)
    
        if self.wallpaper != wallpaper {
            self.wallpaper = wallpaper
            switch wallpaper {
                case .builtin:
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    self.imageNode.setSignal(settingsBuiltinWallpaperImage(account: context.account))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .color(color):
                    if color == 0x00ffffff {
                        self.imageNode.isHidden = false
                        self.backgroundNode.isHidden = true
                        self.imageNode.setSignal(whiteColorImage(theme: context.sharedContext.currentPresentationData.with { $0 }.theme))
                        let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                        apply()
                    } else {
                        self.imageNode.isHidden = true
                        self.backgroundNode.isHidden = false
                        self.backgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: color))
                    }
                case let .image(representations, _):
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource)) })
                    self.imageNode.setSignal(wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad))
                  
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    self.imageNode.isHidden = false
                    
                    let convertedRepresentations : [ImageRepresentationWithReference] = file.file.previewRepresentations.map {
                        ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource))
                    }
                    
                    let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                    if file.isPattern {
                        self.backgroundNode.isHidden = false
                        
                        var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.5)
                        var patternIntensity: CGFloat = 0.5
                        if let color = file.settings.color {
                            if let intensity = file.settings.intensity {
                                patternIntensity = CGFloat(intensity) / 100.0
                            }
                            patternColor = UIColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
                        }
                        self.backgroundNode.backgroundColor = patternColor
                        self.color = patternColor
                        imageSignal = patternWallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, mode: .thumbnail, autoFetchFullSize: true)
                    } else {
                        self.backgroundNode.isHidden = true
                        
                        imageSignal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: .standalone(media: file.file), representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad)
                    }
                    self.imageNode.setSignal(imageSignal, attemptSynchronously: synchronousLoad)
                    
                    let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets(), emptyColor: self.color))
                    apply()
            }
        } else if let wallpaper = self.wallpaper {
            switch wallpaper {
                case .builtin, .color:
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .image(representations, _):
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets(), emptyColor: self.color))
                    apply()
            }
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}
