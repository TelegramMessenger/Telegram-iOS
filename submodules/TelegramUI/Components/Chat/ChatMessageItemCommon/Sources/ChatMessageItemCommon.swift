import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import Emoji

public struct ChatMessageItemWidthFill {
    public var compactInset: CGFloat
    public var compactWidthBoundary: CGFloat
    public var freeMaximumFillFactor: CGFloat
    
    public func widthFor(_ width: CGFloat) -> CGFloat {
        if width <= self.compactWidthBoundary {
            return max(1.0, width - self.compactInset)
        } else {
            return max(1.0, floor(width * self.freeMaximumFillFactor))
        }
    }
}

public struct ChatMessageItemBubbleLayoutConstants {
    public var edgeInset: CGFloat
    public var defaultSpacing: CGFloat
    public var mergedSpacing: CGFloat
    public var maximumWidthFill: ChatMessageItemWidthFill
    public var minimumSize: CGSize
    public var contentInsets: UIEdgeInsets
    public var borderInset: CGFloat
    public var strokeInsets: UIEdgeInsets
    
    public init(edgeInset: CGFloat, defaultSpacing: CGFloat, mergedSpacing: CGFloat, maximumWidthFill: ChatMessageItemWidthFill, minimumSize: CGSize, contentInsets: UIEdgeInsets, borderInset: CGFloat, strokeInsets: UIEdgeInsets) {
        self.edgeInset = edgeInset
        self.defaultSpacing = defaultSpacing
        self.mergedSpacing = mergedSpacing
        self.maximumWidthFill = maximumWidthFill
        self.minimumSize = minimumSize
        self.contentInsets = contentInsets
        self.borderInset = borderInset
        self.strokeInsets = strokeInsets
    }
}

public struct ChatMessageItemTextLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    
    public init(bubbleInsets: UIEdgeInsets) {
        self.bubbleInsets = bubbleInsets
    }
}

public struct ChatMessageItemImageLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    public var statusInsets: UIEdgeInsets
    public var defaultCornerRadius: CGFloat
    public var mergedCornerRadius: CGFloat
    public var contentMergedCornerRadius: CGFloat
    public var maxDimensions: CGSize
    public var minDimensions: CGSize
    
    public init(bubbleInsets: UIEdgeInsets, statusInsets: UIEdgeInsets, defaultCornerRadius: CGFloat, mergedCornerRadius: CGFloat, contentMergedCornerRadius: CGFloat, maxDimensions: CGSize, minDimensions: CGSize) {
        self.bubbleInsets = bubbleInsets
        self.statusInsets = statusInsets
        self.defaultCornerRadius = defaultCornerRadius
        self.mergedCornerRadius = mergedCornerRadius
        self.contentMergedCornerRadius = contentMergedCornerRadius
        self.maxDimensions = maxDimensions
        self.minDimensions = minDimensions
    }
}

public struct ChatMessageItemVideoLayoutConstants {
    public var maxHorizontalHeight: CGFloat
    public var maxVerticalHeight: CGFloat
    
    public init(maxHorizontalHeight: CGFloat, maxVerticalHeight: CGFloat) {
        self.maxHorizontalHeight = maxHorizontalHeight
        self.maxVerticalHeight = maxVerticalHeight
    }
}

public struct ChatMessageItemInstantVideoConstants {
    public var insets: UIEdgeInsets
    public var dimensions: CGSize
    
    public init(insets: UIEdgeInsets, dimensions: CGSize) {
        self.insets = insets
        self.dimensions = dimensions
    }
}

public struct ChatMessageItemFileLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    
    public init(bubbleInsets: UIEdgeInsets) {
        self.bubbleInsets = bubbleInsets
    }
}

public struct ChatMessageItemWallpaperLayoutConstants {
    public var maxTextWidth: CGFloat
    
    public init(maxTextWidth: CGFloat) {
        self.maxTextWidth = maxTextWidth
    }
}

