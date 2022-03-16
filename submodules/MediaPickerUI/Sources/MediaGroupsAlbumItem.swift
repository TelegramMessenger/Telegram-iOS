import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AppBundle

class MediaGroupsAlbumItem: ListViewItem, ListViewItemWithHeader {
    enum Icon {
        case bursts
        case panoramas
        case screenshots
        case selfPortraits
        case slomoVideos
        case timelapses
        case videos
        case animated
        case depthEffect
        case livePhotos
        case hidden
        
        var image: UIImage? {
            switch self {
                case .bursts:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Burst")
                case .panoramas:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Panorama")
                case .screenshots:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Screenshot")
                case .selfPortraits:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Selfie")
                case .slomoVideos:
                    return UIImage(bundleImageName: "Chat/Attach Menu/SloMo")
                case .timelapses:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Timelapse")
                case .videos:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Video")
                case .animated:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Animated")
                case .depthEffect:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Portrait")
                case .livePhotos:
                    return UIImage(bundleImageName: "Chat/Attach Menu/LivePhoto")
                case .hidden:
                    return UIImage(bundleImageName: "Chat/Attach Menu/Hidden")
            }
        }
    }
    let presentationData: ItemListPresentationData
    let title: String
    let count: String
    let icon: Icon?
    let action: () -> Void
    let header: ListViewItemHeader? = nil
    
    init(presentationData: ItemListPresentationData, title: String, count: String, icon: Icon?, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.title = title
        self.count = count
        self.icon = icon
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MediaGroupsAlbumItemNode()
            let (first, last) = MediaGroupsAlbumItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (layout, apply) = node.asyncLayout()(self, params, first, last)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? MediaGroupsAlbumItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (first, last) = MediaGroupsAlbumItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (layout, apply) = makeLayout(self, params, first, last)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    public func selected(listView: ListView){
        self.action()
        
        listView.clearHighlightAnimated(true)
    }
    
    static func mergeType(item: MediaGroupsAlbumItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool) {
        var first = false
        var last = false

        if let previousItem = previousItem, !(previousItem is MediaGroupsAlbumItem) {
            first = true
        }
        if nextItem == nil {
            last = true
        }
       
        return (first, last)
    }
}

class MediaGroupsAlbumItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private let countNode: TextNode
    private let arrowNode: ASImageNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: MediaGroupsAlbumItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.countNode = TextNode()
        self.countNode.isUserInteractionEnabled = false
        self.countNode.contentMode = .left
        self.countNode.contentsScale = UIScreen.main.scale
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.countNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.activateArea)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    func asyncLayout() -> (_ item: MediaGroupsAlbumItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeCountLayout = TextNode.asyncLayout(self.countNode)
        let currentItem = self.item
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let titleFont = Font.regular(21.0)
            let countFont = Font.regular(17.0)
            
            let leftInset: CGFloat = 60.0 + params.leftInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - 10.0 - leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (countLayout, countApply) = makeCountLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.count, font: countFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - 10.0 - leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentHeight: CGFloat = 48.0
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = UIEdgeInsets()
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: layout.contentSize.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.iconNode.image = generateTintedImage(image: item.icon?.image, color: item.presentationData.theme.list.itemAccentColor)
                        strongSelf.arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                    }
                    
                    strongSelf.addSubnode(strongSelf.activateArea)
                    
                    let _ = titleApply()
                    let _ = countApply()

                    let titleOffset = leftInset
                    let hideBottomStripe: Bool = last
                    
                    if let image = strongSelf.iconNode.image {
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 14.0, y: floorToScreenPixels((contentSize.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    
                    strongSelf.topStripeNode.isHidden = true
                    strongSelf.bottomStripeNode.isHidden = hideBottomStripe
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: titleOffset, y: floorToScreenPixels((contentSize.height - titleLayout.size.height) / 2.0) + 1.0), size: titleLayout.size)
                                        
                    if let arrowSize = strongSelf.arrowNode.image?.size {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - arrowSize.width - 12.0, y: floorToScreenPixels((contentSize.height - arrowSize.height) / 2.0)), size: arrowSize)
                        
                        strongSelf.countNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - countLayout.size.width - arrowSize.width - 12.0 - 2.0, y: floorToScreenPixels((contentSize.height - countLayout.size.height) / 2.0) + 1.0), size: countLayout.size)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
