import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AppBundle
import LocalizedPeerData
import TelegramStringFormatting
import AccountContext
import ChatPresentationInterfaceState

private protocol ChatEmptyNodeContent {
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}

private let titleFont = Font.medium(15.0)
private let messageFont = Font.regular(14.0)

private final class ChatEmptyNodeRegularChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let textNode: ImmediateTextNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    override init() {
        self.textNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            let text: String
            switch interfaceState.chatLocation {
            case .peer, .replyThread, .feed:
                if case .scheduledMessages = interfaceState.subject {
                    text = interfaceState.strings.ScheduledMessages_EmptyPlaceholder
                } else {
                    text = interfaceState.strings.Conversation_EmptyPlaceholder
                }
            }
            
            self.textNode.attributedText = NSAttributedString(string: text, font: messageFont, textColor: serviceColor.primaryText)
        }
        
        let insets = UIEdgeInsets(top: 6.0, left: 10.0, bottom: 6.0, right: 10.0)
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let contentWidth = textSize.width
        let contentHeight = textSize.height
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: insets.top), size: textSize))
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

protocol ChatEmptyNodeStickerContentNode: ASDisplayNode {
    var stickerNode: ChatMediaInputStickerGridItemNode { get }
}

final class ChatEmptyNodeGreetingChatContent: ASDisplayNode, ChatEmptyNodeStickerContentNode, ChatEmptyNodeContent, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var stickerItem: ChatMediaInputStickerGridItem?
    let stickerNode: ChatMediaInputStickerGridItemNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var didSetupSticker = false
    private let disposable = MetaDisposable()
        
    init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
        self.context = context
        self.interaction = interaction
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.lineSpacing = 0.15
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.15
        self.textNode.textAlignment = .center
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.stickerNode = ChatMediaInputStickerGridItemNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.stickerNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.stickerTapGesture(_:)))
        tapRecognizer.delegate = self
        self.stickerNode.view.addGestureRecognizer(tapRecognizer)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func stickerTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let stickerItem = self.stickerItem else {
            return
        }
        let _ = self.interaction?.sendSticker(.standalone(media: stickerItem.stickerItem.file), false, self, self.stickerNode.bounds)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            self.titleNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_EmptyPlaceholder, font: titleFont, textColor: serviceColor.primaryText)
            
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_GreetingText, font: messageFont, textColor: serviceColor.primaryText)
        }
        
        let stickerSize: CGSize
        let inset: CGFloat
        if size.width == 320.0 {
            stickerSize = CGSize(width: 106.0, height: 106.0)
            inset = 8.0
        } else  {
            stickerSize = CGSize(width: 160.0, height: 160.0)
            inset = 15.0
        }
        if let item = self.stickerItem {
            self.stickerNode.updateLayout(item: item, size: stickerSize, isVisible: true, synchronousLoads: true)
        } else if !self.didSetupSticker {
            let sticker: Signal<TelegramMediaFile?, NoError>
            if let preloadedSticker = interfaceState.greetingData?.sticker {
                sticker = preloadedSticker
            } else {
                sticker = self.context.engine.stickers.randomGreetingSticker()
                |> map { item -> TelegramMediaFile? in
                    return item?.file
                }
            }
            
            self.didSetupSticker = true
            self.disposable.set((sticker
            |> deliverOnMainQueue).start(next: { [weak self] sticker in
                if let strongSelf = self, let sticker = sticker {
                    let inputNodeInteraction = ChatMediaInputNodeInteraction(
                        navigateToCollectionId: { _ in
                        },
                        navigateBackToStickers: {
                        },
                        setGifMode: { _ in
                        },
                        openSettings: {
                        },
                        openTrending: { _ in
                        },
                        dismissTrendingPacks: { _ in
                        },
                        toggleSearch: { _, _, _ in
                        },
                        openPeerSpecificSettings: {
                        },
                        dismissPeerSpecificSettings: {
                        },
                        clearRecentlyUsedStickers: {
                        }
                    )
                    inputNodeInteraction.displayStickerPlaceholder = false
                    
                    let index = ItemCollectionItemIndex(index: 0, id: 0)
                    let collectionId = ItemCollectionId(namespace: 0, id: 0)
                    let stickerPackItem = StickerPackItem(index: index, file: sticker, indexKeys: [])
                    let item = ChatMediaInputStickerGridItem(account: strongSelf.context.account, collectionId: collectionId, stickerPackInfo: nil, index: ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: collectionId, itemIndex: index), stickerItem: stickerPackItem, canManagePeerSpecificPack: nil, interfaceInteraction: nil, inputNodeInteraction: inputNodeInteraction, hasAccessory: false, theme: interfaceState.theme, large: true, selected: {})
                    strongSelf.stickerItem = item
                    strongSelf.stickerNode.updateLayout(item: item, size: stickerSize, isVisible: true, synchronousLoads: true)
                    strongSelf.stickerNode.isVisibleInGrid = true
                    strongSelf.stickerNode.updateIsPanelVisible(true)
                }
            }))
        }
        
        let insets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        let titleSpacing: CGFloat = 5.0
        let stickerSpacing: CGFloat = 5.0
        
        var contentWidth: CGFloat = 220.0
        var contentHeight: CGFloat = 0.0
                
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, max(titleSize.width, textSize.width))
        
        contentHeight += titleSize.height + titleSpacing + textSize.height + stickerSpacing + stickerSize.height
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: contentRect.minY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
       
        let textFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let stickerFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - stickerSize.width) / 2.0), y: textFrame.maxY + stickerSpacing), size: stickerSize)
        transition.updateFrame(node: self.stickerNode, frame: stickerFrame)
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

