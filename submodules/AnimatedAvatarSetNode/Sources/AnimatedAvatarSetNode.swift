import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AvatarNode
import SwiftSignalKit
import TelegramCore
import AccountContext
import AudioBlob

public final class AnimatedAvatarSetContext {
    public final class Content {
        fileprivate final class Item {
            fileprivate enum Key: Hashable {
                case peer(EnginePeer.Id)
                case placeholder(Int)
            }
            
            fileprivate let peer: EnginePeer?
            fileprivate let placeholderColor: UIColor
            
            fileprivate init(peer: EnginePeer?, placeholderColor: UIColor) {
                self.peer = peer
                self.placeholderColor = placeholderColor
            }
        }
        
        fileprivate var items: [(Item.Key, Item)]
        
        fileprivate init(items: [(Item.Key, Item)]) {
            self.items = items
        }
    }
    
    private final class ItemState {
        let peer: EnginePeer
        
        init(peer: EnginePeer) {
            self.peer = peer
        }
    }
    
    private var peers: [EnginePeer] = []
    private var itemStates: [EnginePeer.Id: ItemState] = [:]
    
    public init() {
    }
    
    public func update(peers: [EnginePeer], animated: Bool) -> Content {
        var items: [(Content.Item.Key, Content.Item)] = []
        for peer in peers {
            items.append((.peer(peer.id), Content.Item(peer: peer, placeholderColor: .white)))
        }
        return Content(items: items)
    }

    public func updatePlaceholder(color: UIColor, count: Int, animated: Bool) -> Content {
        var items: [(Content.Item.Key, Content.Item)] = []
        for i in 0 ..< count {
            items.append((.placeholder(i), Content.Item(peer: nil, placeholderColor: color)))
        }
        return Content(items: items)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 12.0)

private final class ContentNode: ASDisplayNode {
    private var audioLevelView: VoiceBlobView?
    private var audioLevelBlobOverlay: UIImageView?
    private let unclippedNode: ASImageNode
    private let clippedNode: ASImageNode

    private var size: CGSize
    private var spacing: CGFloat
    
    private var disposable: Disposable?
    
    init(context: AccountContext, peer: EnginePeer?, placeholderColor: UIColor, synchronousLoad: Bool, size: CGSize, spacing: CGFloat) {
        self.size = size
        self.spacing = spacing

        self.unclippedNode = ASImageNode()
        self.clippedNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.unclippedNode)
        self.addSubnode(self.clippedNode)

        if let peer = peer {
            if let representation = peer.smallProfileImage, let signal = peerAvatarImage(account: context.account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: representation, displayDimensions: size, synchronousLoad: synchronousLoad) {
                let image = generateImage(size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(UIColor.lightGray.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                })!
                self.updateImage(image: image, size: size, spacing: spacing)

                let disposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] imageVersions in
                    guard let strongSelf = self else {
                        return
                    }
                    let image = imageVersions?.0
                    if let image = image {
                        strongSelf.updateImage(image: image, size: size, spacing: spacing)
                    }
                })
                self.disposable = disposable
            } else {
                let image = generateImage(size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    drawPeerAvatarLetters(context: context, size: size, font: avatarFont, letters: peer.displayLetters, peerId: peer.id)
                })!
                self.updateImage(image: image, size: size, spacing: spacing)
            }
        } else {
            let image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(placeholderColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            })!
            self.updateImage(image: image, size: size, spacing: spacing)
        }
    }
    
    private func updateImage(image: UIImage, size: CGSize, spacing: CGFloat) {
        self.unclippedNode.image = image
        self.clippedNode.image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.5, dy: -1.5).offsetBy(dx: spacing - size.width, dy: 0.0))
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateLayout(size: CGSize, isClipped: Bool, animated: Bool) {
        self.unclippedNode.frame = CGRect(origin: CGPoint(), size: size)
        self.clippedNode.frame = CGRect(origin: CGPoint(), size: size)
        
        if animated && self.unclippedNode.alpha.isZero != self.clippedNode.alpha.isZero {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self.unclippedNode, alpha: isClipped ? 0.0 : 1.0)
            transition.updateAlpha(node: self.clippedNode, alpha: isClipped ? 1.0 : 0.0)
        } else {
            self.unclippedNode.alpha = isClipped ? 0.0 : 1.0
            self.clippedNode.alpha = isClipped ? 1.0 : 0.0
        }
    }
    
    func updateAudioLevel(color: UIColor, backgroundColor: UIColor, value: Float) {
        if self.audioLevelView == nil, value > 0.0 {
            let blobFrame = self.unclippedNode.bounds.insetBy(dx: -8.0, dy: -8.0)
            
            let audioLevelView = VoiceBlobView(
                frame: blobFrame,
                maxLevel: 0.3,
                smallBlobRange: (0, 0),
                mediumBlobRange: (0.7, 0.8),
                bigBlobRange: (0.8, 0.9)
            )
            
            let maskRect = CGRect(origin: .zero, size: blobFrame.size)
            let playbackMaskLayer = CAShapeLayer()
            playbackMaskLayer.frame = maskRect
            playbackMaskLayer.fillRule = .evenOdd
            let maskPath = UIBezierPath()
            maskPath.append(UIBezierPath(roundedRect: self.unclippedNode.bounds.offsetBy(dx: 8, dy: 8), cornerRadius: maskRect.width / 2.0))
            maskPath.append(UIBezierPath(rect: maskRect))
            playbackMaskLayer.path = maskPath.cgPath
            //audioLevelView.layer.mask = playbackMaskLayer
            
            audioLevelView.setColor(color)
            self.audioLevelView = audioLevelView
            self.view.insertSubview(audioLevelView, at: 0)
        }
        
        let level = min(1.0, max(0.0, CGFloat(value)))
        if let audioLevelView = self.audioLevelView {
            audioLevelView.updateLevel(CGFloat(value) * 2.0)
            
            let avatarScale: CGFloat
            let audioLevelScale: CGFloat
            if value > 0.0 {
                audioLevelView.startAnimating()
                avatarScale = 1.03 + level * 0.07
                audioLevelScale = 1.0
            } else {
                audioLevelView.stopAnimating(duration: 0.5)
                avatarScale = 1.0
                audioLevelScale = 0.01
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            transition.updateSublayerTransformScale(node: self, scale: CGPoint(x: avatarScale, y: avatarScale), beginWithCurrentState: true)
            transition.updateSublayerTransformScale(layer: audioLevelView.layer, scale: CGPoint(x: audioLevelScale, y: audioLevelScale), beginWithCurrentState: true)
        }
    }
}

