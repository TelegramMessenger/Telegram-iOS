import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import AVFoundation
import ContextUI
import TelegramPresentationData
import ShimmerEffect
import SoftwareVideo

final class MultiplexedVideoPlaceholderNode: ASDisplayNode {
    private let effectNode: ShimmerEffectNode
    private var theme: PresentationTheme?
    private var size: CGSize?
    
    override init() {
        self.effectNode = ShimmerEffectNode()
        
        super.init()
        
        self.addSubnode(self.effectNode)
    }
    
    func update(size: CGSize, theme: PresentationTheme) {
        if self.theme === theme && self.size == size {
            return
        }
        
        self.effectNode.frame = CGRect(origin: CGPoint(), size: size)
        self.effectNode.update(backgroundColor: theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0), foregroundColor: theme.chat.inputMediaPanel.stickersSectionTextColor.blitOver(theme.chat.inputMediaPanel.stickersBackgroundColor, alpha: 0.2), shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3), shapes: [.rect(rect: CGRect(origin: CGPoint(), size: size))], size: bounds.size)
    }
    
    func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        self.effectNode.updateAbsoluteRect(absoluteRect, within: containerSize)
    }
}

private final class MultiplexedVideoTrackingNode: ASDisplayNode {
    var inHierarchyUpdated: ((Bool) -> Void)?
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.inHierarchyUpdated?(true)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.inHierarchyUpdated?(false)
    }
}

private final class VisibleVideoItem {
    enum Id: Equatable, Hashable {
        case saved(MediaId)
        case trending(MediaId)
    }
    let id: Id
    let file: MultiplexedVideoNodeFile
    let frame: CGRect
    
    init(file: MultiplexedVideoNodeFile, frame: CGRect, isTrending: Bool) {
        self.file = file
        self.frame = frame
        if isTrending {
            self.id = .trending(file.file.media.fileId)
        } else {
            self.id = .saved(file.file.media.fileId)
        }
    }
}

final class MultiplexedVideoNodeFile {
    let file: FileMediaReference
    let contextResult: (ChatContextResultCollection, ChatContextResult)?
    
    init(file: FileMediaReference, contextResult: (ChatContextResultCollection, ChatContextResult)?) {
        self.file = file
        self.contextResult = contextResult
    }
}

final class MultiplexedVideoNodeFiles {
    let saved: [MultiplexedVideoNodeFile]
    let trending: [MultiplexedVideoNodeFile]
    let isSearch: Bool
    let canLoadMore: Bool
    let isStale: Bool
    
    init(saved: [MultiplexedVideoNodeFile], trending: [MultiplexedVideoNodeFile], isSearch: Bool, canLoadMore: Bool, isStale: Bool) {
        self.saved = saved
        self.trending = trending
        self.isSearch = isSearch
        self.canLoadMore = canLoadMore
        self.isStale = isStale
    }
}

