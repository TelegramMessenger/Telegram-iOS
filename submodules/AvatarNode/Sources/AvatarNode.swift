import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AnimationUI
import AppBundle
import AccountContext
import Emoji
import Accelerate

private let deletedIcon = UIImage(bundleImageName: "Avatar/DeletedIcon")?.precomposed()
private let phoneIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/PhoneIcon"), color: .white)
public let savedMessagesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/SavedMessagesIcon"), color: .white)
private let archivedChatsIcon = UIImage(bundleImageName: "Avatar/ArchiveAvatarIcon")?.precomposed()
private let repliesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/RepliesMessagesIcon"), color: .white)

public func avatarPlaceholderFont(size: CGFloat) -> UIFont {
    return Font.with(size: size, design: .round, weight: .bold)
}

public enum AvatarNodeClipStyle {
    case none
    case round
    case roundedRect
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
    
    init(theme: PresentationTheme?, accountPeerId: EnginePeer.Id?, peerId: EnginePeer.Id?, colors: [UIColor], letters: [String], font: UIFont, icon: AvatarNodeIcon, explicitColorIndex: Int?, hasImage: Bool, clipStyle: AvatarNodeClipStyle) {
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
        
        super.init()
    }
    
    func withUpdatedHasImage(_ hasImage: Bool) -> AvatarNodeParameters {
        return AvatarNodeParameters(theme: self.theme, accountPeerId: self.accountPeerId, peerId: self.peerId, colors: self.colors, letters: self.letters, font: self.font, icon: self.icon, explicitColorIndex: self.explicitColorIndex, hasImage: hasImage, clipStyle: self.clipStyle)
    }
}

private let grayscaleColors: [UIColor] = [
    UIColor(rgb: 0xb1b1b1), UIColor(rgb: 0xcdcdcd)
]

private let savedMessagesColors: [UIColor] = [
    UIColor(rgb: 0x2a9ef1), UIColor(rgb: 0x72d5fd)
]

private func calculateColors(explicitColorIndex: Int?, peerId: EnginePeer.Id?, icon: AvatarNodeIcon, theme: PresentationTheme?) -> [UIColor] {
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
            colors = grayscaleColors
        } else if case .phoneIcon = icon {
            colors = grayscaleColors
        } else if case .savedMessagesIcon = icon {
            colors = savedMessagesColors
        } else if case .repliesIcon = icon {
            colors = savedMessagesColors
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
        } else {
            colors = grayscaleColors
        }
    } else if colorIndex == -1 {
        if let theme {
            let backgroundColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
            colors = [backgroundColors.1, backgroundColors.0]
        } else {
            colors = grayscaleColors
        }
    } else {
        colors = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count]
    }
    
    return colors
}

public enum AvatarNodeExplicitIcon {
    case phone
}

private enum AvatarNodeState: Equatable {
    case empty
    case peerAvatar(EnginePeer.Id, [String], TelegramMediaImageRepresentation?, AvatarNodeClipStyle)
    case custom(letter: [String], explicitColorIndex: Int?, explicitIcon: AvatarNodeExplicitIcon?)
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.peerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations, lhsClipStyle), .peerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations, rhsClipStyle)):
            return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations && lhsClipStyle == rhsClipStyle
        case let (.custom(lhsLetters, lhsIndex, lhsIcon), .custom(rhsLetters, rhsIndex, rhsIcon)):
            return lhsLetters == rhsLetters && lhsIndex == rhsIndex && lhsIcon == rhsIcon
        default:
            return false
    }
}

private enum AvatarNodeIcon: Equatable {
    case none
    case savedMessagesIcon
    case repliesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon
    case deletedIcon
    case phoneIcon
}

