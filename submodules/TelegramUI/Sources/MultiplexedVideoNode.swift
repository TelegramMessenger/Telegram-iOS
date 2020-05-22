import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import AVFoundation
import ContextUI
import TelegramPresentationData

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
    let fileReference: FileMediaReference
    let frame: CGRect
    
    init(fileReference: FileMediaReference, frame: CGRect, isTrending: Bool) {
        self.fileReference = fileReference
        self.frame = frame
        if isTrending {
            self.id = .trending(fileReference.media.fileId)
        } else {
            self.id = .saved(fileReference.media.fileId)
        }
    }
}

final class MultiplexedVideoNodeFiles {
    let saved: [FileMediaReference]
    let trending: [FileMediaReference]
    
    init(saved: [FileMediaReference], trending: [FileMediaReference]) {
        self.saved = saved
        self.trending = trending
    }
}

private final class TrendingHeaderNode: ASDisplayNode {
    private let titleNode: ImmediateTextNode
    private let reactions: [String]
    private let reactionNodes: [ImmediateTextNode]
    private let scrollNode: ASScrollNode
    
    var reactionSelected: ((String) -> Void)?
    
    override init() {
        self.titleNode = ImmediateTextNode()
        self.reactions = [
            "👍", "👎", "😍", "😂", "😯", "😕", "😢", "😡", "💪", "👏", "🙈", "😒"
        ]
        self.scrollNode = ASScrollNode()
        let scrollNode = self.scrollNode
        self.reactionNodes = reactions.map { reaction -> ImmediateTextNode in
            let textNode = ImmediateTextNode()
            textNode.attributedText = NSAttributedString(string: reaction, font: Font.regular(30.0), textColor: .black)
            scrollNode.addSubnode(textNode)
            return textNode
        }
        
        super.init()
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.scrollNode)
        
