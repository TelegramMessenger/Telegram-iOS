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
        self.imageContainerNode.cornerRadius = 4.0
        let (signal, imageSize) = item.image
        self.imageSize = imageSize
        
        super.init()
        
        self.imageContainerNode.addSubnode(self.imageNode)
        self.addSubnode(self.imageContainerNode)
        self.imageNode.setSignal(signal)
    }
    
    func updateLayout(height: CGFloat, progress: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let baseWidth: CGFloat = 20.0
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

final class GalleryThumbnailContainerNode: ASDisplayNode {
    let groupId: Int64
    private let contentNode: ASDisplayNode
    
    private var items: [GalleryThumbnailItem] = []
    private var itemNodes: [GalleryThumbnailItemNode] = []
    private var centralIndexAndProgress: (Int, CGFloat)?
    private var currentLayout: CGSize?
    
    init(groupId: Int64) {
        self.groupId = groupId
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
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
                    self.contentNode.addSubnode(itemNode)
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
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        if let (centralIndex, progress) = self.centralIndexAndProgress {
            self.updateLayout(size: size, centralIndex: centralIndex, progress: progress, transition: transition)
        }
    }
    
    func updateLayout(size: CGSize, centralIndex: Int, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayout = size
        self.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        let spacing: CGFloat = 2.0
        let centralSpacing: CGFloat = 6.0
        let itemHeight: CGFloat = 30.0
        let centralProgress: CGFloat = 1.0 - abs(progress * 2.0)
        let leftProgress: CGFloat = max(0.0, -progress * 2.0)
        let rightProgress: CGFloat = max(0.0, progress * 2.0)
        
        let centralWidth = self.itemNodes[centralIndex].updateLayout(height: itemHeight, progress: centralProgress, transition: transition)
        var centralFrame = CGRect(origin: CGPoint(x: ((size.width - centralWidth) / 2.0), y: 0.0), size: CGSize(width: centralWidth, height: itemHeight))
        centralFrame.origin.x += -progress * 2.0 * centralFrame.width
        let currentCentralSpacing: CGFloat = centralProgress * centralSpacing + (1.0 - centralProgress) * spacing
        var leftOffset = centralFrame.minX - currentCentralSpacing
        var rightOffset = centralFrame.maxX + currentCentralSpacing
        transition.updateFrame(node: self.itemNodes[centralIndex], frame: centralFrame)
        
        for i in (0 ..< centralIndex).reversed() {
            let progress: CGFloat = i == centralIndex - 1 ? leftProgress : 0.0
            let itemSpacing: CGFloat = progress * centralSpacing + (1.0 - progress) * spacing
            let itemWidth = self.itemNodes[i].updateLayout(height: itemHeight, progress: progress, transition: transition)
            transition.updateFrame(node: self.itemNodes[i], frame: CGRect(origin: CGPoint(x: leftOffset - itemWidth, y: 0.0), size: CGSize(width: itemWidth, height: itemHeight)))
            leftOffset -= itemSpacing + itemWidth
        }
        
        for i in (centralIndex + 1) ..< self.itemNodes.count {
            let progress = i == centralIndex + 1 ? rightProgress : 0.0
            let itemSpacing: CGFloat = progress * centralSpacing + (1.0 - progress) * spacing
            let itemWidth = self.itemNodes[i].updateLayout(height: itemHeight, progress: progress, transition: transition)
            transition.updateFrame(node: self.itemNodes[i], frame: CGRect(origin: CGPoint(x: rightOffset, y: 0.0), size: CGSize(width: itemWidth, height: itemHeight)))
            rightOffset += itemSpacing + itemWidth
        }
    }
}
