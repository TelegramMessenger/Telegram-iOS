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
import WallpaperBackgroundNode
import ComponentFlow
import EmojiStatusComponent
import ChatLoadingNode
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import ReactionSelectionNode
import ChatMediaInputStickerGridItem
import UndoUI
import PremiumUI
import LottieComponent
import BundleIconComponent

private protocol ChatEmptyNodeContent {
    func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize
}

private let titleFont = Font.semibold(15.0)
private let messageFont = Font.regular(13.0)

private final class ChatEmptyNodeRegularChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let textNode: ImmediateTextNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    override init() {
        self.textNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            let text: String
            if case .detailsPlaceholder = subject {
                text = interfaceState.strings.ChatList_StartMessaging
            } else {
                switch interfaceState.chatLocation {
                case .peer, .replyThread, .customChatContents:
                    if case .scheduledMessages = interfaceState.subject {
                        text = interfaceState.strings.ScheduledMessages_EmptyPlaceholder
                    } else {
                        text = interfaceState.strings.Conversation_EmptyPlaceholder
                    }
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

public protocol ChatEmptyNodeStickerContentNode: ASDisplayNode {
    var stickerNode: ChatMediaInputStickerGridItemNode { get }
}

public final class ChatEmptyNodeGreetingChatContent: ASDisplayNode, ChatEmptyNodeStickerContentNode, ChatEmptyNodeContent, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var stickerItem: ChatMediaInputStickerGridItem?
    public var stickerNode: ChatMediaInputStickerGridItemNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var didSetupSticker = false
    private let disposable = MetaDisposable()
    private var currentCustomStickerFile: TelegramMediaFile?
        
    public init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
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
    
    override public func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.stickerTapGesture(_:)))
        tapRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.stickerNode.view.addGestureRecognizer(tapRecognizer)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func stickerTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let stickerItem = self.stickerItem else {
            return
        }
        let _ = self.interaction?.sendSticker(.standalone(media: stickerItem.stickerItem.file._parse()), false, self.view, self.stickerNode.bounds, nil, [])
    }
    
    public func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        let isFirstTime = self.currentTheme == nil
        
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
        }
        
        var customStickerFile: TelegramMediaFile?
        
        let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
        if case let .emptyChat(emptyChat) = subject, case let .customGreeting(stickerFile, title, text) = emptyChat {
            customStickerFile = stickerFile
            self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: serviceColor.primaryText)
            self.textNode.attributedText = NSAttributedString(string: text, font: messageFont, textColor: serviceColor.primaryText)
        } else if let businessIntro = interfaceState.businessIntro {
            self.titleNode.attributedText = NSAttributedString(string: !businessIntro.title.isEmpty ? businessIntro.title : interfaceState.strings.Conversation_EmptyPlaceholder, font: titleFont, textColor: serviceColor.primaryText)
            self.textNode.attributedText = NSAttributedString(string: !businessIntro.text.isEmpty ? businessIntro.text : interfaceState.strings.Conversation_GreetingText, font: messageFont, textColor: serviceColor.primaryText)
            customStickerFile = businessIntro.stickerFile
        } else {
            self.titleNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_EmptyPlaceholder, font: titleFont, textColor: serviceColor.primaryText)
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_GreetingText, font: messageFont, textColor: serviceColor.primaryText)
        }
        
        let previousCustomStickerFile = self.currentCustomStickerFile
        self.currentCustomStickerFile = customStickerFile
        
        var stickerSize: CGSize
        let inset: CGFloat
        if size.width == 320.0 {
            stickerSize = CGSize(width: 106.0, height: 106.0)
            inset = 8.0
        } else  {
            stickerSize = CGSize(width: 160.0, height: 160.0)
            inset = 15.0
        }
        
        if let customStickerFile, let dimensions = customStickerFile.dimensions?.cgSize {
            stickerSize = dimensions.aspectFitted(stickerSize)
        }
        
        if let item = self.stickerItem, previousCustomStickerFile == customStickerFile {
            self.stickerNode.updateLayout(item: item, size: stickerSize, isVisible: true, synchronousLoads: true)
        } else if !self.didSetupSticker || previousCustomStickerFile != customStickerFile {
            let sticker: Signal<TelegramMediaFile?, NoError>
            if let customStickerFile {
                sticker = .single(customStickerFile)
            } else if let preloadedSticker = interfaceState.greetingData?.sticker {
                sticker = preloadedSticker
            } else {
                sticker = self.context.engine.stickers.randomGreetingSticker()
                |> map { item -> TelegramMediaFile? in
                    return item?.file
                }
            }
            
            if !isFirstTime, case let .emptyChat(emptyChat) = subject, case .customGreeting = emptyChat {
                let previousStickerNode = self.stickerNode
                previousStickerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousStickerNode] _ in
                    previousStickerNode?.removeFromSupernode()
                })
                previousStickerNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                
                self.stickerNode = ChatMediaInputStickerGridItemNode()
                self.addSubnode(self.stickerNode)
                self.stickerNode.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                self.stickerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            self.didSetupSticker = true
            self.disposable.set((sticker
            |> deliverOnMainQueue).startStrict(next: { [weak self] sticker in
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
                    let item = ChatMediaInputStickerGridItem(context: strongSelf.context, collectionId: collectionId, stickerPackInfo: nil, index: ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: collectionId, itemIndex: index), stickerItem: stickerPackItem, canManagePeerSpecificPack: nil, interfaceInteraction: nil, inputNodeInteraction: inputNodeInteraction, hasAccessory: false, theme: interfaceState.theme, large: true, selected: {})
                    strongSelf.stickerItem = item
                    
                    if isFirstTime {
                        
                    }
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

public final class ChatEmptyNodeNearbyChatContent: ASDisplayNode, ChatEmptyNodeStickerContentNode, ChatEmptyNodeContent, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var stickerItem: ChatMediaInputStickerGridItem?
    public let stickerNode: ChatMediaInputStickerGridItemNode
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var didSetupSticker = false
    private let disposable = MetaDisposable()
    
    public init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
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
    
    override public func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.stickerTapGesture(_:)))
        tapRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.stickerNode.view.addGestureRecognizer(tapRecognizer)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func stickerTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let stickerItem = self.stickerItem else {
            return
        }
        let _ = self.interaction?.sendSticker(.standalone(media: stickerItem.stickerItem.file._parse()), false, self.view, self.stickerNode.bounds, nil, [])
    }
    
    public func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            var displayName = ""
            let distance = interfaceState.peerNearbyData?.distance ?? 0
            
            if let renderedPeer = interfaceState.renderedPeer {
                if let chatPeer = renderedPeer.chatOrMonoforumMainPeer {
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
            |> deliverOnMainQueue).startStrict(next: { [weak self] sticker in
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
                    let item = ChatMediaInputStickerGridItem(context: strongSelf.context, collectionId: collectionId, stickerPackInfo: nil, index: ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: collectionId, itemIndex: index), stickerItem: stickerPackItem, canManagePeerSpecificPack: nil, interfaceInteraction: nil, inputNodeInteraction: inputNodeInteraction, hasAccessory: false, theme: interfaceState.theme, large: true, selected: {})
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
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
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
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
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
    
    private var linkTextButton: HighlightTrackingButtonNode?
    private var linkTextNode: ImmediateTextNode?
    private var linkTextHighlightNode: LinkHighlightingNode?
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var businessLink: TelegramBusinessChatLinks.Link?
    var shareBusinessLink: ((String) -> Void)?
    
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
    
    @objc private func linkTextButtonPressed() {
        guard let businessLink = self.businessLink else {
            return
        }
        self.shareBusinessLink?(businessLink.url)
    }
    
    func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        var maxWidth: CGFloat = size.width
        var centerText = false
        
        var insets = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 15.0, right: 15.0)
        var imageSpacing: CGFloat = 12.0
        var titleSpacing: CGFloat = 4.0
        
        let businessLinkTextSpacing: CGFloat = 9.0
        
        if case let .customChatContents(customChatContents) = interfaceState.subject {
            maxWidth = min(240.0, maxWidth)
            
            switch customChatContents.kind {
            case .quickReplyMessageInput:
                insets.top = 10.0
                imageSpacing = 5.0
                titleSpacing = 5.0
            case .businessLinkSetup:
                insets.top = -9.0
                imageSpacing = 4.0
                titleSpacing = 5.0
            case .hashTagSearch:
                break
            }
        }
        
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
            
            var iconName = "Chat/Empty Chat/Cloud"
            
            let titleString: String
            let strings: [String]
            var textFontSize: CGFloat = 14.0
            
            var businessLink: String?
            
            if case let .customChatContents(customChatContents) = interfaceState.subject {
                switch customChatContents.kind {
                case let .quickReplyMessageInput(shortcut, shortcutType):
                    switch shortcutType {
                    case .generic:
                        iconName = "Chat/Empty Chat/QuickReplies"
                        centerText = false
                        titleString = interfaceState.strings.Chat_EmptyState_QuickReply_Title
                        strings = [
                            interfaceState.strings.Chat_EmptyState_QuickReply_Text1(shortcut).string,
                            interfaceState.strings.Chat_EmptyState_QuickReply_Text2
                        ]
                    case .greeting:
                        iconName = "Chat/Empty Chat/GreetingShortcut"
                        centerText = true
                        titleString = interfaceState.strings.EmptyState_GreetingMessage_Title
                        strings = [
                            interfaceState.strings.EmptyState_GreetingMessage_Text
                        ]
                    case .away:
                        iconName = "Chat/Empty Chat/AwayShortcut"
                        centerText = true
                        titleString = interfaceState.strings.EmptyState_AwayMessage_Title
                        strings = [
                            interfaceState.strings.EmptyState_AwayMessage_Text
                        ]
                    }
                case let .businessLinkSetup(link):
                    iconName = "Chat/Empty Chat/BusinessLink"
                    centerText = true
                    titleString = interfaceState.strings.Business_Links_PreviewTitle
                    textFontSize = 13.0
                    strings = [
                        interfaceState.strings.Business_Links_PreviewText
                    ]
                    if link.url.hasPrefix("https://") {
                        businessLink = String(link.url[link.url.index(link.url.startIndex, offsetBy: "https://".count)...])
                    } else {
                        businessLink = link.url
                    }
                    
                    self.businessLink = link
                case .hashTagSearch:
                    titleString = ""
                    strings = []
                }
            } else {
                titleString = interfaceState.strings.Conversation_CloudStorageInfo_Title
                strings = [
                    interfaceState.strings.Conversation_ClousStorageInfo_Description1,
                    interfaceState.strings.Conversation_ClousStorageInfo_Description2,
                    interfaceState.strings.Conversation_ClousStorageInfo_Description3,
                    interfaceState.strings.Conversation_ClousStorageInfo_Description4
                ]
            }
            
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: iconName), color: serviceColor.primaryText)
            
            self.titleNode.attributedText = NSAttributedString(string: titleString, font: titleFont, textColor: serviceColor.primaryText)
            
            let lines: [NSAttributedString] = strings.map {
                return parseMarkdownIntoAttributedString($0, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(textFontSize), textColor: serviceColor.primaryText),
                    bold: MarkdownAttributeSet(font: Font.semibold(textFontSize), textColor: serviceColor.primaryText),
                    link: MarkdownAttributeSet(font: Font.regular(textFontSize), textColor: serviceColor.primaryText),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: centerText ? .center : .natural)
            }
            
            for i in 0 ..< lines.count {
                if i >= self.lineNodes.count {
                    let textNode = ImmediateTextNode()
                    textNode.maximumNumberOfLines = 0
                    textNode.isUserInteractionEnabled = false
                    textNode.displaysAsynchronously = false
                    textNode.textAlignment = centerText ? .center : .natural
                    self.addSubnode(textNode)
                    self.lineNodes.append(textNode)
                }
                
                self.lineNodes[i].attributedText = lines[i]
            }
            
            if let businessLink {
                let linkTextButton: HighlightTrackingButtonNode
                if let current = self.linkTextButton {
                    linkTextButton = current
                } else {
                    linkTextButton = HighlightTrackingButtonNode()
                    self.linkTextButton = linkTextButton
                    self.addSubnode(linkTextButton)
                    
                    linkTextButton.addTarget(self, action: #selector(self.linkTextButtonPressed), forControlEvents: .touchUpInside)
                    linkTextButton.highligthedChanged = { [weak linkTextButton] highlighted in
                        if let linkTextButton, linkTextButton.bounds.width > 0.0 {
                            let animateScale = true
                            
                            let topScale: CGFloat = (linkTextButton.bounds.width - 8.0) / linkTextButton.bounds.width
                            let maxScale: CGFloat = (linkTextButton.bounds.width + 2.0) / linkTextButton.bounds.width
                            
                            if highlighted {
                                linkTextButton.layer.removeAnimation(forKey: "transform.scale")
                                
                                if animateScale {
                                    let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                                    transition.setScale(layer: linkTextButton.layer, scale: topScale)
                                }
                            } else {
                                if animateScale {
                                    let transition = ComponentTransition(animation: .none)
                                    transition.setScale(layer: linkTextButton.layer, scale: 1.0)
                                    
                                    linkTextButton.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak linkTextButton] _ in
                                        guard let linkTextButton else {
                                            return
                                        }
                                        
                                        linkTextButton.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                                    })
                                }
                            }
                        }
                    }
                }
                
                let linkTextNode: ImmediateTextNode
                if let current = self.linkTextNode {
                    linkTextNode = current
                } else {
                    linkTextNode = ImmediateTextNode()
                    linkTextNode.maximumNumberOfLines = 0
                    linkTextNode.textAlignment = .center
                    linkTextNode.lineSpacing = 0.2
                    self.linkTextNode = linkTextNode
                    linkTextButton.addSubnode(linkTextNode)
                }
                
                linkTextNode.attributedText = NSAttributedString(string: businessLink, font: Font.medium(textFontSize), textColor: serviceColor.primaryText)
            } else {
                if let linkTextButton = self.linkTextButton {
                    self.linkTextButton = nil
                    linkTextButton.removeFromSupernode()
                }
                if let linkTextNode = self.linkTextNode {
                    self.linkTextNode = nil
                    linkTextNode.removeFromSupernode()
                }
            }
        }
        
        var contentWidth: CGFloat = 100.0
        var contentHeight: CGFloat = 0.0
        
        if let image = self.iconNode.image {
            contentHeight += image.size.height
            contentHeight += imageSpacing
            contentWidth = max(contentWidth, image.size.width)
        }
        
        var lineNodes: [(CGSize, ImmediateTextNode)] = []
        for textNode in self.lineNodes {
            let textSize = textNode.updateLayout(CGSize(width: maxWidth - insets.left - insets.right - 10.0, height: CGFloat.greatestFiniteMagnitude))
            contentWidth = max(contentWidth, textSize.width)
            contentHeight += textSize.height + titleSpacing
            lineNodes.append((textSize, textNode))
        }
        
        var linkTextLayout: TextNodeLayout?
        if let linkTextNode {
            let linkTextLayoutValue = linkTextNode.updateLayoutFullInfo(CGSize(width: maxWidth - insets.left - insets.right - 10.0, height: CGFloat.greatestFiniteMagnitude))
            linkTextLayout = linkTextLayoutValue
            contentHeight += businessLinkTextSpacing + linkTextLayoutValue.size.height + 20.0
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
        var isFirstLine = true
        for (textSize, textNode) in lineNodes {
            if isFirstLine {
                isFirstLine = false
            } else {
                lineOffset += 4.0
            }
            
            let isRTL = textNode.cachedLayout?.hasRTL ?? false
            transition.updateFrame(node: textNode, frame: CGRect(origin: CGPoint(x: isRTL ? contentRect.maxX - textSize.width : contentRect.minX, y: lineOffset), size: textSize))
            lineOffset += textSize.height
        }
        
        if let linkTextButton = self.linkTextButton, let linkTextNode = self.linkTextNode, let linkTextLayout {
            if isFirstLine {
                isFirstLine = false
            } else {
                lineOffset += businessLinkTextSpacing
            }
            
            let linkTextButtonFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - linkTextLayout.size.width) * 0.5), y: lineOffset), size: linkTextLayout.size)
            let linkTextFrame = CGRect(origin: CGPoint(), size: linkTextButtonFrame.size)
            
            transition.updatePosition(node: linkTextButton, position: linkTextButtonFrame.center)
            transition.updateBounds(node: linkTextButton, bounds: CGRect(origin: CGPoint(), size: linkTextButtonFrame.size))
            transition.updateFrame(node: linkTextNode, frame: linkTextFrame)
            
            let linkTextHighlightNode: LinkHighlightingNode
            if let current = self.linkTextHighlightNode {
                linkTextHighlightNode = current
            } else {
                linkTextHighlightNode = LinkHighlightingNode(color: .black)
                linkTextHighlightNode.inset = 0.0
                linkTextHighlightNode.useModernPathCalculation = true
                self.linkTextHighlightNode = linkTextHighlightNode
                linkTextNode.supernode?.insertSubnode(linkTextHighlightNode, belowSubnode: linkTextNode)
            }
            
            let textLayout = linkTextLayout
            
            var labelRects = textLayout.linesRects()
            if labelRects.count > 1 {
                let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                for i in 0 ..< sortedIndices.count {
                    let index = sortedIndices[i]
                    for j in -1 ... 1 {
                        if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                            if abs(labelRects[index + j].width - labelRects[index].width) < 16.0 {
                                labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                                labelRects[index].size.width = labelRects[index + j].size.width
                            }
                        }
                    }
                }
            }
            for i in 0 ..< labelRects.count {
                labelRects[i] = labelRects[i].insetBy(dx: -4.0, dy: 0.0)
                if i == 0 {
                    labelRects[i].origin.y -= 1.0
                    labelRects[i].size.height += 1.0
                }
                if i == labelRects.count - 1 {
                    labelRects[i].size.height += 1.0
                } else {
                    let deltaY = labelRects[i + 1].minY - labelRects[i].maxY
                    let topDelta = deltaY * 0.5 - 0.0
                    let bottomDelta = deltaY * 0.5 - 0.0
                    labelRects[i].size.height += topDelta
                    labelRects[i + 1].origin.y -= bottomDelta
                    labelRects[i + 1].size.height += bottomDelta
                }
                labelRects[i].origin.x = floor((textLayout.size.width - labelRects[i].width) / 2.0)
            }
            for i in 0 ..< labelRects.count {
                labelRects[i].origin.y -= 12.0
            }
            
            linkTextHighlightNode.innerRadius = 4.0
            linkTextHighlightNode.outerRadius = 4.0
            
            linkTextHighlightNode.updateRects(labelRects, color: interfaceState.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1))
            
            linkTextHighlightNode.frame = linkTextFrame.offsetBy(dx: 0.0, dy: 0.0)
        } else {
            if let linkTextHighlightNode = self.linkTextHighlightNode {
                self.linkTextHighlightNode = nil
                linkTextHighlightNode.removeFromSupernode()
            }
        }
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

