import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting

public class ItemListCallListItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let messages: [Message]
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let displayDecorations: Bool
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, messages: [Message], sectionId: ItemListSectionId, style: ItemListStyle, displayDecorations: Bool = true) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.messages = messages
        self.sectionId = sectionId
        self.style = style
        self.displayDecorations = displayDecorations
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListCallListItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListCallListItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private func stringForCallType(message: Message, strings: PresentationStrings) -> String {
    var string = ""
    for media in message.media {
        switch media {
            case let action as TelegramMediaAction:
                switch action.action {
                    case let .phoneCall(_, discardReason, _, isVideo):
                        let incoming = message.flags.contains(.Incoming)
                        if let discardReason = discardReason {
                            switch discardReason {
                            case .disconnect:
                                if isVideo {
                                    string = strings.Notification_VideoCallCanceled
                                } else {
                                    string = strings.Notification_CallCanceled
                                }
                            case .missed, .busy:
                                if incoming {
                                    if isVideo {
                                        string = strings.Notification_VideoCallMissed
                                    } else {
                                        string = strings.Notification_CallMissed
                                    }
                                } else {
                                    if isVideo {
                                        string = strings.Notification_VideoCallCanceled
                                    } else {
                                        string = strings.Notification_CallCanceled
                                    }
                                }
                            case .hangup:
                                break
                            }
                        }
                        
                        if string.isEmpty {
                            if incoming {
                                if isVideo {
                                    string = strings.Notification_VideoCallIncoming
                                } else {
                                    string = strings.Notification_CallIncoming
                                }
                            } else {
                                if isVideo {
                                    string = strings.Notification_VideoCallOutgoing
                                } else {
                                    string = strings.Notification_CallOutgoing
                                }
                            }
                        }
                    default:
                        break
                }
                    
            default:
                break
        }
    }
    return string
}

public class ItemListCallListItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    let titleNode: TextNode
    var callNodes: [(TextNode, TextNode)]
    
    private let accessibilityArea: AccessibilityAreaNode
    
    private var item: ItemListCallListItem?
    
    override public var canBeSelected: Bool {
        return false
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
    
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.isAccessibilityElement = false
        
        self.callNodes = []
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.accessibilityArea)
    }
    
    public func asyncLayout() -> (_ item: ItemListCallListItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let currentItem = self.item
        
        return { [weak self] item, params, neighbors in
            if let strongSelf = self, strongSelf.callNodes.count != item.messages.count {
                for pair in strongSelf.callNodes {
                    pair.0.removeFromSupernode()
                    pair.1.removeFromSupernode()
                }
                
                strongSelf.callNodes = []
                
                for _ in item.messages {
                    let timeNode = TextNode()
                    timeNode.isUserInteractionEnabled = false
                    strongSelf.addSubnode(timeNode)
                    
                    let typeNode = TextNode()
                    typeNode.isUserInteractionEnabled = false
                    strongSelf.addSubnode(typeNode)
                    
                    strongSelf.callNodes.append((timeNode, typeNode))
                }
            }
            
            var makeNodesLayout: [((TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode), (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode))] = []
            if let strongSelf = self {
                for nodes in strongSelf.callNodes {
                    let makeTimeLayout = TextNode.asyncLayout(nodes.0)
                    let makeTypeLayout = TextNode.asyncLayout(nodes.1)
                    makeNodesLayout.append((makeTimeLayout, makeTypeLayout))
                }
            }
    
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let titleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let font = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let typeFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            let contentSize: CGSize
            var contentHeight: CGFloat = 0.0
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            
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
            
            if !item.displayDecorations {
                insets = UIEdgeInsets()
            }
            
            let earliestMessage = item.messages.sorted(by: {$0.timestamp < $1.timestamp}).first!
            let titleText = stringForDate(timestamp: earliestMessage.timestamp, strings: item.presentationData.strings)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleText, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            contentHeight += titleLayout.size.height + 18.0
            
            var index = 0
            var nodesLayout: [(TextNodeLayout, TextNodeLayout)] = []
            var nodesApply: [(() -> TextNode, () -> TextNode)] = []
            for message in item.messages {
                let makeTimeLayout = makeNodesLayout[index].0
                let time = stringForMessageTimestamp(timestamp: message.timestamp, dateTimeFormat: item.dateTimeFormat)
                let (timeLayout, timeApply) = makeTimeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: time, font: font, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let makeTypeLayout = makeNodesLayout[index].1
                let type = stringForCallType(message: message, strings: item.presentationData.strings)
                let (typeLayout, typeApply) = makeTypeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: type, font: typeFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                nodesLayout.append((timeLayout, typeLayout))
                nodesApply.append((timeApply, typeApply))
             
                contentHeight += timeLayout.size.height + 12.0
                
                index += 1
            }
            
            contentSize = CGSize(width: params.width, height: contentHeight)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    for apply in nodesApply {
                        let _ = apply.0()
                        let _ = apply.1()
                    }
                    
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
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
                        switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = !item.displayDecorations
                        }
                        strongSelf.bottomStripeNode.isHidden = !item.displayDecorations
                        strongSelf.backgroundNode.isHidden = !item.displayDecorations
                        let bottomStripeInset: CGFloat
                        switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                        default:
                            bottomStripeInset = 0.0
                        }
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: titleLayout.size)
                    
                    var index = 0
                    var yOffset = strongSelf.titleNode.frame.maxY + 10.0
                    for nodes in strongSelf.callNodes {
                        let layout = nodesLayout[index]
                        nodes.0.frame = CGRect(origin: CGPoint(x: leftInset, y: yOffset), size: layout.0.size)
                        nodes.1.frame = CGRect(origin: CGPoint(x: leftInset + 75.0, y: yOffset), size: layout.1.size)
                        
                        yOffset += layout.0.size.height + 12.0
                        index += 1
                    }
                    
                    strongSelf.accessibilityArea.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

