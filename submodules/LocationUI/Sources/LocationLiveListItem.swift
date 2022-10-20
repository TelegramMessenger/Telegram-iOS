import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import LocationResources
import AppBundle
import AvatarNode
import LiveLocationTimerNode
import SolidRoundedButtonNode

final class LocationLiveListItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let message: Message
    let distance: Double?
    
    let drivingTime: ExpectedTravelTime
    let transitTime: ExpectedTravelTime
    let walkingTime: ExpectedTravelTime
    
    let action: () -> Void
    let longTapAction: () -> Void
    
    let drivingAction: () -> Void
    let transitAction: () -> Void
    let walkingAction: () -> Void
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, message: Message, distance: Double?, drivingTime: ExpectedTravelTime, transitTime: ExpectedTravelTime, walkingTime: ExpectedTravelTime, action: @escaping () -> Void, longTapAction: @escaping () -> Void = { }, drivingAction: @escaping () -> Void, transitAction: @escaping () -> Void, walkingAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.message = message
        self.distance = distance
        self.drivingTime = drivingTime
        self.transitTime = transitTime
        self.walkingTime = walkingTime
        self.action = action
        self.longTapAction = longTapAction
        self.drivingAction = drivingAction
        self.transitAction = transitAction
        self.walkingAction = walkingAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationLiveListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem is LocationLiveListItem)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationLiveListItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem is LocationLiveListItem)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return true
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(false)
        self.action()
    }
}

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))
final class LocationLiveListItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private let avatarNode: AvatarNode
    private var timerNode: ChatMessageLiveLocationTimerNode?
    
    private var drivingButtonNode: SolidRoundedButtonNode?
    private var transitButtonNode: SolidRoundedButtonNode?
    private var walkingButtonNode: SolidRoundedButtonNode?
    
    private var item: LocationLiveListItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
    
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem is LocationLiveListItem)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
    
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
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
    
    func asyncLayout() -> (_ item: LocationLiveListItem, _ params: ListViewItemLayoutParams, _ hasSeparator: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        return { [weak self] item, params, hasSeparator in
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let verticalInset: CGFloat = 8.0
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            var title: String = ""
            if let author = item.message.author {
                title = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder)
            }
            let titleAttributedString = NSAttributedString(string: title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 54.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var updateTimestamp = item.message.timestamp
            for attribute in item.message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    updateTimestamp = attribute.date
                    break
                }
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let timeString = stringForRelativeLiveLocationTimestamp(strings: item.presentationData.strings, relativeTimestamp: Int32(updateTimestamp), relativeTo: Int32(timestamp), dateTimeFormat: item.dateTimeFormat)
           
            var subtitle = timeString
            if let distance = item.distance {
                let distanceString = item.presentationData.strings.Map_DistanceAway(shortStringForDistance(strings: item.presentationData.strings, distance: Int32(distance))).string
                subtitle = "\(timeString) • \(distanceString)"
            }
            
            let subtitleAttributedString = NSAttributedString(string: subtitle, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 54.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            var contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height)
            let hasEta: Bool
            if case .ready = item.drivingTime {
                hasEta = true
            } else if case .ready = item.transitTime {
                hasEta = true
            } else if case .ready = item.walkingTime {
                hasEta = true
            } else {
                hasEta = false
            }
            if hasEta {
                contentSize.height += 46.0
            }
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.presentationData.theme !== item.presentationData.theme {
                    updatedTheme = item.presentationData.theme
                }
                                
                return (self?.avatarNode.ready, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        }
                        
                        let titleNode = titleApply()
                        if strongSelf.titleNode == nil {
                            strongSelf.titleNode = titleNode
                            strongSelf.addSubnode(titleNode)
                        }
                        
                        let subtitleNode = subtitleApply()
                        if strongSelf.subtitleNode == nil {
                            strongSelf.subtitleNode = subtitleNode
                            strongSelf.addSubnode(subtitleNode)
                        }
                        
                        let buttonTheme = SolidRoundedButtonTheme(theme: item.presentationData.theme)
                        if strongSelf.drivingButtonNode == nil {
                            strongSelf.drivingButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsDriving"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.drivingButtonNode?.alpha = 0.0
                            strongSelf.drivingButtonNode?.iconSpacing = 5.0
                            strongSelf.drivingButtonNode?.allowsGroupOpacity = true
                            strongSelf.drivingButtonNode?.pressed = { [weak self] in
                                if let item = self?.item {
                                    item.drivingAction()
                                }
                            }
                            strongSelf.drivingButtonNode.flatMap { strongSelf.addSubnode($0) }
                            
                            strongSelf.transitButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsTransit"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.transitButtonNode?.alpha = 0.0
                            strongSelf.transitButtonNode?.iconSpacing = 2.0
                            strongSelf.transitButtonNode?.allowsGroupOpacity = true
                            strongSelf.transitButtonNode?.pressed = { [weak self] in
                                if let item = self?.item {
                                    item.transitAction()
                                }
                            }
                            strongSelf.transitButtonNode.flatMap { strongSelf.addSubnode($0) }
                            
                            strongSelf.walkingButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsWalking"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.walkingButtonNode?.alpha = 0.0
                            strongSelf.walkingButtonNode?.iconSpacing = 2.0
                            strongSelf.walkingButtonNode?.allowsGroupOpacity = true
                            strongSelf.walkingButtonNode?.pressed = { [weak self] in
                                if let item = self?.item {
                                    item.walkingAction()
                                }
                            }
                            strongSelf.walkingButtonNode.flatMap { strongSelf.addSubnode($0) }
                        } else if let _ = updatedTheme {
                            strongSelf.drivingButtonNode?.updateTheme(buttonTheme)
                            strongSelf.drivingButtonNode?.icon = generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsDriving"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                            
                            strongSelf.transitButtonNode?.updateTheme(buttonTheme)
                            strongSelf.transitButtonNode?.icon = generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsTransit"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                            
                            strongSelf.walkingButtonNode?.updateTheme(buttonTheme)
                            strongSelf.walkingButtonNode?.icon = generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsWalking"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                        }
                        
                        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                        titleNode.frame = titleFrame
                        
                        let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size)
                        subtitleNode.frame = subtitleFrame

                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = separatorHeight
                        let avatarSize: CGFloat = 40.0
                        
                        if let peer = item.message.author {
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(peer), overrideImage: nil, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: false)
                        }
                        
                        strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 8.0), size: CGSize(width: avatarSize, height: avatarSize))

                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentSize.width, height: contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: contentSize.width, height: contentSize.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = !hasSeparator
                        
                        var liveBroadcastingTimeout: Int32 = 0
                        if let location = getLocation(from: item.message), let timeout = location.liveBroadcastingTimeout {
                            liveBroadcastingTimeout = timeout
                        }
                        
                        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        if currentTimestamp < item.message.timestamp + liveBroadcastingTimeout {
                            let timerNode: ChatMessageLiveLocationTimerNode
                            if let current = strongSelf.timerNode {
                                timerNode = current
                            } else {
                                timerNode = ChatMessageLiveLocationTimerNode()
                                strongSelf.addSubnode(timerNode)
                                strongSelf.timerNode = timerNode
                            }
                            let timerSize = CGSize(width: 28.0, height: 28.0)
                            timerNode.update(backgroundColor: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.4), foregroundColor: item.presentationData.theme.list.itemAccentColor, textColor: item.presentationData.theme.list.itemAccentColor, beginTimestamp: Double(item.message.timestamp), timeout: Double(liveBroadcastingTimeout), strings: item.presentationData.strings)
                            timerNode.frame = CGRect(origin: CGPoint(x: contentSize.width - 16.0 - timerSize.width, y: 14.0), size: timerSize)
                        } else if let timerNode = strongSelf.timerNode {
                            strongSelf.timerNode = nil
                            timerNode.removeFromSupernode()
                        }
                        
                        if case let .ready(drivingTime) = item.drivingTime {
                            strongSelf.drivingButtonNode?.title = stringForEstimatedDuration(strings: item.presentationData.strings, time: drivingTime, format: { $0 })
                            
                            if let previousDrivingTime = currentItem?.drivingTime, case .calculating = previousDrivingTime {
                                strongSelf.drivingButtonNode?.alpha = 1.0
                                strongSelf.drivingButtonNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        if case let .ready(transitTime) = item.transitTime {
                            strongSelf.transitButtonNode?.title = stringForEstimatedDuration(strings: item.presentationData.strings, time: transitTime, format: { $0 })
                            
                            if let previousTransitTime = currentItem?.transitTime, case .calculating = previousTransitTime {
                                strongSelf.transitButtonNode?.alpha = 1.0
                                strongSelf.transitButtonNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        if case let .ready(walkingTime) = item.walkingTime {
                            strongSelf.walkingButtonNode?.title = stringForEstimatedDuration(strings: item.presentationData.strings, time: walkingTime, format: { $0 })
                            
                            if let previousWalkingTime = currentItem?.walkingTime, case .calculating = previousWalkingTime {
                                strongSelf.walkingButtonNode?.alpha = 1.0
                                strongSelf.walkingButtonNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        let directionsWidth: CGFloat = 93.0
                        let directionsSpacing: CGFloat = 8.0
                        let drivingHeight = strongSelf.drivingButtonNode?.updateLayout(width: directionsWidth, transition: .immediate) ?? 0.0
                        let transitHeight = strongSelf.transitButtonNode?.updateLayout(width: directionsWidth, transition: .immediate) ?? 0.0
                        let walkingHeight = strongSelf.walkingButtonNode?.updateLayout(width: directionsWidth, transition: .immediate) ?? 0.0
                              
                        var buttonOrigin = leftInset
                        strongSelf.drivingButtonNode?.frame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + 12.0), size: CGSize(width: directionsWidth, height: drivingHeight))
                        
                        if case .ready = item.drivingTime {
                            buttonOrigin += directionsWidth + directionsSpacing
                        }
                        
                        strongSelf.transitButtonNode?.frame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + 12.0), size: CGSize(width: directionsWidth, height: transitHeight))
                        
                        if case .ready = item.transitTime {
                            buttonOrigin += directionsWidth + directionsSpacing
                        }
                        
                        strongSelf.walkingButtonNode?.frame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + 12.0), size: CGSize(width: directionsWidth, height: walkingHeight))
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
}