public final class ChatEmptyNodeTopicChatContent: ASDisplayNode, ChatEmptyNodeContent, ASGestureRecognizerDelegate {
    private let context: AccountContext
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
        
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private let iconView: ComponentView<Empty>
            
    public init(context: AccountContext) {
        self.context = context
        
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
        
        self.iconView = ComponentView<Empty>()
                
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    public func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings
            
            self.titleNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_EmptyTopicPlaceholder_Title, font: titleFont, textColor: serviceColor.primaryText)
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_EmptyTopicPlaceholder_Text, font: messageFont, textColor: serviceColor.primaryText)
        }
        
        let inset: CGFloat
        if size.width == 320.0 {
            inset = 8.0
        } else  {
            inset = 15.0
        }
       
        let iconContent: EmojiStatusComponent.Content
        if let fileId = interfaceState.threadData?.icon {
            iconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 96.0, height: 96.0), placeholderColor: .clear, themeColor: serviceColor.primaryText, loopMode: .count(2))
        } else {
            let title = interfaceState.threadData?.title ?? ""
            let iconColor = interfaceState.threadData?.iconColor ?? 0
            iconContent = .topic(title: String(title.prefix(1)), color: iconColor, size: CGSize(width: 64.0, height: 64.0))
        }
        
        let insets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        let titleSpacing: CGFloat = 6.0
        let iconSpacing: CGFloat = 9.0
        
        let iconSize = self.iconView.update(
            transition: .easeInOut(duration: 0.2),
            component: AnyComponent(EmojiStatusComponent(
                context: self.context,
                animationCache: self.context.animationCache,
                animationRenderer: self.context.animationRenderer,
                content: iconContent,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 54.0, height: 54.0)
        )
                
        var contentWidth: CGFloat = 196.0
        var contentHeight: CGFloat = 0.0
                
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
        
        contentWidth = max(contentWidth, max(titleSize.width, textSize.width))
        
        contentHeight += titleSize.height + titleSpacing + textSize.height + iconSpacing + iconSize.height
        
        let contentRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: contentWidth, height: contentHeight))
        
        let iconFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - iconSize.width) / 2.0), y: contentRect.minY), size: iconSize)
        
        if let iconComponentView = self.iconView.view {
            if iconComponentView.superview == nil {
                self.view.addSubview(iconComponentView)
            }
            transition.updateFrame(view: iconComponentView, frame: iconFrame)
        }
        
        let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
       
        let textFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((contentRect.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        return contentRect.insetBy(dx: -insets.left, dy: -insets.top).size
    }
}

