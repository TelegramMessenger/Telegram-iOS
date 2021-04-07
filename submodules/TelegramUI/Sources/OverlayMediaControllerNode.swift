import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import AccountContext

private final class OverlayMediaControllerNodeView: UITracingLayerView {
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
}

private final class OverlayMediaVideoNodeData {
    var node: OverlayMediaItemNode
    var location: CGPoint
    var isMinimized: Bool
    var currentSize: CGSize
    
    init(node: OverlayMediaItemNode, location: CGPoint, isMinimized: Bool, currentSize: CGSize) {
        self.node = node
        self.location = location
        self.isMinimized = isMinimized
        self.currentSize = currentSize
    }
}



final class OverlayMediaControllerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let updatePossibleEmbeddingItem: (OverlayMediaControllerEmbeddingItem?) -> Void
    private let embedPossibleEmbeddingItem: (OverlayMediaControllerEmbeddingItem) -> Bool
    
    private var videoNodes: [OverlayMediaVideoNodeData] = []
    private var validLayout: ContainerViewLayout?
    
    private var locationByGroup: [OverlayMediaItemNodeGroup: CGPoint] = [:]
    
    private weak var draggingNode: OverlayMediaItemNode?
    private var draggingStartPosition = CGPoint()
    
    private var pinchingNode: OverlayMediaItemNode?
    private var pinchingNodeInitialSize: CGSize?
    
    init(updatePossibleEmbeddingItem: @escaping (OverlayMediaControllerEmbeddingItem?) -> Void, embedPossibleEmbeddingItem: @escaping (OverlayMediaControllerEmbeddingItem) -> Bool) {
        self.updatePossibleEmbeddingItem = updatePossibleEmbeddingItem
        self.embedPossibleEmbeddingItem = embedPossibleEmbeddingItem
        
        super.init()
        
        self.setViewBlock({
            return OverlayMediaControllerNodeView()
        })
        
        (self.view as! OverlayMediaControllerNodeView).hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self
        self.view.addGestureRecognizer(panRecognizer)
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchGesture(_:)))
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    deinit {
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        return true
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for item in self.videoNodes {
            if item.node.frame.contains(point) {
                if let result = item.node.hitTest(point.offsetBy(dx: -item.node.frame.origin.x, dy: -item.node.frame.origin.y), with: event) {
                    return result
                } else {
                    return item.node.view
                }
            }
        }
        return nil
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        for item in self.videoNodes {
            let nodeSize = item.currentSize
            transition.updateFrame(node: item.node, frame: CGRect(origin: self.nodePosition(layout: layout, size: nodeSize, location: item.location, hidden: !item.node.customTransition && !item.node.hasAttachedContext, isMinimized: item.isMinimized, tempExtendedTopInset: item.node.tempExtendedTopInset), size: nodeSize))
            item.node.updateLayout(nodeSize)
        }
    }
    
    private func nodePosition(layout: ContainerViewLayout, size: CGSize, location: CGPoint, hidden: Bool, isMinimized: Bool, tempExtendedTopInset: Bool) -> CGPoint {
        var layoutInsets = layout.insets(options: [.input])
        layoutInsets.bottom += 48.0
        if tempExtendedTopInset {
            layoutInsets.top += 38.0
        }
        let inset: CGFloat = 4.0 + layout.safeInsets.left
        var result = CGPoint()
        if location.x.isZero {
            if isMinimized {
                result.x = inset - size.width + 40.0
            } else if hidden {
                result.x = -size.width - inset
            } else {
                result.x = inset
            }
        } else {
            if isMinimized {
                result.x = layout.size.width - inset - 40.0
            } else if hidden {
                result.x = layout.size.width + inset
            } else {
                result.x = layout.size.width - inset - size.width
            }
        }
        if location.y.isZero {
            result.y = layoutInsets.top + inset
        } else {
            result.y = layout.size.height - layoutInsets.bottom - inset - size.height
        }
        return result
    }
    
    private func nodeLocationForPosition(layout: ContainerViewLayout, position: CGPoint, velocity: CGPoint, size: CGSize, tempExtendedTopInset: Bool) -> (CGPoint, Bool) {
        var layoutInsets = layout.insets(options: [.input])
        layoutInsets.bottom += 48.0
        if tempExtendedTopInset {
            layoutInsets.top += 38.0
        }
        var result = CGPoint()
        if position.x < layout.size.width / 2.0 {
            result.x = 0.0
        } else {
            result.x = 1.0
        }
        if position.y < layoutInsets.top + (layout.size.height - layoutInsets.bottom - layoutInsets.top) / 2.0 {
            result.y = 0.0
        } else {
            result.y = 1.0
        }
        
        let currentPosition = result
        
        let angleEpsilon: CGFloat = 30.0
        var shouldHide = false
        
        if (velocity.x * velocity.x + velocity.y * velocity.y) >= 500.0 * 500.0 {
            let x = velocity.x
            let y = velocity.y
            
            var angle = atan2(y, x) * 180.0 / CGFloat.pi * -1.0
            if angle < 0.0 {
                angle += 360.0
            }
            
            if currentPosition.x.isZero && currentPosition.y.isZero {
                if ((angle > 0 && angle < 90 - angleEpsilon) || angle > 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                } else if (angle > 180 + angleEpsilon && angle < 270 + angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                } else if (angle > 270 + angleEpsilon && angle < 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                } else {
                    shouldHide = true
                }
            } else if !currentPosition.x.isZero && currentPosition.y.isZero {
                if (angle > 90 + angleEpsilon && angle < 180 + angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (angle > 270 - angleEpsilon && angle < 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                }
                else if (angle > 180 + angleEpsilon && angle < 270 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                }
                else {
                    shouldHide = true
                }
            } else if currentPosition.x.isZero && !currentPosition.y.isZero {
                if (angle > 90 - angleEpsilon && angle < 180 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (angle < angleEpsilon || angle > 270 + angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                }
                else if (angle > angleEpsilon && angle < 90 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                }
                else if (!shouldHide) {
                    shouldHide = true
                }
            } else if !currentPosition.x.isZero && !currentPosition.y.isZero {
                if (angle > angleEpsilon && angle < 90 + angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                }
                else if (angle > 180 - angleEpsilon && angle < 270 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                }
                else if (angle > 90 + angleEpsilon && angle < 180 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (!shouldHide) {
                    shouldHide = true
                }
            }
        }
        
        return (result, shouldHide)
    }
    
    var hasNodes: Bool {
        return !self.videoNodes.isEmpty
    }
    
    func addNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        var location = CGPoint(x: 1.0, y: 0.0)
        node.customTransition = customTransition
        if let group = node.group {
            if let groupLocation = self.locationByGroup[group] {
                location = groupLocation
            }
        }
        let nodeData = OverlayMediaVideoNodeData(node: node, location: location, isMinimized: false, currentSize: node.preferredSizeForOverlayDisplay(boundingSize: self.frame.size))
        self.videoNodes.append(nodeData)
        self.addSubnode(node)
        if let validLayout = self.validLayout {
            let nodeSize = nodeData.currentSize
            if self.draggingNode !== node {
                if customTransition {
                    node.frame = CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: location, hidden: false, isMinimized: false, tempExtendedTopInset: node.tempExtendedTopInset), size: nodeSize)
                } else {
                    node.frame = CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: location, hidden: true, isMinimized: false, tempExtendedTopInset: node.tempExtendedTopInset), size: nodeSize)
                }
            }
            node.updateLayout(nodeSize)
            
            self.containerLayoutUpdated(validLayout, transition: .immediate)
            
            if !customTransition {
                let positionX = CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: location, hidden: true, isMinimized: false, tempExtendedTopInset: node.tempExtendedTopInset), size: nodeSize).center.x
                node.layer.animatePosition(from: CGPoint(x: positionX - node.layer.position.x, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        node.hasAttachedContextUpdated = { [weak self] _ in
            if let strongSelf = self, let validLayout = strongSelf.validLayout, !customTransition {
                strongSelf.containerLayoutUpdated(validLayout, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        node.unminimize = { [weak self, weak node] in
            if let strongSelf = self, let node = node {
                if let index = strongSelf.videoNodes.firstIndex(where: { $0.node === node }), let validLayout = strongSelf.validLayout, node !== strongSelf.draggingNode, strongSelf.videoNodes[index].isMinimized {
                    strongSelf.videoNodes[index].isMinimized = false
                    node.updateMinimizedEdge(nil, adjusting: true)
                    strongSelf.containerLayoutUpdated(validLayout, transition: .animated(duration: 0.3, curve: .spring))
                }
            }
        }
        node.setShouldAcquireContext(true)
    }
    
    func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        if node.supernode === self {
            node.hasAttachedContextUpdated = nil
            node.setShouldAcquireContext(false)
            if let index = self.videoNodes.firstIndex(where: { $0.node === node }), let validLayout = self.validLayout {
                if customTransition {
                    node.removeFromSupernode()
                } else {
                    let nodeSize = self.videoNodes[index].currentSize
                    node.layer.animateFrame(from: node.layer.frame, to: CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: self.videoNodes[index].location, hidden: true, isMinimized: self.videoNodes[index].isMinimized, tempExtendedTopInset: node.tempExtendedTopInset), size: nodeSize), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak node] _ in
                        node?.removeFromSupernode()
                    })
                }
            } else {
                node.removeFromSupernode()
            }
            if let index = self.videoNodes.firstIndex(where: { $0.node === node }) {
                self.videoNodes.remove(at: index)
            }
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let draggingNode = self.draggingNode, let validLayout = self.validLayout, let index = self.videoNodes.firstIndex(where: { $0.node === draggingNode }){
                    let nodeSize = self.videoNodes[index].currentSize
                    let previousFrame = draggingNode.frame
                    draggingNode.frame = CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: self.videoNodes[index].location, hidden: !draggingNode.customTransition && !draggingNode.hasAttachedContext, isMinimized: self.videoNodes[index].isMinimized, tempExtendedTopInset: draggingNode.tempExtendedTopInset), size: nodeSize)
                    draggingNode.layer.animateFrame(from: previousFrame, to: draggingNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    self.draggingNode = nil
                }
                loop: for item in self.videoNodes {
                    if item.node.frame.contains(recognizer.location(in: self.view)) {
                        self.draggingNode = item.node
                        self.draggingStartPosition = item.node.frame.origin
                        break loop
                    }
                }
            case .changed:
                if let draggingNode = self.draggingNode, let validLayout = self.validLayout {
                    let translation = recognizer.translation(in: self.view)
                    var nodeFrame = draggingNode.frame
                    nodeFrame.origin = self.draggingStartPosition.offsetBy(dx: translation.x, dy: translation.y)
                    if nodeFrame.midX < 0.0 {
                        draggingNode.updateMinimizedEdge(.left, adjusting: true)
                    } else if nodeFrame.midX > validLayout.size.width {
                        draggingNode.updateMinimizedEdge(.right, adjusting: true)
                    } else {
                        draggingNode.updateMinimizedEdge(nil, adjusting: true)
                    }
                    draggingNode.frame = nodeFrame
                    self.updatePossibleEmbeddingItem(OverlayMediaControllerEmbeddingItem(
                        position: nodeFrame.center,
                        itemNode: draggingNode
                    ))
                }
            case .ended, .cancelled:
                if let draggingNode = self.draggingNode, let validLayout = self.validLayout, let index = self.videoNodes.firstIndex(where: { $0.node === draggingNode }){
                    let nodeSize = self.videoNodes[index].currentSize
                    let previousFrame = draggingNode.frame
                    
                    if self.embedPossibleEmbeddingItem(OverlayMediaControllerEmbeddingItem(
                        position: previousFrame.center,
                        itemNode: draggingNode
                    )) {
                        self.draggingNode = nil
                    } else {
                        let (updatedLocation, shouldDismiss) = self.nodeLocationForPosition(layout: validLayout, position: CGPoint(x: previousFrame.midX, y: previousFrame.midY), velocity: recognizer.velocity(in: self.view), size: nodeSize, tempExtendedTopInset: draggingNode.tempExtendedTopInset)
                        
                        if shouldDismiss && draggingNode.isMinimizeable {
                            draggingNode.updateMinimizedEdge(updatedLocation.x.isZero ? .left : .right, adjusting: false)
                            self.videoNodes[index].isMinimized = true
                        } else {
                            draggingNode.updateMinimizedEdge(nil, adjusting: true)
                            self.videoNodes[index].isMinimized = false
                        }
                        
                        if let group = draggingNode.group {
                            self.locationByGroup[group] = updatedLocation
                        }
                        self.videoNodes[index].location = updatedLocation
                        
                        draggingNode.frame = CGRect(origin: self.nodePosition(layout: validLayout, size: nodeSize, location: updatedLocation, hidden: !draggingNode.hasAttachedContext, isMinimized: self.videoNodes[index].isMinimized, tempExtendedTopInset: draggingNode.tempExtendedTopInset), size: nodeSize)
                        draggingNode.layer.animateFrame(from: previousFrame, to: draggingNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                        self.draggingNode = nil
                        
                        if shouldDismiss && !draggingNode.isMinimizeable {
                            draggingNode.dismiss()
                        }
                    }
                    self.updatePossibleEmbeddingItem(nil)
                }
            default:
                break
        }
    }
    
    @objc func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
            case .began:
                let location = recognizer.location(in: self.view)
                loop: for videoNode in self.videoNodes {
                    if videoNode.node.frame.contains(location) {
                        if videoNode.node.isMinimizeable {
                            self.pinchingNode = videoNode.node
                            self.pinchingNodeInitialSize = videoNode.currentSize
                        }
                        break loop
                    }
                }
            case .changed:
                if let validLayout = self.validLayout, let pinchingNode = self.pinchingNode, let initialSize = self.pinchingNodeInitialSize {
                    let minSize = CGSize(width: 180.0, height: 90.0)
                    let maxSize = CGSize(width: validLayout.size.width - validLayout.safeInsets.left - validLayout.safeInsets.right - 14.0, height: 500.0)
                    
                    let scale = recognizer.scale
                    var updatedSize = CGSize(width: floor(initialSize.width * scale), height: floor(initialSize.height * scale))
                    updatedSize = updatedSize.fitted(maxSize)
                    if updatedSize.width < minSize.width {
                        updatedSize = updatedSize.aspectFitted(CGSize(width: minSize.width, height: 1000.0))
                    }
                    
                    loop: for videoNode in self.videoNodes {
                        if videoNode.node === pinchingNode {
                            videoNode.currentSize = updatedSize
                            break loop
                        }
                    }
                    
                    self.containerLayoutUpdated(validLayout, transition: .immediate)
                }
            case .ended, .cancelled:
                self.pinchingNode = nil
                self.pinchingNodeInitialSize = nil
            default:
                break
        }
    }
}