public struct ChatMessageItemLayoutConstants {
    public var avatarDiameter: CGFloat
    public var timestampHeaderHeight: CGFloat
    public var timestampDateAndTopicHeaderHeight: CGFloat
    
    public var bubble: ChatMessageItemBubbleLayoutConstants
    public var image: ChatMessageItemImageLayoutConstants
    public var video: ChatMessageItemVideoLayoutConstants
    public var text: ChatMessageItemTextLayoutConstants
    public var file: ChatMessageItemFileLayoutConstants
    public var instantVideo: ChatMessageItemInstantVideoConstants
    public var wallpapers: ChatMessageItemWallpaperLayoutConstants
    
    public init(avatarDiameter: CGFloat, timestampHeaderHeight: CGFloat, timestampDateAndTopicHeaderHeight: CGFloat, bubble: ChatMessageItemBubbleLayoutConstants, image: ChatMessageItemImageLayoutConstants, video: ChatMessageItemVideoLayoutConstants, text: ChatMessageItemTextLayoutConstants, file: ChatMessageItemFileLayoutConstants, instantVideo: ChatMessageItemInstantVideoConstants, wallpapers: ChatMessageItemWallpaperLayoutConstants) {
        self.avatarDiameter = avatarDiameter
        self.timestampHeaderHeight = timestampHeaderHeight
        self.timestampDateAndTopicHeaderHeight = timestampDateAndTopicHeaderHeight
        self.bubble = bubble
        self.image = image
        self.video = video
        self.text = text
        self.file = file
        self.instantVideo = instantVideo
        self.wallpapers = wallpapers
    }
    
    public static var `default`: ChatMessageItemLayoutConstants {
        return self.compact
    }
    
    public static var compact: ChatMessageItemLayoutConstants {
        let bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 3.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 0.0, maximumWidthFill: ChatMessageItemWidthFill(compactInset: 36.0, compactWidthBoundary: 500.0, freeMaximumFillFactor: 0.85), minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 0.0), borderInset: UIScreenPixel, strokeInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0))
        let text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 11.0, bottom: 6.0 - UIScreenPixel, right: 11.0))
        let image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 16.0, mergedCornerRadius: 8.0, contentMergedCornerRadius: 0.0, maxDimensions: CGSize(width: 300.0, height: 380.0), minDimensions: CGSize(width: 170.0, height: 74.0))
        let video = ChatMessageItemVideoLayoutConstants(maxHorizontalHeight: 250.0, maxVerticalHeight: 360.0)
        let file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        let instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 212.0, height: 212.0))
        let wallpapers = ChatMessageItemWallpaperLayoutConstants(maxTextWidth: 180.0)
        
        return ChatMessageItemLayoutConstants(avatarDiameter: 37.0, timestampHeaderHeight: 34.0, timestampDateAndTopicHeaderHeight: 7.0 * 2.0 + 20.0 * 2.0 + 7.0, bubble: bubble, image: image, video: video, text: text, file: file, instantVideo: instantVideo, wallpapers: wallpapers)
    }
    
    public static var regular: ChatMessageItemLayoutConstants {
        let bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 3.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 0.0, maximumWidthFill: ChatMessageItemWidthFill(compactInset: 36.0, compactWidthBoundary: 500.0, freeMaximumFillFactor: 0.65), minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 0.0), borderInset: UIScreenPixel, strokeInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0))
        let text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 10.0, bottom: 6.0 - UIScreenPixel, right: 10.0))
        let image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 16.0, mergedCornerRadius: 8.0, contentMergedCornerRadius: 5.0, maxDimensions: CGSize(width: 440.0, height: 440.0), minDimensions: CGSize(width: 170.0, height: 74.0))
        let video = ChatMessageItemVideoLayoutConstants(maxHorizontalHeight: 250.0, maxVerticalHeight: 360.0)
        let file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        let instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 240.0, height: 240.0))
        let wallpapers = ChatMessageItemWallpaperLayoutConstants(maxTextWidth: 180.0)
        
        return ChatMessageItemLayoutConstants(avatarDiameter: 37.0, timestampHeaderHeight: 34.0, timestampDateAndTopicHeaderHeight: 7.0 * 2.0 + 20.0 * 2.0 + 7.0, bubble: bubble, image: image, video: video, text: text, file: file, instantVideo: instantVideo, wallpapers: wallpapers)
    }
}

