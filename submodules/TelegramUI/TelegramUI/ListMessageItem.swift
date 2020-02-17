import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences

final class ListMessageItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let fontSize: PresentationFontSize
    let dateTimeFormat: PresentationDateTimeFormat
    let context: AccountContext
    let chatLocation: ChatLocation
    let controllerInteraction: ChatControllerInteraction
    let message: Message
    let selection: ChatHistoryMessageSelection
    
    let header: ListMessageDateHeader?
    
    let selectable: Bool = true
    
    public init(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, context: AccountContext, chatLocation: ChatLocation, controllerInteraction: ChatControllerInteraction, message: Message, selection: ChatHistoryMessageSelection, displayHeader: Bool) {
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.dateTimeFormat = dateTimeFormat
        self.context = context
        self.chatLocation = chatLocation
        self.controllerInteraction = controllerInteraction
        self.message = message
        if displayHeader {
            self.header = ListMessageDateHeader(timestamp: message.timestamp, theme: theme, strings: strings, fontSize: fontSize)
        } else {
            self.header = nil
        }
        self.selection = selection
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        var viewClassName: AnyClass = ListMessageSnippetItemNode.self
        
        for media in message.media {
            if let _ = media as? TelegramMediaFile {
                viewClassName = ListMessageFileItemNode.self
                break
            }
        }
        
        let configure = { () -> Void in
            let node = (viewClassName as! ListMessageNode.Type).init()
            node.controllerInteraction = self.controllerInteraction
            node.setupItem(self)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = (previousItem != nil, nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
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
                    let (top, bottom, dateAtBottom) = (previousItem != nil, nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
                    
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
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        if case let .selectable(selected) = self.selection {
            self.controllerInteraction.toggleMessagesSelection([self.message.id], !selected)
        } else {
            listView.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ListMessageFileItemNode {
                    if let messageId = itemNode.item?.message.id, messageId == self.message.id {
                        itemNode.activateMedia()
                    }
                } else if let itemNode = itemNode as? ListMessageSnippetItemNode {
                    if let messageId = itemNode.item?.message.id, messageId == self.message.id {
                        itemNode.activateMedia()
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
        return "(ListMessageItem id: \(self.message.id), text: \"\(self.message.text)\")"
    }
}