final class MultiplexedVideoNode: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let trackingNode: MultiplexedVideoTrackingNode
    var didScroll: ((CGFloat, CGFloat) -> Void)?
    var didEndScrolling: (() -> Void)?
    var reactionSelected: ((String) -> Void)?
    
    var topInset: CGFloat = 0.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    var bottomInset: CGFloat = 0.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    var idealHeight: CGFloat = 93.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    private(set) var files: MultiplexedVideoNodeFiles = MultiplexedVideoNodeFiles(saved: [], trending: [], isSearch: false, canLoadMore: false, isStale: false)
    
    func setFiles(files: MultiplexedVideoNodeFiles, synchronous: Bool, resetScrollingToOffset: CGFloat?) {
        self.files = files
        
        self.ignoreDidScroll = true
        if let resetScrollingToOffset = resetScrollingToOffset {
            self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y :resetScrollingToOffset)
        }
        self.updateVisibleItems(extendSizeForTransition: 0.0, transition: .immediate, synchronous: synchronous)
        self.ignoreDidScroll = false
    }
    
    private var displayItems: [VisibleVideoItem] = []
    private var visibleThumbnailLayers: [VisibleVideoItem.Id: SoftwareVideoThumbnailNode] = [:]
    private var visiblePlaceholderNodes: [Int: MultiplexedVideoPlaceholderNode] = [:]

    private let contextContainerNode: ContextControllerSourceNode
    let scrollNode: ASScrollNode
    
    private var visibleLayers: [VisibleVideoItem.Id: (SoftwareVideoLayerFrameManager, SampleBufferLayer)] = [:]
    
    private let trendingTitleNode: ImmediateTextNode
    
    private var displayLink: CADisplayLink!
    private var timeOffset = 0.0
    private var pauseTime = 0.0
    
    private let timebase: CMTimebase
    
    var fileSelected: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect) -> Void)?
    var fileContextMenu: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void)?
    var enableVideoNodes = false
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.trackingNode = MultiplexedVideoTrackingNode()
        self.trackingNode.isLayerBacked = true
        
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        CMTimebaseSetRate(timebase!, rate: 0.0)
        self.timebase = timebase!
        
        self.contextContainerNode = ContextControllerSourceNode()
        self.scrollNode = ASScrollNode()
        
        self.trendingTitleNode = ImmediateTextNode()
        self.trendingTitleNode.attributedText = NSAttributedString(string: strings.Chat_Gifs_TrendingSectionHeader, font: Font.medium(12.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        
        super.init()
        
        self.isOpaque = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.alwaysBounceVertical = true
        
        self.scrollNode.addSubnode(self.trendingTitleNode)
        
        self.addSubnode(self.trackingNode)
        self.addSubnode(self.contextContainerNode)
        self.contextContainerNode.addSubnode(self.scrollNode)
        
        class DisplayLinkProxy: NSObject {
            weak var target: MultiplexedVideoNode?
            
            init(target: MultiplexedVideoNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink.add(to: RunLoop.main, forMode: .common)
        if #available(iOS 10.0, *) {
            self.displayLink.preferredFramesPerSecond = 25
        } else {
            self.displayLink.frameInterval = 2
        }
        self.displayLink.isPaused = true
        
        self.trackingNode.inHierarchyUpdated = { [weak self] value in
            if let strongSelf = self {
                if !value {
                    CMTimebaseSetRate(strongSelf.timebase, rate: 0.0)
                } else {
                    CMTimebaseSetRate(strongSelf.timebase, rate: 1.0)
                }
                strongSelf.displayLink.isPaused = !value
                if value && !strongSelf.enableVideoNodes {
                    strongSelf.enableVideoNodes = true
                    strongSelf.validVisibleItemsOffset = nil
                    strongSelf.updateImmediatelyVisibleItems()
                } else if !value {
                    strongSelf.enableVideoNodes = false
                }
            }
        }
        
        self.scrollNode.view.delegate = self
        
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(recognizer)
        
        var gestureLocation: CGPoint?
        
        self.contextContainerNode.shouldBegin = { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            gestureLocation = point
            return strongSelf.fileAt(point: point) != nil
        }
        
        self.contextContainerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let gestureLocation = gestureLocation else {
                return
            }
            if let (file, rect, isSaved) = strongSelf.fileAt(point: gestureLocation) {
                if !strongSelf.files.isStale {
                    strongSelf.fileContextMenu?(file, strongSelf, rect.offsetBy(dx: 0.0, dy: -strongSelf.scrollNode.bounds.minY), gesture, isSaved)
                } else {
                    gesture.cancel()
                }
            } else {
                gesture.cancel()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.displayLink.invalidate()
        self.displayLink.isPaused = true
        for (_, value) in self.visibleLayers {
            value.1.isFreed = true
        }
        clearSampleBufferLayerPoll()
    }
    
    private func displayLinkEvent() {
        let timestamp = CMTimebaseGetTime(self.timebase).seconds
        for (_, (manager, _)) in self.visibleLayers {
            manager.tick(timestamp: timestamp)
        }
    }
    
    private var validSize: CGSize?
    func updateLayout(theme: PresentationTheme, strings: PresentationStrings, size: CGSize, transition: ContainedViewLayoutTransition) {
        self.theme = theme
        self.strings = strings
        if self.validSize == nil || !self.validSize!.equalTo(size) {
            let previousSize = self.validSize ?? CGSize()
            self.validSize = size
            self.contextContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
            let startTime = CFAbsoluteTimeGetCurrent()
            self.updateVisibleItems(extendSizeForTransition: max(0.0, previousSize.height - size.height), transition: transition)
            print("MultiplexedVideoNode layout updateVisibleItems: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    
    private var ignoreDidScroll: Bool = false
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreDidScroll {
            self.updateImmediatelyVisibleItems()
            self.didScroll?(scrollView.contentOffset.y, scrollView.contentSize.height)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.didEndScrolling?()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.didEndScrolling?()
        }
    }
    
    private var currentExtendSizeForTransition: CGFloat = 0.0
    
    private var validVisibleItemsOffset: CGFloat?
    private func updateImmediatelyVisibleItems(ensureFrames: Bool = false, synchronous: Bool = false) {
        var visibleBounds = self.scrollNode.bounds
        let containerSize = visibleBounds.size
        visibleBounds.size.height += max(0.0, self.currentExtendSizeForTransition)
        let visibleThumbnailBounds = visibleBounds.insetBy(dx: 0.0, dy: -350.0)
        
        let containerWidth = containerSize.width
        let itemSpacing: CGFloat = 1.0
        let itemsInRow = max(3, min(6, Int(containerWidth / 140.0)))
        let itemSize: CGFloat = floor(containerWidth / CGFloat(itemsInRow))
        
        let absoluteContainerSize = CGSize(width: containerSize.width, height: containerSize.height)
        let absoluteContainerOffset = -visibleBounds.origin.y
        
        if let validVisibleItemsOffset = self.validVisibleItemsOffset, validVisibleItemsOffset.isEqual(to: visibleBounds.origin.y) {
            return
        }
        self.validVisibleItemsOffset = visibleBounds.origin.y
        let minVisibleY = visibleBounds.minY
        let maxVisibleY = visibleBounds.maxY
        
        let minVisibleThumbnailY = visibleThumbnailBounds.minY
        let maxVisibleThumbnailY = visibleThumbnailBounds.maxY
        
        var visibleThumbnailIds = Set<VisibleVideoItem.Id>()
        var visibleIds = Set<VisibleVideoItem.Id>()
        
        var maxVisibleIndex = -1
        
        for index in 0 ..< self.displayItems.count {
            let item = self.displayItems[index]
            
            if item.frame.maxY < minVisibleThumbnailY {
                continue
            }
            if item.frame.minY > maxVisibleThumbnailY {
                break
            }
            
            maxVisibleIndex = max(maxVisibleIndex, index)
            
            visibleThumbnailIds.insert(item.id)
            
            let thumbnailLayer: SoftwareVideoThumbnailNode
            if let current = self.visibleThumbnailLayers[item.id] {
                thumbnailLayer = current
                if ensureFrames {
                    thumbnailLayer.frame = item.frame
                }
            } else {
                var existingPlaceholderNode: MultiplexedVideoPlaceholderNode?
                if let placeholderNode = self.visiblePlaceholderNodes[index] {
                    existingPlaceholderNode = placeholderNode
                    self.visiblePlaceholderNodes.removeValue(forKey: index)
                    placeholderNode.removeFromSupernode()
                }
                
                thumbnailLayer = SoftwareVideoThumbnailNode(account: self.account, fileReference: item.file.file, synchronousLoad: synchronous, usePlaceholder: true, existingPlaceholder: existingPlaceholderNode)
                thumbnailLayer.frame = item.frame
                self.scrollNode.addSubnode(thumbnailLayer)
                self.visibleThumbnailLayers[item.id] = thumbnailLayer
            }
            
            thumbnailLayer.update(theme: self.theme, size: item.frame.size)
            thumbnailLayer.updateAbsoluteRect(item.frame.offsetBy(dx: 0.0, dy: absoluteContainerOffset), within: absoluteContainerSize)
            
            if item.frame.maxY < minVisibleY {
                continue
            }
            if item.frame.minY > maxVisibleY {
                continue
            }
            
            visibleIds.insert(item.id)
            
            if let (_, layerHolder) = self.visibleLayers[item.id] {
                if ensureFrames {
                    layerHolder.layer.frame = item.frame
                }
            } else {
                let layerHolder = takeSampleBufferLayer()
                layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                layerHolder.layer.frame = item.frame
                self.scrollNode.layer.addSublayer(layerHolder.layer)
                let manager = SoftwareVideoLayerFrameManager(account: self.account, fileReference: item.file.file, layerHolder: layerHolder)
                self.visibleLayers[item.id] = (manager, layerHolder)
                self.visibleThumbnailLayers[item.id]?.ready = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.visibleLayers[item.id]?.0.start()
                    }
                }
            }
        }
        
        var visiblePlaceholderIndices = Set<Int>()
        if self.files.canLoadMore {
            let verticalOffset: CGFloat = self.topInset
            
            let sideInset: CGFloat = 0.0
            
            var indexImpl = maxVisibleIndex + 1
            while true {
                let index = indexImpl
                indexImpl += 1
                
                let rowIndex = index / Int(itemsInRow)
                let columnIndex = index % Int(itemsInRow)
                let itemOrigin = CGPoint(x: sideInset + CGFloat(columnIndex) * (itemSize + itemSpacing), y: verticalOffset + itemSpacing + CGFloat(rowIndex) * (itemSize + itemSpacing))
                let itemFrame = CGRect(origin: itemOrigin, size: CGSize(width: columnIndex == itemsInRow ? (containerWidth - itemOrigin.x) : itemSize, height: itemSize))
                if itemFrame.maxY < minVisibleY {
                    continue
                }
                if itemFrame.minY > maxVisibleY {
                    break
                }
                visiblePlaceholderIndices.insert(index)
                
                let placeholderNode: MultiplexedVideoPlaceholderNode
                if let current = self.visiblePlaceholderNodes[index] {
                    placeholderNode = current
                } else {
                    placeholderNode = MultiplexedVideoPlaceholderNode()
                    self.visiblePlaceholderNodes[index] = placeholderNode
                    self.scrollNode.addSubnode(placeholderNode)
                }
                placeholderNode.frame = itemFrame
                placeholderNode.update(size: itemFrame.size, theme: self.theme)
                placeholderNode.updateAbsoluteRect(itemFrame.offsetBy(dx: 0.0, dy: absoluteContainerOffset), within: absoluteContainerSize)
            }
        }
        
        var removeIds: [VisibleVideoItem.Id] = []
        for id in self.visibleLayers.keys {
            if !visibleIds.contains(id) {
                removeIds.append(id)
            }
        }
        
        var removeThumbnailIds: [VisibleVideoItem.Id] = []
        for id in self.visibleThumbnailLayers.keys {
            if !visibleThumbnailIds.contains(id) {
                removeThumbnailIds.append(id)
            }
        }
        
        var removePlaceholderIndices: [Int] = []
        for index in self.visiblePlaceholderNodes.keys {
            if !visiblePlaceholderIndices.contains(index) {
                removePlaceholderIndices.append(index)
            }
        }
        
        for id in removeIds {
            let (_, layerHolder) = self.visibleLayers[id]!
            layerHolder.layer.removeFromSuperlayer()
            self.visibleLayers.removeValue(forKey: id)
        }
        
        for id in removeThumbnailIds {
            let thumbnailLayer = self.visibleThumbnailLayers[id]!
            thumbnailLayer.removeFromSupernode()
            self.visibleThumbnailLayers.removeValue(forKey: id)
        }
        
        for index in removePlaceholderIndices {
            if let placeholderNode = self.visiblePlaceholderNodes[index] {
                placeholderNode.removeFromSupernode()
                self.visiblePlaceholderNodes.removeValue(forKey: index)
            }
        }
    }
    
    private func updateVisibleItems(extendSizeForTransition: CGFloat, transition: ContainedViewLayoutTransition, synchronous: Bool = false) {
        let drawableSize = self.scrollNode.bounds.size
        if !drawableSize.width.isZero {
            var displayItems: [VisibleVideoItem] = []
            
            var verticalOffset: CGFloat = self.topInset
            
            func commitFileGrid(files: [MultiplexedVideoNodeFile], isTrending: Bool) {
                let containerWidth = drawableSize.width
                let itemCount = files.count
                let itemSpacing: CGFloat = 1.0
                let itemsInRow = max(3, min(6, Int(containerWidth / 140.0)))
                let itemSize: CGFloat = floor(containerWidth / CGFloat(itemsInRow))
                
                let rowCount = itemCount / itemsInRow + (itemCount % itemsInRow == 0 ? 0 : 1)
                
                let sideInset: CGFloat = 0.0
                
                for index in 0 ..< itemCount {
                    let rowIndex = index / Int(itemsInRow)
                    let columnIndex = index % Int(itemsInRow)
                    let itemOrigin = CGPoint(x: sideInset + CGFloat(columnIndex) * (itemSize + itemSpacing), y: verticalOffset + itemSpacing + CGFloat(rowIndex) * (itemSize + itemSpacing))
                    let itemFrame = CGRect(origin: itemOrigin, size: CGSize(width: columnIndex == itemsInRow ? (containerWidth - itemOrigin.x) : itemSize, height: itemSize))
                    displayItems.append(VisibleVideoItem(file: files[index], frame: itemFrame, isTrending: isTrending))
                }
                
                let contentHeight = CGFloat(rowCount + 1) * itemSpacing + CGFloat(rowCount) * itemSize
                verticalOffset += contentHeight
            }
            
            func commitFilesSpans(files: [MultiplexedVideoNodeFile], isTrending: Bool) {
                var rowsCount = 0
                var firstRowMax = 0;
                
                let viewPortAvailableSize = drawableSize.width
                
                let preferredRowSize: CGFloat = 100.0
                let itemsCount = files.count
                let spanCount: CGFloat = 100.0
                var spanLeft = spanCount
                var currentItemsInRow = 0
                var currentItemsSpanAmount: CGFloat = 0.0
                
                var itemSpans: [Int: CGFloat] = [:]
                var itemsToRow: [Int: Int] = [:]
                
                for a in 0 ..< itemsCount {
                    var size: CGSize
                    if let dimensions = files[a].file.media.dimensions {
                        size = dimensions.cgSize
                    } else {
                        size = CGSize(width: 100.0, height: 100.0)
                    }
                    if size.width <= 0.0 {
                        size.width = 100.0
                    }
                    if size.height <= 0.0 {
                        size.height = 100.0
                    }
                    //size = CGSize(width: 100.0, height: 100.0)
                    let aspect: CGFloat = size.width / size.height
                    if aspect > 4.0 || aspect < 0.2 {
                        size.width = max(size.width, size.height)
                        size.height = size.width
                    }

                    var requiredSpan = min(spanCount, floor(spanCount * (size.width / size.height * preferredRowSize / viewPortAvailableSize)))
                    let moveToNewRow = spanLeft < requiredSpan || requiredSpan > 33.0 && spanLeft < requiredSpan - 15.0
                    if moveToNewRow {
                        if spanLeft > 0 {
                            let spanPerItem = floor(spanLeft / CGFloat(currentItemsInRow))
                            
                            let start = a - currentItemsInRow
                            var b = start
                            while b < start + currentItemsInRow {
                                if (b == start + currentItemsInRow - 1) {
                                    itemSpans[b] = itemSpans[b]! + spanLeft
                                } else {
                                    itemSpans[b] = itemSpans[b]! + spanPerItem
                                }
                                spanLeft -= spanPerItem;
                                
                                b += 1
                            }
                            
                            itemsToRow[a - 1] = rowsCount
                        }
                        rowsCount += 1
                        currentItemsSpanAmount = 0
                        currentItemsInRow = 0
                        spanLeft = spanCount
                    } else {
                        if spanLeft < requiredSpan {
                            requiredSpan = spanLeft
                        }
                    }
                    if rowsCount == 0 {
                        firstRowMax = max(firstRowMax, a)
                    }
                    if a == itemsCount - 1 {
                        itemsToRow[a] = rowsCount
                    }
                    currentItemsSpanAmount += requiredSpan
                    currentItemsInRow += 1
                    spanLeft -= requiredSpan
                    spanLeft = max(0, spanLeft)

                    itemSpans[a] = requiredSpan
                }
                if itemsCount != 0 {
                    rowsCount += 1
                }
                
                var currentRowHorizontalOffset: CGFloat = 0.0
                for index in 0 ..< files.count {
                    guard let width = itemSpans[index] else {
                        continue
                    }
                    let itemWidth = floor(width * drawableSize.width / 100.0) - 1
                    
                    var itemSize = CGSize(width: itemWidth, height: preferredRowSize)
                    if itemsToRow[index] != nil && currentRowHorizontalOffset + itemSize.width >= drawableSize.width - 10.0 {
                        itemSize.width = max(itemSize.width, drawableSize.width - currentRowHorizontalOffset)
                    }
                    displayItems.append(VisibleVideoItem(file: files[index], frame: CGRect(origin: CGPoint(x: currentRowHorizontalOffset, y: verticalOffset), size: itemSize), isTrending: isTrending))
                    currentRowHorizontalOffset += itemSize.width + 1.0
                    
                    if itemsToRow[index] != nil {
                        verticalOffset += preferredRowSize + 1.0
                        currentRowHorizontalOffset = 0.0
                    }
                }
            }
            
            var hasContent = false
            if !self.files.saved.isEmpty {
                commitFileGrid(files: self.files.saved, isTrending: false)
                hasContent = true
            }
            if !self.files.trending.isEmpty {
                if self.files.isSearch {
                    self.trendingTitleNode.isHidden = true
                } else {
                    self.trendingTitleNode.isHidden = false
                    if hasContent {
                        verticalOffset += 16.0
                    }
                    let leftInset: CGFloat = 10.0
                    let trendingTitleSize = self.trendingTitleNode.updateLayout(CGSize(width: drawableSize.width - leftInset * 2.0, height: 100.0))
                    self.trendingTitleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalOffset - 3.0), size: trendingTitleSize)
                    verticalOffset += trendingTitleSize.height + 5.0
                }
                commitFileGrid(files: self.files.trending, isTrending: true)
            } else {
                self.trendingTitleNode.isHidden = true
            }
            
            let contentSize = CGSize(width: drawableSize.width, height: verticalOffset + self.bottomInset)
            self.scrollNode.view.contentSize = contentSize
            
            self.displayItems = displayItems
            
            self.validVisibleItemsOffset = nil
            self.currentExtendSizeForTransition = extendSizeForTransition
            self.updateImmediatelyVisibleItems(ensureFrames: true, synchronous: synchronous)
            
            transition.updateAlpha(node: scrollNode, alpha: 1.0, force: true, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.currentExtendSizeForTransition = 0.0
                strongSelf.updateImmediatelyVisibleItems()
            })
        }
    }
    
    @objc func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.view)
            if let (file, rect, _) = self.fileAt(point: point) {
                if !self.files.isStale {
                    self.fileSelected?(file, self, rect)
                }
            }
        }
    }
    
    func frameForItem(_ id: MediaId) -> CGRect? {
        for item in self.displayItems {
            if item.file.file.media.fileId == id {
                return item.frame
            }
        }
        return nil
    }
    
    func fileAt(point: CGPoint) -> (MultiplexedVideoNodeFile, CGRect, Bool)? {
        let offsetPoint = point.offsetBy(dx: 0.0, dy: self.scrollNode.bounds.minY)
        return self.offsetFileAt(point: offsetPoint)
    }
    
    private func offsetFileAt(point: CGPoint) -> (MultiplexedVideoNodeFile, CGRect, Bool)? {
        for item in self.displayItems {
            if item.frame.contains(point) {
                let isSaved: Bool
                switch item.id {
                case .saved:
                    isSaved = true
                case .trending:
                    isSaved = false
                }
                return (item.file, item.frame, isSaved)
            }
        }
        return nil
    }
}

