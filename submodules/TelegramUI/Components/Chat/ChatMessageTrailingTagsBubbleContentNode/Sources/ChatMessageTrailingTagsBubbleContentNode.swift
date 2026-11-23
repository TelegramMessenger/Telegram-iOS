import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon

private enum PillId: Hashable {
    case tag(Int)
    case toggle
}

private final class PillNode: ASDisplayNode {
    let textNode: TextNode
    let accessibilityArea: AccessibilityAreaNode

    init(textNode: TextNode) {
        self.textNode = textNode
        self.accessibilityArea = AccessibilityAreaNode()
        self.accessibilityArea.accessibilityTraits = .button

        super.init()

        self.displaysAsynchronously = false
        self.clipsToBounds = true
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = false
        self.addSubnode(self.textNode)
        self.addSubnode(self.accessibilityArea)
    }
}

public final class ChatMessageTrailingTagsBubbleContentNode: ChatMessageBubbleContentNode, ChatMessageBubbleTrailingSelectionContent {
    private let separatorNode: ASDisplayNode
    private let statusNode: ChatMessageDateAndStatusNode
    private var pillNodes: [PillId: PillNode] = [:]
    private var pillFrames: [(id: PillId, frame: CGRect, hashtag: String?)] = []
    private var highlightedPillId: PillId?
    private var userIsExpanded: Bool?
    private var appliedIsExpanded: Bool?
    private var selectionRanges: [NSRange] = []
    public private(set) var trailingSelectionText: String = ""

    public var trailingSelectionTargets: [(range: NSRange, frame: CGRect)] {
        return self.pillFrames.compactMap { pill in
            if case let .tag(index) = pill.id, index < self.selectionRanges.count {
                return (self.selectionRanges[index], pill.frame)
            }
            return nil
        }
    }

