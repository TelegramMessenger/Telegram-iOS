import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle
import WallpaperBackgroundNode

final class ChatMessageSwipeToReplyNode: ASDisplayNode {
    enum Action {
        case reply
        case like
        case unlike
    }
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private let backgroundNode: NavigationBackgroundNode
    private let foregroundNode: ASImageNode
    
    private var absolutePosition: (CGRect, CGSize)?
    
    init(fillColor: UIColor, enableBlur: Bool, foregroundColor: UIColor, backgroundNode: WallpaperBackgroundNode?, action: ChatMessageSwipeToReplyNode.Action) {
        self.backgroundNode = NavigationBackgroundNode(color: fillColor, enableBlur: enableBlur)
        self.backgroundNode.isUserInteractionEnabled = false

        self.foregroundNode = ASImageNode()
        self.foregroundNode.isUserInteractionEnabled = false

        self.foregroundNode.image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            switch action {
            case .reply:
                if let image = UIImage(bundleImageName: "Chat/Message/ShareIcon") {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: -1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setFillColor(foregroundColor.cgColor)
                    context.fill(imageRect)
                }
            case .like, .unlike:
                if let image = UIImage(bundleImageName: action == .like ? "Chat/Reactions/SwipeActionHeartFilled" : "Chat/Reactions/SwipeActionHeartBroken") {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    if case .like = action {
                        context.translateBy(x: 0.0, y: -1.0)
                    } else {
                        context.translateBy(x: 0.5, y: -1.0)
                    }
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setFillColor(foregroundColor.cgColor)
                    context.fill(imageRect)
                }
            }
        })
        
        super.init()
        
        self.allowsGroupOpacity = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.foregroundNode)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 33.0, height: 33.0))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: self.backgroundNode.bounds.height / 2.0, transition: .immediate)
        self.foregroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 33.0, height: 33.0))
        
        if backgroundNode?.hasExtraBubbleBackground() == true {
            if let backgroundContent = backgroundNode?.makeBubbleBackground(for: .free) {
                backgroundContent.clipsToBounds = true
                backgroundContent.allowsGroupOpacity = true
                self.backgroundContent = backgroundContent
                self.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            self.backgroundNode.isHidden = true
            backgroundContent.cornerRadius =  min(self.backgroundNode.bounds.width, self.backgroundNode.bounds.height) / 2.0
            backgroundContent.frame = self.backgroundNode.frame
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += containerSize.height - rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        } else {
            self.backgroundNode.isHidden = false
        }
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
}

extension ChatMessageSwipeToReplyNode.Action {
    init(_ action: ChatControllerInteractionSwipeAction?) {
        if let action = action {
            switch action {
            case .none:
                self = .reply
            case .reply:
                self = .reply
            }
        } else {
            self = .reply
        }
    }
}
