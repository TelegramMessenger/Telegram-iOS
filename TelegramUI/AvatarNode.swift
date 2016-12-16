import Foundation
import AsyncDisplayKit
import Postbox
import UIKit
import Display
import TelegramCore

private class AvatarNodeParameters: NSObject {
    let account: Account
    let peerId: PeerId
    let letters: [String]
    let font: UIFont
    
    init(account: Account, peerId: PeerId, letters: [String], font: UIFont) {
        self.account = account
        self.peerId = peerId
        self.letters = letters
        self.font = font
        
        super.init()
    }
}

let gradientColors: [NSArray] = [
    [UIColor(0xff516a).cgColor, UIColor(0xff885e).cgColor],
    [UIColor(0xffa85c).cgColor, UIColor(0xffcd6a).cgColor],
    [UIColor(0x54cb68).cgColor, UIColor(0xa0de7e).cgColor],
    [UIColor(0x2a9ef1).cgColor, UIColor(0x72d5fd).cgColor],
    [UIColor(0x665fff).cgColor, UIColor(0x82b1ff).cgColor],
    [UIColor(0xd669ed).cgColor, UIColor(0xe0a2f3).cgColor]
]

private enum AvatarNodeState: Equatable {
    case Empty
    case PeerAvatar(PeerId, [String], TelegramMediaImageRepresentation?)
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
        case (.Empty, .Empty):
            return true
        case let (.PeerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations), .PeerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations)):
            return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations
        default:
            return false
    }
}

public final class AvatarNode: ASDisplayNode {
    var font: UIFont {
        didSet {
            if oldValue !== font {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(account: parameters.account, peerId: parameters.peerId, letters: parameters.letters, font: self.font)
                }
                
                if !self.displaySuspended {
                    self.setNeedsDisplay()
                }
            }
        }
    }
    private var parameters: AvatarNodeParameters?
    let imageNode: ImageNode
    
    private var state: AvatarNodeState = .Empty
    
    public init(font: UIFont) {
        self.font = font
        self.imageNode = ImageNode()
        
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
    
    public func setPeer(account: Account, peer: Peer) {
        let updatedState = AvatarNodeState.PeerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage)
        if updatedState != self.state {
            self.state = updatedState
            
            let parameters = AvatarNodeParameters(account: account, peerId: peer.id, letters: peer.displayLetters, font: self.font)
            
            self.displaySuspended = true
            self.contents = nil
            
            if let signal = peerAvatarImage(account: account, peer: peer) {
                self.imageNode.setSignal(signal)
            } else {
                self.displaySuspended = false
            }
            if self.parameters == nil || self.parameters != parameters {
                self.parameters = parameters
                self.setNeedsDisplay()
            }
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol {
        return parameters ?? NSObject()
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: () -> Bool, isRasterizing: Bool) {
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
            colorIndex = Int(parameters.account.peerId.id + parameters.peerId.id)
        } else {
            colorIndex = 0
        }
        
        let colorsArray: NSArray = gradientColors[colorIndex % gradientColors.count]
        
        var locations: [CGFloat] = [1.0, 0.2];
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.size.height), options: CGGradientDrawingOptions())
        
        context.setBlendMode(.normal)
        
        if let parameters = parameters as? AvatarNodeParameters {
            let letters = parameters.letters
            let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
            let attributedString = NSAttributedString(string: string, attributes: [NSFontAttributeName: parameters.font, NSForegroundColorAttributeName: UIColor.white])
            
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
