import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import AnimatedAvatarSetNode
import ContextUI
import AvatarNode
import ReactionImageComponent
import AnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import TextFormat
import EmojiStatusComponent

private let avatarFont = avatarPlaceholderFont(size: 16.0)

public final class ReactionListContextMenuContent: ContextControllerItemsContent {
    private final class BackButtonNode: HighlightTrackingButtonNode {
        let highlightBackgroundNode: ASDisplayNode
        let titleLabelNode: ImmediateTextNode
        let separatorNode: ASDisplayNode
        let iconNode: ASImageNode
        
        var action: (() -> Void)?
        
        private var theme: PresentationTheme?
        
        init() {
            self.highlightBackgroundNode = ASDisplayNode()
            self.highlightBackgroundNode.isAccessibilityElement = false
            self.highlightBackgroundNode.alpha = 0.0
            
            self.titleLabelNode = ImmediateTextNode()
            self.titleLabelNode.isAccessibilityElement = false
            self.titleLabelNode.maximumNumberOfLines = 1
            self.titleLabelNode.isUserInteractionEnabled = false
            
            self.iconNode = ASImageNode()
            self.iconNode.isAccessibilityElement = false
            
            self.separatorNode = ASDisplayNode()
            self.separatorNode.isAccessibilityElement = false
            
            super.init()
            
            self.addSubnode(self.separatorNode)
            self.addSubnode(self.highlightBackgroundNode)
            self.addSubnode(self.titleLabelNode)
            self.addSubnode(self.iconNode)
            
            self.isAccessibilityElement = true
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let strongSelf = self else {
                    return
                }
                if highlighted {
                    strongSelf.highlightBackgroundNode.alpha = 1.0
                } else {
                    let previousAlpha = strongSelf.highlightBackgroundNode.alpha
                    strongSelf.highlightBackgroundNode.alpha = 0.0
                    strongSelf.highlightBackgroundNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                }
            }
            
            self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }
        
        @objc private func pressed() {
            self.action?()
        }
        
        func update(size: CGSize, presentationData: PresentationData, isLast: Bool) {
            let standardIconWidth: CGFloat = 32.0
            let sideInset: CGFloat = 16.0
            let iconSideInset: CGFloat = 12.0
            
            if self.theme !== presentationData.theme {
                self.theme = presentationData.theme
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: presentationData.theme.contextMenu.primaryColor)
                
                self.accessibilityLabel = presentationData.strings.Common_Back
            }
            
            self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
            self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
            
            self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
            