public final class ChatEmptyNodePremiumRequiredChatContent: ASDisplayNode, ChatEmptyNodeContent {
    private let isPremiumDisabled: Bool
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let iconBackground: SimpleLayer
    private var icon = ComponentView<Empty>()
    private let text = ComponentView<Empty>()
    private let buttonTitle = ComponentView<Empty>()
    private let button: HighlightTrackingButton
    private let buttonStarsNode: PremiumStarsNode
        
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private let stars: Int64?
    
    public init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?, stars: Int64?) {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        self.isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        self.stars = stars
        
        self.interaction = interaction
        
        self.iconBackground = SimpleLayer()

        self.button = HighlightTrackingButton()
        self.button.clipsToBounds = true
        
        self.buttonStarsNode = PremiumStarsNode()
        self.buttonStarsNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.layer.addSublayer(self.iconBackground)
        
        if !self.isPremiumDisabled {
            self.view.addSubview(self.button)
            
            self.button.addSubnode(self.buttonStarsNode)
            
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.button.layer.removeAnimation(forKey: "opacity")
                    self.button.alpha = 0.6
                } else {
                    self.button.alpha = 1.0
                    self.button.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
    }
    
    @objc private func buttonPressed() {
        if let interaction = self.interaction {
            if let _ = self.stars {
                interaction.openStarsPurchase(nil)
            } else {
                interaction.openPremiumRequiredForMessaging()
            }
        }
    }
    
    public func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: ChatEmptyNode.Subject, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        let serviceColor = serviceMessageColorComponents(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
        
        let maxWidth = min(270.0, size.width)
        
        let sideInset: CGFloat = 22.0
        let topInset: CGFloat = 16.0
        let bottomInset: CGFloat = 16.0
        let iconBackgroundSize: CGFloat = 120.0
        let iconTextSpacing: CGFloat = 16.0
        let textButtonSpacing: CGFloat = 12.0
        
        let peerTitle: String
        if let peer = interfaceState.renderedPeer?.chatOrMonoforumMainPeer {
            peerTitle = EnginePeer(peer).compactDisplayTitle
        } else {
            peerTitle = " "
        }
        
        let text: NSAttributedString
        var actionText: String?
        let attributes = MarkdownAttributes(
            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: serviceColor.primaryText),
            bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: serviceColor.primaryText),
            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: serviceColor.primaryText),
            linkAttribute: { url in
                return ("URL", url)
            }
        )
        if let amount = self.stars {
            let starsString = presentationStringsFormattedNumber(Int32(amount), interfaceState.dateTimeFormat.groupingSeparator)
            let rawText: String
            
            if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum {
                rawText = interfaceState.strings.Chat_EmptyStateMonoforumPaid_Text(peerTitle, " $ \(starsString)").string
            } else if self.isPremiumDisabled {
                rawText = interfaceState.strings.Chat_EmptyStatePaidMessagingDisabled_Text(peerTitle, " $ \(starsString)").string
            } else {
                rawText = interfaceState.strings.Chat_EmptyStatePaidMessaging_Text(peerTitle, " $ \(starsString)").string
            }
            let attributedString = parseMarkdownIntoAttributedString(rawText, attributes: attributes).mutableCopy() as! NSMutableAttributedString
            if let range = attributedString.string.range(of: "$") {
                attributedString.addAttribute(.attachment, value: PresentationResourcesChat.chatEmptyStateStarIcon(interfaceState.theme)!, range: NSRange(range, in: attributedString.string))
                attributedString.addAttribute(.foregroundColor, value: serviceColor.primaryText, range: NSRange(range, in: attributedString.string))
                attributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: attributedString.string))
            }
            text = attributedString
            actionText = interfaceState.strings.Chat_EmptyStatePaidMessaging_Action
        } else {
            if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum {
                let rawText = interfaceState.strings.Chat_EmptyStateMonoforum_Text(peerTitle).string
                text = parseMarkdownIntoAttributedString(rawText, attributes: attributes)
            } else {
                let rawText: String
                if self.isPremiumDisabled {
                    rawText = interfaceState.strings.Chat_EmptyStateMessagingRestrictedToPremiumDisabled_Text(peerTitle).string
                } else {
                    rawText = interfaceState.strings.Chat_EmptyStateMessagingRestrictedToPremium_Text(peerTitle).string
                }
                text = parseMarkdownIntoAttributedString(rawText, attributes: attributes)
                actionText = interfaceState.strings.Chat_EmptyStateMessagingRestrictedToPremium_Action
            }
        }
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(BalancedTextComponent(
                text: .plain(text),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: maxWidth - sideInset * 2.0, height: 500.0)
        )
        
        var buttonTitleSize: CGSize?
        if let actionText {
            buttonTitleSize = self.buttonTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: actionText, font: Font.semibold(15.0), textColor: serviceColor.primaryText))
                )),
                environment: {},
                containerSize: CGSize(width: 250.0, height: 100.0)
            )
        } else {
            self.buttonTitle.view?.removeFromSuperview()
        }
        
        var buttonSize: CGSize?
        if let buttonTitleSize {
            buttonSize = CGSize(width: buttonTitleSize.width + 20.0 * 2.0, height: buttonTitleSize.height + 9.0 * 2.0)
        }
        
        var contentsWidth: CGFloat = 0.0
        contentsWidth = max(contentsWidth, iconBackgroundSize + sideInset * 2.0)
        contentsWidth = max(contentsWidth, textSize.width + sideInset * 2.0)
        
        if !self.isPremiumDisabled, let buttonSize {
            contentsWidth = max(contentsWidth, buttonSize.width + sideInset * 2.0)
        }
        
        var contentsHeight: CGFloat = 0.0
        contentsHeight += topInset
        
        let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((contentsWidth - iconBackgroundSize) * 0.5), y: contentsHeight), size: CGSize(width: iconBackgroundSize, height: iconBackgroundSize))
        transition.updateFrame(layer: self.iconBackground, frame: iconBackgroundFrame)
        transition.updateCornerRadius(layer: self.iconBackground, cornerRadius: iconBackgroundSize * 0.5)
        self.iconBackground.backgroundColor = (interfaceState.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)).cgColor
        contentsHeight += iconBackgroundSize
        contentsHeight += iconTextSpacing
        
        let iconComponent: AnyComponent<Empty>
        do {
            if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum {
                if let view = self.icon.view, !(view is BundleIconComponent.View) {
                    view.removeFromSuperview()
                    self.icon = ComponentView()
                }
                
                iconComponent = AnyComponent(BundleIconComponent(
                    name: "Chat/Empty Chat/ChannelMessages",
                    tintColor: serviceColor.primaryText
                ))
            } else {
                if let view = self.icon.view, !(view is LottieComponent.View) {
                    view.removeFromSuperview()
                    self.icon = ComponentView()
                }
                
                iconComponent = AnyComponent(
                    LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "PremiumRequired"),
                        color: serviceColor.primaryText,
                        size: CGSize(width: 120.0, height: 120.0),
                        loop: true
                    )
                )
            }
        }
        let iconSize = self.icon.update(
            transition: .immediate,
            component: iconComponent,
            environment: {},
            containerSize: CGSize(width: maxWidth - sideInset * 2.0, height: 500.0)
        )
        let iconFrame = CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floor((iconBackgroundFrame.width - iconSize.width) * 0.5), y: iconBackgroundFrame.minY + floor((iconBackgroundFrame.height - iconSize.height) * 0.5)), size: iconSize)
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                iconView.isUserInteractionEnabled = false
                self.view.addSubview(iconView)
            }
            iconView.frame = iconFrame
        }

        let textFrame = CGRect(origin: CGPoint(x: floor((contentsWidth - textSize.width) * 0.5), y: contentsHeight), size: textSize)
        if let textView = self.text.view {
            if textView.superview == nil {
                textView.isUserInteractionEnabled = false
                self.view.addSubview(textView)
            }
            textView.frame = textFrame
        }
        contentsHeight += textSize.height
        
        if !self.isPremiumDisabled, let buttonTitleSize, let buttonSize {
            contentsHeight += textButtonSpacing
            
            let buttonFrame = CGRect(origin: CGPoint(x: floor((contentsWidth - buttonSize.width) * 0.5), y: contentsHeight), size: buttonSize)
            transition.updateFrame(view: self.button, frame: buttonFrame)
            transition.updateCornerRadius(layer: self.button.layer, cornerRadius: buttonFrame.height * 0.5)
            if let buttonTitleView = self.buttonTitle.view {
                if buttonTitleView.superview == nil {
                    buttonTitleView.isUserInteractionEnabled = false
                    self.button.addSubview(buttonTitleView)
                }
                transition.updateFrame(view: buttonTitleView, frame: CGRect(origin: CGPoint(x: floor((buttonSize.width - buttonTitleSize.width) * 0.5), y: floor((buttonSize.height - buttonTitleSize.height) * 0.5)), size: buttonTitleSize))
            }
            self.button.backgroundColor = interfaceState.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
            self.buttonStarsNode.frame = CGRect(origin: CGPoint(), size: buttonSize)
            contentsHeight += buttonSize.height
            contentsHeight += bottomInset
        } else {
            contentsHeight += bottomInset
        }
            
        
        return CGSize(width: contentsWidth, height: contentsHeight)
    }
}

