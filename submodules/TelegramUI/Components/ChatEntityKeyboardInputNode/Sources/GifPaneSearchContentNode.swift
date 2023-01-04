import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import ChatControllerInteraction
import MultiplexedVideoNode
import ChatPresentationInterfaceState

final class GifPaneSearchContentNode: ASDisplayNode & PaneSearchContentNode {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var multiplexedNode: MultiplexedVideoNode?
    private let notFoundNode: ASImageNode
    private let notFoundLabel: ImmediateTextNode
    
    private var nextOffset: (String, String)?
    private var isLoadingNextResults: Bool = false
    
    private var validLayout: CGSize?
    
    private let trendingPromise: Promise<ChatMediaInputGifPaneTrendingState?>
    private let searchDisposable = MetaDisposable()
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    var deactivateSearchBar: (() -> Void)?
    var updateActivity: ((Bool) -> Void)?
    var requestUpdateQuery: ((String) -> Void)?
    var openGifContextMenu: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void)?
    
    private var hasInitialText = false
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, trendingPromise: Promise<ChatMediaInputGifPaneTrendingState?>) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.inputNodeInteraction = inputNodeInteraction
        self.trendingPromise = trendingPromise
        
        self.theme = theme
        self.strings = strings
        
        self.notFoundNode = ASImageNode()
        self.notFoundNode.displayWithoutProcessing = true
        self.notFoundNode.displaysAsynchronously = false
        self.notFoundNode.clipsToBounds = false
        
        self.notFoundLabel = ImmediateTextNode()
        self.notFoundLabel.displaysAsynchronously = false
        self.notFoundLabel.isUserInteractionEnabled = false
        self.notFoundNode.addSubnode(self.notFoundLabel)
        
        super.init()
        
        self.notFoundNode.isHidden = true
        
        self._ready.set(.single(Void()))
        
        self.addSubnode(self.notFoundNode)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    func updateText(_ text: String, languageCode: String?) {
        self.hasInitialText = true
        self.isLoadingNextResults = true
        
        let signal: Signal<([MultiplexedVideoNodeFile], String?)?, NoError>
        if !text.isEmpty {
            signal = paneGifSearchForQuery(context: self.context, query: text, offset: "", updateActivity: self.updateActivity)
            |> map { result -> ([MultiplexedVideoNodeFile], String?)? in
                if let result = result {
                    return (result.files, result.nextOffset)
                } else {
                    return nil
                }
            }
            self.updateActivity?(true)
        } else {
            signal = self.trendingPromise.get()
            |> map { items -> ([MultiplexedVideoNodeFile], String?)? in
                if let items = items {
                    return (items.files, nil)
                } else {
                    return nil
                }
            }
            self.updateActivity?(false)
        }
        
        self.searchDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self, let (result, nextOffset) = result else {
                return
            }
            
            strongSelf.isLoadingNextResults = false
            if let nextOffset = nextOffset {
                strongSelf.nextOffset = (text, nextOffset)
            } else {
                strongSelf.nextOffset = nil
            }
            strongSelf.multiplexedNode?.setFiles(files: MultiplexedVideoNodeFiles(saved: [], trending: result, isSearch: true, canLoadMore: false, isStale: false), synchronous: true, resetScrollingToOffset: nil)
            strongSelf.updateActivity?(false)
            strongSelf.notFoundNode.isHidden = text.isEmpty || !result.isEmpty
        }))
    }
    
    private func loadMore() {
        if self.isLoadingNextResults {
            return
        }
        guard let (text, nextOffsetValue) = self.nextOffset else {
            return
        }
        self.isLoadingNextResults = true
        
        let signal: Signal<([MultiplexedVideoNodeFile], String?)?, NoError>
        signal = paneGifSearchForQuery(context: self.context, query: text, offset: nextOffsetValue, updateActivity: self.updateActivity)
        |> map { result -> ([MultiplexedVideoNodeFile], String?)? in
            if let result = result {
                return (result.files, result.nextOffset)
            } else {
                return nil
            }
        }
        
        self.searchDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self, let (result, nextOffset) = result else {
                return
            }
            
            var files = strongSelf.multiplexedNode?.files.trending ?? []
            var currentIds = Set(files.map { $0.file.media.fileId })
            for item in result {
                if currentIds.contains(item.file.media.fileId) {
                    continue
                }
                currentIds.insert(item.file.media.fileId)
                files.append(item)
            }
            
            strongSelf.isLoadingNextResults = false
            if let nextOffset = nextOffset {
                strongSelf.nextOffset = (text, nextOffset)
            } else {
                strongSelf.nextOffset = nil
            }
            strongSelf.multiplexedNode?.setFiles(files: MultiplexedVideoNodeFiles(saved: [], trending: files, isSearch: true, canLoadMore: false, isStale: false), synchronous: true, resetScrollingToOffset: nil)
            strongSelf.notFoundNode.isHidden = text.isEmpty || !files.isEmpty
        }))
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.notFoundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/GifsNotFoundIcon"), color: theme.list.freeMonoIconColor)
        self.notFoundLabel.attributedText = NSAttributedString(string: strings.Gif_NoGifsFound, font: Font.medium(14.0), textColor: theme.list.freeTextColor)
    }
    
    func updatePreviewing(animated: Bool) {
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        if let multiplexedNode = self.multiplexedNode, let file = multiplexedNode.fileAt(point: point.offsetBy(dx: -multiplexedNode.frame.minX, dy: -multiplexedNode.frame.minY)) {
            return (self, file)
        } else {
            return nil
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = size
        
        if let image = self.notFoundNode.image {
            let areaHeight = size.height - inputHeight

            let labelSize = self.notFoundLabel.updateLayout(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))

            transition.updateFrame(node: self.notFoundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((areaHeight - image.size.height - labelSize.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.notFoundLabel, frame: CGRect(origin: CGPoint(x: floor((image.size.width - labelSize.width) / 2.0), y: image.size.height + 8.0), size: labelSize))
        }
        
        if let multiplexedNode = self.multiplexedNode {
            multiplexedNode.topInset = 0.0
            multiplexedNode.bottomInset = 0.0
            let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            
            transition.updateFrame(layer: multiplexedNode.layer, frame: nodeFrame)
            multiplexedNode.updateLayout(theme: self.theme, strings: self.strings, size: nodeFrame.size, transition: transition)
        }
        
        if firstLayout && !self.hasInitialText {
            self.updateText("", languageCode: nil)
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.multiplexedNode == nil {
            let multiplexedNode = MultiplexedVideoNode(account: self.context.account, theme: self.theme, strings: self.strings)
            self.multiplexedNode = multiplexedNode
            if let layout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: layout)
            }
            
            self.addSubnode(multiplexedNode)
            
            multiplexedNode.fileSelected = { [weak self] file, sourceNode, sourceRect in
                if let (collection, result) = file.contextResult {
                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode.view, sourceRect, false)
                } else {
                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode.view, sourceRect, false, false)
                }
            }
            
            multiplexedNode.fileContextMenu = { [weak self] fileReference, sourceNode, sourceRect, gesture, isSaved in
                self?.openGifContextMenu?(fileReference, sourceNode, sourceRect, gesture, isSaved)
            }
            
            multiplexedNode.didScroll = { [weak self] offset, height in
                guard let strongSelf = self, let multiplexedNode = strongSelf.multiplexedNode else {
                    return
                }
                
                strongSelf.deactivateSearchBar?()
                
                if offset >= height - multiplexedNode.bounds.height - 200.0 {
                    strongSelf.loadMore()
                }
            }
            
            multiplexedNode.reactionSelected = { [weak self] reaction in
                self?.requestUpdateQuery?(reaction)
            }
        }
    }
    
    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let multiplexedNode = self.multiplexedNode else {
            return
        }
        
        multiplexedNode.alpha = 0.0
        transition.updateAlpha(layer: multiplexedNode.layer, alpha: 1.0, completion: { _ in
        })

        if case let .animated(duration, curve) = transition {
            multiplexedNode.layer.animatePosition(from: CGPoint(x: 0.0, y: additivePosition), to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, additive: true)
        }
    }
    
    func animateOut(transition: ContainedViewLayoutTransition) {
        guard let multiplexedNode = self.multiplexedNode else {
            return
        }
        
        transition.updateAlpha(layer: multiplexedNode.layer, alpha: 0.0, completion: { _ in
        })
    }
}