public final class AnimatedAvatarSetNode: ASDisplayNode {
    private var contentNodes: [AnimatedAvatarSetContext.Content.Item.Key: ContentNode] = [:]
    
    override public init() {
        super.init()
    }
    
    public func update(context: AccountContext, content: AnimatedAvatarSetContext.Content, itemSize: CGSize = CGSize(width: 30.0, height: 30.0), customSpacing: CGFloat? = nil, animated: Bool, synchronousLoad: Bool) -> CGSize {
        var contentWidth: CGFloat = 0.0
        let contentHeight: CGFloat = itemSize.height

        let spacing: CGFloat
        if let customSpacing = customSpacing {
            spacing = customSpacing
        } else {
            spacing = 10.0
        }
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        
        var validKeys: [AnimatedAvatarSetContext.Content.Item.Key] = []
        var index = 0
        for i in 0 ..< content.items.count {
            let (key, item) = content.items[i]
            
            validKeys.append(key)
            
            let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: itemSize)
            
            let itemNode: ContentNode
            if let current = self.contentNodes[key] {
                itemNode = current
                itemNode.updateLayout(size: itemSize, isClipped: index != 0, animated: animated)
                transition.updateFrame(node: itemNode, frame: itemFrame)
            } else {
                itemNode = ContentNode(context: context, peer: item.peer, placeholderColor: item.placeholderColor, synchronousLoad: synchronousLoad, size: itemSize, spacing: spacing)
                self.addSubnode(itemNode)
                self.contentNodes[key] = itemNode
                itemNode.updateLayout(size: itemSize, isClipped: index != 0, animated: false)
                itemNode.frame = itemFrame
                if animated {
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    itemNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
            }
            itemNode.zPosition = CGFloat(100 - i)
            contentWidth += itemSize.width - spacing
            index += 1
        }
        var removeKeys: [AnimatedAvatarSetContext.Content.Item.Key] = []
        for key in self.contentNodes.keys {
            if !validKeys.contains(key) {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            guard let itemNode = self.contentNodes.removeValue(forKey: key) else {
                continue
            }
            itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemNode] _ in
                itemNode?.removeFromSupernode()
            })
            itemNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
        }
        
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    public func updateAudioLevels(color: UIColor, backgroundColor: UIColor, levels: [EnginePeer.Id: Float]) {
        for (key, itemNode) in self.contentNodes {
            if case let .peer(peerId) = key, let value = levels[peerId] {
                itemNode.updateAudioLevel(color: color, backgroundColor: backgroundColor, value: value)
            } else {
                itemNode.updateAudioLevel(color: color, backgroundColor: backgroundColor, value: 0.0)
            }
        }
    }
}

public final class AnimatedAvatarSetView: UIView {
    private final class ContentView: UIView {
        private let unclippedView: UIImageView
        private let clippedView: UIImageView

