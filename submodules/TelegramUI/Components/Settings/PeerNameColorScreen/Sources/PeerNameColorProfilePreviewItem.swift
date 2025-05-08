import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ComponentFlow
import PeerInfoCoverComponent
import AvatarNode
import EmojiStatusComponent
import ListItemComponentAdaptor
import ComponentDisplayAdapters
import MultilineTextComponent

final class PeerNameColorProfilePreviewItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    let context: AccountContext
    let theme: PresentationTheme
    let componentTheme: PresentationTheme
    let strings: PresentationStrings
    let topInset: CGFloat
    let sectionId: ItemListSectionId
    let peer: EnginePeer?
    let subtitleString: String?
    let files: [Int64: TelegramMediaFile]
    let nameDisplayOrder: PresentationPersonNameOrder
    let showBackground: Bool
    
    init(context: AccountContext, theme: PresentationTheme, componentTheme: PresentationTheme, strings: PresentationStrings, topInset: CGFloat, sectionId: ItemListSectionId, peer: EnginePeer?, subtitleString: String? = nil, files: [Int64: TelegramMediaFile], nameDisplayOrder: PresentationPersonNameOrder, showBackground: Bool) {
        self.context = context
        self.theme = theme
        self.componentTheme = componentTheme
        self.strings = strings
        self.topInset = topInset
        self.sectionId = sectionId
        self.peer = peer
        self.subtitleString = subtitleString
        self.files = files
        self.nameDisplayOrder = nameDisplayOrder
        self.showBackground = showBackground
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerNameColorProfilePreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? PeerNameColorProfilePreviewItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
    
    func item() -> ListViewItem {
        return self
    }
    
    static func ==(lhs: PeerNameColorProfilePreviewItem, rhs: PeerNameColorProfilePreviewItem) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.componentTheme !== rhs.componentTheme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.showBackground != rhs.showBackground {
            return false
        }
        return true
    }
}

