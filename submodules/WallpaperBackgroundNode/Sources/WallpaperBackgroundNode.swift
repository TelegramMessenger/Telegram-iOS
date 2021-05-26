import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GradientBackground
import TelegramPresentationData
import SyncCore
import TelegramCore
import AccountContext
import SwiftSignalKit
import WallpaperResources
import Postbox

private let motionAmount: CGFloat = 32.0

public final class WallpaperBackgroundNode: ASDisplayNode {
    private let context: AccountContext
    
    private let contentNode: ASDisplayNode
    private var gradientBackgroundNode: GradientBackgroundNode?
    private let patternImageNode: TransformImageNode

    private var validLayout: CGSize?
    private var wallpaper: TelegramWallpaper?

    private let patternImageDisposable = MetaDisposable()
    
    private var motionEnabled: Bool = false {
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
                if !self.frame.isEmpty {
                    self.updateScale()
                }
            }
        }
    }
    
    public var rotation: CGFloat = 0.0 {
        didSet {
            var fromValue: CGFloat = 0.0
            if let value = (self.layer.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.floatValue {
                fromValue = CGFloat(value)
            }
            self.contentNode.layer.transform = CATransform3DMakeRotation(self.rotation, 0.0, 0.0, 1.0)
            self.contentNode.layer.animateRotation(from: fromValue, to: self.rotation, duration: 0.3)
        }
    }
    
    private var imageContentMode: UIView.ContentMode {
        didSet {
            self.contentNode.contentMode = self.imageContentMode
        }
    }
    
    private func updateScale() {
        if self.motionEnabled {
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            self.contentNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
        } else {
            self.contentNode.transform = CATransform3DIdentity
        }
    }
    
    public init(context: AccountContext) {
        self.context = context
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = self.imageContentMode

        self.patternImageNode = TransformImageNode()
        self.patternImageNode.layer.compositingFilter = "softLightBlendMode"
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
        self.addSubnode(self.patternImageNode)
    }

    deinit {
        self.patternImageDisposable.dispose()
    }

    public func update(wallpaper: TelegramWallpaper) {
        let previousWallpaper = self.wallpaper
        if self.wallpaper == wallpaper {
            return
        }
        self.wallpaper = wallpaper

        var gradientColors: [UInt32] = []
        var gradientAngle: Int32 = 0

        if case let .color(color) = wallpaper {
            gradientColors = [color]
        } else if case let .gradient(colors, settings) = wallpaper {
            gradientColors = colors
            gradientAngle = settings.rotation ?? 0
        } else if case let .file(_, _, _, _, isPattern, _, _, _, settings) = wallpaper, isPattern {
            gradientColors = settings.colors
            gradientAngle = settings.rotation ?? 0
        }

        if gradientColors.count >= 3 {
            if self.gradientBackgroundNode == nil {
                let gradientBackgroundNode = createGradientBackgroundNode()
                self.gradientBackgroundNode = gradientBackgroundNode
                self.insertSubnode(gradientBackgroundNode, aboveSubnode: self.contentNode)
                gradientBackgroundNode.addSubnode(self.patternImageNode)
            }
            self.gradientBackgroundNode?.updateColors(colors: gradientColors.map { color -> UIColor in
                return UIColor(rgb: color)
            })

            self.contentNode.backgroundColor = nil
            self.contentNode.contents = nil
            self.motionEnabled = false
        } else {
            if let gradientBackgroundNode = self.gradientBackgroundNode {
                self.gradientBackgroundNode = nil
                gradientBackgroundNode.removeFromSupernode()
                self.insertSubnode(self.patternImageNode, aboveSubnode: self.contentNode)
            }

            self.motionEnabled = wallpaper.settings?.motion ?? false

            if gradientColors.count >= 2 {
                self.contentNode.backgroundColor = nil
                self.contentNode.contents = generateImage(CGSize(width: 100.0, height: 200.0), rotatedContext: { size, context in
                    let gradientColors = [UIColor(rgb: gradientColors[0]).cgColor, UIColor(rgb: gradientColors[1]).cgColor] as CFArray

                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.rotate(by: CGFloat(gradientAngle) * CGFloat.pi / 180.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                })?.cgImage
            } else if gradientColors.count >= 1 {
                self.contentNode.backgroundColor = UIColor(rgb: gradientColors[0])
                self.contentNode.contents = nil
            } else {
                self.contentNode.backgroundColor = .white
                self.contentNode.contents = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: self.context.sharedContext.accountManager.mediaBox, knockoutMode: false)?.cgImage
                self.contentNode.isHidden = false
            }
        }

        switch wallpaper {
        case let .file(id, _, _, _, isPattern, _, _, file, settings) where isPattern:
            var updated = true
            if let previousWallpaper = previousWallpaper {
                switch previousWallpaper {
                case let .file(previousId, _, _, _, previousIsPattern, _, _, previousFile, _):
                    if id == previousId && isPattern == previousIsPattern && file.id == previousFile.id {
                        updated = false
                    }
                default:
                    break
                }
            }

            if updated {
                func reference(for resource: MediaResource, media: Media, message: Message?) -> MediaResourceReference {
                    if let message = message {
                        return .media(media: .message(message: MessageReference(message), media: media), resource: resource)
                    }
                    return .wallpaper(wallpaper: nil, resource: resource)
                }

                var convertedRepresentations: [ImageRepresentationWithReference] = []
                for representation in file.previewRepresentations {
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: representation.resource, media: file, message: nil)))
                }
                let dimensions = file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: reference(for: file.resource, media: file, message: nil)))

                let signal = patternWallpaperImage(account: self.context.account, accountManager: self.context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: true)
                self.patternImageNode.setSignal(signal)
            }
            self.patternImageNode.alpha = CGFloat(settings.intensity ?? 50) / 100.0
            self.patternImageNode.isHidden = false
        default:
            self.patternImageNode.isHidden = true
        }

        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = size

        transition.updatePosition(node: self.contentNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(), size: size))

        if let gradientBackgroundNode = self.gradientBackgroundNode {
            transition.updateFrame(node: gradientBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            gradientBackgroundNode.updateLayout(size: size, transition: transition)
        }

        let makeImageLayout = self.patternImageNode.asyncLayout()
        let applyImage = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: PatternWallpaperArguments(colors: [.clear], rotation: nil, customPatternColor: .black, preview: false)))
        applyImage()
        transition.updateFrame(node: self.patternImageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }

    public func animateEvent(transition: ContainedViewLayoutTransition) {
        self.gradientBackgroundNode?.animateEvent(transition: transition)
    }
}
