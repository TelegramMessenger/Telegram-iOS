import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode

public final class DrawingWallpaperRenderer {
    private let context: AccountContext
    private let dayWallpaper: TelegramWallpaper?
    private let nightWallpaper: TelegramWallpaper?
    
    private let wallpaperBackgroundNode: WallpaperBackgroundNode
    private let darkWallpaperBackgroundNode: WallpaperBackgroundNode
    
    public init (context: AccountContext, dayWallpaper: TelegramWallpaper?, nightWallpaper: TelegramWallpaper?) {
        self.context = context
        self.dayWallpaper = dayWallpaper
        self.nightWallpaper = nightWallpaper
        
        self.wallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: false)
        self.wallpaperBackgroundNode.displaysAsynchronously = false
        
        let wallpaper = self.dayWallpaper ?? context.sharedContext.currentPresentationData.with { $0 }.chatWallpaper
        self.wallpaperBackgroundNode.update(wallpaper: wallpaper, animated: false)
        
        self.darkWallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: false)
        self.darkWallpaperBackgroundNode.displaysAsynchronously = false
        
        let darkTheme = defaultDarkColorPresentationTheme
        let darkWallpaper = self.nightWallpaper ?? darkTheme.chat.defaultWallpaper
        self.darkWallpaperBackgroundNode.update(wallpaper: darkWallpaper, animated: false)
    }
    
    public func render(completion: @escaping (CGSize, UIImage?, UIImage?, CGRect?) -> Void) {
        self.updateLayout(size: CGSize(width: 360.0, height: 640.0))
        
        let resultSize = CGSize(width: 1080, height: 1920)
        Queue.mainQueue().justDispatch {
            self.generate(view: self.wallpaperBackgroundNode.view) { dayImage in
                if self.dayWallpaper != nil && self.nightWallpaper == nil {
                    completion(resultSize, dayImage, nil, nil)
                } else {
                    Queue.mainQueue().justDispatch {
                        self.generate(view: self.darkWallpaperBackgroundNode.view) { nightImage in
                            completion(resultSize, dayImage, nightImage, nil)
                        }
                    }
                }
            }
        }
    }
    
    private func generate(view: UIView, completion: @escaping (UIImage) -> Void) {
        let size = CGSize(width: 360.0, height: 640.0)
        UIGraphicsBeginImageContextWithOptions(size, false, 3.0)
        view.drawHierarchy(in: CGRect(origin: CGPoint(), size: size), afterScreenUpdates: true)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = generateImage(CGSize(width: size.width * 3.0, height: size.height * 3.0), contextGenerator: { size, context in
            if let cgImage = img?.cgImage {
                context.draw(cgImage, in: CGRect(origin: .zero, size: size), byTiling: false)
            }
        }, opaque: true, scale: 1.0)
        if let finalImage {
            completion(finalImage)
        }
    }
    
    private func updateLayout(size: CGSize) {
        self.wallpaperBackgroundNode.updateLayout(size: size, displayMode: .aspectFill, transition: .immediate)
        self.wallpaperBackgroundNode.frame = CGRect(origin: .zero, size: size)
        self.darkWallpaperBackgroundNode.updateLayout(size: size, displayMode: .aspectFill, transition: .immediate)
        self.darkWallpaperBackgroundNode.frame = CGRect(origin: .zero, size: size)
    }
}

public final class DrawingMessageRenderer {
    final class ContainerNode: ASDisplayNode {
        private let context: AccountContext
        private let messages: [Message]
        private let isNight: Bool
        private let isOverlay: Bool
        private let isLink: Bool
        private let isGift: Bool
        private let wallpaperColor: UIColor?
        
        private let messagesContainerNode: ASDisplayNode
        private var avatarHeaderNode: ListViewItemHeaderNode?
        private var messageNodes: [ListViewItemNode]?
        
        init(
            context: AccountContext,
            messages: [Message],
            isNight: Bool = false,
            isOverlay: Bool = false,
            isLink: Bool = false,
            isGift: Bool = false,
            wallpaperColor: UIColor? = nil
        ) {
            self.context = context
            self.messages = messages
            self.isNight = isNight
            self.isOverlay = isOverlay
            self.isLink = isLink
            self.isGift = isGift
            self.wallpaperColor = wallpaperColor
            
            self.messagesContainerNode = ASDisplayNode()
            self.messagesContainerNode.displaysAsynchronously = false
            self.messagesContainerNode.clipsToBounds = true
            self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
                    
            super.init()
            
            self.displaysAsynchronously = false
            
            self.addSubnode(self.messagesContainerNode)
        }
        