final class PeerNameColorProfilePreviewItemNode: ListViewItemNode {
    private let background = ComponentView<Empty>()
    private let avatarNode: AvatarNode
    private let title = ComponentView<Empty>()
    private let subtitle = ComponentView<Empty>()
    private var icon: ComponentView<Empty>?
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var item: PeerNameColorProfilePreviewItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
        self.avatarNode = AvatarNode(font: avatarFont)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
    }
        
    func asyncLayout() -> (_ item: PeerNameColorProfilePreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { [weak self] item, params, neighbors in
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: 210.0 + item.topInset)
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            if params.width <= 320.0 {
                insets.top = 0.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animation in
                guard let self else {
                    return
                }
                if let previousItem = self.item, (previousItem.peer?.nameColor != item.peer?.nameColor) || (previousItem.peer?.profileColor != item.peer?.profileColor) || (previousItem.peer?.profileBackgroundEmojiId != item.peer?.profileBackgroundEmojiId) {
                    UIView.transition(with: self.view, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                    })
                }
                self.item = item
                    
                self.backgroundNode.backgroundColor = item.theme.rootController.navigationBar.opaqueBackgroundColor
                self.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                self.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                if self.backgroundNode.supernode == nil {
                    self.addSubnode(self.backgroundNode)
                }
                if self.topStripeNode.supernode == nil {
                    self.addSubnode(self.topStripeNode)
                }
                if self.bottomStripeNode.supernode == nil {
                    self.addSubnode(self.bottomStripeNode)
                }
                if self.maskNode.supernode == nil {
                    self.addSubnode(self.maskNode)
                }
                
                if params.isStandalone {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    transition.updateAlpha(node: self.backgroundNode, alpha: item.showBackground ? 1.0 : 0.0)
                    transition.updateAlpha(node: self.bottomStripeNode, alpha: item.showBackground ? 1.0 : 0.0)
                    
                    self.backgroundNode.isHidden = false
                    self.topStripeNode.isHidden = true
                    self.bottomStripeNode.isHidden = false
                    self.maskNode.isHidden = true
                    
                    self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height - separatorHeight), size: CGSize(width: layoutSize.width, height: separatorHeight))
                } else {
                    self.backgroundNode.isHidden = true
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                    case .sameSection(false):
                        self.topStripeNode.isHidden = true
                    default:
                        hasTopCorners = true
                        self.topStripeNode.isHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = 0.0
                        bottomStripeOffset = -separatorHeight
                        self.bottomStripeNode.isHidden = item.peer?.profileColor == nil
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                        hasBottomCorners = true
                        self.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.componentTheme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    self.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                }
                
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                
                let coverFrame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                
                let avatarSize: CGFloat = 104.0
                let avatarFrame = CGRect(origin: CGPoint(x: floor((coverFrame.width - avatarSize) * 0.5), y: coverFrame.minY + item.topInset + 24.0), size: CGSize(width: avatarSize, height: avatarSize))
                
                let subject: PeerInfoCoverComponent.Subject?
                if let status = item.peer?.emojiStatus, case .starGift = status.content {
                    subject = .status(status)
                } else if let peer = item.peer {
                    subject = .peer(peer)
                } else {
                    subject = nil
                }
                let _ = self.background.update(
                    transition: .immediate,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: item.context,
                        subject: subject,
                        files: item.files,
                        isDark: item.theme.overallDarkAppearance,
                        avatarCenter: avatarFrame.center,
                        avatarScale: 1.0,
                        defaultHeight: coverFrame.height,
                        avatarTransitionFraction: 0.0,
                        patternTransitionFraction: 0.0
                    )),
                    environment: {},
                    containerSize: coverFrame.size
                )
                if let backgroundView = self.background.view {
                    if backgroundView.superview == nil {
                        backgroundView.clipsToBounds = true
                        self.view.insertSubview(backgroundView, at: 1)
                    }
                    backgroundView.frame = coverFrame
                }
                
                let clipStyle: AvatarNodeClipStyle
                switch item.peer {
                case let .channel(channel) where channel.isForumOrMonoForum:
                    clipStyle = .roundedRect
                default:
                    clipStyle = .round
                }
                self.avatarNode.setPeer(
                    context: item.context,
                    theme: item.theme,
                    peer: item.peer,
                    clipStyle: clipStyle,
                    synchronousLoad: true,
                    displayDimensions: avatarFrame.size
                )
                if self.avatarNode.supernode == nil {
                    self.addSubnode(self.avatarNode)
                }
                self.avatarNode.frame = avatarFrame.offsetBy(dx: coverFrame.minX, dy: 0.0)
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
                
                enum CredibilityIcon {
                    case none
                    case premium
                    case verified
                    case fake
                    case scam
                    case emojiStatus(PeerEmojiStatus)
                }
                
                let credibilityIcon: CredibilityIcon
                if let peer = item.peer {
                    if peer.isFake {
                        credibilityIcon = .fake
                    } else if peer.isScam {
                        credibilityIcon = .scam
                    } else if case let .user(user) = peer, let emojiStatus = user.emojiStatus {
                        credibilityIcon = .emojiStatus(emojiStatus)
                    } else if case let .channel(channel) = peer, let emojiStatus = channel.emojiStatus {
                        credibilityIcon = .emojiStatus(emojiStatus)
                    } else if peer.isVerified {
                        credibilityIcon = .verified
                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled && (peer.id != item.context.account.peerId) {
                        credibilityIcon = .premium
                    } else {
                        credibilityIcon = .none
                    }
                } else {
                    credibilityIcon = .none
                }
                
                let statusColor: UIColor
                if let status = item.peer?.emojiStatus, case .starGift = status.content {
                    statusColor = .white
                } else if let peer = item.peer, peer.profileColor != nil {
                    statusColor = .white
                } else {
                    statusColor = item.theme.list.itemCheckColors.fillColor
                }
                
                let emojiStatusContent: EmojiStatusComponent.Content
                switch credibilityIcon {
                case .none:
                    emojiStatusContent = .none
                case .premium:
                    emojiStatusContent = .premium(color: statusColor)
                case .verified:
                    emojiStatusContent = .verified(fillColor: statusColor, foregroundColor: .clear, sizeType: .large)
                case .fake:
                    emojiStatusContent = .text(color: item.theme.chat.message.incoming.scamColor, string: item.strings.Message_FakeAccount.uppercased())
                case .scam:
                    emojiStatusContent = .text(color: item.theme.chat.message.incoming.scamColor, string: item.strings.Message_ScamAccount.uppercased())
                case let .emojiStatus(emojiStatus):
                    emojiStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: item.theme.list.mediaPlaceholderColor, themeColor: statusColor, loopMode: .forever)
                }
                
                let backgroundColor: UIColor
                let titleColor: UIColor
                let subtitleColor: UIColor
                var particleColor: UIColor?
                if let status = item.peer?.emojiStatus, case let .starGift(_, _, _, _, _, _, outerColor, _, _) = status.content {
                    titleColor = .white
                    backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColor))
                    subtitleColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColor.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
                    particleColor = .white
                } else if let peer = item.peer, let profileColor = peer.profileColor {
                    titleColor = .white
                    backgroundColor = item.context.peerNameColors.getProfile(profileColor).main
                    subtitleColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColor.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
                } else {
                    titleColor = item.theme.list.itemPrimaryTextColor
                    subtitleColor = item.theme.list.itemSecondaryTextColor
                    backgroundColor = .clear
                }
                
                var hasStatusIcon = false
                if case .none = emojiStatusContent {
                } else {
                    hasStatusIcon = true
                }
                
                var maxTitleWidth = coverFrame.width - 16.0
                if hasStatusIcon {
                    maxTitleWidth -= 4.0 + 34.0
                }
                
                let titleString: String = item.peer?.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder) ?? " "
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleString, font: Font.semibold(28.0), textColor: titleColor)),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: maxTitleWidth, height: 100.0)
                )
                
                var titleContentWidth = titleSize.width
                if case .none = emojiStatusContent {
                } else {
                    titleContentWidth += 4.0 + 34.0
                }
                
                let titleFrame = CGRect(origin: CGPoint(x: coverFrame.minX + floor((coverFrame.width - titleContentWidth) * 0.5), y: avatarFrame.maxY + 10.0), size: titleSize)
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        titleView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
                        self.view.addSubview(titleView)
                    }
                    titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                    animation.animator.updatePosition(layer: titleView.layer, position: titleFrame.origin, completion: nil)
                }
                
                let icon: ComponentView<Empty>
                if let current = self.icon {
                    icon = current
                } else {
                    icon = ComponentView()
                    self.icon = icon
                }
                let iconSize = CGSize(width: 34.0, height: 34.0)
                let _ = icon.update(
                    transition: ComponentTransition(animation.transition),
                    component: AnyComponent(EmojiStatusComponent(
                        context: item.context,
                        animationCache: item.context.animationCache,
                        animationRenderer: item.context.animationRenderer,
                        content: emojiStatusContent,
                        particleColor: particleColor,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: iconSize
                )
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        self.view.addSubview(iconView)
                    }
                    let iconFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - iconSize.height) * 0.5)), size: iconSize)
                    iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
                    animation.animator.updatePosition(layer: iconView.layer, position: iconFrame.center, completion: nil)
                }
                
                let subtitleString: String
                if let value = item.subtitleString {
                    subtitleString = value
                } else if case .channel = item.peer {
                    subtitleString = item.strings.Channel_Status
                } else {
                    subtitleString = item.strings.LastSeen_JustNow
                }
                let subtitleSize = self.subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(Text(
                        text: subtitleString, font: Font.regular(18.0), color: subtitleColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: coverFrame.width - 16.0, height: 100.0)
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: coverFrame.minX + floor((coverFrame.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + 3.0), size: subtitleSize)
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.view.addSubview(subtitleView)
                    }
                    subtitleView.frame = subtitleFrame
                }
                
                self.maskNode.frame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                self.backgroundNode.frame = backgroundFrame
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
