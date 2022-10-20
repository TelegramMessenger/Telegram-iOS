import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences
import ItemListUI

public final class ListMessageItemInteraction {
    public let openMessage: (Message, ChatControllerInteractionOpenMessageMode) -> Bool
    public let openMessageContextMenu: (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void
    public let toggleMessagesSelection: ([MessageId], Bool) -> Void
    let openUrl: (String, Bool, Bool?, Message?) -> Void
    let openInstantPage: (Message, ChatMessageItemAssociatedData?) -> Void
    let longTap: (ChatControllerInteractionLongTapAction, Message?) -> Void
    let getHiddenMedia: () -> [MessageId: [Media]]
    
    public var searchTextHighightState: String?
    
    public init(openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Bool, openMessageContextMenu: @escaping (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void, toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void, openUrl: @escaping (String, Bool, Bool?, Message?) -> Void, openInstantPage: @escaping (Message, ChatMessageItemAssociatedData?) -> Void, longTap: @escaping (ChatControllerInteractionLongTapAction, Message?) -> Void, getHiddenMedia: @escaping () -> [MessageId: [Media]]) {
        self.openMessage = openMessage
        self.openMessageContextMenu = openMessageContextMenu
        self.toggleMessagesSelection = toggleMessagesSelection
        self.openUrl = openUrl
        self.openInstantPage = openInstantPage
        self.longTap = longTap
        self.getHiddenMedia = getHiddenMedia
    }
    
    public static var `default`: ListMessageItemInteraction = ListMessageItemInteraction(openMessage: { _, _ in
        return false
    }, openMessageContextMenu: { _, _, _, _, _ in
    }, toggleMessagesSelection: { _, _ in
    }, openUrl: { _, _, _, _ in
    }, openInstantPage: { _, _ in
    }, longTap: { _, _ in
    }, getHiddenMedia: { () -> [MessageId : [Media]] in
        return [:]
    })
}

public final class ListMessageItem: ListViewItem {
    let presentationData: ChatPresentationData
    let context: AccountContext
    let chatLocation: ChatLocation
    let interaction: ListMessageItemInteraction
    let message: Message?
    public let selection: ChatHistoryMessageSelection
    let hintIsLink: Bool
    let isGlobalSearchResult: Bool
    let isDownloadList: Bool
    let displayFileInfo: Bool
    let displayBackground: Bool
    let style: ItemListStyle
    
    let header: ListViewItemHeader?
    
    public let selectable: Bool = true
    
    public init(presentationData: ChatPresentationData, context: AccountContext, chatLocation: ChatLocation, interaction: ListMessageItemInteraction, message: Message?, selection: ChatHistoryMessageSelection, displayHeader: Bool, customHeader: ListViewItemHeader? = nil, hintIsLink: Bool = false, isGlobalSearchResult: Bool = false, isDownloadList: Bool = false, displayFileInfo: Bool = true, displayBackground: Bool = false, style: ItemListStyle = .plain) {
        self.presentationData = presentationData
        self.context = context
        self.chatLocation = chatLocation
        self.interaction = interaction
        self.message = message
        if let header = customHeader {
            self.header = header
        } else if displayHeader, let message = message {
            self.header = ListMessageDateHeader(timestamp: message.timestamp, theme: presentationData.theme.theme, strings: presentationData.strings, fontSize: presentationData.fontSize)
        } else {
            self.header = nil
        }
        self.selection = selection
        self.hintIsLink = hintIsLink
        self.isGlobalSearchResult = isGlobalSearchResult
        self.isDownloadList = isDownloadList
        self.displayFileInfo = displayFileInfo
        self.displayBackground = displayBackground
        self.style = style
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        var viewClassName: AnyClass = ListMessageSnippetItemNode.self
        
        if !self.hintIsLink {
            if let message = self.message {
                for media in message.media {
                    if let _ = media as? TelegramMediaFile {
                        viewClassName = ListMessageFileItemNode.self
                        break
                    } else if let _ = media as? TelegramMediaImage {
                        viewClassName = ListMessageFileItemNode.self
                        break
                    }
                }
            } else {
                viewClassName = ListMessageFileItemNode.self
            }
        }
        
        let configure = { () -> Void in
            let node = (viewClassName as! ListMessageNode.Type).init()
            node.interaction = self.interaction
            node.setupItem(self)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = (previousItem != nil && !(previousItem is ItemListItem), nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
            let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom)
            
            node.updateSelectionState(animated: false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ListMessageNode {
                nodeValue.setupItem(self)
                
                nodeValue.updateSelectionState(animated: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom, dateAtBottom) = (previousItem != nil && !(previousItem is ItemListItem), nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        guard let message = self.message else {
            return
        }
        
        if case let .selectable(selected) = self.selection {
            self.interaction.toggleMessagesSelection([message.id], !selected)
        } else {
            if !self.displayFileInfo {
                let _ = self.interaction.openMessage(message, .default)
            } else {
                listView.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ListMessageFileItemNode {
                        if let messageId = itemNode.item?.message?.id, messageId == message.id {
                            itemNode.activateMedia()
                        }
                    } else if let itemNode = itemNode as? ListMessageSnippetItemNode {
                        if let messageId = itemNode.item?.message?.id, messageId == message.id {
                            itemNode.activateMedia()
                        }
                    }
                }
            }
        }
    }
    
    func getDateAtBottom(top: ListViewItem?, bottom: ListViewItem?) -> Bool {
        var dateAtBottom = false
        if let top = top as? ListMessageItem, top.header != nil {
            if top.header?.id != self.header?.id {
                dateAtBottom = true
            }
        } else {
            dateAtBottom = true
        }
        
        return dateAtBottom
    }
    
    public var description: String {
        if let message = self.message {
            return "(ListMessageItem id: \(message.id), text: \"\(message.text)\")"
        } else {
            return "(ListMessageItem empty)"
        }
    }
}
