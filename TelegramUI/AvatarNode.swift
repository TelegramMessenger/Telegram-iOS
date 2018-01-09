import Foundation
import AsyncDisplayKit
import Postbox
import UIKit
import Display
import TelegramCore
import SwiftSignalKit

private let savedMessagesIcon = UIImage(bundleImageName: "Avatar/SavedMessagesIcon")?.precomposed()

private class AvatarNodeParameters: NSObject {
    let accountPeerId: PeerId?
    let peerId: PeerId?
    let letters: [String]
    let font: UIFont
    let savedMessagesIcon: Bool
    
    init(accountPeerId: PeerId?, peerId: PeerId?, letters: [String], font: UIFont, savedMessagesIcon: Bool) {
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.letters = letters
        self.font = font
        self.savedMessagesIcon = savedMessagesIcon
        
        super.init()
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
    UIColor(rgb: 0xefefef).cgColor, UIColor(rgb: 0xeeeeee).cgColor
]
    
private let savedMessagesColors: NSArray = [
    UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor
]

private enum AvatarNodeState: Equatable {
    case empty
    case peerAvatar(PeerId, [String], TelegramMediaImageRepresentation?)
    case custom([String])
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.peerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations), .peerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations)):
            return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations
        case let (.custom(lhsLetters), .custom(rhsLetters)):
            return lhsLetters == rhsLetters
        default:
            return false
    }
}

public enum AvatarNodeImageOverride {
    case none
    case image(TelegramMediaImageRepresentation)
    case savedMessagesIcon
}

public final class AvatarNode: ASDisplayNode {
    var font: UIFont {
        didSet {
            if oldValue !== font {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(accountPeerId: parameters.accountPeerId, peerId: parameters.peerId, letters: parameters.letters, font: self.font, savedMessagesIcon: parameters.savedMessagesIcon)
                }
                
                if !self.displaySuspended {
                    self.setNeedsDisplay()
                }
            }
        }
    }
    private var parameters: AvatarNodeParameters?
    let imageNode: ImageNode
    
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
    
    override public var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let updateImage = !value.size.equalTo(super.frame.size)
            super.frame = value
            self.imageNode.frame = CGRect(origin: CGPoint(), size: value.size)
            if updateImage && !self.displaySuspended {
                self.setNeedsDisplay()
            }
        }
    }
    
    public func setPeer(account: Account, peer: Peer, overrideImage: AvatarNodeImageOverride? = nil) {
        var representation: TelegramMediaImageRepresentation?
        var savedMessagesIcon = false
        if let overrideImage = overrideImage {
            switch overrideImage {
                case .none:
                    representation = nil
                case let .image(image):
                    representation = image
                case .savedMessagesIcon:
                    representation = nil
                    savedMessagesIcon = true
            }
        } else {
            representation = peer.smallProfileImage
        }
        let updatedState: AvatarNodeState = .peerAvatar(peer.id, peer.displayLetters, representation)
        if updatedState != self.state {
            self.state = updatedState
            
            let parameters = AvatarNodeParameters(accountPeerId: account.peerId, peerId: peer.id, letters: peer.displayLetters, font: self.font, savedMessagesIcon: savedMessagesIcon)
            
            self.displaySuspended = true
            self.contents = nil
            
            if let signal = peerAvatarImage(account: account, representation: representation) {
                self.imageReady.set(self.imageNode.ready)
                self.imageNode.setSignal(signal)
            } else {
                self.imageReady.set(.single(true))
                self.displaySuspended = false
                if self.isNodeLoaded {
                    self.imageNode.contents = nil
                }
            }
            if self.parameters == nil || self.parameters != parameters {
                self.parameters = parameters
                self.setNeedsDisplay()
            }
        }
    }
    
    public func setCustomLetters(_ letters: [String]) {
        let updatedState: AvatarNodeState = .custom(letters)
        if updatedState != self.state {
            self.state = updatedState
            
            let parameters = AvatarNodeParameters(accountPeerId: nil, peerId: nil, letters: letters, font: self.font, savedMessagesIcon: false)
            
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
            if let accountPeerId = parameters.accountPeerId, let peerId = parameters.peerId {
                colorIndex = abs(Int(accountPeerId.id + peerId.id))
            } else {
                colorIndex = -1
            }
        } else {
            colorIndex = -1
        }
        
        let colorsArray: NSArray
        if let parameters = parameters as? AvatarNodeParameters, parameters.savedMessagesIcon {
            colorsArray = savedMessagesColors
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
            if parameters.savedMessagesIcon {
                let factor = bounds.size.width / 60.0
                context.translateBy(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
                context.scaleBy(x: factor, y: -factor)
                context.translateBy(x: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                
                if let savedMessagesIcon = savedMessagesIcon {
                    context.draw(savedMessagesIcon.cgImage!, in: CGRect(origin: CGPoint(x: floor((bounds.size.width - savedMessagesIcon.size.width) / 2.0), y: floor((bounds.size.height - savedMessagesIcon.size.height) / 2.0)), size: savedMessagesIcon.size))
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
