import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import CheckNode
import AvatarNode
import TelegramStringFormatting
import AccountContext
import PeerPresenceStatusManager
import ItemListPeerItem
import ContextUI
import AccountContext

public final class ContactItemHighlighting {
    public var chatLocation: ChatLocation?
    public var progress: CGFloat = 1.0
    
    public init(chatLocation: ChatLocation? = nil) {
        self.chatLocation = chatLocation
    }
}

public enum ContactsPeerItemStatus {
    case none
    case presence(PeerPresence, PresentationDateTimeFormat)
    case addressName(String)
    case custom(String)
}

public enum ContactsPeerItemSelection: Equatable {
    case none
    case selectable(selected: Bool)
}

public struct ContactsPeerItemEditing: Equatable {
    public var editable: Bool
    public var editing: Bool
    public var revealed: Bool
    
    public init(editable: Bool, editing: Bool, revealed: Bool) {
        self.editable = editable
        self.editing = editing
        self.revealed = revealed
    }
}

public enum ContactsPeerItemPeerMode {
    case generalSearch
    case peer
}

public enum ContactsPeerItemBadgeType {
    case active
    case inactive
}

public struct ContactsPeerItemBadge {
    public var count: Int32
    public var type: ContactsPeerItemBadgeType
    
    public init(count: Int32, type: ContactsPeerItemBadgeType) {
        self.count = count
        self.type = type
    }
}

public enum ContactsPeerItemActionIcon {
    case none
    case add
}

public enum ContactsPeerItemPeer: Equatable {
    case peer(peer: Peer?, chatPeer: Peer?)
    case deviceContact(stableId: DeviceContactStableId, contact: DeviceContactBasicData)
    
