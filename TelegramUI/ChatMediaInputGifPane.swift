import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputGifPane: ASDisplayNode, UIScrollViewDelegate {
    private let multiplexedNode: MultiplexedVideoNode
    
    private let disposable = MetaDisposable()
    
    init(account: Account, controllerInteraction: ChatControllerInteraction) {
        self.multiplexedNode = MultiplexedVideoNode(account: account)
        
        super.init()
        
        self.view.addSubview(self.multiplexedNode)
        let initialOrder = Atomic<[MediaId]?>(value: nil)
        let gifs = account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)])
            |> map { view -> [TelegramMediaFile] in
                var recentGifs: OrderedItemListView?
                if let orderedView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] {
                    recentGifs = orderedView as? OrderedItemListView
                }
                if let recentGifs = recentGifs {
                    return recentGifs.items.map { ($0.contents as! RecentMediaItem).media as! TelegramMediaFile }
                } else {
                    return []
                }
        }
        self.disposable.set((gifs |> deliverOnMainQueue).start(next: { [weak self] gifs in
            if let strongSelf = self {
                strongSelf.multiplexedNode.files = gifs
            }
        }))
        
        self.multiplexedNode.fileSelected = { file in
            controllerInteraction.sendGif(file)
        }
        self.multiplexedNode.fileLongPressed = { [weak self] file in
            if let strongSelf = self, let itemFrame = strongSelf.multiplexedNode.frameForItem(file.fileId) {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text("Delete"), action: {
                    let _ = removeSavedGif(postbox: account.postbox, mediaId: file.fileId).start()
                })])
                controllerInteraction.presentController(contextMenuController, ContextMenuControllerPresentationArguments(sourceNodeAndRect: {
                    if let strongSelf = self {
                        return (strongSelf, strongSelf.multiplexedNode.convert(itemFrame, to: strongSelf.view).insetBy(dx: -2.0, dy: -2.0).offsetBy(dx: strongSelf.multiplexedNode.frame.minX, dy: strongSelf.multiplexedNode.frame.minY))
                    } else {
                        return nil
                    }
                }))
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.multiplexedNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
    }
}
