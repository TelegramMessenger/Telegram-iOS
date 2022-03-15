import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle

let maxInteritemSpacing: CGFloat = 240.0
let sectionInsetTop: CGFloat = 40.0
let sectionInsetBottom: CGFloat = 0.0
let zOffset: CGFloat = -60.0

let perspectiveCorrection: CGFloat = -1.0 / 1000.0
let maxRotationAngle: CGFloat = -CGFloat.pi / 2.2

extension CATransform3D {
    func interpolate(other: CATransform3D, progress: CGFloat) -> CATransform3D {
        var vectors = Array<CGFloat>(repeating: 0.0, count: 16)
        vectors[0]  = self.m11 + (other.m11 - self.m11) * progress
        vectors[1]  = self.m12 + (other.m12 - self.m12) * progress
        vectors[2]  = self.m13 + (other.m13 - self.m13) * progress
        vectors[3]  = self.m14 + (other.m14 - self.m14) * progress
        vectors[4]  = self.m21 + (other.m21 - self.m21) * progress
        vectors[5]  = self.m22 + (other.m22 - self.m22) * progress
        vectors[6]  = self.m23 + (other.m23 - self.m23) * progress
        vectors[7]  = self.m24 + (other.m24 - self.m24) * progress
        vectors[8]  = self.m31 + (other.m31 - self.m31) * progress
        vectors[9]  = self.m32 + (other.m32 - self.m32) * progress
        vectors[10] = self.m33 + (other.m33 - self.m33) * progress
        vectors[11] = self.m34 + (other.m34 - self.m34) * progress
        vectors[12] = self.m41 + (other.m41 - self.m41) * progress
        vectors[13] = self.m42 + (other.m42 - self.m42) * progress
        vectors[14] = self.m43 + (other.m43 - self.m43) * progress
        vectors[15] = self.m44 + (other.m44 - self.m44) * progress
        
        return CATransform3D(m11: vectors[0], m12: vectors[1], m13: vectors[2], m14: vectors[3], m21: vectors[4], m22: vectors[5], m23: vectors[6], m24: vectors[7], m31: vectors[8], m32: vectors[9], m33: vectors[10], m34: vectors[11], m41: vectors[12], m42: vectors[13], m43: vectors[14], m44: vectors[15])
    }
}


private func angle(for origin: CGFloat, itemCount: Int, bounds: CGRect, contentHeight: CGFloat?) -> CGFloat {
    var rotationAngle = rotationAngleAt0(itemCount: itemCount)
    
    var contentOffset = bounds.origin.y
    if contentOffset < 0.0 {
        contentOffset *= 2.0
    }
//    } else if let contentHeight = contentHeight, bounds.maxY > contentHeight {
////        let maxContentOffset = contentHeight - bounds.height
////        let delta = contentOffset - maxContentOffset
////        contentOffset = maxContentOffset + delta / 2.0
//    }
    
    var yOnScreen = origin - contentOffset - sectionInsetTop
    if yOnScreen < 0 {
        yOnScreen = 0
    } else if yOnScreen > bounds.height {
        yOnScreen = bounds.height
    }
    
    let maxRotationVariance = maxRotationAngle - rotationAngleAt0(itemCount: itemCount)
    rotationAngle += (maxRotationVariance / bounds.height) * yOnScreen

    return rotationAngle
}

private func final3dTransform(for origin: CGFloat, size: CGSize, contentHeight: CGFloat?, itemCount: Int, forcedAngle: CGFloat? = nil, additionalAngle: CGFloat? = nil, bounds: CGRect) -> CATransform3D {
    var transform = CATransform3DIdentity
    transform.m34 = perspectiveCorrection
    
    let rotationAngle = forcedAngle ?? angle(for: origin, itemCount: itemCount, bounds: bounds, contentHeight: contentHeight)
    var effectiveRotationAngle = rotationAngle
    if let additionalAngle = additionalAngle {
        effectiveRotationAngle += additionalAngle
    }
    
    let r = size.height / 2.0 + abs(zOffset / sin(rotationAngle))
    
    let zTranslation = r * sin(rotationAngle)
    let yTranslation: CGFloat = r * (1 - cos(rotationAngle))
    
    let zTranslateTransform = CATransform3DTranslate(transform, 0.0, -yTranslation, zTranslation)
    
    let rotateTransform = CATransform3DRotate(zTranslateTransform, effectiveRotationAngle, 1.0, 0.0, 0.0)
    
    return rotateTransform
}

private func interitemSpacing(itemCount: Int, bounds: CGRect) -> CGFloat {
    var interitemSpacing = maxInteritemSpacing
    if itemCount > 0 {
        interitemSpacing = (bounds.height - sectionInsetTop - sectionInsetBottom) / CGFloat(min(itemCount, 5))
    }
    return interitemSpacing
}

private func frameForIndex(index: Int, size: CGSize, itemCount: Int, bounds: CGRect) -> CGRect {
    let spacing = interitemSpacing(itemCount: itemCount, bounds: bounds)
    let y = sectionInsetTop + spacing * CGFloat(index)
    let origin = CGPoint(x: 0, y: y)
    
    return CGRect(origin: origin, size: size)
}

