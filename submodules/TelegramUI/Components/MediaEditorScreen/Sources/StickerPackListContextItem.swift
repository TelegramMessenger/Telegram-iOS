import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import StickerResources
import ContextUI

final class StickerPackListContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let packs: [(StickerPackCollectionInfo, StickerPackItem?)]
    let packSelected: (StickerPackCollectionInfo) -> Bool
    
    init(context: AccountContext, packs: [(StickerPackCollectionInfo, StickerPackItem?)], packSelected: @escaping (StickerPackCollectionInfo) -> Bool) {
        self.context = context
        self.packs = packs
        self.packSelected = packSelected
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return StickerPackListContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class StickerPackListContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, ASScrollViewDelegate {
    private let item: StickerPackListContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let scrollNode: ASScrollNode
    private let actionNodes: [ContextControllerActionsListActionItemNode]
    private let separatorNodes: [ASDisplayNode]
    
    init(presentationData: PresentationData, item: StickerPackListContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        self.scrollNode = ASScrollNode()
                                
        var actionNodes: [ContextControllerActionsListActionItemNode] = []
        var separatorNodes: [ASDisplayNode] = []
        
        var i = 0
        for (pack, topItem) in item.packs {
            if pack.flags.contains(.isEmoji) {
                continue
            }
            let thumbSize = CGSize(width: 24.0, height: 24.0)
            let thumbnailResource = pack.thumbnail?.resource ?? topItem?.file.resource
            let thumbnailIconSource: ContextMenuActionItemIconSource?
            if let thumbnailResource {
                var resourceId: Int64 = 0
                if let resource = thumbnailResource as? CloudDocumentMediaResource {
                    resourceId = resource.fileId
                }
                let thumbnailFile = topItem?.file ?? TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: resourceId), partialReference: nil, resource: thumbnailResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: thumbnailResource.size ?? 0, attributes: [], alternativeRepresentations: [])

                let _ = freeMediaFileInteractiveFetched(account: item.context.account, userLocation: .other, fileReference: .stickerPack(stickerPack: .id(id: pack.id.id, accessHash: pack.accessHash), media: thumbnailFile)).start()
                thumbnailIconSource = ContextMenuActionItemIconSource(
                    size: thumbSize,
                    signal: chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, resource: thumbnailResource)
                    |> map { generator -> UIImage? in
                        return generator(TransformImageArguments(corners: ImageCorners(), imageSize: thumbSize, boundingSize: thumbSize, intrinsicInsets: .zero))?.generateImage()
                    }
                )
            } else {
                thumbnailIconSource = nil
            }

            let action = ContextMenuActionItem(text: pack.title, textLayout: .singleLine, icon: { _ in nil }, iconSource: thumbnailIconSource, iconPosition: .left, action: { _, f in
                if item.packSelected(pack) {
                    f(.dismissWithoutContent)
                }
            })
            let actionNode = ContextControllerActionsListActionItemNode(getController: getController, requestDismiss: actionSelected, requestUpdateAction: { _, _ in }, item: action)
            actionNodes.append(actionNode)
            if actionNodes.count != item.packs.count {
                let separatorNode = ASDisplayNode()
                separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                separatorNodes.append(separatorNode)
            }
            i += 1
        }
        self.actionNodes = actionNodes
        self.separatorNodes = separatorNodes
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        for separatorNode in self.separatorNodes {
            self.scrollNode.addSubnode(separatorNode)
        }
        for actionNode in self.actionNodes {
            self.scrollNode.addSubnode(actionNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 5.0, right: 0.0)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 250.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        var maxWidth: CGFloat = 0.0
        var contentHeight: CGFloat = 0.0
        var heightsAndCompletions: [(CGFloat, (CGSize, ContainedViewLayoutTransition) -> Void)?] = []
        for i in 0 ..< self.actionNodes.count {
            let itemNode = self.actionNodes[i]
            let (minSize, complete) = itemNode.update(presentationData: self.presentationData, constrainedSize: CGSize(width: constrainedWidth, height: constrainedHeight))
            maxWidth = max(maxWidth, minSize.width)
            heightsAndCompletions.append((minSize.height, complete))
            contentHeight += minSize.height
        }
        
        maxWidth = max(maxWidth, minActionsWidth)
        
        let maxHeight: CGFloat = min(155.0, constrainedHeight - 108.0)
        
        return (CGSize(width: maxWidth, height: min(maxHeight, contentHeight)), { size, transition in
            var verticalOffset: CGFloat = 0.0
            for i in 0 ..< heightsAndCompletions.count {
                let itemNode = self.actionNodes[i]
                if let (itemHeight, itemCompletion) = heightsAndCompletions[i] {
                    let itemSize = CGSize(width: maxWidth, height: itemHeight)
                    transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: itemSize))
                    itemCompletion(itemSize, transition)
                    verticalOffset += itemHeight
                }
                
                if i < self.actionNodes.count - 1 {
                    let separatorNode = self.separatorNodes[i]
                    separatorNode.frame = CGRect(x: 0, y: verticalOffset, width: size.width, height: UIScreenPixel)
                }
            }
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: contentHeight)

        })
    }
    
    func updateTheme(presentationData: PresentationData) {
//        for actionNode in self.actionNodes {
//            actionNode.updateTheme(presentationData: presentationData)
//        }
    }
    
    var isActionEnabled: Bool {
        return true
    }
    
    func performAction() {
    }
    
    func setIsHighlighted(_ value: Bool) {
    }
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
//        for actionNode in self.actionNodes {
//            let frame = actionNode.convert(actionNode.bounds, to: self)
//            if frame.contains(point) {
//                return actionNode
//            }
//        }
        return self
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for actionNode in self.actionNodes {
            actionNode.updateIsHighlighted(isHighlighted: false)
        }
    }
}
