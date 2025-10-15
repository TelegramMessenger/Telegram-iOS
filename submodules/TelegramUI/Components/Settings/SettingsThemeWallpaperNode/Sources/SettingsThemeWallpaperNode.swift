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
import GradientBackground
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode

private func whiteColorImage(theme: PresentationTheme, color: UIColor) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single({ arguments in
        guard let context = DrawingContext(size: arguments.drawingSize, clear: true) else {
            return nil
        }
        
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

private let blackColorImage: UIImage? = {
    guard let context = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, opaque: true, clear: false) else {
        return nil
    }
    context.withContext { c in
        c.setFillColor(UIColor.black.cgColor)
        c.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)))
    }
    return context.generateImage()
}()

public final class SettingsThemeWallpaperNode: ASDisplayNode {
    public var wallpaper: TelegramWallpaper?
    private var arguments: PatternWallpaperArguments?
    
    private var emojiFile: TelegramMediaFile?
    
    public let buttonNode = HighlightTrackingButtonNode()
    public let backgroundNode = ASImageNode()
    public let imageNode = TransformImageNode()
    private var gradientNode: GradientBackgroundNode?
    private let statusNode: RadialStatusNode
    
    private let emojiContainerNode: ASDisplayNode
    private let emojiImageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private let stickerFetchedDisposable = MetaDisposable()
    
    public var pressed: (() -> Void)?

    private let displayLoading: Bool
    private var isSelected: Bool = false
    private var isLoaded: Bool = false

    private let isLoadedDisposable = MetaDisposable()
         
    public init(displayLoading: Bool = false, overlayBackgroundColor: UIColor = UIColor(white: 0.0, alpha: 0.3)) {
        self.displayLoading = displayLoading
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.2), enableBlur: true)
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.emojiContainerNode = ASDisplayNode()
        self.emojiContainerNode.isUserInteractionEnabled = false
        self.emojiImageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.statusNode)
        
        self.addSubnode(self.emojiContainerNode)