private func NH_LP_TABLE_LOOKUP(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int) -> Int {
    return table[i * rowsize + j]
}

private func NH_LP_TABLE_LOOKUP_SET(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int, _ value: Int) {
    table[i * rowsize + j] = value
}

private func linearPartitionTable(_ weights: [Int], numberOfPartitions: Int) -> [Int] {
    let n = weights.count
    let k = numberOfPartitions
    
    let tableSize = n * k;
    var tmpTable = Array<Int>(repeatElement(0, count: tableSize))
    
    let solutionSize = (n - 1) * (k - 1)
    var solution = Array<Int>(repeatElement(0, count: solutionSize))
    
    for i in 0 ..< n {
        let offset = i != 0 ? NH_LP_TABLE_LOOKUP(&tmpTable, i - 1, 0, k) : 0
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, 0, k, Int(weights[i]) + offset)
    }
    
    for j in 0 ..< k {
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, 0, j, k, Int(weights[0]))
    }
    
    for i in 1 ..< n {
        for j in 1 ..< k {
            var currentMin = 0
            var minX = Int.max
            
            for x in 0 ..< i {
                let c1 = NH_LP_TABLE_LOOKUP(&tmpTable, x, j - 1, k)
                let c2 = NH_LP_TABLE_LOOKUP(&tmpTable, i, 0, k) - NH_LP_TABLE_LOOKUP(&tmpTable, x, 0, k)
                let cost = max(c1, c2)
                
                if x == 0 || cost < currentMin {
                    currentMin = cost;
                    minX = x
                }
            }
            
            NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, j, k, currentMin)
            NH_LP_TABLE_LOOKUP_SET(&solution, i - 1, j - 1, k - 1, minX)
        }
    }
    
    return solution
}