private enum ChatEmptyNodeContentType: Equatable {
    case regular
    case secret
    case group
    case cloud
    case peerNearby
    case greeting
    case topic
    case premiumRequired
    case starsRequired(Int64?)
}

private final class EmptyAttachedDescriptionNode: HighlightTrackingButtonNode {
    private struct Params: Equatable {
        var theme: PresentationTheme
        var strings: PresentationStrings
        var chatWallpaper: TelegramWallpaper
        var peer: EnginePeer
        var constrainedSize: CGSize
        
        init(theme: PresentationTheme, strings: PresentationStrings, chatWallpaper: TelegramWallpaper, peer: EnginePeer, constrainedSize: CGSize) {
            self.theme = theme
            self.strings = strings
            self.chatWallpaper = chatWallpaper
            self.peer = peer
            self.constrainedSize = constrainedSize
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.chatWallpaper != rhs.chatWallpaper {
                return false
            }
            if lhs.constrainedSize != rhs.constrainedSize {
                return false
            }
            return true
        }
    }
    
    private struct Layout {
        var params: Params
        var size: CGSize
        
        init(params: Params, size: CGSize) {
            self.params = params
            self.size = size
        }
    }
    
    private let textNode: ImmediateTextNode
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private let textMaskNode: LinkHighlightingNode
    