public enum AvatarNodeImageOverride: Equatable {
    case none
    case image(TelegramMediaImageRepresentation)
    case savedMessagesIcon
    case repliesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon(forceNone: Bool)
    case deletedIcon
    case phoneIcon
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

public final class AvatarNode: ASDisplayNode {
    public static let gradientColors: [[UIColor]] = [
        [UIColor(rgb: 0xff516a), UIColor(rgb: 0xff885e)],
        [UIColor(rgb: 0xffa85c), UIColor(rgb: 0xffcd6a)],
        [UIColor(rgb: 0x665fff), UIColor(rgb: 0x82b1ff)],
        [UIColor(rgb: 0x54cb68), UIColor(rgb: 0xa0de7e)],
        [UIColor(rgb: 0x4acccd), UIColor(rgb: 0x00fcfd)],
        [UIColor(rgb: 0x2a9ef1), UIColor(rgb: 0x72d5fd)],
        [UIColor(rgb: 0xd669ed), UIColor(rgb: 0xe0a2f3)],
    ]
    
    public var font: UIFont {
        didSet {
            if oldValue.pointSize != font.pointSize {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(theme: parameters.theme, accountPeerId: parameters.accountPeerId, peerId: parameters.peerId, colors: parameters.colors, letters: parameters.letters, font: self.font, icon: parameters.icon, explicitColorIndex: parameters.explicitColorIndex, hasImage: parameters.hasImage, clipStyle: parameters.clipStyle)
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
    private var animationBackgroundNode: ImageNode?
    private var animationNode: AnimationNode?
    public var editOverlayNode: AvatarEditOverlayNode?
    
    private let imageReadyDisposable = MetaDisposable()
    private var state: AvatarNodeState = .empty
    
    public var unroundedImage: UIImage?
    private var currentImage: UIImage?
    
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
        
        self.imageNode.isLayerBacked = true
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
    
    override public func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
            self.view.accessibilityIgnoresInvertColors = true
        }
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
    
    public func updateSize(size: CGSize) {
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        self.editOverlayNode?.frame = self.imageNode.frame
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
    
    public func setPeer(context genericContext: AccountContext, account: Account? = nil, theme: PresentationTheme, peer: EnginePeer?, authorOfMessage: MessageReference? = nil, overrideImage: AvatarNodeImageOverride? = nil, emptyColor: UIColor? = nil, clipStyle: AvatarNodeClipStyle = .round, synchronousLoad: Bool = false, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), storeUnrounded: Bool = false) {
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
                case .repliesIcon:
                    representation = nil
                    icon = .repliesIcon
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
            }
        } else if peer?.restrictionText(platform: "ios", contentSettings: genericContext.currentContentSettings.with { $0 }) == nil {
            representation = peer?.smallProfileImage
        }
        let updatedState: AvatarNodeState = .peerAvatar(peer?.id ?? EnginePeer.Id(0), peer?.displayLetters ?? [], representation, clipStyle)
        if updatedState != self.state || overrideImage != self.overrideImage || theme !== self.theme {
            self.state = updatedState
            self.overrideImage = overrideImage
            self.theme = theme
            
            let parameters: AvatarNodeParameters
            
            let account = account ?? genericContext.account
            
            if let peer = peer, let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: authorOfMessage, representation: representation, displayDimensions: displayDimensions, clipStyle: clipStyle, emptyColor: emptyColor, synchronousLoad: synchronousLoad, provideUnrounded: storeUnrounded) {
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
                
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer.id, colors: calculateColors(explicitColorIndex: nil, peerId: peer.id, icon: icon, theme: theme), letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: true, clipStyle: clipStyle)
            } else {
                self.imageReady.set(.single(true))
                self.displaySuspended = false
                if self.isNodeLoaded {
                    self.imageNode.contents = nil
                }
                
                self.editOverlayNode?.isHidden = true
                let colors = calculateColors(explicitColorIndex: nil, peerId: peer?.id ?? EnginePeer.Id(0), icon: icon, theme: theme)
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer?.id ?? EnginePeer.Id(0), colors: colors, letters: peer?.displayLetters ?? [], font: self.font, icon: icon, explicitColorIndex: nil, hasImage: false, clipStyle: clipStyle)
                
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
    
