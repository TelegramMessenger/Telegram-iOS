import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputGifPane: ChatMediaInputPane, UIScrollViewDelegate {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private var multiplexedNode: MultiplexedVideoNode?
    private let emptyNode: ImmediateTextNode
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        
        self.emptyNode = ImmediateTextNode()
        self.emptyNode.isLayerBacked = true
        self.emptyNode.attributedText = NSAttributedString(string: strings.Conversation_EmptyGifPanelPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        
        super.init()
        
        self.backgroundColor = theme.chat.inputMediaPanel.gifsBackgroundColor
        
        self.addSubnode(self.emptyNode)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        let emptySize = self.emptyNode.updateLayout(size)
        transition.updateFrame(node: self.emptyNode, frame: CGRect(origin: CGPoint(x: floor(size.width - emptySize.width) / 2.0, y: topInset + floor(size.height - topInset - emptySize.height) / 2.0), size: emptySize))
        
        if let multiplexedNode = self.multiplexedNode {
            multiplexedNode.topInset = topInset
            multiplexedNode.bottomInset = bottomInset
            let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            transition.updateFrame(layer: multiplexedNode.layer, frame: nodeFrame)
            multiplexedNode.updateLayout(size: nodeFrame.size, transition: transition)
        }
    }
    
    func fileAt(point: CGPoint) -> TelegramMediaFile? {
        if let multiplexedNode = self.multiplexedNode {
            return multiplexedNode.fileAt(point: point.offsetBy(dx: -multiplexedNode.frame.minX, dy: -multiplexedNode.frame.minY))
        } else {
            return nil
        }
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
                    strongSelf.emptyNode.isHidden = !gifs.isEmpty
                }
            }))
            
            multiplexedNode.fileSelected = { [weak self] file in
                self?.controllerInteraction.sendGif(file)
            }
        }
    }
}