    private let badgeTextNode: ImmediateTextNode
    private let badgeBackgroundView: UIImageView
    
    private var currentLayout: Layout?
    
    var action: (() -> Void)?
    
    override init(pointerStyle: PointerStyle? = nil) {
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.2
        
        self.textMaskNode = LinkHighlightingNode(color: .white)
        self.textMaskNode.inset = 0.0
        self.textMaskNode.useModernPathCalculation = false
        
        self.badgeTextNode = ImmediateTextNode()
        self.badgeBackgroundView = UIImageView()
        
        super.init(pointerStyle: pointerStyle)
        
        self.addSubnode(self.textNode)
        
        self.view.addSubview(self.badgeBackgroundView)
        self.addSubnode(self.badgeTextNode)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let animateScale = true
                
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "transform.scale")
                    
                    if animateScale {
                        let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                        transition.setScale(layer: self.layer, scale: topScale)
                    }
                } else {
                    if animateScale {
                        let transition = ComponentTransition(animation: .none)
                        transition.setScale(layer: self.layer, scale: 1.0)
                        
                        self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
        }
    }
    
    @objc private func pressed() {
        self.action?()
    }
    
    func update(
        theme: PresentationTheme,
        strings: PresentationStrings,
        chatWallpaper: TelegramWallpaper,
        peer: EnginePeer,
        wallpaperBackgroundNode: WallpaperBackgroundNode?,
        constrainedSize: CGSize
    ) -> CGSize {
        let params = Params(
            theme: theme,
            strings: strings,
            chatWallpaper: chatWallpaper,
            peer: peer,
            constrainedSize: constrainedSize
        )
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        } else {
            let size = self.updateInternal(params: params, wallpaperBackgroundNode: wallpaperBackgroundNode)
            self.currentLayout = Layout(params: params, size: size)
            return size
        }
    }
    
    private func updateInternal(params: Params, wallpaperBackgroundNode: WallpaperBackgroundNode?) -> CGSize {
        let serviceColor = serviceMessageColorComponents(theme: params.theme, wallpaper: params.chatWallpaper)
        
        let textString = NSMutableAttributedString()
        textString.append(NSAttributedString(string: params.strings.Chat_EmptyStateIntroFooter(params.peer.compactDisplayTitle).string, font: Font.regular(13.0), textColor: serviceColor.primaryText))
        textString.append(NSAttributedString(string: "  .\(params.strings.Chat_EmptyStateIntroFooterAction)", font: Font.regular(11.0), textColor: .clear))
        self.textNode.attributedText = textString
        
        let maxTextSize = CGSize(width: min(300.0, params.constrainedSize.width - 8.0 * 2.0), height: params.constrainedSize.height - 8.0 * 2.0)
        
        var bestSize: (availableWidth: CGFloat, info: TextNodeLayout)
        let info = self.textNode.updateLayoutFullInfo(maxTextSize)
        bestSize = (maxTextSize.width, info)
        if info.numberOfLines > 1 {
            let measureIncrement = 8.0
            var measureWidth = info.size.width
            measureWidth -= measureIncrement
            while measureWidth > 0.0 {
                let otherInfo = self.textNode.updateLayoutFullInfo(CGSize(width: measureWidth, height: maxTextSize.height))
                if otherInfo.numberOfLines > bestSize.info.numberOfLines {
                    break
                }
                if (otherInfo.size.width - otherInfo.trailingLineWidth) < (bestSize.info.size.width - bestSize.info.trailingLineWidth) {
                    bestSize = (measureWidth, otherInfo)
                }
                
                measureWidth -= measureIncrement
            }
            
            let bestInfo = self.textNode.updateLayoutFullInfo(CGSize(width: bestSize.availableWidth, height: maxTextSize.height))
            bestSize = (maxTextSize.width, bestInfo)
        }
        
        let textLayout = bestSize.info
        
        var labelRects = textLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 16.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: 0.0)
            if i == 0 {
                labelRects[i].origin.y -= 2.0
                labelRects[i].size.height += 2.0
            }
            if i == labelRects.count - 1 {
                labelRects[i].size.height += 3.0
            } else {
                let deltaYHalf = ceil((labelRects[i + 1].minY - labelRects[i].maxY) * 0.5)
                let topDelta = deltaYHalf + 0.0
                let bottomDelta = deltaYHalf - 0.0
                labelRects[i].size.height += topDelta
                labelRects[i + 1].origin.y -= bottomDelta
                labelRects[i + 1].size.height += bottomDelta
            }
            labelRects[i].origin.x = floor((textLayout.size.width - labelRects[i].width) / 2.0)
        }
        for i in 0 ..< labelRects.count {
            labelRects[i].origin.y -= 12.0
        }
        if !labelRects.isEmpty {
            self.textMaskNode.innerRadius = labelRects[0].height * 0.25
            self.textMaskNode.outerRadius = labelRects[0].height * 0.5
        }
        self.textMaskNode.updateRects(labelRects)
        
        let size = CGSize(width: textLayout.size.width + 4.0 * 2.0, height: textLayout.size.height + 4.0 * 2.0)
        let textFrame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: textLayout.size)
        self.textNode.frame = textFrame
        
        self.badgeTextNode.attributedText = NSAttributedString(string: params.strings.Chat_EmptyStateIntroFooterAction, font: Font.regular(11.0), textColor: serviceColor.primaryText)
        let badgeTextSize = self.badgeTextNode.updateLayout(CGSize(width: 200.0, height: 100.0))
        if let lastLineFrame = labelRects.last {
            let badgeTextFrame = CGRect(origin: CGPoint(x: lastLineFrame.maxX - badgeTextSize.width - 3.0, y: textFrame.maxY - badgeTextSize.height - 3.0 - UIScreenPixel), size: badgeTextSize)
            self.badgeTextNode.frame = badgeTextFrame
            
            let badgeBackgroundFrame = badgeTextFrame.insetBy(dx: -4.0, dy: -1.0)
            if badgeBackgroundFrame.height != self.badgeBackgroundView.image?.size.height {
                self.badgeBackgroundView.image = generateStretchableFilledCircleImage(diameter: badgeBackgroundFrame.height, color: serviceColor.primaryText.withMultipliedAlpha(0.1))
            }
            self.badgeBackgroundView.frame = badgeBackgroundFrame
        }
        
        self.textMaskNode.frame = textFrame.offsetBy(dx: 3.0, dy: 0.0)
        
        if let wallpaperBackgroundNode {
            if self.backgroundContent == nil, let backgroundContent = wallpaperBackgroundNode.makeBubbleBackground(for: .free) {

                self.backgroundContent = backgroundContent
                backgroundContent.view.mask = self.textMaskNode.view
                self.insertSubnode(backgroundContent, at: 0)
            }
            
            if let backgroundContent = self.backgroundContent {
                backgroundContent.frame = CGRect(origin: CGPoint(x: -4.0, y: 0.0), size: CGSize(width: size.width + 4.0 * 2.0, height: size.height))
            }
        } else if let backgroundContent = self.backgroundContent {
            self.backgroundContent = nil
            backgroundContent.removeFromSupernode()
        }
        
        return size
    }
    
    func updateAbsolutePosition(rect: CGRect, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        guard let backgroundContent = self.backgroundContent else {
            return
        }
        var backgroundFrame = backgroundContent.frame
        backgroundFrame.origin.x += rect.minX
        backgroundFrame.origin.y += rect.minY
        backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
    }
}