        for i in 0 ..< self.reactionNodes.count {
            self.reactionNodes[i].view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self.scrollNode.view)
            for i in 0 ..< self.reactionNodes.count {
                if self.reactionNodes[i].frame.contains(location) {
                    let reaction = self.reactions[i]
                    self.reactionSelected?(reaction)
                    break
                }
            }
        }
    }
    
    func update(theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, sideInset: CGFloat) -> CGFloat {
        let height: CGFloat = 72.0
        let leftInset: CGFloat = 10.0
        
        //TODO:localize
        self.titleNode.attributedText = NSAttributedString(string: "TRENDING GIFS", font: Font.medium(12.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset * 2.0 - sideInset * 2.0, height: 100.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: titleSize)
        
        let reactionSizes = self.reactionNodes.map { reactionNode -> CGSize in
            return reactionNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        }
        
        let reactionSpacing: CGFloat = 4.0
        var reactionsOffset: CGFloat = leftInset - 2.0
        
        for i in 0 ..< self.reactionNodes.count {
            if i != 0 {
                reactionsOffset += reactionSpacing
            }
            reactionNodes[i].frame = CGRect(origin: CGPoint(x: reactionsOffset, y: 0.0), size: reactionSizes[i])
            reactionsOffset += reactionSizes[i].width
        }
        reactionsOffset += leftInset - 2.0
        
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 28.0), size: CGSize(width: width, height: 44.0))
        self.scrollNode.view.contentSize = CGSize(width: reactionsOffset, height: 44.0)
        
        return height
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
    
    var files: MultiplexedVideoNodeFiles = MultiplexedVideoNodeFiles(saved: [], trending: []) {
        didSet {
            let startTime = CFAbsoluteTimeGetCurrent()
            self.updateVisibleItems(extendSizeForTransition: 0.0, transition: .immediate, synchronous: true)
            print("MultiplexedVideoNode files updateVisibleItems: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    private var displayItems: [VisibleVideoItem] = []
    private var visibleThumbnailLayers: [VisibleVideoItem.Id: SoftwareVideoThumbnailLayer] = [:]
    private var statusDisposable: [VisibleVideoItem.Id: MetaDisposable] = [:]

    private let contextContainerNode: ContextControllerSourceNode
    let scrollNode: ASScrollNode
    
    private var visibleLayers: [VisibleVideoItem.Id: (SoftwareVideoLayerFrameManager, SampleBufferLayer)] = [:]
    
    private let savedTitleNode: ImmediateTextNode
    private let trendingHeaderNode: TrendingHeaderNode
    
    private var displayLink: CADisplayLink!
    private var timeOffset = 0.0
    private var pauseTime = 0.0
    
    private let timebase: CMTimebase
    
    var fileSelected: ((FileMediaReference, ASDisplayNode, CGRect) -> Void)?
    var fileContextMenu: ((FileMediaReference, ASDisplayNode, CGRect, ContextGesture) -> Void)?
    var enableVideoNodes = false
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.trackingNode = MultiplexedVideoTrackingNode()
        self.trackingNode.isLayerBacked = true
        
        var timebase: CMTimebase?
        CMTimebaseCreateWithMasterClock(allocator: nil, masterClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        CMTimebaseSetRate(timebase!, rate: 0.0)
        self.timebase = timebase!
        
        self.contextContainerNode = ContextControllerSourceNode()
        self.scrollNode = ASScrollNode()
        
        //TODO:localization
        self.savedTitleNode = ImmediateTextNode()
        self.savedTitleNode.attributedText = NSAttributedString(string: "MY GIFS", font: Font.medium(12.0), textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        
        self.trendingHeaderNode = TrendingHeaderNode()
        
        super.init()
        
        self.trendingHeaderNode.reactionSelected = { [weak self] reaction in
            self?.reactionSelected?(reaction)
        }
        
        self.isOpaque = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.alwaysBounceVertical = true
        
        self.scrollNode.addSubnode(self.savedTitleNode)
        self.scrollNode.addSubnode(self.trendingHeaderNode)
        
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
            if let (file, rect) = strongSelf.fileAt(point: gestureLocation) {
                strongSelf.fileContextMenu?(file, strongSelf, rect.offsetBy(dx: 0.0, dy: -strongSelf.scrollNode.bounds.minY), gesture)
            } else {
                gesture.cancel()
            }
        }
        
        self.contextContainerNode.customActivationProgress = { [weak self] progress, update in
            guard let strongSelf = self, let gestureLocation = gestureLocation else {
                return
            }
            /*let minScale: CGFloat = (strongSelf.bounds.width - 10.0) / strongSelf.bounds.width
            let currentScale = 1.0 * (1.0 - progress) + minScale * progress
            switch update {
            case .update:
                strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
            case .begin:
                strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
            case let .ended(previousProgress):
                let previousScale = 1.0 * (1.0 - previousProgress) + minScale * previousProgress
                strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
                strongSelf.layer.animateSpring(from: previousScale as NSNumber, to: currentScale as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5, delay: 0.0, initialVelocity: 0.0, damping: 90.0)
            }*/
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.displayLink.invalidate()
        self.displayLink.isPaused = true
        for(_, disposable) in self.statusDisposable {
            disposable.dispose()
        }
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateImmediatelyVisibleItems()
        self.didScroll?(scrollView.contentOffset.y, scrollView.contentSize.height)
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
        visibleBounds.size.height += max(0.0, self.currentExtendSizeForTransition)
        let visibleThumbnailBounds = visibleBounds.insetBy(dx: 0.0, dy: -350.0)
        
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
        
        for item in self.displayItems {
            if item.frame.maxY < minVisibleThumbnailY {
                continue;
            }
            if item.frame.minY > maxVisibleThumbnailY {
                break;
            }
            
            visibleThumbnailIds.insert(item.id)
            
            if let thumbnailLayer = self.visibleThumbnailLayers[item.id] {
                if ensureFrames {
                    thumbnailLayer.frame = item.frame
                }
            } else {
                let thumbnailLayer = SoftwareVideoThumbnailLayer(account: self.account, fileReference: item.fileReference, synchronousLoad: synchronous)
                thumbnailLayer.frame = item.frame
                self.scrollNode.layer.addSublayer(thumbnailLayer)
                self.visibleThumbnailLayers[item.id] = thumbnailLayer
            }
            
            let progressSize = CGSize(width: 24.0, height: 24.0)
            let progressFrame =  CGRect(origin: CGPoint(x: item.frame.midX - progressSize.width / 2.0, y: item.frame.midY - progressSize.height / 2.0), size: progressSize)
            
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
                let manager = SoftwareVideoLayerFrameManager(account: self.account, fileReference: item.fileReference, layerHolder: layerHolder)
                self.visibleLayers[item.id] = (manager, layerHolder)
                self.visibleThumbnailLayers[item.id]?.ready = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.visibleLayers[item.id]?.0.start()
                    }
                }
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
        
        /*var removeProgressIds: [MediaId] = []
        for id in self.visibleProgressNodes.keys {
            if !visibleIds.contains(id) {
                removeProgressIds.append(id)
            }
        }*/
        
        for id in removeIds {
            let (_, layerHolder) = self.visibleLayers[id]!
            layerHolder.layer.removeFromSuperlayer()
            self.visibleLayers.removeValue(forKey: id)
        }
        
        for id in removeThumbnailIds {
            let thumbnailLayer = self.visibleThumbnailLayers[id]!
            thumbnailLayer.removeFromSuperlayer()
            self.visibleThumbnailLayers.removeValue(forKey: id)
        }
        
        /*for id in removeProgressIds {
            let progressNode = self.visibleProgressNodes[id]!
            progressNode.removeFromSupernode()
            self.visibleProgressNodes.removeValue(forKey: id)
            self.statusDisposable.removeValue(forKey: id)?.dispose()
        }*/
    }
    
    private func updateVisibleItems(extendSizeForTransition: CGFloat, transition: ContainedViewLayoutTransition, synchronous: Bool = false) {
        let drawableSize = self.scrollNode.bounds.size
        if !drawableSize.width.isZero {
            var displayItems: [VisibleVideoItem] = []
            
            let idealHeight = self.idealHeight
            
            var verticalOffset: CGFloat = self.topInset
            
            func commitFilesSpans(files: [FileMediaReference], isTrending: Bool) {
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
                    if let dimensions = files[a].media.dimensions {
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
                    if itemsToRow[index] != nil {
                        itemSize.width = max(itemSize.width, drawableSize.width - currentRowHorizontalOffset)
                    }
                    displayItems.append(VisibleVideoItem(fileReference: files[index], frame: CGRect(origin: CGPoint(x: currentRowHorizontalOffset, y: verticalOffset), size: itemSize), isTrending: isTrending))
                    currentRowHorizontalOffset += itemSize.width + 1.0
                    
                    if itemsToRow[index] != nil {
                        verticalOffset += preferredRowSize + 1.0
                        currentRowHorizontalOffset = 0.0
                    }
                }
            }
            
            func commitFiles(files: [FileMediaReference], isTrending: Bool) {
                var weights: [Int] = []
                var totalItemSize: CGFloat = 0.0
                for item in files {
                    let aspectRatio: CGFloat
                    if let dimensions = item.media.dimensions {
                        aspectRatio = dimensions.cgSize.width / dimensions.cgSize.height
                    } else {
                        aspectRatio = 1.0
                    }
                    weights.append(Int(aspectRatio * 100))
                    totalItemSize += aspectRatio * idealHeight
                }
                
                let numberOfRows = max(Int(round(totalItemSize / drawableSize.width)), 1)
                
                let partition = linearPartitionForWeights(weights, numberOfPartitions:numberOfRows)
                
                var i = 0
                var offset = CGPoint(x: 0.0, y: verticalOffset)
                var previousItemSize: CGFloat = 0.0
                let maxWidth = drawableSize.width
                
                let minimumInteritemSpacing: CGFloat = 1.0
                let minimumLineSpacing: CGFloat = 1.0
                
                let viewportWidth: CGFloat = drawableSize.width
                
                let preferredRowSize = idealHeight
                
                var rowIndex = -1
                for row in partition {
                    rowIndex += 1
                    
                    var summedRatios: CGFloat = 0.0
                    
                    var j = i
                    var n = i + row.count
                    
                    while j < n {
                        let aspectRatio: CGFloat
                        if let dimensions = files[j].media.dimensions {
                            aspectRatio = dimensions.cgSize.width / dimensions.cgSize.height
                        } else {
                            aspectRatio = 1.0
                        }
                        
                        summedRatios += aspectRatio
                        
                        j += 1
                    }
                    
                    var rowSize = drawableSize.width - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                    
                    if rowIndex == partition.count - 1 {
                        if row.count < 2 {
                            rowSize = floor(viewportWidth / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                        } else if row.count < 3 {
                            rowSize = floor(viewportWidth * 2.0 / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                        }
                    }
                    
                    j = i
                    n = i + row.count
                    
                    while j < n {
                        let aspectRatio: CGFloat
                        if let dimensions = files[j].media.dimensions {
                            aspectRatio = dimensions.cgSize.width / dimensions.cgSize.height
                        } else {
                            aspectRatio = 1.0
                        }
                        let preferredAspectRatio = aspectRatio
                        
                        let actualSize = CGSize(width: round(rowSize / summedRatios * (preferredAspectRatio)), height: preferredRowSize)
                        
                        var frame = CGRect(x: offset.x, y: offset.y, width: actualSize.width, height: actualSize.height)
                        if frame.origin.x + frame.size.width >= maxWidth - 2.0 {
                            frame.size.width = max(1.0, maxWidth - frame.origin.x)
                        }
                        
                        displayItems.append(VisibleVideoItem(fileReference: files[j], frame: frame, isTrending: isTrending))
                        
                        offset.x += actualSize.width + minimumInteritemSpacing
                        previousItemSize = actualSize.height
                        verticalOffset = frame.maxY
                        
                        j += 1
                    }
                    
                    if row.count > 0 {
                        offset = CGPoint(x: 0.0, y: offset.y + previousItemSize + minimumLineSpacing)
                    }
                    
                    i += row.count
                }
            }
            
            if !self.files.saved.isEmpty {
                self.savedTitleNode.isHidden = false
                let leftInset: CGFloat = 10.0
                let savedTitleSize = self.savedTitleNode.updateLayout(CGSize(width: drawableSize.width - leftInset * 2.0, height: 100.0))
                self.savedTitleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalOffset - 3.0), size: savedTitleSize)
                verticalOffset += savedTitleSize.height + 5.0
                commitFilesSpans(files: self.files.saved, isTrending: false)
                //commitFiles(files: self.files.saved, isTrending: false)
            } else {
                self.savedTitleNode.isHidden = true
            }
            if !self.files.trending.isEmpty {
                self.trendingHeaderNode.isHidden = false
                let trendingHeight = self.trendingHeaderNode.update(theme: self.theme, strings: self.strings, width: drawableSize.width, sideInset: 0.0)
                self.trendingHeaderNode.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: drawableSize.width, height: trendingHeight))
                verticalOffset += trendingHeight
                commitFilesSpans(files: self.files.trending, isTrending: true)
                //commitFiles(files: self.files.trending, isTrending: true)
            } else {
                self.trendingHeaderNode.isHidden = true
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
            if let (file, rect) = self.fileAt(point: point) {
                self.fileSelected?(file, self, rect)
            }
        }
    }
    
    func frameForItem(_ id: MediaId) -> CGRect? {
        for item in self.displayItems {
            if item.fileReference.media.fileId == id {
                return item.frame
            }
        }
        return nil
    }
    
    func fileAt(point: CGPoint) -> (FileMediaReference, CGRect)? {
        let offsetPoint = point.offsetBy(dx: 0.0, dy: self.scrollNode.bounds.minY)
        return self.offsetFileAt(point: offsetPoint)
    }
    
    private func offsetFileAt(point: CGPoint) -> (FileMediaReference, CGRect)? {
        for item in self.displayItems {
            if item.frame.contains(point) {
                return (item.fileReference, item.frame)
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
