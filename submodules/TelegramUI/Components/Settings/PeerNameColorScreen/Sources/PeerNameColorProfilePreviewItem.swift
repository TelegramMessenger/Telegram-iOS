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

final class PeerNameColorProfilePreviewItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let componentTheme: PresentationTheme
    let strings: PresentationStrings
    let sectionId: ItemListSectionId
    let peer: EnginePeer?
    let files: [Int64: TelegramMediaFile]
    let nameDisplayOrder: PresentationPersonNameOrder
    
    init(context: AccountContext, theme: PresentationTheme, componentTheme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, peer: EnginePeer?, files: [Int64: TelegramMediaFile], nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.theme = theme
        self.componentTheme = componentTheme
        self.strings = strings
        self.sectionId = sectionId
        self.peer = peer
        self.files = files
        self.nameDisplayOrder = nameDisplayOrder
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerNameColorProfilePreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
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
                            apply()
                        })
                    }
                }
            }
        }
    }
}

final class PeerNameColorProfilePreviewItemNode: ListViewItemNode {
    private let background = ComponentView<Empty>()
    private let avatarNode: AvatarNode
    private let title = ComponentView<Empty>()
    private let subtitle = ComponentView<Empty>()
    private var icon: ComponentView<Empty>?
    
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var item: PeerNameColorProfilePreviewItem?
    
    init() {
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
    
    deinit {
    }
    
    func asyncLayout() -> (_ item: PeerNameColorProfilePreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: 210.0)
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            if params.width <= 320.0 {
                insets.top = 0.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                if let previousItem = self.item, (previousItem.peer?.profileColor != item.peer?.profileColor) || (previousItem.peer?.profileBackgroundEmojiId != item.peer?.profileBackgroundEmojiId) {
                    UIView.transition(with: self.view, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                    })
                }
                self.item = item
                    
                self.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                self.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                if self.topStripeNode.supernode == nil {
                    self.addSubnode(self.topStripeNode)
                }
                if self.bottomStripeNode.supernode == nil {
                    self.addSubnode(self.bottomStripeNode)
                }
                if self.maskNode.supernode == nil {
                    self.addSubnode(self.maskNode)
                }
                    
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
                
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                
                let coverFrame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                
                let avatarSize: CGFloat = 104.0
                let avatarFrame = CGRect(origin: CGPoint(x: floor((coverFrame.width - avatarSize) * 0.5), y: coverFrame.minY + 24.0), size: CGSize(width: avatarSize, height: avatarSize))
                
                let _ = self.background.update(
                    transition: .immediate,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: item.context,
                        peer: item.peer,
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
                        self.view.insertSubview(backgroundView, at: 0)
                    }
                    backgroundView.frame = coverFrame
                }
                
                let clipStyle: AvatarNodeClipStyle
                switch item.peer {
                case let .channel(channel) where channel.isForum:
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
                self.avatarNode.frame = avatarFrame.offsetBy(dx: coverFrame.minX, dy: coverFrame.minY)
                
                let backgroundColor: UIColor
                let titleColor: UIColor
                let subtitleColor: UIColor
                if let peer = item.peer, let profileColor = peer.profileColor {
                    titleColor = .white
                    backgroundColor = item.context.peerNameColors.getProfile(profileColor).main
                    subtitleColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColor.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
                } else {
                    titleColor = item.theme.list.itemPrimaryTextColor
                    subtitleColor = item.theme.list.itemSecondaryTextColor
                    backgroundColor = .clear
                }
                
                let titleString: String = item.peer?.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder) ?? " "
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(Text(
                        text: titleString, font: Font.semibold(28.0), color: titleColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: coverFrame.width - 16.0, height: 100.0)
                )
                let titleFrame = CGRect(origin: CGPoint(x: coverFrame.minX + floor((coverFrame.width - titleSize.width) * 0.5), y: avatarFrame.maxY + 10.0), size: titleSize)
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        self.view.addSubview(titleView)
                    }
                    titleView.frame = titleFrame
                }
                
                let subtitleString: String = item.strings.LastSeen_JustNow
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
                self.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
