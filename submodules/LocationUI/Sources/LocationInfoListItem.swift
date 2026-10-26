import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import LocationResources
import ShimmerEffect
import ComponentFlow
import ButtonComponent
import BundleIconComponent

public final class LocationInfoListItem: ListViewItem {
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let presentationData: ItemListPresentationData
    let engine: TelegramEngine
    let location: TelegramMediaMap
    let address: String?
    let distance: String?
    let drivingTime: ExpectedTravelTime
    let walkingTime: ExpectedTravelTime
    let hasEta: Bool
    let action: () -> Void
    let drivingAction: () -> Void
    let walkingAction: () -> Void
    
    public init(
        presentationData: ItemListPresentationData,
        engine: TelegramEngine,
        location: TelegramMediaMap,
        address: String?,
        distance: String?,
        drivingTime: ExpectedTravelTime,
        walkingTime: ExpectedTravelTime,
        hasEta: Bool,
        action: @escaping () -> Void,
        drivingAction: @escaping () -> Void,
        walkingAction: @escaping () -> Void
    ) {
        self.presentationData = presentationData
        self.engine = engine
        self.location = location
        self.address = address
        self.distance = distance
        self.drivingTime = drivingTime
        self.walkingTime = walkingTime
        self.hasEta = hasEta
        self.action = action
        self.drivingAction = drivingAction
        self.walkingAction = walkingAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationInfoListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
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

public final class LocationInfoListItemNode: ListViewItemNode {
    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private let venueIconNode: TransformImageNode
    private let buttonNode: HighlightableButtonNode
    
    private var placeholderNode: ShimmerEffectNode?
    private let drivingButton = ComponentView<Empty>()
    private let walkingButton = ComponentView<Empty>()
    
    private var item: LocationInfoListItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var absoluteLocation: (CGRect, CGSize)?
    
    required public init() {
        self.buttonNode = HighlightableButtonNode()
        self.venueIconNode = TransformImageNode()
        self.venueIconNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
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
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
        
    public func asyncLayout() -> (_ item: LocationInfoListItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let iconLayout = self.venueIconNode.asyncLayout()
        
        return { [weak self] item, params in
            let leftInset: CGFloat = 78.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let verticalInset: CGFloat = 14.0
            let iconSize: CGFloat = 40.0
            let directionsButtonHeight: CGFloat = 52.0
            let directionsTopInset: CGFloat = 18.0
            
            let titleFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
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
            
            let titleSpacing: CGFloat = 0.0
            let bottomInset: CGFloat = 16.0
            let textContentSize = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height + bottomInset
            let etaContentSize = verticalInset + titleLayout.size.height + titleSpacing + subtitleLayout.size.height + directionsTopInset + directionsButtonHeight + bottomInset
            let contentSize = CGSize(width: params.width, height: item.hasEta ? max(etaContentSize, textContentSize) : textContentSize)
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
                        
                        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                        titleNode.frame = titleFrame
                        
                        let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size)
                        subtitleNode.frame = subtitleFrame
                        
                        let iconNodeFrame = CGRect(origin: CGPoint(x: params.leftInset + 26.0, y: 14.0), size: CGSize(width: iconSize, height: iconSize))
                        strongSelf.venueIconNode.frame = iconNodeFrame
                        
                        let glassInset: CGFloat = 6.0
                        let buttonSideInset: CGFloat = 30.0
                        let buttonSpacing: CGFloat = 10.0
                        var directionsWidth: CGFloat = floorToScreenPixels((params.width - glassInset * 2.0 - buttonSideInset * 2.0 - buttonSpacing) / 2.0)
                        
                        if item.hasEta {
                            let buttonBackground = ButtonComponent.Background(
                                style: .glass,
                                color: item.presentationData.theme.list.itemCheckColors.fillColor,
                                foreground: item.presentationData.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: item.presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            )
                            let foregroundColor = item.presentationData.theme.list.itemCheckColors.foregroundColor
                            
                            var drivingButtonTitle = ""
                            var walkingButtonTitle = ""
                            var drivingButtonHasIcon = true
                            var drivingButtonVisible = false
                            var walkingButtonVisible = false
                            
                            if item.drivingTime == .unknown && item.walkingTime == .unknown {
                                drivingButtonHasIcon = false
                                drivingButtonTitle = item.presentationData.strings.Map_GetDirections
                                drivingButtonVisible = true
                                
                                if let previousDrivingTime = currentItem?.drivingTime, case .calculating = previousDrivingTime {
                                    strongSelf.drivingButton.view?.alpha = 1.0
                                    strongSelf.drivingButton.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                }
                            } else {
                                if case let .ready(drivingTime) = item.drivingTime {
                                    drivingButtonTitle = stringForEstimatedDuration(strings: item.presentationData.strings, time: drivingTime, format: { $0 }) ?? ""
                                    drivingButtonVisible = true
                                    
                                    if let previousDrivingTime = currentItem?.drivingTime, case .calculating = previousDrivingTime {
                                        strongSelf.drivingButton.view?.alpha = 1.0
                                        strongSelf.drivingButton.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
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
                            }
                                                        
                            let drivingButtonContent: AnyComponent<Empty>
                            if drivingButtonHasIcon {
                                drivingButtonContent = AnyComponent(
                                    HStack([
                                        AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Location/DirectionsDriving", tintColor: foregroundColor))),
                                        AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(text: drivingButtonTitle, font: Font.semibold(17.0), color: foregroundColor)))
                                    ], spacing: 5.0)
                                )
                            } else {
                                drivingButtonContent = AnyComponent(Text(text: drivingButtonTitle, font: Font.semibold(17.0), color: foregroundColor))
                            }
                            
                            let drivingButtonSize = strongSelf.drivingButton.update(
                                transition: .immediate,
                                component: AnyComponent(ButtonComponent(
                                    background: buttonBackground,
                                    content: AnyComponentWithIdentity(
                                        id: AnyHashable("driving-\(drivingButtonHasIcon)-\(drivingButtonTitle)"),
                                        component: drivingButtonContent
                                    ),
                                    action: { [weak self] in
                                        if let item = self?.item {
                                            item.drivingAction()
                                        }
                                    }
                                )),
                                environment: {},
                                containerSize: CGSize(width: drivingButtonHasIcon ? directionsWidth : contentSize.width - glassInset * 2.0 - buttonSideInset * 2.0, height: directionsButtonHeight)
                            )
                            if !drivingButtonHasIcon {
                                directionsWidth = drivingButtonSize.width
                            }
                            
                            let walkingButtonSize = strongSelf.walkingButton.update(
                                transition: .immediate,
                                component: AnyComponent(ButtonComponent(
                                    background: buttonBackground,
                                    content: AnyComponentWithIdentity(
                                        id: AnyHashable("walking-\(walkingButtonTitle)"),
                                        component: AnyComponent(
                                            HStack([
                                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Location/DirectionsWalking", tintColor: foregroundColor))),
                                                AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(text: walkingButtonTitle, font: Font.semibold(17.0), color: foregroundColor)))
                                            ], spacing: 2.0)
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
                                containerSize: CGSize(width: directionsWidth, height: directionsButtonHeight)
                            )
                            
                            var buttonOrigin = glassInset + buttonSideInset
                            
                            if case .calculating = item.drivingTime, case .calculating = item.walkingTime {
                                let shimmerNode: ShimmerEffectNode
                                if let current = strongSelf.placeholderNode {
                                    shimmerNode = current
                                } else {
                                    shimmerNode = ShimmerEffectNode()
                                    strongSelf.placeholderNode = shimmerNode
                                    strongSelf.addSubnode(shimmerNode)
                                }
                                shimmerNode.frame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + directionsTopInset), size: CGSize(width: contentSize.width - buttonOrigin * 2.0, height: directionsButtonHeight))
                                if let (rect, size) = strongSelf.absoluteLocation {
                                    shimmerNode.updateAbsoluteRect(rect, within: size)
                                }
                                
                                var shapes: [ShimmerEffectNode.Shape] = []
                                shapes.append(.roundedRectLine(startPoint: CGPoint(x: 0.0, y: 0.0), width: directionsWidth, diameter: directionsButtonHeight))
                                shapes.append(.roundedRectLine(startPoint: CGPoint(x: directionsWidth + buttonSpacing, y: 0.0), width: directionsWidth, diameter: directionsButtonHeight))
                                shapes.append(.roundedRectLine(startPoint: CGPoint(x: directionsWidth + buttonSpacing + directionsWidth + buttonSpacing, y: 0.0), width: directionsWidth, diameter: directionsButtonHeight))
                                
                                shimmerNode.update(backgroundColor: .clear, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: shimmerNode.frame.size, mask: true)
                            } else if let shimmerNode = strongSelf.placeholderNode {
                                strongSelf.placeholderNode = nil
                                shimmerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmerNode] _ in
                                    shimmerNode?.removeFromSupernode()
                                })
                            }
                            
                            
                            let drivingButtonFrame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + directionsTopInset), size: CGSize(width: directionsWidth, height: drivingButtonSize.height))
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
                                buttonOrigin += directionsWidth + buttonSpacing
                            }
                            
                            let walkingButtonFrame = CGRect(origin: CGPoint(x: buttonOrigin, y: subtitleFrame.maxY + directionsTopInset), size: CGSize(width: directionsWidth, height: walkingButtonSize.height))
                            if let walkingButtonView = strongSelf.walkingButton.view {
                                if walkingButtonView.superview == nil {
                                    strongSelf.view.addSubview(walkingButtonView)
                                }
                                walkingButtonView.frame = walkingButtonFrame
                                if walkingButtonView.layer.animation(forKey: "opacity") == nil {
                                    walkingButtonView.alpha = walkingButtonVisible ? 1.0 : 0.0
                                }
                            }
                        } else {
                            strongSelf.drivingButton.view?.alpha = 0.0
                            strongSelf.walkingButton.view?.alpha = 0.0
                            if let shimmerNode = strongSelf.placeholderNode {
                                strongSelf.placeholderNode = nil
                                shimmerNode.removeFromSupernode()
                            }
                        }
                        
                        strongSelf.buttonNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: 72.0)
                    }
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
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
