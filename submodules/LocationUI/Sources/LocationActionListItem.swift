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
import LiveLocationTimerNode

public enum LocationActionListItemIcon: Equatable {
    case location
    case liveLocation
    case stopLiveLocation
    case venue(TelegramMediaMap)
    
    public static func ==(lhs: LocationActionListItemIcon, rhs: LocationActionListItemIcon) -> Bool {
        switch lhs {
            case .location:
                if case .location = rhs {
                    return true
                } else {
                    return false
                }
            case .liveLocation:
                if case .liveLocation = rhs {
                    return true
                } else {
                    return false
                }
            case .stopLiveLocation:
                if case .stopLiveLocation = rhs {
                    return true
                } else {
                    return false
                }
            case let .venue(lhsVenue):
                if case let .venue(rhsVenue) = rhs, lhsVenue.venue?.id == rhsVenue.venue?.id {
                    return true
                } else {
                    return false
                }
        }
    }
}

private func generateLocationIcon(theme: PresentationTheme) -> UIImage {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(theme.chat.inputPanel.actionControlFillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Location/SendLocationIcon"), color: theme.chat.inputPanel.actionControlForegroundColor) {
            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
        }
    })!
}

private func generateLiveLocationIcon(theme: PresentationTheme, stop: Bool) -> UIImage {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(rgb: stop ? 0xff6464 : 0x6cc139).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: stop ? "Location/SendLocationIcon" : "Location/SendLiveLocationIcon"), color: theme.chat.inputPanel.actionControlForegroundColor) {
            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
        }
    })!
}

final class LocationActionListItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let engine: TelegramEngine
    let title: String
    let subtitle: String
    let icon: LocationActionListItemIcon
    let beginTimeAndTimeout: (Double, Double)?
    let action: () -> Void
    let highlighted: (Bool) -> Void
    
    public init(presentationData: ItemListPresentationData, engine: TelegramEngine, title: String, subtitle: String, icon: LocationActionListItemIcon, beginTimeAndTimeout: (Double, Double)?, action: @escaping () -> Void, highlighted: @escaping (Bool) -> Void = { _ in }) {
        self.presentationData = presentationData
        self.engine = engine
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.beginTimeAndTimeout = beginTimeAndTimeout
        self.action = action
        self.highlighted = highlighted
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationActionListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem is LocationActionListItem || nextItem is LocationLiveListItem)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationActionListItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem is LocationActionListItem || nextItem is LocationLiveListItem)
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

final class LocationActionListItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private let iconNode: ASImageNode
    private let venueIconNode: TransformImageNode
    private var timerNode: ChatMessageLiveLocationTimerNode?
    private var wavesNode: LiveLocationWavesNode?
    
    private var item: LocationActionListItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.venueIconNode = TransformImageNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.venueIconNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem is LocationActionListItem)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.item?.highlighted(highlighted)
        
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
    
    func asyncLayout() -> (_ item: LocationActionListItem, _ params: ListViewItemLayoutParams, _ hasSeparator: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let iconLayout = self.venueIconNode.asyncLayout()
        
        return { [weak self] item, params, hasSeparator in
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let verticalInset: CGFloat = 8.0
            let iconSize: CGFloat = 40.0
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            let titleAttributedString = NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let subtitleAttributedString = NSAttributedString(string: item.subtitle, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            let bottomInset: CGFloat = hasSeparator ? 0.0 : 4.0
            var contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height + bottomInset)
            if hasSeparator {
                contentSize.height = max(52.0, contentSize.height)
            }
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.presentationData.theme !== item.presentationData.theme {
                    updatedTheme = item.presentationData.theme
                }
                
                var updatedIcon: LocationActionListItemIcon?
                if currentItem?.icon != item.icon || updatedTheme != nil {
                    updatedIcon = item.icon
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        }
                        
                        if let updatedIcon = updatedIcon {
                            switch updatedIcon {
                                case .location:
                                    strongSelf.iconNode.isHidden = false
                                    strongSelf.venueIconNode.isHidden = true
                                    strongSelf.iconNode.image = generateLocationIcon(theme: item.presentationData.theme)
                                case .liveLocation, .stopLiveLocation:
                                    strongSelf.iconNode.isHidden = false
                                    strongSelf.venueIconNode.isHidden = true
                                    strongSelf.iconNode.image = generateLiveLocationIcon(theme: item.presentationData.theme, stop: updatedIcon == .stopLiveLocation)
                                case let .venue(venue):
                                    strongSelf.iconNode.isHidden = true
                                    strongSelf.venueIconNode.isHidden = false
                                    strongSelf.venueIconNode.setSignal(venueIcon(engine: item.engine, type: venue.venue?.type ?? "", background: true))
                            }
                            
                            if updatedIcon == .stopLiveLocation {
                                let wavesNode = LiveLocationWavesNode(color: item.presentationData.theme.chat.inputPanel.actionControlForegroundColor)
                                strongSelf.addSubnode(wavesNode)
                                strongSelf.wavesNode = wavesNode
                            } else if let wavesNode = strongSelf.wavesNode {
                                strongSelf.wavesNode = nil
                                wavesNode.removeFromSupernode()
                            }
                            strongSelf.wavesNode?.color = item.presentationData.theme.chat.inputPanel.actionControlForegroundColor
                        }
                        
                        let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: iconSize, height: iconSize), boundingSize: CGSize(width: iconSize, height: iconSize), intrinsicInsets: UIEdgeInsets()))
                        iconApply()
                        
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

                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = separatorHeight
                        
                        let iconNodeFrame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floorToScreenPixels((contentSize.height - bottomInset - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize))
                        strongSelf.iconNode.frame = iconNodeFrame
                        strongSelf.venueIconNode.frame = iconNodeFrame
                        
                        strongSelf.wavesNode?.frame = CGRect(origin: CGPoint(x: params.leftInset + 11.0, y: floorToScreenPixels((contentSize.height - bottomInset - iconSize) / 2.0) - 4.0), size: CGSize(width: 48.0, height: 48.0))
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentSize.width, height: contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: contentSize.width, height: contentSize.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = !hasSeparator
                        
                        if let (beginTimestamp, timeout) = item.beginTimeAndTimeout {
                            let timerNode: ChatMessageLiveLocationTimerNode
                            if let current = strongSelf.timerNode {
                                timerNode = current
                            } else {
                                timerNode = ChatMessageLiveLocationTimerNode()
                                strongSelf.addSubnode(timerNode)
                                strongSelf.timerNode = timerNode
                            }
                            let timerSize = CGSize(width: 28.0, height: 28.0)
                            timerNode.update(backgroundColor: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.4), foregroundColor: item.presentationData.theme.list.itemAccentColor, textColor: item.presentationData.theme.list.itemAccentColor, beginTimestamp: beginTimestamp, timeout: timeout, strings: item.presentationData.strings)
                            timerNode.frame = CGRect(origin: CGPoint(x: contentSize.width - 16.0 - timerSize.width, y: floorToScreenPixels((contentSize.height - timerSize.height) / 2.0) - 2.0), size: timerSize)
                        } else if let timerNode = strongSelf.timerNode {
                            strongSelf.timerNode = nil
                            timerNode.removeFromSupernode()
                        }
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
