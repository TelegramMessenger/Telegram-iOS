import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import AccountContext
import ChatListSearchItemHeader

private func callDurationString(strings: PresentationStrings, duration: Int32) -> String {
    if duration < 60 {
        return strings.Call_ShortSeconds(duration)
    } else {
        return strings.Call_ShortMinutes(duration / 60)
    }
}

private func callListNeighbors(item: ListViewItem, topItem: ListViewItem?, bottomItem: ListViewItem?) -> ItemListNeighbors {
    let topNeighbor: ItemListNeighbor
    if let topItem = topItem {
        if let item = item as? ItemListItem, let topItem = topItem as? ItemListItem {
            if topItem.sectionId != item.sectionId {
                topNeighbor = .otherSection(topItem.requestsNoInset ? .none : .full)
            } else {
                topNeighbor = .sameSection(alwaysPlain: topItem.isAlwaysPlain)
            }
        } else {
            if item is CallListCallItem && topItem is CallListCallItem {
                topNeighbor = .sameSection(alwaysPlain: false)
            } else {
                topNeighbor = .otherSection(.full)
            }
        }
    } else {
        topNeighbor = .none
    }
    
    let bottomNeighbor: ItemListNeighbor
    if let bottomItem = bottomItem {
        if let item = item as? ItemListItem, let bottomItem = bottomItem as? ItemListItem {
            if bottomItem.sectionId != item.sectionId {
                bottomNeighbor = .otherSection(bottomItem.requestsNoInset ? .none : .full)
            } else {
                bottomNeighbor = .sameSection(alwaysPlain: bottomItem.isAlwaysPlain)
            }
        } else {
            if item is CallListCallItem && bottomItem is CallListCallItem {
                bottomNeighbor = .sameSection(alwaysPlain: false)
            } else {
                bottomNeighbor = .otherSection(.full)
            }
        }
    } else {
        bottomNeighbor = .none
    }
    
    return ItemListNeighbors(top: topNeighbor, bottom: bottomNeighbor)
}

class CallListCallItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let context: AccountContext
    let style: ItemListStyle
    let topMessage: EngineMessage
    let messages: [EngineMessage]
    let editing: Bool
    let revealed: Bool
    let interaction: CallListNodeInteraction
    
    let selectable: Bool = true
    let headerAccessoryItem: ListViewAccessoryItem?
    let header: ListViewItemHeader?
    
    init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, context: AccountContext, style: ItemListStyle, topMessage: EngineMessage, messages: [EngineMessage], editing: Bool, revealed: Bool, displayHeader: Bool, interaction: CallListNodeInteraction) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.context = context
        self.style = style
        self.topMessage = topMessage
        self.messages = messages
        self.editing = editing
        self.revealed = revealed
        self.interaction = interaction
        
        self.headerAccessoryItem = nil
        if displayHeader {
            self.header = ChatListSearchItemHeader(type: .recentCalls, theme: presentationData.theme, strings: presentationData.strings)
        } else {
            self.header = nil
        }
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CallListCallItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader, callListNeighbors(item: self, topItem: previousItem, bottomItem: nextItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        nodeApply(synchronousLoads).1(false)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? CallListCallItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, callListNeighbors(item: self, topItem: previousItem, bottomItem: nextItem))
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(false).1(animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        var isVideo = false
        for media in self.topMessage.media {
            if let action = media as? TelegramMediaAction {
                if case let .phoneCall(_, _, _, isVideoValue) = action.action {
                    isVideo = isVideoValue
                    break
                }
            }
        }
        self.interaction.call(self.topMessage.id.peerId, isVideo)
    }
    
    static func mergeType(item: CallListCallItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? CallListCallItem {
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
                if let nextItem = nextItem as? CallListCallItem {
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

class CallListCallItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private var credibilityIconNode: ASImageNode?
    private let statusNode: TextNode
    private let dateNode: TextNode
    private let typeIconNode: ASImageNode
    private let infoButtonNode: HighlightableButtonNode
    
    var editableControlNode: ItemListEditableControlNode?
    
    private let accessibilityArea: AccessibilityAreaNode
    
    private var layoutParams: (CallListCallItem, ListViewItemLayoutParams, Bool, Bool, Bool)?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.containerNode = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        self.dateNode = TextNode()
        
        self.typeIconNode = ASImageNode()
        self.typeIconNode.isLayerBacked = true
        self.typeIconNode.displayWithoutProcessing = true
        self.typeIconNode.displaysAsynchronously = false
        
        self.infoButtonNode = HighlightableButtonNode()
        self.infoButtonNode.hitTestSlop = UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -10.0)
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.typeIconNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.dateNode)
        self.containerNode.addSubnode(self.infoButtonNode)
        self.addSubnode(self.accessibilityArea)
        
        self.infoButtonNode.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        
        self.accessibilityArea.activate = { [weak self] in
            guard let item = self?.layoutParams?.0 else {
                return false
            }
            var isVideo = false
            for media in item.topMessage.media {
                if let action = media as? TelegramMediaAction {
                    if case let .phoneCall(_, _, _, isVideoValue) = action.action {
                        isVideo = isVideoValue
                    }
                }
            }
            item.interaction.call(item.topMessage.id.peerId, isVideo)
            return true
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, params, first, last, firstWithHeader)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader, callListNeighbors(item: item, topItem: previousItem, bottomItem: nextItem))
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply(false)
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                if self.backgroundNode.supernode != nil {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.backgroundNode)
                } else {
                    self.insertSubnode(self.highlightedBackgroundNode, at: 0)
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
    
    func asyncLayout() -> (_ item: CallListCallItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> (Signal<Void, NoError>?, (Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            var updatedInfoIcon = false
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                
                updatedInfoIcon = true
            }
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let avatarDiameter = min(40.0, floor(item.presentationData.fontSize.itemListBaseFontSize * 40.0 / 17.0))
            
            let editingOffset: CGFloat
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            if item.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
            } else {
                editingOffset = 0.0
            }
            
            var leftInset: CGFloat = 46.0 + avatarDiameter + params.leftInset
            let rightInset: CGFloat = 13.0 + params.rightInset
            var infoIconRightInset: CGFloat = rightInset - 1.0
            
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            var dateRightInset: CGFloat = 46.0 + params.rightInset
            if item.editing {
                leftInset += editingOffset
                dateRightInset += 5.0
                infoIconRightInset -= 36.0
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            var statusAccessibilityString = ""
            
            var titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            var hasMissed = false
            var hasIncoming = false
            var hasOutgoing = false
            var isVideo = false
            
            var hadDuration = false
            var callDuration: Int32?
            
            for message in item.messages {
                inner: for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, duration, video) = action.action {
                            isVideo = video
                            if message.flags.contains(.Incoming) {
                                hasIncoming = true
                                
                                if let discardReason = discardReason, case .missed = discardReason {
                                    titleColor = item.presentationData.theme.list.itemDestructiveColor
                                    hasMissed = true
                                }
                            } else {
                                hasOutgoing = true
                            }
                            if callDuration == nil && !hadDuration {
                                hadDuration = true
                                callDuration = duration
                            } else {
                                callDuration = nil
                            }
                        }
                        break inner
                    }
                }
            }
            
            if let peer = item.topMessage.peers[item.topMessage.id.peerId] {
                if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                        if item.messages.count > 1 {
                            string.append(NSAttributedString(string: " (\(item.messages.count))", font: titleFont, textColor: titleColor))
                        }
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleFont, textColor: titleColor)
                    } else {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
                }
                
                if hasMissed {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallMissedShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallMissed : item.presentationData.strings.Call_VoiceOver_VoiceCallMissed
                } else if hasIncoming && hasOutgoing {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallOutgoingShort + ", " + item.presentationData.strings.Notification_CallIncomingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    statusAccessibilityString = isVideo ? (item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing + ", " + item.presentationData.strings.Call_VoiceOver_VideoCallIncoming) : (item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing + ", " + item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming)
                } else if hasIncoming {
                    if let callDuration = callDuration, callDuration != 0 {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallTimeFormat(item.presentationData.strings.Notification_CallIncomingShort, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = item.presentationData.strings.Notification_CallTimeFormat(isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallIncoming : item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string
                        
                    } else {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallIncomingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallIncoming : item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming
                    }
                } else {
                    if let callDuration = callDuration, callDuration != 0 {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallTimeFormat(item.presentationData.strings.Notification_CallOutgoingShort, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = item.presentationData.strings.Notification_CallTimeFormat(isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing : item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string
                    } else {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallOutgoingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing : item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing
                    }
                }
            }
            
            var t = Int(item.topMessage.timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.topMessage.timestamp, relativeTo: timestamp, dateTimeFormat: item.dateTimeFormat)
            
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            var currentCredibilityIconImage: UIImage?
            if let peer = item.topMessage.peers[item.topMessage.id.peerId], peer.id != item.context.account.peerId {
                if peer.isScam {
                    currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                } else if peer.isFake {
                    currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                } else if peer.isVerified {
                    currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                    currentCredibilityIconImage = PresentationResourcesChatList.premiumIcon(item.presentationData.theme)
                }
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let currentCredibilityIconImage = currentCredibilityIconImage {
                additionalTitleInset += 3.0 + currentCredibilityIconImage.size.width
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - additionalTitleInset - leftInset - dateRightInset - dateLayout.size.width - (item.editing ? -30.0 : 10.0)), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - dateRightInset - dateLayout.size.width - (item.editing ? -30.0 : 10.0)), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = -1.0
            let verticalInset: CGFloat = 6.0
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: titleLayout.size.height + titleSpacing + statusLayout.size.height + verticalInset * 2.0), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let outgoingVoiceIcon = PresentationResourcesCallList.outgoingIcon(item.presentationData.theme)
            let outgoingVideoIcon = PresentationResourcesCallList.outgoingVideoIcon(item.presentationData.theme)
            let infoIcon = PresentationResourcesCallList.infoButton(item.presentationData.theme)
            
            let outgoingIcon = isVideo ? outgoingVideoIcon : outgoingVoiceIcon
            
            let contentSize = nodeLayout.contentSize
            
            return (nodeLayout, { [weak self] synchronousLoads in
                if let strongSelf = self {
                    if let peer = item.topMessage.peers[item.topMessage.id.peerId] {
                        var overrideImage: AvatarNodeImageOverride?
                        if peer.isDeleted {
                            overrideImage = .deletedIcon
                        }
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(peer), overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
                    }
                    
                    return (strongSelf.avatarNode.ready, { [weak strongSelf] animated in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, params, first, last, firstWithHeader)
                            
                            let revealOffset = strongSelf.revealOffset
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            if let _ = updatedTheme {
                                strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                                strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                                strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            if let editableControlSizeAndApply = editableControlSizeAndApply {
                                let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: CGSize(width: editableControlSizeAndApply.0, height: nodeLayout.contentSize.height))
                                if strongSelf.editableControlNode == nil {
                                    let editableControlNode = editableControlSizeAndApply.1(nodeLayout.contentSize.height)
                                    editableControlNode.tapped = {
                                        if let strongSelf = self {
                                            strongSelf.setRevealOptionsOpened(true, animated: true)
                                            strongSelf.revealOptionsInteractivelyOpened()
                                        }
                                    }
                                    strongSelf.editableControlNode = editableControlNode
                                    strongSelf.addSubnode(editableControlNode)
                                    editableControlNode.frame = editableControlFrame
                                    transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                                    editableControlNode.alpha = 0.0
                                    transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                                } else {
                                    strongSelf.editableControlNode?.frame = editableControlFrame
                                }
                            } else if let editableControlNode = strongSelf.editableControlNode {
                                var editableControlFrame = editableControlNode.frame
                                editableControlFrame.origin.x = -editableControlFrame.size.width
                                strongSelf.editableControlNode = nil
                                transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                                transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                                    editableControlNode?.removeFromSupernode()
                                })
                            }
                            
                            switch item.style {
                                case .plain:
                                    if strongSelf.backgroundNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                                    }
                                    if strongSelf.topStripeNode.supernode != nil {
                                        strongSelf.topStripeNode.removeFromSupernode()
                                    }
                                    if !last && strongSelf.bottomStripeNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                                    } else if last && strongSelf.bottomStripeNode.supernode != nil {
                                        strongSelf.bottomStripeNode.removeFromSupernode()
                                    }
                                    if strongSelf.maskNode.supernode != nil {
                                        strongSelf.maskNode.removeFromSupernode()
                                    }
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight)))
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
                                        strongSelf.addSubnode(strongSelf.maskNode)
                                    }
                                    let hasCorners = itemListHasRoundedBlockLayout(params)
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
                                            bottomStripeInset = leftInset
                                            strongSelf.bottomStripeNode.isHidden = false
                                        default:
                                            bottomStripeInset = 0.0
                                            hasBottomCorners = true
                                            strongSelf.bottomStripeNode.isHidden = hasCorners
                                    }
                                
                                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                                    
                                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width - bottomStripeInset, height: separatorHeight)))
                            }
                            
                    
                            transition.updateFrameAdditive(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 52.0, y: floor((contentSize.height - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter)))
                            
                            let _ = titleApply()
                            let titleFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: verticalInset), size: titleLayout.size)
                            transition.updateFrameAdditive(node: strongSelf.titleNode, frame: titleFrame)
                            
                            let _ = statusApply()
                            transition.updateFrameAdditive(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                            
                            if let currentCredibilityIconImage = currentCredibilityIconImage {
                                let iconNode: ASImageNode
                                if let current = strongSelf.credibilityIconNode {
                                    iconNode = current
                                } else {
                                    iconNode = ASImageNode()
                                    iconNode.isLayerBacked = true
                                    iconNode.displaysAsynchronously = false
                                    iconNode.displayWithoutProcessing = true
                                    strongSelf.containerNode.addSubnode(iconNode)
                                    strongSelf.credibilityIconNode = iconNode
                                }
                                iconNode.image = currentCredibilityIconImage
                                transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - currentCredibilityIconImage.size.height / 2.0) - UIScreenPixel), size: currentCredibilityIconImage.size))
                            } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                                strongSelf.credibilityIconNode = nil
                                credibilityIconNode.removeFromSupernode()
                            }
                            
                            let _ = dateApply()
                            transition.updateFrameAdditive(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + params.width - dateRightInset - dateLayout.size.width, y: floor((nodeLayout.contentSize.height - dateLayout.size.height) / 2.0) + 2.0), size: dateLayout.size))
                            
                            if let outgoingIcon = outgoingIcon {
                                if strongSelf.typeIconNode.image !== outgoingIcon {
                                    strongSelf.typeIconNode.image = outgoingIcon
                                }
                                transition.updateFrameAdditive(node: strongSelf.typeIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 79.0, y: floor((nodeLayout.contentSize.height - outgoingIcon.size.height) / 2.0)), size: outgoingIcon.size))
                            }
                            strongSelf.typeIconNode.isHidden = !hasOutgoing
                            
                            if let infoIcon = infoIcon {
                                if updatedInfoIcon {
                                    strongSelf.infoButtonNode.setImage(infoIcon, for: [])
                                }
                                transition.updateFrameAdditive(node: strongSelf.infoButtonNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - infoIconRightInset - infoIcon.size.width, y: floor((nodeLayout.contentSize.height - infoIcon.size.height) / 2.0)), size: infoIcon.size))
                            }
                            transition.updateAlpha(node: strongSelf.infoButtonNode, alpha: item.editing ? 0.0 : 1.0)
                            
                            let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                            
                            strongSelf.accessibilityArea.accessibilityLabel = titleAttributedString?.string
                            strongSelf.accessibilityArea.accessibilityValue = statusAccessibilityString
                            strongSelf.accessibilityArea.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            
                            strongSelf.infoButtonNode.accessibilityLabel = item.presentationData.strings.Conversation_Info
                            
                            strongSelf.view.accessibilityCustomActions = [UIAccessibilityCustomAction(name: item.presentationData.strings.Common_Delete, target: strongSelf, selector: #selector(strongSelf.performLocalAccessibilityCustomAction(_:)))]
                            
                            strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                            strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
                        }
                    })
                } else {
                    return (nil, { _ in })
                }
            })
        }
    }
    
    override func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.3, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let (item, _, _, _, _) = self.layoutParams {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    @objc func infoPressed() {
        if let item = self.layoutParams?.0 {
            item.interaction.openInfo(item.topMessage.id.peerId, item.messages)
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.layoutParams?.0 {
            item.interaction.setMessageIdWithRevealedOptions(item.topMessage.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.layoutParams?.0 {
            item.interaction.setMessageIdWithRevealedOptions(nil, item.topMessage.id)
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let (item, params, _, _, _) = self.layoutParams {
            let revealOffset = offset
            
            let editingOffset: CGFloat
            if let editableControlNode = self.editableControlNode {
                editingOffset = editableControlNode.bounds.size.width
                var editableControlFrame = editableControlNode.frame
                editableControlFrame.origin.x = params.leftInset + offset
                transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            let leftInset: CGFloat = 86.0 + params.leftInset + editingOffset
            let rightInset: CGFloat = 13.0 + params.rightInset
            var infoIconRightInset: CGFloat = rightInset - 1.0
            
            var dateRightInset: CGFloat = 46.0 + params.rightInset
            if item.editing {
                dateRightInset += 5.0
                infoIconRightInset -= 36.0
            }
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = revealOffset + leftInset - 52.0
            transition.updateFrameAdditive(node: self.avatarNode, frame: avatarFrame)
            
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
            
            transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
            
            transition.updateFrameAdditive(node: self.dateNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + self.bounds.size.width - dateRightInset - self.dateNode.bounds.size.width, y: self.dateNode.frame.minY), size: self.dateNode.bounds.size))
            
            transition.updateFrameAdditive(node: self.typeIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 81.0, y: self.typeIconNode.frame.minY), size: self.typeIconNode.bounds.size))
            
            transition.updateFrameAdditive(node: self.infoButtonNode, frame: CGRect(origin: CGPoint(x: revealOffset + self.bounds.size.width - infoIconRightInset - self.infoButtonNode.bounds.width, y: self.infoButtonNode.frame.minY), size: self.infoButtonNode.bounds.size))
        }
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        if let item = self.layoutParams?.0 {
            item.interaction.delete(item.messages.map { $0.id })
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let item = self.layoutParams?.0 {
            item.interaction.delete(item.messages.map { $0.id })
        }
    }
}
