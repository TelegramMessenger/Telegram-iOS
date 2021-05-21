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
import GradientBackground

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
    let backgroundNode = ASImageNode()
    let imageNode = TransformImageNode()
    private var gradientNode: GradientBackgroundNode?
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

        var colors: [UInt32] = []
        if case let .gradient(value, _) = wallpaper {
            colors = value
        } else if case let .file(file) = wallpaper {
            colors = file.settings.colors
        } else if case let .color(color) = wallpaper {
            colors = [color]
        }
        if colors.count >= 3 {
            if let gradientNode = self.gradientNode {
                gradientNode.updateColors(colors: colors.map { UIColor(rgb: $0) })
            } else {
                let gradientNode = createGradientBackgroundNode()
                gradientNode.isUserInteractionEnabled = false
                self.gradientNode = gradientNode
                gradientNode.updateColors(colors: colors.map { UIColor(rgb: $0) })
                self.insertSubnode(gradientNode, aboveSubnode: self.backgroundNode)
            }

            self.backgroundNode.image = nil
        } else {
            if let gradientNode = self.gradientNode {
                self.gradientNode = nil
                gradientNode.removeFromSupernode()
            }

            if colors.count >= 2 {
                self.backgroundNode.image = generateGradientImage(size: CGSize(width: 80.0, height: 80.0), colors: colors.map(UIColor.init(rgb:)), locations: [0.0, 1.0], direction: .vertical)
                self.backgroundNode.backgroundColor = nil
            } else if colors.count >= 1 {
                self.backgroundNode.image = nil
                self.backgroundNode.backgroundColor = UIColor(rgb: colors[0])
            }
        }

        if let gradientNode = self.gradientNode {
            gradientNode.frame = CGRect(origin: CGPoint(), size: size)
            gradientNode.updateLayout(size: size, transition: .immediate)
        }
        
        let state: RadialStatusNodeState = selected ? .check(.white) : .none
        self.statusNode.transitionToState(state, animated: false, completion: {})
        
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - progressDiameter) / 2.0), y: floorToScreenPixels((size.height - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
        
        let corners = ImageCorners(radius: cornerRadius)
    
        if self.wallpaper != wallpaper {
            self.wallpaper = wallpaper
            switch wallpaper {
                case .builtin:
                    self.imageNode.alpha = 1.0
                    self.imageNode.setSignal(settingsBuiltinWallpaperImage(account: context.account))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .image(representations, _):
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: nil, resource: $0.resource)) })
                    self.imageNode.alpha = 10
                    self.imageNode.setSignal(wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad))
                  
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                case let .file(file):
                    let convertedRepresentations : [ImageRepresentationWithReference] = file.file.previewRepresentations.map {
                        ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: .slug(file.slug), resource: $0.resource))
                    }
                    
                    let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                    if wallpaper.isPattern {
                        var patternColors: [UIColor] = []
                        var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.5)
                        var patternIntensity: CGFloat = 0.5
                        if !file.settings.colors.isEmpty {
                            if let intensity = file.settings.intensity {
                                patternIntensity = CGFloat(intensity) / 100.0
                            }
                            patternColor = UIColor(rgb: file.settings.colors[0], alpha: patternIntensity)
                            patternColors.append(patternColor)
                            
                            if file.settings.colors.count >= 2 {
                                patternColors.append(UIColor(rgb: file.settings.colors[1], alpha: patternIntensity))
                            }
                        }

                        self.imageNode.alpha = CGFloat(file.settings.intensity ?? 50) / 100.0

                        self.arguments = PatternWallpaperArguments(colors: [.clear], rotation: nil, customPatternColor: UIColor(white: 0.0, alpha: 0.3))
                        imageSignal = patternWallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, mode: .thumbnail, autoFetchFullSize: true)
                    } else {
                        self.imageNode.alpha = 1.0

                        imageSignal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: .standalone(media: file.file), representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad)
                    }
                    self.imageNode.setSignal(imageSignal, attemptSynchronously: synchronousLoad)
                    
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 100, height: 100)
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: self.arguments))
                    apply()
                default:
                    break
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
