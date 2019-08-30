import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AnimationUI

private let deletedIcon = UIImage(bundleImageName: "Avatar/DeletedIcon")?.precomposed()
private let savedMessagesIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/SavedMessagesIcon"), color: .white)
private let archivedChatsIcon = UIImage(bundleImageName: "Avatar/ArchiveAvatarIcon")?.precomposed()

public enum AvatarNodeClipStyle {
    case none
    case round
}

private class AvatarNodeParameters: NSObject {
    let theme: PresentationTheme?
    let accountPeerId: PeerId?
    let peerId: PeerId?
    let letters: [String]
    let font: UIFont
    let icon: AvatarNodeIcon
    let explicitColorIndex: Int?
    let hasImage: Bool
    let clipStyle: AvatarNodeClipStyle
    
    init(theme: PresentationTheme?, accountPeerId: PeerId?, peerId: PeerId?, letters: [String], font: UIFont, icon: AvatarNodeIcon, explicitColorIndex: Int?, hasImage: Bool, clipStyle: AvatarNodeClipStyle) {
        self.theme = theme
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.letters = letters
        self.font = font
        self.icon = icon
        self.explicitColorIndex = explicitColorIndex
        self.hasImage = hasImage
        self.clipStyle = clipStyle
        
        super.init()
    }
    
    func withUpdatedHasImage(_ hasImage: Bool) -> AvatarNodeParameters {
        return AvatarNodeParameters(theme: self.theme, accountPeerId: self.accountPeerId, peerId: self.peerId, letters: self.letters, font: self.font, icon: self.icon, explicitColorIndex: self.explicitColorIndex, hasImage: hasImage, clipStyle: self.clipStyle)
    }
}

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func generateGradientFilledCircleImage(diameter: CGFloat, colors: NSArray) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.addEllipse(in: bounds)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.size.height), options: CGGradientDrawingOptions())
    })
}

private let grayscaleColors: NSArray = [
    UIColor(rgb: 0xb1b1b1).cgColor, UIColor(rgb: 0xcdcdcd).cgColor
]

private let savedMessagesColors: NSArray = [
    UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor
]

private enum AvatarNodeState: Equatable {
    case empty
    case peerAvatar(PeerId, [String], TelegramMediaImageRepresentation?)
    case custom(letter: [String], explicitColorIndex: Int?)
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.peerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations), .peerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations)):
            return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations
        case let (.custom(lhsLetters, lhsIndex), .custom(rhsLetters, rhsIndex)):
            return lhsLetters == rhsLetters && lhsIndex == rhsIndex
        default:
            return false
    }
}

private enum AvatarNodeIcon: Equatable {
    case none
    case savedMessagesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon
    case deletedIcon
}

public enum AvatarNodeImageOverride: Equatable {
    case none
    case image(TelegramMediaImageRepresentation)
    case savedMessagesIcon
    case archivedChatsIcon(hiddenByDefault: Bool)
    case editAvatarIcon
    case deletedIcon
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
        
        if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIcon"), color: .white) {
            context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0), y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0)), size: editAvatarIcon.size))
        }
    }
}

public final class AvatarNode: ASDisplayNode {
    public var font: UIFont {
        didSet {
            if oldValue !== font {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(theme: parameters.theme, accountPeerId: parameters.accountPeerId, peerId: parameters.peerId, letters: parameters.letters, font: self.font, icon: parameters.icon, explicitColorIndex: parameters.explicitColorIndex, hasImage: parameters.hasImage, clipStyle: parameters.clipStyle)
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
        self.imageNode = ImageNode(enableHasImage: true)
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
        
        self.imageNode.isLayerBacked = true
        self.addSubnode(self.imageNode)
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
            self.imageNode.frame = CGRect(origin: CGPoint(), size: value.size)
            self.editOverlayNode?.frame = self.imageNode.frame
            if updateImage && !self.displaySuspended {
                self.setNeedsDisplay()
                self.editOverlayNode?.setNeedsDisplay()
            }
        }
    }
    
    public func playArchiveAnimation() {
        guard let theme = self.theme else {
            return
        }
        
        var iconColor = theme.chatList.unpinnedArchiveAvatarColor.foregroundColor
        var backgroundColor = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.topColor
        let animationBackgroundNode = ASImageNode()
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
    
    public func setPeer(account: Account, theme: PresentationTheme, peer: Peer?, authorOfMessage: MessageReference? = nil, overrideImage: AvatarNodeImageOverride? = nil, emptyColor: UIColor? = nil, clipStyle: AvatarNodeClipStyle = .round, synchronousLoad: Bool = false) {
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
                case let .archivedChatsIcon(hiddenByDefault):
                    representation = nil
                    icon = .archivedChatsIcon(hiddenByDefault: hiddenByDefault)
                case .editAvatarIcon:
                    representation = peer?.smallProfileImage
                    icon = .editAvatarIcon
                case .deletedIcon:
                    representation = nil
                    icon = .deletedIcon
            }
        } else if peer?.restrictionText(platform: "ios") == nil {
            representation = peer?.smallProfileImage
        }
        let updatedState: AvatarNodeState = .peerAvatar(peer?.id ?? PeerId(namespace: 0, id: 0), peer?.displayLetters ?? [], representation)
        if updatedState != self.state || overrideImage != self.overrideImage || theme !== self.theme {
            self.state = updatedState
            self.overrideImage = overrideImage
            self.theme = theme
            
            let parameters: AvatarNodeParameters
            
            if let peer = peer, let signal = peerAvatarImage(account: account, peer: peer, authorOfMessage: authorOfMessage, representation: representation, emptyColor: emptyColor, synchronousLoad: synchronousLoad) {
                self.contents = nil
                self.displaySuspended = true
                self.imageReady.set(self.imageNode.ready)
                self.imageNode.setSignal(signal)
                
                if case .editAvatarIcon = icon {
                    if self.editOverlayNode == nil {
                        let editOverlayNode = AvatarEditOverlayNode()
                        editOverlayNode.frame = self.imageNode.frame
                        self.addSubnode(editOverlayNode)
                        
                        self.editOverlayNode = editOverlayNode
                    }
                    self.editOverlayNode?.isHidden = false
                } else {
                    self.editOverlayNode?.isHidden = true
                }
                
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer.id, letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: true, clipStyle: clipStyle)
            } else {
                self.imageReady.set(.single(true))
                self.displaySuspended = false
                if self.isNodeLoaded {
                    self.imageNode.contents = nil
                }
                
                self.editOverlayNode?.isHidden = true
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer?.id ?? PeerId(namespace: 0, id: 0), letters: peer?.displayLetters ?? [], font: self.font, icon: icon, explicitColorIndex: nil, hasImage: false, clipStyle: clipStyle)
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
    
    public func setCustomLetters(_ letters: [String], explicitColor: AvatarNodeColorOverride? = nil) {
        var explicitIndex: Int?
        if let explicitColor = explicitColor {
            switch explicitColor {
                case .blue:
                    explicitIndex = 5
            }
        }
        let updatedState: AvatarNodeState = .custom(letter: letters, explicitColorIndex: explicitIndex)
        if updatedState != self.state {
            self.state = updatedState
            
            let parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, letters: letters, font: self.font, icon: .none, explicitColorIndex: explicitIndex, hasImage: false, clipStyle: .round)
            
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
        
        let colorIndex: Int
        if let parameters = parameters as? AvatarNodeParameters {
            if case .round = parameters.clipStyle {
                context.beginPath()
                context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height:
                    bounds.size.height))
                context.clip()
            }
            
            if let explicitColorIndex = parameters.explicitColorIndex {
                colorIndex = explicitColorIndex
            } else {
                if let accountPeerId = parameters.accountPeerId, let peerId = parameters.peerId {
                    if peerId.namespace == -1 {
                        colorIndex = -1
                    } else {
                        colorIndex = abs(Int(clamping: accountPeerId.id &+ peerId.id))
                    }
                } else {
                    colorIndex = -1
                }
            }
        } else {
            colorIndex = -1
        }
        
