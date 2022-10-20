import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

private let itemBaseSize = CGSize(width: 23.0, height: 42.0)
private let spacing: CGFloat = 2.0
private let maxWidth: CGFloat = 75.0

public protocol GalleryThumbnailItem {
    func isEqual(to: GalleryThumbnailItem) -> Bool
    func image(synchronous: Bool) -> (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize)
}

private final class GalleryThumbnailItemNode: ASDisplayNode {
    private let imageNode: TransformImageNode
    private let imageContainerNode: ASDisplayNode
    
    private let imageSize: CGSize
    
    init(item: GalleryThumbnailItem, synchronous: Bool) {
        self.imageNode = TransformImageNode()
        self.imageContainerNode = ASDisplayNode()
        self.imageContainerNode.clipsToBounds = true
        self.imageContainerNode.cornerRadius = 2.0
        let (signal, imageSize) = item.image(synchronous: synchronous)
        self.imageSize = imageSize
        
        super.init()
        
        self.imageContainerNode.addSubnode(self.imageNode)
        self.addSubnode(self.imageContainerNode)
        self.imageNode.setSignal(signal, attemptSynchronously: synchronous)
    }
    
    func updateLayout(height: CGFloat, progress: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let boundingSize = self.imageSize.aspectFilled(CGSize(width: 1.0, height: height))
        let width = itemBaseSize.width * (1.0 - progress) + min(maxWidth, boundingSize.width) * progress
        let arguments = TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
        let makeLayout = self.imageNode.asyncLayout()
        let apply = makeLayout(arguments)
        apply()
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: (width - boundingSize.width) / 2.0, y: 0.0), size: boundingSize))
        transition.updateFrame(node: self.imageContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        
        return width
    }
}

public final class GalleryThumbnailContainerNode: ASDisplayNode, UIScrollViewDelegate {
    public let groupId: Int64
    private let scrollNode: ASScrollNode
    
    public private(set) var items: [GalleryThumbnailItem] = []
    public private(set) var indexes: [Int] = []
    private var itemNodes: [GalleryThumbnailItemNode] = []
    private var centralIndexAndProgress: (Int, CGFloat?)?
    private var currentLayout: CGSize?
    public var updateSynchronously: Bool = false
    
    private var isPanning: Bool = false
    
    public var itemChanged: ((Int) -> Void)?
    
    public init(groupId: Int64) {
        self.groupId = groupId
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        self.addSubnode(self.scrollNode)
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        for i in 0 ..< self.itemNodes.count {
            let view = self.itemNodes[i]
            if view.frame.contains(location) {
                self.updateCentralIndexAndProgress(centralIndex: i, progress: 0.0, transition: .animated(duration: 0.4, curve: .spring))
                self.itemChanged?(i)
                break
            }
        }
    }
    
    public func updateItems(_ items: [GalleryThumbnailItem], indexes: [Int], centralIndex: Int, progress: CGFloat) {
        self.indexes = indexes
        let items: [GalleryThumbnailItem] = items.count <= 1 ? [] : items
        var updated = false
        if self.items.count == items.count {
            for i in 0 ..< self.items.count {
                if !self.items[i].isEqual(to: items[i]) {
                    updated = true
                }
            }
        } else {
            updated = true
        }
        if updated {
            var itemNodes: [GalleryThumbnailItemNode] = []
            for item in items {
                if let index = self.items.firstIndex(where: { $0.isEqual(to: item) }) {
                    itemNodes.append(self.itemNodes[index])
                } else {
                    itemNodes.append(GalleryThumbnailItemNode(item: item, synchronous: self.updateSynchronously))
                }
            }
            
            for itemNode in itemNodes {
                if itemNode.supernode == nil {
                    self.scrollNode.addSubnode(itemNode)
                }
            }
            for itemNode in self.itemNodes {
                if !itemNodes.contains(where: { $0 === itemNode }) {
                    itemNode.removeFromSupernode()
                }
            }
            self.items = items
            self.itemNodes = itemNodes
        }
        
        var updatedIndexOnly = false
        if let centralIndexAndProgress = self.centralIndexAndProgress, centralIndexAndProgress.0 != centralIndex, centralIndexAndProgress.1 == progress {
            updatedIndexOnly = true
        }
        
        self.centralIndexAndProgress = (centralIndex, progress)
        if let size = self.currentLayout {
            self.updateLayout(size: size, transition: updatedIndexOnly ? .animated(duration: 0.2, curve: .spring) : .immediate)
        }
    }
    
