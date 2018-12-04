import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputGifPane: ChatMediaInputPane, UIScrollViewDelegate {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private let paneDidScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void
    private let fixPaneScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void
    private var multiplexedNode: MultiplexedVideoNode?
    private let emptyNode: ImmediateTextNode
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    private var didScrollPreviousOffset: CGFloat?
    
    private var didScrollPreviousState: ChatMediaInputPaneScrollState?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, paneDidScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void, fixPaneScroll: @escaping  (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        self.paneDidScroll = paneDidScroll
        self.fixPaneScroll = fixPaneScroll
        
        self.emptyNode = ImmediateTextNode()
        self.emptyNode.isUserInteractionEnabled = false
        self.emptyNode.attributedText = NSAttributedString(string: strings.Conversation_EmptyGifPanelPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.emptyNode.textAlignment = .center
        self.emptyNode.maximumNumberOfLines = 3
        
        super.init()
        
        self.backgroundColor = theme.chat.inputMediaPanel.gifsBackgroundColor
        
        self.addSubnode(self.emptyNode)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, transition: ContainedViewLayoutTransition) {
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
    
    func fileAt(point: CGPoint) -> FileMediaReference? {
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
                |> map { view -> [FileMediaReference] in
                    var recentGifs: OrderedItemListView?
                    if let orderedView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] {
                        recentGifs = orderedView as? OrderedItemListView
                    }
                    if let recentGifs = recentGifs {
                        return recentGifs.items.map { item in
                            let file = (item.contents as! RecentMediaItem).media as! TelegramMediaFile
                            return .savedGif(media: file)
                        }
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
            
            multiplexedNode.fileSelected = { [weak self] fileReference in
                self?.controllerInteraction.sendGif(fileReference)
            }
            
            multiplexedNode.didScroll = { [weak self] offset, height in
                guard let strongSelf = self else {
                    return
                }
                let absoluteOffset = -offset
                var delta: CGFloat = 0.0
                if let didScrollPreviousOffset = strongSelf.didScrollPreviousOffset {
                    delta = absoluteOffset - didScrollPreviousOffset
                }
                strongSelf.didScrollPreviousOffset = absoluteOffset
                let state = ChatMediaInputPaneScrollState(absoluteOffset: absoluteOffset, relativeChange: delta)
                strongSelf.didScrollPreviousState = state
                strongSelf.paneDidScroll(strongSelf, state, .immediate)
            }
            
            multiplexedNode.didEndScrolling = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let didScrollPreviousState = strongSelf.didScrollPreviousState {
                    strongSelf.fixPaneScroll(strongSelf, didScrollPreviousState)
                }
            }
        }
    }
}
