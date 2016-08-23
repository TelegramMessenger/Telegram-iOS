import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class GalleryPagerNode: ASDisplayNode, UIScrollViewDelegate {
    private let pageGap: CGFloat = 20.0
    
    private let scrollView: UIScrollView
    
    private var items: [GalleryItem] = []
    private var itemNodes: [GalleryItemNode] = []
    private var centralItemIndex: Int? {
        didSet {
            if oldValue != self.centralItemIndex {
                self.centralItemIndexUpdated(self.centralItemIndex)
            }
        }
    }
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var centralItemIndexUpdated: (Int?) -> Void = { _ in }
    var toggleControlsVisibility: () -> Void = { }
    
    override init() {
        self.scrollView = UIScrollView()
        
        super.init()
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.isPagingEnabled = true
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.scrollsToTop = false
        self.view.addSubview(self.scrollView)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var previousCentralNodeHorizontalOffset: CGFloat?
        if let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            previousCentralNodeHorizontalOffset = self.scrollView.contentOffset.x - centralNode.frame.minX
        }
        
        self.scrollView.frame = CGRect(origin: CGPoint(x: -self.pageGap, y: 0.0), size: CGSize(width: layout.size.width + self.pageGap * 2.0, height: layout.size.height))
        
        for i in 0 ..< self.itemNodes.count {
            self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
            self.itemNodes[i].containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if let previousCentralNodeHorizontalOffset = previousCentralNodeHorizontalOffset, let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            self.scrollView.contentOffset = CGPoint(x: centralNode.frame.minX + previousCentralNodeHorizontalOffset, y: 0.0)
        }
        
        self.updateItemNodes()
    }
    
    func ready() -> Signal<Void, NoError> {
        if let itemNode = self.centralItemNode() {
            return itemNode.ready()
        }
        return .single(Void())
    }
    
    func centralItemNode() -> GalleryItemNode? {
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            return centralItemNode
        } else {
            return nil
        }
    }
    
    func replaceItems(_ items: [GalleryItem], centralItemIndex: Int?) {
        for itemNode in self.itemNodes {
            itemNode.removeFromSupernode()
        }
        self.itemNodes.removeAll()
        if let centralItemIndex = centralItemIndex, centralItemIndex >= 0 && centralItemIndex < items.count {
            self.centralItemIndex = centralItemIndex
        } else {
            self.centralItemIndex = nil
        }
        self.items = items
        
        self.updateItemNodes()
    }
    
    private func makeNodeForItem(at index: Int) -> GalleryItemNode {
        let node = self.items[index].node()
        node.toggleControlsVisibility = self.toggleControlsVisibility
        node.index = index
        return node
    }
    
    private func visibleItemNode(at index: Int) -> GalleryItemNode? {
        for itemNode in self.itemNodes {
            if itemNode.index == index {
                return itemNode
            }
        }
        return nil
    }
    
    private func addVisibleItemNode(_ node: GalleryItemNode) {
        var added = false
        for i in 0 ..< self.itemNodes.count {
            if node.index < self.itemNodes[i].index {
                self.itemNodes.insert(node, at: i)
                added = true
                break
            }
        }
        if !added {
            self.itemNodes.append(node)
        }
        self.scrollView.addSubview(node.view)
    }
    
    private func removeVisibleItemNode(internalIndex: Int) {
        self.itemNodes[internalIndex].view.removeFromSuperview()
        self.itemNodes.remove(at: internalIndex)
    }
    
    private func updateItemNodes() {
        if self.items.isEmpty {
            return
        }
        
        var resetOffsetToCentralItem = false
        if self.itemNodes.isEmpty {
            let node = self.makeNodeForItem(at: self.centralItemIndex ?? 0)
            node.frame = CGRect(origin: CGPoint(), size: scrollView.bounds.size)
            if let containerLayout = self.containerLayout {
                node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
            }
            self.addVisibleItemNode(node)
            self.centralItemIndex = node.index
            resetOffsetToCentralItem = true
        }
        
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            if centralItemIndex != 0 {
                if self.visibleItemNode(at: centralItemIndex - 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex - 1)
                    node.frame = centralItemNode.frame.offsetBy(dx: -centralItemNode.frame.size.width - self.pageGap, dy: 0.0)
                    if let containerLayout = self.containerLayout {
                        node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            if centralItemIndex != items.count - 1 {
                if self.visibleItemNode(at: centralItemIndex + 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex + 1)
                    node.frame = centralItemNode.frame.offsetBy(dx: centralItemNode.frame.size.width + self.pageGap, dy: 0.0)
                    if let containerLayout = self.containerLayout {
                        node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            for i in 0 ..< self.itemNodes.count {
                self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
            }
            
            if resetOffsetToCentralItem {
                self.scrollView.contentOffset = CGPoint(x: centralItemNode.frame.minX - self.pageGap, y: 0.0)
            }
            
            if let centralItemCandidateNode = self.centralItemCandidate(), centralItemCandidateNode.index != centralItemIndex {
                for i in (0 ..< self.itemNodes.count).reversed() {
                    let node = self.itemNodes[i]
                    if node.index < centralItemCandidateNode.index - 1 || node.index > centralItemCandidateNode.index + 1 {
                        self.removeVisibleItemNode(internalIndex: i)
                    }
                }
                
                self.centralItemIndex = centralItemCandidateNode.index
                
                if centralItemCandidateNode.index != 0 {
                    if self.visibleItemNode(at: centralItemCandidateNode.index - 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index - 1)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: -centralItemCandidateNode.frame.size.width - self.pageGap, dy: 0.0)
                        if let containerLayout = self.containerLayout {
                            node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                if centralItemCandidateNode.index != items.count - 1 {
                    if self.visibleItemNode(at: centralItemCandidateNode.index + 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index + 1)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: centralItemCandidateNode.frame.size.width + self.pageGap, dy: 0.0)
                        if let containerLayout = self.containerLayout {
                            node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                let previousCentralCandidateHorizontalOffset = self.scrollView.contentOffset.x - centralItemCandidateNode.frame.minX
                
                for i in 0 ..< self.itemNodes.count {
                    self.itemNodes[i].frame = CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height))
                }
                
                self.scrollView.contentOffset = CGPoint(x: centralItemCandidateNode.frame.minX + previousCentralCandidateHorizontalOffset, y: 0.0)
            }
            
            self.scrollView.contentSize = CGSize(width: CGFloat(self.itemNodes.count) * self.scrollView.bounds.size.width, height: self.scrollView.bounds.size.height)
        } else {
            assertionFailure()
        }
        
        for itemNode in self.itemNodes {
            itemNode.centralityUpdated(isCentral: itemNode.index == self.centralItemIndex)
            itemNode.visibilityUpdated(isVisible: self.scrollView.bounds.intersects(itemNode.frame))
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateItemNodes()
    }
    
    private func centralItemCandidate() -> GalleryItemNode? {
        let hotizontlOffset = self.scrollView.contentOffset.x + self.pageGap
        var closestNodeAndDistance: (Int, CGFloat)?
        for i in 0 ..< self.itemNodes.count {
            let node = self.itemNodes[i]
            let distance = abs(node.frame.minX - hotizontlOffset)
            if let currentClosestNodeAndDistance = closestNodeAndDistance {
                if distance < currentClosestNodeAndDistance.1 {
                    closestNodeAndDistance = (node.index, distance)
                }
            } else {
                closestNodeAndDistance = (node.index, distance)
            }
        }
        if let closestNodeAndDistance = closestNodeAndDistance {
            return self.visibleItemNode(at: closestNodeAndDistance.0)
        } else {
            return nil
        }
    }
}