    public func updateCentralIndexAndProgress(centralIndex: Int, progress: CGFloat, transition: ContainedViewLayoutTransition = .immediate) {
        self.centralIndexAndProgress = (centralIndex, progress)
        if let size = self.currentLayout {
            self.updateLayout(size: size, transition: transition)
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        if let (centralIndex, progress) = self.centralIndexAndProgress {
            self.updateLayout(size: size, centralIndex: centralIndex, progress: progress, transition: transition)
        }
    }
    
    private func contentOffsetToCenterItem(index: Int, progress: CGFloat?, contentInset: UIEdgeInsets) -> CGPoint {
        let progress = progress ?? 0.0
        return CGPoint(x: -contentInset.left + (CGFloat(index) + progress) * (itemBaseSize.width + spacing), y: 0.0)
    }
    
    public func updateLayout(size: CGSize, centralIndex: Int, progress: CGFloat?, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        let centralSpacing: CGFloat = 8.0
        
        let contentInset = UIEdgeInsets(top: 0.0, left: size.width / 2.0, bottom: 0.0, right: 0.0)
        let contentSize = CGSize(width: size.width - contentInset.left + (itemBaseSize.width + spacing) * CGFloat(self.itemNodes.count - 1), height : size.height)
        
        var updated = false
        if contentInset != self.scrollNode.view.contentInset {
            self.scrollNode.view.contentInset = contentInset
            updated = true
        }
        if contentSize != self.scrollNode.view.contentSize {
            self.scrollNode.view.contentSize = contentSize
            updated = true
        }
                
        var progress = progress ?? 0.0
        if centralIndex == 0 && progress < 0.0 {
            progress = 0.0
        } else if centralIndex == self.itemNodes.count - 1 && progress > 0.0 {
            progress = 0.0
        }
        
        
        if updated || !self.isPanning {
            transition.animateView {
                self.scrollNode.view.contentOffset = self.contentOffsetToCenterItem(index: centralIndex, progress: progress, contentInset: contentInset)
            }
        }
        
        var itemFrames: [CGRect] = []
        var lastTrailingSpacing: CGFloat = 0.0
        var xOffset: CGFloat = -itemBaseSize.width / 2.0
        for i in 0 ..< self.itemNodes.count {
            let itemProgress: CGFloat
            if i == centralIndex && !self.isPanning {
                itemProgress = 1.0 - abs(progress)
            } else if i == centralIndex - 1 {
                itemProgress = max(0.0, -progress)
            } else if i == centralIndex + 1 {
                itemProgress = max(0.0, progress)
            } else {
                itemProgress = 0.0
            }
            let itemSpacing = itemProgress * centralSpacing + (1.0 - itemProgress) * spacing
            let itemWidth = self.itemNodes[i].updateLayout(height: itemBaseSize.height, progress: itemProgress, transition: transition)
           
            if itemWidth > itemBaseSize.width {
                xOffset -= (itemWidth - itemBaseSize.width) / 2.0
                if itemSpacing > spacing && i > 0 {
                    xOffset -= (itemSpacing - spacing) / 2.0
                }
            }
            
            let itemX: CGFloat
            if i == 0 {
                itemX = 0.0
            } else {
                itemX = itemFrames[itemFrames.count - 1].maxX + lastTrailingSpacing + itemSpacing * 0.5
            }
            if i == self.itemNodes.count - 1 {
                lastTrailingSpacing = 0.0
            } else {
                lastTrailingSpacing = itemSpacing * 0.5
            }            
            itemFrames.append(CGRect(origin: CGPoint(x: itemX, y: 0.0), size: CGSize(width: itemWidth, height: itemBaseSize.height)))
        }
        
        for i in 0 ..< itemFrames.count {
            itemFrames[i].origin.x += xOffset
        }
        
        for i in 0 ..< self.itemNodes.count {
            transition.updateFrame(node: self.itemNodes[i], frame: itemFrames[i])
        }
    }
    
    func animateIn(fromLeft: Bool) {
        let collection = fromLeft ? self.itemNodes : self.itemNodes.reversed()
        let offset: CGFloat = fromLeft ? 15.0 : -15.0
        var delay: Double = 0.0
        for itemNode in collection {
            itemNode.layer.animateScale(from: 0.9, to: 1.0, duration: 0.15 + delay)
            itemNode.layer.animatePosition(from: CGPoint(x: offset, y: 0.0), to: CGPoint(), duration: 0.15 + delay, additive: true)
            delay += 0.01
        }
    }
    
    public func animateOut(toRight: Bool) {
        let collection = toRight ? self.itemNodes : self.itemNodes.reversed()
        let offset: CGFloat = toRight ? -15.0 : 15.0
        var delay: Double = 0.0
        for itemNode in collection {
            itemNode.layer.animateScale(from: 1.0, to: 0.9, duration: 0.15 + delay, removeOnCompletion: false)
            itemNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: offset, y: 0.0), duration: 0.15 + delay, removeOnCompletion: false, additive: true)
            delay += 0.01
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let currentLayout = self.currentLayout else {
            return
        }
    
        if scrollView.isDragging && !self.isPanning {
            if let (currentCentralIndex, _) = self.centralIndexAndProgress {
                self.centralIndexAndProgress = (currentCentralIndex, nil)
            }
            self.isPanning = true
            
            self.updateLayout(size: currentLayout, transition: .animated(duration: 0.4, curve: .spring))
        }
        
        if scrollView.isDragging || scrollView.isDecelerating {
            let position = scrollView.contentInset.left + scrollView.contentOffset.x
            let index = max(0, min(self.items.count - 1, Int(round(position / (itemBaseSize.width + spacing)))))
            
            if let (currentCentralIndex, _) = self.centralIndexAndProgress, currentCentralIndex != index {
                self.centralIndexAndProgress = (index, nil)
                self.itemChanged?(index)
            }
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let currentLayout = self.currentLayout else {
            return
        }
        
        if let _ = self.centralIndexAndProgress {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            if !decelerate {
                self.isPanning = false
                self.updateLayout(size: currentLayout, transition: transition)
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let currentLayout = self.currentLayout, !scrollView.isTracking else {
            return
        }
        
        if let (centralIndex, progress) = self.centralIndexAndProgress {
            let contentOffset = contentOffsetToCenterItem(index: centralIndex, progress: progress, contentInset: self.scrollNode.view.contentInset)
         
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            if self.isPanning {
                self.isPanning = false
                self.updateLayout(size: currentLayout, transition: transition)
            }
            transition.animateView {
                self.scrollNode.view.contentOffset = contentOffset
            }
        }
    }
}