//        self.emojiContainerNode.addSubnode(self.emojiNode)
        self.emojiContainerNode.addSubnode(self.emojiImageNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        var firstTime = true
        self.emojiImageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    strongSelf.emojiImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            firstTime = false
        }
    }

    deinit {
        self.isLoadedDisposable.dispose()
        self.stickerFetchedDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {

    }
    
    public func setSelected(_ selected: Bool, animated: Bool = false) {
        if self.isSelected != selected {
            self.isSelected = selected

            self.updateStatus(animated: animated)
        }
    }

    private func updateIsLoaded(isLoaded: Bool, animated: Bool) {
        if self.isLoaded != isLoaded {
            self.isLoaded = isLoaded
            self.updateStatus(animated: animated)
        }
    }

    private func updateStatus(animated: Bool) {
        if self.isSelected {
            if self.isLoaded || !displayLoading {
                self.statusNode.transitionToState(.check(.white), animated: animated, completion: {})
            } else {
                self.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true), animated: animated, completion: {})
            }
        } else {
            self.statusNode.transitionToState(.none, animated: animated, completion: {})
        }
    }
    
    public func setOverlayBackgroundColor(_ color: UIColor) {
        self.statusNode.backgroundNodeColor = color
    }
    
    public func setWallpaper(context: AccountContext, theme: PresentationTheme? = nil, wallpaper: TelegramWallpaper, isEmpty: Bool = false, emojiFile: TelegramMediaFile? = nil, selected: Bool, size: CGSize, cornerRadius: CGFloat = 0.0, synchronousLoad: Bool = false) {
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)

        var colors: [UInt32] = []
        var intensity: CGFloat = 0.5
        if case let .gradient(gradient) = wallpaper {
            colors = gradient.colors
        } else if case let .file(file) = wallpaper {
            colors = file.settings.colors
            intensity = CGFloat(file.settings.intensity ?? 50) / 100.0
        } else if case let .color(color) = wallpaper {
            colors = [color]
        }
        let isBlack = UIColor.average(of: colors.map(UIColor.init(rgb:))).hsb.b <= 0.01
        if colors.count >= 3 {
            if let gradientNode = self.gradientNode {
                gradientNode.updateColors(colors: colors.map { UIColor(rgb: $0) })
            } else {
                let gradientNode = createGradientBackgroundNode()
                gradientNode.isUserInteractionEnabled = false
                self.gradientNode = gradientNode
                gradientNode.updateColors(colors: colors.map { UIColor(rgb: $0) })
                self.insertSubnode(gradientNode, belowSubnode: self.imageNode)
            }

            if intensity < 0.0 {
                self.imageNode.layer.compositingFilter = nil
            } else {
                if isBlack {
                    self.imageNode.layer.compositingFilter = nil
                } else {
                    self.imageNode.layer.compositingFilter = "softLightBlendMode"
                }
            }
            self.backgroundNode.image = nil
        } else {
            if let gradientNode = self.gradientNode {
                self.gradientNode = nil
                gradientNode.removeFromSupernode()
            }

            if intensity < 0.0 {
                self.imageNode.layer.compositingFilter = nil
            } else {
                if isBlack {
                    self.imageNode.layer.compositingFilter = nil
                } else {
                    self.imageNode.layer.compositingFilter = "softLightBlendMode"
                }
            }

            if colors.count >= 2 {
                self.backgroundNode.image = generateGradientImage(size: CGSize(width: 80.0, height: 80.0), colors: colors.map(UIColor.init(rgb:)), locations: [0.0, 1.0], direction: .vertical)
                self.backgroundNode.backgroundColor = nil
            } else if colors.count >= 1 {
                self.backgroundNode.image = nil
                self.backgroundNode.backgroundColor = UIColor(rgb: colors[0])
            }
        }
        
        if isEmpty, let theme {
            self.backgroundNode.image = nil
            self.backgroundNode.backgroundColor = theme.list.mediaPlaceholderColor
        }

        if let gradientNode = self.gradientNode {
            gradientNode.frame = CGRect(origin: CGPoint(), size: size)
            gradientNode.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
        }
        
        let progressDiameter: CGFloat = 50.0
        self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - progressDiameter) / 2.0), y: floorToScreenPixels((size.height - progressDiameter) / 2.0), width: progressDiameter, height: progressDiameter)
        
        let corners = ImageCorners(radius: cornerRadius)
    
        if self.wallpaper != wallpaper && !isEmpty {
            self.wallpaper = wallpaper
            switch wallpaper {
                case .builtin:
                    self.imageNode.alpha = 1.0
                    self.imageNode.setSignal(settingsBuiltinWallpaperImage(account: context.account, thumbnail: true))
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: CGSize(), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                    self.isLoadedDisposable.set(nil)
                    self.updateIsLoaded(isLoaded: true, animated: false)
                case let .image(representations, _):
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: nil, resource: $0.resource)) })
                    self.imageNode.alpha = 1.0
                    self.imageNode.setSignal(wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, synchronousLoad: synchronousLoad))
                  
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: corners, imageSize: largestImageRepresentation(representations)!.dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
                    apply()
                    self.isLoadedDisposable.set(nil)
                    self.updateIsLoaded(isLoaded: true, animated: false)
                case let .file(file):
                    let convertedRepresentations : [ImageRepresentationWithReference] = file.file.previewRepresentations.map {
                        ImageRepresentationWithReference(representation: $0, reference: .wallpaper(wallpaper: .slug(file.slug), resource: $0.resource))
                    }

                    let fullDimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                    let convertedFullRepresentations = [ImageRepresentationWithReference(representation: .init(dimensions: fullDimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false), reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource))]
                    
                    let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                    if wallpaper.isPattern {
                        var patternIntensity: CGFloat = 0.5
                        if !file.settings.colors.isEmpty {
                            if let intensity = file.settings.intensity {
                                patternIntensity = CGFloat(intensity) / 100.0
                            }
                        }

                        if patternIntensity < 0.0 {
                            self.imageNode.alpha = 1.0
                            self.arguments = PatternWallpaperArguments(colors: [.clear], rotation: nil, customPatternColor: UIColor(white: 0.0, alpha: 1.0 + patternIntensity))
                        } else {
                            self.imageNode.alpha = CGFloat(file.settings.intensity ?? 50) / 100.0
                            let isLight = UIColor.average(of: file.settings.colors.map(UIColor.init(rgb:))).hsb.b > 0.3
                            self.arguments = PatternWallpaperArguments(colors: [.clear], rotation: nil, customPatternColor: isLight ? .black : .white)
                        }
                        imageSignal = patternWallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, mode: .thumbnail, autoFetchFullSize: true)
                        |> mapToSignal { generatorAndRects -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> in
                            if let (generator, _) = generatorAndRects {
                                return .single(generator)
                            } else {
                                return .complete()
                            }
                        }

                        let anyStatus = combineLatest(queue: .mainQueue(),
                            context.account.postbox.mediaBox.resourceStatus(convertedFullRepresentations[0].reference.resource, approximateSynchronousValue: true),
                            context.sharedContext.accountManager.mediaBox.resourceStatus(convertedFullRepresentations[0].reference.resource, approximateSynchronousValue: true)
                        )
                        |> map { a, b -> Bool in
                            switch a {
                            case .Local:
                                return true
                            default:
                                break
                            }
                            switch b {
                            case .Local:
                                return true
                            default:
                                break
                            }
                            return false
                        }
                        |> distinctUntilChanged

                        self.updateIsLoaded(isLoaded: false, animated: false)
                        self.isLoadedDisposable.set((anyStatus
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.updateIsLoaded(isLoaded: value, animated: true)
                        }))
                    } else {
                        self.imageNode.alpha = 1.0

                        imageSignal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: .standalone(media: file.file), representations: convertedRepresentations, thumbnail: true, autoFetchFullSize: true, blurred: file.settings.blur, synchronousLoad: synchronousLoad)

                        self.updateIsLoaded(isLoaded: true, animated: false)
                        self.isLoadedDisposable.set(nil)
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
                case .builtin, .color, .gradient, .emoticon:
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

        self.setSelected(selected, animated: false)
        
        
        self.emojiContainerNode.frame = self.backgroundNode.frame
        
        var emojiFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 42.0) / 2.0), y: 98.0), size: CGSize(width: 42.0, height: 42.0))
        if isEmpty {
            emojiFrame = emojiFrame.insetBy(dx: 3.0, dy: 3.0)
        }
        if let file = emojiFile, self.emojiFile?.id != emojiFile?.id {
            self.emojiFile = file
            
            let imageApply = self.emojiImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: emojiFrame.size, boundingSize: emojiFrame.size, intrinsicInsets: UIEdgeInsets()))
            imageApply()
            self.emojiImageNode.setSignal(chatMessageStickerPackThumbnail(postbox: context.account.postbox, resource: file.resource, animated: true, nilIfEmpty: true))
            self.emojiImageNode.frame = emojiFrame
            
            let animatedStickerNode: AnimatedStickerNode
            if let current = self.animatedStickerNode {
                animatedStickerNode = current
            } else {
                animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                animatedStickerNode.started = { [weak self] in
                    self?.emojiImageNode.isHidden = true
                }
                self.animatedStickerNode = animatedStickerNode
                self.emojiContainerNode.addSubnode(animatedStickerNode)
                let pathPrefix = context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: file.resource), width: 128, height: 128, playbackMode: .still(.start), mode: .direct(cachePathPrefix: pathPrefix))
                
                animatedStickerNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            }
            animatedStickerNode.autoplay = true
            animatedStickerNode.visibility = true
            
            self.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)).start())
            
//            let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
//            self.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: file.immediateThumbnailData, size: emojiFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency, imageSize: thumbnailDimensions.cgSize)
//            self.placeholderNode.frame = emojiFrame
        }
        
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.frame = emojiFrame
            animatedStickerNode.updateLayout(size: emojiFrame.size)
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}
