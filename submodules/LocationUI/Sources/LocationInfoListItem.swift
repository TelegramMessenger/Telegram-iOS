import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import LocationResources
import AppBundle
import SolidRoundedButtonNode
import ShimmerEffect

final class LocationInfoListItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let engine: TelegramEngine
    let location: TelegramMediaMap
    let address: String?
    let distance: String?
    let drivingTime: ExpectedTravelTime
    let transitTime: ExpectedTravelTime
    let walkingTime: ExpectedTravelTime
    let action: () -> Void
    let drivingAction: () -> Void
    let transitAction: () -> Void
    let walkingAction: () -> Void
    
    public init(presentationData: ItemListPresentationData, engine: TelegramEngine, location: TelegramMediaMap, address: String?, distance: String?, drivingTime: ExpectedTravelTime, transitTime: ExpectedTravelTime, walkingTime: ExpectedTravelTime, action: @escaping () -> Void, drivingAction: @escaping () -> Void, transitAction: @escaping () -> Void, walkingAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.engine = engine
        self.location = location
        self.address = address
        self.distance = distance
        self.drivingTime = drivingTime
        self.transitTime = transitTime
        self.walkingTime = walkingTime
        self.action = action
        self.drivingAction = drivingAction
        self.transitAction = transitAction
        self.walkingAction = walkingAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationInfoListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationInfoListItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
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
        return false
    }
}

