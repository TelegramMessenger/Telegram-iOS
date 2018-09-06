import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

protocol GalleryThumbnailItem {
    func isEqual(to: GalleryThumbnailItem) -> Bool
    var image: (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) { get }
}

private final class GalleryThumbnailItemNode: ASDisplayNode {
    private let imageNode: TransformImageNode
    private let imageContainerNode: ASDisplayNode
    
    private let imageSize: CGSize
    
    init(item: GalleryThumbnailItem) {
        self.imageNode = TransformImageNode()
        self.imageContainerNode = ASDisplayNode()
        self.imageContainerNode.clipsToBounds = true
        self.imageContainerNode.cornerRadius = 2.0
        let (signal, imageSize) = item.image
        self.imageSize = imageSize
        
        super.init()
        
        self.imageContainerNode.addSubnode(self.imageNode)
        self.addSubnode(self.imageContainerNode)
        self.imageNode.setSignal(signal)
    }
    
    func updateLayout(height: CGFloat, progress: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let baseWidth: CGFloat = 23.0
        let boundingSize = self.imageSize.aspectFilled(CGSize(width: 1.0, height: height))
        let width = baseWidth * (1.0 - progress) + boundingSize.width * progress
        let arguments = TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
        let makeLayout = self.imageNode.asyncLayout()
        let apply = makeLayout(arguments)
        apply()
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: (width - boundingSize.width) / 2.0, y: 0.0), size: boundingSize))
        transition.updateFrame(node: self.imageContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        
        return width
    }
}

final class GalleryThumbnailContainerNode: ASDisplayNode, UIScrollViewDelegate {
    let groupId: Int64
    private let scrollNode: ASScrollNode
    
    private(set) var items: [GalleryThumbnailItem] = []
    private var itemNodes: [GalleryThumbnailItemNode] = []
    private var centralIndexAndProgress: (Int, CGFloat)?
    private var currentLayout: CGSize?
    
    init(groupId: Int64) {
        self.groupId = groupId
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
    }
    
    func updateItems(_ items: [GalleryThumbnailItem], centralIndex: Int, progress: CGFloat) {
        var updated = false
        if self.items.count == items.count {
            for i in 0 ..< self.items.count {
                if !self.items[i].isEqual(to: items[i]) {
                    updated = true
                    break
                }
            }
        } else {
            updated = true
        }
        if updated {
            var itemNodes: [GalleryThumbnailItemNode] = []
            for item in items {
                if let index = self.items.index(where: { $0.isEqual(to: item) }) {
                    itemNodes.append(self.itemNodes[index])
                } else {
                    itemNodes.append(GalleryThumbnailItemNode(item: item))
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
        self.centralIndexAndProgress = (centralIndex, progress)
        if let size = self.currentLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func updateCentralIndexAndProgress(centralIndex: Int, progress: CGFloat) {
        self.centralIndexAndProgress = (centralIndex, progress)
        if let size = self.currentLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        if let (centralIndex, progress) = self.centralIndexAndProgress {
            self.updateLayout(size: size, centralIndex: centralIndex, progress: progress, transition: transition)
        }
    }
    
    func updateLayout(size: CGSize, centralIndex: Int, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        let spacing: CGFloat = 2.0
        let centralSpacing: CGFloat = 8.0
        let itemHeight: CGFloat = 42.0
        
        var itemFrames: [CGRect] = []
        var lastTrailingSpacing: CGFloat = 0.0
        for i in 0 ..< self.itemNodes.count {
            let itemProgress: CGFloat
            if i == centralIndex {
                itemProgress = 1.0 - abs(progress)
            } else if i == centralIndex - 1 {
                itemProgress = max(0.0, -progress)
            } else if i == centralIndex + 1 {
                itemProgress = max(0.0, progress)
            } else {
                itemProgress = 0.0
            }
            let itemSpacing = itemProgress * centralSpacing + (1.0 - itemProgress) * spacing
            let itemX: CGFloat
            if i == 0 {
                itemX = lastTrailingSpacing
            } else {
                itemX = lastTrailingSpacing + itemFrames[itemFrames.count - 1].maxX + itemSpacing * 0.5
            }
            if i == self.itemNodes.count - 1 {
                lastTrailingSpacing = 0.0
            } else {
                lastTrailingSpacing = itemSpacing * 0.5
            }
            let itemWidth = self.itemNodes[i].updateLayout(height: itemHeight, progress: itemProgress, transition: transition)
            itemFrames.append(CGRect(origin: CGPoint(x: itemX, y: 0.0), size: CGSize(width: itemWidth, height: itemHeight)))
        }
        
        for i in 0 ..< itemFrames.count {
            if i == centralIndex {
                var midX = itemFrames[i].midX
                if progress < 0.0 {
                    if i != 0 {
                        midX = midX * (1.0 - abs(progress)) + itemFrames[i - 1].midX * abs(progress)
                    } else {
                        midX = midX * (1.0 - abs(progress)) + itemFrames[i].offsetBy(dx: -itemFrames[i].width, dy: 0.0).midX * abs(progress)
                    }
                } else if progress > 0.0 {
                    if i != itemFrames.count - 1 {
                        midX = midX * (1.0 - abs(progress)) + itemFrames[i + 1].midX * abs(progress)
                    } else {
                        midX = midX * (1.0 - abs(progress)) + itemFrames[i].offsetBy(dx: itemFrames[i].width, dy: 0.0).midX * abs(progress)
                    }
                }
                let offset = size.width / 2.0 - midX
                for j in 0 ..< itemFrames.count {
                    itemFrames[j].origin.x += offset
                }
                break
            }
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
    
    func animateOut(toRight: Bool) {
        let collection = toRight ? self.itemNodes : self.itemNodes.reversed()
        let offset: CGFloat = toRight ? -15.0 : 15.0
        var delay: Double = 0.0
        for itemNode in collection {
            itemNode.layer.animateScale(from: 1.0, to: 0.9, duration: 0.15 + delay, removeOnCompletion: false)
            itemNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: offset, y: 0.0), duration: 0.15 + delay, removeOnCompletion: false, additive: true)
            delay += 0.01
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
    }
}