    public func setCustomLetters(_ letters: [String], explicitColor: AvatarNodeColorOverride? = nil, icon: AvatarNodeExplicitIcon? = nil) {
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
                parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, colors: calculateColors(explicitColorIndex: explicitIndex, peerId: nil, icon: .phoneIcon, theme: nil), letters: [], font: self.font, icon: .phoneIcon, explicitColorIndex: explicitIndex, hasImage: false, clipStyle: .round)
            } else {
                parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, colors: calculateColors(explicitColorIndex: explicitIndex, peerId: nil, icon: .none, theme: nil), letters: letters, font: self.font, icon: .none, explicitColorIndex: explicitIndex, hasImage: false, clipStyle: .round)
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
        assertNotOnMainThread()
        
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
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
            }
        } else {
            colors = grayscaleColors
        }
        
        let colorsArray: NSArray = colors.map(\.cgColor) as NSArray
        
        var iconColor = UIColor.white
        if let parameters = parameters as? AvatarNodeParameters, parameters.icon != .none {
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
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.size.height), options: CGGradientDrawingOptions())
        
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
            } else if case .repliesIcon = parameters.icon {
                let factor = bounds.size.width / 60.0
                context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                context.scaleBy(x: factor, y: -factor)
                context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                
                if let repliesIcon = repliesIcon {
                    context.draw(repliesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - repliesIcon.size.width) / 2.0), y: floor((bounds.size.height - repliesIcon.size.height) / 2.0)), size: repliesIcon.size))
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
    }
    
    static func asyncLayout(_ node: AvatarNode?) -> (_ context: AccountContext, _ peer: EnginePeer, _ font: UIFont) -> () -> AvatarNode? {
        let currentState = node?.state
        let createNode = node == nil
        return { [weak node] context, peer, font in
            let state: AvatarNodeState = .peerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage, .round)
            if currentState != state {
            }
            var createdNode: AvatarNode?
            if createNode {
                createdNode = AvatarNode(font: font)
            }
            return {
                let updatedNode: AvatarNode?
                if let createdNode = createdNode {
                    updatedNode = createdNode
                } else {
                    updatedNode = node
                }
                if let updatedNode = updatedNode {
                    return updatedNode
                } else {
                    return nil
                }
            }
        }
    }
}

public func drawPeerAvatarLetters(context: CGContext, size: CGSize, round: Bool = true, font: UIFont, letters: [String], peerId: EnginePeer.Id) {
    if round {
        context.beginPath()
        context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
            size.height))
        context.clip()
    }
    
    let colorIndex: Int
    if peerId.namespace == .max {
        colorIndex = -1
    } else {
        colorIndex = Int(clamping: abs(peerId.id._internalGetInt64Value()))
    }
    
    let colorsArray: NSArray
    if colorIndex == -1 {
        colorsArray = grayscaleColors.map(\.cgColor) as NSArray
    } else {
        colorsArray = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count].map(\.cgColor) as NSArray
    }
    
    var locations: [CGFloat] = [1.0, 0.0]
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context.resetClip()
    
    context.setBlendMode(.normal)
    
    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.white])
    
    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    
    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
    
    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context.scaleBy(x: 1.0, y: -1.0)
    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    let textPosition = context.textPosition
    context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    CTLineDraw(line, context)
    context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    context.textPosition = textPosition
}

public enum AvatarBackgroundColor {
    case blue
    case yellow
    case green
    case purple
    case red
    case violet
}

public func generateAvatarImage(size: CGSize, icon: UIImage?, iconScale: CGFloat = 1.0, color: AvatarBackgroundColor) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.beginPath()
        context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
            size.height))
        context.clip()
        
        let colorIndex: Int
        switch color {
        case .blue:
            colorIndex = 5
        case .yellow:
            colorIndex = 1
        case .green:
            colorIndex = 3
        case .purple:
            colorIndex = 2
        case .red:
            colorIndex = 0
        case .violet:
            colorIndex = 6
        }
        
        let colorsArray: NSArray
        if colorIndex == -1 {
            colorsArray = grayscaleColors.map(\.cgColor) as NSArray
        } else {
            colorsArray = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count].map(\.cgColor) as NSArray
        }
        
        var locations: [CGFloat] = [1.0, 0.0]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        context.setBlendMode(.normal)
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let icon = icon {
            let iconSize = CGSize(width: icon.size.width * iconScale, height: icon.size.height * iconScale)
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            context.draw(icon.cgImage!, in: iconFrame)
        }
    })
}

