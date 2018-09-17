import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

private let updatingAvatarOverlayImage = generateFilledCircleImage(diameter: 66.0, color: UIColor(white: 1.0, alpha: 0.5), backgroundColor: nil)

enum ItemListAvatarAndNameInfoItemTitleType {
    case group
    case channel
}

enum ItemListAvatarAndNameInfoItemName: Equatable {
    case personName(firstName: String, lastName: String)
    case title(title: String, type: ItemListAvatarAndNameInfoItemTitleType)
    
    init(_ peer: Peer) {
        switch peer.indexName {
            case let .personName(first, last, _, _):
                self = .personName(firstName: first, lastName: last)
            case let .title(title, _):
                let type: ItemListAvatarAndNameInfoItemTitleType
                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                    type = .channel
                } else {
                    type = .group
                }
                self = .title(title: title, type: type)
        }
    }
    
    var composedTitle: String {
        switch self {
            case let .personName(firstName, lastName):
                if !firstName.isEmpty && !lastName.isEmpty {
                    return firstName + " " + lastName
                } else if !firstName.isEmpty {
                    return firstName
                } else {
                    return lastName
                }
            case let .title(title, _):
                return title
        }
    }
    
    func composedDisplayTitle(strings: PresentationStrings) -> String {
        switch self {
            case let .personName(firstName, lastName):
                if !firstName.isEmpty && !lastName.isEmpty {
                    return firstName + " " + lastName
                } else if !firstName.isEmpty {
                    return firstName
                } else if !lastName.isEmpty {
                    return lastName
                } else {
                    return strings.User_DeletedAccount
                }
            case let .title(title, _):
                return title
        }
    }
    
    var isEmpty: Bool {
        switch self {
            case let .personName(firstName, _):
                return firstName.isEmpty
            case let .title(title, _):
                return title.isEmpty
        }
    }
    
    static func ==(lhs: ItemListAvatarAndNameInfoItemName, rhs: ItemListAvatarAndNameInfoItemName) -> Bool {
        switch lhs {
            case let .personName(firstName, lastName):
                if case .personName(firstName, lastName) = rhs {
                    return true
                } else {
                    return false
                }
            case let .title(title, type):
                if case .title(title, type) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct ItemListAvatarAndNameInfoItemState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    
    init(editingName: ItemListAvatarAndNameInfoItemName? = nil, updatingName: ItemListAvatarAndNameInfoItemName? = nil) {
        self.editingName = editingName
        self.updatingName = updatingName
    }
    
    static func ==(lhs: ItemListAvatarAndNameInfoItemState, rhs: ItemListAvatarAndNameInfoItemState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        return true
    }
}

final class ItemListAvatarAndNameInfoItemContext {
    var hiddenAvatarRepresentation: TelegramMediaImageRepresentation?
}

enum ItemListAvatarAndNameInfoItemStyle {
    case plain
    case blocks(withTopInset: Bool)
}

enum ItemListAvatarAndNameInfoItemUpdatingAvatar: Equatable {
    case image(TelegramMediaImageRepresentation)
    case none
    
    static func ==(lhs: ItemListAvatarAndNameInfoItemUpdatingAvatar, rhs: ItemListAvatarAndNameInfoItemUpdatingAvatar) -> Bool {
        switch lhs {
            case let .image(representation):
                if case .image(representation) = rhs {
                    return true
                } else {
                    return false
                }
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ItemListAvatarAndNameInfoItemMode {
    case generic
    case settings
    case editSettings
}

class ItemListAvatarAndNameInfoItem: ListViewItem, ItemListItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mode: ItemListAvatarAndNameInfoItemMode
    let peer: Peer?
    let presence: PeerPresence?
    let label: String?
    let cachedData: CachedPeerData?
    let state: ItemListAvatarAndNameInfoItemState
    let sectionId: ItemListSectionId
    let style: ItemListAvatarAndNameInfoItemStyle
    let editingNameUpdated: (ItemListAvatarAndNameInfoItemName) -> Void
    let avatarTapped: () -> Void
    let context: ItemListAvatarAndNameInfoItemContext?
    let updatingImage: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let call: (() -> Void)?
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    let tag: ItemListItemTag?
    
    let selectable: Bool

    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, mode: ItemListAvatarAndNameInfoItemMode, peer: Peer?, presence: PeerPresence?, label: String? = nil, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, sectionId: ItemListSectionId, style: ItemListAvatarAndNameInfoItemStyle, editingNameUpdated: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, avatarTapped: @escaping () -> Void, context: ItemListAvatarAndNameInfoItemContext? = nil, updatingImage: ItemListAvatarAndNameInfoItemUpdatingAvatar? = nil, call: (() -> Void)? = nil, action: (() -> Void)? = nil, longTapAction: (() -> Void)? = nil, tag: ItemListItemTag? = nil) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.peer = peer
        self.presence = presence
        self.label = label
        self.cachedData = cachedData
        self.state = state
        self.sectionId = sectionId
        self.style = style
        self.editingNameUpdated = editingNameUpdated
        self.avatarTapped = avatarTapped
        self.context = context
        self.updatingImage = updatingImage
        self.call = call
        self.action = action
        self.longTapAction = longTapAction
        self.tag = tag
        
        if case .settings = mode {
            self.selectable = true
        } else {
            self.selectable = false
        }
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListAvatarAndNameInfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListAvatarAndNameInfoItemNode {
                var animated = true
                if case .None = animation {
                    animated = false
                }
                let makeLayout = nodeValue.asyncLayout()
                
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
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 28.0)!
private let nameFont = Font.medium(19.0)
private let statusFont = Font.regular(15.0)

class ItemListAvatarAndNameInfoItemNode: ListViewItemNode, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let updatingAvatarOverlay: ASImageNode
    
    private let callButton: HighlightableButtonNode
    
    private let nameNode: TextNode
    private var verificationIconNode: ASImageNode?
    private let statusNode: TextNode
    
    private let arrowNode: ASImageNode
    
    private var inputSeparator: ASDisplayNode?
    private var inputFirstField: UITextField?
    private var inputSecondField: UITextField?
    
    private var item: ItemListAvatarAndNameInfoItem?
    private var layoutWidthAndNeighbors: (width: ListViewItemLayoutParams, neighbors: ItemListNeighbors)?
    private var peerPresenceManager: PeerPresenceStatusManager?
    
    private let hiddenAvatarRepresentationDisposable = MetaDisposable()
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    var callButtonFrame: CGRect? {
        if !self.callButton.alpha.isZero && self.callButton.supernode != nil {
            return self.callButton.frame
        } else {
            return nil
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.updatingAvatarOverlay = ASImageNode()
        self.updatingAvatarOverlay.displayWithoutProcessing = true
        self.updatingAvatarOverlay.displaysAsynchronously = false
        
        self.nameNode = TextNode()
        self.nameNode.isLayerBacked = true
        self.nameNode.contentMode = .left
        self.nameNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        
        self.callButton = HighlightableButtonNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.nameNode)
        self.addSubnode(self.statusNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let item = strongSelf.item, let layoutWidthAndNeighbors = strongSelf.layoutWidthAndNeighbors {
                let (_, apply) = strongSelf.asyncLayout()(item, layoutWidthAndNeighbors.0, layoutWidthAndNeighbors.1)
                apply(true)
            }
        })
        
        self.callButton.addTarget(self, action: #selector(callButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.hiddenAvatarRepresentationDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.avatarTapGesture(_:))))
    }
    
    func asyncLayout() -> (_ item: ItemListAvatarAndNameInfoItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        let currentOverlayImage = self.updatingAvatarOverlay.image
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            var isVerified = false
            if let peer = item.peer as? TelegramUser {
                isVerified = peer.flags.contains(.isVerified)
            } else if let peer = item.peer as? TelegramChannel {
                isVerified = peer.flags.contains(.isVerified)
            }
            var verificationIconImage: UIImage?
            if isVerified {
                verificationIconImage = PresentationResourcesItemList.verifiedPeerIcon(item.theme)
            }
            
            let displayTitle: ItemListAvatarAndNameInfoItemName
            if let updatingName = item.state.updatingName {
                displayTitle = updatingName
            } else if let peer = item.peer {
                displayTitle = ItemListAvatarAndNameInfoItemName(peer)
            } else {
                displayTitle = .title(title: "", type: .group)
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let verificationIconImage = verificationIconImage {
                additionalTitleInset += 3.0 + verificationIconImage.size.width
            }
            
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayTitle.composedDisplayTitle(strings: item.strings), font: nameFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: baseWidth - 20 - 94.0 - (item.call != nil ? 36.0 : 0.0) - additionalTitleInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var statusText: String = ""
            let statusColor: UIColor
            if let peer = item.peer as? TelegramUser {
                switch item.mode {
                    case .settings:
                        if let phone = peer.phone, !phone.isEmpty {
                            statusText += formatPhoneNumber(phone)
                        }
                        if let username = peer.username, !username.isEmpty {
                            if !statusText.isEmpty {
                                statusText += "\n"
                            }
                            statusText += "@\(username)"
                        }
                        statusColor = item.theme.list.itemSecondaryTextColor
                    case .generic, .editSettings:
                        if let label = item.label {
                            statusText = label
                            statusColor = item.theme.list.itemSecondaryTextColor
                        } else if let _ = peer.botInfo {
                            statusText = item.strings.Bot_GenericBotStatus
                            statusColor = item.theme.list.itemSecondaryTextColor
                        } else if let presence = item.presence as? TelegramUserPresence {
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (string, activity) = stringAndActivityForUserPresence(strings: item.strings, timeFormat: .regular, presence: presence, relativeTo: Int32(timestamp))
                            statusText = string
                            if activity {
                                statusColor = item.theme.list.itemAccentColor
                            } else {
                                statusColor = item.theme.list.itemSecondaryTextColor
                            }
                        } else {
                            statusText = ""
                            statusColor = item.theme.list.itemPrimaryTextColor
                        }
                }
            } else if let channel = item.peer as? TelegramChannel {
                if let cachedChannelData = item.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    if case .group = channel.info {
                        statusText = item.strings.Conversation_StatusMembers(memberCount)
                    } else {
                        statusText = item.strings.Conversation_StatusSubscribers(memberCount)
                    }
                    statusColor = item.theme.list.itemSecondaryTextColor
                } else {
                    switch channel.info {
                        case .broadcast:
                            statusText = item.strings.Channel_Status
                            statusColor = item.theme.list.itemSecondaryTextColor
                        case .group:
                            statusText = item.strings.Group_Status
                            statusColor = item.theme.list.itemSecondaryTextColor
                    }
                }
            } else if let group = item.peer as? TelegramGroup {
                statusText = item.strings.GroupInfo_ParticipantCount(Int32(group.participantCount))
                statusColor = item.theme.list.itemSecondaryTextColor
            } else {
                statusText = ""
                statusColor = item.theme.list.itemPrimaryTextColor
            }
            
            let (statusNodeLayout, statusNodeApply) = layoutStatusNode(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: baseWidth - 20, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
                    contentSize = CGSize(width: params.width, height: 96.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case let .blocks(withTopInset):
                    itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
                    contentSize = CGSize(width: params.width, height: 92.0)
                    if withTopInset {
                        insets = itemListNeighborsGroupedInsets(neighbors)
                    } else {
                        let topInset: CGFloat
                        switch neighbors.top {
                            case .sameSection, .none:
                                topInset = 0.0
                            case .otherSection:
                                topInset = separatorHeight + 35.0
                        }
                        insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: separatorHeight, right: 0.0)
                    }
            }
            
            var updateAvatarOverlayImage: UIImage?
            if item.updatingImage != nil && item.peer?.id.namespace != -1 && currentOverlayImage == nil {
                updateAvatarOverlayImage = updatingAvatarOverlayImage
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.layoutWidthAndNeighbors = (params, neighbors)
                    
                    var updatedArrowImage: UIImage?
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.inputSeparator?.backgroundColor = itemSeparatorColor
                        strongSelf.callButton.setImage(PresentationResourcesChat.chatInfoCallButtonImage(item.theme), for: [])
                        
                        updatedArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                    }
                    
                    if item.updatingImage != nil {
                        if let updateAvatarOverlayImage = updateAvatarOverlayImage {
                            strongSelf.updatingAvatarOverlay.image = updateAvatarOverlayImage
                        }
                        strongSelf.updatingAvatarOverlay.alpha = 1.0
                        if strongSelf.updatingAvatarOverlay.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.updatingAvatarOverlay, aboveSubnode: strongSelf.avatarNode)
                        }
                    } else if strongSelf.updatingAvatarOverlay.supernode != nil {
                        if animated {
                            strongSelf.updatingAvatarOverlay.alpha = 0.0
                            strongSelf.updatingAvatarOverlay.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { value in
                                if value {
                                    self?.updatingAvatarOverlay.removeFromSupernode()
                                }
                            })
                        } else {
                            strongSelf.updatingAvatarOverlay.removeFromSupernode()
                        }
                    }
                    
                    if item.call != nil {
                        strongSelf.addSubnode(strongSelf.callButton)
                        
                        strongSelf.callButton.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 44.0 - 10.0, y: floor((contentSize.height - 44.0) / 2.0) - 2.0), size: CGSize(width: 44.0, height: 44.0))
                    } else if strongSelf.callButton.supernode != nil {
                        strongSelf.callButton.removeFromSupernode()
                    }
                    
                    let avatarOriginY: CGFloat
                    switch item.style {
                        case .plain:
                            avatarOriginY = 15.0
                            
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.bottomStripeNode.removeFromSupernode()
                            }
                        case .blocks:
                            avatarOriginY = 13.0
                            
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
                                case .sameSection:
                                    strongSelf.topStripeNode.isHidden = true
                                case .none, .otherSection:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection:
                                    bottomStripeInset = params.leftInset + 16.0
                                case .none, .otherSection:
                                    bottomStripeInset = 0.0
                            }
                        
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: layoutSize.height - insets.top - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let _ = nameNodeApply()
                    let _ = statusNodeApply()
                    
                    if let peer = item.peer {
                        var overrideImage: AvatarNodeImageOverride?
                        if let updatingImage = item.updatingImage {
                            switch updatingImage {
                                case .none:
                                    overrideImage = AvatarNodeImageOverride.none
                                case let .image(representation):
                                    overrideImage = .image(representation)
                            }
                        } else if case .editSettings = item.mode {
                            overrideImage = AvatarNodeImageOverride.editAvatarIcon
                        }
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer, overrideImage: overrideImage)
                    }
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: avatarOriginY), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.avatarNode.frame = avatarFrame
                    strongSelf.updatingAvatarOverlay.frame = avatarFrame
                    
                    let nameY: CGFloat
                    if statusText.isEmpty {
                        nameY = floor((layout.contentSize.height - nameNodeLayout.size.height) / 2.0)
                    } else {
                        nameY = floor((layout.contentSize.height - nameNodeLayout.size.height - 3.0 - statusNodeLayout.size.height) / 2.0)
                    }
                    let nameFrame = CGRect(origin: CGPoint(x: params.leftInset + 94.0, y: nameY), size: nameNodeLayout.size)
                    strongSelf.nameNode.frame = nameFrame
                    
                    if let verificationIconImage = verificationIconImage {
                        if strongSelf.verificationIconNode == nil {
                            let verificationIconNode = ASImageNode()
                            verificationIconNode.isLayerBacked = true
                            verificationIconNode.displayWithoutProcessing = true
                            verificationIconNode.displaysAsynchronously = false
                            verificationIconNode.alpha = strongSelf.nameNode.alpha
                            strongSelf.verificationIconNode = verificationIconNode
                            strongSelf.addSubnode(verificationIconNode)
                        }
                        strongSelf.verificationIconNode?.image = verificationIconImage
                        strongSelf.verificationIconNode?.frame = CGRect(origin: CGPoint(x: nameFrame.maxX + 3.0, y: nameFrame.minY + 4.0 + UIScreenPixel), size: verificationIconImage.size)
                    } else if let verificationIconNode = strongSelf.verificationIconNode {
                        strongSelf.verificationIconNode = nil
                        verificationIconNode.removeFromSupernode()
                    }
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 94.0, y: nameFrame.maxY + 3.0), size: statusNodeLayout.size)
                    
                    if let editingName = item.state.editingName {
                        var animateIn = false
                        if strongSelf.inputSeparator == nil {
                            animateIn = true
                        }
                        switch editingName {
                            case let .personName(firstName, lastName):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.backgroundColor = itemSeparatorColor
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.font = Font.regular(17.0)
                                    inputFirstField.textColor = item.theme.list.itemPrimaryTextColor
                                    inputFirstField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
                                    inputFirstField.autocorrectionType = .no
                                    inputFirstField.attributedPlaceholder = NSAttributedString(string: item.strings.UserInfo_FirstNamePlaceholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
                                    inputFirstField.attributedText = NSAttributedString(string: firstName, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != firstName {
                                    strongSelf.inputFirstField?.text = firstName
                                }
                                
                                if strongSelf.inputSecondField == nil {
                                    let inputSecondField = TextFieldNodeView()
                                    inputSecondField.font = Font.regular(17.0)
                                    inputSecondField.textColor = item.theme.list.itemPrimaryTextColor
                                    inputSecondField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
                                    inputSecondField.autocorrectionType = .no
                                    inputSecondField.attributedPlaceholder = NSAttributedString(string: item.strings.UserInfo_LastNamePlaceholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
                                    inputSecondField.attributedText = NSAttributedString(string: lastName, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputSecondField = inputSecondField
                                    strongSelf.view.addSubview(inputSecondField)
                                    inputSecondField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputSecondField?.text != lastName {
                                    strongSelf.inputSecondField?.text = lastName
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: params.leftInset + 100.0, y: 46.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 111.0, y: 12.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 111.0 - 8.0, height: 30.0))
                                strongSelf.inputSecondField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 111.0, y: 52.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 111.0 - 8.0, height: 30.0))
                                
                                if animated && animateIn {
                                    strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputSecondField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                }
                            case let .title(title, type):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.backgroundColor = itemSeparatorColor
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.font = Font.regular(17.0)
                                    inputFirstField.textColor = item.theme.list.itemPrimaryTextColor
                                    inputFirstField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
                                    inputFirstField.autocorrectionType = .no
                                    let placeholder: String
                                    switch type {
                                        case .group:
                                            placeholder = item.strings.GroupInfo_GroupNamePlaceholder
                                        case .channel:
                                            placeholder = item.strings.GroupInfo_ChannelListNamePlaceholder
                                    }
                                    inputFirstField.attributedPlaceholder = NSAttributedString(string: placeholder, font: Font.regular(19.0), textColor: item.theme.list.itemPlaceholderTextColor)
                                    inputFirstField.attributedText = NSAttributedString(string: title, font: Font.regular(19.0), textColor: item.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != title {
                                    strongSelf.inputFirstField?.text = title
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: params.leftInset + 100.0, y: 62.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 102.0, y: 26.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 102.0 - 8.0, height: 35.0))
                                
                                if animated && animateIn {
                                    strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                }
                        }
                        
                        if animated && animateIn {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 0.0
                            strongSelf.callButton.layer.animateAlpha(from: CGFloat(strongSelf.callButton.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.callButton.alpha = 0.0
                            if let verificationIconNode = strongSelf.verificationIconNode {
                                verificationIconNode.layer.animateAlpha(from: CGFloat(verificationIconNode.layer.opacity), to: 0.0, duration: 0.3)
                                verificationIconNode.alpha = 0.0
                            }
                        } else {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.alpha = 0.0
                            strongSelf.callButton.alpha = 0.0
                            strongSelf.verificationIconNode?.alpha = 0.0
                        }
                    } else {
                        var animateOut = false
                        if let inputSeparator = strongSelf.inputSeparator {
                            animateOut = true
                            strongSelf.inputSeparator = nil
                            
                            if animated {
                                inputSeparator.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSeparator] _ in
                                    inputSeparator?.removeFromSupernode()
                                })
                            } else {
                                inputSeparator.removeFromSupernode()
                            }
                        }
                        if let inputFirstField = strongSelf.inputFirstField {
                            strongSelf.inputFirstField = nil
                            if animated {
                                inputFirstField.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputFirstField] _ in
                                    inputFirstField?.removeFromSuperview()
                                })
                            } else {
                                inputFirstField.removeFromSuperview()
                            }
                        }
                        if let inputSecondField = strongSelf.inputSecondField {
                            strongSelf.inputSecondField = nil
                            if animated {
                                inputSecondField.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSecondField] _ in
                                    inputSecondField?.removeFromSuperview()
                                })
                            } else {
                                inputSecondField.removeFromSuperview()
                            }
                        }
                        if animated && animateOut {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 1.0
                            
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 1.0
                            
                            strongSelf.callButton.layer.animateAlpha(from: CGFloat(strongSelf.callButton.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.callButton.alpha = 1.0
                            
                            if let verificationIconNode = strongSelf.verificationIconNode {
                                verificationIconNode.layer.animateAlpha(from: CGFloat(verificationIconNode.layer.opacity), to: 1.0, duration: 0.3)
                                verificationIconNode.alpha = 1.0
                            }
                        } else {
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.alpha = 1.0
                            strongSelf.callButton.alpha = 1.0
                            strongSelf.verificationIconNode?.alpha = 1.0
                        }
                    }
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.updateAvatarHidden()
                    
                    if let updatedArrowImage = updatedArrowImage {
                        strongSelf.arrowNode.image = updatedArrowImage
                    }
                    
                    if case .settings = item.mode, let arrowImage = strongSelf.arrowNode.image {
                        if strongSelf.arrowNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.arrowNode)
                        }
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 15.0 - arrowImage.size.width, y: floor((layout.contentSize.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                    } else if strongSelf.arrowNode.supernode != nil {
                        strongSelf.arrowNode.removeFromSupernode()
                    }
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
    
    @objc func textFieldDidChange(_ inputField: UITextField) {
        if let item = self.item, let currentEditingName = item.state.editingName {
            var editingName: ItemListAvatarAndNameInfoItemName?
            if let inputFirstField = self.inputFirstField, let inputSecondField = self.inputSecondField {
                editingName = .personName(firstName: inputFirstField.text ?? "", lastName: inputSecondField.text ?? "")
            } else if let inputFirstField = self.inputFirstField {
                if case let .title(_, type) = currentEditingName {
                    editingName = .title(title: inputFirstField.text ?? "", type: type)
                }
            }
            if let editingName = editingName {
                item.editingNameUpdated(editingName)
            }
        }
    }
    
    @objc func avatarTapGesture(_ recognizer: UITapGestureRecognizer) {
        if let item = self.item {
            item.avatarTapped()
        }
    }
    
    func avatarTransitionNode() -> ((ASDisplayNode, () -> UIView?), CGRect) {
        let avatarNode = self.avatarNode
        return ((self.avatarNode, { [weak avatarNode] in
            return avatarNode?.view.snapshotContentTree(unhide: true)
        }), self.avatarNode.bounds)
    }
    
    func updateAvatarHidden() {
        var hidden = false
        if let item = self.item, let context = item.context, let peer = item.peer, let hiddenAvatarRepresentation = context.hiddenAvatarRepresentation {
            if peer.profileImageRepresentations.contains(hiddenAvatarRepresentation) {
                hidden = true
            }
        }
        if hidden != self.avatarNode.isHidden {
            self.avatarNode.isHidden = hidden
        }
    }
    
    @objc func callButtonPressed() {
        self.item?.call?()
    }
    
    func focus() {
        self.inputFirstField?.becomeFirstResponder()
    }
    
    override func longTapped() {
        self.item?.longTapAction?()
    }
    
    override var canBeLongTapped: Bool {
        return self.item?.longTapAction != nil
    }
}
