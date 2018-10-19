import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

struct ItemListPeerItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
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
    let account: Account
    let peer: Peer
    let aliasHandling: ItemListPeerItemAliasHandling
    let nameColor: ItemListPeerItemNameColor
    let presence: PeerPresence?
    let text: ItemListPeerItemText
    let label: ItemListPeerItemLabel
    let editing: ItemListPeerItemEditing
    let revealOptions: ItemListPeerItemRevealOptions?
    let switchValue: ItemListPeerItemSwitch?
    let enabled: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    let toggleUpdated: ((Bool) -> Void)?
    let hasTopStripe: Bool
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, account: Account, peer: Peer, aliasHandling: ItemListPeerItemAliasHandling = .standard, nameColor: ItemListPeerItemNameColor = .primary, presence: PeerPresence?, text: ItemListPeerItemText, label: ItemListPeerItemLabel, editing: ItemListPeerItemEditing, revealOptions: ItemListPeerItemRevealOptions? = nil, switchValue: ItemListPeerItemSwitch?, enabled: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void, toggleUpdated: ((Bool) -> Void)? = nil, hasTopStripe: Bool = true) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.account = account
        self.peer = peer
        self.aliasHandling = aliasHandling
        self.nameColor = nameColor
        self.presence = presence
        self.text = text
        self.label = label
        self.editing = editing
        self.revealOptions = revealOptions
        self.switchValue = switchValue
        self.enabled = enabled
        self.sectionId = sectionId
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.toggleUpdated = toggleUpdated
        self.hasTopStripe = hasTopStripe
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListPeerItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (node.avatarNode.ready, { apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
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
                        completion(layout, {
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
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
private let avatarFont: UIFont = UIFont(name: ".SFCompactRounded-Semibold", size: 17.0)!

class ItemListPeerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let labelNode: TextNode
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
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.labelNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2)
                apply(true)
            }
        })
    }
    
    func asyncLayout() -> (_ item: ItemListPeerItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        var currentSwitchNode = self.switchNode
        var currentCheckNode = self.checkNode
        
        let currentLabelArrowNode = self.labelArrowNode
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, neighbors in
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
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
            
            if item.peer.id == item.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                titleAttributedString = NSAttributedString(string: item.strings.DialogList_SavedMessages, font: titleBoldFont, textColor: titleColor)
            } else if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                    string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                    string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: titleColor))
                    titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.strings.User_DeletedAccount, font: titleBoldFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: titleColor)
            }
            
            switch item.text {
                case .presence:
                    if let user = item.peer as? TelegramUser, user.botInfo != nil {
                        statusAttributedString = NSAttributedString(string: item.strings.Bot_GenericBotStatus, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
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

            let leftInset: CGFloat = 65.0 + params.leftInset
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(48.0, item.theme, false)
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
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: labelAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - labelLayout.size.width - editingOffset - rightInset - labelInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - labelInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: params.width, height: 48.0)
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
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors)
                    
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
                            let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
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
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: statusAttributedString == nil ? 13.0 : 5.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 25.0), size: statusLayout.size))
                    
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

                    transition.updateFrame(node: strongSelf.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - labelLayout.size.width - rightLabelInset - rightInset, y: floor((contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size))
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 12.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0)))
                    
                    if item.peer.id == item.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: item.peer, overrideImage: .savedMessagesIcon)
                    } else {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: item.peer)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: 48.0 + UIScreenPixel + UIScreenPixel))
                    
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
        
        guard let params = self.layoutParams?.1 else {
            return
        }
        
        let leftInset: CGFloat = 65.0 + params.leftInset
        
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
        
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - self.labelNode.bounds.size.width - rightLabelInset, y: self.labelNode.frame.minY), size: self.labelNode.bounds.size))
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + params.leftInset + 12.0, y: self.avatarNode.frame.minY), size: CGSize(width: 40.0, height: 40.0)))
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
