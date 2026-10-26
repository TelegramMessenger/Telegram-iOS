import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import LocationResources
import AvatarNode
import LiveLocationTimerNode
import ComponentFlow
import ButtonComponent
import BundleIconComponent

final class LocationLiveListItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable(HeaderNeighborDescriptor(headerId: nil, headerFamily: .locationLive))
    }

    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let message: EngineMessage
    let distance: Double?
    
    let drivingTime: ExpectedTravelTime
    let walkingTime: ExpectedTravelTime
    
    let action: () -> Void
    let longTapAction: () -> Void
    
    let drivingAction: () -> Void
    let walkingAction: () -> Void
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, message: EngineMessage, distance: Double?, drivingTime: ExpectedTravelTime, walkingTime: ExpectedTravelTime, action: @escaping () -> Void, longTapAction: @escaping () -> Void = { }, drivingAction: @escaping () -> Void, walkingAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.message = message
        self.distance = distance
        self.drivingTime = drivingTime
        self.walkingTime = walkingTime
        self.action = action
        self.longTapAction = longTapAction
        self.drivingAction = drivingAction
        self.walkingAction = walkingAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationLiveListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, neighbors.next?.base(HeaderNeighborFacet.self)?.headerFamily == .locationLive)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationLiveListItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, neighbors.next?.base(HeaderNeighborFacet.self)?.headerFamily == .locationLive)
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
    private let highlightedBackgroundNode: ASDisplayNode
    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private let avatarNode: AvatarNode
    private var timerNode: ChatMessageLiveLocationTimerNode?
    
    private let drivingButton = ComponentView<Empty>()
    private let walkingButton = ComponentView<Empty>()
    
    private var item: LocationLiveListItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
    
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.avatarNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, neighbors.next?.base(HeaderNeighborFacet.self)?.headerFamily == .locationLive)
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
                self.insertSubnode(self.highlightedBackgroundNode, at: 0)
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
            let leftInset: CGFloat = 72.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let verticalInset: CGFloat = 8.0
            
            let titleFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            var title: String = ""
            if let author = item.message.author {
                title = author.displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder)
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
            
            let titleSpacing: CGFloat = 0.0
            var contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height)
            var hasEta: Bool
            if case .ready = item.drivingTime {
                hasEta = true
            } else if case .ready = item.walkingTime {
                hasEta = true
            } else {
                hasEta = false
            }
            hasEta = true
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
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.contextMenu.itemHighlightedBackgroundColor
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
                        
                        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                        titleNode.frame = titleFrame
                        
                        let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size)
                        subtitleNode.frame = subtitleFrame

                        let avatarSize: CGFloat = 40.0
                        if let peer = item.message.author {
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: nil, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: false)
                        }
                        
                        strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 22.0, y: 8.0), size: CGSize(width: avatarSize, height: avatarSize))

                        let highlightFrame = CGRect(origin: CGPoint(x: 14.0, y: 2.0), size: CGSize(width: contentSize.width - 14.0 * 2.0, height: 52.0))
                        let highlightCornerRadius = highlightFrame.height * 0.5
                        strongSelf.highlightedBackgroundNode.frame = highlightFrame
                        strongSelf.highlightedBackgroundNode.cornerRadius = highlightCornerRadius
                        
                        var liveBroadcastingTimeout: Int32 = 0
                        if let location = getLocation(from: item.message), let timeout = location.liveBroadcastingTimeout {
                            liveBroadcastingTimeout = timeout
                        }
                        
                        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        let remainingTime: Int32
                        if liveBroadcastingTimeout == liveLocationIndefinitePeriod {
                            remainingTime = liveLocationIndefinitePeriod
                        } else {
                            remainingTime = max(0, item.message.timestamp + liveBroadcastingTimeout - currentTimestamp)
                        }
                        
                        if remainingTime > 0 {
                            let timerNode: ChatMessageLiveLocationTimerNode
                            if let current = strongSelf.timerNode {
                                timerNode = current
                            } else {
                                timerNode = ChatMessageLiveLocationTimerNode()
                                strongSelf.addSubnode(timerNode)
                                strongSelf.timerNode = timerNode
                            }
                            let timerSize = CGSize(width: 24.0, height: 24.0)
                            timerNode.update(backgroundColor: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.4), foregroundColor: item.presentationData.theme.list.itemAccentColor, textColor: item.presentationData.theme.list.itemAccentColor, beginTimestamp: Double(item.message.timestamp), timeout: Int32(liveBroadcastingTimeout) == liveLocationIndefinitePeriod ? -1.0 : Double(liveBroadcastingTimeout), strings: item.presentationData.strings)
                            timerNode.frame = CGRect(origin: CGPoint(x: contentSize.width - 26.0 - timerSize.width, y: floorToScreenPixels((56.0 - timerSize.height) / 2.0)), size: timerSize)
                        } else if let timerNode = strongSelf.timerNode {
                            strongSelf.timerNode = nil
                            timerNode.removeFromSupernode()
                        }
                        
                        let buttonBackground = ButtonComponent.Background(
                            style: .glass,
                            color: item.presentationData.theme.list.itemCheckColors.fillColor,
                            foreground: item.presentationData.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: item.presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        )
                        let foregroundColor = item.presentationData.theme.list.itemCheckColors.foregroundColor
                        var directionsSize = CGSize(width: 96.0, height: 36.0)
                        let directionsSpacing: CGFloat = 8.0
                        
                        var drivingButtonTitle = ""
                        var drivingButtonHasIcon = true
                        var walkingButtonTitle = ""
                        var drivingButtonVisible = false
                        var walkingButtonVisible = false
                                                
                        if case let .ready(drivingTime) = item.drivingTime {
                            drivingButtonTitle = stringForEstimatedDuration(strings: item.presentationData.strings, time: drivingTime, format: { $0 }) ?? ""
                            drivingButtonVisible = true
                            
                            if let previousDrivingTime = currentItem?.drivingTime, case .calculating = previousDrivingTime {
                                strongSelf.drivingButton.view?.alpha = 1.0
                                strongSelf.drivingButton.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        } else {
                            drivingButtonVisible = true
                            if case .unknown = item.walkingTime {
                                drivingButtonHasIcon = false
                                drivingButtonTitle = item.presentationData.strings.Map_GetDirections
                                directionsSize.width = contentSize.width - leftInset * 2.0
                            }
                        }
                        
                        if case let .ready(walkingTime) = item.walkingTime {
                            walkingButtonTitle = stringForEstimatedDuration(strings: item.presentationData.strings, time: walkingTime, format: { $0 }) ?? ""
                            walkingButtonVisible = true
                            
                            if let previousWalkingTime = currentItem?.walkingTime, case .calculating = previousWalkingTime {
                                strongSelf.walkingButton.view?.alpha = 1.0
                                strongSelf.walkingButton.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        var drivingButtonContent: [AnyComponentWithIdentity<Empty>] = []
                        if drivingButtonHasIcon {
                            drivingButtonContent.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Location/DirectionsDriving", tintColor: foregroundColor))))
                        }
                        drivingButtonContent.append(AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(text: drivingButtonTitle, font: Font.semibold(14.0), color: foregroundColor))))
                        
                        let drivingButtonSize = strongSelf.drivingButton.update(
                            transition: .immediate,
                            component: AnyComponent(ButtonComponent(
                                background: buttonBackground,
                                content: AnyComponentWithIdentity(
                                    id: AnyHashable("driving-\(drivingButtonTitle)"),
                                    component: AnyComponent(
                                        HStack(drivingButtonContent, spacing: 2.0)
                                    )
                                ),
                                contentInsets: UIEdgeInsets(),
                                action: { [weak self] in
                                    if let item = self?.item {
                                        item.drivingAction()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: directionsSize
                        )
                        
                        let walkingButtonSize = strongSelf.walkingButton.update(
                            transition: .immediate,
                            component: AnyComponent(ButtonComponent(
                                background: buttonBackground,
                                content: AnyComponentWithIdentity(
                                    id: AnyHashable("walking-\(walkingButtonTitle)"),
                                    component: AnyComponent(
                                        HStack([
                                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Location/DirectionsWalking", tintColor: foregroundColor))),
                                            AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(text: walkingButtonTitle, font: Font.semibold(14.0), color: foregroundColor)))
                                        ], spacing: 0.0)
                                    )
                                ),
                                contentInsets: UIEdgeInsets(),
                                action: { [weak self] in
                                    if let item = self?.item {
                                        item.walkingAction()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: directionsSize
                        )
                              
                        var buttonOrigin = leftInset
                        let drivingButtonFrame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + 12.0), size: drivingButtonSize)
                        if let drivingButtonView = strongSelf.drivingButton.view {
                            if drivingButtonView.superview == nil {
                                strongSelf.view.addSubview(drivingButtonView)
                            }
                            drivingButtonView.frame = drivingButtonFrame
                            if drivingButtonView.layer.animation(forKey: "opacity") == nil {
                                drivingButtonView.alpha = drivingButtonVisible ? 1.0 : 0.0
                            }
                        }
                        
                        if case .ready = item.drivingTime {
                            buttonOrigin += directionsSize.width + directionsSpacing
                        }
                        
                        let walkingButtonFrame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + 12.0), size: walkingButtonSize)
                        if let walkingButtonView = strongSelf.walkingButton.view {
                            if walkingButtonView.superview == nil {
                                strongSelf.view.addSubview(walkingButtonView)
                            }
                            walkingButtonView.frame = walkingButtonFrame
                            if walkingButtonView.layer.animation(forKey: "opacity") == nil {
                                walkingButtonView.alpha = walkingButtonVisible ? 1.0 : 0.0
                            }
                        }
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
}

public extension ListViewItemHeaderFamily {
    static let locationLive = ListViewItemHeaderFamily("locationLive")
}