final class ChatEmptyNodeNearbyChatContent: ASDisplayNode, ChatEmptyNodeStickerContentNode, ChatEmptyNodeContent, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var stickerItem: ChatMediaInputStickerGridItem?
    let stickerNode: ChatMediaInputStickerGridItemNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var didSetupSticker = false
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
        self.context = context
        self.interaction = interaction
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.lineSpacing = 0.15
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.15
        self.textNode.textAlignment = .center
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.stickerNode = ChatMediaInputStickerGridItemNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.stickerNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.stickerTapGesture(_:)))
        tapRecognizer.delegate = self
        self.stickerNode.view.addGestureRecognizer(tapRecognizer)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func stickerTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let stickerItem = self.stickerItem else {
            return
        }
        let _ = self.interaction?.sendSticker(.standalone(media: stickerItem.stickerItem.file), false, self, self.stickerNode.bounds)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            var displayName = ""
            let distance = interfaceState.peerNearbyData?.distance ?? 0
            
            if let renderedPeer = interfaceState.renderedPeer {
                if let chatPeer = renderedPeer.peers[renderedPeer.peerId] {
                    displayName = EnginePeer(chatPeer).compactDisplayTitle
                }
            }

            let titleString = interfaceState.strings.Conversation_PeerNearbyTitle(displayName, shortStringForDistance(strings: interfaceState.strings, distance: distance)).string
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            self.titleNode.attributedText = NSAttributedString(string: titleString, font: titleFont, textColor: serviceColor.primaryText)
            
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_PeerNearbyText, font: messageFont, textColor: serviceColor.primaryText)
        }
        
        let stickerSize = CGSize(width: 160.0, height: 160.0)
        if let item = self.stickerItem {
            self.stickerNode.updateLayout(item: item, size: stickerSize, isVisible: true, synchronousLoads: true)
        } else if !self.didSetupSticker {
            let sticker: Signal<TelegramMediaFile?, NoError>
            if let preloadedSticker = interfaceState.greetingData?.sticker {
                sticker = preloadedSticker
            } else {
                sticker = self.context.engine.stickers.randomGreetingSticker()
                |> map { item -> TelegramMediaFile? in
                    return item?.file
                }
            }
            
            self.didSetupSticker = true
            self.disposable.set((sticker
            |> deliverOnMainQueue).start(next: { [weak self] sticker in
                if let strongSelf = self, let sticker = sticker {
                    let inputNodeInteraction = ChatMediaInputNodeInteraction(
                        navigateToCollectionId: { _ in
                        },
                        navigateBackToStickers: {
                        },
                        setGifMode: { _ in
                        },
                        openSettings: {
                        },
                        openTrending: { _ in
                        },
                        dismissTrendingPacks: { _ in
                        },
                        toggleSearch: { _, _, _ in
                        },
                        openPeerSpecificSettings: {
                        },
                        dismissPeerSpecificSettings: {
                        },
                        clearRecentlyUsedStickers: {
                        }
                    )
                    inputNodeInteraction.displayStickerPlaceholder = false
                    
                    let index = ItemCollectionItemIndex(index: 0, id: 0)
                    let collectionId = ItemCollectionId(namespace: 0, id: 0)
                    let stickerPackItem = StickerPackItem(index: index, file: sticker, indexKeys: [])
                    let item = ChatMediaInputStickerGridItem(account: strongSelf.context.account, collectionId: collectionId, stickerPackInfo: nil, index: ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: collectionId, itemIndex: index), stickerItem: stickerPackItem, canManagePeerSpecificPack: nil, interfaceInteraction: nil, inputNodeInteraction: inputNodeInteraction, hasAccessory: false, theme: interfaceState.theme, large: true, selected: {})
                    strongSelf.stickerItem = item
                    strongSelf.stickerNode.updateLayout(item: item, size: stickerSize, isVisible: true, synchronousLoads: true)
                    strongSelf.stickerNode.isVisibleInGrid = true
                    strongSelf.stickerNode.updateIsPanelVisible(true)
                }
            }))
        }
        
        let insets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
        let titleSpacing: CGFloat = 5.0
        let stickerSpacing: CGFloat = 5.0
        
        var contentWidth: CGFloat = 210.0
        var contentHeight: CGFloat = 0.0
                
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, max(titleSize.width, textSize.width))
        
        contentHeight += titleSize.height + titleSpacing + textSize.height + stickerSpacing + stickerSize.height
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: contentRect.minY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
      
        let textFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let stickerFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - stickerSize.width) / 2.0), y: textFrame.maxY + stickerSpacing), size: stickerSize)
        transition.updateFrame(node: self.stickerNode, frame: stickerFrame)
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

private final class ChatEmptyNodeSecretChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private var lineNodes: [(ASImageNode, ImmediateTextNode)] = []
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    override init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.lineSpacing = 0.25
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 0
        self.subtitleNode.lineSpacing = 0.25
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            var title = " "
            var incoming = false
            if let renderedPeer = interfaceState.renderedPeer {
                if let chatPeer = renderedPeer.peers[renderedPeer.peerId] as? TelegramSecretChat {
                    if case .participant = chatPeer.role {
                        incoming = true
                    }
                    if let user = renderedPeer.peers[chatPeer.regularPeerId] {
                        title = EnginePeer(user).compactDisplayTitle
                    }
                }
            }
            
            let titleString: String
            if incoming {
                titleString = interfaceState.strings.Conversation_EncryptedPlaceholderTitleIncoming(title).string
            } else {
                titleString = interfaceState.strings.Conversation_EncryptedPlaceholderTitleOutgoing(title).string
            }
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            self.titleNode.attributedText = NSAttributedString(string: titleString, font: titleFont, textColor: serviceColor.primaryText)
            
            self.subtitleNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_EncryptedDescriptionTitle, font: messageFont, textColor: serviceColor.primaryText)
            
            let strings: [String] = [
                interfaceState.strings.Conversation_EncryptedDescription1,
                interfaceState.strings.Conversation_EncryptedDescription2,
                interfaceState.strings.Conversation_EncryptedDescription3,
                interfaceState.strings.Conversation_EncryptedDescription4
            ]
            
            let lines: [NSAttributedString] = strings.map { NSAttributedString(string: $0, font: messageFont, textColor: serviceColor.primaryText) }
            
            let graphics = PresentationResourcesChat.additionalGraphics(interfaceState.theme, wallpaper: interfaceState.chatWallpaper, bubbleCorners: interfaceState.bubbleCorners)
            let lockIcon = graphics.chatEmptyItemLockIcon
            
            for i in 0 ..< lines.count {
                if i >= self.lineNodes.count {
                    let iconNode = ASImageNode()
                    iconNode.isLayerBacked = true
                    iconNode.displaysAsynchronously = false
                    iconNode.displayWithoutProcessing = true
                    let textNode = ImmediateTextNode()
                    textNode.maximumNumberOfLines = 0
                    textNode.isUserInteractionEnabled = false
                    textNode.displaysAsynchronously = false
                    self.addSubnode(iconNode)
                    self.addSubnode(textNode)
                    self.lineNodes.append((iconNode, textNode))
                }
                
                self.lineNodes[i].0.image = lockIcon
                self.lineNodes[i].1.attributedText = lines[i]
            }
        }
        
        let insets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
        let titleSpacing: CGFloat = 5.0
        let subtitleSpacing: CGFloat = 11.0
        let iconInset: CGFloat = 14.0
        
        var contentWidth: CGFloat = 100.0
        var contentHeight: CGFloat = 0.0
        
        var lineNodes: [(CGSize, ASImageNode, ImmediateTextNode)] = []
        for (iconNode, textNode) in self.lineNodes {
            let textSize = textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right - 10.0, height: CGFloat.greatestFiniteMagnitude))
            contentWidth = max(contentWidth, iconInset + textSize.width)
            contentHeight += textSize.height + subtitleSpacing
            lineNodes.append((textSize, iconNode, textNode))
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, max(titleSize.width, subtitleSize.width))
        
        contentHeight += titleSize.height + titleSpacing + subtitleSize.height
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: contentRect.minY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        let subtitleFrame = CGRect(origin: CGPoint(x: contentRect.minX, y: titleFrame.maxY + titleSpacing), size: subtitleSize)
        transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        
        var lineOffset = subtitleFrame.maxY + subtitleSpacing / 2.0
        for (textSize, iconNode, textNode) in lineNodes {
            if let image = iconNode.image {
                transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: lineOffset + 1.0), size: image.size))
            }
            transition.updateFrame(node: textNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + iconInset, y: lineOffset), size: textSize))
            lineOffset += textSize.height + subtitleSpacing
        }
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

private final class ChatEmptyNodeGroupChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private var lineNodes: [(ASImageNode, ImmediateTextNode)] = []
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    override init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.lineSpacing = 0.25
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 0
        self.subtitleNode.lineSpacing = 0.25
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let titleString: String = interfaceState.strings.EmptyGroupInfo_Title
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            self.titleNode.attributedText = NSAttributedString(string: titleString, font: titleFont, textColor: serviceColor.primaryText)
            
            self.subtitleNode.attributedText = NSAttributedString(string: interfaceState.strings.EmptyGroupInfo_Subtitle, font: messageFont, textColor: serviceColor.primaryText)
            
            let strings: [String] = [
                interfaceState.strings.EmptyGroupInfo_Line1("\(interfaceState.limitsConfiguration.maxSupergroupMemberCount)").string,
                interfaceState.strings.EmptyGroupInfo_Line2,
                interfaceState.strings.EmptyGroupInfo_Line3,
                interfaceState.strings.EmptyGroupInfo_Line4
            ]
            
            let lines: [NSAttributedString] = strings.map { NSAttributedString(string: $0, font: messageFont, textColor: serviceColor.primaryText) }
            
            let graphics = PresentationResourcesChat.additionalGraphics(interfaceState.theme, wallpaper: interfaceState.chatWallpaper, bubbleCorners: interfaceState.bubbleCorners)
            let lockIcon = graphics.emptyChatListCheckIcon
            
            for i in 0 ..< lines.count {
                if i >= self.lineNodes.count {
                    let iconNode = ASImageNode()
                    iconNode.isLayerBacked = true
                    iconNode.displaysAsynchronously = false
                    iconNode.displayWithoutProcessing = true
                    let textNode = ImmediateTextNode()
                    textNode.maximumNumberOfLines = 0
                    textNode.isUserInteractionEnabled = false
                    textNode.displaysAsynchronously = false
                    self.addSubnode(iconNode)
                    self.addSubnode(textNode)
                    self.lineNodes.append((iconNode, textNode))
                }
                
                self.lineNodes[i].0.image = lockIcon
                self.lineNodes[i].1.attributedText = lines[i]
            }
        }
        
        let insets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
        let titleSpacing: CGFloat = 5.0
        let subtitleSpacing: CGFloat = 11.0
        let iconInset: CGFloat = 19.0
        
        var contentWidth: CGFloat = 100.0
        var contentHeight: CGFloat = 0.0
        
        var lineNodes: [(CGSize, ASImageNode, ImmediateTextNode)] = []
        for (iconNode, textNode) in self.lineNodes {
            let textSize = textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right - 10.0, height: CGFloat.greatestFiniteMagnitude))
            contentWidth = max(contentWidth, iconInset + textSize.width)
            contentHeight += textSize.height + subtitleSpacing
            lineNodes.append((textSize, iconNode, textNode))
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, max(titleSize.width, subtitleSize.width))
        
        contentHeight += titleSize.height + titleSpacing + subtitleSize.height
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: contentRect.minY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        let subtitleFrame = CGRect(origin: CGPoint(x: contentRect.minX, y: titleFrame.maxY + titleSpacing), size: subtitleSize)
        transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        
        var lineOffset = subtitleFrame.maxY + subtitleSpacing / 2.0
        for (textSize, iconNode, textNode) in lineNodes {
            if let image = iconNode.image {
                transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: lineOffset + 2.0), size: image.size))
            }
            transition.updateFrame(node: textNode, frame: CGRect(origin: CGPoint(x: contentRect.minX + iconInset, y: lineOffset), size: textSize))
            lineOffset += textSize.height + subtitleSpacing
        }
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

private final class ChatEmptyNodeCloudChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private var lineNodes: [ImmediateTextNode] = []
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.lineSpacing = 0.15
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Empty Chat/Cloud"), color: serviceColor.primaryText)
            
            let titleString = interfaceState.strings.Conversation_CloudStorageInfo_Title
            self.titleNode.attributedText = NSAttributedString(string: titleString, font: titleFont, textColor: serviceColor.primaryText)
            
            let strings: [String] = [
                interfaceState.strings.Conversation_ClousStorageInfo_Description1,
                interfaceState.strings.Conversation_ClousStorageInfo_Description2,
                interfaceState.strings.Conversation_ClousStorageInfo_Description3,
                interfaceState.strings.Conversation_ClousStorageInfo_Description4
            ]
            
            let lines: [NSAttributedString] = strings.map { NSAttributedString(string: $0, font: messageFont, textColor: serviceColor.primaryText) }
            
            for i in 0 ..< lines.count {
                if i >= self.lineNodes.count {
                    let textNode = ImmediateTextNode()
                    textNode.maximumNumberOfLines = 0
                    textNode.isUserInteractionEnabled = false
                    textNode.displaysAsynchronously = false
                    self.addSubnode(textNode)
                    self.lineNodes.append(textNode)
                }
                
                self.lineNodes[i].attributedText = lines[i]
            }
        }
        
        let insets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
        
        let imageSpacing: CGFloat = 12.0
        let titleSpacing: CGFloat = 4.0
        
        var contentWidth: CGFloat = 100.0
        var contentHeight: CGFloat = 0.0
        
        if let image = self.iconNode.image {
            contentHeight += image.size.height
            contentHeight += imageSpacing
            contentWidth = max(contentWidth, image.size.width)
        }
        
        var lineNodes: [(CGSize, ImmediateTextNode)] = []
        for textNode in self.lineNodes {
            let textSize = textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right - 10.0, height: CGFloat.greatestFiniteMagnitude))
            contentWidth = max(contentWidth, textSize.width)
            contentHeight += textSize.height + titleSpacing
            lineNodes.append((textSize, textNode))
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, titleSize.width)
        
        contentHeight += titleSize.height + titleSpacing
        
        var imageAreaHeight: CGFloat = 0.0
        if let image = self.iconNode.image {
            imageAreaHeight += image.size.height
            imageAreaHeight += imageSpacing
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - image.size.width) / 2.0), y: insets.top), size: image.size))
        }
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top + imageAreaHeight), size: CGSize(width: contentWidth, height: contentHeight))
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: contentRect.minY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        var lineOffset = titleFrame.maxY + titleSpacing
        for (textSize, textNode) in lineNodes {
            let isRTL = textNode.cachedLayout?.hasRTL ?? false
            transition.updateFrame(node: textNode, frame: CGRect(origin: CGPoint(x: isRTL ? contentRect.maxX - textSize.width : contentRect.minX, y: lineOffset), size: textSize))
            lineOffset += textSize.height + 4.0
        }
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

private enum ChatEmptyNodeContentType {
    case regular
    case secret
    case group
    case cloud
    case peerNearby
    case greeting
}

final class ChatEmptyNode: ASDisplayNode {
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let backgroundNode: NavigationBackgroundNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var content: (ChatEmptyNodeContentType, ASDisplayNode & ChatEmptyNodeContent)?
    
