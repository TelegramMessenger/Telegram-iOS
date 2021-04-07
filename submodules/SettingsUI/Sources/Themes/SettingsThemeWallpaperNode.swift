import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import WallpaperResources

private func whiteColorImage(theme: PresentationTheme, color: UIColor) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single({ arguments in
        let context = DrawingContext(size: arguments.drawingSize, clear: true)
        
        context.withFlippedContext { c in
            c.setFillColor(color.cgColor)
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
    var wallpaper: TelegramWallpaper?
    private var arguments: PatternWallpaperArguments?
    
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
    
    func setOverlayBackgroundColor(_ color: UIColor) {
        self.statusNode.backgroundNodeColor = color
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
                    let theme = context.sharedContext.currentPresentationData.with { $0 }.theme
                    let uiColor = UIColor(rgb: color)
                    if uiColor.distance(to: theme.list.itemBlocksBackgroundColor) < 200 {
                        self.imageNode.isHidden = false
                        self.backgroundNode.isHidden = true
                        self.imageNode.setSignal(whiteColorImage(theme: theme, color: uiColor))
                        let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                        apply()
                    } else {
                        self.imageNode.isHidden = true
                        self.backgroundNode.isHidden = false
                        self.backgroundNode.backgroundColor = UIColor(rgb: color)
                    }
                case let .gradient(topColor, bottomColor, _):
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    self.imageNode.setSignal(gradientImage([UIColor(rgb: topColor), UIColor(rgb: bottomColor)]))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .image(representations, _):
                    self.imageNode.isHidden = false
                    self.backgroundNode.isHidden = true
                    
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: nil, resource: $0.resource)) })
                    self.imageNode.setSignal(wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad))
                  
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    self.imageNode.isHidden = false
                    
                    let convertedRepresentations : [ImageRepresentationWithReference] = file.file.previewRepresentations.map {
                        ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: .slug(file.slug), resource: $0.resource))
                    }
                    
                    let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                    if wallpaper.isPattern {
                        self.backgroundNode.isHidden = false
                        
                        var patternColors: [UIColor] = []
                        var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.5)
                        var patternIntensity: CGFloat = 0.5
                        if let color = file.settings.color {
                            if let intensity = file.settings.intensity {
                                patternIntensity = CGFloat(intensity) / 100.0
                            }
                            patternColor = UIColor(rgb: color, alpha: patternIntensity)
                            patternColors.append(patternColor)
                            
                            if let bottomColor = file.settings.bottomColor {
                                patternColors.append(UIColor(rgb: bottomColor, alpha: patternIntensity))
                            }
                        }
                        
                        self.backgroundNode.backgroundColor = patternColor
                        self.arguments = PatternWallpaperArguments(colors: patternColors, rotation: file.settings.rotation)
                        imageSignal = patternWallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, mode: .thumbnail, autoFetchFullSize: true)
                    } else {
                        self.backgroundNode.isHidden = true
                        
                        imageSignal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: .standalone(media: file.file), representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad)
                    }
                    self.imageNode.setSignal(imageSignal, attemptSynchronously: synchronousLoad)
                    
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 100, height: 100)
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: self.arguments))
                    apply()
            }
        } else if let wallpaper = self.wallpaper {
            switch wallpaper {
                case .builtin, .color, .gradient:
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .image(representations, _):
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 100, height: 100)
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: self.arguments))
                    apply()
            }
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}