        let colorsArray: NSArray
        var iconColor = UIColor.white
        if let parameters = parameters as? AvatarNodeParameters, parameters.icon != .none {
            if case .deletedIcon = parameters.icon {
                colorsArray = grayscaleColors
            } else if case .savedMessagesIcon = parameters.icon {
                colorsArray = savedMessagesColors
            } else if case .editAvatarIcon = parameters.icon, let theme = parameters.theme {
                colorsArray = [theme.list.blocksBackgroundColor.cgColor, theme.list.blocksBackgroundColor.cgColor]
            } else if case let .archivedChatsIcon(hiddenByDefault) = parameters.icon, let theme = parameters.theme {
                let backgroundColors: (UIColor, UIColor)
                if hiddenByDefault {
                    iconColor = theme.chatList.unpinnedArchiveAvatarColor.foregroundColor
                    backgroundColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
                } else {
                    iconColor = theme.chatList.pinnedArchiveAvatarColor.foregroundColor
                    backgroundColors = theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
                }
                colorsArray = [backgroundColors.1.cgColor, backgroundColors.0.cgColor]
            } else {
                colorsArray = grayscaleColors
            }
        } else if colorIndex == -1 {
            colorsArray = grayscaleColors
        } else {
            colorsArray = gradientColors[colorIndex % gradientColors.count]
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
            } else if case .savedMessagesIcon = parameters.icon {
                let factor = bounds.size.width / 60.0
                context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                context.scaleBy(x: factor, y: -factor)
                context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                
                if let savedMessagesIcon = savedMessagesIcon {
                    context.draw(savedMessagesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - savedMessagesIcon.size.width) / 2.0), y: floor((bounds.size.height - savedMessagesIcon.size.height) / 2.0)), size: savedMessagesIcon.size))
                }
            } else if case .editAvatarIcon = parameters.icon, let theme = parameters.theme, !parameters.hasImage {
                context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                
                if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIcon"), color: theme.list.freeMonoIconColor) {
                    context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0), y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0)), size: editAvatarIcon.size))
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
                let letters = parameters.letters
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
    
    static func asyncLayout(_ node: AvatarNode?) -> (_ account: Account, _ peer: Peer, _ font: UIFont) -> () -> AvatarNode? {
        let currentState = node?.state
        let createNode = node == nil
        return { [weak node] account, peer, font in
            let state: AvatarNodeState = .peerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage)
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

public func drawPeerAvatarLetters(context: CGContext, size: CGSize, font: UIFont, letters: [String], accountPeerId: PeerId, peerId: PeerId) {
    context.beginPath()
    context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
        size.height))
    context.clip()
    
    let colorIndex: Int
    if peerId.namespace == -1 {
        colorIndex = -1
    } else {
        colorIndex = abs(Int(clamping: accountPeerId.id &+ peerId.id))
    }
    
    let colorsArray: NSArray
    if colorIndex == -1 {
        colorsArray = grayscaleColors
    } else {
        colorsArray = gradientColors[colorIndex % gradientColors.count]
    }
    
    var locations: [CGFloat] = [1.0, 0.0]
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
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
    
    context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    CTLineDraw(line, context)
    context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
}