public final class ChatEmptyNode: ASDisplayNode {
    public enum Subject {
        public enum EmptyType: Equatable {
            case generic
            case joined
            case clearedHistory
            case topic
            case botInfo
            case customGreeting(sticker: TelegramMediaFile?, title: String, text: String)
        }
        
        case emptyChat(EmptyType)
        case detailsPlaceholder
    }
    private let context: AccountContext
    private let interaction: ChatPanelInterfaceInteraction?
    
    private let backgroundNode: NavigationBackgroundNode
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var currentTheme: PresentationTheme?
    private var currentStrings: PresentationStrings?
    
    private var content: (ChatEmptyNodeContentType, ASDisplayNode & ChatEmptyNodeContent)?
    private var attachedDescriptionNode: EmptyAttachedDescriptionNode?
    
    public init(context: AccountContext, interaction: ChatPanelInterfaceInteraction?) {
        self.context = context
        self.interaction = interaction
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
    
    public func animateFromLoadingNode(_ loadingNode: ChatLoadingNode) {
        guard let (_, node) = self.content else {
            return
        }
        
        let duration: Double = 0.3
        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        node.layer.animateScale(from: 0.01, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        
        let targetCornerRadius = self.backgroundNode.backgroundCornerRadius
        let targetFrame = self.backgroundNode.frame
        let initialFrame = loadingNode.convert(loadingNode.progressFrame, to: self)
        
        let transition = ContainedViewLayoutTransition.animated(duration: duration, curve: .spring)
        self.backgroundNode.layer.animateFrame(from: initialFrame, to: targetFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        self.backgroundNode.update(size: initialFrame.size, cornerRadius: initialFrame.size.width / 2.0, transition: .immediate)
        self.backgroundNode.update(size: targetFrame.size, cornerRadius: targetCornerRadius, transition: transition)
        
        if let backgroundContent = self.backgroundContent {
            backgroundContent.layer.animateFrame(from: initialFrame, to: targetFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            backgroundContent.cornerRadius = initialFrame.size.width / 2.0
            transition.updateCornerRadius(layer: backgroundContent.layer, cornerRadius: targetCornerRadius)
        }
        
        if let attachedDescriptionNode = self.attachedDescriptionNode {
            attachedDescriptionNode.layer.animatePosition(from: initialFrame.center, to: attachedDescriptionNode.position, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            attachedDescriptionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            attachedDescriptionNode.layer.animateScale(from: 0.001, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    public func updateLayout(interfaceState: ChatPresentationInterfaceState, subject: Subject, loadingNode: ChatLoadingNode?, backgroundNode: WallpaperBackgroundNode?, size: CGSize, insets: UIEdgeInsets, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.wallpaperBackgroundNode = backgroundNode
        
        if self.currentTheme !== interfaceState.theme || self.currentStrings !== interfaceState.strings {
            self.currentTheme = interfaceState.theme
            self.currentStrings = interfaceState.strings

            self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper), enableBlur: self.context.sharedContext.energyUsageSettings.fullTranslucency && dateFillNeedsBlur(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper), transition: .immediate)
        }
    
        var isScheduledMessages = false
        if case .scheduledMessages = interfaceState.subject {
            isScheduledMessages = true
        }
        
        var contentType: ChatEmptyNodeContentType
        var displayAttachedDescription = false
        switch subject {
        case .detailsPlaceholder:
            contentType = .regular
        case let .emptyChat(emptyType):
            if case .customGreeting = emptyType {
                contentType = .greeting
            } else if case .customChatContents = interfaceState.subject {
                contentType = .cloud
            } else if case .replyThread = interfaceState.chatLocation {
                if case .topic = emptyType {
                    contentType = .topic
                } else {
                    contentType = .regular
                }
            } else if let peer = interfaceState.renderedPeer?.peer, !isScheduledMessages {
                 if peer.id == self.context.account.peerId {
                    contentType = .cloud
                } else if let _ = peer as? TelegramSecretChat {
                    contentType = .secret
                } else if let group = peer as? TelegramGroup, case .creator = group.role {
                    contentType = .group
                } else if let channel = peer as? TelegramChannel, case .group = channel.info, channel.flags.contains(.isCreator) && !channel.flags.contains(.isGigagroup) && !channel.isMonoForum {
                    contentType = .group
                } else if let _ = interfaceState.peerNearbyData {
                    contentType = .peerNearby
                } else if let peer = peer as? TelegramUser {
                    if let sendPaidMessageStars = interfaceState.sendPaidMessageStars, interfaceState.businessIntro == nil {
                        contentType = .starsRequired(sendPaidMessageStars.value)
                    } else if interfaceState.isPremiumRequiredForMessaging {
                        contentType = .premiumRequired
                    } else {
                        if peer.isDeleted || peer.botInfo != nil || peer.flags.contains(.isSupport) || peer.isScam || interfaceState.peerIsBlocked {
                            contentType = .regular
                        } else {
                            contentType = .greeting
                            if interfaceState.businessIntro != nil {
                                displayAttachedDescription = true
                            }
                        }
                    }
                } else if let channel = peer as? TelegramChannel, channel.isMonoForum {
                    if let mainChannel = interfaceState.renderedPeer?.chatOrMonoforumMainPeer as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                        contentType = .regular
                    } else {
                        contentType = .starsRequired(interfaceState.sendPaidMessageStars?.value)
                    }
                } else {
                    contentType = .regular
                }
            } else {
                contentType = .regular
            }
        }
      
        var updateGreetingSticker = false
        var contentTransition = transition
        if self.content?.0 != contentType {
            var animateContentIn = false
            if let node = self.content?.1 {
                node.removeFromSupernode()
                if self.content?.0 != nil, case .greeting = contentType, transition.isAnimated {
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
                let cloudNode = ChatEmptyNodeCloudChatContent()
                node = cloudNode
                cloudNode.shareBusinessLink = { [weak self] url in
                    guard let self, let interfaceInteraction = self.interaction else {
                        return
                    }
                    
                    UIPasteboard.general.string = url
                    
                    let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                    
                    let controller = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { _ in
                        return false
                    })
                    interfaceInteraction.presentControllerInCurrent(controller, nil)
                }
            case .peerNearby:
                node = ChatEmptyNodeNearbyChatContent(context: self.context, interaction: self.interaction)
            case .greeting:
                node = ChatEmptyNodeGreetingChatContent(context: self.context, interaction: self.interaction)
                updateGreetingSticker = true
            case .topic:
                node = ChatEmptyNodeTopicChatContent(context: self.context)
            case .premiumRequired:
                node = ChatEmptyNodePremiumRequiredChatContent(context: self.context, interaction: self.interaction, stars: nil)
            case let .starsRequired(stars):
                node = ChatEmptyNodePremiumRequiredChatContent(context: self.context, interaction: self.interaction, stars: stars)
            }
            self.content = (contentType, node)
            self.addSubnode(node)
            contentTransition = .immediate
            
            if animateContentIn, case let .animated(duration, curve) = transition {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                node.layer.animateScale(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        switch contentType {
        case .peerNearby, .greeting, .premiumRequired, .starsRequired, .cloud:
            self.isUserInteractionEnabled = true
        default:
            self.isUserInteractionEnabled = false
        }

        let displayRect = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
        
        var contentSize = CGSize()
        if let contentNode = self.content?.1 {
            contentSize = contentNode.updateLayout(interfaceState: interfaceState, subject: subject, size: displayRect.size, leftInset: leftInset, rightInset: rightInset, transition: contentTransition)
            
            if updateGreetingSticker {
                self.context.prefetchManager?.prepareNextGreetingSticker()
            }
        }
        
        let contentFrame = CGRect(origin: CGPoint(x: displayRect.minX + leftInset + floor((displayRect.width - leftInset - rightInset - contentSize.width) / 2.0), y: displayRect.minY + floor((displayRect.height - contentSize.height) / 2.0)), size: contentSize)
        if let contentNode = self.content?.1 {
            contentTransition.updateFrame(node: contentNode, frame: contentFrame)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: contentFrame)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: min(20.0, self.backgroundNode.bounds.height / 2.0), transition: transition)
        
        if displayAttachedDescription, let peer = interfaceState.renderedPeer?.chatOrMonoforumMainPeer {
            let isPremium = interfaceState.isPremium
            let attachedDescriptionNode: EmptyAttachedDescriptionNode
            if let current = self.attachedDescriptionNode {
                attachedDescriptionNode = current
            } else {
                attachedDescriptionNode = EmptyAttachedDescriptionNode()
                self.attachedDescriptionNode = attachedDescriptionNode
                self.addSubnode(attachedDescriptionNode)
                
                let strings = interfaceState.strings
                
                attachedDescriptionNode.action = { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    let context = self.context
                    var replaceImpl: ((ViewController) -> Void)?
                    var dismissImpl: (() -> Void)?
                    let controller = PremiumLimitsListScreen(context: context, subject: .business, source: .other, order: [.business], buttonText: strings.Chat_EmptyStateIntroFooterPremiumActionButton, isPremium: false, forceDark: false)
                    controller.action = {
                        if isPremium {
                            dismissImpl?()
                        } else {
                            let controller = PremiumIntroScreen(context: context, source: .settings, forceDark: false)
                            replaceImpl?(controller)
                        }
                    }
                    replaceImpl = { [weak self, weak controller] c in
                        controller?.dismiss(animated: true, completion: {
                            guard let self else {
                                return
                            }
                            self.interaction?.chatController()?.push(c)
                        })
                    }
                    dismissImpl = { [weak controller] in
                        controller?.dismiss(animated: true, completion: {
                        })
                    }
                    self.interaction?.chatController()?.push(controller)
                }
            }
            
            let attachedDescriptionSize = attachedDescriptionNode.update(
                theme: interfaceState.theme,
                strings: interfaceState.strings,
                chatWallpaper: interfaceState.chatWallpaper,
                peer: EnginePeer(peer),
                wallpaperBackgroundNode: backgroundNode,
                constrainedSize: CGSize(width: size.width - insets.left - insets.right, height: 200.0)
            )
            let attachedDescriptionFrame = CGRect(origin: CGPoint(x: leftInset + floor((size.width - leftInset - rightInset - attachedDescriptionSize.width) * 0.5), y: contentFrame.maxY + 4.0), size: attachedDescriptionSize)
            transition.updateFrame(node: attachedDescriptionNode, frame: attachedDescriptionFrame)
            
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = attachedDescriptionNode.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                attachedDescriptionNode.updateAbsolutePosition(rect: backgroundFrame, containerSize: containerSize, transition: .immediate)
            }
        } else if let attachedDescriptionNode = self.attachedDescriptionNode {
            self.attachedDescriptionNode = nil
            attachedDescriptionNode.removeFromSupernode()
        }
    
        if backgroundNode?.hasExtraBubbleBackground() == true {
            if self.backgroundContent == nil, let backgroundContent = backgroundNode?.makeBubbleBackground(for: .free) {
                backgroundContent.clipsToBounds = true

                self.backgroundContent = backgroundContent
                self.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            self.backgroundNode.isHidden = true
            backgroundContent.cornerRadius = min(20.0, self.backgroundNode.bounds.height / 2.0)            
            transition.updateFrame(node: backgroundContent, frame: contentFrame)

            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        } else {
            self.backgroundNode.isHidden = false
        }
        
        if let loadingNode = loadingNode {
            self.animateFromLoadingNode(loadingNode)
        }
    }
    
    
    public func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
        
        if let attachedDescriptionNode = self.attachedDescriptionNode {
            var backgroundFrame = attachedDescriptionNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            attachedDescriptionNode.updateAbsolutePosition(rect: backgroundFrame, containerSize: containerSize, transition: transition)
        }
    }
}
