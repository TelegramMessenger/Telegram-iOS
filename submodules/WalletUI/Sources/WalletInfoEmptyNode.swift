import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode
import SwiftSignalKit
import AppBundle

class WalletInfoEmptyItem: ListViewItem {
    let theme: WalletTheme
    let strings: WalletStrings
    let address: String
    let loading: Bool
    let displayAddressContextMenu: (ASDisplayNode, CGRect) -> Void
    
    let selectable: Bool = false
    
    init(theme: WalletTheme, strings: WalletStrings, address: String, loading: Bool, displayAddressContextMenu: @escaping (ASDisplayNode, CGRect) -> Void) {
        self.theme = theme
        self.strings = strings
        self.address = address
        self.loading = loading
        self.displayAddressContextMenu = displayAddressContextMenu
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletInfoEmptyItemNode()
            node.insets = UIEdgeInsets()
            node.layoutForParams(params, item: self, previousItem: previousItem, nextItem: nextItem)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is WalletInfoEmptyItemNode)
            if let nodeValue = node() as? WalletInfoEmptyItemNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

final class WalletInfoEmptyItemNode: ListViewItemNode {
    private let offsetContainer: ASDisplayNode
    private let animationNode: AnimatedStickerNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let addressNode: TextNode
    
    private var item: WalletInfoEmptyItem?
    
    init() {
        self.offsetContainer = ASDisplayNode()
        
        self.animationNode = AnimatedStickerNode()
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.textNode = TextNode()
        self.addressNode = TextNode()
        
        super.init(layerBacked: false)
        
        self.wantsTrailingItemSpaceUpdates = true
        
        self.offsetContainer.addSubnode(self.animationNode)
        self.offsetContainer.addSubnode(self.titleNode)
        self.offsetContainer.addSubnode(self.textNode)
        self.offsetContainer.addSubnode(self.addressNode)
        self.addSubnode(self.offsetContainer)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            return .waitForSingleTap
        }
        self.addressNode.view.addGestureRecognizer(recognizer)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .longTap:
                    self.item?.displayAddressContextMenu(self, self.addressNode.frame)
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! WalletInfoEmptyItem, params)
        apply()
    }
    
    func asyncLayout() -> (_ item: WalletInfoEmptyItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        
        return { [weak self] item, params in
            var iconSpacing: CGFloat = 5.0
            var titleSpacing: CGFloat = 19.0
            var iconSize = CGSize(width: 140.0, height: 140.0)
            let contentVerticalOrigin: CGFloat = 10.0
            
            let sideInset: CGFloat = 16.0
            var iconOffset = CGPoint()
            
            let title = item.strings.Wallet_Info_WalletCreated
            let text = item.strings.Wallet_Info_Address
            
            let textColor = item.theme.list.itemPrimaryTextColor
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: Font.bold(32.0), textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - sideInset * 2.0, height: .greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.1, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: Font.regular(16.0), textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - sideInset * 2.0, height: .greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.1, cutout: nil, insets: UIEdgeInsets()))
            
            var addressString = item.address
            addressString.insert("\n", at: addressString.index(addressString.startIndex, offsetBy: addressString.count / 2))
            let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: addressString, font: Font.monospace(16.0), textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - sideInset * 2.0, height: .greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.1, cutout: nil, insets: UIEdgeInsets()))
            
            let availableHeight = params.availableHeight - contentVerticalOrigin * 2.0
            
            let rawContentHeight: CGFloat = iconSize.height + titleLayout.size.height + textLayout.size.height + addressLayout.size.height
            let contentSpacing = iconSpacing + titleSpacing + titleSpacing
            let contentSpacingFactor = max(0.2, min(1.0, (availableHeight - rawContentHeight) / contentSpacing))
            
            if contentSpacingFactor < 0.25 {
                iconSize = CGSize(width: 90.0, height: 90.0)
            }
            
            iconSpacing = floor(iconSpacing * contentSpacingFactor)
            titleSpacing = floor(titleSpacing * contentSpacingFactor)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((params.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
            let titleFrame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.size.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleLayout.size)
            let textFrame = CGRect(origin: CGPoint(x: floor((params.width - textLayout.size.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textLayout.size)
            let addressFrame = CGRect(origin: CGPoint(x: floor((params.width - addressLayout.size.width) / 2.0), y: textFrame.maxY + titleSpacing), size: addressLayout.size)
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: (item.loading ? iconFrame.maxY : addressFrame.maxY) + contentVerticalOrigin), insets: UIEdgeInsets())
            
            return (layout, {
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.item?.loading != item.loading {
                    if item.loading {
                        if let path = getAppBundle().path(forResource: "WalletInitializing", ofType: "tgs") {
                            strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 280, height: 280, playbackMode: .loop, mode: .direct)
                            strongSelf.animationNode.visibility = true
                        }
                    } else {
                        if let path = getAppBundle().path(forResource: "WalletEmpty", ofType: "tgs") {
                            strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 280, height: 280, playbackMode: .once, mode: .direct)
                            strongSelf.animationNode.visibility = true
                        }
                    }
                }
                
                strongSelf.item = item
                
                strongSelf.animationNode.updateLayout(size: iconSize)
                
                strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                
                let _ = titleApply()
                let _ = textApply()
                let _ = addressApply()
                    
                let transition: ContainedViewLayoutTransition = .immediate
                
                transition.updateFrameAdditive(node: strongSelf.animationNode, frame: iconFrame)
                strongSelf.animationNode.updateLayout(size: iconFrame.size)
                transition.updateFrameAdditive(node: strongSelf.animationNode, frame: iconFrame)
                transition.updateFrameAdditive(node: strongSelf.titleNode, frame: titleFrame)
                transition.updateFrameAdditive(node: strongSelf.textNode, frame: textFrame)
                transition.updateFrameAdditive(node: strongSelf.addressNode, frame: addressFrame)
                
                strongSelf.titleNode.isHidden = item.loading
                strongSelf.textNode.isHidden = item.loading
                strongSelf.addressNode.isHidden = item.loading
                    
                strongSelf.contentSize = layout.contentSize
                strongSelf.insets = layout.insets
            })
        }
    }
    
    override func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels(height / 2.0)), size: self.offsetContainer.bounds.size))
        }
    }
}