    required public init() {
        self.separatorNode = ASDisplayNode()
        self.statusNode = ChatMessageDateAndStatusNode()

        super.init()

        self.separatorNode.isLayerBacked = true
        self.addSubnode(self.separatorNode)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func togglePressed() {
        guard let item = self.item else {
            return
        }
        self.userIsExpanded = !(self.userIsExpanded ?? item.attributes.expandsTrailingTags)
        let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
    }

    public override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.statusNode.supernode != nil, let _ = self.statusNode.hitTest(self.view.convert(point, to: self.statusNode.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        guard let pill = self.pillFrames.first(where: { $0.frame.insetBy(dx: -2.0, dy: -2.0).contains(point) }) else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        if case .longTap = gesture, let hashtag = pill.hashtag {
            return ChatMessageBubbleContentTapAction(content: .copy(hashtag))
        }
        guard case .tap = gesture else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        if let hashtag = pill.hashtag {
            return ChatMessageBubbleContentTapAction(content: .hashtag(nil, hashtag))
        }
        return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
            self?.togglePressed()
        }), hasLongTapAction: false)
    }

    public override func updateTouchesAtPoint(_ point: CGPoint?) {
        var highlightedPillId: PillId?
        if let point {
            highlightedPillId = self.pillFrames.first(where: { $0.frame.contains(point) })?.id
        }
        if self.highlightedPillId == highlightedPillId {
            return
        }
        if let previous = self.highlightedPillId, let node = self.pillNodes[previous] {
            node.alpha = 1.0
            node.layer.animateAlpha(from: 0.5, to: 1.0, duration: 0.18)
        }
        self.highlightedPillId = highlightedPillId
        if let highlightedPillId, let node = self.pillNodes[highlightedPillId] {
            node.layer.removeAnimation(forKey: "opacity")
            node.alpha = 0.5
        }
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let statusLayout = self.statusNode.asyncLayout()
        let currentUserIsExpanded = self.userIsExpanded
        let currentTextNodes = self.pillNodes.mapValues(\.textNode)

        return { [weak self] item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { [weak self] constrainedSize, position in
                let message = item.message
                let currentIsExpanded = currentUserIsExpanded ?? item.attributes.expandsTrailingTags
                let incoming = message.effectivelyIncoming(item.context.account.peerId)
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                let entities = message.textEntitiesAttribute?.entities ?? []
                let footer = trailingHashtagFooter(text: message.text, entities: entities, isCaption: !message.media.isEmpty)
                let hashtags = footer?.hashtags ?? []
                var selectionText = ""
                var selectionRanges: [NSRange] = []
                if let footer, let blockRange = trailingHashtagBlockRange(text: message.text, entities: entities) {
                    let string = message.text as NSString
                    selectionText = string.substring(with: NSRange(location: footer.textEnd, length: blockRange.upperBound - footer.textEnd))
                    for entity in entities {
                        if case .Hashtag = entity.type, entity.range.lowerBound >= blockRange.lowerBound, entity.range.upperBound <= string.length {
                            selectionRanges.append(NSRange(location: entity.range.lowerBound - footer.textEnd, length: entity.range.count))
                        }
                    }
                    if selectionRanges.count != hashtags.count {
                        selectionRanges = []
                    }
                }

                let font = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 12.0 / 17.0))
                let pillHeight: CGFloat = floor(font.lineHeight) + 5.0
                let pillInset: CGFloat = 8.0
                let pillSpacing: CGFloat = 4.0
                let sideInset = layoutConstants.text.bubbleInsets.left + 2.0
                let topInset: CGFloat = 7.0
                let bottomInset: CGFloat = 4.0
                let maxContentWidth = constrainedSize.width - sideInset * 2.0

                let makeLabel: (PillId, String) -> (TextNodeLayout, () -> TextNode) = { id, text in
                    let layout = TextNode.asyncLayout(currentTextNodes[id])
                    return layout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: font, textColor: messageTheme.linkTextColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, maxContentWidth - pillInset * 2.0), height: 100.0)))
                }
                let labels = hashtags.enumerated().map { index, hashtag in
                    return makeLabel(.tag(index), hashtag)
                }

                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: message)
                if message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        starsCount = attribute.stars.value
                    }
                }

                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else if let subject = item.associatedData.subject, case .messageOptions = subject {
                    dateFormat = .minimal
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(context: item.context, message: EngineMessage(message), dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)

                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else if message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if message.flags.isSending && !message.isSentOrAcknowledged {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                    default:
                        statusType = nil
                    }
                }

                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited && !item.presentationData.isPreview,
                        impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: nil, reactionSettings: item.presentationData.isPreview ? nil : ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: EngineMessage(message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false)),
                        constrainedSize: CGSize(width: maxContentWidth, height: constrainedSize.height),
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        areStarReactionsEnabled: item.associatedData.areStarReactionsEnabled,
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && isReplyThread,
                        hasAutoremove: message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: EngineMessage(item.topMessage)),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }

                var suggestedWidth: CGFloat = 0.0
                for label in labels.prefix(3) {
                    suggestedWidth += label.0.size.width + pillInset * 2.0 + pillSpacing
                }
                suggestedWidth = min(maxContentWidth, suggestedWidth)
                if let statusSuggestedWidthAndContinue {
                    suggestedWidth = max(suggestedWidth, statusSuggestedWidthAndContinue.0)
                }

                return (suggestedWidth + sideInset * 2.0, { [weak self] boundingWidth in
                    let contentWidth = boundingWidth - sideInset * 2.0
                    let pillWidth: (CGFloat) -> CGFloat = { labelWidth in
                        return min(contentWidth, ceil(labelWidth) + pillInset * 2.0)
                    }

                    var visibleCount = labels.count
                    var toggleLabel: (TextNodeLayout, () -> TextNode)?
                    var toggleAccessibilityLabel: String?
                    if !currentIsExpanded {
                        var x: CGFloat = 0.0
                        var fitting = 0
                        for index in 0 ..< labels.count {
                            let width = pillWidth(labels[index].0.size.width)
                            let reserved = index == labels.count - 1 ? 0.0 : pillSpacing + pillWidth(makeLabel(.toggle, "+\(labels.count - index - 1)").0.size.width)
                            if x + width + reserved > contentWidth && fitting != 0 {
                                break
                            }
                            x += width + pillSpacing
                            fitting += 1
                        }
                        visibleCount = fitting
                        if visibleCount < labels.count {
                            toggleLabel = makeLabel(.toggle, "+\(labels.count - visibleCount)")
                            toggleAccessibilityLabel = item.presentationData.strings.Support_Tags_VoiceOverShowMore(Int32(labels.count - visibleCount))
                        }
                    } else {
                        var x: CGFloat = 0.0
                        var rowCount = 1
                        for label in labels {
                            let width = pillWidth(label.0.size.width)
                            if x != 0.0 && x + width > contentWidth {
                                x = 0.0
                                rowCount += 1
                            }
                            x += width + pillSpacing
                        }
                        if rowCount > 1 {
                            toggleLabel = makeLabel(.toggle, "\u{2212}")
                            toggleAccessibilityLabel = item.presentationData.strings.Support_Tags_VoiceOverShowFewer
                        }
                    }

                    var frames: [(id: PillId, frame: CGRect, hashtag: String?, label: (TextNodeLayout, () -> TextNode))] = []
                    var x: CGFloat = 0.0
                    var y: CGFloat = topInset
                    let place: (PillId, String?, (TextNodeLayout, () -> TextNode)) -> Void = { id, hashtag, label in
                        let width = pillWidth(label.0.size.width)
                        if x != 0.0 && x + width > contentWidth {
                            x = 0.0
                            y += pillHeight + pillSpacing
                        }
                        frames.append((id, CGRect(x: sideInset + x, y: y, width: width, height: pillHeight), hashtag, label))
                        x += width + pillSpacing
                    }
                    for index in 0 ..< visibleCount {
                        place(.tag(index), hashtags[index], labels[index])
                    }
                    if let toggleLabel {
                        place(.toggle, nil, toggleLabel)
                    }
                    let pillsBottom = y + pillHeight

                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right)
                    var boundingSize = CGSize(width: boundingWidth, height: pillsBottom + bottomInset)
                    if let statusSizeAndApply {
                        boundingSize.height += statusSizeAndApply.0.height + layoutConstants.text.bubbleInsets.bottom
                    }

                    return (boundingSize, { [weak self] animation, _, info in
                        guard let strongSelf = self else {
                            return
                        }
                        let isFirstTime = strongSelf.item == nil
                        strongSelf.item = item
                        strongSelf.trailingSelectionText = selectionText
                        strongSelf.selectionRanges = selectionRanges

                        strongSelf.separatorNode.backgroundColor = messageTheme.primaryTextColor.withMultipliedAlpha(0.12)
                        strongSelf.separatorNode.frame = CGRect(x: sideInset, y: 2.0, width: contentWidth, height: UIScreenPixel)

                        if let appliedIsExpanded = strongSelf.appliedIsExpanded, appliedIsExpanded != currentIsExpanded {
                            info?.setInvertOffsetDirection()
                        }
                        strongSelf.appliedIsExpanded = currentIsExpanded

                        var validIds = Set<PillId>()
                        strongSelf.pillFrames = []
                        for pill in frames {
                            validIds.insert(pill.id)
                            let textNode = pill.label.1()
                            let node: PillNode
                            var isNew = false
                            if let current = strongSelf.pillNodes[pill.id], current.textNode === textNode {
                                node = current
                            } else {
                                strongSelf.pillNodes[pill.id]?.removeFromSupernode()
                                node = PillNode(textNode: textNode)
                                strongSelf.pillNodes[pill.id] = node
                                strongSelf.addSubnode(node)
                                isNew = true
                            }
                            node.backgroundColor = messageTheme.linkTextColor.withMultipliedAlpha(0.12)
                            node.cornerRadius = pillHeight / 2.0
                            if isNew || isFirstTime {
                                node.frame = pill.frame
                                if !isFirstTime {
                                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                                }
                            } else {
                                animation.animator.updateFrame(layer: node.layer, frame: pill.frame, completion: nil)
                            }
                            textNode.frame = CGRect(x: pillInset, y: floorToScreenPixels((pillHeight - pill.label.0.size.height) / 2.0), width: pill.frame.width - pillInset * 2.0, height: pill.label.0.size.height)
                            node.accessibilityArea.frame = CGRect(origin: CGPoint(), size: pill.frame.size)
                            node.accessibilityArea.accessibilityLabel = pill.hashtag ?? toggleAccessibilityLabel
                            let hashtag = pill.hashtag
                            node.accessibilityArea.activate = { [weak strongSelf] in
                                guard let strongSelf, let item = strongSelf.item else {
                                    return false
                                }
                                if let hashtag {
                                    item.controllerInteraction.openHashtag(nil, hashtag)
                                } else {
                                    strongSelf.togglePressed()
                                }
                                return true
                            }
                            strongSelf.pillFrames.append((pill.id, pill.frame, pill.hashtag))
                        }
                        for (id, node) in strongSelf.pillNodes where !validIds.contains(id) {
                            node.removeFromSupernode()
                            strongSelf.pillNodes.removeValue(forKey: id)
                        }

                        if let statusSizeAndApply {
                            strongSelf.statusNode.reactionSelected = { [weak strongSelf] _, value, sourceView in
                                guard let strongSelf, let item = strongSelf.item else {
                                    return
                                }
                                item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
                            }
                            strongSelf.statusNode.openReactionPreview = { [weak strongSelf] gesture, sourceNode, value in
                                guard let strongSelf, let item = strongSelf.item else {
                                    gesture?.cancel()
                                    return
                                }
                                item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
                            }
                            let statusFrame = CGRect(origin: CGPoint(x: boundingWidth - layoutConstants.text.bubbleInsets.right - statusSizeAndApply.0.width, y: pillsBottom + bottomInset), size: statusSizeAndApply.0)
                            if isFirstTime {
                                strongSelf.statusNode.frame = statusFrame
                            } else {
                                animation.animator.updateFrame(layer: strongSelf.statusNode.layer, frame: statusFrame, completion: nil)
                            }
                            if strongSelf.statusNode.supernode == nil {
                                strongSelf.addSubnode(strongSelf.statusNode)
                                statusSizeAndApply.1(.None)
                            } else {
                                statusSizeAndApply.1(animation)
                            }
                        } else if strongSelf.statusNode.supernode != nil {
                            strongSelf.statusNode.removeFromSupernode()
                        }
                    })
                })
            })
        }
    }

    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }

    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }

    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