    init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
        self.context = context
        self.interaction = interaction
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
    }
    
    func animateFromLoadingNode(_ loadingNode: ChatLoadingNode) {
        guard let (_, node) = content else {
            return
        }
        
        let duration: Double = 0.2
        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        node.layer.animateScale(from: 0.0, to: 1.0, duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        
        let targetCornerRadius = self.backgroundNode.backgroundCornerRadius
        let targetFrame = self.backgroundNode.frame
        let initialFrame = loadingNode.convert(loadingNode.progressFrame, to: self)
        
        self.backgroundNode.layer.animateFrame(from: initialFrame, to: targetFrame, duration: duration)
        self.backgroundNode.update(size: initialFrame.size, cornerRadius: initialFrame.size.width / 2.0, transition: .immediate)
        self.backgroundNode.update(size: targetFrame.size, cornerRadius: targetCornerRadius, transition: .animated(duration: duration, curve: .easeInOut))
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, emptyType: ChatHistoryNodeLoadState.EmptyType, loadingNode: ChatLoadingNode?, size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings

            self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper), enableBlur: dateFillNeedsBlur(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper), transition: .immediate)
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = interfaceState.subject {
            isScheduledMessages = true
        }
        
        let contentType: ChatEmptyNodeContentType
        if case .replyThread = interfaceState.chatLocation {
            contentType = .regular
        } else if let peer = interfaceState.renderedPeer?.peer, !isScheduledMessages {
            if peer.id == self.context.account.peerId {
                contentType = .cloud
            } else if let _ = peer as? TelegramSecretChat {
                contentType = .secret
            } else if let group = peer as? TelegramGroup, case .creator = group.role {
                contentType = .group
            } else if let channel = peer as? TelegramChannel, case .group = channel.info, channel.flags.contains(.isCreator) && !channel.flags.contains(.isGigagroup) {
                contentType = .group
            } else if let _ = interfaceState.peerNearbyData {
                contentType = .peerNearby
            } else if let peer = peer as? TelegramUser {
                if peer.isDeleted || peer.botInfo != nil || peer.flags.contains(.isSupport) || peer.isScam || interfaceState.peerIsBlocked {
                    contentType = .regular
                } else if case .clearedHistory = emptyType {
                    contentType = .regular
                } else {
                    contentType = .greeting
                }
            } else {
                contentType = .regular
            }
        } else {
            contentType = .regular
        }
        
        var updateGreetingSticker = false
        var contentTransition = transition
        if self.content?.0 != contentType {
            var animateContentIn = false
            if let node = self.content?.1 {
                node.removeFromSupernode()
                if self.content?.0 != nil && contentType == .greeting && transition.isAnimated {
                    animateContentIn = true
                }
            }
            let node: ASDisplayNode & ChatEmptyNodeContent
            switch contentType {
                case .regular:
                    node = ChatEmptyNodeRegularChatContent()
                case .secret:
                    node = ChatEmptyNodeSecretChatContent()
                case .group:
                    node = ChatEmptyNodeGroupChatContent()
                case .cloud:
                    node = ChatEmptyNodeCloudChatContent()
                case .peerNearby:
                    node = ChatEmptyNodeNearbyChatContent(context: self.context, interaction: self.interaction)
                case .greeting:
                    node = ChatEmptyNodeGreetingChatContent(context: self.context, interaction: self.interaction)
                    updateGreetingSticker = true
            }
            self.content = (contentType, node)
            self.addSubnode(node)
            contentTransition = .immediate
            
            if animateContentIn, case let .animated(duration, curve) = transition {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                node.layer.animateScale(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        self.isUserInteractionEnabled = [.peerNearby, .greeting].contains(contentType)
        
        let displayRect = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
        
        var contentSize = CGSize()
        if let contentNode = self.content?.1 {
            contentSize = contentNode.updateLayout(interfaceState: interfaceState, size: displayRect.size, transition: contentTransition)
            
            if updateGreetingSticker {
                self.context.prefetchManager?.prepareNextGreetingSticker()
            }
        }
        
        let contentFrame = CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - contentSize.width) / 2.0), y: displayRect.minY + floor((displayRect.height - contentSize.height) / 2.0)), size: contentSize)
        if let contentNode = self.content?.1 {
            contentTransition.updateFrame(node: contentNode, frame: contentFrame)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: contentFrame)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: min(20.0, self.backgroundNode.bounds.height / 2.0), transition: transition)
        
        if let loadingNode = loadingNode {
            self.animateFromLoadingNode(loadingNode)
        }
    }
}
