import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AnimationUI
import AppBundle
import AccountContext
import Emoji
import Accelerate
import ComponentFlow
import AvatarStoryIndicatorComponent
import DirectMediaImageCache

private let deletedIcon = UIImage(bundleImageName: "Avatar/DeletedIcon")?.precomposed()
private let phoneIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/PhoneIcon"), color: .white)
public let savedMessagesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/SavedMessagesIcon"), color: .white)
public let repostStoryIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/RepostStoryIcon"), color: .white)
private let archivedChatsIcon = UIImage(bundleImageName: "Avatar/ArchiveAvatarIcon")?.precomposed()
private let repliesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/RepliesMessagesIcon"), color: .white)
private let anonymousSavedMessagesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/AnonymousSenderIcon"), color: .white)
private let anonymousSavedMessagesDarkIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/AnonymousSenderIcon"), color: UIColor(white: 1.0, alpha: 0.4))
private let myNotesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/MyNotesIcon"), color: .white)
private let cameraIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/CameraIcon"), color: .white)
private let storyIcon = generateTintedImage(image: UIImage(bundleImageName: "Share/Story"), color: .white)

public func avatarPlaceholderFont(size: CGFloat) -> UIFont {
    return Font.with(size: size, design: .round, weight: .bold)
}

public enum AvatarNodeClipStyle {
    case none
    case round
    case roundedRect
    case bubble
}

private class AvatarNodeParameters: NSObject {
    let theme: PresentationTheme?
    let accountPeerId: EnginePeer.Id?
    let peerId: EnginePeer.Id?
    let colors: [UIColor]
    let letters: [String]
    let font: UIFont
    let icon: AvatarNodeIcon
    let explicitColorIndex: Int?
    let hasImage: Bool
    let clipStyle: AvatarNodeClipStyle
    let cutoutRect: CGRect?
    
    init(theme: PresentationTheme?, accountPeerId: EnginePeer.Id?, peerId: EnginePeer.Id?, colors: [UIColor], letters: [String], font: UIFont, icon: AvatarNodeIcon, explicitColorIndex: Int?, hasImage: Bool, clipStyle: AvatarNodeClipStyle, cutoutRect: CGRect?) {
        self.theme = theme
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.colors = colors
        self.letters = letters
        self.font = font
        self.icon = icon
        self.explicitColorIndex = explicitColorIndex
        self.hasImage = hasImage
        self.clipStyle = clipStyle
        self.cutoutRect = cutoutRect
        
        super.init()
    }
    
    func withUpdatedHasImage(_ hasImage: Bool) -> AvatarNodeParameters {
        return AvatarNodeParameters(theme: self.theme, accountPeerId: self.accountPeerId, peerId: self.peerId, colors: self.colors, letters: self.letters, font: self.font, icon: self.icon, explicitColorIndex: self.explicitColorIndex, hasImage: hasImage, clipStyle: self.clipStyle, cutoutRect: self.cutoutRect)
    }
}

public func calculateAvatarColors(context: AccountContext?, explicitColorIndex: Int?, peerId: EnginePeer.Id?, nameColor: PeerNameColor?, icon: AvatarNodeIcon, theme: PresentationTheme?) -> [UIColor] {
    let colorIndex: Int
    if let explicitColorIndex = explicitColorIndex {
        colorIndex = explicitColorIndex
    } else {
        if let peerId {
            if peerId.namespace == .max {
                colorIndex = -1
            } else {
                colorIndex = abs(Int(clamping: peerId.id._internalGetInt64Value()))
            }
        } else {
            colorIndex = -1
        }
    }
    
    let colors: [UIColor]
    if icon != .none {
        if case .deletedIcon = icon {
            colors = AvatarNode.grayscaleColors
        } else if case .phoneIcon = icon {
            colors = AvatarNode.grayscaleColors
        } else if case .savedMessagesIcon = icon {
            colors = AvatarNode.savedMessagesColors
        } else if case .repostIcon = icon {
            colors = AvatarNode.repostColors
        } else if case .storyIcon = icon {
            colors = AvatarNode.repostColors
        } else if case .repliesIcon = icon {
            colors = AvatarNode.savedMessagesColors
        } else if case let .anonymousSavedMessagesIcon(isColored) = icon {
            if isColored {
                colors = AvatarNode.savedMessagesColors
            } else {
                if let theme, theme.overallDarkAppearance {
                    colors = AvatarNode.grayscaleDarkColors
                } else {
                    colors = AvatarNode.grayscaleColors
                }
            }
        } else if case .myNotesIcon = icon {
            colors = AvatarNode.savedMessagesColors
        } else if case .editAvatarIcon = icon, let theme {
            colors = [theme.list.itemAccentColor.withAlphaComponent(0.1), theme.list.itemAccentColor.withAlphaComponent(0.1)]
        } else if case let .archivedChatsIcon(hiddenByDefault) = icon, let theme = theme {
            let backgroundColors: (UIColor, UIColor)
            if hiddenByDefault {
                backgroundColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
            } else {
                backgroundColors = theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
            }
            colors = [backgroundColors.1, backgroundColors.0]
        } else if case .cameraIcon = icon {
            colors = AvatarNode.repostColors
        } else {
            colors = AvatarNode.grayscaleColors
        }
    } else if colorIndex == -1 {
        if let theme {
            let backgroundColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
            colors = [backgroundColors.1, backgroundColors.0]
        } else {
            colors = AvatarNode.grayscaleColors
        }
    } else {
        if let nameColor {
            if let context, nameColor.rawValue > 13 {
                let nameColors = context.peerNameColors.get(nameColor)
                let hue = nameColors.main.hsb.h
                var index: Int = 0
                if hue > 0.9 || hue < 0.02 {
                    index = 0
                } else if hue < 0.1 {
                    index = 1
                } else if hue < 0.4 {
                    index = 3
                } else if hue < 0.5 {
                    index = 4
                } else if hue < 0.6 {
                    index = 5
                } else if hue < 0.75 {
                    index = 2
                } else {
                    index = 6
                }
                colors = AvatarNode.gradientColors[index % AvatarNode.gradientColors.count]
            } else {
                colors = AvatarNode.gradientColors[Int(nameColor.rawValue) % AvatarNode.gradientColors.count]
            }
        } else {
            colors = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count]
        }
    }
    
    return colors
}

public enum AvatarNodeExplicitIcon {
    case phone
}

private enum AvatarNodeState: Equatable {
    case empty
    case peerAvatar(EnginePeer.Id, PeerNameColor?, [String], TelegramMediaImageRepresentation?, AvatarNodeClipStyle, CGRect?)
    case custom(letter: [String], explicitColorIndex: Int?, explicitIcon: AvatarNodeExplicitIcon?)
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.peerAvatar(lhsPeerId, lhsPeerNameColor, lhsLetters, lhsPhotoRepresentations, lhsClipStyle, lhsCutoutRect), .peerAvatar(rhsPeerId, rhsPeerNameColor, rhsLetters, rhsPhotoRepresentations, rhsClipStyle, rhsCutoutRect)):
            return lhsPeerId == rhsPeerId && lhsPeerNameColor == rhsPeerNameColor && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations && lhsClipStyle == rhsClipStyle && lhsCutoutRect == rhsCutoutRect
        case let (.custom(lhsLetters, lhsIndex, lhsIcon), .custom(rhsLetters, rhsIndex, rhsIcon)):
            return lhsLetters == rhsLetters && lhsIndex == rhsIndex && lhsIcon == rhsIcon
        default:
            return false
    }
}