private func rotationAngleAt0(itemCount: Int) -> CGFloat {
    let multiplier: CGFloat = min(CGFloat(itemCount), 5.0) - 1.0
    return -CGFloat.pi / 7.0 - CGFloat.pi / 7.0 * multiplier / 4.0
}

private let shadowImage: UIImage? = {
    return generateImage(CGSize(width: 1.0, height: 640.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor] as CFArray
        
        var locations: [CGFloat] = [0.0, 0.65, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: bounds.height), options: [])
    })
}()

class StackItemContainerNode: ASDisplayNode {
    private let node: ASDisplayNode
    private let shadowNode: ASImageNode
    
    var tapped: (() -> Void)?
    var highlighted: ((Bool) -> Void)?
    
    init(node: ASDisplayNode) {
        self.node = node
        self.shadowNode = ASImageNode()
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.displayWithoutProcessing = true
        self.shadowNode.contentMode = .scaleToFill
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 10.0
        applySmoothRoundedCorners(self.layer)
        
        self.shadowNode.image = shadowImage
        
        self.addSubnode(self.node)
        self.addSubnode(self.shadowNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { point in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let point = point, point.x > 280.0 {
                self?.highlighted?(true)
            } else {
                self?.highlighted?(false)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    func animateIn() {
        self.shadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.tapped?()
                default:
                    break
                }
            }
        default:
            break
        }
    }

    override func layout() {
        super.layout()
        
        self.node.frame = self.bounds
        self.shadowNode.frame = self.bounds
    }
}

public class StackContainerNode: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let scrollNode: ASScrollNode
    private var nodes: [StackItemContainerNode]
    
    private var deleteGestureRecognizer: UIPanGestureRecognizer?
    private var offsetsForDeletingItems: [Int: CGPoint]?
    private var currentDeletingIndexPath: Int?
    private var deletingOffset: CGFloat?
    
    private var animatingIn = false
    
    private var validLayout: CGSize?
    
