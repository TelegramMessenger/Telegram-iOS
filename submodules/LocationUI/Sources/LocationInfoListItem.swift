import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import LocationResources
import AppBundle
import SolidRoundedButtonNode

final class LocationInfoListItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let account: Account
    let location: TelegramMediaMap
    let address: String?
    let distance: String?
    let eta: String?
    let action: () -> Void
    let getDirections: () -> Void
    
    public init(presentationData: ItemListPresentationData, account: Account, location: TelegramMediaMap, address: String?, distance: String?, eta: String?, action: @escaping () -> Void, getDirections: @escaping () -> Void) {
        self.presentationData = presentationData
        self.account = account
        self.location = location
        self.address = address
        self.distance = distance
        self.eta = eta
        self.action = action
        self.getDirections = getDirections
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
    private var directionsButtonNode: SolidRoundedButtonNode?
    
    private var item: LocationInfoListItem?
    private var layoutParams: ListViewItemLayoutParams?
    
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
            let contentSize = CGSize(width: params.width, height: max(126.0, verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height + bottomInset))
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
                            strongSelf.directionsButtonNode?.updateTheme(SolidRoundedButtonTheme(theme: item.presentationData.theme))
                        }
                        
                        if let updatedLocation = updatedLocation {
                            strongSelf.venueIconNode.setSignal(venueIcon(postbox: item.account.postbox, type: updatedLocation.venue?.type ?? "", background: true))
                        }
                        
                        let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: iconSize, height: iconSize), boundingSize: CGSize(width: iconSize, height: iconSize), intrinsicInsets: UIEdgeInsets()))
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
                        
                        let directionsButtonNode: SolidRoundedButtonNode
                        if let currentDirectionsButtonNode = strongSelf.directionsButtonNode {
                            directionsButtonNode = currentDirectionsButtonNode
                        } else {
                            directionsButtonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: item.presentationData.theme), height: 50.0, cornerRadius: 10.0)
                            directionsButtonNode.title = item.presentationData.strings.Map_Directions
                            directionsButtonNode.pressed = {
                                item.getDirections()
                            }
                            strongSelf.addSubnode(directionsButtonNode)
                            strongSelf.directionsButtonNode = directionsButtonNode
                        }
                        directionsButtonNode.subtitle = item.eta
                        
                        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                        titleNode.frame = titleFrame
                        
                        let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size)
                        subtitleNode.frame = subtitleFrame

                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = separatorHeight
                        
                        let iconNodeFrame = CGRect(origin: CGPoint(x: params.leftInset + inset, y: 10.0), size: CGSize(width: iconSize, height: iconSize))
                        strongSelf.venueIconNode.frame = iconNodeFrame
                        
                        let directionsWidth = contentSize.width - inset * 2.0
                        let directionsHeight = directionsButtonNode.updateLayout(width: directionsWidth, transition: .immediate)
                        directionsButtonNode.frame = CGRect(x: inset, y: iconNodeFrame.maxY + 14.0, width: directionsWidth, height: directionsHeight)
                        
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
}