public enum AvatarNodeIcon: Equatable {
    case none
    case savedMessagesIcon
    case repliesIcon
    case anonymousSavedMessagesIcon(isColored: Bool)
    case myNotesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon
    case deletedIcon
    case phoneIcon
    case repostIcon
    case cameraIcon
    case storyIcon
}

public enum AvatarNodeImageOverride: Equatable {
    case none
    case image(TelegramMediaImageRepresentation)
    case savedMessagesIcon
    case repliesIcon
    case anonymousSavedMessagesIcon(isColored: Bool)
    case myNotesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon(forceNone: Bool)
    case deletedIcon
    case phoneIcon
    case repostIcon
    case cameraIcon
    case storyIcon
}

public enum AvatarNodeColorOverride {
    case blue
}

public final class AvatarEditOverlayNode: ASDisplayNode {
    override public init() {
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        assertNotOnMainThread()
        
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        context.beginPath()
        context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height:
            bounds.size.height))
        context.clip()
        
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.fill(bounds)
        
        context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
        
        context.setBlendMode(.normal)
        
        if bounds.width > 90.0 {
            if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: .white) {
                context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0) + 0.5, y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0) + 1.0), size: editAvatarIcon.size))
            }
        } else {
            if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIcon"), color: .white) {
                context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0) + 0.5, y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0) + 1.0), size: editAvatarIcon.size))
            }
        }
    }
}

private func generateAvatarBubblePath() -> CGPath {
    return try! convertSvgPath("M60,30.274903 C60,46.843446 46.568544,60.274904 30,60.274904 C13.431458,60.274904 0,46.843446 0,30.274903 C0,23.634797 2.158635,17.499547 5.810547,12.529785 L6.036133,12.226074 C6.921364,10.896042 7.367402,8.104698 5.548828,5.316895 C3.606939,2.340088 1.186019,0.979668 2.399414,0.470215 C3.148032,0.156204 7.572027,0.000065 10.764648,1.790527 C12.148517,2.56662 13.2296,3.342422 14.09224,4.039734 C14.42622,4.309704 14.892063,4.349773 15.265962,4.138523 C19.618079,1.679604 24.644722,0.274902 30,0.274902 C46.568544,0.274902 60,13.70636 60,30.274903 Z ")
}