final class LocationInfoListItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private let venueIconNode: TransformImageNode
    private let buttonNode: HighlightableButtonNode
    
    private var placeholderNode: ShimmerEffectNode?
    private var drivingButtonNode: SolidRoundedButtonNode?
    private var transitButtonNode: SolidRoundedButtonNode?
    private var walkingButtonNode: SolidRoundedButtonNode?
    
    private var item: LocationInfoListItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var absoluteLocation: (CGRect, CGSize)?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.buttonNode = HighlightableButtonNode()
        self.venueIconNode = TransformImageNode()
        self.venueIconNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.venueIconNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode?.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode?.alpha = 0.4
                    strongSelf.subtitleNode?.layer.removeAnimation(forKey: "opacity")
                    strongSelf.subtitleNode?.alpha = 0.4
                    strongSelf.venueIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.venueIconNode.alpha = 0.4
                } else {
                    strongSelf.titleNode?.alpha = 1.0
                    strongSelf.titleNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.subtitleNode?.alpha = 1.0
                    strongSelf.subtitleNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.venueIconNode.alpha = 1.0
                    strongSelf.venueIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
        
    func asyncLayout() -> (_ item: LocationInfoListItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let iconLayout = self.venueIconNode.asyncLayout()
        
        return { [weak self] item, params in
            let leftInset: CGFloat = 75.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let verticalInset: CGFloat = 14.0
            let iconSize: CGFloat = 48.0
            let inset: CGFloat = 15.0
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            let title: String
            let subtitle: String
            var subtitleComponents: [String] = []
            
            if let venue = item.location.venue {
                title = venue.title
            } else {
                title = item.presentationData.strings.Map_Location
            }
            
            if let address = item.address {
                subtitleComponents.append(address)
            }
            if let distance = item.distance {
                subtitleComponents.append(distance)
            }
            
            subtitle = subtitleComponents.joined(separator: " • ")
            
            let titleAttributedString = NSAttributedString(string: title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let subtitleAttributedString = NSAttributedString(string: subtitle, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            let bottomInset: CGFloat = 4.0
            let contentSize = CGSize(width: params.width, height: max(100.0, verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height + bottomInset))
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.presentationData.theme !== item.presentationData.theme {
                    updatedTheme = item.presentationData.theme
                }
                
                var updatedLocation: TelegramMediaMap?
                if currentItem?.location.venue?.id != item.location.venue?.id || updatedTheme != nil {
                    updatedLocation = item.location
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                        }
                        
                        let arguments = VenueIconArguments(defaultBackgroundColor: item.presentationData.theme.chat.inputPanel.actionControlFillColor, defaultForegroundColor: item.presentationData.theme.chat.inputPanel.actionControlForegroundColor)
                        if let updatedLocation = updatedLocation {
                            strongSelf.venueIconNode.setSignal(venueIcon(engine: item.engine, type: updatedLocation.venue?.type ?? "", background: true))
                        }
                        
                        let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: iconSize, height: iconSize), boundingSize: CGSize(width: iconSize, height: iconSize), intrinsicInsets: UIEdgeInsets(), custom: arguments))
                        iconApply()
                        
                        let titleNode = titleApply()
                        if strongSelf.titleNode == nil {
                            titleNode.isUserInteractionEnabled = false
                            strongSelf.titleNode = titleNode
                            strongSelf.addSubnode(titleNode)
                        }
                        
                        let subtitleNode = subtitleApply()
                        if strongSelf.subtitleNode == nil {
                            subtitleNode.isUserInteractionEnabled = false
                            strongSelf.subtitleNode = subtitleNode
                            strongSelf.addSubnode(subtitleNode)
                        }
                        
                        let buttonTheme = SolidRoundedButtonTheme(theme: item.presentationData.theme)
                        if strongSelf.drivingButtonNode == nil {
                            strongSelf.drivingButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsDriving"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.drivingButtonNode?.iconSpacing = 5.0
                            strongSelf.drivingButtonNode?.alpha = 0.0
                            strongSelf.drivingButtonNode?.allowsGroupOpacity = true
                            strongSelf.drivingButtonNode?.pressed = { [weak self] in
                                if let item = self?.item {
                                    item.drivingAction()
                                }
                            }
                            strongSelf.drivingButtonNode.flatMap { strongSelf.addSubnode($0) }
                            
                            strongSelf.transitButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsTransit"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.transitButtonNode?.iconSpacing = 2.0
                            strongSelf.transitButtonNode?.alpha = 0.0
                            strongSelf.transitButtonNode?.allowsGroupOpacity = true
                            strongSelf.transitButtonNode?.pressed = { [weak self] in
                                if let item = self?.item {
                                    item.transitAction()
                                }
                            }
                            strongSelf.transitButtonNode.flatMap { strongSelf.addSubnode($0) }
                            
                            strongSelf.walkingButtonNode = SolidRoundedButtonNode(icon: generateTintedImage(image: UIImage(bundleImageName: "Location/DirectionsWalking"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor), theme: buttonTheme, fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
                            strongSelf.walkingButtonNode?.iconSpacing = 2.0
                            strongSelf.walkingButtonNode?.alpha = 0.0
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
                        
                        let iconNodeFrame = CGRect(origin: CGPoint(x: params.leftInset + inset, y: 10.0), size: CGSize(width: iconSize, height: iconSize))
                        strongSelf.venueIconNode.frame = iconNodeFrame
                        
                        var directionsWidth: CGFloat = 93.0
                        
                        if item.drivingTime == .unknown && item.transitTime == .unknown && item.walkingTime == .unknown {
                            strongSelf.drivingButtonNode?.icon = nil
                            strongSelf.drivingButtonNode?.title = item.presentationData.strings.Map_GetDirections
                            if let drivingButtonNode = strongSelf.drivingButtonNode {
                                let buttonSize = drivingButtonNode.sizeThatFits(contentSize)
                                directionsWidth = buttonSize.width
                            }
                            
                            if let previousDrivingTime = currentItem?.drivingTime, case .calculating = previousDrivingTime {
                                strongSelf.drivingButtonNode?.alpha = 1.0
                                strongSelf.drivingButtonNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        } else {
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
                        }
                        
                        let directionsSpacing: CGFloat = 8.0
                        
                        if case .calculating = item.drivingTime, case .calculating = item.transitTime, case .calculating = item.walkingTime {
                            let shimmerNode: ShimmerEffectNode
                            if let current = strongSelf.placeholderNode {
                                shimmerNode = current
                            } else {
                                shimmerNode = ShimmerEffectNode()
                                strongSelf.placeholderNode = shimmerNode
                                strongSelf.addSubnode(shimmerNode)
                            }
                            shimmerNode.frame = CGRect(origin: CGPoint(x: leftInset, y: subtitleFrame.maxY + 12.0), size: CGSize(width: contentSize.width - leftInset, height: 32.0))
                            if let (rect, size) = strongSelf.absoluteLocation {
                                shimmerNode.updateAbsoluteRect(rect, within: size)
                            }
                            
                            var shapes: [ShimmerEffectNode.Shape] = []
                            shapes.append(.roundedRectLine(startPoint: CGPoint(x: 0.0, y: 0.0), width: directionsWidth, diameter: 32.0))
                            shapes.append(.roundedRectLine(startPoint: CGPoint(x: directionsWidth + directionsSpacing, y: 0.0), width: directionsWidth, diameter: 32.0))
                            shapes.append(.roundedRectLine(startPoint: CGPoint(x: directionsWidth + directionsSpacing + directionsWidth + directionsSpacing, y: 0.0), width: directionsWidth, diameter: 32.0))
                            
                            shimmerNode.update(backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: shimmerNode.frame.size)
                        } else if let shimmerNode = strongSelf.placeholderNode {
                            strongSelf.placeholderNode = nil
                            shimmerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmerNode] _ in
                                shimmerNode?.removeFromSupernode()
                            })
                        }
                        
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
                        
                        strongSelf.buttonNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: 72.0)
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentSize.width, height: contentSize.height))
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
    
    @objc private func buttonPressed() {
        self.item?.action()
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
}
