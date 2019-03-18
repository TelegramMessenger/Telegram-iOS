import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

struct ChatMessageItemWidthFill {
    let compactInset: CGFloat
    let compactWidthBoundary: CGFloat
    let freeMaximumFillFactor: CGFloat
    
    func widthFor(_ width: CGFloat) -> CGFloat {
        if width <= self.compactWidthBoundary {
            return max(1.0, width - self.compactInset)
        } else {
            return max(1.0, floor(width * self.freeMaximumFillFactor))
        }
    }
}

struct ChatMessageItemBubbleLayoutConstants {
    let edgeInset: CGFloat
    let defaultSpacing: CGFloat
    let mergedSpacing: CGFloat
    let maximumWidthFill: ChatMessageItemWidthFill
    let minimumSize: CGSize
    let contentInsets: UIEdgeInsets
    let borderInset: CGFloat
}

struct ChatMessageItemTextLayoutConstants {
    let bubbleInsets: UIEdgeInsets
}

struct ChatMessageItemImageLayoutConstants {
    let bubbleInsets: UIEdgeInsets
    let statusInsets: UIEdgeInsets
    let defaultCornerRadius: CGFloat
    let mergedCornerRadius: CGFloat
    let contentMergedCornerRadius: CGFloat
    let maxDimensions: CGSize
    let minDimensions: CGSize
}

struct ChatMessageItemVideoLayoutConstants {
    let maxHorizontalHeight: CGFloat
    let maxVerticalHeight: CGFloat
}

struct ChatMessageItemInstantVideoConstants {
    let insets: UIEdgeInsets
    let dimensions: CGSize
}

struct ChatMessageItemFileLayoutConstants {
    let bubbleInsets: UIEdgeInsets
}

struct ChatMessageItemWallpaperLayoutConstants {
    let maxTextWidth: CGFloat
}

struct ChatMessageItemLayoutConstants {
    let avatarDiameter: CGFloat
    let timestampHeaderHeight: CGFloat
    
    let bubble: ChatMessageItemBubbleLayoutConstants
    let image: ChatMessageItemImageLayoutConstants
    let video: ChatMessageItemVideoLayoutConstants
    let text: ChatMessageItemTextLayoutConstants
    let file: ChatMessageItemFileLayoutConstants
    let instantVideo: ChatMessageItemInstantVideoConstants
    let wallpapers: ChatMessageItemWallpaperLayoutConstants
    
    init() {
        self.avatarDiameter = 37.0
        self.timestampHeaderHeight = 34.0
        
        self.bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 4.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 1.0, maximumWidthFill: ChatMessageItemWidthFill(compactInset: 36.0, compactWidthBoundary: 500.0, freeMaximumFillFactor: 0.85), minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 0.0), borderInset: UIScreenPixel)
        self.text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 12.0, bottom: 6.0 - UIScreenPixel, right: 12.0))
        self.image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 1.0 + UIScreenPixel, left: 1.0 + UIScreenPixel, bottom: 1.0 + UIScreenPixel, right: 1.0 + UIScreenPixel), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 17.0, mergedCornerRadius: 5.0, contentMergedCornerRadius: 5.0, maxDimensions: CGSize(width: 300.0, height: 300.0), minDimensions: CGSize(width: 170.0, height: 74.0))
        self.video = ChatMessageItemVideoLayoutConstants(maxHorizontalHeight: 250.0, maxVerticalHeight: 360.0)
        self.file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        self.instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 212.0, height: 212.0))
        self.wallpapers = ChatMessageItemWallpaperLayoutConstants(maxTextWidth: 180.0)
    }
}

enum ChatMessageItemBottomNeighbor {
    case none
    case merged(semi: Bool)
}

let defaultChatMessageItemLayoutConstants = ChatMessageItemLayoutConstants()

enum ChatMessagePeekPreviewContent {
    case media(Media)
    case url(ASDisplayNode, CGRect, String)
}

private let voiceMessageDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
}()

private let musicDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
}()

final class ChatMessageAccessibilityData {
    let label: String?
    let value: String?
    let hint: String?
    let traits: UIAccessibilityTraits
    
    init(item: ChatMessageItem, isSelected: Bool?) {
        var label: String
        let value: String
        var hint: String?
        var traits: UIAccessibilityTraits = 0
        
        let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
        var announceIncomingAuthors = false
        if let peer = item.message.peers[item.message.id.peerId] {
            if peer is TelegramGroup {
                announceIncomingAuthors = true
            } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                announceIncomingAuthors = true
            }
        }
        
        var authorName: String?
        if let author = item.message.author {
            authorName = author.displayTitle
            if isIncoming {
                label = author.displayTitle
            } else {
                label = "Your message"
            }
        } else {
            label = "Message"
        }
        
        if let chatPeer = item.message.peers[item.message.id.peerId] {
            let (_, _, messageText) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, message: item.message, chatPeer: RenderedPeer(peer: chatPeer), accountPeerId: item.context.account.peerId)
            
            var text = messageText
            