public final class AvatarNode: ASDisplayNode {
    public static func avatarBubbleMask(size: CGSize) -> UIImage! {
        return generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.white.cgColor)
            AvatarNode.addAvatarBubblePath(context: context, rect: CGRect(origin: CGPoint(), size: size))
            context.fillPath()
        })
    }
    
    public static let avatarBubblePath: CGPath = generateAvatarBubblePath()
    
    public static func addAvatarBubblePath(context: CGContext, rect: CGRect) {
        let path = AvatarNode.avatarBubblePath
        let sx = rect.width / 60.0
        let sy = rect.height / 60.274904
        var transform = CGAffineTransform(
            a: sx, b: 0.0,
            c: 0.0, d: -sy,
            tx: rect.minX,
            ty: rect.minY + rect.height
        )
        let transformedPath = path.copy(using: &transform)!
        context.addPath(transformedPath)
    }
    
    public static let gradientColors: [[UIColor]] = [
        [UIColor(rgb: 0xff516a), UIColor(rgb: 0xff885e)],
        [UIColor(rgb: 0xffa85c), UIColor(rgb: 0xffcd6a)],
        [UIColor(rgb: 0x665fff), UIColor(rgb: 0x82b1ff)],
        [UIColor(rgb: 0x54cb68), UIColor(rgb: 0xa0de7e)],
        [UIColor(rgb: 0x4acccd), UIColor(rgb: 0x00fcfd)],
        [UIColor(rgb: 0x2a9ef1), UIColor(rgb: 0x72d5fd)],
        [UIColor(rgb: 0xd669ed), UIColor(rgb: 0xe0a2f3)],
    ]
    
    static let grayscaleColors: [UIColor] = [
        UIColor(rgb: 0xb1b1b1), UIColor(rgb: 0xcdcdcd)
    ]
    
    static let grayscaleDarkColors: [UIColor] = [
        UIColor(white: 1.0, alpha: 0.22), UIColor(white: 1.0, alpha: 0.18)
    ]
    
    static let savedMessagesColors: [UIColor] = [
        UIColor(rgb: 0x2a9ef1), UIColor(rgb: 0x72d5fd)
    ]
    
    static let repostColors: [UIColor] = [
        UIColor(rgb: 0x3DA1FD), UIColor(rgb: 0x34C76F)
    ]
    
    public final class ContentNode: ASDisplayNode {
        private struct Params: Equatable {
            let peerId: EnginePeer.Id?
            let resourceId: String?
            let displayDimensions: CGSize
            let clipStyle: AvatarNodeClipStyle
            
            init(
                peerId: EnginePeer.Id?,
                resourceId: String?,
                displayDimensions: CGSize,
                clipStyle: AvatarNodeClipStyle
            ) {
                self.peerId = peerId
                self.resourceId = resourceId
                self.displayDimensions = displayDimensions
                self.clipStyle = clipStyle
            }
        }
        
        public var font: UIFont {
            didSet {
                if oldValue.pointSize != font.pointSize {
                    if let parameters = self.parameters {
                        self.parameters = AvatarNodeParameters(theme: parameters.theme, accountPeerId: parameters.accountPeerId, peerId: parameters.peerId, colors: parameters.colors, letters: parameters.letters, font: self.font, icon: parameters.icon, explicitColorIndex: parameters.explicitColorIndex, hasImage: parameters.hasImage, clipStyle: parameters.clipStyle, cutoutRect: parameters.cutoutRect)
                    }
                    
                    if !self.displaySuspended {
                        self.setNeedsDisplay()
                    }
                }
            }
        }
        private var parameters: AvatarNodeParameters?
        private var theme: PresentationTheme?
        private var overrideImage: AvatarNodeImageOverride?
        public let imageNode: ImageNode
        private var imageNodeMask: UIImageView?
        public var editOverlayNode: AvatarEditOverlayNode?
        
        private let imageReadyDisposable = MetaDisposable()
        fileprivate var state: AvatarNodeState = .empty
        
        public var unroundedImage: UIImage?
        private var currentImage: UIImage?
        
        private var params: Params?
        private var loadDisposable = MetaDisposable()
        
        var clipStyle: AvatarNodeClipStyle {
            if let params = self.params {
                return params.clipStyle
            } else if case let .peerAvatar(_, _, _, _, clipStyle, _) = self.state {
                return clipStyle
            }
            return .none
        }
        
        public var badgeView: AvatarBadgeView? {
            didSet {
                if self.badgeView !== oldValue {
                    if let badgeView = self.badgeView, let parameters = self.parameters {
                        if parameters.hasImage {
                            if let currentImage = self.currentImage {
                                badgeView.update(content: .image(currentImage))
                            }
                        } else {
                            let badgeColor: UIColor
                            if parameters.colors.isEmpty {
                                badgeColor = .white
                            } else {
                                badgeColor = parameters.colors[parameters.colors.count - 1]
                            }
                            badgeView.update(content: .color(badgeColor))
                        }
                    }
                }
            }
        }
        
        private let imageReady = Promise<Bool>(false)
        public var ready: Signal<Void, NoError> {
            let imageReady = self.imageReady
            return Signal { subscriber in
                return imageReady.get().start(next: { next in
                    if next {
                        subscriber.putCompletion()
                    }
                })
            }
        }
        
        public init(font: UIFont) {
            self.font = font
            self.imageNode = ImageNode(enableHasImage: true, enableAnimatedTransition: true)
            
            super.init()
            
            self.isOpaque = false
            self.displaysAsynchronously = true
            self.disableClearContentsOnHide = true
            
            self.imageNode.isUserInteractionEnabled = false
            self.addSubnode(self.imageNode)
            
            self.imageNode.contentUpdated = { [weak self] image in
                guard let self else {
                    return
                }
                
                self.currentImage = image
                
                guard let badgeView = self.badgeView, let parameters = self.parameters else {
                    return
                }
                
                if parameters.hasImage, let image {
                    badgeView.update(content: .image(image))
                }
            }
        }
        
        deinit {
            self.loadDisposable.dispose()
        }
        
        override public func didLoad() {
            super.didLoad()
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
                self.view.accessibilityIgnoresInvertColors = true
            }
        }
        
        public func updateSize(size: CGSize) {
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            self.editOverlayNode?.frame = self.imageNode.frame
            if let imageNodeMask = self.imageNodeMask {
                imageNodeMask.frame = CGRect(origin: CGPoint(), size: size)
            }
            if !self.displaySuspended {
                self.setNeedsDisplay()
                self.editOverlayNode?.setNeedsDisplay()
            }
        }
        
        public func playArchiveAnimation() {
            guard let theme = self.theme else {
                return
            }
            
            var iconColor = theme.chatList.unpinnedArchiveAvatarColor.foregroundColor
            var backgroundColor = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.topColor
            let animationBackgroundNode = ASImageNode()
            animationBackgroundNode.isUserInteractionEnabled = false
            animationBackgroundNode.frame = self.imageNode.frame
            if let overrideImage = self.overrideImage, case let .archivedChatsIcon(hiddenByDefault) = overrideImage {
                let backgroundColors: (UIColor, UIColor)
                if hiddenByDefault {
                    backgroundColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
                    iconColor = theme.chatList.unpinnedArchiveAvatarColor.foregroundColor
                } else {
                    backgroundColors = theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
                    iconColor = theme.chatList.pinnedArchiveAvatarColor.foregroundColor
                }
                let colors: NSArray = [backgroundColors.1.cgColor, backgroundColors.0.cgColor]
                backgroundColor = backgroundColors.1.mixedWith(backgroundColors.0, alpha: 0.5)
                animationBackgroundNode.image = generateGradientFilledCircleImage(diameter: self.imageNode.frame.width, colors: colors)
            }
            
            self.addSubnode(animationBackgroundNode)
            
            let animationNode = AnimationNode(animation: "anim_archiveAvatar", colors: ["box1.box1.Fill 1": iconColor, "box3.box3.Fill 1": iconColor, "box2.box2.Fill 1": backgroundColor], scale: 0.1653828)
            animationNode.isUserInteractionEnabled = false
            animationNode.completion = { [weak animationBackgroundNode, weak self] in
                self?.imageNode.isHidden = false
                animationBackgroundNode?.removeFromSupernode()
            }
            animationBackgroundNode.addSubnode(animationNode)
            
            animationBackgroundNode.layer.animateScale(from: 1.0, to: 1.07, duration: 0.12, removeOnCompletion: false, completion: { [weak animationBackgroundNode] finished in
                animationBackgroundNode?.layer.animateScale(from: 1.07, to: 1.0, duration: 0.12, removeOnCompletion: false)
            })
            
            if var size = animationNode.preferredSize() {
                size = CGSize(width: ceil(size.width), height: ceil(size.height))
                animationNode.frame = CGRect(x: floor((self.bounds.width - size.width) / 2.0), y: floor((self.bounds.height - size.height) / 2.0) + 1.0, width: size.width, height: size.height)
                animationNode.play()
            }
            self.imageNode.isHidden = true
        }
        
        public func playRepostAnimation() {
            let animationNode = AnimationNode(animation: "anim_storyrepost", colors: [:], scale: 0.11)
            animationNode.isUserInteractionEnabled = false
            self.addSubnode(animationNode)
            
            if var size = animationNode.preferredSize() {
                size = CGSize(width: ceil(size.width), height: ceil(size.height))
                animationNode.frame = CGRect(x: floor((self.bounds.width - size.width) / 2.0), y: floor((self.bounds.height - size.height) / 2.0) + 1.0, width: size.width, height: size.height)
                Queue.mainQueue().after(0.15, {
                    animationNode.play()
                })
            }
        }
        
        public func playCameraAnimation() {
            let animationBackgroundNode = ASImageNode()
            animationBackgroundNode.isUserInteractionEnabled = false
            animationBackgroundNode.frame = self.imageNode.frame
            animationBackgroundNode.image = generateGradientFilledCircleImage(diameter: self.imageNode.frame.width, colors: AvatarNode.repostColors.map { $0.cgColor } as NSArray)
            self.addSubnode(animationBackgroundNode)
            
            let animationNode = AnimationNode(animation: "anim_camera", colors: [:], scale: 0.082)
            animationNode.isUserInteractionEnabled = false
            self.addSubnode(animationNode)
            
            if var size = animationNode.preferredSize() {
                size = CGSize(width: ceil(size.width), height: ceil(size.height))
                animationNode.frame = CGRect(x: floor((self.bounds.width - size.width) / 2.0) + 1.0, y: floor((self.bounds.height - size.height) / 2.0), width: size.width, height: size.height)
                Queue.mainQueue().after(0.15, {
                    animationNode.play()
                    animationNode.completion = { [weak animationNode, weak animationBackgroundNode] in
                        animationNode?.removeFromSupernode()
                        animationBackgroundNode?.removeFromSupernode()
                    }
                })
            }
        }
        
        public func setPeer(
            accountPeerId: EnginePeer.Id,
            postbox: Postbox,
            network: Network,
            contentSettings: ContentSettings,
            theme: PresentationTheme,
            peer: EnginePeer?,
            authorOfMessage: MessageReference? = nil,
            overrideImage: AvatarNodeImageOverride? = nil,
            emptyColor: UIColor? = nil,
            clipStyle: AvatarNodeClipStyle = .round,
            synchronousLoad: Bool = false,
            displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
            storeUnrounded: Bool = false,
            cutoutRect: CGRect? = nil
        ) {
            var synchronousLoad = synchronousLoad
            var representation: TelegramMediaImageRepresentation?
            var icon = AvatarNodeIcon.none
            if let overrideImage = overrideImage {
                switch overrideImage {
                case .none:
                    representation = nil
                case let .image(image):
                    representation = image
                    synchronousLoad = false
                case .savedMessagesIcon:
                    representation = nil
                    icon = .savedMessagesIcon
                case .repostIcon:
                    representation = nil
                    icon = .repostIcon
                case .repliesIcon:
                    representation = nil
                    icon = .repliesIcon
                case let .anonymousSavedMessagesIcon(isColored):
                    representation = nil
                    icon = .anonymousSavedMessagesIcon(isColored: isColored)
                case .myNotesIcon:
                    representation = nil
                    icon = .myNotesIcon
                case let .archivedChatsIcon(hiddenByDefault):
                    representation = nil
                    icon = .archivedChatsIcon(hiddenByDefault: hiddenByDefault)
                case let .editAvatarIcon(forceNone):
                    representation = forceNone ? nil : peer?.smallProfileImage
                    icon = .editAvatarIcon
                case .deletedIcon:
                    representation = nil
                    icon = .deletedIcon
                case .phoneIcon:
                    representation = nil
                    icon = .phoneIcon
                case .cameraIcon:
                    representation = nil
                    icon = .cameraIcon
                case .storyIcon:
                    representation = nil
                    icon = .storyIcon
                }
            } else if peer?.restrictionText(platform: "ios", contentSettings: contentSettings) == nil {
                representation = peer?.smallProfileImage
            }
            
            let updatedState: AvatarNodeState = .peerAvatar(peer?.id ?? EnginePeer.Id(0), peer?.nameColor, peer?.displayLetters ?? [], representation, clipStyle, cutoutRect)
            if updatedState != self.state || overrideImage != self.overrideImage || theme !== self.theme {
                self.state = updatedState
                self.overrideImage = overrideImage
                self.theme = theme
                
                let parameters: AvatarNodeParameters
                
                if let peer = peer, let signal = peerAvatarImage(postbox: postbox, network: network, peerReference: PeerReference(peer._asPeer()), authorOfMessage: authorOfMessage, representation: representation, displayDimensions: displayDimensions, clipStyle: clipStyle, emptyColor: emptyColor, synchronousLoad: synchronousLoad, provideUnrounded: storeUnrounded, cutoutRect: cutoutRect) {
                    self.contents = nil
                    self.displaySuspended = true
                    self.imageReady.set(self.imageNode.contentReady)
                    self.imageNode.setSignal(signal |> beforeNext { [weak self] next in
                        Queue.mainQueue().async {
                            self?.unroundedImage = next?.1
                        }
                    }
                    |> map { next -> UIImage? in
                        return next?.0
                    })
                    
                    if case .editAvatarIcon = icon {
                        if self.editOverlayNode == nil {
                            let editOverlayNode = AvatarEditOverlayNode()
                            editOverlayNode.frame = self.imageNode.frame
                            editOverlayNode.isUserInteractionEnabled = false
                            self.addSubnode(editOverlayNode)
                            
                            self.editOverlayNode = editOverlayNode
                        }
                        self.editOverlayNode?.isHidden = false
                    } else {
                        self.editOverlayNode?.isHidden = true
                    }
                    
                    parameters = AvatarNodeParameters(theme: theme, accountPeerId: accountPeerId, peerId: peer.id, colors: calculateAvatarColors(context: nil, explicitColorIndex: nil, peerId: peer.id, nameColor: peer.nameColor, icon: icon, theme: theme), letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: true, clipStyle: clipStyle, cutoutRect: cutoutRect)
                } else {
                    self.imageReady.set(.single(true))
                    self.displaySuspended = false
                    if self.isNodeLoaded {
                        self.imageNode.contents = nil
                    }
                    
                    self.editOverlayNode?.isHidden = true
                    let colors = calculateAvatarColors(context: nil, explicitColorIndex: nil, peerId: peer?.id ?? EnginePeer.Id(0), nameColor: peer?.nameColor, icon: icon, theme: theme)
                    parameters = AvatarNodeParameters(theme: theme, accountPeerId: accountPeerId, peerId: peer?.id ?? EnginePeer.Id(0), colors: colors, letters: peer?.displayLetters ?? [], font: self.font, icon: icon, explicitColorIndex: nil, hasImage: false, clipStyle: clipStyle, cutoutRect: cutoutRect)
                    
                    if let badgeView = self.badgeView {
                        let badgeColor: UIColor
                        if colors.isEmpty {
                            badgeColor = .white
                        } else {
                            badgeColor = colors[colors.count - 1]
                        }
                        badgeView.update(content: .color(badgeColor))
                    }
                }
                if self.parameters == nil || self.parameters != parameters {
                    self.parameters = parameters
                    self.setNeedsDisplay()
                    if synchronousLoad {
                        self.recursivelyEnsureDisplaySynchronously(true)
                    }
                }
            }
        }
        
        func setPeerV2(
            context genericContext: AccountContext,
            account: Account? = nil,
            theme: PresentationTheme,
            peer: EnginePeer?,
            authorOfMessage: MessageReference? = nil,
            overrideImage: AvatarNodeImageOverride? = nil,
            emptyColor: UIColor? = nil,
            clipStyle: AvatarNodeClipStyle = .round,
            synchronousLoad: Bool = false,
            displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
            storeUnrounded: Bool = false
        ) {
            let smallProfileImage = peer?.smallProfileImage
            let params = Params(
                peerId: peer?.id,
                resourceId: smallProfileImage?.resource.id.stringRepresentation,
                displayDimensions: displayDimensions,
                clipStyle: clipStyle
            )
            if self.params == params {
                return
            }
            let previousSize = self.params?.displayDimensions
            self.params = params
            
            switch clipStyle {
            case .none:
                self.imageNode.clipsToBounds = false
                self.imageNode.cornerRadius = 0.0
            case .round:
                self.imageNode.clipsToBounds = true
                self.imageNode.cornerRadius = displayDimensions.height * 0.5
            case .roundedRect:
                self.imageNode.clipsToBounds = true
                self.imageNode.cornerRadius = displayDimensions.height * 0.25
            case .bubble:
                break
            }
            
            if case .bubble = clipStyle {
                var updateMask = false
                let imageNodeMask: UIImageView
                if let current = self.imageNodeMask {
                    imageNodeMask = current
                    updateMask = previousSize != params.displayDimensions
                } else {
                    imageNodeMask = UIImageView()
                    self.imageNodeMask = imageNodeMask
                    self.imageNode.view.mask = imageNodeMask
                    imageNodeMask.frame = self.imageNode.frame
                    updateMask = true
                }
                if updateMask {
                    imageNodeMask.image = AvatarNode.avatarBubbleMask(size: params.displayDimensions)
                }
            } else if self.imageNodeMask != nil {
                self.imageNodeMask = nil
                self.imageNode.view.mask = nil
            }
            
            if let imageCache = genericContext.imageCache as? DirectMediaImageCache, let peer, let smallProfileImage = peer.smallProfileImage, let peerReference = PeerReference(peer._asPeer()) {
                if let result = imageCache.getAvatarImage(peer: peerReference, resource: MediaResourceReference.avatar(peer: peerReference, resource: smallProfileImage.resource), immediateThumbnail: peer.profileImageRepresentations.first?.immediateThumbnailData, size: Int(displayDimensions.width * UIScreenScale), synchronous: synchronousLoad) {
                    if let image = result.image {
                        self.imageNode.contents = image.cgImage
                    }
                    if let loadSignal = result.loadSignal {
                        self.loadDisposable.set((loadSignal |> deliverOnMainQueue).start(next: { [weak self] image in
                            guard let self else {
                                return
                            }
                            self.imageNode.contents = image?.cgImage
                        }).strict())
                    }
                }
            }
        }
        
        public func setPeer(
            context genericContext: AccountContext,
            account: Account? = nil,
            theme: PresentationTheme,
            peer: EnginePeer?,
            authorOfMessage: MessageReference? = nil,
            overrideImage: AvatarNodeImageOverride? = nil,
            emptyColor: UIColor? = nil,
            clipStyle: AvatarNodeClipStyle = .round,
            synchronousLoad: Bool = false,
            displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
            storeUnrounded: Bool = false,
            cutoutRect: CGRect? = nil
        ) {
            var synchronousLoad = synchronousLoad
            var representation: TelegramMediaImageRepresentation?
            var icon = AvatarNodeIcon.none
            if let overrideImage = overrideImage {
                switch overrideImage {
                case .none:
                    representation = nil
                case let .image(image):
                    representation = image
                    synchronousLoad = false
                case .savedMessagesIcon:
                    representation = nil
                    icon = .savedMessagesIcon
                case .repostIcon:
                    representation = nil
                    icon = .repostIcon
                case .repliesIcon:
                    representation = nil
                    icon = .repliesIcon
                case let .anonymousSavedMessagesIcon(isColored):
                    representation = nil
                    icon = .anonymousSavedMessagesIcon(isColored: isColored)
                case .myNotesIcon:
                    representation = nil
                    icon = .myNotesIcon
                case let .archivedChatsIcon(hiddenByDefault):
                    representation = nil
                    icon = .archivedChatsIcon(hiddenByDefault: hiddenByDefault)
                case let .editAvatarIcon(forceNone):
                    representation = forceNone ? nil : peer?.smallProfileImage
                    icon = .editAvatarIcon
                case .deletedIcon:
                    representation = nil
                    icon = .deletedIcon
                case .phoneIcon:
                    representation = nil
                    icon = .phoneIcon
                case .cameraIcon:
                    representation = nil
                    icon = .cameraIcon
                case .storyIcon:
                    representation = nil
                    icon = .storyIcon
                }
            } else if peer?.restrictionText(platform: "ios", contentSettings: genericContext.currentContentSettings.with { $0 }) == nil {
                representation = peer?.smallProfileImage
            }
            
            let updatedState: AvatarNodeState = .peerAvatar(peer?.id ?? EnginePeer.Id(0), peer?.nameColor, peer?.displayLetters ?? [], representation, clipStyle, cutoutRect)
            if updatedState != self.state || overrideImage != self.overrideImage || theme !== self.theme {
                self.state = updatedState
                self.overrideImage = overrideImage
                self.theme = theme
                
                let parameters: AvatarNodeParameters
                
                let account = account ?? genericContext.account
                
                if let peer = peer, let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: authorOfMessage, representation: representation, displayDimensions: displayDimensions, clipStyle: clipStyle, emptyColor: emptyColor, synchronousLoad: synchronousLoad, provideUnrounded: storeUnrounded, cutoutRect: cutoutRect) {
                    self.contents = nil
                    self.displaySuspended = true
                    self.imageReady.set(self.imageNode.contentReady)
                    self.imageNode.setSignal(signal |> beforeNext { [weak self] next in
                        Queue.mainQueue().async {
                            self?.unroundedImage = next?.1
                        }
                    }
                    |> map { next -> UIImage? in
                        return next?.0
                    })
                    
                    if case .editAvatarIcon = icon {
                        if self.editOverlayNode == nil {
                            let editOverlayNode = AvatarEditOverlayNode()
                            editOverlayNode.frame = self.imageNode.frame
                            editOverlayNode.isUserInteractionEnabled = false
                            self.addSubnode(editOverlayNode)
                            
                            self.editOverlayNode = editOverlayNode
                        }
                        self.editOverlayNode?.isHidden = false
                    } else {
                        self.editOverlayNode?.isHidden = true
                    }
                    
                    parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer.id, colors: calculateAvatarColors(context: genericContext, explicitColorIndex: nil, peerId: peer.id, nameColor: peer.nameColor, icon: icon, theme: theme), letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: true, clipStyle: clipStyle, cutoutRect: cutoutRect)
                } else {
                    self.imageReady.set(.single(true))
                    self.displaySuspended = false
                    if self.isNodeLoaded {
                        self.imageNode.contents = nil
                    }
                    
                    self.editOverlayNode?.isHidden = true
                    let colors = calculateAvatarColors(context: genericContext, explicitColorIndex: nil, peerId: peer?.id ?? EnginePeer.Id(0), nameColor: peer?.nameColor, icon: icon, theme: theme)
                    parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer?.id ?? EnginePeer.Id(0), colors: colors, letters: peer?.displayLetters ?? [], font: self.font, icon: icon, explicitColorIndex: nil, hasImage: false, clipStyle: clipStyle, cutoutRect: cutoutRect)
                    
                    if let badgeView = self.badgeView {
                        let badgeColor: UIColor
                        if colors.isEmpty {
                            badgeColor = .white
                        } else {
                            badgeColor = colors[colors.count - 1]
                        }
                        badgeView.update(content: .color(badgeColor))
                    }
                }
                if self.parameters == nil || self.parameters != parameters {
                    self.parameters = parameters
                    self.setNeedsDisplay()
                    if synchronousLoad {
                        self.recursivelyEnsureDisplaySynchronously(true)
                    }
                }
            }
        }
        
        public func setCustomLetters(_ letters: [String], explicitColor: AvatarNodeColorOverride? = nil, icon: AvatarNodeExplicitIcon? = nil, cutoutRect: CGRect? = nil) {
            var explicitIndex: Int?
            if let explicitColor = explicitColor {
                switch explicitColor {
                    case .blue:
                        explicitIndex = 5
                }
            }
            let updatedState: AvatarNodeState = .custom(letter: letters, explicitColorIndex: explicitIndex, explicitIcon: icon)
            if updatedState != self.state {
                self.state = updatedState
                
                let parameters: AvatarNodeParameters
                if let icon = icon, case .phone = icon {
                    parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, colors: calculateAvatarColors(context: nil, explicitColorIndex: explicitIndex, peerId: nil, nameColor: nil, icon: .phoneIcon, theme: nil), letters: [], font: self.font, icon: .phoneIcon, explicitColorIndex: explicitIndex, hasImage: false, clipStyle: .round, cutoutRect: cutoutRect)
                } else {
                    parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, colors: calculateAvatarColors(context: nil, explicitColorIndex: explicitIndex, peerId: nil, nameColor: nil, icon: .none, theme: nil), letters: letters, font: self.font, icon: .none, explicitColorIndex: explicitIndex, hasImage: false, clipStyle: .round, cutoutRect: cutoutRect)
                }
                
                self.displaySuspended = true
                self.contents = nil
            
                self.imageReady.set(.single(true))
                self.displaySuspended = false
                
                if self.parameters == nil || self.parameters != parameters {
                    self.parameters = parameters
                    self.setNeedsDisplay()
                }
            }
        }
        
        override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol {
            return parameters ?? NSObject()
        }
        
        @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
            let context = UIGraphicsGetCurrentContext()!
            
            if !isRasterizing {
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fill(bounds)
            }
            
            if !(parameters is AvatarNodeParameters) {
                return
            }
            
            let colors: [UIColor]
            if let parameters = parameters as? AvatarNodeParameters {
                colors = parameters.colors
                
                if case .round = parameters.clipStyle {
                    context.beginPath()
                    context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height:
                        bounds.size.height))
                    context.clip()
                } else if case .roundedRect = parameters.clipStyle {
                    context.beginPath()
                    context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height: bounds.size.height), cornerRadius: floor(bounds.size.width * 0.25)).cgPath)
                    context.clip()
                } else if case .bubble = parameters.clipStyle {
                    context.beginPath()
                    AvatarNode.addAvatarBubblePath(context: context, rect: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height: bounds.size.height))
                    context.clip()
                }
            } else {
                colors = grayscaleColors
            }
            
            let colorsArray: NSArray = colors.map(\.cgColor) as NSArray
            
            var iconColor = UIColor.white
            var diagonal = false
            if let parameters = parameters as? AvatarNodeParameters, parameters.icon != .none {
                if case .repostIcon = parameters.icon {
                    diagonal = true
                }
                if case let .archivedChatsIcon(hiddenByDefault) = parameters.icon, let theme = parameters.theme {
                    if hiddenByDefault {
                        iconColor = theme.chatList.unpinnedArchiveAvatarColor.foregroundColor
                    } else {
                        iconColor = theme.chatList.pinnedArchiveAvatarColor.foregroundColor
                    }
                }
            }
            
            var locations: [CGFloat] = [1.0, 0.0]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
            
            if diagonal {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: bounds.size.height), end: CGPoint(x: bounds.size.width, y: 0.0), options: CGGradientDrawingOptions())
            } else {
                context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.size.height), options: CGGradientDrawingOptions())
            }
            
            context.setBlendMode(.normal)
            
            if let parameters = parameters as? AvatarNodeParameters {
                if case .deletedIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let deletedIcon = deletedIcon {
                        context.draw(deletedIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - deletedIcon.size.width) / 2.0), y: floor((bounds.size.height - deletedIcon.size.height) / 2.0)), size: deletedIcon.size))
                    }
                } else if case .phoneIcon = parameters.icon {
                    let factor: CGFloat = 1.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let phoneIcon = phoneIcon {
                        context.draw(phoneIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - phoneIcon.size.width) / 2.0), y: floor((bounds.size.height - phoneIcon.size.height) / 2.0)), size: phoneIcon.size))
                    }
                } else if case .savedMessagesIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let savedMessagesIcon = savedMessagesIcon {
                        context.draw(savedMessagesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - savedMessagesIcon.size.width) / 2.0), y: floor((bounds.size.height - savedMessagesIcon.size.height) / 2.0)), size: savedMessagesIcon.size))
                    }
                } else if case .repostIcon = parameters.icon {
                    if !"".isEmpty {
                        let factor = bounds.size.width / 60.0
                        context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                        context.scaleBy(x: factor, y: -factor)
                        context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                        
                        if let repostStoryIcon = repostStoryIcon {
                            context.draw(repostStoryIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - repostStoryIcon.size.width) / 2.0), y: floor((bounds.size.height - repostStoryIcon.size.height) / 2.0)), size: repostStoryIcon.size))
                        }
                    }
                } else if case .repliesIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let repliesIcon = repliesIcon {
                        context.draw(repliesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - repliesIcon.size.width) / 2.0), y: floor((bounds.size.height - repliesIcon.size.height) / 2.0)), size: repliesIcon.size))
                    }
                } else if case let .anonymousSavedMessagesIcon(isColored) = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let theme = parameters.theme, theme.overallDarkAppearance, !isColored {
                        if let anonymousSavedMessagesDarkIcon = anonymousSavedMessagesDarkIcon {
                            context.draw(anonymousSavedMessagesDarkIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - anonymousSavedMessagesDarkIcon.size.width) / 2.0), y: floor((bounds.size.height - anonymousSavedMessagesDarkIcon.size.height) / 2.0)), size: anonymousSavedMessagesDarkIcon.size))
                        }
                    } else {
                        if let anonymousSavedMessagesIcon = anonymousSavedMessagesIcon {
                            context.draw(anonymousSavedMessagesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - anonymousSavedMessagesIcon.size.width) / 2.0), y: floor((bounds.size.height - anonymousSavedMessagesIcon.size.height) / 2.0)), size: anonymousSavedMessagesIcon.size))
                        }
                    }
                } else if case .myNotesIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let myNotesIcon = myNotesIcon {
                        context.draw(myNotesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - myNotesIcon.size.width) / 2.0), y: floor((bounds.size.height - myNotesIcon.size.height) / 2.0)), size: myNotesIcon.size))
                    }
                } else if case .cameraIcon = parameters.icon {
                    let factor = bounds.size.width / 40.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let cameraIcon = cameraIcon {
                        context.draw(cameraIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - cameraIcon.size.width) / 2.0), y: floor((bounds.size.height - cameraIcon.size.height) / 2.0)), size: cameraIcon.size))
                    }
                } else if case .storyIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let storyIcon = storyIcon {
                        context.draw(storyIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - storyIcon.size.width) / 2.0), y: floor((bounds.size.height - storyIcon.size.height) / 2.0)), size: storyIcon.size))
                    }
                } else if case .editAvatarIcon = parameters.icon, let theme = parameters.theme, !parameters.hasImage {
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if bounds.width > 90.0, let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: theme.list.itemAccentColor) {
                        context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0) + 0.5, y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0) + 1.0), size: editAvatarIcon.size))
                    } else if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIcon"), color: theme.list.itemAccentColor) {
                        context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0) + 0.5, y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0) + 1.0), size: editAvatarIcon.size))
                    }
                } else if case .archivedChatsIcon = parameters.icon {
                    let factor = bounds.size.width / 60.0
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: factor, y: -factor)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    if let archivedChatsIcon = generateTintedImage(image: archivedChatsIcon, color: iconColor) {
                        context.draw(archivedChatsIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - archivedChatsIcon.size.width) / 2.0), y: floor((bounds.size.height - archivedChatsIcon.size.height) / 2.0)), size: archivedChatsIcon.size))
                    }
                } else {
                    var letters = parameters.letters
                    if letters.count == 2 && letters[0].isSingleEmoji && letters[1].isSingleEmoji {
                        letters = [letters[0]]
                    }
                    
                    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
                    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: parameters.font, NSAttributedString.Key.foregroundColor: UIColor.white])
                    
                    let line = CTLineCreateWithAttributedString(attributedString)
                    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                    
                    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
                    let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (bounds.size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (bounds.size.height - lineBounds.size.height) / 2.0))
                    
                    context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    
                    context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
                    CTLineDraw(line, context)
                    context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
                }
            }
            
            if let parameters = parameters as? AvatarNodeParameters, let cutoutRect = parameters.cutoutRect {
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fillEllipse(in: cutoutRect.offsetBy(dx: 0.0, dy: bounds.height - cutoutRect.maxY - cutoutRect.height))
            }
        }
    }
    
    public let contentNode: ContentNode
    private var storyIndicator: ComponentView<Empty>?
    public private(set) var storyPresentationParams: StoryPresentationParams?
    
    private var loadingStatuses = Bag<Disposable>()
    
    public struct StoryStats: Equatable {
        public var totalCount: Int
        public var unseenCount: Int
        public var hasUnseenCloseFriendsItems: Bool
        public var progress: Float?
        
        public init(
            totalCount: Int,
            unseenCount: Int,
            hasUnseenCloseFriendsItems: Bool,
            progress: Float? = nil
        ) {
            self.totalCount = totalCount
            self.unseenCount = unseenCount
            self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
            self.progress = progress
        }
    }
    
    public private(set) var storyStats: StoryStats?
    
    public var font: UIFont {
        get {
            return self.contentNode.font
        } set(value) {
            self.contentNode.font = value
        }
    }
    
    public var editOverlayNode: AvatarEditOverlayNode? {
        get {
            return self.contentNode.editOverlayNode
        } set(value) {
            self.contentNode.editOverlayNode = value
        }
    }
    
    public var unroundedImage: UIImage? {
        get {
            return self.contentNode.unroundedImage
        } set(value) {
            self.contentNode.unroundedImage = value
        }
    }
    
    public var badgeView: AvatarBadgeView? {
        get {
            return self.contentNode.badgeView
        } set(value) {
            self.contentNode.badgeView = value
        }
    }
    
    public var ready: Signal<Void, NoError> {
        return self.contentNode.ready
    }
    
    public var imageNode: ImageNode {
        return self.contentNode.imageNode
    }
    
    public init(font: UIFont) {
        self.contentNode = ContentNode(font: font)
        
        super.init()
        
        self.onDidLoad { [weak self] _ in
            guard let self else {
                return
            }
            self.updateStoryIndicator(transition: .immediate)
        }
        
        self.addSubnode(self.contentNode)
    }
    
    deinit {
        self.cancelLoading()
    }
    
    override public var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let updateImage = !value.size.equalTo(super.frame.size)
            super.frame = value
            
            if updateImage {
                self.updateSize(size: value.size)
            }
        }
    }
    
    override public func nodeDidLoad() {
        super.nodeDidLoad()
    }
    
    public func updateSize(size: CGSize) {
        self.contentNode.position = CGRect(origin: CGPoint(), size: size).center
        self.contentNode.bounds = CGRect(origin: CGPoint(), size: size)
        
        self.contentNode.updateSize(size: size)
        
        self.updateStoryIndicator(transition: .immediate)
    }
    
    public func playArchiveAnimation() {
        self.contentNode.playArchiveAnimation()
    }
    
    public func playRepostAnimation() {
        self.contentNode.playRepostAnimation()
    }
    
    public func playCameraAnimation() {
        self.contentNode.playCameraAnimation ()
    }
    
    public func setPeer(
        accountPeerId: EnginePeer.Id,
        postbox: Postbox,
        network: Network,
        contentSettings: ContentSettings,
        theme: PresentationTheme,
        peer: EnginePeer?,
        authorOfMessage: MessageReference? = nil,
        overrideImage: AvatarNodeImageOverride? = nil,
        emptyColor: UIColor? = nil,
        clipStyle: AvatarNodeClipStyle = .round,
        synchronousLoad: Bool = false,
        displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
        storeUnrounded: Bool = false
    ) {
        self.contentNode.setPeer(
            accountPeerId: accountPeerId,
            postbox: postbox,
            network: network,
            contentSettings: contentSettings,
            theme: theme,
            peer: peer,
            authorOfMessage: authorOfMessage,
            overrideImage: overrideImage,
            emptyColor: emptyColor,
            clipStyle: clipStyle,
            synchronousLoad: synchronousLoad,
            displayDimensions: displayDimensions,
            storeUnrounded: storeUnrounded
        )
    }
    
    public func setPeerV2(
        context genericContext: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer?,
        authorOfMessage: MessageReference? = nil,
        overrideImage: AvatarNodeImageOverride? = nil,
        emptyColor: UIColor? = nil,
        clipStyle: AvatarNodeClipStyle = .round,
        synchronousLoad: Bool = false,
        displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
        storeUnrounded: Bool = false
    ) {
        self.contentNode.setPeerV2(
            context: genericContext,
            theme: theme,
            peer: peer,
            authorOfMessage: authorOfMessage,
            overrideImage: overrideImage,
            emptyColor: emptyColor,
            clipStyle: clipStyle,
            synchronousLoad: synchronousLoad,
            displayDimensions: displayDimensions,
            storeUnrounded: storeUnrounded
        )
    }
    
    public func setPeer(
        context: AccountContext,
        account: Account? = nil,
        theme: PresentationTheme,
        peer: EnginePeer?,
        authorOfMessage: MessageReference? = nil,
        overrideImage: AvatarNodeImageOverride? = nil,
        emptyColor: UIColor? = nil,
        clipStyle: AvatarNodeClipStyle = .round,
        synchronousLoad: Bool = false,
        displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0),
        storeUnrounded: Bool = false,
        cutoutRect: CGRect? = nil
    ) {
        self.contentNode.setPeer(
            context: context,
            account: account,
            theme: theme,
            peer: peer,
            authorOfMessage: authorOfMessage,
            overrideImage: overrideImage,
            emptyColor: emptyColor,
            clipStyle: clipStyle,
            synchronousLoad: synchronousLoad,
            displayDimensions: displayDimensions,
            storeUnrounded: storeUnrounded,
            cutoutRect: cutoutRect
        )
    }
    
    public func setCustomLetters(_ letters: [String], explicitColor: AvatarNodeColorOverride? = nil, icon: AvatarNodeExplicitIcon? = nil) {
        self.contentNode.setCustomLetters(letters, explicitColor: explicitColor, icon: icon)
    }
    
    public func setStoryStats(storyStats: StoryStats?, presentationParams: StoryPresentationParams, transition: ComponentTransition) {
        if self.storyStats != storyStats || self.storyPresentationParams != presentationParams {
            self.storyStats = storyStats
            self.storyPresentationParams = presentationParams
            
            self.updateStoryIndicator(transition: transition)
        }
    }
    
    public struct Colors: Equatable {
        public var unseenColors: [UIColor]
        public var unseenCloseFriendsColors: [UIColor]
        public var seenColors: [UIColor]
        
        public init(
            unseenColors: [UIColor],
            unseenCloseFriendsColors: [UIColor],
            seenColors: [UIColor]
        ) {
            self.unseenColors = unseenColors
            self.unseenCloseFriendsColors = unseenCloseFriendsColors
            self.seenColors = seenColors
        }
        
        public init(theme: PresentationTheme) {
            self.unseenColors = [theme.chatList.storyUnseenColors.topColor, theme.chatList.storyUnseenColors.bottomColor]
            self.unseenCloseFriendsColors = [theme.chatList.storyUnseenPrivateColors.topColor, theme.chatList.storyUnseenPrivateColors.bottomColor]
            self.seenColors = [theme.chatList.storySeenColors.topColor, theme.chatList.storySeenColors.bottomColor]
        }
    }
    
    public struct StoryPresentationParams: Equatable {
        public var colors: Colors
        public var lineWidth: CGFloat
        public var inactiveLineWidth: CGFloat
        public var forceRoundedRect: Bool
        
        public init(
            colors: Colors,
            lineWidth: CGFloat,
            inactiveLineWidth: CGFloat,
            forceRoundedRect: Bool =  false
        ) {
            self.colors = colors
            self.lineWidth = lineWidth
            self.inactiveLineWidth = inactiveLineWidth
            self.forceRoundedRect = forceRoundedRect
        }
    }
    
    private func updateStoryIndicator(transition: ComponentTransition) {
        if !self.isNodeLoaded {
            return
        }
        if self.bounds.isEmpty {
            return
        }
        guard let storyPresentationParams = self.storyPresentationParams else {
            return
        }
        
        let size = self.bounds.size
                
        if let storyStats = self.storyStats {
            let activeLineWidth = storyPresentationParams.lineWidth
            let inactiveLineWidth = storyPresentationParams.inactiveLineWidth
            let indicatorSize = CGSize(width: size.width - activeLineWidth * 4.0, height: size.height - activeLineWidth * 4.0)
            let avatarScale = (size.width - activeLineWidth * 4.0) / size.width
            
            let storyIndicator: ComponentView<Empty>
            var indicatorTransition = transition
            if let current = self.storyIndicator {
                storyIndicator = current
            } else {
                indicatorTransition = transition.withAnimation(.none)
                storyIndicator = ComponentView()
                self.storyIndicator = storyIndicator
            }
            var mappedProgress: AvatarStoryIndicatorComponent.Progress?
            if let value = storyStats.progress {
                mappedProgress = .definite(value)
            } else if !self.loadingStatuses.isEmpty {
                mappedProgress = .indefinite
            }
            let _ = storyIndicator.update(
                transition: indicatorTransition,
                component: AnyComponent(AvatarStoryIndicatorComponent(
                    hasUnseen: storyStats.unseenCount != 0,
                    hasUnseenCloseFriendsItems: storyStats.hasUnseenCloseFriendsItems,
                    colors: AvatarStoryIndicatorComponent.Colors(
                        unseenColors: storyPresentationParams.colors.unseenColors,
                        unseenCloseFriendsColors: storyPresentationParams.colors.unseenCloseFriendsColors,
                        seenColors: storyPresentationParams.colors.seenColors
                    ),
                    activeLineWidth: activeLineWidth,
                    inactiveLineWidth: inactiveLineWidth,
                    counters: AvatarStoryIndicatorComponent.Counters(
                        totalCount: storyStats.totalCount,
                        unseenCount: storyStats.unseenCount
                    ),
                    progress: mappedProgress,
                    isRoundedRect: self.contentNode.clipStyle == .roundedRect || storyPresentationParams.forceRoundedRect
                )),
                environment: {},
                containerSize: indicatorSize
            )
            if let storyIndicatorView = storyIndicator.view {
                if storyIndicatorView.superview == nil {
                    self.view.insertSubview(storyIndicatorView, aboveSubview: self.contentNode.view)
                }
                indicatorTransition.setFrame(view: storyIndicatorView, frame: CGRect(origin: CGPoint(x: (size.width - indicatorSize.width) * 0.5, y: (size.height - indicatorSize.height) * 0.5), size: indicatorSize))
            }
            transition.setScale(view: self.contentNode.view, scale: avatarScale)
        } else {
            transition.setScale(view: self.contentNode.view, scale: 1.0)
            if let storyIndicator = self.storyIndicator {
                self.storyIndicator = nil
                if let storyIndicatorView = storyIndicator.view {
                    transition.setAlpha(view: storyIndicatorView, alpha: 0.0, completion: { [weak storyIndicatorView] _ in
                        storyIndicatorView?.removeFromSuperview()
                    })
                }
            }
        }
    }
    
    public func cancelLoading() {
        for disposable in self.loadingStatuses.copyItems() {
            disposable.dispose()
        }
        self.loadingStatuses.removeAll()
        self.updateStoryIndicator(transition: .immediate)
    }
    
    public func pushLoadingStatus(signal: Signal<Never, NoError>) -> Disposable {
        let disposable = MetaDisposable()
        
        for d in self.loadingStatuses.copyItems() {
            d.dispose()
        }
        self.loadingStatuses.removeAll()
        
        let index = self.loadingStatuses.add(disposable)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
            self?.updateStoryIndicator(transition: .immediate)
        })
        
        disposable.set(signal.start(completed: { [weak self] in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                if let previousDisposable = self.loadingStatuses.copyItemsWithIndices().first(where: { $0.0 == index })?.1 {
                    previousDisposable.dispose()
                }
                self.loadingStatuses.remove(index)
                if self.loadingStatuses.isEmpty {
                    self.updateStoryIndicator(transition: .immediate)
                }
            }
        }))
        
        return ActionDisposable { [weak self] in
            guard let self else {
                return
            }
            if let previousDisposable = self.loadingStatuses.copyItemsWithIndices().first(where: { $0.0 == index })?.1 {
                previousDisposable.dispose()
            }
            self.loadingStatuses.remove(index)
            if self.loadingStatuses.isEmpty {
                self.updateStoryIndicator(transition: .immediate)
            }
        }
    }
}

