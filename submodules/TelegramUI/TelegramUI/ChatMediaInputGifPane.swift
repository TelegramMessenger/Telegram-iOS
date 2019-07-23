import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData

private func fixListScrolling(_ multiplexedNode: MultiplexedVideoNode) {
    let searchBarHeight: CGFloat = 56.0
    
    let contentOffset = multiplexedNode.view.contentOffset.y
    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
    
    if contentOffset < 60.0 {
        if contentOffset < searchBarHeight * 0.6 {
            transition.updateBounds(layer: multiplexedNode.layer, bounds: CGRect(origin: CGPoint(), size: multiplexedNode.bounds.size))
        } else {
            transition.updateBounds(layer: multiplexedNode.layer, bounds: CGRect(origin: CGPoint(x: 0.0, y: 60.0), size: multiplexedNode.bounds.size))
        }
    }
}

final class ChatMediaInputGifPane: ChatMediaInputPane, UIScrollViewDelegate {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private let paneDidScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void
    private let fixPaneScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void
    
    let searchPlaceholderNode: PaneSearchBarPlaceholderNode
    private var multiplexedNode: MultiplexedVideoNode?
    private let emptyNode: ImmediateTextNode
    
    private let disposable = MetaDisposable()
    let trendingPromise = Promise<[FileMediaReference]?>(nil)
    
    private var validLayout: (CGSize, CGFloat, CGFloat, Bool, Bool)?
    private var didScrollPreviousOffset: CGFloat?
    
    private var didScrollPreviousState: ChatMediaInputPaneScrollState?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, paneDidScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void, fixPaneScroll: @escaping  (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        self.paneDidScroll = paneDidScroll
        self.fixPaneScroll = fixPaneScroll
        
        self.searchPlaceholderNode = PaneSearchBarPlaceholderNode()
        
        self.emptyNode = ImmediateTextNode()
        self.emptyNode.isUserInteractionEnabled = false
        self.emptyNode.attributedText = NSAttributedString(string: strings.Gif_NoGifsPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.emptyNode.textAlignment = .center
        self.emptyNode.maximumNumberOfLines = 3
        
        super.init()
        
        self.addSubnode(self.emptyNode)
        
        self.searchPlaceholderNode.activate = { [weak self] in
            self?.inputNodeInteraction?.toggleSearch(true, .gif)
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.emptyNode.attributedText = NSAttributedString(string: strings.Gif_NoGifsPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        
        self.searchPlaceholderNode.setup(theme: theme, strings: strings, type: .gifs)
        
        if let layout = self.validLayout {
            self.updateLayout(size: layout.0, topInset: layout.1, bottomInset: layout.2, isExpanded: layout.3, isVisible: layout.4, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, transition: ContainedViewLayoutTransition) {
        var changedIsExpanded = false
        if let (_, _, _, previousIsExpanded, _) = self.validLayout {
            if previousIsExpanded != isExpanded {
                changedIsExpanded = true
            }
        }
        self.validLayout = (size, topInset, bottomInset, isExpanded, isVisible)
        
        let emptySize = self.emptyNode.updateLayout(size)
        transition.updateFrame(node: self.emptyNode, frame: CGRect(origin: CGPoint(x: floor(size.width - emptySize.width) / 2.0, y: topInset + floor(size.height - topInset - emptySize.height) / 2.0), size: emptySize))
        
        if let multiplexedNode = self.multiplexedNode {
            let previousBounds = multiplexedNode.layer.bounds
            multiplexedNode.topInset = topInset + 60.0
            multiplexedNode.bottomInset = bottomInset
            let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
    
            var targetBounds = CGRect(origin: previousBounds.origin, size: nodeFrame.size)
            if changedIsExpanded {
                targetBounds.origin.y = isExpanded || multiplexedNode.files.isEmpty ? 0.0 : 60.0
            }
            
            transition.updateBounds(layer: multiplexedNode.layer, bounds: targetBounds)
            transition.updatePosition(layer: multiplexedNode.layer, position: nodeFrame.center)
            
            multiplexedNode.updateLayout(size: nodeFrame.size, transition: transition)
            self.searchPlaceholderNode.frame = CGRect(x: 0.0, y: 41.0, width: size.width, height: 56.0)
        }
    }
    
    func fileAt(point: CGPoint) -> (FileMediaReference, CGRect)? {
        if let multiplexedNode = self.multiplexedNode {
            return multiplexedNode.fileAt(point: point.offsetBy(dx: -multiplexedNode.frame.minX, dy: -multiplexedNode.frame.minY))
        } else {
            return nil
        }
    }
    
    override var isEmpty: Bool {
        return self.multiplexedNode?.files.isEmpty ?? true
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.multiplexedNode == nil {
            self.trendingPromise.set(paneGifSearchForQuery(account: account, query: "", updateActivity: nil))
            
            let multiplexedNode = MultiplexedVideoNode(account: account)
            self.multiplexedNode = multiplexedNode
            if let layout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: layout.0)
            }
            
            self.addSubnode(multiplexedNode)
            multiplexedNode.addSubnode(self.searchPlaceholderNode)
            
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
                    let previousFiles = strongSelf.multiplexedNode?.files
                    strongSelf.multiplexedNode?.files = gifs
                    strongSelf.emptyNode.isHidden = !gifs.isEmpty
                    if (previousFiles ?? []).isEmpty && !gifs.isEmpty {
                        strongSelf.multiplexedNode?.view.contentOffset = CGPoint(x: 0.0, y: 60.0)
                    }
                }
            }))
            
            multiplexedNode.fileSelected = { [weak self] fileReference, sourceNode, sourceRect in
                self?.controllerInteraction.sendGif(fileReference, sourceNode, sourceRect)
            }
            
            multiplexedNode.didScroll = { [weak self] offset, height in
                guard let strongSelf = self else {
                    return
                }
                let absoluteOffset = -offset + 60.0
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
                
                if let multiplexedNode = strongSelf.multiplexedNode {
                    fixListScrolling(multiplexedNode)
                }
            }
        }
    }
}