    override public init() {
        self.scrollNode = ASScrollNode()
        self.nodes = []
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.scrollNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.alwaysBounceVertical = true
        
        let deleteGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanToDelete(gestureRecognizer:)))
        deleteGestureRecognizer.delegate = self
        deleteGestureRecognizer.delaysTouchesBegan = true
        self.scrollNode.view.addGestureRecognizer(deleteGestureRecognizer)
        self.deleteGestureRecognizer = deleteGestureRecognizer
    }
    
    func item(forYPosition y: CGFloat) -> Int? {
        let itemCount = self.nodes.count
        let bounds = self.scrollNode.bounds
        
        let spacing = interitemSpacing(itemCount: itemCount, bounds: bounds)
        return max(0, min(Int(floor((y - sectionInsetTop) / spacing)), itemCount - 1))
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        
        let touch = panGesture.location(in: gestureRecognizer.view)
        let velocity = panGesture.velocity(in: gestureRecognizer.view)
        
        if abs(velocity.x) > abs(velocity.y), let item = self.item(forYPosition: touch.y) {
            return item > 0
        }
        return false
    }
    
    @objc func didPanToDelete(gestureRecognizer: UIPanGestureRecognizer) {
        let scrollView = self.scrollNode.view
        
        switch gestureRecognizer.state {
            case .began:
                let touch = gestureRecognizer.location(in: scrollView)
                guard let item = self.item(forYPosition: touch.y) else { return }
                
                self.currentDeletingIndexPath = item
            case .changed:
                guard let _ = self.currentDeletingIndexPath else { return }
                
                var delta = gestureRecognizer.translation(in: scrollView)
                delta.y = 0
                
                if let offset = self.deletingOffset {
                    self.deletingOffset = offset + delta.x
                } else {
                    self.deletingOffset = delta.x
                }
                
                gestureRecognizer.setTranslation(.zero, in: scrollView)
            
                self.updateLayout()
            case .ended:
                if let _ = self.currentDeletingIndexPath {
                    if let offset = self.deletingOffset {
                        if offset < -self.frame.width / 2.0 {
                            self.deletingOffset = -self.frame.width
                        } else {
                            self.deletingOffset = nil
                            self.currentDeletingIndexPath = nil
                        }
                    }
                }
            
                UIView.animate(withDuration: 0.3) {
                    self.updateLayout()
                }
            case .cancelled, .failed:
                self.currentDeletingIndexPath = nil
                self.deletingOffset = nil
            default:
                break
        }
      }
    
    func setup() {
        let images: [UIImage] = [UIImage(bundleImageName: "Settings/test1")!, UIImage(bundleImageName: "Settings/test5")!, UIImage(bundleImageName: "Settings/test4")!, UIImage(bundleImageName: "Settings/test3")!, UIImage(bundleImageName: "Settings/test2")!]
        for i in 0 ..< 5 {
            let node = ASImageNode()
            node.image = images[i]
            
            let containerNode = StackItemContainerNode(node: node)
            containerNode.tapped = { [weak self] in
                self?.animateIn(index: i)
            }
            containerNode.highlighted = { [weak self] highlighted in
                self?.highlight(index: i, value: highlighted)
            }
            self.nodes.append(containerNode)
        }
        
        var index: Int = 0
        let bounds = self.scrollNode.view.bounds
        let itemCount = self.nodes.count
        
        for node in self.nodes {
            self.scrollNode.addSubnode(node)
            
            let size = CGSize(width: self.frame.width, height: self.frame.height)
            let frame = frameForIndex(index: index, size: size, itemCount: itemCount, bounds: bounds)
            node.frame = frame
            let transform = final3dTransform(for: frame.minY, size: frame.size, contentHeight: nil, itemCount: itemCount, bounds: bounds)
            node.transform = transform
            index += 1
        }
        
        if let lastFrame = self.nodes.last?.frame {
            self.scrollNode.view.contentSize = CGSize(width: self.frame.width, height: lastFrame.minY)
        }
    }
    
    public func animateIn(index: Int) {
        let node = self.nodes[index]
        
        self.animatingIn = true
        self.scrollNode.view.isUserInteractionEnabled = false
        node.animateIn()
        UIView.animate(withDuration: 0.3) {
            node.transform = CATransform3DIdentity
            node.position = CGPoint(x: self.scrollNode.frame.width / 2.0, y: self.scrollNode.frame.height / 2.0)
        }
        
        for i in 0 ..< index {
            let node = self.nodes[i]
            node.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -550.0), duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, mediaTimingFunction: nil, removeOnCompletion: false, additive: true, force: false, completion: nil)
        }
        
        for i in (index + 1) ..< self.nodes.count {
            let node = self.nodes[i]
            node.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 550.0), duration: 0.3, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, mediaTimingFunction: nil, removeOnCompletion: false, additive: true, force: false, completion: nil)
        }
    }
    
    public func highlight(index: Int, value: Bool) {
        let node = self.nodes[index]
        
        let bounds = self.scrollNode.view.bounds
        let contentHeight = self.scrollNode.view.contentSize.height
        let itemCount = self.nodes.count
        
        UIView.animate(withDuration: 0.4) {
            let transform = final3dTransform(for: node.frame.minY, size: node.frame.size, contentHeight: contentHeight, itemCount: itemCount, additionalAngle: value ? 0.04 : nil, bounds: bounds)
            node.transform = transform
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.animatingIn else {
            return
        }
        self.updateLayout()
    }
    
    func updateLayout() {
        let bounds = self.scrollNode.view.bounds
        let contentHeight = self.scrollNode.view.contentSize.height
        let itemCount = self.nodes.count
        
        var index: Int = 0
        for node in self.nodes {
            let initialTransform = final3dTransform(for: node.frame.minY, size: node.frame.size, contentHeight: contentHeight, itemCount: itemCount, bounds: bounds)
            let initialFrame = frameForIndex(index: index, size: node.frame.size, itemCount: itemCount, bounds: bounds)
            
            var targetTransform: CATransform3D?
            var targetPosition: CGPoint?
            
            var finalPosition = initialFrame.center
            
            if let deletingIndex = self.currentDeletingIndexPath, let offset = self.deletingOffset {
                if deletingIndex == index {
                    finalPosition = CGPoint(x: self.frame.width / 2.0 + min(offset, 0.0), y: node.position.y)
                } else if index < deletingIndex {
                    let frame = frameForIndex(index: index, size: node.frame.size, itemCount: itemCount - 1, bounds: bounds)
                    targetPosition = frame.center
                    
                    let spacing = interitemSpacing(itemCount: itemCount - 1, bounds: bounds)
                    targetTransform = final3dTransform(for: frame.minY, size: node.frame.size, contentHeight: contentHeight - node.frame.height - spacing, itemCount: itemCount - 1, bounds: bounds)
                } else {
                    let frame = frameForIndex(index: index - 1, size: node.frame.size, itemCount: itemCount - 1, bounds: bounds)
                    targetPosition = frame.center
                    
                    let spacing = interitemSpacing(itemCount: itemCount - 1, bounds: bounds)
                    targetTransform = final3dTransform(for: frame.minY, size: node.frame.size, contentHeight: contentHeight - node.frame.height - spacing, itemCount: itemCount - 1, bounds: bounds)
                }
            } else {
                node.position = initialFrame.center
            }
            
            var finalTransform = initialTransform
            if let targetTransform = targetTransform, let offset = self.deletingOffset {
                let progress = min(1.0, abs(offset / (self.frame.width)))
                finalTransform = initialTransform.interpolate(other: targetTransform, progress: progress)
            }
            
            if let targetPosition = targetPosition, let offset = self.deletingOffset {
                let progress = min(1.0, abs(offset / (self.frame.width)))
                finalPosition = CGPoint(x: finalPosition.x + (targetPosition.x - finalPosition.x) * progress, y: finalPosition.y + (targetPosition.y - finalPosition.y) * progress)
            }
            
            node.transform = finalTransform
            node.position = finalPosition
            
            index += 1
        }
    }
    
    public func update(size: CGSize) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = size
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        
        if !hadValidLayout {
            self.setup()
        }
    }
}