public final class AvatarBadgeView: UIImageView {
    enum OriginalContent: Equatable {
        case color(UIColor)
        case image(UIImage)
        
        static func ==(lhs: OriginalContent, rhs: OriginalContent) -> Bool {
            switch lhs {
            case let .color(color):
                if case .color(color) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(lhsImage):
                if case let .image(rhsImage) = rhs {
                    return lhsImage === rhsImage
                } else {
                    return false
                }
            }
        }
    }
    
    private struct Parameters: Equatable {
        var size: CGSize
        var text: String
    }
    
    private var originalContent: OriginalContent?
    private var parameters: Parameters?
    private var hasContent: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(content: OriginalContent) {
        if self.originalContent != content || !self.hasContent {
            self.originalContent = content
            self.update()
        }
    }
    
    public func update(size: CGSize, text: String) {
        let parameters = Parameters(size: size, text: text)
        if self.parameters != parameters || !self.hasContent {
            self.parameters = parameters
            self.update()
        }
    }
    
    private func update() {
        guard let originalContent = self.originalContent, let parameters = self.parameters else {
            return
        }
        
        self.hasContent = true
        
        let blurredWidth = 16
        let blurredHeight = 16
        guard let blurredContext = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0, opaque: true) else {
            return
        }
        let blurredSize = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))
        blurredContext.withContext { c in
            switch originalContent {
            case let .color(color):
                c.setFillColor(color.cgColor)
                c.fill(CGRect(origin: CGPoint(), size: blurredSize))
            case let .image(image):
                c.setFillColor(UIColor.black.cgColor)
                c.fill(CGRect(origin: CGPoint(), size: blurredSize))
                
                c.scaleBy(x: blurredSize.width / parameters.size.width, y: blurredSize.height / parameters.size.height)
                let offsetFactor: CGFloat = 1.0 - 0.6
                let imageFrame = CGRect(origin: CGPoint(x: parameters.size.width - image.size.width + offsetFactor * parameters.size.width, y: parameters.size.height - image.size.height + offsetFactor * parameters.size.height), size: image.size)
                
                UIGraphicsPushContext(c)
                image.draw(in: imageFrame)
                UIGraphicsPopContext()
            }
        }
        
        var rSum: Int64 = 0
        var gSum: Int64 = 0
        var bSum: Int64 = 0
        for y in 0 ..< blurredHeight {
            let row = blurredContext.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: y * blurredContext.bytesPerRow)
            for x in 0 ..< blurredWidth {
                let pixel = row.advanced(by: x * 4)
                bSum += Int64(pixel.advanced(by: 0).pointee)
                gSum += Int64(pixel.advanced(by: 1).pointee)
                rSum += Int64(pixel.advanced(by: 2).pointee)
            }
        }
        let colorNorm = CGFloat(blurredWidth * blurredHeight)
        let invColorNorm: CGFloat = 1.0 / (255.0 * colorNorm)
        let aR = CGFloat(rSum) * invColorNorm
        let aG = CGFloat(gSum) * invColorNorm
        let aB = CGFloat(bSum) * invColorNorm
        let luminance: CGFloat = 0.299 * aR + 0.587 * aG + 0.114 * aB
        
        let isLightImage = luminance > 0.9
        
        var brightness: CGFloat = 1.0
        if isLightImage {
            brightness = 0.99
        } else {
            brightness = 0.94
        }
            
        var destinationBuffer = vImage_Buffer()
        destinationBuffer.width = UInt(blurredWidth)
        destinationBuffer.height = UInt(blurredHeight)
        destinationBuffer.data = blurredContext.bytes
        destinationBuffer.rowBytes = blurredContext.bytesPerRow
        
        vImageBoxConvolve_ARGB8888(
            &destinationBuffer,
            &destinationBuffer,
            nil,
            0, 0,
            UInt32(15),
            UInt32(15),
            nil,
            vImage_Flags(kvImageTruncateKernel | kvImageDoNotTile)
        )
        
        let divisor: Int32 = 0x1000

        let rwgt: CGFloat = 0.3086
        let gwgt: CGFloat = 0.6094
        let bwgt: CGFloat = 0.0820

        let adjustSaturation: CGFloat = 1.7

        let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
        let b = (1.0 - adjustSaturation) * rwgt
        let c = (1.0 - adjustSaturation) * rwgt
        let d = (1.0 - adjustSaturation) * gwgt
        let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
        let f = (1.0 - adjustSaturation) * gwgt
        let g = (1.0 - adjustSaturation) * bwgt
        let h = (1.0 - adjustSaturation) * bwgt
        let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

        let satMatrix: [CGFloat] = [
            a, b, c, 0,
            d, e, f, 0,
            g, h, i, 0,
            0, 0, 0, 1
        ]
        
        let brighnessMatrix: [CGFloat] = [
            brightness, 0, 0, 0,
            0, brightness, 0, 0,
            0, 0, brightness, 0,
            0, 0, 0, 1
        ]
        
        func matrixMul(a: [CGFloat], b: [CGFloat], result: inout [CGFloat]) {
            for i in 0 ..< 4 {
                for j in 0 ..< 4 {
                    var sum: CGFloat = 0.0
                    for k in 0 ..< 4 {
                        sum += a[i + k * 4] * b[k + j * 4]
                    }
                    result[i + j * 4] = sum
                }
            }
        }
        
        var resultMatrix = Array<CGFloat>(repeating: 0.0, count: 4 * 4)
        matrixMul(a: satMatrix, b: brighnessMatrix, result: &resultMatrix)

        var matrix: [Int16] = resultMatrix.map { value in
            return Int16(value * CGFloat(divisor))
        }

        vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
        
        guard let blurredImage = blurredContext.generateImage() else {
            return
        }
        
        self.image = generateImage(parameters.size, rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.black.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            blurredImage.draw(in: CGRect(origin: CGPoint(), size: size), blendMode: .sourceIn, alpha: 1.0)
            
            context.setBlendMode(.normal)
            
            let textColor: UIColor
            if isLightImage {
                textColor = UIColor(white: 0.7, alpha: 1.0)
            } else {
                textColor = .white
            }
            
            var fontSize: CGFloat = floor(parameters.size.height * 0.48)
            while true {
                let string = NSAttributedString(string: parameters.text, font: Font.bold(fontSize), textColor: textColor)
                let stringBounds = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                
                if stringBounds.width <= size.width - 5.0 * 2.0 || fontSize <= 2.0 {
                    string.draw(at: CGPoint(x: stringBounds.minX + floorToScreenPixels((size.width - stringBounds.width) / 2.0), y: stringBounds.minY + floorToScreenPixels((size.height - stringBounds.height) / 2.0)))
                    break
                } else {
                    fontSize -= 1.0
                }
            }
            
            let lineWidth: CGFloat = 1.5
            let lineInset: CGFloat = 2.0
            let lineRadius: CGFloat = size.width * 0.5 - lineInset - lineWidth * 0.5
            context.setLineWidth(lineWidth)
            context.setStrokeColor(textColor.cgColor)
            context.setLineCap(.round)
            
            context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: CGFloat.pi * 0.5, endAngle: -CGFloat.pi * 0.5, clockwise: false)
            context.strokePath()
            
            let sectionAngle: CGFloat = CGFloat.pi / 11.0
            
            for i in 0 ..< 10 {
                if i % 2 == 0 {
                    continue
                }
                
                let startAngle = CGFloat.pi * 0.5 - CGFloat(i) * sectionAngle - sectionAngle * 0.15
                let endAngle = startAngle - sectionAngle * 0.75
                
                context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                context.strokePath()
            }
            
            /*if isLightImage {
                context.setLineWidth(UIScreenPixel)
                context.setStrokeColor(textColor.withMultipliedAlpha(1.0).cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: UIScreenPixel * 0.5, dy: UIScreenPixel * 0.5))
            }*/
            
            UIGraphicsPopContext()
        })
    }
}