        public func render(presentationData: PresentationData, completion: @escaping (CGSize, UIImage?, CGRect?) -> Void) {
            var mockPresentationData = presentationData
            if self.isNight {
                let darkTheme = defaultDarkColorPresentationTheme
                mockPresentationData = mockPresentationData.withUpdated(theme: darkTheme).withUpdated(chatWallpaper: darkTheme.chat.defaultWallpaper)
            }
            
            let layout = ContainerViewLayout(size: CGSize(width: 360.0, height: 640.0), metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: .portrait), deviceMetrics: .iPhoneX, intrinsicInsets: .zero, safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 0.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)
            let size = self.updateMessagesLayout(layout: layout, presentationData: mockPresentationData)
            let _ = self.updateMessagesLayout(layout: layout, presentationData: mockPresentationData)
            
            Queue.mainQueue().after(0.35, {
                var mediaRect: CGRect?
                if let messageNode = self.messageNodes?.first {
                    if self.isOverlay {
                        func hideNonOverlayViews(_ view: UIView) -> Bool {
                            var hasResult = false
                            for view in view.subviews {
                                if view.tag == 0xFACE {
                                    hasResult = true
                                } else {
                                    if hideNonOverlayViews(view) {
                                        hasResult = true
                                    } else {
                                        view.isHidden = true
                                    }
                                }
                            }
                            return hasResult
                        }
                        let _ = hideNonOverlayViews(messageNode.view)
                    } else if !self.isNight {
                        func findMediaView(_ view: UIView) -> UIView? {
                            for view in view.subviews {
                                if let _ = view.asyncdisplaykit_node as? UniversalVideoNode {
                                    return view
                                } else {
                                    if let result = findMediaView(view) {
                                        return result
                                    }
                                }
                            }
                            return nil
                        }
                        
                        if let mediaView = findMediaView(messageNode.view) {
                            var rect = mediaView.convert(mediaView.bounds, to: self.messagesContainerNode.view)
                            rect.origin.y = self.messagesContainerNode.frame.height - rect.maxY
                            mediaRect = rect
                        }
                    }
                }
                
                var borderColor: UIColor?
                if self.isGift && !self.isOverlay, let wallpaperColor = self.wallpaperColor {
                    borderColor = wallpaperColor.withMultiplied(hue: 1.0, saturation: 1.5, brightness: self.isNight ? 1.6 : 0.7).withAlphaComponent(0.6)
                }

                self.generate(size: size, borderColor: borderColor) { image in
                    completion(size, image, mediaRect)
                }
            })
        }
        
