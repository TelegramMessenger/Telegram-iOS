import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListAddressItem
import SwiftSignalKit
import AccountContext

final class PeerInfoScreenAddressItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let text: String
    let imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
    let action: (() -> Void)?
    let longTapAction: ((ASDisplayNode, String) -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    
    init(
        id: AnyHashable,
        label: String,
        text: String,
        imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?,
        action: (() -> Void)?,
        longTapAction: ((ASDisplayNode, String) -> Void)? = nil,
        linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.imageSignal = imageSignal
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.contextAction = contextAction
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenAddressItemNode()
    }
}

private final class PeerInfoScreenAddressItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let maskNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenAddressItem?
    private var itemNode: ItemListAddressItemNode?
    
    private var presentationData: PresentationData?
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.maskNode)
        
        self.contextSourceNode.contentNode.clipsToBounds = true
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        
        self.addSubnode(self.activateArea)
        
        self.containerNode.isGestureEnabled = false
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture, nil)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let presentationData = strongSelf.presentationData else {
                return
            }
            let theme = presentationData.theme
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] _ in
            guard let self, let item = self.item else {
                return .keepWithSingleTap
            }
            
            if item.longTapAction != nil {
                return .waitForSingleTap
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    if let item = self.item {
                        item.action?()
                    }
                case .longTap:
                    if let item = self.item {
                        item.longTapAction?(self, item.text)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenAddressItem else {
            return 10.0
        }
        
        self.item = item
        self.presentationData = presentationData
        
        self.containerNode.isGestureEnabled = item.contextAction != nil
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let addressItem = ItemListAddressItem(theme: presentationData.theme, label: item.label, text: item.text, imageSignal: item.imageSignal, sectionId: 0, style: .blocks, displayDecorations: false, action: nil, longTapAction: nil, linkItemAction: item.linkItemAction)
        
        let params = ListViewItemLayoutParams(width: width, leftInset: safeInsets.left, rightInset: safeInsets.right, availableHeight: 1000.0)
        
        let itemNode: ItemListAddressItemNode
        if let current = self.itemNode {
            itemNode = current
            addressItem.updateNode(async: { $0() }, node: {
                return itemNode
            }, params: params, previousItem: addressItem, nextItem: addressItem, animation: .None, completion: { (layout, apply) in
                let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: layout.size.height))
                
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                itemNode.frame = nodeFrame
                
                apply(ListViewItemApply(isOnScreen: true))
            })
        } else {
            var itemNodeValue: ListViewItemNode?
            addressItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNodeValue = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            itemNode = itemNodeValue as! ItemListAddressItemNode
            itemNode.isUserInteractionEnabled = false
            self.itemNode = itemNode
            self.contextSourceNode.contentNode.addSubnode(itemNode)
        }
        
        let height = itemNode.contentSize.height
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height)))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        self.activateArea.accessibilityLabel = item.label
        
        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        transition.updateFrame(node: self.contextSourceNode.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        
        let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height))
        let extractedRect = nonExtractedRect
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        if self.contextSourceNode.isExtractedToContextPreview {
            self.extractedBackgroundImageNode.frame = extractedRect
        } else {
            self.extractedBackgroundImageNode.frame = nonExtractedRect
        }
        self.contextSourceNode.contentRect = extractedRect
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
    }
}
