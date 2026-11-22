import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences
import ItemListUI

public final class ListMessageItemInteraction {
    public let openMessage: (EngineRawMessage, ChatControllerInteractionOpenMessageMode) -> Bool
    public let openMessageContextMenu: (EngineRawMessage, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void
    public let toggleMessagesSelection: ([EngineMessage.Id], Bool) -> Void
    public let toggleMediaPlayback: ((EngineRawMessage) -> Void)?
    let openUrl: (String, Bool, Bool?, EngineRawMessage?) -> Void
    let openInstantPage: (EngineRawMessage, ChatMessageItemAssociatedData?) -> Void
    let longTap: (ChatControllerInteractionLongTapAction, EngineRawMessage?) -> Void
    let getHiddenMedia: () -> [EngineMessage.Id: [EngineRawMedia]]
    
    public var searchTextHighightState: String?
    public var preferredStoryHighQuality: Bool = false
    
    public init(
        openMessage: @escaping (EngineRawMessage, ChatControllerInteractionOpenMessageMode) -> Bool,
        openMessageContextMenu: @escaping (EngineRawMessage, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void,
        toggleMediaPlayback: ((EngineRawMessage) -> Void)?,
        toggleMessagesSelection: @escaping ([EngineMessage.Id], Bool) -> Void,
        openUrl: @escaping (String, Bool, Bool?, EngineRawMessage?) -> Void,
        openInstantPage: @escaping (EngineRawMessage, ChatMessageItemAssociatedData?) -> Void,
        longTap: @escaping (ChatControllerInteractionLongTapAction, EngineRawMessage?) -> Void,
        getHiddenMedia: @escaping () -> [EngineMessage.Id: [EngineRawMedia]]
    ) {
        self.openMessage = openMessage
        self.openMessageContextMenu = openMessageContextMenu
        self.toggleMediaPlayback = toggleMediaPlayback
        self.toggleMessagesSelection = toggleMessagesSelection
        self.openUrl = openUrl
        self.openInstantPage = openInstantPage
        self.longTap = longTap
        self.getHiddenMedia = getHiddenMedia
    }
    
    public static var `default`: ListMessageItemInteraction = ListMessageItemInteraction(openMessage: { _, _ in
        return false
    }, openMessageContextMenu: { _, _, _, _, _ in
    }, toggleMediaPlayback: nil, toggleMessagesSelection: { _, _ in
    },
    openUrl: { _, _, _, _ in
    }, openInstantPage: { _, _ in
    }, longTap: { _, _ in
    }, getHiddenMedia: { () -> [EngineMessage.Id : [EngineRawMedia]] in
        return [:]
    })
}

public enum ListMessageItemSelectionSide {
    case left
    case right
}

public final class ListMessageItem: ListViewItem, ItemListItem {
    let presentationData: ChatPresentationData
    let systemStyle: ItemListSystemStyle
    let context: AccountContext
    let chatLocation: ChatLocation
    let interaction: ListMessageItemInteraction
    let message: EngineRawMessage?
    let translateToLanguage: String?
    public let selection: ChatHistoryMessageSelection
    public let selectionSide: ListMessageItemSelectionSide
    let hintIsLink: Bool
    let isGlobalSearchResult: Bool
    let isDownloadList: Bool
    let isSavedMusic: Bool
    /// Non-nil when this row is a synthesized track of a rich message's audio queue.
    let richMessageQueueId: EngineMessage.Id?
    let isStoryMusic: Bool
    let isAttachMusic: Bool
    let displayFileInfo: Bool
    let displayBackground: Bool
    let canReorder: Bool
    let style: ItemListStyle
    
    let header: ListViewItemHeader?

    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ItemListHeaderNeighborDescriptor(
            sectionId: self.sectionId,
            isAlwaysPlain: self.isAlwaysPlain,
            requestsNoInset: self.requestsNoInset,
            isTextItem: false,
            hasActiveRevealOptions: false,
            headerId: self.header?.id,
            headerFamily: .listMessage
        ))
    }
    
    public var sectionId: ItemListSectionId
    
    public let selectable: Bool = true
    
