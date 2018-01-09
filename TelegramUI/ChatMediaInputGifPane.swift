import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputGifPane: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private var multiplexedNode: MultiplexedVideoNode?
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    init(account: Account, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        
        super.init()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        self.multiplexedNode?.bottomInset = bottomInset
        self.multiplexedNode?.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.multiplexedNode == nil {
            let multiplexedNode = MultiplexedVideoNode(account: account)
            self.multiplexedNode = multiplexedNode
            if let validLayout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: validLayout)
            }
            
            self.view.addSubview(multiplexedNode)
            let initialOrder = Atomic<[MediaId]?>(value: nil)
            let gifs = self.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)])
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
                    strongSelf.multiplexedNode?.files = gifs
                }
            }))
            
            multiplexedNode.fileSelected = { [weak self] file in
                self?.controllerInteraction.sendGif(file)
            }
            multiplexedNode.fileLongPressed = { [weak self] file in
                if let strongSelf = self, let multiplexedNode = strongSelf.multiplexedNode, let itemFrame = multiplexedNode.frameForItem(file.fileId) {
                    let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                    let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(presentationData.strings.Common_Delete), action: {
                        if let strongSelf = self {
                            let _ = removeSavedGif(postbox: strongSelf.account.postbox, mediaId: file.fileId).start()
                        }
                    })])
                    strongSelf.controllerInteraction.presentController(contextMenuController, ContextMenuControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self, let multiplexedNode = strongSelf.multiplexedNode {
                            return (strongSelf, multiplexedNode.convert(itemFrame, to: strongSelf.view).insetBy(dx: -2.0, dy: -2.0).offsetBy(dx: multiplexedNode.frame.minX, dy: multiplexedNode.frame.minY))
                        } else {
                            return nil
                        }
                    }))
                }
            }
        }
    }
}
