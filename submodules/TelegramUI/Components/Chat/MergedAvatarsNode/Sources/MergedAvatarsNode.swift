import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import Postbox
import TelegramCore
import AvatarNode
import AccountContext

private enum PeerAvatarReference: Equatable {
    case letters(PeerId, PeerColor?, [String])
    case image(PeerReference, TelegramMediaImageRepresentation)
    
    var peerId: PeerId {
        switch self {
        case let .letters(value, _, _):
            return value
        case let .image(value, _):
            return value.id
        }
    }
}

private extension PeerAvatarReference {
    init(peer: Peer) {
        if let photo = peer.smallProfileImage, let peerReference = PeerReference(peer) {
            self = .image(peerReference, photo)
        } else {
            self = .letters(peer.id, peer.nameColor, peer.displayLetters)
        }
    }
}

private final class MergedAvatarsNodeArguments: NSObject {
    let peers: [PeerAvatarReference]
    let images: [PeerId: UIImage]
    let imageSize: CGFloat
    let imageSpacing: CGFloat
    let borderWidth: CGFloat
    let avatarFontSize: CGFloat
    
    init(peers: [PeerAvatarReference], images: [PeerId: UIImage], imageSize: CGFloat, imageSpacing: CGFloat, borderWidth: CGFloat, avatarFontSize: CGFloat) {
        self.peers = peers
        self.images = images
        self.imageSize = imageSize
        self.imageSpacing = imageSpacing
        self.borderWidth = borderWidth
        self.avatarFontSize = avatarFontSize
    }
}

private let defaultMergedImageSize: CGFloat = 16.0
private let defaultMergedImageSpacing: CGFloat = 15.0
private let defaultBorderWidth: CGFloat = 1.0

public final class MergedAvatarsNode: ASDisplayNode {
    public static let defaultMergedImageSize: CGFloat = 16.0
    public static let defaultMergedImageSpacing: CGFloat = 15.0
    public static let defaultBorderWidth: CGFloat = 1.0
    public static let defaultAvatarFontSize: CGFloat = 8.0
    
    private var peers: [PeerAvatarReference] = []
    private var images: [PeerId: UIImage] = [:]
    private var disposables: [PeerId: Disposable] = [:]
    private let buttonNode: HighlightTrackingButtonNode
    private var imageSize: CGFloat = defaultMergedImageSize
    private var imageSpacing: CGFloat = defaultMergedImageSpacing
    private var borderWidthValue: CGFloat = defaultBorderWidth
    private var avatarFontSize: CGFloat = defaultAvatarFontSize
    
    public var pressed: (() -> Void)?
    
    override public init() {
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.addSubnode(self.buttonNode)
    }
    
    deinit {
        for (_, disposable) in self.disposables {
            disposable.dispose()
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    public func updateLayout(size: CGSize) {
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    public func update(context: AccountContext, peers: [Peer], synchronousLoad: Bool, imageSize: CGFloat, imageSpacing: CGFloat, borderWidth: CGFloat, avatarFontSize: CGFloat = 8.0) {
        self.imageSize = imageSize
        self.imageSpacing = imageSpacing
        self.borderWidthValue = borderWidth
        self.avatarFontSize = avatarFontSize
        
        var filteredPeers = peers.map(PeerAvatarReference.init)
        if filteredPeers.count > 3 {
            filteredPeers = filteredPeers.dropLast(filteredPeers.count - 3)
        }
        if filteredPeers != self.peers {
            self.peers = filteredPeers
            
            var validImageIds: [PeerId] = []
            for peer in filteredPeers {
                if case .image = peer {
                    validImageIds.append(peer.peerId)
                }
            }
            
            var removedImageIds: [PeerId] = []
            for (id, _) in self.images {
                if !validImageIds.contains(id) {
                    removedImageIds.append(id)
                }
            }
            var removedDisposableIds: [PeerId] = []
            for (id, disposable) in self.disposables {
                if !validImageIds.contains(id) {
                    disposable.dispose()
                    removedDisposableIds.append(id)
                }
            }
            for id in removedImageIds {
                self.images.removeValue(forKey: id)
            }
            for id in removedDisposableIds {
                self.disposables.removeValue(forKey: id)
            }
            for peer in filteredPeers {
                switch peer {
                case let .image(peerReference, representation):
                    if self.disposables[peer.peerId] == nil {
                        if let signal = peerAvatarImage(account: context.account, peerReference: peerReference, authorOfMessage: nil, representation: representation, displayDimensions: CGSize(width: imageSize, height: imageSize), synchronousLoad: synchronousLoad) {
                            let disposable = (signal
                            |> deliverOnMainQueue).startStrict(next: { [weak self] imageVersions in
                                guard let strongSelf = self else {
                                    return
                                }
                                let image = imageVersions?.0
                                if let image = image {
                                    strongSelf.images[peer.peerId] = image
                                    strongSelf.setNeedsDisplay()
                                }
                            })
                            self.disposables[peer.peerId] = disposable
                        }
                    }
                case .letters:
                    break
                }
            }
            self.setNeedsDisplay()
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol {
        return MergedAvatarsNodeArguments(peers: self.peers, images: self.images, imageSize: self.imageSize, imageSpacing: self.imageSpacing, borderWidth: self.borderWidthValue, avatarFontSize: self.avatarFontSize)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        assertNotOnMainThread()
        
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? MergedAvatarsNodeArguments else {
            return
        }
        
        let mergedImageSize = parameters.imageSize
        let mergedImageSpacing = parameters.imageSpacing
        
        var currentX = mergedImageSize + mergedImageSpacing * CGFloat(parameters.peers.count - 1) - mergedImageSize
        for i in (0 ..< parameters.peers.count).reversed() {
            let imageRect = CGRect(origin: CGPoint(x: currentX, y: 0.0), size: CGSize(width: mergedImageSize, height: mergedImageSize))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: imageRect.insetBy(dx: -parameters.borderWidth, dy: -parameters.borderWidth))
            context.setBlendMode(.normal)
            
            context.saveGState()
            switch parameters.peers[i] {
            case let .letters(peerId, nameColor, letters):
                context.translateBy(x: currentX, y: 0.0)
                drawPeerAvatarLetters(context: context, size: CGSize(width: mergedImageSize, height: mergedImageSize), font: avatarPlaceholderFont(size: parameters.avatarFontSize), letters: letters, peerId: peerId, nameColor: nameColor)
                context.translateBy(x: -currentX, y: 0.0)
            case .image:
                if let image = parameters.images[parameters.peers[i].peerId] {
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    context.draw(image.cgImage!, in: imageRect)
                } else {
                    context.setFillColor(UIColor.gray.cgColor)
                    context.fillEllipse(in: imageRect)
                }
            }
            context.restoreGState()
            currentX -= mergedImageSpacing
        }
    }
}
