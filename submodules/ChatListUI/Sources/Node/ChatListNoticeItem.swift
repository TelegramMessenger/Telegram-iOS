import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ListSectionHeaderNode
import AppBundle
import ItemListUI
import Markdown
import AccountContext
import MergedAvatarsNode
import TextNodeWithEntities
import TextFormat

class ChatListNoticeItem: ListViewItem {
    enum Action {
        case activate
        case hide
        case buttonChoice(isPositive: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let notice: ChatListNotice
    let action: (Action) -> Void
    
    let selectable: Bool = true
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, notice: ChatListNotice, action: @escaping (Action) -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.notice = notice
        self.action = action
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        self.action(.activate)
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListNoticeItemNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, false)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply()
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListNoticeItemNode)
            if let nodeValue = node() as? ChatListNoticeItemNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

private let titleFont = Font.semibold(15.0)
private let textFont = Font.regular(15.0)
private let smallTextFont = Font.regular(14.0)

final class ChatListNoticeItemNode: ItemListRevealOptionsItemNode {
    private let contentContainer: ASDisplayNode
    private let titleNode: TextNodeWithEntities
    private let textNode: TextNode
    private let arrowNode: ASImageNode
    private let separatorNode: ASDisplayNode
    
    private var avatarsNode: MergedAvatarsNode?
    
    private var closeButton: HighlightableButtonNode?
    
    private var okButtonText: TextNode?
    private var cancelButtonText: TextNode?
    private var okButton: HighlightableButtonNode?
    private var cancelButton: HighlightableButtonNode?
    
    private var item: ChatListNoticeItem?
    