public func canViewMessageReactionList(message: Message) -> Bool {
    var found = false
    var canViewList = false
    for attribute in message.attributes {
        if let attribute = attribute as? ReactionsMessageAttribute {
            canViewList = attribute.canViewList
            found = true
            break
        }
    }
    
    if !found {
        return false
    }
    
    if let peer = message.peers[message.id.peerId] {
        if let channel = peer as? TelegramChannel {
            if case .broadcast = channel.info {
                return false
            } else {
                return canViewList
            }
        } else if let _ = peer as? TelegramGroup {
            return canViewList
        } else if let _ = peer as? TelegramUser {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public let chatMessagePeerIdColors: [UIColor] = [
    UIColor(rgb: 0xfc5c51),
    UIColor(rgb: 0xfa790f),
    UIColor(rgb: 0x895dd5),
    UIColor(rgb: 0x0fb297),
    UIColor(rgb: 0x00c0c2),
    UIColor(rgb: 0x3ca5ec),
    UIColor(rgb: 0x3d72ed)
]

public enum TranscribedText: Equatable {
    case success(text: String, isPending: Bool)
    case error(AudioTranscriptionMessageAttribute.TranscriptionError)
}

public func transcribedText(message: Message) -> TranscribedText? {
    for attribute in message.attributes {
        if let attribute = attribute as? AudioTranscriptionMessageAttribute {
            if !attribute.text.isEmpty {
                return .success(text: attribute.text, isPending: attribute.isPending)
            } else {
                if attribute.isPending {
                    return nil
                } else {
                    return .error(attribute.error ?? .generic)
                }
            }
        }
    }
    return nil
}

public func isPollEffectivelyClosed(message: Message, poll: TelegramMediaPoll) -> Bool {
    if poll.isClosed {
        return true
    } else {
        return false
    }
}

public extension ChatReplyThreadMessage {
    var effectiveTopId: MessageId {
        return self.channelMessageId ?? MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: self.threadId))
    }
}

public func messageIsEligibleForLargeEmoji(_ message: Message) -> Bool {
    if !message.text.isEmpty && message.text.containsOnlyEmoji {
        if !(message.textEntitiesAttribute?.entities.isEmpty ?? true) {
            return false
        }
        return true
    } else {
        return false
    }
}

public func messageIsEligibleForLargeCustomEmoji(_ message: Message) -> Bool {
    let text = message.text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    guard !text.isEmpty && text.containsOnlyEmoji else {
        return false
    }
    let entities = message.textEntitiesAttribute?.entities ?? []
    guard entities.count > 0 else {
        return false
    }
    for entity in entities {
        if case let .CustomEmoji(_, fileId) = entity.type {
            if let _ = message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                
            } else {
                return false
            }
        } else {
            return false
        }
    }
    return true
}

public func canAddMessageReactions(message: Message) -> Bool {
    if message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    if let peer = message.peers[message.id.peerId] {
        if let _ = peer as? TelegramSecretChat {
            return false
        }
    } else {
        return false
    }
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            if message.flags.contains(.ReactionsArePossible) {
                return true
            } else {
                switch action.action {
                case .unknown, .groupCreated, .channelMigratedFromGroup, .groupMigratedToChannel, .historyCleared, .customText, .botDomainAccessGranted, .botAppAccessGranted, .botSentSecureValues, .phoneNumberRequest, .webViewData, .topicCreated, .attachMenuBotAllowed, .requestedPeer, .giveawayLaunched, .suggestedPostApprovalStatus, .suggestedPostSuccess, .suggestedPostRefund:
                    return false
                default:
                    return true
                }
            }
        }
    }
    return true
}