    public static func ==(lhs: ContactsPeerItemPeer, rhs: ContactsPeerItemPeer) -> Bool {
        switch lhs {
        case let .peer(lhsPeer, lhsChatPeer):
            if case let .peer(rhsPeer, rhsChatPeer) = rhs {
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                if !arePeersEqual(lhsChatPeer, rhsChatPeer) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .deviceContact(stableId, contact):
            if case .deviceContact(stableId, contact) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public class ContactsPeerItem: ItemListItem, ListViewItemWithHeader {
    let presentationData: ItemListPresentationData
    let style: ItemListStyle
    public let sectionId: ItemListSectionId
    let sortOrder: PresentationPersonNameOrder
    let displayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peerMode: ContactsPeerItemPeerMode
    public let peer: ContactsPeerItemPeer
    let status: ContactsPeerItemStatus
    let badge: ContactsPeerItemBadge?
    let enabled: Bool
    let selection: ContactsPeerItemSelection
    let editing: ContactsPeerItemEditing
    let options: [ItemListPeerItemRevealOption]
    let actionIcon: ContactsPeerItemActionIcon
    let action: (ContactsPeerItemPeer) -> Void
    let setPeerIdWithRevealedOptions: ((PeerId?, PeerId?) -> Void)?
    let deletePeer: ((PeerId) -> Void)?
    let itemHighlighting: ContactItemHighlighting?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    public let selectable: Bool
    
    public let headerAccessoryItem: ListViewAccessoryItem?
    
    public let header: ListViewItemHeader?
    
    public init(presentationData: ItemListPresentationData, style: ItemListStyle = .plain, sectionId: ItemListSectionId = 0, sortOrder: PresentationPersonNameOrder, displayOrder: PresentationPersonNameOrder, context: AccountContext, peerMode: ContactsPeerItemPeerMode, peer: ContactsPeerItemPeer, status: ContactsPeerItemStatus, badge: ContactsPeerItemBadge? = nil, enabled: Bool, selection: ContactsPeerItemSelection, editing: ContactsPeerItemEditing, options: [ItemListPeerItemRevealOption] = [], actionIcon: ContactsPeerItemActionIcon = .none, index: PeerNameIndex?, header: ListViewItemHeader?, action: @escaping (ContactsPeerItemPeer) -> Void, setPeerIdWithRevealedOptions: ((PeerId?, PeerId?) -> Void)? = nil, deletePeer: ((PeerId) -> Void)? = nil, itemHighlighting: ContactItemHighlighting? = nil, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil) {
        self.presentationData = presentationData
        self.style = style
        self.sectionId = sectionId
        self.sortOrder = sortOrder
        self.displayOrder = displayOrder
        self.context = context
        self.peerMode = peerMode
        self.peer = peer
        self.status = status
        self.badge = badge
        self.enabled = enabled
        self.selection = selection
        self.editing = editing
        self.options = options
        self.actionIcon = actionIcon
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.header = header
        self.itemHighlighting = itemHighlighting
        self.selectable = enabled
        self.contextAction = contextAction
        
        if let index = index {
            var letter: String = "#"
            switch peer {
                case let .peer(peer, _):
                    if let user = peer as? TelegramUser {
                        switch index {
                            case .firstNameFirst:
                                if let firstName = user.firstName, !firstName.isEmpty {
                                    letter = String(firstName.prefix(1)).uppercased()
                                } else if let lastName = user.lastName, !lastName.isEmpty {
                                    letter = String(lastName.prefix(1)).uppercased()
                                }
                            case .lastNameFirst:
                                if let lastName = user.lastName, !lastName.isEmpty {
                                    letter = String(lastName.prefix(1)).uppercased()
                                } else if let firstName = user.firstName, !firstName.isEmpty {
                                    letter = String(firstName.prefix(1)).uppercased()
                                }
                        }
                    } else if let group = peer as? TelegramGroup {
                        if !group.title.isEmpty {
                            letter = String(group.title.prefix(1)).uppercased()
                        }
                    } else if let channel = peer as? TelegramChannel {
                        if !channel.title.isEmpty {
                            letter = String(channel.title.prefix(1)).uppercased()
                        }
                    }
                case let .deviceContact(_, contact):
                    switch index {
                        case .firstNameFirst:
                            if !contact.firstName.isEmpty {
                                letter = String(contact.firstName.prefix(1)).uppercased()
                            } else if !contact.lastName.isEmpty {
                                letter = String(contact.lastName.prefix(1)).uppercased()
                            }
                        case .lastNameFirst:
                            if !contact.lastName.isEmpty {
                                letter = String(contact.lastName.prefix(1)).uppercased()
                            } else if !contact.firstName.isEmpty {
                                letter = String(contact.firstName.prefix(1)).uppercased()
                            }
                    }
            }
            self.headerAccessoryItem = ContactsSectionHeaderAccessoryItem(sectionHeader: .letter(letter), theme: presentationData.theme)
        } else {
            self.headerAccessoryItem = nil
        }
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ContactsPeerItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    let (signal, apply) = nodeApply()
                    return (signal, { _ in
                        apply(false, synchronousLoads)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ContactsPeerItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply().1(animation.isAnimated, false)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        self.action(self.peer)
    }
    
    static func mergeType(item: ContactsPeerItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ListViewItemWithHeader {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if let nextItem = nextItem {
            if let header = item.header {
                if let nextItem = nextItem as? ListViewItemWithHeader {
                    last = header.id != nextItem.header?.id
                } else {
                    last = true
                }
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

public class ContactsPeerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let containerNode: ContextControllerSourceNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private var verificationIconNode: ASImageNode?
    private let statusNode: TextNode
    private var badgeBackgroundNode: ASImageNode?
    private var badgeTextNode: TextNode?
    private var selectionNode: CheckNode?
    private var actionIconNode: ASImageNode?
    
    private var isHighlighted: Bool = false

    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ContactsPeerItem, ListViewItemLayoutParams, Bool, Bool, Bool, ItemListNeighbors)?
    public var chatPeer: Peer? {
        if let peer = self.layoutParams?.0.peer {
            switch peer {
                case let .peer(peer, chatPeer):
                    return chatPeer ?? peer
                case .deviceContact:
                    return nil
            }
        } else {
            return nil
        }
    }
    
    public var item: ContactsPeerItem? {
        return self.layoutParams?.0
    }
    
    required public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.containerNode = ContextControllerSourceNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4, layoutParams.5)
                let _ = apply()
            }
        })
        
        self.containerNode.activated = { [weak self] gesture in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.containerNode, gesture)
        }
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, params, first, last, firstWithHeader, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        if let item = self.item, case .selectable = item.selection {
            return
        }
        
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.isHighlighted = highlighted
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }

    
    public func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        var reallyHighlighted = self.isHighlighted
        let highlightProgress: CGFloat = self.item?.itemHighlighting?.progress ?? 1.0
        if let item = self.item {
            switch item.peer {
            case let .peer(_, chatPeer):
                if let peer = chatPeer {
                    if ChatLocation.peer(peer.id) == item.itemHighlighting?.chatLocation {
                        reallyHighlighted = true
                    }
                }
            default:
                break
            }
        }
        
        if reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: highlightProgress)
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 1.0 - highlightProgress, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    }
                })
            }
        }
    }
    
    public func asyncLayout() -> (_ item: ContactsPeerItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (Bool, Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let currentSelectionNode = self.selectionNode
        
        let makeBadgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let titleBoldFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            let badgeFont = Font.regular(14.0)
            let avatarDiameter = min(40.0, floor(item.presentationData.fontSize.itemListBaseFontSize * 40.0 / 17.0))
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            var leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset
            
            let updatedSelectionNode: CheckNode?
            var isSelected = false
            switch item.selection {
            case .none:
                updatedSelectionNode = nil
            case let .selectable(selected):
                leftInset += 28.0
                isSelected = selected
                
                let selectionNode: CheckNode
                if let current = currentSelectionNode {
                    selectionNode = current
                    updatedSelectionNode = selectionNode
                } else {
                    selectionNode = CheckNode(strokeColor: item.presentationData.theme.list.itemCheckColors.strokeColor, fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, style: .plain)
                    selectionNode.isUserInteractionEnabled = false
                    updatedSelectionNode = selectionNode
                }
            }
            
            var verificationIconImage: UIImage?
            switch item.peer {
            case let .peer(peer, _):
                if let peer = peer, peer.isVerified {
                    verificationIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                }
            case .deviceContact:
                break
            }
            
            let actionIconImage: UIImage?
            switch item.actionIcon {
            case .none:
                actionIconImage = nil
            case .add:
                actionIconImage = PresentationResourcesItemList.plusIconImage(item.presentationData.theme)
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var userPresence: TelegramUserPresence?
            
            switch item.peer {
            case let .peer(peer, chatPeer):
                if let peer = peer {
                    let textColor: UIColor
                    if let _ = chatPeer as? TelegramSecretChat {
                        textColor = item.presentationData.theme.chatList.secretTitleColor
                    } else {
                        textColor = item.presentationData.theme.list.itemPrimaryTextColor
                    }
                    if let user = peer as? TelegramUser {
                        if peer.id == item.context.account.peerId, case .generalSearch = item.peerMode {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleBoldFont, textColor: textColor)
                        } else if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                            let string = NSMutableAttributedString()
                            switch item.displayOrder {
                            case .firstLast:
                                string.append(NSAttributedString(string: firstName, font: item.sortOrder == .firstLast ? titleBoldFont : titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: lastName, font: item.sortOrder == .firstLast ? titleFont : titleBoldFont, textColor: textColor))
                            case .lastFirst:
                                string.append(NSAttributedString(string: lastName, font: item.sortOrder == .firstLast ? titleFont : titleBoldFont, textColor: textColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: firstName, font: item.sortOrder == .firstLast ? titleBoldFont : titleFont, textColor: textColor))
                            }
                            titleAttributedString = string
                        } else if let firstName = user.firstName, !firstName.isEmpty {
                            titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: textColor)
                        } else if let lastName = user.lastName, !lastName.isEmpty {
                            titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: textColor)
                        } else {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleBoldFont, textColor: textColor)
                        }
                    } else if let group = peer as? TelegramGroup {
                        titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                    } else if let channel = peer as? TelegramChannel {
                        titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                    }
                    
                    switch item.status {
                    case .none:
                        break
                    case let .presence(presence, dateTimeFormat):
                        let presence = (presence as? TelegramUserPresence) ?? TelegramUserPresence(status: .none, lastActivity: 0)
                        userPresence = presence
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
                    case let .addressName(suffix):
                        if let addressName = peer.addressName {
                            let addressNameString = NSAttributedString(string: "@" + addressName, font: statusFont, textColor: item.presentationData.theme.list.itemAccentColor)
                            if !suffix.isEmpty {
                                let suffixString = NSAttributedString(string: suffix, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                                let finalString = NSMutableAttributedString()
                                finalString.append(addressNameString)
                                finalString.append(suffixString)
                                statusAttributedString = finalString
                            } else {
                                statusAttributedString = addressNameString
                            }
                        } else if !suffix.isEmpty {
                            statusAttributedString = NSAttributedString(string: suffix, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        }
                    case let .custom(text):
                        statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    }
                }
            case let .deviceContact(_, contact):
                let textColor: UIColor = item.presentationData.theme.list.itemPrimaryTextColor
                
                if !contact.firstName.isEmpty, !contact.lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: contact.firstName, font: titleFont, textColor: textColor))
                    string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                    string.append(NSAttributedString(string: contact.lastName, font: titleBoldFont, textColor: textColor))
                    titleAttributedString = string
                } else if !contact.firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: contact.firstName, font: titleBoldFont, textColor: textColor)
                } else if !contact.lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: contact.lastName, font: titleBoldFont, textColor: textColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleBoldFont, textColor: textColor)
                }
                
                switch item.status {
                case let .custom(text):
                    statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                default:
                    break
                }
            }
            
            var badgeTextLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            var currentBadgeBackgroundImage: UIImage?
            if let badge = item.badge {
                let badgeTextColor: UIColor
                switch badge.type {
                    case .inactive:
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: 20.0)
                        badgeTextColor = item.presentationData.theme.chatList.unreadBadgeInactiveTextColor
                    case .active:
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: 20.0)
                        badgeTextColor = item.presentationData.theme.chatList.unreadBadgeActiveTextColor
                }
                let badgeAttributedString = NSAttributedString(string: badge.count > 0 ? "\(badge.count)" : " ", font: badgeFont, textColor: badgeTextColor)
                badgeTextLayoutAndApply = makeBadgeTextLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            var badgeSize: CGFloat = 0.0
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage, let (badgeTextLayout, _) = badgeTextLayoutAndApply {
                badgeSize += max(currentBadgeBackgroundImage.size.width, badgeTextLayout.size.width + 10.0) + 5.0
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let verificationIconImage = verificationIconImage {
                additionalTitleInset += 3.0 + verificationIconImage.size.width
            }
            if let actionIconImage = actionIconImage {
                additionalTitleInset += 3.0 + actionIconImage.size.width
            }
            
            additionalTitleInset += badgeSize
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset - additionalTitleInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset - badgeSize), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleVerticalInset: CGFloat = statusAttributedString == nil ? 13.0 : 6.0
            let verticalInset: CGFloat = statusAttributedString == nil ? 13.0 : 6.0
            
            let statusHeightComponent: CGFloat
            if statusAttributedString == nil {
                statusHeightComponent = 0.0
            } else {
                statusHeightComponent = -1.0 + statusLayout.size.height
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + statusHeightComponent), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame: CGRect
            if statusAttributedString != nil {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleVerticalInset), size: titleLayout.size)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.enabled {
                var mappedOptions: [ItemListRevealOption] = []
                var index: Int32 = 0
                for option in item.options {
                    let color: UIColor
                    let textColor: UIColor
                    switch option.type {
                        case .neutral:
                            color = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.constructive.foregroundColor
                        case .warning:
                            color = item.presentationData.theme.list.itemDisclosureActions.warning.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.warning.foregroundColor
                        case .destructive:
                            color = item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor
                    }
                    mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                    index += 1
                }
                peerRevealOptions = mappedOptions
            } else {
                peerRevealOptions = []
            }
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    return (.complete(), { [weak strongSelf] animated, synchronousLoads in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, params, first, last, firstWithHeader, neighbors)
                            
                            strongSelf.accessibilityLabel = titleAttributedString?.string
                            strongSelf.accessibilityValue = statusAttributedString?.string
                            
                            strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                            
                            switch item.peer {
                                case let .peer(peer, _):
                                    if let peer = peer {
                                        var overrideImage: AvatarNodeImageOverride?
                                        if peer.id == item.context.account.peerId, case .generalSearch = item.peerMode {
                                            overrideImage = .savedMessagesIcon
                                        } else if peer.isDeleted {
                                            overrideImage = .deletedIcon
                                        }
                                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
                                    }
                                case let .deviceContact(_, contact):
                                    let letters: [String]
                                    if !contact.firstName.isEmpty && !contact.lastName.isEmpty {
                                        letters = [contact.firstName[..<contact.firstName.index(after: contact.firstName.startIndex)].uppercased(), contact.lastName[..<contact.lastName.index(after: contact.lastName.startIndex)].uppercased()]
                                    } else if !contact.firstName.isEmpty {
                                        letters = [contact.firstName[..<contact.firstName.index(after: contact.firstName.startIndex)].uppercased()]
                                    } else if !contact.lastName.isEmpty {
                                        letters = [contact.lastName[..<contact.lastName.index(after: contact.lastName.startIndex)].uppercased()]
                                    } else {
                                        letters = [" "]
                                    }
                                    strongSelf.avatarNode.setCustomLetters(letters)
                            }
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            let revealOffset = strongSelf.revealOffset
                            
                            if let _ = updatedTheme {
                                switch item.style {
                                case .plain:
                                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                    strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                                case .blocks:
                                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                                    strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                                }
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            switch item.style {
                            case .plain:
                                strongSelf.topSeparatorNode.isHidden = true
                            case .blocks:
                                switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topSeparatorNode.isHidden = true
                                default:
                                    strongSelf.topSeparatorNode.isHidden = false
                                }
                            }
                            
                            transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 50.0, y: floor((nodeLayout.contentSize.height - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter)))
                            
                            let _ = titleApply()
                            transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame.offsetBy(dx: revealOffset, dy: 0.0))
                            
                            strongSelf.titleNode.alpha = item.enabled ? 1.0 : 0.4
                            strongSelf.statusNode.alpha = item.enabled ? 1.0 : 1.0
                            
                            let _ = statusApply()
                            let statusFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: strongSelf.titleNode.frame.maxY - 1.0), size: statusLayout.size)
                            let previousStatusFrame = strongSelf.statusNode.frame
                            
                            strongSelf.statusNode.frame = statusFrame
                            transition.animatePositionAdditive(node: strongSelf.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
                            
                            if let verificationIconImage = verificationIconImage {
                                if strongSelf.verificationIconNode == nil {
                                    let verificationIconNode = ASImageNode()
                                    verificationIconNode.isLayerBacked = true
                                    verificationIconNode.displayWithoutProcessing = true
                                    verificationIconNode.displaysAsynchronously = false
                                    strongSelf.verificationIconNode = verificationIconNode
                                    strongSelf.containerNode.addSubnode(verificationIconNode)
                                }
                                if let verificationIconNode = strongSelf.verificationIconNode {
                                    verificationIconNode.image = verificationIconImage
                                    
                                    transition.updateFrame(node: verificationIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + titleFrame.maxX + 3.0, y: titleFrame.minY + 3.0 + UIScreenPixel), size: verificationIconImage.size))
                                }
                            } else if let verificationIconNode = strongSelf.verificationIconNode {
                                strongSelf.verificationIconNode = nil
                                verificationIconNode.removeFromSupernode()
                            }
                            
                            if let actionIconImage = actionIconImage {
                                if strongSelf.actionIconNode == nil {
                                    let actionIconNode = ASImageNode()
                                    actionIconNode.isLayerBacked = true
                                    actionIconNode.displayWithoutProcessing = true
                                    actionIconNode.displaysAsynchronously = false
                                    strongSelf.actionIconNode = actionIconNode
                                    strongSelf.containerNode.addSubnode(actionIconNode)
                                }
                                if let actionIconNode = strongSelf.actionIconNode {
                                    actionIconNode.image = actionIconImage
                                    
                                    transition.updateFrame(node: actionIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - params.rightInset - 12.0 - actionIconImage.size.width, y: floor((nodeLayout.contentSize.height - actionIconImage.size.height) / 2.0)), size: actionIconImage.size))
                                }
                            } else if let actionIconNode = strongSelf.actionIconNode {
                                strongSelf.actionIconNode = nil
                                actionIconNode.removeFromSupernode()
                            }
                            
                            let badgeBackgroundWidth: CGFloat
                            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage, let (badgeTextLayout, badgeTextApply) = badgeTextLayoutAndApply {
                                let badgeBackgroundNode: ASImageNode
                                let badgeTransition: ContainedViewLayoutTransition
                                if let current = strongSelf.badgeBackgroundNode {
                                    badgeBackgroundNode = current
                                    badgeTransition = transition
                                } else {
                                    badgeBackgroundNode = ASImageNode()
                                    badgeBackgroundNode.isLayerBacked = true
                                    badgeBackgroundNode.displaysAsynchronously = false
                                    badgeBackgroundNode.displayWithoutProcessing = true
                                    strongSelf.containerNode.addSubnode(badgeBackgroundNode)
                                    strongSelf.badgeBackgroundNode = badgeBackgroundNode
                                    badgeTransition = .immediate
                                }
                                
                                badgeBackgroundNode.image = currentBadgeBackgroundImage
                                
                                badgeBackgroundWidth = max(badgeTextLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                                let badgeBackgroundFrame = CGRect(x: revealOffset + params.width - params.rightInset - badgeBackgroundWidth - 6.0, y: floor((nodeLayout.contentSize.height - currentBadgeBackgroundImage.size.height) / 2.0), width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                                let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeTextLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 2.0), size: badgeTextLayout.size)
                                
                                let badgeTextNode = badgeTextApply()
                                if badgeTextNode !== strongSelf.badgeTextNode {
                                    strongSelf.badgeTextNode?.removeFromSupernode()
                                    strongSelf.containerNode.addSubnode(badgeTextNode)
                                    strongSelf.badgeTextNode = badgeTextNode
                                }
                                
                                badgeTransition.updateFrame(node: badgeBackgroundNode, frame: badgeBackgroundFrame)
                                badgeTransition.updateFrame(node: badgeTextNode, frame: badgeTextFrame)
                            } else {
                                badgeBackgroundWidth = 0.0
                                if let badgeBackgroundNode = strongSelf.badgeBackgroundNode {
                                    badgeBackgroundNode.removeFromSupernode()
                                    strongSelf.badgeBackgroundNode = nil
                                }
                                if let badgeTextNode = strongSelf.badgeTextNode {
                                    badgeTextNode.removeFromSupernode()
                                    strongSelf.badgeTextNode = badgeTextNode
                                }
                            }
                            
                            if let updatedSelectionNode = updatedSelectionNode {
                                if strongSelf.selectionNode !== updatedSelectionNode {
                                    strongSelf.selectionNode?.removeFromSupernode()
                                    strongSelf.selectionNode = updatedSelectionNode
                                    strongSelf.addSubnode(updatedSelectionNode)
                                }
                                updatedSelectionNode.setIsChecked(isSelected, animated: animated)
                                
                                updatedSelectionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 6.0, y: floor((nodeLayout.contentSize.height - 32.0) / 2.0)), size: CGSize(width: 32.0, height: 32.0))
                            } else if let selectionNode = strongSelf.selectionNode {
                                selectionNode.removeFromSupernode()
                                strongSelf.selectionNode = nil
                            }
                            
                            let separatorHeight = UIScreenPixel
                            
                            let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(nodeLayout.insets.top, separatorHeight)), size: CGSize(width: nodeLayout.contentSize.width, height: separatorHeight))
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - leftInset), height: separatorHeight))
                            strongSelf.separatorNode.isHidden = last
                            
                            if let userPresence = userPresence {
                                strongSelf.peerPresenceManager?.reset(presence: userPresence)
                            }
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                            
                            if item.editing.editable {
                                strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                                strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                            } else {
                                strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                                strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                            }
                        }
                    })
                } else {
                    return (nil, { _, _ in
                    })
                }
            })
        }
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let item = self.item, let params = self.layoutParams?.1 {
            var leftInset: CGFloat = 65.0 + params.leftInset
            
            switch item.selection {
                case .none:
                    break
                case .selectable:
                    leftInset += 28.0
            }
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = offset + leftInset - 50.0
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var statusFrame = self.statusNode.frame
            let previousStatusFrame = statusFrame
            statusFrame.origin.x = leftInset + offset
            self.statusNode.frame = statusFrame
            transition.animatePositionAdditive(node: self.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
            
            if let verificationIconNode = self.verificationIconNode {
                var iconFrame = verificationIconNode.frame
                iconFrame.origin.x = titleFrame.maxX + 3.0
                transition.updateFrame(node: verificationIconNode, frame: iconFrame)
            }
            
            if let badgeBackgroundNode = self.badgeBackgroundNode, let badgeTextNode = self.badgeTextNode {
                var badgeBackgroundFrame = badgeBackgroundNode.frame
                badgeBackgroundFrame.origin.x = offset + params.width - params.rightInset - badgeBackgroundFrame.width - 6.0
                var badgeTextFrame = badgeTextNode.frame
                badgeTextFrame.origin.x = badgeBackgroundFrame.midX - badgeTextFrame.width / 2.0
                    
                transition.updateFrame(node: badgeBackgroundNode, frame: badgeBackgroundFrame)
                transition.updateFrame(node: badgeTextNode, frame: badgeTextFrame)
            }
        }
    }
    
    override public func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            switch item.peer {
                case let .peer(peer, chatPeer):
                    if let peer = chatPeer ?? peer {
                        item.setPeerIdWithRevealedOptions?(peer.id, nil)
                    }
                case .deviceContact:
                    break
            }
        }
    }
    
    override public func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            switch item.peer {
                case let .peer(peer, chatPeer):
                    if let peer = chatPeer ?? peer {
                        item.setPeerIdWithRevealedOptions?(nil, peer.id)
                    }
                case .deviceContact:
                    break
            }
        }
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            if item.editing.editable {
                switch item.peer {
                    case let .peer(peer, chatPeer):
                        if let peer = chatPeer ?? peer {
                            item.deletePeer?(peer.id)
                        }
                    case .deviceContact:
                        break
                }
            } else {
                item.options[Int(option.key)].action()
            }
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
    
    override public func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func header() -> ListViewItemHeader? {
        if let (item, _, _, _, _, _) = self.layoutParams {
            return item.header
        } else {
            return nil
        }
    }
}