        private func generate(size: CGSize, borderColor: UIColor? = nil, completion: @escaping (UIImage) -> Void) {
            UIGraphicsBeginImageContextWithOptions(size, false, 3.0)
            self.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: size), afterScreenUpdates: true)
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            let finalImage = generateImage(CGSize(width: size.width * 3.0, height: size.height * 3.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                if let borderColor {
                    context.addPath(CGPath(roundedRect: CGRect(origin: CGPoint(x: 6.0, y: 12.0), size: CGSize(width: size.width - 6.0, height: size.height - 13.0)), cornerWidth: 70.0, cornerHeight: 70.0, transform: nil))
                    context.setFillColor(borderColor.cgColor)
                    context.fillPath()
                }
                if let cgImage = img?.cgImage {
                    context.draw(cgImage, in: CGRect(origin: .zero, size: size), byTiling: false)
                }
            }, opaque: false, scale: 1.0)
            if let finalImage {
                completion(finalImage)
            }
        }
        
        private func updateMessagesLayout(layout: ContainerViewLayout, presentationData: PresentationData) -> CGSize {
            let size = layout.size
                    
            let theme = presentationData.theme.withUpdated(preview: true)
            
            let chatBubbleCorners = PresentationChatBubbleCorners(
                mainRadius: presentationData.chatBubbleCorners.mainRadius,
                auxiliaryRadius: presentationData.chatBubbleCorners.auxiliaryRadius,
                mergeBubbleCorners: presentationData.chatBubbleCorners.mergeBubbleCorners,
                hasTails: !self.isLink
            )
            
            let avatarHeaderItem: ListViewItemHeader?
            if let author = self.messages.first?.author {
                let avatarPeer: Peer
                if let peer = self.messages.first!.peers[author.id] {
                    avatarPeer = peer
                } else {
                    avatarPeer = author
                }
                avatarHeaderItem = self.context.sharedContext.makeChatMessageAvatarHeaderItem(context: self.context, timestamp: self.messages.first?.timestamp ?? 0, peer: avatarPeer, message: self.messages.first!, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder)
            } else {
                avatarHeaderItem = nil
            }
            let items: [ListViewItem] = [self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: self.messages, theme: theme, strings: presentationData.strings, wallpaper: presentationData.theme.chat.defaultWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: nil, availableReactions: nil, accountPeer: nil, isCentered: false, isPreview: true, isStandalone: false)]
        
            let inset: CGFloat = 16.0
            var leftInset: CGFloat = 37.0
            if self.isLink {
                leftInset = -6.0
            } else if self.isGift {
                leftInset = -50.0
            }
            let containerWidth = layout.size.width - inset * 2.0
            let params = ListViewItemLayoutParams(width: containerWidth, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
            
            var width: CGFloat = containerWidth
            var height: CGFloat = size.height
            if let messageNodes = self.messageNodes {
                for i in 0 ..< items.count {
                    let itemNode = messageNodes[i]
                    items[i].updateNode(async: { $0() }, node: {
                        return itemNode
                    }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                        let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: layout.size.height))
                        
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.frame = nodeFrame
                        itemNode.isUserInteractionEnabled = false
                        
                        apply(ListViewItemApply(isOnScreen: true))
                    })
                }
            } else {
                var messageNodes: [ListViewItemNode] = []
                for i in 0 ..< items.count {
                    var itemNode: ListViewItemNode?
                    items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                        itemNode = node
                        apply().1(ListViewItemApply(isOnScreen: true))
                    })
                    itemNode!.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    itemNode!.isUserInteractionEnabled = false
                    messageNodes.append(itemNode!)
                    self.messagesContainerNode.addSubnode(itemNode!)
                }
                self.messageNodes = messageNodes
            }
        
            if let messageNodes = self.messageNodes {
                var minX: CGFloat = .greatestFiniteMagnitude
                var maxX: CGFloat = -.greatestFiniteMagnitude
                var minY: CGFloat = .greatestFiniteMagnitude
                var maxY: CGFloat = -.greatestFiniteMagnitude
                for node in messageNodes {
                    if node.frame.minY < minY {
                        minY = node.frame.minY
                    }
                    if node.frame.maxY > maxY {
                        maxY = node.frame.maxY
                    }
                    if let areaNode = node.subnodes?.last {
                        if areaNode.frame.minX < minX {
                            minX = areaNode.frame.minX
                        }
                        if areaNode.frame.maxX > maxX {
                            maxX = areaNode.frame.maxX
                        }
                    }
                }
                width = abs(maxX - minX)
                height = abs(maxY - minY)
            }
            
            var bottomOffset: CGFloat = 0.0
            if let messageNodes = self.messageNodes {
                for itemNode in messageNodes {
                    itemNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: itemNode.frame.size)
                    bottomOffset += itemNode.frame.maxY
                    itemNode.updateFrame(itemNode.frame, within: layout.size)
                }
            }
                    
            if let avatarHeaderItem {
                let avatarHeaderNode: ListViewItemHeaderNode
                if let currentAvatarHeaderNode = self.avatarHeaderNode {
                    avatarHeaderNode = currentAvatarHeaderNode
                    avatarHeaderItem.updateNode(avatarHeaderNode, previous: nil, next: avatarHeaderItem)
                } else {
                    avatarHeaderNode = avatarHeaderItem.node(synchronousLoad: true)
                    avatarHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    self.messagesContainerNode.addSubnode(avatarHeaderNode)
                    self.avatarHeaderNode = avatarHeaderNode
                }
             
                avatarHeaderNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 3.0), size: CGSize(width: layout.size.width, height: avatarHeaderItem.height))
                avatarHeaderNode.updateLayout(size: size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate)
            }
            
            var finalWidth: CGFloat = width
            if leftInset > 0.0 {
                finalWidth += leftInset + 6.0
            }
            
            let containerSize = CGSize(width: finalWidth, height: height)
            self.frame = CGRect(origin: CGPoint(x: -1000.0, y: 0.0), size: containerSize)
            self.messagesContainerNode.frame = CGRect(origin: CGPoint(), size: containerSize)
            
            return containerSize
        }
    }
    
    public struct Result {
        public struct MediaFrame {
            public let rect: CGRect
            public let cornerRadius: CGFloat
        }
        
        public let size: CGSize
        public let dayImage: UIImage
        public let nightImage: UIImage
        public let overlayImage: UIImage
        public let mediaFrame: MediaFrame?
    }
    
    private let context: AccountContext
    private let messages: [Message]
    
    private let dayContainerNode: ContainerNode
    private let nightContainerNode: ContainerNode
    private let overlayContainerNode: ContainerNode
    
    public init(
        context: AccountContext,
        messages: [Message],
        parentView: UIView,
        isLink: Bool = false,
        isGift: Bool = false,
        wallpaperDayColor: UIColor? = nil,
        wallpaperNightColor: UIColor? = nil
    ) {
        self.context = context
        self.messages = messages
        
        self.dayContainerNode = ContainerNode(context: context, messages: messages, isLink: isLink, isGift: isGift, wallpaperColor: wallpaperDayColor)
        self.nightContainerNode = ContainerNode(context: context, messages: messages, isNight: true, isLink: isLink, isGift: isGift, wallpaperColor: wallpaperNightColor)
        self.overlayContainerNode = ContainerNode(context: context, messages: messages, isOverlay: true, isLink: isLink, isGift: isGift, wallpaperColor: nil)
        
        parentView.addSubview(self.dayContainerNode.view)
        parentView.addSubview(self.nightContainerNode.view)
        parentView.addSubview(self.overlayContainerNode.view)
    }
    
    public func render(completion: @escaping (Result) -> Void) {
        Queue.mainQueue().justDispatch {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let defaultPresentationData = defaultPresentationData()
                        
            let mockPresentationData = PresentationData(
                strings: presentationData.strings,
                theme: defaultPresentationTheme,
                autoNightModeTriggered: false,
                chatWallpaper: presentationData.chatWallpaper,
                chatFontSize: defaultPresentationData.chatFontSize,
                chatBubbleCorners: defaultPresentationData.chatBubbleCorners,
                listsFontSize: defaultPresentationData.listsFontSize,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                nameSortOrder: presentationData.nameSortOrder,
                reduceMotion: false,
                largeEmoji: true
            )
            
            var finalSize: CGSize = .zero
            var dayImage: UIImage?
            var nightImage: UIImage?
            var overlayImage: UIImage?
            var mediaRect: CGRect?
            
            let completeIfReady = {
                if let dayImage, let nightImage, let overlayImage {
                    var cornerRadius: CGFloat = defaultPresentationData.chatBubbleCorners.mainRadius
                    if let mediaRect, mediaRect.width == mediaRect.height, mediaRect.width == 240.0 {
                        cornerRadius = mediaRect.width / 2.0
                    } else if let rect = mediaRect {
                        mediaRect = CGRect(x: rect.minX + 4.0, y: rect.minY, width: rect.width - 6.0, height: rect.height - 1.0)
                    }
                    completion(Result(size: finalSize, dayImage: dayImage, nightImage: nightImage, overlayImage: overlayImage, mediaFrame: mediaRect.flatMap { Result.MediaFrame(rect: $0, cornerRadius: cornerRadius) }))
                    
                    self.dayContainerNode.view.removeFromSuperview()
                    self.nightContainerNode.view.removeFromSuperview()
                    self.overlayContainerNode.view.removeFromSuperview()
                }
            }
            self.dayContainerNode.render(presentationData: mockPresentationData) { size, image, rect in
                finalSize = size
                dayImage = image
                mediaRect = rect
                completeIfReady()
            }
            self.nightContainerNode.render(presentationData: mockPresentationData) { size, image, _ in
                nightImage = image
                completeIfReady()
            }
            self.overlayContainerNode.render(presentationData: mockPresentationData) { size, image, _ in
                overlayImage = image
                completeIfReady()
            }
        }
    }
}