    public init(
        presentationData: ChatPresentationData,
        systemStyle: ItemListSystemStyle = .legacy,
        context: AccountContext,
        chatLocation: ChatLocation,
        interaction: ListMessageItemInteraction,
        message: EngineRawMessage?,
        translateToLanguage: String? = nil,
        selection: ChatHistoryMessageSelection,
        selectionSide: ListMessageItemSelectionSide = .right,
        displayHeader: Bool,
        customHeader: ListViewItemHeader? = nil,
        hintIsLink: Bool = false,
        isGlobalSearchResult: Bool = false,
        isDownloadList: Bool = false,
        isSavedMusic: Bool = false,
        isStoryMusic: Bool = false,
        isAttachMusic: Bool = false,
        displayFileInfo: Bool = true,
        displayBackground: Bool = false,
        canReorder: Bool = false,
        richMessageQueueId: EngineMessage.Id? = nil,
        style: ItemListStyle = .plain,
        sectionId: ItemListSectionId = 0
    ) {
        self.presentationData = presentationData
        self.systemStyle = systemStyle
        self.context = context
        self.chatLocation = chatLocation
        self.interaction = interaction
        self.message = message
        self.translateToLanguage = translateToLanguage
        if let header = customHeader {
            self.header = header
        } else if displayHeader, let message = message {
            self.header = ListMessageDateHeader(timestamp: message.timestamp, theme: presentationData.theme.theme, strings: presentationData.strings, fontSize: presentationData.fontSize)
        } else {
            self.header = nil
        }
        self.selection = selection
        self.selectionSide = selectionSide
        self.hintIsLink = hintIsLink
        self.isGlobalSearchResult = isGlobalSearchResult
        self.isDownloadList = isDownloadList
        self.isSavedMusic = isSavedMusic
        self.richMessageQueueId = richMessageQueueId
        self.isStoryMusic = isStoryMusic
        self.isAttachMusic = isAttachMusic
        self.displayFileInfo = displayFileInfo
        self.displayBackground = displayBackground
        self.canReorder = canReorder
        self.style = style
        self.sectionId = sectionId
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        var viewClassName: AnyClass = ListMessageSnippetItemNode.self
        
        if !self.hintIsLink {
            if let message = self.message {
                for media in message.effectiveMedia {
                    if let _ = media as? TelegramMediaFile {
                        viewClassName = ListMessageFileItemNode.self
                        break
                    } else if let _ = media as? TelegramMediaImage {
                        viewClassName = ListMessageFileItemNode.self
                        break
                    } else if let _ = media as? TelegramMediaStory {
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
            
            var topMerged = false
            if neighbors.previous != nil {
                if let previousItem = neighbors.previous?.base(ItemListNeighborFacet.self), previousItem.sectionId == self.sectionId && !previousItem.isAlwaysPlain {
                    topMerged = true
                }
            }
            
            var bottomMerged = false
            if neighbors.next != nil {
                if let nextItem = neighbors.next?.base(ItemListNeighborFacet.self), nextItem.sectionId == self.sectionId && !nextItem.isAlwaysPlain {
                    bottomMerged = true
                }
            }
            
            
            let (top, bottom, dateAtBottom) = (topMerged, bottomMerged, self.getDateAtBottom(top: neighbors.previous))
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ListMessageNode {
                nodeValue.setupItem(self)
                
                nodeValue.updateSelectionState(animated: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                var topMerged = false
                if neighbors.previous != nil {
                    if let previousItem = neighbors.previous?.base(ItemListNeighborFacet.self), previousItem.sectionId == self.sectionId && !previousItem.isAlwaysPlain {
                        topMerged = true
                    }
                }
                
                var bottomMerged = false
                if neighbors.next != nil {
                    if let nextItem = neighbors.next?.base(ItemListNeighborFacet.self), nextItem.sectionId == self.sectionId && !nextItem.isAlwaysPlain {
                        bottomMerged = true
                    }
                }
                
                async {
                    let (top, bottom, dateAtBottom) = (topMerged, bottomMerged, self.getDateAtBottom(top: neighbors.previous))
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
        
        if case let .selectable(selected, _) = self.selection {
            self.interaction.toggleMessagesSelection([message.id], !selected)
        } else {
            if !self.displayFileInfo || self.isAttachMusic {
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
    
    func getDateAtBottom(top: AnyEquatable?) -> Bool {
        var dateAtBottom = false
        if let top = top?.base(HeaderNeighborFacet.self), top.headerFamily == .listMessage, top.headerId != nil {
            if top.headerId != self.header?.id {
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

public extension ListViewItemHeaderFamily {
    static let listMessage = ListViewItemHeaderFamily("listMessage")
}