        private var size: CGSize
        private var spacing: CGFloat
        
        private var disposable: Disposable?
        
        init(context: AccountContext, peer: EnginePeer?, placeholderColor: UIColor, synchronousLoad: Bool, size: CGSize, spacing: CGFloat) {
            self.size = size
            self.spacing = spacing

            self.unclippedView = UIImageView()
            self.clippedView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.unclippedView)
            self.addSubview(self.clippedView)

            if let peer = peer {
                if let representation = peer.smallProfileImage, let signal = peerAvatarImage(account: context.account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: representation, displayDimensions: size, synchronousLoad: synchronousLoad) {
                    let image = generateImage(size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(UIColor.lightGray.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    })!
                    self.updateImage(image: image, size: size, spacing: spacing)

                    let disposable = (signal
                    |> deliverOnMainQueue).start(next: { [weak self] imageVersions in
                        guard let strongSelf = self else {
                            return
                        }
                        let image = imageVersions?.0
                        if let image = image {
                            strongSelf.updateImage(image: image, size: size, spacing: spacing)
                        }
                    })
                    self.disposable = disposable
                } else {
                    let image = generateImage(size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        drawPeerAvatarLetters(context: context, size: size, font: avatarFont, letters: peer.displayLetters, peerId: peer.id)
                    })!
                    self.updateImage(image: image, size: size, spacing: spacing)
                }
            } else {
                let image = generateImage(size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(placeholderColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                })!
                self.updateImage(image: image, size: size, spacing: spacing)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateImage(image: UIImage, size: CGSize, spacing: CGFloat) {
            self.unclippedView.image = image
            self.clippedView.image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.5, dy: -1.5).offsetBy(dx: spacing - size.width, dy: 0.0))
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func updateLayout(size: CGSize, isClipped: Bool, animated: Bool) {
            self.unclippedView.frame = CGRect(origin: CGPoint(), size: size)
            self.clippedView.frame = CGRect(origin: CGPoint(), size: size)
            
            if animated && self.unclippedView.alpha.isZero != self.clippedView.alpha.isZero {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                transition.updateAlpha(layer: self.unclippedView.layer, alpha: isClipped ? 0.0 : 1.0)
                transition.updateAlpha(layer: self.clippedView.layer, alpha: isClipped ? 1.0 : 0.0)
            } else {
                self.unclippedView.alpha = isClipped ? 0.0 : 1.0
                self.clippedView.alpha = isClipped ? 1.0 : 0.0
            }
        }
    }
    
    private var contentViews: [AnimatedAvatarSetContext.Content.Item.Key: ContentView] = [:]
    
    public func update(context: AccountContext, content: AnimatedAvatarSetContext.Content, itemSize: CGSize = CGSize(width: 30.0, height: 30.0), customSpacing: CGFloat? = nil, animation: ListViewItemUpdateAnimation, synchronousLoad: Bool) -> CGSize {
        var contentWidth: CGFloat = 0.0
        let contentHeight: CGFloat = itemSize.height

        let spacing: CGFloat
        if let customSpacing = customSpacing {
            spacing = customSpacing
        } else {
            spacing = 10.0
        }
        
        var validKeys: [AnimatedAvatarSetContext.Content.Item.Key] = []
        var index = 0
        for i in 0 ..< content.items.count {
            let (key, item) = content.items[i]
            
            validKeys.append(key)
            
            let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: itemSize)
            
            let itemView: ContentView
            if let current = self.contentViews[key] {
                itemView = current
                itemView.updateLayout(size: itemSize, isClipped: index != 0, animated: animation.isAnimated)
                animation.animator.updateFrame(layer: itemView.layer, frame: itemFrame, completion: nil)
            } else {
                itemView = ContentView(context: context, peer: item.peer, placeholderColor: item.placeholderColor, synchronousLoad: synchronousLoad, size: itemSize, spacing: spacing)
                self.addSubview(itemView)
                self.contentViews[key] = itemView
                itemView.updateLayout(size: itemSize, isClipped: index != 0, animated: false)
                itemView.frame = itemFrame
                if animation.isAnimated {
                    itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    itemView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
            }
            itemView.layer.zPosition = CGFloat(100 - i)
            contentWidth += itemSize.width - spacing
            index += 1
        }
        var removeKeys: [AnimatedAvatarSetContext.Content.Item.Key] = []
        for key in self.contentViews.keys {
            if !validKeys.contains(key) {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            guard let itemView = self.contentViews.removeValue(forKey: key) else {
                continue
            }
            if animation.isAnimated {
                itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemView] _ in
                    itemView?.removeFromSuperview()
                })
                itemView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            } else {
                itemView.removeFromSuperview()
            }
        }
        
        return CGSize(width: contentWidth, height: contentHeight)
    }
}
