import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ActivityIndicator
import AvatarNode
import TelegramStringFormatting
import PeerPresenceStatusManager
import AppBundle
import PhoneNumberFormat
import AccountContext

private let updatingAvatarOverlayImage = generateFilledCircleImage(diameter: 66.0, color: UIColor(white: 0.0, alpha: 0.4), backgroundColor: nil)

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

public enum ItemListAvatarAndNameInfoItemTitleType {
    case group
    case channel
}

public enum ItemListAvatarAndNameInfoItemName: Equatable {
    case personName(firstName: String, lastName: String, phone: String)
    case title(title: String, type: ItemListAvatarAndNameInfoItemTitleType)
    
    public init(_ peer: EnginePeer) {
        switch peer.indexName {
        case let .personName(first, last, _, phone):
            self = .personName(firstName: first, lastName: last, phone: phone ?? "")
        case let .title(title, _):
            let type: ItemListAvatarAndNameInfoItemTitleType
            if case let .channel(peer) = peer, case .broadcast = peer.info {
                type = .channel
            } else {
                type = .group
            }
            self = .title(title: title, type: type)
        }
    }
    
    public var composedTitle: String {
        switch self {
        case let .personName(firstName, lastName, _):
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
    
    public func composedDisplayTitle(strings: PresentationStrings) -> String {
        switch self {
        case let .personName(firstName, lastName, phone):
            if !firstName.isEmpty {
                if !lastName.isEmpty {
                    return "\(firstName) \(lastName)"
                } else {
                    return firstName
                }
            } else if !lastName.isEmpty {
                return lastName
            } else if !phone.isEmpty {
                return formatPhoneNumber("+\(phone)")
            } else {
                return strings.User_DeletedAccount
            }
        case let .title(title, _):
            return title
        }
    }
    
    public var isEmpty: Bool {
        switch self {
        case let .personName(firstName, lastName, phone):
            return firstName.isEmpty && lastName.isEmpty && phone.isEmpty
        case let .title(title, _):
            return title.isEmpty
        }
    }
}

public struct ItemListAvatarAndNameInfoItemState: Equatable {
    public var editingName: ItemListAvatarAndNameInfoItemName?
    public var updatingName: ItemListAvatarAndNameInfoItemName?
    
    public init(editingName: ItemListAvatarAndNameInfoItemName? = nil, updatingName: ItemListAvatarAndNameInfoItemName? = nil) {
        self.editingName = editingName
        self.updatingName = updatingName
    }
}

public final class ItemListAvatarAndNameInfoItemContext {
    public var hiddenAvatarRepresentation: TelegramMediaImageRepresentation?
    
    public init(hiddenAvatarRepresentation: TelegramMediaImageRepresentation? = nil) {
        self.hiddenAvatarRepresentation = hiddenAvatarRepresentation
    }
}

public enum ItemListAvatarAndNameInfoItemStyle {
    case plain
    case blocks(withTopInset: Bool, withExtendedBottomInset: Bool)
}

public enum ItemListAvatarAndNameInfoItemUpdatingAvatar: Equatable {
    case image(TelegramMediaImageRepresentation, Bool)
    case none
}

public enum ItemListAvatarAndNameInfoItemMode {
    case generic
    case contact
    case settings
    case editSettings
}

public class ItemListAvatarAndNameInfoItem: ListViewItem, ItemListItem {
    let accountContext: AccountContext
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let mode: ItemListAvatarAndNameInfoItemMode
    let peer: EnginePeer?
    let presence: EnginePeer.Presence?
    let label: String?
    let memberCount: Int?
    let state: ItemListAvatarAndNameInfoItemState
    public let sectionId: ItemListSectionId
    let style: ItemListAvatarAndNameInfoItemStyle
    let editingNameUpdated: (ItemListAvatarAndNameInfoItemName) -> Void
    let editingNameCompleted: () -> Void
    let avatarTapped: () -> Void
    let context: ItemListAvatarAndNameInfoItemContext?
    let updatingImage: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let call: (() -> Void)?
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    public let tag: ItemListItemTag?
    
    public let selectable: Bool

    public init(accountContext: AccountContext, presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, mode: ItemListAvatarAndNameInfoItemMode, peer: EnginePeer?, presence: EnginePeer.Presence?, label: String? = nil, memberCount: Int?, state: ItemListAvatarAndNameInfoItemState, sectionId: ItemListSectionId, style: ItemListAvatarAndNameInfoItemStyle, editingNameUpdated: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, editingNameCompleted: @escaping () -> Void = {}, avatarTapped: @escaping () -> Void, context: ItemListAvatarAndNameInfoItemContext? = nil, updatingImage: ItemListAvatarAndNameInfoItemUpdatingAvatar? = nil, call: (() -> Void)? = nil, action: (() -> Void)? = nil, longTapAction: (() -> Void)? = nil, tag: ItemListItemTag? = nil) {
        self.accountContext = accountContext
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.mode = mode
        self.peer = peer
        self.presence = presence
        self.label = label
        self.memberCount = memberCount
        self.state = state
        self.sectionId = sectionId
        self.style = style
        self.editingNameUpdated = editingNameUpdated
        self.editingNameCompleted = editingNameCompleted
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
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListAvatarAndNameInfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { _ in apply(false, synchronousLoads) })
            })
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
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
                        completion(layout, { _ in
                            apply(animated, false)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let avatarFont = avatarPlaceholderFont(size: 28.0)

public class ItemListAvatarAndNameInfoItemNode: ListViewItemNode, ItemListItemNode, ItemListItemFocusableNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let avatarNode: AvatarNode
    private let updatingAvatarOverlay: ASImageNode
    private let activityIndicator: ActivityIndicator
    
    private let callButton: HighlightableButtonNode
    
    private let nameNode: TextNode
    private var credibilityIconNode: ASImageNode?
    private let statusNode: TextNode
    
    private let arrowNode: ASImageNode
    
    private var inputSeparator: ASDisplayNode?
    private var inputFirstField: UITextField?
    private var inputSecondField: UITextField?
    
    private var inputFirstClearButton: HighlightableButtonNode?
    private var inputSecondClearButton: HighlightableButtonNode?
    
    private var item: ItemListAvatarAndNameInfoItem?
    private var layoutWidthAndNeighbors: (width: ListViewItemLayoutParams, neighbors: ItemListNeighbors)?
    private var peerPresenceManager: PeerPresenceStatusManager?
    
    private let hiddenAvatarRepresentationDisposable = MetaDisposable()
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public var callButtonFrame: CGRect? {
        if !self.callButton.alpha.isZero && self.callButton.supernode != nil {
            return self.callButton.frame
        } else {
            return nil
        }
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.updatingAvatarOverlay = ASImageNode()
        self.updatingAvatarOverlay.isUserInteractionEnabled = false
        self.updatingAvatarOverlay.displayWithoutProcessing = true
        self.updatingAvatarOverlay.displaysAsynchronously = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(.white, 22.0, 1.0, false))
        self.activityIndicator.isHidden = true
        self.activityIndicator.isUserInteractionEnabled = false
        
        self.nameNode = TextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.contentMode = .left
        self.nameNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        
        self.callButton = HighlightableButtonNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.activityIndicator)
        
        self.addSubnode(self.nameNode)
        self.addSubnode(self.statusNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let item = strongSelf.item, let layoutWidthAndNeighbors = strongSelf.layoutWidthAndNeighbors {
                let (_, apply) = strongSelf.asyncLayout()(item, layoutWidthAndNeighbors.0, layoutWidthAndNeighbors.1)
                apply(true, false)
            }
        })
        