            loop: for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    for attribute in file.attributes {
                        switch attribute {
                            case let .Audio(audio):
                                if isSelected == nil {
                                    hint = "Double tap to play"
                                }
                                traits |= UIAccessibilityTraitStartsMediaSession
                                if audio.isVoice {
                                    let durationString = voiceMessageDurationFormatter.string(from: Double(audio.duration)) ?? ""
                                    if isIncoming {
                                        if announceIncomingAuthors, let authorName = authorName {
                                            label = "Voice message, from: \(authorName)"
                                        } else {
                                            label = "Voice message"
                                        }
                                    } else {
                                        label = "Your voice message"
                                    }
                                    text = "Duration: \(durationString)"
                                } else {
                                    let durationString = musicDurationFormatter.string(from: Double(audio.duration)) ?? ""
                                    if announceIncomingAuthors, let authorName = authorName {
                                        label = "Music file, from: \(authorName)"
                                    } else {
                                        label = "Your music file"
                                    }
                                    let performer = audio.performer ?? "Unknown"
                                    let title = audio.title ?? "Unknown"
                                    text = "\(title), by \(performer). Duration: \(durationString)"
                                }
                            default:
                                break
                        }
                    }
                    break loop
                }
            }
            
            var result = ""
            
            if let isSelected = isSelected {
                if isSelected {
                    result += "Selected.\n"
                }
                traits |= UIAccessibilityTraitStartsMediaSession
            }
            
            result += "\(text)"
            
            let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(item.message.timestamp)), dateStyle: DateFormatter.Style.medium, timeStyle: DateFormatter.Style.short)
            
            result += "\n\(dateString)"
            if !isIncoming && item.read {
                if announceIncomingAuthors {
                    result += "Seen by recipients"
                } else {
                    result += "Seen by recipient"
                }
            }
            value = result
        } else {
            value = ""
        }
        
        self.label = label
        self.value = value
        self.hint = hint
        self.traits = traits
    }
}

public class ChatMessageItemView: ListViewItemNode {
    let layoutConstants = defaultChatMessageItemLayoutConstants
    
    var item: ChatMessageItem?
    
    public required convenience init() {
        self.init(layerBacked: false)
    }
    
    public init(layerBacked: Bool) {
        super.init(layerBacked: layerBacked, dynamicBounce: true, rotated: true)
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func reuse() {
        super.reuse()
        
        self.item = nil
        self.frame = CGRect()
    }
    
    func setupItem(_ item: ChatMessageItem) {
        self.item = item
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ChatMessageItem {
            let doLayout = self.asyncLayout()
            let merged = item.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom, merged.dateAtBottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None, false)
        }
    }
    
    override public func layoutAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode, leftInset: CGFloat, rightInset: CGFloat) {
        if let avatarNode = accessoryItemNode as? ChatMessageAvatarAccessoryItemNode {
            avatarNode.frame = CGRect(origin: CGPoint(x: leftInset + 3.0, y: self.apparentFrame.height - 38.0 - self.insets.top - 2.0 - UIScreenPixel), size: CGSize(width: 38.0, height: 38.0))
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        if short {
            //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height, to: 0.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        } else {
            self.transitionOffset = -self.bounds.size.height * 1.6
            self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        }
    }
    
    func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool) -> Void) {
        return { _, _, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: 32.0, height: 32.0), insets: UIEdgeInsets()), { _, _ in
                
            })
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func peekPreviewContent(at point: CGPoint) -> (Message, ChatMessagePeekPreviewContent)? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func updateSelectionState(animated: Bool) {
    }
    
    func updateSearchTextHighlightState() {
    }
    
    func updateHighlightedState(animated: Bool) {
        var isHighlightedInOverlay = false
        if let item = self.item, let contextHighlightedState = item.controllerInteraction.contextHighlightedState {
            switch item.content {
                case let .message(message, _, _, _):
                    if contextHighlightedState.messageStableId == message.stableId {
                        isHighlightedInOverlay = true
                    }
                case let .group(messages):
                    for (message, _, _, _) in messages {
                        if contextHighlightedState.messageStableId == message.stableId {
                            isHighlightedInOverlay = true
                            break
                        }
                    }
            }
        }
        self.isHighlightedInOverlay = isHighlightedInOverlay
    }
    
    func updateAutomaticMediaDownloadSettings() {
    }
    
    func playMediaWithSound() -> (() -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return nil
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.item {
            return item.header
        } else {
            return nil
        }
    }
    
    func performMessageButtonAction(button: ReplyMarkupButton) {
        if let item = self.item {
            switch button.action {
                case .text:
                    item.controllerInteraction.sendMessage(button.title)
                case let .url(url):
                    item.controllerInteraction.openUrl(url, true, nil)
                case .requestMap:
                    item.controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    item.controllerInteraction.shareAccountContact()
                case .openWebApp:
                    item.controllerInteraction.requestMessageActionCallback(item.message.id, nil, true)
                case let .callback(data):
                    item.controllerInteraction.requestMessageActionCallback(item.message.id, data, false)
                case let .switchInline(samePeer, query):
                    var botPeer: Peer?
                    
                    var found = false
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute {
                            if let peerId = attribute.peerId {
                                botPeer = item.message.peers[peerId]
                                found = true
                            }
                        }
                    }
                    if !found {
                        botPeer = item.message.author
                    }
                    
                    var peerId: PeerId?
                    if samePeer {
                        peerId = item.message.id.peerId
                    }
                    if let botPeer = botPeer, let addressName = botPeer.addressName {
                        item.controllerInteraction.activateSwitchInline(peerId, "@\(addressName) \(query)")
                    }
                case .payment:
                    item.controllerInteraction.openCheckoutOrReceipt(item.message.id)
            }
        }
    }
    
    func presentMessageButtonContextMenu(button: ReplyMarkupButton) {
        if let item = self.item {
            switch button.action {
                case let .url(url):
                    item.controllerInteraction.longTap(.url(url))
                default:
                    break
            }
        }
    }
}
