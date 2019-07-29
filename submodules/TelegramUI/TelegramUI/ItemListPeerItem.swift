import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

struct ItemListPeerItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
}

enum ItemListPeerItemHeight {
    case generic
    case peerList
}

enum ItemListPeerItemText {
    case presence
    case text(String)
    case none
}

enum ItemListPeerItemLabel {
    case none
    case text(String)
    case disclosure(String)
    case badge(String)
}

struct ItemListPeerItemSwitch {
    let value: Bool
    let style: ItemListPeerItemSwitchStyle
}

enum ItemListPeerItemSwitchStyle {
    case standard
    case check
}

enum ItemListPeerItemAliasHandling {
    case standard
    case threatSelfAsSaved
}

enum ItemListPeerItemNameColor {
    case primary
    case secret
}

enum ItemListPeerItemNameStyle {
    case distinctBold
    case plain
}

enum ItemListPeerItemRevealOptionType {
    case neutral
    case warning
    case destructive
}

struct ItemListPeerItemRevealOption {
    let type: ItemListPeerItemRevealOptionType
    let title: String
    let action: () -> Void
}

struct ItemListPeerItemRevealOptions {
    let options: [ItemListPeerItemRevealOption]
}

final class ItemListPeerItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let account: Account
    let peer: Peer
    let height: ItemListPeerItemHeight
    let aliasHandling: ItemListPeerItemAliasHandling
    let nameColor: ItemListPeerItemNameColor
    let nameStyle: ItemListPeerItemNameStyle
    let presence: PeerPresence?
    let text: ItemListPeerItemText
    let label: ItemListPeerItemLabel
    let editing: ItemListPeerItemEditing
    let revealOptions: ItemListPeerItemRevealOptions?
    let switchValue: ItemListPeerItemSwitch?
    let enabled: Bool
    let selectable: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    let toggleUpdated: ((Bool) -> Void)?
    let hasTopStripe: Bool
    let hasTopGroupInset: Bool
    let noInsets: Bool
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, account: Account, peer: Peer, height: ItemListPeerItemHeight = .peerList, aliasHandling: ItemListPeerItemAliasHandling = .standard, nameColor: ItemListPeerItemNameColor = .primary, nameStyle: ItemListPeerItemNameStyle = .distinctBold, presence: PeerPresence?, text: ItemListPeerItemText, label: ItemListPeerItemLabel, editing: ItemListPeerItemEditing, revealOptions: ItemListPeerItemRevealOptions? = nil, switchValue: ItemListPeerItemSwitch?, enabled: Bool, selectable: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void, toggleUpdated: ((Bool) -> Void)? = nil, hasTopStripe: Bool = true, hasTopGroupInset: Bool = true, noInsets: Bool = false, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.account = account
        self.peer = peer
        self.height = height
        self.aliasHandling = aliasHandling
        self.nameColor = nameColor
        self.nameStyle = nameStyle
        self.presence = presence
        self.text = text
        self.label = label
        self.editing = editing
        self.revealOptions = revealOptions
        self.switchValue = switchValue
        self.enabled = enabled
        self.selectable = selectable
        self.sectionId = sectionId
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.toggleUpdated = toggleUpdated
        self.hasTopStripe = hasTopStripe
        self.hasTopGroupInset = hasTopGroupInset
        self.noInsets = noInsets
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListPeerItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (node.avatarNode.ready, { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListPeerItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let titleFont = Font.regular(17.0)
private let titleBoldFont = Font.medium(17.0)
private let statusFont = Font.regular(14.0)
private let labelFont = Font.regular(13.0)
private let labelDisclosureFont = Font.regular(17.0)
private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 15.0)!
private let badgeFont = Font.regular(15.0)

class ItemListPeerItemNode: ItemListRevealOptionsItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let labelBadgeNode: ASImageNode
    private var labelArrowNode: ASImageNode?
    private let statusNode: TextNode
    private var switchNode: SwitchNode?
    private var checkNode: ASImageNode?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ItemListPeerItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil || self.disabledOverlayNode != nil {
            return false
        }
        if let item = self.layoutParams?.0, item.action != nil {
            return true
        } else {
            return false
        }
    }
    
    var tag: ItemListItemTag? {
        return self.layoutParams?.0.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.labelBadgeNode = ASImageNode()
        self.labelBadgeNode.displayWithoutProcessing = true
        self.labelBadgeNode.displaysAsynchronously = false
        self.labelBadgeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.labelNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2)
                apply(false, true)
            }
        })
    }
    
    func asyncLayout() -> (_ item: ItemListPeerItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        var currentSwitchNode = self.switchNode
        var currentCheckNode = self.checkNode
        
        let currentLabelArrowNode = self.labelArrowNode
        
        let currentItem = self.layoutParams?.0
        
        let currentHasBadge = self.labelBadgeNode.image != nil
        
        return { item, params, neighbors in
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            var updatedLabelBadgeImage: UIImage?
            
            var badgeColor: UIColor?
            if case .badge = item.label {
                badgeColor = item.theme.list.itemAccentColor
            }
            
            let badgeDiameter: CGFloat = 20.0
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                if let badgeColor = badgeColor {
                    updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
                }
            } else if let badgeColor = badgeColor, !currentHasBadge {
                updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var labelAttributedString: NSAttributedString?
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.enabled {
                if let revealOptions = item.revealOptions {
                    var mappedOptions: [ItemListRevealOption] = []
                    var index: Int32 = 0
                    for option in revealOptions.options {
                        let color: UIColor
                        let textColor: UIColor
                        switch option.type {
                            case .neutral:
                                color = item.theme.list.itemDisclosureActions.constructive.fillColor
                                textColor = item.theme.list.itemDisclosureActions.constructive.foregroundColor
                            case .warning:
                                color = item.theme.list.itemDisclosureActions.warning.fillColor
                                textColor = item.theme.list.itemDisclosureActions.warning.foregroundColor
                            case .destructive:
                                color = item.theme.list.itemDisclosureActions.destructive.fillColor
                                textColor = item.theme.list.itemDisclosureActions.destructive.foregroundColor
                        }
                        mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                        index += 1
                    }
                    peerRevealOptions = mappedOptions
                } else {
                    peerRevealOptions = [ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]
                }
            } else {
                peerRevealOptions = []
            }
            
            var rightInset: CGFloat = params.rightInset
            let switchSize = CGSize(width: 51.0, height: 31.0)
            var checkImage: UIImage?
            
            if let switchValue = item.switchValue {
                switch switchValue.style {
                    case .standard:
                        if currentSwitchNode == nil {
                            currentSwitchNode = SwitchNode()
                        }
                        rightInset += switchSize.width
                        currentCheckNode = nil
                    case .check:
                        checkImage = PresentationResourcesItemList.checkIconImage(item.theme)
                        if currentCheckNode == nil {
                            currentCheckNode = ASImageNode()
                        }
                        rightInset += 24.0
                        currentSwitchNode = nil
                }
            } else {
                currentSwitchNode = nil
                currentCheckNode = nil
            }
            
            let titleColor: UIColor
            switch item.nameColor {
                case .primary:
                    titleColor = item.theme.list.itemPrimaryTextColor
                case .secret:
                    titleColor = item.theme.chatList.secretTitleColor
            }
            
            let currentBoldFont: UIFont
            switch item.nameStyle {
                case .distinctBold:
                    currentBoldFont = titleBoldFont
                case .plain:
                    currentBoldFont = titleFont
            }
            
            if item.peer.id == item.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                titleAttributedString = NSAttributedString(string: item.strings.DialogList_SavedMessages, font: currentBoldFont, textColor: titleColor)
            } else if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    switch item.nameDisplayOrder {
                        case .firstLast:
                            string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                            string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                            string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                        case .lastFirst:
                            string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                            string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                            string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                    }
                    titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: currentBoldFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.strings.User_DeletedAccount, font: currentBoldFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: currentBoldFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: currentBoldFont, textColor: titleColor)
            }
            
            switch item.text {
                case .presence:
                    if let user = item.peer as? TelegramUser, let botInfo = user.botInfo {
                        let botStatus: String
                        if botInfo.flags.contains(.hasAccessToChatHistory) {
                            botStatus = item.strings.Bot_GroupStatusReadsHistory
                        } else {
                            botStatus = item.strings.Bot_GroupStatusDoesNotReadHistory
                        }
                        statusAttributedString = NSAttributedString(string: botStatus, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                    } else if let presence = item.presence as? TelegramUserPresence {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        let (string, activity) = stringAndActivityForUserPresence(strings: item.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor)
                    } else {
                        statusAttributedString = NSAttributedString(string: item.strings.LastSeen_Offline, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                    }
                case let .text(text):
                    statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                case .none:
                    break
            }

            let leftInset: CGFloat
            let height: CGFloat
            let verticalOffset: CGFloat
            let avatarSize: CGFloat
            switch item.height {
                case .generic:
                    height = 44.0
                    verticalOffset = -3.0
                    avatarSize = 31.0
                    leftInset = 59.0 + params.leftInset
                case .peerList:
                    height = 50.0
                    verticalOffset = 0.0
                    avatarSize = 40.0
                    leftInset = 65.0 + params.leftInset
            }
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(50.0, item.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            } else {
                editingOffset = 0.0
            }
            
            var labelInset: CGFloat = 0.0
            var updatedLabelArrowNode: ASImageNode?
            switch item.label {
                case .none:
                    break
                case let .text(text):
                    labelAttributedString = NSAttributedString(string: text, font: labelFont, textColor: item.theme.list.itemSecondaryTextColor)
                    labelInset += 15.0
                case let .disclosure(text):
                    if let currentLabelArrowNode = currentLabelArrowNode {
                        updatedLabelArrowNode = currentLabelArrowNode
                    } else {
                        let arrowNode = ASImageNode()
                        arrowNode.isLayerBacked = true
                        arrowNode.displayWithoutProcessing = true
                        arrowNode.displaysAsynchronously = false
                        arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                        updatedLabelArrowNode = arrowNode
                    }
                    labelInset += 40.0
                    labelAttributedString = NSAttributedString(string: text, font: labelDisclosureFont, textColor: item.theme.list.itemSecondaryTextColor)
                case let .badge(text):
                    labelAttributedString = NSAttributedString(string: text, font: badgeFont, textColor: item.theme.list.itemCheckColors.foregroundColor)
                    labelInset += 15.0
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: labelAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - labelLayout.size.width - editingOffset - rightInset - labelInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - labelInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var insets = itemListNeighborsGroupedInsets(neighbors)
            if !item.hasTopGroupInset {
                switch neighbors.top {
                    case .none:
                        insets.top = 0.0
                    default:
                        break
                }
            }
            if item.noInsets {
                insets.top = 0.0
                insets.bottom = 0.0
            }
            
            let contentSize = CGSize(width: params.width, height: height)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = item.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors)
                    
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    var combinedValueString = ""
                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
                        combinedValueString.append(statusString)
                    }
                    if let labelString = labelAttributedString?.string, !labelString.isEmpty {
                        combinedValueString.append(", \(labelString)")
                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.labelArrowNode?.image = updateArrowImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.avatarNode)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        } else {
                            strongSelf.editableControlNode?.frame = editableControlFrame
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editing.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = labelApply()
                    
                    strongSelf.labelNode.isHidden = labelAttributedString == nil
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = !item.hasTopStripe
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: (statusAttributedString == nil ? 14.0 : 6.0) + verticalOffset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 27.0 + verticalOffset), size: statusLayout.size))
                    
                    if let currentSwitchNode = currentSwitchNode {
                        if currentSwitchNode !== strongSelf.switchNode {
                            strongSelf.switchNode = currentSwitchNode
                            if let disabledOverlayNode = strongSelf.disabledOverlayNode, disabledOverlayNode.supernode != nil {
                                strongSelf.insertSubnode(currentSwitchNode, belowSubnode: disabledOverlayNode)
                            } else {
                                strongSelf.addSubnode(currentSwitchNode)
                            }
                            currentSwitchNode.valueUpdated = { value in
                                if let strongSelf = self {
                                    strongSelf.toggleUpdated(value)
                                }
                            }
                        }
                        currentSwitchNode.frame = CGRect(origin: CGPoint(x: revealOffset + params.width - switchSize.width - 15.0, y: floor((contentSize.height - switchSize.height) / 2.0)), size: switchSize)
                        if let switchValue = item.switchValue {
                            currentSwitchNode.setOn(switchValue.value, animated: animated)
                        }
                    } else if let switchNode = strongSelf.switchNode {
                        switchNode.removeFromSupernode()
                        strongSelf.switchNode = nil
                    }
                    
                    if let currentCheckNode = currentCheckNode {
                        if currentCheckNode !== strongSelf.checkNode {
                            strongSelf.checkNode = currentCheckNode
                            if let disabledOverlayNode = strongSelf.disabledOverlayNode, disabledOverlayNode.supernode != nil {
                                strongSelf.insertSubnode(currentCheckNode, belowSubnode: disabledOverlayNode)
                            } else {
                                strongSelf.addSubnode(currentCheckNode)
                            }
                        }
                        if let checkImage = checkImage {
                            currentCheckNode.image = checkImage
                            currentCheckNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - checkImage.size.width - floor((44.0 - checkImage.size.width) / 2.0), y: floor((layout.contentSize.height - checkImage.size.height) / 2.0)), size: checkImage.size)
                        }
                        if let switchValue = item.switchValue {
                            currentCheckNode.isHidden = !switchValue.value
                        }
                    } else if let checkNode = strongSelf.checkNode {
                        checkNode.removeFromSupernode()
                        strongSelf.checkNode = nil
                    }
                    
                    var rightLabelInset: CGFloat = 15.0
                    
                    if let updatedLabelArrowNode = updatedLabelArrowNode {
                        strongSelf.labelArrowNode = updatedLabelArrowNode
                        strongSelf.addSubnode(updatedLabelArrowNode)
                        if let image = updatedLabelArrowNode.image {
                            let labelArrowNodeFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightLabelInset - image.size.width, y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                            transition.updateFrame(node: updatedLabelArrowNode, frame: labelArrowNodeFrame)
                            rightLabelInset += 19.0
                        }
                    } else if let labelArrowNode = strongSelf.labelArrowNode {
                        labelArrowNode.removeFromSupernode()
                        strongSelf.labelArrowNode = nil
                    }
                    
                    let badgeWidth = max(badgeDiameter, labelLayout.size.width + 10.0)
                    let labelFrame: CGRect
                    if case .badge = item.label {
                        labelFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - badgeWidth + (badgeWidth - labelLayout.size.width) / 2.0, y: floor((contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                        strongSelf.labelNode.frame = labelFrame
                    } else {
                        labelFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - labelLayout.size.width - rightLabelInset - rightInset, y: floor((contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                        transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
                    }
                    
                    if let updateBadgeImage = updatedLabelBadgeImage {
                        if strongSelf.labelBadgeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.labelBadgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.labelBadgeNode.image = updateBadgeImage
                    }
                    if badgeColor == nil && strongSelf.labelBadgeNode.supernode != nil {
                        strongSelf.labelBadgeNode.image = nil
                        strongSelf.labelBadgeNode.removeFromSupernode()
                    }
                    
                    strongSelf.labelBadgeNode.frame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - badgeWidth, y: labelFrame.minY - 1.0), size: CGSize(width: badgeWidth, height: badgeDiameter))
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0, y: floorToScreenPixels((height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
                    
                    if item.peer.id == item.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                        strongSelf.avatarNode.setPeer(account: item.account, theme: item.theme, peer: item.peer, overrideImage: .savedMessagesIcon, emptyColor: item.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                    } else {
                        var overrideImage: AvatarNodeImageOverride?
                        if item.peer.isDeleted {
                            overrideImage = .deletedIcon
                        }
                        strongSelf.avatarNode.setPeer(account: item.account, theme: item.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel + UIScreenPixel))
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let item = self.layoutParams?.0, let params = self.layoutParams?.1 else {
            return
        }
        
        let leftInset: CGFloat
        switch item.height {
        case .generic:
            leftInset = 59.0 + params.leftInset
        case .peerList:
            leftInset = 65.0 + params.leftInset
        }
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
        
        var rightLabelInset: CGFloat = 15.0 + params.rightInset
        
        if let labelArrowNode = self.labelArrowNode {
            if let image = labelArrowNode.image {
                let labelArrowNodeFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - image.size.width, y: labelArrowNode.frame.minY), size: image.size)
                transition.updateFrame(node: labelArrowNode, frame: labelArrowNodeFrame)
                rightLabelInset += 19.0
            }
        }
        
        let badgeDiameter: CGFloat = 20.0
        let labelSize = self.labelNode.frame.size
        
        let badgeWidth = max(badgeDiameter, labelSize.width + 10.0)
        let labelFrame: CGRect
        if case .badge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: offset + params.width - rightLabelInset - badgeWidth + (badgeWidth - labelSize.width) / 2.0, y: self.labelNode.frame.minY), size: labelSize)
        } else {
            labelFrame = CGRect(origin: CGPoint(x: offset + params.width - self.labelNode.bounds.size.width - rightLabelInset, y: self.labelNode.frame.minY), size: self.labelNode.bounds.size)
        }
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        transition.updateFrame(node: self.labelBadgeNode, frame: CGRect(origin: CGPoint(x: offset + params.width - rightLabelInset - badgeWidth, y: self.labelBadgeNode.frame.minY), size: CGSize(width: badgeWidth, height: badgeDiameter)))
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + params.leftInset + 15.0, y: self.avatarNode.frame.minY), size: self.avatarNode.bounds.size))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(item.peer.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(nil, item.peer.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            if let revealOptions = item.revealOptions {
                if option.key >= 0 && option.key < Int32(revealOptions.options.count) {
                    revealOptions.options[Int(option.key)].action()
                }
            } else {
                item.removePeer(item.peer.id)
            }
        }
    }
    
    private func toggleUpdated(_ value: Bool) {
        if let (item, _, _) = self.layoutParams {
            item.toggleUpdated?(value)
        }
    }
}
