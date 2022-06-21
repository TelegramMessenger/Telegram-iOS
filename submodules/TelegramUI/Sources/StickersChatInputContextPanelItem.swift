import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import StickerResources
import AccountContext
import ChatPresentationInterfaceState

final class StickersChatInputContextPanelItem: ListViewItem {
    let account: Account
    let theme: PresentationTheme
    let index: Int
    let files: [TelegramMediaFile]
    let itemsInRow: Int
    let stickersInteraction: StickersChatInputContextPanelInteraction
    let interfaceInteraction: ChatPanelInterfaceInteraction
    
    let selectable: Bool = false
    
    public init(account: Account, theme: PresentationTheme, index: Int, files: [TelegramMediaFile], itemsInRow: Int, stickersInteraction: StickersChatInputContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) {
        self.account = account
        self.theme = theme
        self.index = index
        self.files = files
        self.itemsInRow = itemsInRow
        self.stickersInteraction = stickersInteraction
        self.interfaceInteraction = interfaceInteraction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = StickersChatInputContextPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? StickersChatInputContextPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

private let itemSize = CGSize(width: 66.0, height: 66.0)
private let inset: CGFloat = 3.0

final class StickersChatInputContextPanelItemNode: ListViewItemNode {
    private let topSeparatorNode: ASDisplayNode
    private var nodes: [TransformImageNode] = []
    private var item: StickersChatInputContextPanelItem?
    private let disposables = DisposableSet()
    
    private var currentPreviewingIndex: Int?
    
    init() {
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? StickersChatInputContextPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let item = self.item else {
            return
        }
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        for i in 0 ..< self.nodes.count {
            if self.nodes[i].frame.contains(location) {
                let file = item.files[i]
                let _ = item.interfaceInteraction.sendSticker(.standalone(media: file), true, self.nodes[i], self.nodes[i].bounds)
                break
            }
        }
    }
    
    func stickerItem(at index: Int) -> StickerPackItem? {
        guard let item = self.item else {
            return nil
        }
        if index < item.files.count {
            return StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: 0), file: item.files[index], indexKeys: [])
        } else {
            return nil
        }
    }
    
    func stickerItem(at location: CGPoint) -> (StickerPackItem, ASDisplayNode)? {
        guard let item = self.item else {
            return nil
        }
        for i in 0 ..< self.nodes.count {
            if self.nodes[i].frame.contains(location) {
                return (StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: 0), file: item.files[i], indexKeys: []), self.nodes[i])
            }
        }
        return nil
    }
    
    func updatePreviewing(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        var previewingIndex: Int? = nil
        for i in 0 ..< item.files.count {
            if item.stickersInteraction.previewedStickerItem == self.stickerItem(at: i) {
                previewingIndex = i
                break
            }
        }
        
        if self.currentPreviewingIndex != previewingIndex {
            self.currentPreviewingIndex = previewingIndex
            
            for i in 0 ..< self.nodes.count {
                let layer = self.nodes[i].layer
                if i == previewingIndex {
                    layer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                    if animated {
                        let scale = ((layer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.floatValue ?? (layer.value(forKeyPath: "transform.scale") as? NSNumber)?.floatValue) ?? 1.0
                        layer.animateSpring(from: scale as NSNumber, to: 0.8 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    }
                } else {
                    layer.transform = CATransform3DIdentity
                    if animated {
                        let scale = ((layer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.floatValue ?? (layer.value(forKeyPath: "transform.scale") as? NSNumber)?.floatValue) ?? 0.8
                        layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                    }
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: StickersChatInputContextPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { [weak self] item, params, mergedTop, mergedBottom in
            let baseWidth = params.width - params.leftInset - params.rightInset
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 66.0), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.backgroundColor = item.theme.list.plainBackgroundColor
                    strongSelf.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.item = item
                    
                    if item.index == 0 && strongSelf.topSeparatorNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.topSeparatorNode)
                    }
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    
                    let spacing = (baseWidth - itemSize.width * CGFloat(item.itemsInRow)) / (CGFloat(max(1, item.itemsInRow + 1)))
                    
                    var i = 0
                    for file in item.files {
                        let imageNode: TransformImageNode
                        if strongSelf.nodes.count > i {
                            imageNode = strongSelf.nodes[i]
                        } else {
                            imageNode = TransformImageNode()
                            strongSelf.nodes.append(imageNode)
                            strongSelf.addSubnode(imageNode)
                        }
                        
                        imageNode.setSignal(chatMessageSticker(account: item.account, file: file, small: true))
                        strongSelf.disposables.add(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: true)).start())
                        
                        var imageSize = itemSize
                        if let dimensions = file.dimensions {
                            imageSize = dimensions.cgSize.aspectFitted(CGSize(width: itemSize.width - 4.0, height: itemSize.height - 4.0))
                            imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                        }
                        
                        imageNode.frame = CGRect(x: spacing + params.leftInset + (itemSize.width + spacing) * CGFloat(i) + floor((itemSize.width - imageSize.width) / 2.0), y: floor((itemSize.height - imageSize.height) / 2.0), width: imageSize.width, height: imageSize.height)
                        
                        i += 1
                    }
                }
            })
        }
    }
}
