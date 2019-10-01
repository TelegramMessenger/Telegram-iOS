import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import QrCode

class WalletQrCodeItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let address: String
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    public let isAlwaysPlain: Bool = true
    
    init(theme: PresentationTheme, address: String, sectionId: ItemListSectionId, style: ItemListStyle, action: @escaping () -> Void, longTapAction: @escaping () -> Void) {
        self.theme = theme
        self.address = address
        self.sectionId = sectionId
        self.style = style
        self.action = action
        self.longTapAction = longTapAction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletQrCodeItemNode()
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? WalletQrCodeItemNode {
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

class WalletQrCodeItemNode: ListViewItemNode {
    private let imageNode: TransformImageNode
    
    private var item: WalletQrCodeItem?
    
    var tag: Any? {
        return self.item?.tag
    }
    
    init() {
        self.imageNode = TransformImageNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            self?.imageNode.alpha = point != nil ? 0.4 : 1.0
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.item?.action?()
                case .longTap:
                    self.item?.longTapAction?()
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    func asyncLayout() -> (_ item: WalletQrCodeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            var updatedAddress: String?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            if currentItem?.address != item.address || updatedTheme != nil {
                updatedAddress = item.address
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let inset: CGFloat = 0.0
            var imageSize = CGSize(width: 128.0, height: 128.0)
            let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
            
            switch item.style {
            case .plain:
                contentSize = CGSize(width: params.width, height: imageSize.height + 30.0)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                contentSize = CGSize(width: params.width, height: imageSize.height + 30.0)
                insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let updatedAddress = updatedAddress {
                        strongSelf.imageNode.setSignal(qrCode(string: updatedAddress, color: item.theme.list.itemPrimaryTextColor.withAlphaComponent(0.77), backgroundColor: item.theme.list.blocksBackgroundColor, icon: .custom(UIImage(bundleImageName: "Wallet/QrGem"))), attemptSynchronously: true)
                    }
                    
                    let _ = imageApply()
                        
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: (params.width - imageSize.width) / 2.0, y: 0.0), size: imageSize)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