private func linearPartitionForWeights(_ weights: [Int], numberOfPartitions: Int) -> [[Int]] {
    var n = weights.count
    var k = numberOfPartitions
    
    if k <= 0 {
        return []
    }
    
    if k >= n {
        var partition: [[Int]] = []
        for weight in weights {
            partition.append([weight])
        }
        return partition
    }
    
    if n == 1 {
        return [weights]
    }
    
    var solution = linearPartitionTable(weights, numberOfPartitions: numberOfPartitions)
    let solutionRowSize = numberOfPartitions - 1
    
    k = k - 2;
    n = n - 1;
    
    var answer: [[Int]] = []
    
    while k >= 0 {
        if n < 1 {
            answer.insert([], at: 0)
        } else {
            var currentAnswer: [Int] = []
            
            var i = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize) + 1
            let range = n + 1
            while i < range {
                currentAnswer.append(weights[i])
                i += 1
            }
            
            answer.insert(currentAnswer, at: 0)
            
            n = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize)
        }
        
        k = k - 1
    }
    
    var currentAnswer: [Int] = []
    var i = 0
    let range = n + 1
    while i < range {
        currentAnswer.append(weights[i])
        i += 1
    }
    
    answer.insert(currentAnswer, at: 0)
    
    return answer
}
