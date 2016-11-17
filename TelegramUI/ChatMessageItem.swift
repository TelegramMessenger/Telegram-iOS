import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore

private func mediaIsNotMergeable(_ media: Media) -> Bool {
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    if let _ = media as? TelegramMediaAction {
        return true
    }
    
    return false
}

private func messagesShouldBeMerged(_ lhs: Message, _ rhs: Message) -> Bool {
    if abs(lhs.timestamp - rhs.timestamp) < 5 * 60 && lhs.author?.id == rhs.author?.id {
        for media in lhs.media {
            if mediaIsNotMergeable(media) {
                return false
            }
        }
        for media in rhs.media {
            if mediaIsNotMergeable(media) {
                return false
            }
        }
        for attribute in lhs.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    return false
                }
                break
            }
        }
        
        return true
    }
    
    return false
}

func chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)  -> Bool{
    let lhsHeader: ChatMessageDateHeader?
    let rhsHeader: ChatMessageDateHeader?
    if let lhs = lhs as? ChatMessageItem {
        lhsHeader = lhs.header
    } else if let lhs = lhs as? ChatHoleItem {
        lhsHeader = lhs.header
    } else if let lhs = lhs as? ChatUnreadItem {
        lhsHeader = lhs.header
    } else {
        lhsHeader = nil
    }
    if let rhs = rhs {
        if let rhs = rhs as? ChatMessageItem {
            rhsHeader = rhs.header
        } else if let rhs = rhs as? ChatHoleItem {
            rhsHeader = rhs.header
        } else if let rhs = rhs as? ChatUnreadItem {
            rhsHeader = rhs.header
        } else {
            rhsHeader = nil
        }
    } else {
        rhsHeader = nil
    }
    if let lhsHeader = lhsHeader, let rhsHeader = rhsHeader {
        return lhsHeader.id == rhsHeader.id
    } else {
        return false
    }
}

public final class ChatMessageItem: ListViewItem, CustomStringConvertible {
    let account: Account
    let peerId: PeerId
    let controllerInteraction: ChatControllerInteraction
    let message: Message
    let read: Bool
    
    public let accessoryItem: ListViewAccessoryItem?
    let header: ChatMessageDateHeader
    
    public init(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, message: Message, read: Bool) {
        self.account = account
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.message = message
        self.read = read
        
        var accessoryItem: ListViewAccessoryItem?
        let incoming = message.effectivelyIncoming
        let displayAuthorInfo = incoming && message.author != nil && peerId.isGroupOrChannel
        
        self.header = ChatMessageDateHeader(timestamp: message.timestamp)
        
        if displayAuthorInfo {
            var hasActionMedia = false
            for media in message.media {
                if media is TelegramMediaAction {
                    hasActionMedia = true
                    break
                }
            }
            if !hasActionMedia {
                if let author = message.author {
                    accessoryItem = ChatMessageAvatarAccessoryItem(account: account, peerId: author.id, peer: author, messageTimestamp: message.timestamp)
                }
            }
        }
        self.accessoryItem = accessoryItem
    }
    
    public func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        var viewClassName: AnyClass = ChatMessageBubbleItemNode.self
        
        for media in message.media {
            if let telegramFile = media as? TelegramMediaFile, telegramFile.isSticker {
                viewClassName = ChatMessageStickerItemNode.self
            } else if let _ = media as? TelegramMediaAction {
                viewClassName = ChatMessageActionItemNode.self
            }
        }
        
        let configure = { () -> Void in
            let node = (viewClassName as! ChatMessageItemView.Type).init()
            node.controllerInteraction = self.controllerInteraction
            node.setupItem(self)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = nodeLayout(self, width, top, bottom, dateAtBottom)
            
            node.updateSelectionState(animated: false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply(.None)
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    final func mergedWithItems(top: ListViewItem?, bottom: ListViewItem?) -> (top: Bool, bottom: Bool, dateAtBottom: Bool) {
        var mergedTop = false
        var mergedBottom = false
        var dateAtBottom = false
        if let top = top as? ChatMessageItem {
            if top.header.id != self.header.id {
                mergedBottom = false
            } else {
                mergedBottom = messagesShouldBeMerged(message, top.message)
            }
        }
        if let bottom = bottom as? ChatMessageItem {
            if bottom.header.id != self.header.id {
                mergedTop = false
                dateAtBottom = true
            } else {
                mergedTop = messagesShouldBeMerged(bottom.message, message)
            }
        } else if let bottom = bottom as? ChatUnreadItem {
            if bottom.header.id != self.header.id {
                dateAtBottom = true
            }
        } else if let bottom = bottom as? ChatHoleItem {
            if bottom.header.id != self.header.id {
                dateAtBottom = true
            }
        } else {
            dateAtBottom = true
        }
        
        return (mergedTop, mergedBottom, dateAtBottom)
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ChatMessageItemView {
            Queue.mainQueue().async {
                node.setupItem(self)
                
                node.updateSelectionState(animated: false)
                
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem)
                    
                    let (layout, apply) = nodeLayout(self, width, top, bottom, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
    
    public var description: String {
        return "(ChatMessageItem id: \(self.message.id), text: \"\(self.message.text)\")"
    }
    
    
}
