import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import ContextUI

private func fixListScrolling(_ multiplexedNode: MultiplexedVideoNode) {
    let searchBarHeight: CGFloat = 56.0
    
    let contentOffset = multiplexedNode.scrollNode.view.contentOffset.y
    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
    
    if contentOffset < 60.0 {
        if contentOffset < searchBarHeight * 0.6 {
            transition.updateBounds(layer: multiplexedNode.scrollNode.layer, bounds: CGRect(origin: CGPoint(), size: multiplexedNode.bounds.size))
        } else {
            transition.updateBounds(layer: multiplexedNode.scrollNode.layer, bounds: CGRect(origin: CGPoint(x: 0.0, y: 60.0), size: multiplexedNode.bounds.size))
        }
    }
}

final class ChatMediaInputGifPane: ChatMediaInputPane, UIScrollViewDelegate {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let controllerInteraction: ChatControllerInteraction
    
    private let paneDidScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void
    private let fixPaneScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void
    private let openGifContextMenu: (MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void
    
    private let searchPlaceholderNode: PaneSearchBarPlaceholderNode
    var visibleSearchPlaceholderNode: PaneSearchBarPlaceholderNode? {
        guard let scrollNode = multiplexedNode?.scrollNode else {
            return nil
        }
        if scrollNode.bounds.contains(self.searchPlaceholderNode.frame) {
            return self.searchPlaceholderNode
        }
        return nil
    }
    
    private var multiplexedNode: MultiplexedVideoNode?
    private let emptyNode: ImmediateTextNode
    
    private let disposable = MetaDisposable()
    let trendingPromise = Promise<[MultiplexedVideoNodeFile]?>(nil)
    
    private var validLayout: (CGSize, CGFloat, CGFloat, Bool, Bool, DeviceMetrics)?
    private var didScrollPreviousOffset: CGFloat?
    
    private var didScrollPreviousState: ChatMediaInputPaneScrollState?
    
    private(set) var mode: ChatMediaInputGifMode = .recent
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, paneDidScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void, fixPaneScroll: @escaping  (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void, openGifContextMenu: @escaping (MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.controllerInteraction = controllerInteraction
        self.paneDidScroll = paneDidScroll
        self.fixPaneScroll = fixPaneScroll
        self.openGifContextMenu = openGifContextMenu
        
        self.searchPlaceholderNode = PaneSearchBarPlaceholderNode()
        
        self.emptyNode = ImmediateTextNode()
        self.emptyNode.isUserInteractionEnabled = false
        self.emptyNode.attributedText = NSAttributedString(string: strings.Gif_NoGifsPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.emptyNode.textAlignment = .center
        self.emptyNode.maximumNumberOfLines = 3
        self.emptyNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.emptyNode)
        
        self.searchPlaceholderNode.activate = { [weak self] in
            self?.inputNodeInteraction?.toggleSearch(true, .gif, "")
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.emptyNode.attributedText = NSAttributedString(string: strings.Gif_NoGifsPlaceholder, font: Font.regular(15.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        
        self.searchPlaceholderNode.setup(theme: theme, strings: strings, type: .gifs)
        
        if let layout = self.validLayout {
            self.updateLayout(size: layout.0, topInset: layout.1, bottomInset: layout.2, isExpanded: layout.3, isVisible: layout.4, deviceMetrics: layout.5, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        var changedIsExpanded = false
        if let (_, _, _, previousIsExpanded, _, _) = self.validLayout {
            if previousIsExpanded != isExpanded {
                changedIsExpanded = true
            }
        }
        self.validLayout = (size, topInset, bottomInset, isExpanded, isVisible, deviceMetrics)
        
        let emptySize = self.emptyNode.updateLayout(size)
        transition.updateFrame(node: self.emptyNode, frame: CGRect(origin: CGPoint(x: floor(size.width - emptySize.width) / 2.0, y: topInset + floor(size.height - topInset - emptySize.height) / 2.0), size: emptySize))
        
        self.updateMultiplexedNodeLayout(changedIsExpanded: changedIsExpanded, transition: transition)
    }
    
    func fileAt(point: CGPoint) -> (MultiplexedVideoNodeFile, CGRect, Bool)? {
        if let multiplexedNode = self.multiplexedNode {
            return multiplexedNode.fileAt(point: point.offsetBy(dx: -multiplexedNode.frame.minX, dy: -multiplexedNode.frame.minY))
        } else {
            return nil
        }
    }
    
    func setMode(mode: ChatMediaInputGifMode) {
        if self.mode == mode {
            return
        }
        self.mode = mode
        self.resetMode(synchronous: true)
    }
    
    override var isEmpty: Bool {
        if let files = self.multiplexedNode?.files {
            return files.trending.isEmpty && files.saved.isEmpty
        } else {
            return true
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.initializeIfNeeded()
    }
    
    private func updateMultiplexedNodeLayout(changedIsExpanded: Bool, transition: ContainedViewLayoutTransition) {
        guard let (size, topInset, bottomInset, _, _, deviceMetrics) = self.validLayout else {
            return
        }
        
        if let multiplexedNode = self.multiplexedNode {
            let _ = multiplexedNode.scrollNode.layer.bounds
            
            let displaySearch: Bool
            
            switch self.mode {
            case .recent:
                displaySearch = true
            default:
                displaySearch = false
            }
            
            multiplexedNode.topInset = topInset + (displaySearch ? 60.0 : 0.0)
            multiplexedNode.bottomInset = bottomInset

            if case .tablet = deviceMetrics.type, size.width > 480.0 {
                multiplexedNode.idealHeight = 120.0
            } else {
                multiplexedNode.idealHeight = 93.0
            }
            
            let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))

            /*var targetBounds = CGRect(origin: previousBounds.origin, size: nodeFrame.size)
            if changedIsExpanded {
                let isEmpty = multiplexedNode.files.trending.isEmpty && multiplexedNode.files.saved.isEmpty
                //targetBounds.origin.y = isExpanded || isEmpty ? 0.0 : 60.0
            }*/
            
            //transition.updateBounds(layer: multiplexedNode.scrollNode.layer, bounds: targetBounds)
            transition.updateFrame(node: multiplexedNode, frame: nodeFrame)
            
            multiplexedNode.updateLayout(theme: self.theme, strings: self.strings, size: nodeFrame.size, transition: transition)
            self.searchPlaceholderNode.frame = CGRect(x: 0.0, y: 41.0, width: size.width, height: 56.0)
        }
    }
    
    func initializeIfNeeded() {
        if self.multiplexedNode == nil {
            self.trendingPromise.set(paneGifSearchForQuery(account: account, query: "", offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
            |> map { items -> [MultiplexedVideoNodeFile]? in
                if let (items, _) = items {
                    return items
                } else {
                    return nil
                }
            })
            
            let multiplexedNode = MultiplexedVideoNode(account: self.account, theme: self.theme, strings: self.strings)
            self.multiplexedNode = multiplexedNode
            if let layout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: layout.0)
            }
            
            multiplexedNode.reactionSelected = { [weak self] reaction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.inputNodeInteraction?.toggleSearch(true, .gif, reaction)
            }
            
            self.addSubnode(multiplexedNode)
            multiplexedNode.scrollNode.addSubnode(self.searchPlaceholderNode)
            
            multiplexedNode.fileSelected = { [weak self] file, sourceNode, sourceRect in
                if let (collection, result) = file.contextResult {
                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect)
                } else {
                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode, sourceRect)
                }
            }
            
            multiplexedNode.fileContextMenu = { [weak self] fileReference, sourceNode, sourceRect, gesture, isSaved in
                self?.openGifContextMenu(fileReference, sourceNode, sourceRect, gesture, isSaved)
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
                    //fixListScrolling(multiplexedNode)
                }
            }
            
            self.updateMultiplexedNodeLayout(changedIsExpanded: false, transition: .immediate)

            self.resetMode(synchronous: false)
        }
    }
    
    private func resetMode(synchronous: Bool) {
        let filesSignal: Signal<MultiplexedVideoNodeFiles, NoError>
        switch self.mode {
        case .recent:
            filesSignal = combineLatest(self.trendingPromise.get(), self.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]))
            |> map { trending, view -> MultiplexedVideoNodeFiles in
                var recentGifs: OrderedItemListView?
                if let orderedView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] {
                    recentGifs = orderedView as? OrderedItemListView
                }
                
                var saved: [MultiplexedVideoNodeFile] = []
                
                if let recentGifs = recentGifs {
                    saved = recentGifs.items.map { item in
                        let file = (item.contents as! RecentMediaItem).media as! TelegramMediaFile
                        return MultiplexedVideoNodeFile(file: .savedGif(media: file), contextResult: nil)
                    }
                } else {
                    saved = []
                }
                
                return MultiplexedVideoNodeFiles(saved: saved, trending: trending ?? [], isSearch: false)
            }
        case .trending:
            filesSignal = self.trendingPromise.get()
            |> map { trending -> MultiplexedVideoNodeFiles in
                return MultiplexedVideoNodeFiles(saved: [], trending: trending ?? [], isSearch: true)
            }
        case let .emojiSearch(emoji):
            filesSignal = paneGifSearchForQuery(account: self.account, query: emoji, offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
            |> map { trending -> MultiplexedVideoNodeFiles in
                return MultiplexedVideoNodeFiles(saved: [], trending: trending?.0 ?? [], isSearch: true)
            }
        }
        
        var firstTime = true
        
        self.disposable.set((filesSignal
        |> deliverOnMainQueue).start(next: { [weak self] files in
            if let strongSelf = self {
                //let previousFiles = strongSelf.multiplexedNode?.files
                var resetScrollingToOffset: CGFloat?
                if firstTime {
                    firstTime = false
                    resetScrollingToOffset = 0.0
                }
                
                let displaySearch: Bool
                
                switch strongSelf.mode {
                case .recent:
                    displaySearch = true
                default:
                    displaySearch = false
                }
                
                strongSelf.searchPlaceholderNode.isHidden = !displaySearch
                
                if let (_, topInset, _, _, _, _) = strongSelf.validLayout {
                    strongSelf.multiplexedNode?.topInset = topInset + (displaySearch ? 60.0 : 0.0)
                }
                
                strongSelf.multiplexedNode?.setFiles(files: files, synchronous: synchronous, resetScrollingToOffset: resetScrollingToOffset)
                
                /*let wasEmpty: Bool
                if let previousFiles = previousFiles {
                    wasEmpty = previousFiles.trending.isEmpty && previousFiles.saved.isEmpty
                } else {
                    wasEmpty = true
                }
                let isEmpty = files.trending.isEmpty && files.saved.isEmpty
                strongSelf.emptyNode.isHidden = !isEmpty*/
            }
        }))
    }
}
