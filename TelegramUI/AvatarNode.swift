import Foundation
import AsyncDisplayKit
import Postbox
import UIKit
import Display
import TelegramCore
import SwiftSignalKit

private let savedMessagesIcon = UIImage(bundleImageName: "Avatar/SavedMessagesIcon")?.precomposed()

private class AvatarNodeParameters: NSObject {
    let theme: PresentationTheme?
    let accountPeerId: PeerId?
    let peerId: PeerId?
    let letters: [String]
    let font: UIFont
    let icon: AvatarNodeIcon
    let explicitColorIndex: Int?
    let hasImage: Bool
    
    init(theme: PresentationTheme?, accountPeerId: PeerId?, peerId: PeerId?, letters: [String], font: UIFont, icon: AvatarNodeIcon, explicitColorIndex: Int?, hasImage: Bool) {
        self.theme = theme
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.letters = letters
        self.font = font
        self.icon = icon
        self.explicitColorIndex = explicitColorIndex
        self.hasImage = hasImage
        
        super.init()
    }
    
    func withUpdatedHasImage(_ hasImage: Bool) -> AvatarNodeParameters {
        return AvatarNodeParameters(theme: self.theme, accountPeerId: self.accountPeerId, peerId: self.peerId, letters: self.letters, font: self.font, icon: self.icon, explicitColorIndex: self.explicitColorIndex, hasImage: hasImage)
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

enum AvatarNodeIcon {
    case none
    case savedMessagesIcon
    case editAvatarIcon
}

public enum AvatarNodeImageOverride {
    case none
    case image(TelegramMediaImageRepresentation)
    case savedMessagesIcon
    case editAvatarIcon
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
    var font: UIFont {
        didSet {
            if oldValue !== font {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(theme: parameters.theme, accountPeerId: parameters.accountPeerId, peerId: parameters.peerId, letters: parameters.letters, font: self.font, icon: parameters.icon, explicitColorIndex: parameters.explicitColorIndex, hasImage: parameters.hasImage)
                }
                
                if !self.displaySuspended {
                    self.setNeedsDisplay()
                }
            }
        }
    }
    private var parameters: AvatarNodeParameters?
    private var theme: PresentationTheme?
    let imageNode: ImageNode
    var editOverlayNode: AvatarEditOverlayNode?
    
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
        
        if #available(iOSApplicationExtension 11.0, *), !self.isLayerBacked {
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
    
    public func setPeer(account: Account, peer: Peer, authorOfMessage: MessageReference? = nil, overrideImage: AvatarNodeImageOverride? = nil, emptyColor: UIColor? = nil, synchronousLoad: Bool = false) {
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
                case .editAvatarIcon:
                    representation = peer.smallProfileImage
                    icon = .editAvatarIcon
            }
        } else if peer.restrictionText == nil {
            representation = peer.smallProfileImage
        }
        let updatedState: AvatarNodeState = .peerAvatar(peer.id, peer.displayLetters, representation)
        if updatedState != self.state {
            self.state = updatedState
            
            let parameters: AvatarNodeParameters
            
            self.displaySuspended = true
            self.contents = nil
            
            let theme = account.telegramApplicationContext.currentPresentationData.with { $0 }.theme
            
            if let signal = peerAvatarImage(account: account, peer: peer, authorOfMessage: authorOfMessage, representation: representation, emptyColor: emptyColor, synchronousLoad: synchronousLoad) {
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
                
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer.id, letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: true)
            } else {
                self.imageReady.set(.single(true))
                self.displaySuspended = false
                if self.isNodeLoaded {
                    self.imageNode.contents = nil
                }
                
                self.editOverlayNode?.isHidden = true
                parameters = AvatarNodeParameters(theme: theme, accountPeerId: account.peerId, peerId: peer.id, letters: peer.displayLetters, font: self.font, icon: icon, explicitColorIndex: nil, hasImage: false)
            }
            if self.parameters == nil || self.parameters != parameters {
                self.parameters = parameters
                self.setNeedsDisplay()
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
            
            let parameters = AvatarNodeParameters(theme: nil, accountPeerId: nil, peerId: nil, letters: letters, font: self.font, icon: .none, explicitColorIndex: explicitIndex, hasImage: false)
            
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
        
        context.beginPath()
        context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height:
            bounds.size.height))
        context.clip()
        
        let colorIndex: Int
        if let parameters = parameters as? AvatarNodeParameters {
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
        if let parameters = parameters as? AvatarNodeParameters, parameters.icon != .none {
            if case .savedMessagesIcon = parameters.icon {
                colorsArray = savedMessagesColors
            } else if case .editAvatarIcon = parameters.icon, let theme = parameters.theme {
                colorsArray = [ theme.list.blocksBackgroundColor.cgColor, theme.list.blocksBackgroundColor.cgColor ]
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
            if case .savedMessagesIcon = parameters.icon {
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
                
                if let editAvatarIcon = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIcon"), color: theme.list.freeMonoIcon) {
                    context.draw(editAvatarIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - editAvatarIcon.size.width) / 2.0), y: floor((bounds.size.height - editAvatarIcon.size.height) / 2.0)), size: editAvatarIcon.size))
                }
            } else {
                let letters = parameters.letters
                let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
                let attributedString = NSAttributedString(string: string, attributes: [NSAttributedStringKey.font: parameters.font, NSAttributedStringKey.foregroundColor: UIColor.white])
                
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