    override var apparentHeight: CGFloat {
        didSet {
            self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.width, height: self.apparentHeight))
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.contentContainer.bounds.height - UIScreenPixel), size: CGSize(width: self.contentContainer.bounds.width, height: UIScreenPixel))
        }
    }
    
    required init() {
        self.contentContainer = ASDisplayNode()
        
        self.titleNode = TextNodeWithEntities()
        self.textNode = TextNode()
        self.arrowNode = ASImageNode()
        self.separatorNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.contentContainer.clipsToBounds = true
        self.clipsToBounds = true
        
        self.contentContainer.addSubnode(self.titleNode.textNode)
        self.contentContainer.addSubnode(self.textNode)
        self.contentContainer.addSubnode(self.arrowNode)
        
        self.addSubnode(self.contentContainer)
        self.addSubnode(self.separatorNode)
        
        self.zPosition = 1.0
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    @objc private func closePressed() {
        guard let item = self.item else {
            return
        }
        item.action(.hide)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListNoticeItem, params, nextItem == nil)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListNoticeItem, _ params: ListViewItemLayoutParams, _ isLast: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let previousItem = self.item
        
        let makeTitleLayout = TextNodeWithEntities.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let makeOkButtonTextLayout = TextNode.asyncLayout(self.okButtonText)
        let makeCancelButtonTextLayout = TextNode.asyncLayout(self.cancelButtonText)
        
        return { item, params, last in
            let baseWidth = params.width - params.leftInset - params.rightInset
            let _ = baseWidth
            
            let sideInset: CGFloat = params.leftInset + 16.0
            let rightInset: CGFloat = sideInset + 24.0
            let verticalInset: CGFloat = 9.0
            var spacing: CGFloat = 0.0
            
            let themeUpdated = item.theme !== previousItem?.theme
            
            let titleString: NSAttributedString
            let textString: NSAttributedString
            var avatarPeers: [EnginePeer] = []
            
            var okButtonLayout: (TextNodeLayout, () -> TextNode)?
            var cancelButtonLayout: (TextNodeLayout, () -> TextNode)?
            var alignment: NSTextAlignment = .left
            
            switch item.notice {
            case let .clearStorage(sizeFraction):
                let sizeString = dataSizeString(Int64(sizeFraction), formatting: DataSizeStringFormatting(strings: item.strings, decimalSeparator: "."))
                let rawTitleString = item.strings.ChatList_StorageHintTitle(sizeString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_StorageHintText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case .setupPassword:
                titleString = NSAttributedString(string: item.strings.Settings_SuggestSetupPasswordTitle, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor)
                textString = NSAttributedString(string: item.strings.Settings_SuggestSetupPasswordText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumUpgrade(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumAnnualUpgradeTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumAnnualUpgradeText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumAnnualDiscount(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumAnnualDiscountTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumAnnualDiscountText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumRestore(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumRestoreDiscountTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumRestoreDiscountText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case .xmasPremiumGift:
                titleString = parseMarkdownIntoAttributedString(item.strings.ChatList_PremiumXmasGiftTitle, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.accentTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), linkAttribute: { _ in return nil }))
                textString = NSAttributedString(string: item.strings.ChatList_PremiumXmasGiftText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case .premiumGrace:
                titleString = parseMarkdownIntoAttributedString(item.strings.ChatList_PremiumGraceTitle, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.accentTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), linkAttribute: { _ in return nil }))
                textString = NSAttributedString(string: item.strings.ChatList_PremiumGraceText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case .setupBirthday:
                titleString = NSAttributedString(string: item.strings.ChatList_AddBirthdayTitle, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor)
                textString = NSAttributedString(string: item.strings.ChatList_AddBirthdayText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .birthdayPremiumGift(peers, _):
                let title: String
                let text: String
                if peers.count == 1, let peer = peers.first {
                    var peerName = peer.compactDisplayTitle
                    if peerName.count > 20 {
                        peerName = peerName.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
                    }
                    title = item.strings.ChatList_BirthdaySingleTitle(peerName).string
                    text = item.strings.ChatList_BirthdaySingleText
                } else {
                    title = item.strings.ChatList_BirthdayMultipleTitle(Int32(peers.count))
                    text = item.strings.ChatList_BirthdayMultipleText
                }
                titleString = parseMarkdownIntoAttributedString(title, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.accentTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor), linkAttribute: { _ in return nil }))
                textString = NSAttributedString(string: text, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
                avatarPeers = Array(peers.prefix(3))
            case let .reviewLogin(newSessionReview, totalCount):
                spacing = 2.0
                alignment = .center
                
                var rawTitleString = item.strings.ChatList_SessionReview_PanelTitle
                if totalCount > 1 {
                    rawTitleString = "1/\(totalCount) \(rawTitleString)"
                }
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_SessionReview_PanelText(newSessionReview.device, newSessionReview.location).string, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
                
                okButtonLayout = makeOkButtonTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.ChatList_SessionReview_PanelConfirm, font: titleFont, textColor: item.theme.list.itemAccentColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
                cancelButtonLayout = makeCancelButtonTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.ChatList_SessionReview_PanelReject, font: titleFont, textColor: item.theme.list.itemDestructiveColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
            case let .starsSubscriptionLowBalance(amount, peers):
                let title: String
                let text: String
                let starsValue = item.strings.ChatList_SubscriptionsLowBalance_Stars(Int32(amount))
                if let peer = peers.first, peers.count == 1 {
                    title = item.strings.ChatList_SubscriptionsLowBalance_Single_Title(starsValue, peer.compactDisplayTitle).string
                    text = item.strings.ChatList_SubscriptionsLowBalance_Single_Text
                } else {
                    title = item.strings.ChatList_SubscriptionsLowBalance_Multiple_Title(starsValue).string
                    text = item.strings.ChatList_SubscriptionsLowBalance_Multiple_Text
                }
                let attributedTitle = NSMutableAttributedString(string: "⭐️\(title)", font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor)
                if let range = attributedTitle.string.range(of: "⭐️") {
                    attributedTitle.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedTitle.string))
                    attributedTitle.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: attributedTitle.string))
                }
                titleString = attributedTitle
                textString = NSAttributedString(string: text, font: smallTextFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            }
            
            var leftInset: CGFloat = sideInset
            if !avatarPeers.isEmpty {
                let avatarsWidth = 30.0 + CGFloat(avatarPeers.count - 1) * 16.0
                leftInset += avatarsWidth + 4.0
            }
            
            let titleLayout = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: alignment, lineSpacing: 0.18))
            
            let textLayout = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, maximumNumberOfLines: 10, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: alignment, lineSpacing: 0.18))
            
            var contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.0.size.height + textLayout.0.size.height)
            if let okButtonLayout {
                contentSize.height += okButtonLayout.0.size.height + 20.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if themeUpdated {
                        strongSelf.contentContainer.backgroundColor = item.theme.chatList.pinnedItemBackgroundColor
                        strongSelf.separatorNode.backgroundColor = item.theme.chatList.itemSeparatorColor
                        strongSelf.arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                    }
                    
                    let _ = titleLayout.1(TextNodeWithEntities.Arguments(context: item.context, cache: item.context.animationCache, renderer: item.context.animationRenderer, placeholderColor: .white, attemptSynchronous: true))
                    if case .center = alignment {
                        strongSelf.titleNode.textNode.frame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.0.size.width) * 0.5), y: verticalInset), size: titleLayout.0.size)
                    } else {
                        strongSelf.titleNode.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.0.size)
                    }
                    
                    let _ = textLayout.1()
                    
                    if case .center = alignment {
                        strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((params.width - textLayout.0.size.width) * 0.5), y: strongSelf.titleNode.textNode.frame.maxY + spacing), size: textLayout.0.size)
                    } else {
                        strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.textNode.frame.maxY + spacing), size: textLayout.0.size)
                    }
                    
                    if !avatarPeers.isEmpty {
                        let avatarsNode: MergedAvatarsNode
                        if let current = strongSelf.avatarsNode {
                            avatarsNode = current
                        } else {
                            avatarsNode = MergedAvatarsNode()
                            avatarsNode.isUserInteractionEnabled = false
                            strongSelf.addSubnode(avatarsNode)
                            strongSelf.avatarsNode = avatarsNode
                        }
                        let avatarSize = CGSize(width: 30.0, height: 30.0)
                        avatarsNode.update(context: item.context, peers: avatarPeers.map { $0._asPeer() }, synchronousLoad: false, imageSize: avatarSize.width, imageSpacing: 16.0, borderWidth: 2.0 - UIScreenPixel, avatarFontSize: 10.0)
                        let avatarsSize = CGSize(width: avatarSize.width + 16.0 * CGFloat(avatarPeers.count - 1), height: avatarSize.height)
                        avatarsNode.updateLayout(size: avatarsSize)
                        avatarsNode.frame = CGRect(origin: CGPoint(x: sideInset - 6.0, y: floor((layout.size.height - avatarsSize.height) / 2.0)), size: avatarsSize)
                    } else if let avatarsNode = strongSelf.avatarsNode {
                        avatarsNode.removeFromSupernode()
                        strongSelf.avatarsNode = nil
                    }
                    
                    if let image = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - image.size.width + 8.0, y: floor((layout.size.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    var hasCloseButton = false
                    if case .xmasPremiumGift = item.notice {
                        hasCloseButton = true
                    } else if case .setupBirthday = item.notice {
                        hasCloseButton = true
                    } else if case .birthdayPremiumGift = item.notice {
                        hasCloseButton = true
                    } else if case .premiumGrace = item.notice {
                        hasCloseButton = true
                    } else if case .starsSubscriptionLowBalance = item.notice {
                        hasCloseButton = true
                    }
                                        
                    if let okButtonLayout, let cancelButtonLayout {
                        strongSelf.arrowNode.isHidden = true
                        strongSelf.closeButton?.isHidden = true
                        
                        let okButton: HighlightableButtonNode
                        if let current = strongSelf.okButton {
                            okButton = current
                        } else {
                            okButton = HighlightableButtonNode()
                            strongSelf.okButton = okButton
                            strongSelf.contentContainer.addSubnode(okButton)
                            okButton.addTarget(strongSelf, action: #selector(strongSelf.okButtonPressed), forControlEvents: .touchUpInside)
                        }
                        
                        let cancelButton: HighlightableButtonNode
                        if let current = strongSelf.cancelButton {
                            cancelButton = current
                        } else {
                            cancelButton = HighlightableButtonNode()
                            strongSelf.cancelButton = cancelButton
                            strongSelf.contentContainer.addSubnode(cancelButton)
                            cancelButton.addTarget(strongSelf, action: #selector(strongSelf.cancelButtonPressed), forControlEvents: .touchUpInside)
                        }
                        
                        let okButtonText = okButtonLayout.1()
                        if okButtonText !== strongSelf.okButtonText {
                            strongSelf.okButtonText?.removeFromSupernode()
                            strongSelf.okButtonText = okButtonText
                            okButton.addSubnode(okButtonText)
                        }
                        
                        let cancelButtonText = cancelButtonLayout.1()
                        if cancelButtonText !== strongSelf.okButtonText {
                            strongSelf.cancelButtonText?.removeFromSupernode()
                            strongSelf.cancelButtonText = cancelButtonText
                            cancelButton.addSubnode(cancelButtonText)
                        }
                        
                        let buttonsWidth: CGFloat = max(min(300.0, params.width), okButtonLayout.0.size.width + cancelButtonLayout.0.size.width + 32.0)
                        let buttonWidth: CGFloat = floor(buttonsWidth * 0.5)
                        let buttonHeight: CGFloat = 32.0
                        
                        let okButtonFrame = CGRect(origin: CGPoint(x: floor((params.width - buttonsWidth) * 0.5), y: strongSelf.textNode.frame.maxY + 6.0), size: CGSize(width: buttonWidth, height: buttonHeight))
                        let cancelButtonFrame = CGRect(origin: CGPoint(x: okButtonFrame.maxX, y: strongSelf.textNode.frame.maxY + 6.0), size: CGSize(width: buttonWidth, height: buttonHeight))
                        
                        okButton.frame = okButtonFrame
                        cancelButton.frame = cancelButtonFrame
                        
                        okButtonText.frame = CGRect(origin: CGPoint(x: floor((okButtonFrame.width - okButtonLayout.0.size.width) * 0.5), y: floor((okButtonFrame.height - okButtonLayout.0.size.height) * 0.5)), size: okButtonLayout.0.size)
                        cancelButtonText.frame = CGRect(origin: CGPoint(x: floor((cancelButtonFrame.width - cancelButtonLayout.0.size.width) * 0.5), y: floor((cancelButtonFrame.height - cancelButtonLayout.0.size.height) * 0.5)), size: cancelButtonLayout.0.size)
                    } else {
                        strongSelf.arrowNode.isHidden = hasCloseButton
                        
                        if let okButton = strongSelf.okButton {
                            strongSelf.okButton = nil
                            okButton.removeFromSupernode()
                        }
                        if let cancelButton = strongSelf.cancelButton {
                            strongSelf.cancelButton = nil
                            cancelButton.removeFromSupernode()
                        }
                        if let okButtonText = strongSelf.okButtonText {
                            strongSelf.okButtonText = nil
                            okButtonText.removeFromSupernode()
                        }
                        if let cancelButtonText = strongSelf.cancelButtonText {
                            strongSelf.cancelButtonText = nil
                            cancelButtonText.removeFromSupernode()
                        }
                        
                        if hasCloseButton {
                            let closeButton: HighlightableButtonNode
                            if let current = strongSelf.closeButton {
                                closeButton = current
                            } else {
                                closeButton = HighlightableButtonNode()
                                closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
                                closeButton.addTarget(self, action: #selector(strongSelf.closePressed), forControlEvents: [.touchUpInside])
                                strongSelf.contentContainer.addSubnode(closeButton)
                                strongSelf.closeButton = closeButton
                            }
                            
                            if themeUpdated || closeButton.image(for: .normal) == nil {
                                closeButton.setImage(PresentationResourcesItemList.itemListCloseIconImage(item.theme), for: .normal)
                            }
                            
                            let closeButtonSize = closeButton.measure(CGSize(width: 100.0, height: 100.0))
                            closeButton.frame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - closeButtonSize.width, y: floor((layout.size.height - closeButtonSize.height) / 2.0)), size: closeButtonSize)
                        } else {
                            strongSelf.closeButton?.removeFromSupernode()
                            strongSelf.closeButton = nil
                        }
                    }
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    //strongSelf.contentContainer.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    
                    switch item.notice {
                    default:
                        strongSelf.setRevealOptions((left: [], right: []))
                    }
                }
            })
        }
    }
    
    @objc private func okButtonPressed() {
        self.item?.action(.buttonChoice(isPositive: true))
    }
    
    @objc private func cancelButtonPressed() {
        self.item?.action(.buttonChoice(isPositive: false))
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        //self.transitionOffset = self.bounds.size.height
        //self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        transition.updateSublayerTransformOffset(layer: self.contentContainer.layer, offset: CGPoint(x: offset, y: 0.0))
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            item.action(.hide)
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