            self.titleLabelNode.attributedText = NSAttributedString(string: presentationData.strings.Common_Back, font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
            let titleSize = self.titleLabelNode.updateLayout(CGSize(width: size.width - sideInset - standardIconWidth, height: 100.0))
            self.titleLabelNode.frame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            
            if let iconImage = self.iconNode.image {
                let iconWidth = max(standardIconWidth, iconImage.size.width)
                let iconFrame = CGRect(origin: CGPoint(x: size.width - iconSideInset - iconWidth + floor((iconWidth - iconImage.size.width) / 2.0), y: floor((size.height - iconImage.size.height) / 2.0)), size: iconImage.size)
                self.iconNode.frame = iconFrame
            }
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel))
            self.separatorNode.isHidden = isLast
        }
    }
    
    private final class ReactionTabListNode: ASDisplayNode {
        private final class ItemNode: ASDisplayNode {
            let context: AccountContext
            let animationCache: AnimationCache
            let animationRenderer: MultiAnimationRenderer
            let reaction: MessageReaction.Reaction?
            let count: Int
            
            let titleLabelNode: ImmediateTextNode
            var iconNode: ASImageNode?
            var reactionLayer: InlineStickerItemLayer?
            
            private var iconFrame: CGRect?
            private var file: TelegramMediaFile?
            private var fileDisposable: Disposable?
            
            private var theme: PresentationTheme?
            
            var action: ((MessageReaction.Reaction?) -> Void)?
            
            init(context: AccountContext, availableReactions: AvailableReactions?, reaction: MessageReaction.Reaction?, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, count: Int) {
                self.context = context
                self.reaction = reaction
                self.count = count
                self.animationCache = animationCache
                self.animationRenderer = animationRenderer
                
                self.titleLabelNode = ImmediateTextNode()
                self.titleLabelNode.isUserInteractionEnabled = false
                
                super.init()
                
                self.addSubnode(self.titleLabelNode)
                
                if let reaction = reaction {
                    switch reaction {
                    case .builtin:
                        if let availableReactions = availableReactions {
                            for availableReaction in availableReactions.reactions {
                                if availableReaction.value == reaction {
                                    self.file = availableReaction.centerAnimation
                                    self.updateReactionLayer()
                                    break
                                }
                            }
                        }
                    case let .custom(fileId):
                        self.fileDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                        |> deliverOnMainQueue).start(next: { [weak self] files in
                            guard let strongSelf = self, let file = files[fileId] else {
                                return
                            }
                            strongSelf.file = file
                            strongSelf.updateReactionLayer()
                        })
                    }
                } else {
                    let iconNode = ASImageNode()
                    self.iconNode = iconNode
                    self.addSubnode(iconNode)
                }
                
                self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            }
            
            deinit {
                self.fileDisposable?.dispose()
            }
            
            @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
                if case .ended = recognizer.state {
                    self.action?(self.reaction)
                }
            }
            
            private func updateReactionLayer() {
                guard let file = self.file else {
                    return
                }
                
                if let reactionLayer = self.reactionLayer {
                    self.reactionLayer = nil
                    reactionLayer.removeFromSuperlayer()
                }
                
                let reactionLayer = InlineStickerItemLayer(
                    context: context,
                    attemptSynchronousLoad: false,
                    emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                    file: file,
                    cache: self.animationCache,
                    renderer: self.animationRenderer,
                    placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                    pointSize: CGSize(width: 50.0, height: 50.0)
                )
                self.reactionLayer = reactionLayer
                
                if let reaction = self.reaction, case .custom = reaction {
                    reactionLayer.isVisibleForAnimations = true
                }
                self.layer.addSublayer(reactionLayer)
                
                if var iconFrame = self.iconFrame {
                    if let reaction = self.reaction, case .builtin = reaction {
                        iconFrame = iconFrame.insetBy(dx: -iconFrame.width * 0.5, dy: -iconFrame.height * 0.5)
                    }
                    reactionLayer.frame = iconFrame
                }
            }
            
            func update(presentationData: PresentationData, constrainedSize: CGSize, isSelected: Bool) -> CGSize {
                if presentationData.theme !== self.theme {
                    self.theme = presentationData.theme
                    
                    if let iconNode = self.iconNode {
                        iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reactions"), color: presentationData.theme.contextMenu.primaryColor)
                    }
                }
                
                let sideInset: CGFloat = 12.0
                let iconSpacing: CGFloat = 4.0
                
                
                let iconSize = CGSize(width: 22.0, height: 22.0)
                self.iconFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((constrainedSize.height - iconSize.height) / 2.0)), size: iconSize)
                
                self.titleLabelNode.attributedText = NSAttributedString(string: "\(count)", font: Font.medium(11.0), textColor: presentationData.theme.contextMenu.primaryColor)
                let titleSize = self.titleLabelNode.updateLayout(constrainedSize)
                
                let contentSize = CGSize(width: sideInset * 2.0 + titleSize.width + iconSize.width + iconSpacing, height: titleSize.height)
                
                self.titleLabelNode.frame = CGRect(origin: CGPoint(x: sideInset + iconSize.width + iconSpacing, y: floorToScreenPixels((constrainedSize.height - titleSize.height) / 2.0)), size: titleSize)
                
                if let iconNode = self.iconNode {
                    iconNode.frame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((constrainedSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
                
                if let reactionLayer = self.reactionLayer, var iconFrame = self.iconFrame {
                    if let reaction = self.reaction, case .builtin = reaction {
                        iconFrame = iconFrame.insetBy(dx: -iconFrame.width * 0.5, dy: -iconFrame.height * 0.5)
                    }
                    reactionLayer.frame = iconFrame
                }
                
                return CGSize(width: contentSize.width, height: constrainedSize.height)
            }
        }
        
        private let scrollNode: ASScrollNode
        private let selectionHighlightNode: ASDisplayNode
        private let itemNodes: [ItemNode]
        
        struct ScrollToTabReaction {
            var value: MessageReaction.Reaction?
        }
        var scrollToTabReaction: ScrollToTabReaction?
        
        var action: ((MessageReaction.Reaction?) -> Void)?
        
        init(context: AccountContext, availableReactions: AvailableReactions?, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, reactions: [(MessageReaction.Reaction?, Int)], message: EngineMessage) {
            self.scrollNode = ASScrollNode()
            self.scrollNode.canCancelAllTouchesInViews = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.showsVerticalScrollIndicator = false
            self.scrollNode.view.showsHorizontalScrollIndicator = false
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }
            self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
            
            self.itemNodes = reactions.map { reaction, count in
                return ItemNode(context: context, availableReactions: availableReactions, reaction: reaction, animationCache: animationCache, animationRenderer: animationRenderer, count: count)
            }
            
            self.selectionHighlightNode = ASDisplayNode()
            
            super.init()
            
            self.addSubnode(self.scrollNode)
            
            self.scrollNode.addSubnode(self.selectionHighlightNode)
            
            for itemNode in self.itemNodes {
                self.scrollNode.addSubnode(itemNode)
                itemNode.action = { [weak self] reaction in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.scrollToTabReaction = ScrollToTabReaction(value: reaction)
                    strongSelf.action?(reaction)
                }
            }
        }
        
        func update(size: CGSize, presentationData: PresentationData, selectedReaction: MessageReaction.Reaction?, transition: ContainedViewLayoutTransition) {
            let sideInset: CGFloat = 11.0
            let spacing: CGFloat = 0.0
            let verticalInset: CGFloat = 7.0
            
            self.selectionHighlightNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
            let highlightHeight: CGFloat = size.height - verticalInset * 2.0
            self.selectionHighlightNode.cornerRadius = highlightHeight / 2.0
            
            var contentWidth: CGFloat = sideInset
            for i in 0 ..< self.itemNodes.count {
                if i != 0 {
                    contentWidth += spacing
                }
                
                let itemNode = self.itemNodes[i]
                let itemSize = itemNode.update(presentationData: presentationData, constrainedSize: CGSize(width: size.width, height: size.height), isSelected: itemNode.reaction == selectedReaction)
                let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: itemSize)
                itemNode.frame = itemFrame
                
                if itemNode.reaction == selectedReaction {
                    transition.updateFrame(node: self.selectionHighlightNode, frame: CGRect(origin: CGPoint(x: itemFrame.minX, y: verticalInset), size: CGSize(width: itemFrame.width, height: highlightHeight)))
                }
                
                contentWidth += itemSize.width
            }
            contentWidth += sideInset
            
            self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
            
            let contentSize = CGSize(width: contentWidth, height: size.height)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
            
            if let scrollToTabReaction = self.scrollToTabReaction {
                self.scrollToTabReaction = nil
                for itemNode in self.itemNodes {
                    if itemNode.reaction == scrollToTabReaction.value {
                        self.scrollNode.view.scrollRectToVisible(itemNode.frame.insetBy(dx: -sideInset - 8.0, dy: 0.0), animated: transition.isAnimated)
                        break
                    }
                }
            }
        }
    }
    
    private final class ReactionsTabNode: ASDisplayNode, UIScrollViewDelegate {
        private final class ItemNode: HighlightTrackingButtonNode {
            let context: AccountContext
            let availableReactions: AvailableReactions?
            let animationCache: AnimationCache
            let animationRenderer: MultiAnimationRenderer
            let highlightBackgroundNode: ASDisplayNode
            let avatarNode: AvatarNode
            let titleLabelNode: ImmediateTextNode
            var credibilityIconView: ComponentView<Empty>?
            let separatorNode: ASDisplayNode
            
            private var reactionLayer: InlineStickerItemLayer?
            private var iconFrame: CGRect?
            private var file: TelegramMediaFile?
            private var fileDisposable: Disposable?
            
            let action: () -> Void
            
            private var item: EngineMessageReactionListContext.Item?
            
            init(context: AccountContext, availableReactions: AvailableReactions?, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, action: @escaping () -> Void) {
                self.action = action
                self.context = context
                self.availableReactions = availableReactions
                self.animationCache = animationCache
                self.animationRenderer = animationRenderer
                
                self.avatarNode = AvatarNode(font: avatarFont)
                self.avatarNode.isAccessibilityElement = false
                
                self.highlightBackgroundNode = ASDisplayNode()
                self.highlightBackgroundNode.isAccessibilityElement = false
                self.highlightBackgroundNode.alpha = 0.0
                
                self.titleLabelNode = ImmediateTextNode()
                self.titleLabelNode.isAccessibilityElement = false
                self.titleLabelNode.maximumNumberOfLines = 1
                self.titleLabelNode.isUserInteractionEnabled = false
                
                self.separatorNode = ASDisplayNode()
                self.separatorNode.isAccessibilityElement = false
                
                super.init()
                
                self.isAccessibilityElement = true
                
                self.addSubnode(self.separatorNode)
                self.addSubnode(self.highlightBackgroundNode)
                self.addSubnode(self.avatarNode)
                self.addSubnode(self.titleLabelNode)
                
                self.highligthedChanged = { [weak self] highlighted in
                    guard let strongSelf = self else {
                        return
                    }
                    if highlighted {
                        strongSelf.highlightBackgroundNode.alpha = 1.0
                    } else {
                        let previousAlpha = strongSelf.highlightBackgroundNode.alpha
                        strongSelf.highlightBackgroundNode.alpha = 0.0
                        strongSelf.highlightBackgroundNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                    }
                }
                
                self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
            }
            
            deinit {
                self.fileDisposable?.dispose()
            }
            
            @objc private func pressed() {
                self.action()
            }
            
            private func updateReactionLayer() {
                guard let file = self.file else {
                    return
                }
                
                if let reactionLayer = self.reactionLayer {
                    self.reactionLayer = nil
                    reactionLayer.removeFromSuperlayer()
                }
                
                let reactionLayer = InlineStickerItemLayer(
                    context: context,
                    attemptSynchronousLoad: false,
                    emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                    file: file,
                    cache: self.animationCache,
                    renderer: self.animationRenderer,
                    placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                    pointSize: CGSize(width: 50.0, height: 50.0)
                )
                self.reactionLayer = reactionLayer
                if let item = self.item, let reaction = item.reaction, case .custom = reaction {
                    reactionLayer.isVisibleForAnimations = true
                }
                self.layer.addSublayer(reactionLayer)
                
                if var iconFrame = self.iconFrame {
                    if let item = self.item, let reaction = item.reaction, case .builtin = reaction {
                        iconFrame = iconFrame.insetBy(dx: -iconFrame.width * 0.5, dy: -iconFrame.height * 0.5)
                    }
                    reactionLayer.frame = iconFrame
                }
            }
            
            func update(size: CGSize, presentationData: PresentationData, item: EngineMessageReactionListContext.Item, isLast: Bool, syncronousLoad: Bool) {
                let avatarInset: CGFloat = 12.0
                let avatarSpacing: CGFloat = 8.0
                let avatarSize: CGFloat = 28.0
                let sideInset: CGFloat = 16.0
                
                let reaction: MessageReaction.Reaction? = item.reaction
                
                if reaction != self.item?.reaction {
                    if let reaction = reaction {
                        switch reaction {
                        case .builtin:
                            if let availableReactions = self.availableReactions {
                                for availableReaction in availableReactions.reactions {
                                    if availableReaction.value == reaction {
                                        self.file = availableReaction.centerAnimation
                                        self.updateReactionLayer()
                                        break
                                    }
                                }
                            }
                        case let .custom(fileId):
                            self.fileDisposable = (self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                            |> deliverOnMainQueue).start(next: { [weak self] files in
                                guard let strongSelf = self, let file = files[fileId] else {
                                    return
                                }
                                strongSelf.file = file
                                strongSelf.updateReactionLayer()
                            })
                        }
                    } else {
                        self.file = nil
                        self.fileDisposable?.dispose()
                        self.fileDisposable = nil
                        
                        if let reactionLayer = self.reactionLayer {
                            self.reactionLayer = nil
                            reactionLayer.removeFromSuperlayer()
                        }
                    }
                }
                
                if self.item != item {
                    self.item = item
                    
                    let reactionStringValue: String
                    if let reaction = item.reaction {
                        switch reaction {
                        case let .builtin(value):
                            reactionStringValue = value
                        case .custom:
                            reactionStringValue = ""
                        }
                    } else {
                        reactionStringValue = ""
                    }
                    self.accessibilityLabel = "\(item.peer.debugDisplayTitle) \(reactionStringValue)"
                }
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                var currentCredibilityIcon: EmojiStatusComponent.Content?
                if item.peer.isScam {
                    currentCredibilityIcon = .text(color: presentationData.theme.chat.message.incoming.scamColor, string: presentationData.strings.Message_ScamAccount.uppercased())
                } else if item.peer.isFake {
                    currentCredibilityIcon = .text(color: presentationData.theme.chat.message.incoming.scamColor, string: presentationData.strings.Message_FakeAccount.uppercased())
                } else if case let .user(user) = item.peer, let emojiStatus = user.emojiStatus {
                    currentCredibilityIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: UIColor(white: 0.0, alpha: 0.1), themeColor: presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                } else if item.peer.isVerified {
                    currentCredibilityIcon = .verified(fillColor: presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                } else if item.peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                    currentCredibilityIcon = .premium(color: presentationData.theme.list.itemCheckColors.fillColor)
                }
                
                var credibilityIconSize: CGSize?
                if let currentCredibilityIcon = currentCredibilityIcon {
                    let credibilityIconView: ComponentView<Empty>
                    if let current = self.credibilityIconView {
                        credibilityIconView = current
                    } else {
                        credibilityIconView = ComponentView<Empty>()
                        self.credibilityIconView = credibilityIconView
                    }
                    credibilityIconSize = credibilityIconView.update(
                        transition: .immediate,
                        component: AnyComponent(EmojiStatusComponent(
                            context: self.context,
                            animationCache: self.context.animationCache,
                            animationRenderer: self.context.animationRenderer,
                            content: currentCredibilityIcon,
                            isVisibleForAnimations: true,
                            action: nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: 24.0, height: 24.0)
                    )
                }
                
                var additionalTitleInset: CGFloat = 0.0
                if let credibilityIconSize = credibilityIconSize {
                    additionalTitleInset += 3.0 + credibilityIconSize.width
                }
                
                self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
                self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                
                self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                
                self.avatarNode.frame = CGRect(origin: CGPoint(x: avatarInset, y: floor((size.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                self.avatarNode.setPeer(context: self.context, theme: presentationData.theme, peer: item.peer, synchronousLoad: true)
                
                self.titleLabelNode.attributedText = NSAttributedString(string: item.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
                var maxTextWidth: CGFloat = size.width - avatarInset - avatarSize - avatarSpacing - sideInset - additionalTitleInset
                if reaction != nil {
                    maxTextWidth -= 32.0
                }
                let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                let titleFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarSpacing, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                self.titleLabelNode.frame = titleFrame
                
                if let credibilityIconView = self.credibilityIconView, let credibilityIconSize = credibilityIconSize {
                    if let credibilityIconComponentView = credibilityIconView.view {
                        if credibilityIconComponentView.superview == nil {
                            self.view.addSubview(credibilityIconComponentView)
                        }
                        credibilityIconComponentView.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - credibilityIconSize.height / 2.0) + 1.0 - UIScreenPixel), size: credibilityIconSize)
                    }
                } else if let credibilityIconView = self.credibilityIconView {
                    self.credibilityIconView = nil
                    credibilityIconView.view?.removeFromSuperview()
                }
                
                let reactionSize = CGSize(width: 22.0, height: 22.0)
                self.iconFrame = CGRect(origin: CGPoint(x: size.width - 32.0 - floor((32.0 - reactionSize.width) / 2.0), y: floor((size.height - reactionSize.height) / 2.0)), size: reactionSize)
                
                if let reactionLayer = self.reactionLayer, var iconFrame = self.iconFrame {
                    if let reaction = reaction, case .builtin = reaction {
                        iconFrame = iconFrame.insetBy(dx: -iconFrame.width * 0.5, dy: -iconFrame.height * 0.5)
                    }
                    reactionLayer.frame = iconFrame
                }
                
                self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel))
                self.separatorNode.isHidden = isLast
            }
        }
        
        private struct ItemsState {
            let listState: EngineMessageReactionListContext.State
            let readStats: MessageReadStats?
            
            let mergedItems: [EngineMessageReactionListContext.Item]
            
            init(listState: EngineMessageReactionListContext.State, readStats: MessageReadStats?) {
                self.listState = listState
                self.readStats = readStats
                
                var mergedItems: [EngineMessageReactionListContext.Item] = listState.items
                if !listState.canLoadMore, let readStats = readStats {                    
                    var existingPeers = Set(mergedItems.map(\.peer.id))
                    for peer in readStats.peers {
                        if !existingPeers.contains(peer.id) {
                            existingPeers.insert(peer.id)
                            mergedItems.append(EngineMessageReactionListContext.Item(peer: peer, reaction: nil))
                        }
                    }
                }
                
                self.mergedItems = mergedItems
            }
            
            var totalCount: Int {
                if !self.listState.canLoadMore {
                    return self.mergedItems.count
                } else {
                    let reactionCount = self.listState.totalCount
                    var value = reactionCount
                    if let readStats = self.readStats {
                        if reactionCount < readStats.peers.count && self.listState.hasOutgoingReaction {
                            value = readStats.peers.count + 1
                        } else {
                            value = max(reactionCount, readStats.peers.count)
                        }
                    }
                    return value
                }
            }
            
            var canLoadMore: Bool {
                return self.listState.canLoadMore
            }
            
            func item(at index: Int) -> EngineMessageReactionListContext.Item? {
                if index < self.mergedItems.count {
                    return self.mergedItems[index]
                } else {
                    return nil
                }
            }
        }
        
        private let context: AccountContext
        private let availableReactions: AvailableReactions?
        private let animationCache: AnimationCache
        private let animationRenderer: MultiAnimationRenderer
        let reaction: MessageReaction.Reaction?
        private let requestUpdate: (ReactionsTabNode, ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ReactionsTabNode, ContainedViewLayoutTransition) -> Void
        private let openPeer: (EnginePeer) -> Void
        
        private var hasMore: Bool = false
        
        private let scrollNode: ASScrollNode
        private var ignoreScrolling: Bool = false
        private var animateIn: Bool = false
        private var bottomScrollInset: CGFloat = 0.0
        
        private var presentationData: PresentationData?
        private var currentSize: CGSize?
        private var apparentHeight: CGFloat = 0.0
        
        private let listContext: EngineMessageReactionListContext
        private var state: ItemsState
        private var stateDisposable: Disposable?
        
        private var itemNodes: [Int: ItemNode] = [:]
        
        private var placeholderItemImage: UIImage?
        private var placeholderLayers: [Int: SimpleLayer] = [:]
        
        init(
            context: AccountContext,
            availableReactions: AvailableReactions?,
            animationCache: AnimationCache,
            animationRenderer: MultiAnimationRenderer,
            message: EngineMessage,
            reaction: MessageReaction.Reaction?,
            readStats: MessageReadStats?,
            requestUpdate: @escaping (ReactionsTabNode, ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ReactionsTabNode, ContainedViewLayoutTransition) -> Void,
            openPeer: @escaping (EnginePeer) -> Void
        ) {
            self.context = context
            self.availableReactions = availableReactions
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
            self.reaction = reaction
            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight
            self.openPeer = openPeer
            
            self.listContext = context.engine.messages.messageReactionList(message: message, reaction: reaction)
            self.state = ItemsState(listState: EngineMessageReactionListContext.State(message: message, reaction: reaction), readStats: readStats)
            
            self.scrollNode = ASScrollNode()
            self.scrollNode.canCancelAllTouchesInViews = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.showsVerticalScrollIndicator = false
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }
            self.scrollNode.clipsToBounds = false
            
            super.init()
            
            self.addSubnode(self.scrollNode)
            self.scrollNode.view.delegate = self
            
            self.clipsToBounds = true
            
            self.stateDisposable = (self.listContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                let updatedState = ItemsState(listState: state, readStats: strongSelf.state.readStats)
                var animateIn = false
                if strongSelf.state.item(at: 0) == nil && updatedState.item(at: 0) != nil {
                    animateIn = true
                }
                strongSelf.state = updatedState
                strongSelf.animateIn = true
                strongSelf.requestUpdate(strongSelf, animateIn ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
                if animateIn {
                    for (_, itemNode) in strongSelf.itemNodes {
                        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            })
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateVisibleItems(animated: false, syncronousLoad: false)
            
            if let size = self.currentSize {
                var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
                apparentHeight = max(apparentHeight, 44.0)
                apparentHeight = min(apparentHeight, size.height + 100.0)
                if self.apparentHeight != apparentHeight {
                    self.apparentHeight = apparentHeight
                    
                    self.requestUpdateApparentHeight(self, .immediate)
                }
            }
        }
        
        private func updateVisibleItems(animated: Bool, syncronousLoad: Bool) {
            guard let size = self.currentSize else {
                return
            }
            guard let presentationData = self.presentationData else {
                return
            }
            let itemHeight: CGFloat = 44.0
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -180.0)
            
            var validIds = Set<Int>()
            var validPlaceholderIds = Set<Int>()
            
            let minVisibleIndex = max(0, Int(floor(visibleBounds.minY / itemHeight)))
            let maxVisibleIndex = Int(ceil(visibleBounds.maxY / itemHeight))
            
            if minVisibleIndex <= maxVisibleIndex {
                for index in minVisibleIndex ... maxVisibleIndex {
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(index) * itemHeight), size: CGSize(width: size.width, height: itemHeight))
                    
                    if let item = self.state.item(at: index) {
                        validIds.insert(index)
                        
                        let itemNode: ItemNode
                        if let current = self.itemNodes[index] {
                            itemNode = current
                        } else {
                            let openPeer = self.openPeer
                            let peer = item.peer
                            itemNode = ItemNode(context: self.context, availableReactions: self.availableReactions, animationCache: self.animationCache, animationRenderer: self.animationRenderer, action: {
                                openPeer(peer)
                            })
                            self.itemNodes[index] = itemNode
                            self.scrollNode.addSubnode(itemNode)
                        }
                        
                        itemNode.update(size: itemFrame.size, presentationData: presentationData, item: item, isLast: self.state.item(at: index + 1) == nil, syncronousLoad: syncronousLoad)
                        itemNode.frame = itemFrame
                    } else if index < self.state.totalCount {
                        validPlaceholderIds.insert(index)
                        
                        let placeholderLayer: SimpleLayer
                        if let current = self.placeholderLayers[index] {
                            placeholderLayer = current
                        } else {
                            placeholderLayer = SimpleLayer()
                            if let placeholderItemImage = self.placeholderItemImage {
                                ASDisplayNodeSetResizableContents(placeholderLayer, placeholderItemImage)
                            }
                            self.placeholderLayers[index] = placeholderLayer
                            self.scrollNode.layer.addSublayer(placeholderLayer)
                        }
                        
                        placeholderLayer.frame = itemFrame
                    }
                }
            }
            
            var removeIds: [Int] = []
            for (id, itemNode) in self.itemNodes {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemNode.removeFromSupernode()
                }
            }
            for id in removeIds {
                self.itemNodes.removeValue(forKey: id)
            }
            
            var removePlaceholderIds: [Int] = []
            for (id, placeholderLayer) in self.placeholderLayers {
                if !validPlaceholderIds.contains(id) {
                    removePlaceholderIds.append(id)
                    if animated || self.animateIn {
                        placeholderLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholderLayer] _ in
                            placeholderLayer?.removeFromSuperlayer()
                        })
                    } else {
                        placeholderLayer.removeFromSuperlayer()
                    }
                }
            }
            for id in removePlaceholderIds {
                self.placeholderLayers.removeValue(forKey: id)
            }
            
            if self.state.canLoadMore && maxVisibleIndex >= self.state.listState.items.count - 16 {
                self.listContext.loadMore()
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var extendedScrollNodeFrame = self.scrollNode.frame
            extendedScrollNodeFrame.size.height += self.bottomScrollInset
            
            if extendedScrollNodeFrame.contains(point) {
                return self.scrollNode.view.hitTest(self.view.convert(point, to: self.scrollNode.view), with: event)
            }
            
            return super.hitTest(point, with: event)
        }
        
        func update(presentationData: PresentationData, constrainedSize: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (height: CGFloat, apparentHeight: CGFloat) {
            let itemHeight: CGFloat = 44.0
            
            if self.presentationData?.theme !== presentationData.theme {
                let sideInset: CGFloat = 40.0
                let avatarInset: CGFloat = 12.0
                let avatarSpacing: CGFloat = 8.0
                let avatarSize: CGFloat = 28.0
                let lineHeight: CGFloat = 8.0
                
                let shimmeringForegroundColor: UIColor
                let shimmeringColor: UIColor
                if presentationData.theme.overallDarkAppearance {
                    let backgroundColor = presentationData.theme.contextMenu.backgroundColor.blitOver(presentationData.theme.list.plainBackgroundColor, alpha: 1.0)

                    shimmeringForegroundColor = presentationData.theme.contextMenu.primaryColor.blitOver(backgroundColor, alpha: 0.1)
                    shimmeringColor = presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3)
                } else {
                    shimmeringForegroundColor = presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.07)
                    shimmeringColor = presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3)
                }
                let _ = shimmeringColor
                
                self.placeholderItemImage = generateImage(CGSize(width: avatarInset + avatarSize + avatarSpacing + lineHeight + 2.0 + sideInset, height: itemHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(shimmeringForegroundColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: avatarInset, y: floor((size.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
                    
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarSpacing, y: floor((size.height - lineHeight) / 2.0)), size: CGSize(width: lineHeight + 2.0, height: lineHeight)))
                })?.stretchableImage(withLeftCapWidth: Int(avatarInset + avatarSize + avatarSpacing + lineHeight / 2.0 + 1.0), topCapHeight: 0)
                
                if let placeholderItemImage = self.placeholderItemImage {
                    for (_, placeholderLayer) in self.placeholderLayers {
                        ASDisplayNodeSetResizableContents(placeholderLayer, placeholderItemImage)
                    }
                }
            }
            self.presentationData = presentationData
            
            let size = CGSize(width: constrainedSize.width, height: CGFloat(self.state.totalCount) * itemHeight)
            
            let containerSize = CGSize(width: size.width, height: min(constrainedSize.height, size.height))
            self.currentSize = containerSize
            
            self.ignoreScrolling = true
            
            if self.scrollNode.frame != CGRect(origin: CGPoint(), size: containerSize) {
                self.scrollNode.frame = CGRect(origin: CGPoint(), size: containerSize)
            }
            if self.scrollNode.view.contentInset.bottom != bottomInset {
                self.scrollNode.view.contentInset.bottom = bottomInset
            }
            self.bottomScrollInset = bottomInset
            let scrollContentSize = CGSize(width: size.width, height: size.height)
            if self.scrollNode.view.contentSize != scrollContentSize {
                self.scrollNode.view.contentSize = scrollContentSize
            }
            self.ignoreScrolling = false
            
            self.updateVisibleItems(animated: transition.isAnimated, syncronousLoad: !transition.isAnimated)
            
            self.animateIn = false
            
            var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
            apparentHeight = max(apparentHeight, 44.0)
            apparentHeight = min(apparentHeight, containerSize.height + 100.0)
            self.apparentHeight = apparentHeight
            
            return (containerSize.height, apparentHeight)
        }
    }
    
    final class ItemsNode: ASDisplayNode, ContextControllerItemsNode, UIGestureRecognizerDelegate {
        private let context: AccountContext
        private let availableReactions: AvailableReactions?
        private let animationCache: AnimationCache
        private let animationRenderer: MultiAnimationRenderer
        private let message: EngineMessage
        private let readStats: MessageReadStats?
        private let reactions: [(MessageReaction.Reaction?, Int)]
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ContainedViewLayoutTransition) -> Void
        
        private var presentationData: PresentationData
        
        private var backButtonNode: BackButtonNode?
        private var separatorNode: ASDisplayNode?
        private var tabListNode: ReactionTabListNode?
        
        private var currentTabIndex: Int = 0
        private var visibleTabNodes: [Int: ReactionsTabNode] = [:]
        
        private struct InteractiveTransitionState {
            var toIndex: Int
            var progress: CGFloat
        }
        private var interactiveTransitionState: InteractiveTransitionState?
        
        private let openPeer: (EnginePeer) -> Void
        
        private(set) var apparentHeight: CGFloat = 0.0
        
        init(
            context: AccountContext,
            availableReactions: AvailableReactions?,
            animationCache: AnimationCache,
            animationRenderer: MultiAnimationRenderer,
            message: EngineMessage,
            reaction: MessageReaction.Reaction?,
            readStats: MessageReadStats?,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            back: (() -> Void)?,
            openPeer: @escaping (EnginePeer) -> Void
        ) {
            self.context = context
            self.availableReactions = availableReactions
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
            self.message = message
            self.readStats = readStats
            self.openPeer = openPeer
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            
            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight
            
            //var requestUpdateTab: ((ReactionsTabNode, ContainedViewLayoutTransition) -> Void)?
            //var requestUpdateTabApparentHeight: ((ReactionsTabNode, ContainedViewLayoutTransition) -> Void)?
            
            if let back = back {
                self.backButtonNode = BackButtonNode()
                self.backButtonNode?.action = {
                    back()
                }
            }
            
            var reactions: [(MessageReaction.Reaction?, Int)] = []
            var totalCount: Int = 0
            if let reactionsAttribute = message._asMessage().reactionsAttribute {
                for listReaction in reactionsAttribute.reactions {
                    if reaction == nil || listReaction.value == reaction {
                        totalCount += Int(listReaction.count)
                        reactions.append((listReaction.value, Int(listReaction.count)))
                    }
                }
            }
            if reaction == nil {
                reactions.insert((nil, totalCount), at: 0)
            }
            
            if reactions.count > 2 && totalCount > 10 {
                self.tabListNode = ReactionTabListNode(context: context, availableReactions: availableReactions, animationCache: animationCache, animationRenderer: animationRenderer, reactions: reactions, message: message)
            }
            
            self.reactions = reactions
            
            super.init()
            
            if self.backButtonNode != nil || self.tabListNode != nil {
                self.separatorNode = ASDisplayNode()
            }
            
            if let backButtonNode = self.backButtonNode {
                self.addSubnode(backButtonNode)
            }
            if let tabListNode = self.tabListNode {
                self.addSubnode(tabListNode)
            }
            if let separatorNode = self.separatorNode {
                self.addSubnode(separatorNode)
            }
            
            self.tabListNode?.action = { [weak self] reaction in
                guard let strongSelf = self else {
                    return
                }
                guard let tabIndex = strongSelf.reactions.firstIndex(where: { $0.0 == reaction }) else {
                    return
                }
                guard strongSelf.currentTabIndex != tabIndex else {
                    return
                }
                strongSelf.tabListNode?.scrollToTabReaction = ReactionTabListNode.ScrollToTabReaction(value: reaction)
                strongSelf.currentTabIndex = tabIndex
                
                /*let currentTabNode = ReactionsTabNode(
                    context: context,
                    availableReactions: availableReactions,
                    message: message,
                    reaction: reaction,
                    readStats: nil,
                    requestUpdate: { tab, transition in
                        requestUpdateTab?(tab, transition)
                    },
                    requestUpdateApparentHeight: { tab, transition in
                        requestUpdateTabApparentHeight?(tab, transition)
                    },
                    openPeer: { id in
                        openPeer(id)
                    }
                )
                strongSelf.currentTabNode = currentTabNode
                strongSelf.addSubnode(currentTabNode)*/
                strongSelf.requestUpdate(.animated(duration: 0.45, curve: .spring))
            }
            
            /*requestUpdateTab = { [weak self] tab, transition in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                    strongSelf.requestUpdate(transition)
                }
            }
            
            requestUpdateTabApparentHeight = { [weak self] tab, transition in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                    strongSelf.requestUpdateApparentHeight(transition)
                }
            }*/
            
            let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let strongSelf = self else {
                    return []
                }
                if strongSelf.currentTabIndex == 0 {
                    return .left
                }
                return [.left, .right]
            })
            panRecognizer.delegate = self
            self.view.addGestureRecognizer(panRecognizer)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
                return false
            }
            if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                break
            case .changed:
                let translation = recognizer.translation(in: self.view)
                if !self.bounds.isEmpty {
                    let progress = translation.x / self.bounds.width
                    var toIndex: Int
                    if progress < 0.0 {
                        toIndex = self.currentTabIndex + 1
                    } else {
                        toIndex = self.currentTabIndex - 1
                    }
                    toIndex = max(0, min(toIndex, self.reactions.count - 1))
                    self.interactiveTransitionState = InteractiveTransitionState(toIndex: toIndex, progress: abs(progress))
                    self.requestUpdate(.immediate)
                }
            case .cancelled, .ended:
                if let interactiveTransitionState = self.interactiveTransitionState {
                    self.interactiveTransitionState = nil
                    if interactiveTransitionState.progress >= 0.2 {
                        self.currentTabIndex = interactiveTransitionState.toIndex
                        self.tabListNode?.scrollToTabReaction = ReactionTabListNode.ScrollToTabReaction(value: self.reactions[self.currentTabIndex].0)
                    }
                    self.requestUpdate(.animated(duration: 0.45, curve: .spring))
                }
            default:
                break
            }
        }
        
        func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat) {
            let constrainedSize = CGSize(width: min(260.0, constrainedWidth), height: maxHeight)
            
            var topContentHeight: CGFloat = 0.0
            if let backButtonNode = self.backButtonNode {
                let backButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: 44.0))
                backButtonNode.update(size: backButtonFrame.size, presentationData: self.presentationData, isLast: self.tabListNode == nil)
                transition.updateFrame(node: backButtonNode, frame: backButtonFrame)
                topContentHeight += backButtonFrame.height
            }
            if let tabListNode = self.tabListNode {
                let tabListFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: 44.0))
                let selectedReaction: MessageReaction.Reaction? = self.reactions[self.currentTabIndex].0
                tabListNode.update(size: tabListFrame.size, presentationData: self.presentationData, selectedReaction: selectedReaction, transition: transition)
                transition.updateFrame(node: tabListNode, frame: tabListFrame)
                topContentHeight += tabListFrame.height
            }
            if let separatorNode = self.separatorNode {
                let separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: 7.0))
                separatorNode.backgroundColor = self.presentationData.theme.contextMenu.sectionSeparatorColor
                transition.updateFrame(node: separatorNode, frame: separatorFrame)
                topContentHeight += separatorFrame.height
            }
            
            var tabLayouts: [Int: (height: CGFloat, apparentHeight: CGFloat)] = [:]
            
            var visibleIndices: [Int] = []
            visibleIndices.append(self.currentTabIndex)
            if let interactiveTransitionState = self.interactiveTransitionState {
                visibleIndices.append(interactiveTransitionState.toIndex)
            }
            
            let previousVisibleTabFrames: [(Int, CGRect)] = self.visibleTabNodes.map { key, value -> (Int, CGRect) in
                return (key, value.frame)
            }
            
            for index in visibleIndices {
                var tabTransition = transition
                let tabNode: ReactionsTabNode
                var initialReferenceFrame: CGRect?
                if let current = self.visibleTabNodes[index] {
                    tabNode = current
                } else {
                    for (previousIndex, previousFrame) in previousVisibleTabFrames {
                        if index > previousIndex {
                            initialReferenceFrame = previousFrame.offsetBy(dx: constrainedSize.width, dy: 0.0)
                        } else {
                            initialReferenceFrame = previousFrame.offsetBy(dx: -constrainedSize.width, dy: 0.0)
                        }
                        break
                    }
                    
                    tabNode = ReactionsTabNode(
                        context: self.context,
                        availableReactions: self.availableReactions,
                        animationCache: self.animationCache,
                        animationRenderer: self.animationRenderer,
                        message: self.message,
                        reaction: self.reactions[index].0,
                        readStats: self.reactions[index].0 == nil ? self.readStats : nil,
                        requestUpdate: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                var transition = transition
                                if strongSelf.interactiveTransitionState != nil {
                                    transition = .immediate
                                }
                                strongSelf.requestUpdate(transition)
                            }
                        },
                        requestUpdateApparentHeight: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                var transition = transition
                                if strongSelf.interactiveTransitionState != nil {
                                    transition = .immediate
                                }
                                strongSelf.requestUpdateApparentHeight(transition)
                            }
                        },
                        openPeer: self.openPeer
                    )
                    self.addSubnode(tabNode)
                    self.visibleTabNodes[index] = tabNode
                    tabTransition = .immediate
                }
                
                let tabLayout = tabNode.update(presentationData: presentationData, constrainedSize: CGSize(width: constrainedSize.width, height: constrainedSize.height - topContentHeight), bottomInset: bottomInset, transition: tabTransition)
                tabLayouts[index] = tabLayout
                let currentFractionalTabIndex: CGFloat
                if let interactiveTransitionState = self.interactiveTransitionState {
                    currentFractionalTabIndex = CGFloat(self.currentTabIndex) * (1.0 - interactiveTransitionState.progress) + CGFloat(interactiveTransitionState.toIndex) * interactiveTransitionState.progress
                } else {
                    currentFractionalTabIndex = CGFloat(self.currentTabIndex)
                }
                let xOffset: CGFloat = (CGFloat(index) - currentFractionalTabIndex) * constrainedSize.width
                let tabFrame = CGRect(origin: CGPoint(x: xOffset, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: tabLayout.height + 100.0))
                tabTransition.updateFrame(node: tabNode, frame: tabFrame)
                if let initialReferenceFrame = initialReferenceFrame {
                    transition.animatePositionAdditive(node: tabNode, offset: CGPoint(x: initialReferenceFrame.minX - tabFrame.minX, y: 0.0))
                }
            }
            
            var removedIndices: [Int] = []
            for (index, tabNode) in self.visibleTabNodes {
                if tabLayouts[index] == nil {
                    removedIndices.append(index)
                    
                    var xOffset: CGFloat
                    if index > self.currentTabIndex {
                        xOffset = constrainedSize.width
                    } else {
                        xOffset = -constrainedSize.width
                    }
                    transition.updateFrame(node: tabNode, frame: CGRect(origin: CGPoint(x: xOffset, y: tabNode.frame.minY), size: tabNode.bounds.size), completion: { [weak tabNode] _ in
                        tabNode?.removeFromSupernode()
                    })
                }
            }
            for index in removedIndices {
                self.visibleTabNodes.removeValue(forKey: index)
            }
            
            /*var currentTabTransition = transition
            if self.currentTabNode.bounds.isEmpty {
                currentTabTransition = .immediate
            }
            let currentTabLayout = self.currentTabNode.update(presentationData: presentationData, constrainedSize: CGSize(width: constrainedSize.width, height: constrainedSize.height - topContentHeight), transition: currentTabTransition)
            currentTabTransition.updateFrame(node: self.currentTabNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: currentTabLayout.size.width, height: currentTabLayout.size.height + 100.0)))
            
            if let dismissedTabNode = self.dismissedTabNode {
                self.dismissedTabNode = nil
                if let previousIndex = self.reactions.firstIndex(where: { $0.0 == dismissedTabNode.reaction }), let currentIndex = self.reactions.firstIndex(where: { $0.0 == self.currentTabNode.reaction }) {
                    let offset = previousIndex < currentIndex ? currentTabLayout.size.width : -currentTabLayout.size.width
                    transition.updateFrame(node: dismissedTabNode, frame: dismissedTabNode.frame.offsetBy(dx: -offset, dy: 0.0), completion: { [weak dismissedTabNode] _ in
                        dismissedTabNode?.removeFromSupernode()
                    })
                    transition.animatePositionAdditive(node: self.currentTabNode, offset: CGPoint(x: offset, y: 0.0))
                } else {
                    dismissedTabNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak dismissedTabNode] _ in
                        dismissedTabNode?.removeFromSupernode()
                    })
                    self.currentTabNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }*/
            
            var contentSize = CGSize(width: constrainedSize.width, height: topContentHeight)
            var apparentHeight = topContentHeight
            
            if let interactiveTransitionState = self.interactiveTransitionState, let fromTabLayout = tabLayouts[self.currentTabIndex], let toTabLayout = tabLayouts[interactiveTransitionState.toIndex] {
                let megedTabLayoutHeight = fromTabLayout.height * (1.0 - interactiveTransitionState.progress) + toTabLayout.height * interactiveTransitionState.progress
                let megedTabLayoutApparentHeight = fromTabLayout.apparentHeight * (1.0 - interactiveTransitionState.progress) + toTabLayout.apparentHeight * interactiveTransitionState.progress
                
                contentSize.height += megedTabLayoutHeight
                apparentHeight += megedTabLayoutApparentHeight
            } else if let tabLayout = tabLayouts[self.currentTabIndex] {
                contentSize.height += tabLayout.height
                apparentHeight += tabLayout.apparentHeight
            }
            
            return (contentSize, apparentHeight)
        }
    }
    
    let context: AccountContext
    let availableReactions: AvailableReactions?
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let message: EngineMessage
    let reaction: MessageReaction.Reaction?
    let readStats: MessageReadStats?
    let back: (() -> Void)?
    let openPeer: (EnginePeer) -> Void
    
    public init(
        context: AccountContext,
        availableReactions: AvailableReactions?,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        message: EngineMessage,
        reaction: MessageReaction.Reaction?,
        readStats: MessageReadStats?,
        back: (() -> Void)?,
        openPeer: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.availableReactions = availableReactions
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.message = message
        self.reaction = reaction
        self.readStats = readStats
        self.back = back
        self.openPeer = openPeer
    }
    
    public func node(
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerItemsNode {
        return ItemsNode(
            context: self.context,
            availableReactions: self.availableReactions,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            message: self.message,
            reaction: self.reaction,
            readStats: self.readStats,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight,
            back: self.back,
            openPeer: self.openPeer
        )
    }
}