        self.callButton.addTarget(self, action: #selector(callButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.hiddenAvatarRepresentationDisposable.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.avatarTapGesture(_:))))
    }
    
    public func asyncLayout() -> (_ item: ItemListAvatarAndNameInfoItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        let currentOverlayImage = self.updatingAvatarOverlay.image
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let nameFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 19.0 / 17.0))
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.accountContext.currentAppConfiguration.with { $0 })
            
            var credibilityIconImage: UIImage?
            var credibilityIconOffset: CGFloat = 4.0
            if let peer = item.peer {
                if peer.isScam {
                    credibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                    credibilityIconOffset = 6.0
                } else if peer.isFake {
                    credibilityIconImage = PresentationResourcesChatList.fakeIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                    credibilityIconOffset = 2.0
                } else if peer.isVerified {
                    credibilityIconImage = PresentationResourcesItemList.verifiedPeerIcon(item.presentationData.theme)
                } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                    credibilityIconImage = PresentationResourcesChatList.premiumIcon(item.presentationData.theme)
                }
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
            if let credibilityIconImage = credibilityIconImage {
                additionalTitleInset += 3.0 + credibilityIconImage.size.width
            }
            
            var nameMaximumNumberOfLines = 1
            if case .generic = item.mode {
                nameMaximumNumberOfLines = 2
            }
            
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayTitle.composedDisplayTitle(strings: item.presentationData.strings), font: nameFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: nameMaximumNumberOfLines, truncationType: .end, constrainedSize: CGSize(width: baseWidth - 20 - 94.0 - (item.call != nil ? 36.0 : 0.0) - additionalTitleInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var statusText: String = ""
            let statusColor: UIColor
            if case let .user(peer) = item.peer {
                let servicePeer = isServicePeer(peer)
                switch item.mode {
                    case .settings:
                        if let phone = peer.phone, !phone.isEmpty {
                            statusText += formatPhoneNumber(phone)
                        }
                        if let username = peer.addressName, !username.isEmpty {
                            if !statusText.isEmpty {
                                statusText += "\n"
                            }
                            statusText += "@\(username)"
                        }
                        statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                    case .generic, .contact, .editSettings:
                        if let label = item.label {
                            statusText = label
                            statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                        } else if peer.flags.contains(.isSupport), !servicePeer {
                            statusText = item.presentationData.strings.Bot_GenericSupportStatus
                            statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                        } else if peer.id.isReplies {
                            statusText = ""
                            statusColor = item.presentationData.theme.list.itemPrimaryTextColor
                        } else if let _ = peer.botInfo {
                            statusText = item.presentationData.strings.Bot_GenericBotStatus
                            statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                        } else if case .generic = item.mode, !servicePeer, let presence = item.presence {
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp), expanded: true)
                            statusText = string
                            if activity {
                                statusColor = item.presentationData.theme.list.itemAccentColor
                            } else {
                                statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                            }
                        } else {
                            statusText = ""
                            statusColor = item.presentationData.theme.list.itemPrimaryTextColor
                        }
                }
            } else if case let .channel(channel) = item.peer {
                if let memberCount = item.memberCount {
                    if case .group = channel.info {
                        if memberCount == 0 {
                            statusText = item.presentationData.strings.Group_Status
                        } else {
                            statusText = item.presentationData.strings.Conversation_StatusMembers(Int32(memberCount))
                        }
                    } else {
                        if memberCount == 0 {
                            statusText = item.presentationData.strings.Channel_Status
                        } else {
                            statusText = item.presentationData.strings.Conversation_StatusSubscribers(Int32(memberCount))
                        }
                    }
                    statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                } else {
                    switch channel.info {
                        case .broadcast:
                            statusText = item.presentationData.strings.Channel_Status
                            statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                        case .group:
                            statusText = item.presentationData.strings.Group_Status
                            statusColor = item.presentationData.theme.list.itemSecondaryTextColor
                    }
                }
            } else if case let .legacyGroup(group) = item.peer {
                statusText = item.presentationData.strings.GroupInfo_ParticipantCount(Int32(group.participantCount))
                statusColor = item.presentationData.theme.list.itemSecondaryTextColor
            } else {
                statusText = ""
                statusColor = item.presentationData.theme.list.itemPrimaryTextColor
            }
            
            var availableStatusWidth = baseWidth - 20
            if item.call != nil {
                availableStatusWidth -= 44.0
            }
            
            let (statusNodeLayout, statusNodeApply) = layoutStatusNode(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: availableStatusWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let nameSpacing: CGFloat = 3.0
            
            let hasCorners = itemListHasRoundedBlockLayout(params)
            let contentSize: CGSize
            var insets: UIEdgeInsets
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
            case .plain:
                let verticalInset: CGFloat = 15.0
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                let baseHeight = nameNodeLayout.size.height + nameSpacing + statusNodeLayout.size.height + 40.0
                contentSize = CGSize(width: params.width, height: max(baseHeight, verticalInset * 2.0 + 66.0))
                insets = itemListNeighborsPlainInsets(neighbors)
            case let .blocks(withTopInset, withExtendedBottomInset):
                let verticalInset: CGFloat = 13.0
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                let baseHeight = nameNodeLayout.size.height + nameSpacing + statusNodeLayout.size.height + 30.0
                contentSize = CGSize(width: params.width, height: max(baseHeight, verticalInset * 2.0 + 66.0))
                if withTopInset || hasCorners {
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
                } else {
                    let topInset: CGFloat
                    switch neighbors.top {
                        case .sameSection, .none:
                            topInset = 0.0
                        case .otherSection:
                            topInset = separatorHeight + 35.0
                    }
                    insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: separatorHeight, right: 0.0)
                    if withExtendedBottomInset {
                        insets.bottom += 12.0
                    }
                }
            }
            
            var updateAvatarOverlayImage: UIImage?
            if item.updatingImage != nil && item.peer?.id.namespace != .max && currentOverlayImage == nil {
                updateAvatarOverlayImage = updatingAvatarOverlayImage
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated, synchronousLoads in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.accessibilityLabel = displayTitle.composedTitle
                    
                    strongSelf.layoutWidthAndNeighbors = (params, neighbors)
                    
                    var updatedArrowImage: UIImage?
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.inputSeparator?.backgroundColor = itemSeparatorColor
                        strongSelf.callButton.setImage(PresentationResourcesChat.chatInfoCallButtonImage(item.presentationData.theme), for: [])
                        
                        strongSelf.inputFirstClearButton?.setImage(generateClearIcon(color: item.presentationData.theme.list.inputClearButtonColor), for: [])
                        strongSelf.inputSecondClearButton?.setImage(generateClearIcon(color: item.presentationData.theme.list.inputClearButtonColor), for: [])
                        
                        updatedArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                    }
                    
                    if item.updatingImage != nil {
                        if let updateAvatarOverlayImage = updateAvatarOverlayImage {
                            strongSelf.updatingAvatarOverlay.image = updateAvatarOverlayImage
                        }
                        strongSelf.updatingAvatarOverlay.alpha = 1.0
                        if strongSelf.updatingAvatarOverlay.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.updatingAvatarOverlay, aboveSubnode: strongSelf.avatarNode)
                        }
                        if let updatingImage = item.updatingImage, case let .image(_, loading) = updatingImage {
                            strongSelf.activityIndicator.isHidden = !loading
                        }
                    } else if strongSelf.updatingAvatarOverlay.supernode != nil {
                        if animated {
                            strongSelf.updatingAvatarOverlay.alpha = 0.0
                            strongSelf.updatingAvatarOverlay.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, completion: { value in
                                if value {
                                    self?.updatingAvatarOverlay.removeFromSupernode()
                                }
                            })
                        } else {
                            strongSelf.updatingAvatarOverlay.removeFromSupernode()
                        }
                        strongSelf.activityIndicator.isHidden = true
                    }
                    
                    if item.call != nil {
                        if strongSelf.callButton.supernode == nil {
                            strongSelf.addSubnode(strongSelf.callButton)
                        }
                        
                        strongSelf.callButton.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 44.0 - 10.0, y: floor((contentSize.height - 44.0) / 2.0) - 2.0), size: CGSize(width: 44.0, height: 44.0))
                    } else if strongSelf.callButton.supernode != nil {
                        strongSelf.callButton.removeFromSupernode()
                    }
                    
                    switch item.style {
                        case .plain:
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.bottomStripeNode.removeFromSupernode()
                            }
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                        }
                        case .blocks:
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            if strongSelf.maskNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                            }
                            
                            var hasTopCorners = false
                            var hasBottomCorners = false
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    hasTopCorners = true
                                    strongSelf.topStripeNode.isHidden = hasCorners
                            }
                            
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = params.leftInset + 16.0
                                    strongSelf.bottomStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                            }
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: layoutSize.height - insets.top - insets.bottom), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let _ = nameNodeApply()
                    let _ = statusNodeApply()
                    
                    var ignoreEmpty = false
                    if case .editSettings = item.mode {
                        ignoreEmpty = true
                    }
                    if let peer = item.peer {
                        var overrideImage: AvatarNodeImageOverride?
                        if let updatingImage = item.updatingImage {
                            switch updatingImage {
                                case .none:
                                    overrideImage = AvatarNodeImageOverride.none
                                case let .image(representation, _):
                                    overrideImage = .image(representation)
                            }
                        } else if case .editSettings = item.mode {
                            overrideImage = AvatarNodeImageOverride.editAvatarIcon(forceNone: false)
                        } else if peer.isDeleted {
                            overrideImage = .deletedIcon
                        }
                        
                        strongSelf.avatarNode.setPeer(context: item.accountContext, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: ignoreEmpty ? nil : item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
                    }
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floor((layout.contentSize.height - 66.0) / 2.0)), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.avatarNode.frame = avatarFrame
                    strongSelf.updatingAvatarOverlay.frame = avatarFrame
                    
                    let indicatorSize = strongSelf.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
                    strongSelf.activityIndicator.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(avatarFrame.midX - indicatorSize.width / 2.0), y: floorToScreenPixels(avatarFrame.midY - indicatorSize.height / 2.0)), size: indicatorSize)
                    
                    let nameY: CGFloat
                    if statusText.isEmpty {
                        nameY = floor((layout.contentSize.height - nameNodeLayout.size.height) / 2.0)
                    } else {
                        nameY = floor((layout.contentSize.height - nameNodeLayout.size.height - 3.0 - statusNodeLayout.size.height) / 2.0)
                    }
                    let nameFrame = CGRect(origin: CGPoint(x: params.leftInset + 94.0, y: nameY), size: nameNodeLayout.size)
                    strongSelf.nameNode.frame = nameFrame
                    
                    if let credibilityIconImage = credibilityIconImage {
                        if strongSelf.credibilityIconNode == nil {
                            let credibilityIconNode = ASImageNode()
                            credibilityIconNode.isLayerBacked = true
                            credibilityIconNode.displayWithoutProcessing = true
                            credibilityIconNode.displaysAsynchronously = false
                            credibilityIconNode.alpha = strongSelf.nameNode.alpha
                            strongSelf.credibilityIconNode = credibilityIconNode
                            strongSelf.addSubnode(credibilityIconNode)
                        }
                        strongSelf.credibilityIconNode?.image = credibilityIconImage
                        strongSelf.credibilityIconNode?.frame = CGRect(origin: CGPoint(x: nameFrame.maxX + credibilityIconOffset, y: nameFrame.minY + 4.0 + UIScreenPixel), size: credibilityIconImage.size)
                    } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                        strongSelf.credibilityIconNode = nil
                        credibilityIconNode.removeFromSupernode()
                    }
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 94.0, y: nameFrame.maxY + 3.0), size: statusNodeLayout.size)
                    
                    if let editingName = item.state.editingName {
                        var animateIn = false
                        if strongSelf.inputSeparator == nil {
                            animateIn = true
                        }
                        let keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
                        switch editingName {
                            case let .personName(firstName, lastName, _):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                strongSelf.inputSeparator?.backgroundColor = itemSeparatorColor
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.delegate = self
                                    inputFirstField.font = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
                                    inputFirstField.autocorrectionType = .no
                                    inputFirstField.returnKeyType = .next
                                    inputFirstField.attributedText = NSAttributedString(string: firstName, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != firstName {
                                    strongSelf.inputFirstField?.text = firstName
                                }
                                
                                strongSelf.inputFirstField?.textColor = item.presentationData.theme.list.itemPrimaryTextColor
                                strongSelf.inputFirstField?.attributedPlaceholder = NSAttributedString(string: item.presentationData.strings.UserInfo_FirstNamePlaceholder, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
                                if strongSelf.inputFirstField?.keyboardAppearance != keyboardAppearance {
                                    strongSelf.inputFirstField?.keyboardAppearance = keyboardAppearance
                                }
                                
                                if strongSelf.inputFirstClearButton == nil {
                                    strongSelf.inputFirstClearButton = HighlightableButtonNode()
                                    strongSelf.inputFirstClearButton?.imageNode.displaysAsynchronously = false
                                    strongSelf.inputFirstClearButton?.imageNode.displayWithoutProcessing = true
                                    strongSelf.inputFirstClearButton?.displaysAsynchronously = false
                                    strongSelf.inputFirstClearButton?.setImage(generateClearIcon(color: item.presentationData.theme.list.inputClearButtonColor), for: [])
                                    strongSelf.inputFirstClearButton?.addTarget(strongSelf, action: #selector(strongSelf.firstClearPressed), forControlEvents: .touchUpInside)
                                    strongSelf.inputFirstClearButton?.isHidden = true
                                    strongSelf.addSubnode(strongSelf.inputFirstClearButton!)
                                }
                                
                                if strongSelf.inputSecondField == nil {
                                    let inputSecondField = TextFieldNodeView()
                                    inputSecondField.delegate = self
                                    inputSecondField.font = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
                                    inputSecondField.autocorrectionType = .no
                                    inputSecondField.returnKeyType = .done
                                    inputSecondField.attributedText = NSAttributedString(string: lastName, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputSecondField = inputSecondField
                                    strongSelf.view.addSubview(inputSecondField)
                                    inputSecondField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputSecondField?.text != lastName {
                                    strongSelf.inputSecondField?.text = lastName
                                }
                                
                                strongSelf.inputSecondField?.textColor = item.presentationData.theme.list.itemPrimaryTextColor
                                strongSelf.inputSecondField?.attributedPlaceholder = NSAttributedString(string: item.presentationData.strings.UserInfo_LastNamePlaceholder, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
                                if strongSelf.inputSecondField?.keyboardAppearance != keyboardAppearance {
                                    strongSelf.inputSecondField?.keyboardAppearance = keyboardAppearance
                                }
                                
                                if strongSelf.inputSecondClearButton == nil {
                                    strongSelf.inputSecondClearButton = HighlightableButtonNode()
                                    strongSelf.inputSecondClearButton?.imageNode.displaysAsynchronously = false
                                    strongSelf.inputSecondClearButton?.imageNode.displayWithoutProcessing = true
                                    strongSelf.inputSecondClearButton?.displaysAsynchronously = false
                                    strongSelf.inputSecondClearButton?.setImage(generateClearIcon(color: item.presentationData.theme.list.inputClearButtonColor), for: [])
                                    strongSelf.inputSecondClearButton?.addTarget(strongSelf, action: #selector(strongSelf.secondClearPressed), forControlEvents: .touchUpInside)
                                    strongSelf.inputSecondClearButton?.isHidden = true
                                    strongSelf.addSubnode(strongSelf.inputSecondClearButton!)
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: params.leftInset + 100.0, y: 46.0), size: CGSize(width: params.width - params.leftInset - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 111.0, y: 12.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 111.0 - 36.0, height: 30.0))
                                strongSelf.inputSecondField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 111.0, y: 52.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 111.0 - 36.0, height: 30.0))
                                
                                if let image = strongSelf.inputFirstClearButton?.image(for: []), let inputFieldFrame = strongSelf.inputFirstField?.frame {
                                    strongSelf.inputFirstClearButton?.frame = CGRect(origin: CGPoint(x: inputFieldFrame.maxX, y: inputFieldFrame.minY + floor((inputFieldFrame.size.height - image.size.height) / 2.0) - 1.0 + UIScreenPixel), size: image.size)
                                }
                                if let image = strongSelf.inputSecondClearButton?.image(for: []), let inputFieldFrame = strongSelf.inputSecondField?.frame {
                                    strongSelf.inputSecondClearButton?.frame = CGRect(origin: CGPoint(x: inputFieldFrame.maxX, y: inputFieldFrame.minY + floor((inputFieldFrame.size.height - image.size.height) / 2.0) - 1.0 + UIScreenPixel), size: image.size)
                                }
                                
                                if animated && animateIn {
                                    strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputSecondField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                }
                            case let .title(title, type):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                strongSelf.inputSeparator?.backgroundColor = .clear
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.returnKeyType = .done
                                    inputFirstField.delegate = self
                                    inputFirstField.font = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 19.0 / 17.0))
                                    inputFirstField.autocorrectionType = .no
                                    inputFirstField.attributedText = NSAttributedString(string: title, font: Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 19.0 / 17.0)), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != title {
                                    strongSelf.inputFirstField?.text = title
                                }
                                strongSelf.inputFirstField?.textColor = item.presentationData.theme.list.itemPrimaryTextColor
                                let placeholder: String
                                switch type {
                                    case .group:
                                        placeholder = item.presentationData.strings.GroupInfo_GroupNamePlaceholder
                                    case .channel:
                                        placeholder = item.presentationData.strings.GroupInfo_ChannelListNamePlaceholder
                                }
                                strongSelf.inputFirstField?.attributedPlaceholder = NSAttributedString(string: placeholder, font: Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 19.0 / 17.0)), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
                                if strongSelf.inputFirstField?.keyboardAppearance != keyboardAppearance {
                                    strongSelf.inputFirstField?.keyboardAppearance = keyboardAppearance
                                }
                                
                                if strongSelf.inputFirstClearButton == nil {
                                    strongSelf.inputFirstClearButton = HighlightableButtonNode()
                                    strongSelf.inputFirstClearButton?.imageNode.displaysAsynchronously = false
                                    strongSelf.inputFirstClearButton?.imageNode.displayWithoutProcessing = true
                                    strongSelf.inputFirstClearButton?.displaysAsynchronously = false
                                    strongSelf.inputFirstClearButton?.setImage(generateClearIcon(color: item.presentationData.theme.list.inputClearButtonColor), for: [])
                                    strongSelf.inputFirstClearButton?.addTarget(strongSelf, action: #selector(strongSelf.firstClearPressed), forControlEvents: .touchUpInside)
                                    strongSelf.inputFirstClearButton?.isHidden = true
                                    strongSelf.addSubnode(strongSelf.inputFirstClearButton!)
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: params.leftInset + 100.0, y: 64.0), size: CGSize(width: params.width - params.leftInset - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: params.leftInset + 111.0, y: 28.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 111.0 - 36.0, height: 35.0))
                                
                                if let image = strongSelf.inputFirstClearButton?.image(for: []), let inputFieldFrame = strongSelf.inputFirstField?.frame {
                                    strongSelf.inputFirstClearButton?.frame = CGRect(origin: CGPoint(x: inputFieldFrame.maxX, y: inputFieldFrame.minY + floor((inputFieldFrame.size.height - image.size.height) / 2.0) - 1.0 + UIScreenPixel), size: image.size)
                                }
                                
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
                            if let credibilityIconNode = strongSelf.credibilityIconNode {
                                credibilityIconNode.layer.animateAlpha(from: CGFloat(credibilityIconNode.layer.opacity), to: 0.0, duration: 0.3)
                                credibilityIconNode.alpha = 0.0
                            }
                        } else {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.alpha = 0.0
                            strongSelf.callButton.alpha = 0.0
                            strongSelf.credibilityIconNode?.alpha = 0.0
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
                            
                            if let inputFirstClearButton = strongSelf.inputFirstClearButton {
                                strongSelf.inputFirstClearButton = nil
                                if animated {
                                    inputFirstClearButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputFirstClearButton] _ in
                                        inputFirstClearButton?.removeFromSupernode()
                                    })
                                } else {
                                    inputFirstClearButton.removeFromSupernode()
                                }
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
                            
                            if let inputSecondClearButton = strongSelf.inputSecondClearButton {
                                strongSelf.inputSecondClearButton = nil
                                if animated {
                                    inputSecondClearButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSecondClearButton] _ in
                                        inputSecondClearButton?.removeFromSupernode()
                                    })
                                } else {
                                    inputSecondClearButton.removeFromSupernode()
                                }
                            }
                        }
                        if animated && animateOut {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 1.0
                            
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 1.0
                            
                            strongSelf.callButton.layer.animateAlpha(from: CGFloat(strongSelf.callButton.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.callButton.alpha = 1.0
                            
                            if let credibilityIconNode = strongSelf.credibilityIconNode {
                                credibilityIconNode.layer.animateAlpha(from: CGFloat(credibilityIconNode.layer.opacity), to: 1.0, duration: 0.3)
                                credibilityIconNode.alpha = 1.0
                            }
                        } else {
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.alpha = 1.0
                            strongSelf.callButton.alpha = 1.0
                            strongSelf.credibilityIconNode?.alpha = 1.0
                        }
                    }
                    if let presence = item.presence {
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
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 7.0 - arrowImage.size.width, y: floor((layout.contentSize.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                    } else if strongSelf.arrowNode.supernode != nil {
                        strongSelf.arrowNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
    
    private func updateClearButtonVisibility(_ button: HighlightableButtonNode?, textField: UITextField?) {
        guard let button = button, let textField = textField else {
            return
        }
        button.isHidden = !textField.isFirstResponder || (textField.text?.isEmpty ?? true)
    }
    
    @objc private func textFieldDidChange(_ inputField: UITextField) {
        if let item = self.item, let currentEditingName = item.state.editingName {
            var editingName: ItemListAvatarAndNameInfoItemName?
            if let inputFirstField = self.inputFirstField, let inputSecondField = self.inputSecondField {
                editingName = .personName(firstName: inputFirstField.text ?? "", lastName: inputSecondField.text ?? "", phone: "")
            } else if let inputFirstField = self.inputFirstField {
                if case let .title(_, type) = currentEditingName {
                    editingName = .title(title: inputFirstField.text ?? "", type: type)
                }
            }
            if let editingName = editingName {
                item.editingNameUpdated(editingName)
            }
        }
        
        if inputField == self.inputFirstField {
            self.updateClearButtonVisibility(self.inputFirstClearButton, textField: inputField)
        } else if inputField == self.inputSecondField {
            self.updateClearButtonVisibility(self.inputSecondClearButton, textField: inputField)
        }
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == self.inputFirstField {
            self.updateClearButtonVisibility(self.inputFirstClearButton, textField: textField)
        } else if textField == self.inputSecondField {
            self.updateClearButtonVisibility(self.inputSecondClearButton, textField: textField)
        }
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.inputFirstField {
            self.updateClearButtonVisibility(self.inputFirstClearButton, textField: textField)
        } else if textField == self.inputSecondField {
            self.updateClearButtonVisibility(self.inputSecondClearButton, textField: textField)
        }
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.inputFirstField {
            if let inputSecondField = self.inputSecondField {
                inputSecondField.becomeFirstResponder()
            } else {
                self.item?.editingNameCompleted()
            }
        } else if textField == self.inputSecondField {
            self.item?.editingNameCompleted()
        }
        return true
    }
    
    @objc private func avatarTapGesture(_ recognizer: UITapGestureRecognizer) {
        if let item = self.item {
            item.avatarTapped()
        }
    }
    
    public func avatarTransitionNode() -> ((ASDisplayNode, CGRect, () -> (UIView?, UIView?)), CGRect) {
        let avatarNode = self.avatarNode
        return ((self.avatarNode, self.avatarNode.bounds, { [weak avatarNode] in
            return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
        }), self.avatarNode.bounds)
    }
    
    public func updateAvatarHidden() {
        var hidden = false
        if let item = self.item, let context = item.context, let peer = item.peer, let hiddenAvatarRepresentation = context.hiddenAvatarRepresentation {
            for representation in peer.profileImageRepresentations {
                if representation.resource.id == hiddenAvatarRepresentation.resource.id {
                    hidden = true
                }
            }
        }
        if hidden != self.avatarNode.isHidden {
            self.avatarNode.isHidden = hidden
        }
    }
    
    @objc private func callButtonPressed() {
        self.item?.call?()
    }
    
    @objc private func firstClearPressed() {
        self.inputFirstField?.text = nil
        self.updateClearButtonVisibility(self.inputFirstClearButton, textField: self.inputFirstField)
    }
    
    @objc private func secondClearPressed() {
        self.inputSecondField?.text = nil
        self.updateClearButtonVisibility(self.inputSecondClearButton, textField: self.inputSecondField)
    }
    
    public func focus() {
        self.inputFirstField?.becomeFirstResponder()
    }
    
    override public func longTapped() {
        self.item?.longTapAction?()
    }
    
    override public var canBeLongTapped: Bool {
        return self.item?.longTapAction != nil
    }
}
