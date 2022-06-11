import Foundation
import UIKit
import SceneKit
import Display
import AppBundle
import SwiftSignalKit

final class SwirlStarsView: UIView, PhoneDemoDecorationView {
    private let sceneView: SCNView
    
    private var particles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = getAppBundle().url(forResource: "swirl", withExtension: "scn") {
            self.sceneView.scene = try? SCNScene(url: url, options: nil)
        }
        self.sceneView.isUserInteractionEnabled = false
        self.sceneView.preferredFramesPerSecond = 60
        
        super.init(frame: frame)
        
        self.alpha = 0.0
        
        self.addSubview(self.sceneView)
        
        self.particles = self.sceneView.scene?.rootNode.childNode(withName: "particles", recursively: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.particles = nil
    }
    
    func setVisible(_ visible: Bool) {
        if visible, let particles = self.particles, particles.parent == nil {
            self.sceneView.scene?.rootNode.addChildNode(particles)
        }
        self.setupAnimations()
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
        transition.updateAlpha(layer: self.layer, alpha: visible ? 0.6 : 0.0, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.particles?.parent != nil {
                strongSelf.particles?.removeFromParentNode()
                
                if let node = strongSelf.sceneView.scene?.rootNode.childNode(withName: "star", recursively: false) {
                    node.removeAllAnimations()
                }
            }
        })
    }
    
    func setupAnimations() {
        guard let node = self.sceneView.scene?.rootNode.childNode(withName: "star", recursively: false), node.animationKeys.isEmpty else {
            return
        }
        
        let initial = node.eulerAngles
        let target = SCNVector3(x: node.eulerAngles.x + .pi * 2.0, y: node.eulerAngles.y, z: node.eulerAngles.z)
        
        let animation = CABasicAnimation(keyPath: "eulerAngles")
        animation.fromValue = NSValue(scnVector3: initial)
        animation.toValue = NSValue(scnVector3: target)
        animation.duration = 1.5
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.repeatCount = .infinity
        node.addAnimation(animation, forKey: "rotation")
        
        self.setupMovementAnimation()
    }
    
    func setupMovementAnimation() {
        guard let node = self.sceneView.scene?.rootNode.childNode(withName: "star", recursively: false) else {
            return
        }
        
        node.position = SCNVector3(3.5, 0.0, -2.0)
        let firstPath = UIBezierPath()
        firstPath.move(to: CGPoint(x: 3.5, y: -2.0))
        firstPath.addLine(to: CGPoint(x: -15.5, y: 15.5))
        
        let firstAction = SCNAction.moveAlong(path: firstPath, duration: 2.0)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0
        node.runAction(firstAction)
        SCNTransaction.completionBlock = { [weak self, weak node] in
            Queue.mainQueue().after(2.2, {
                node?.position = SCNVector3(0.0, 0.0, -3.0)
                let secondPath = UIBezierPath()
                secondPath.move(to: CGPoint(x: 0.0, y: -3.0))
                secondPath.addLine(to: CGPoint(x: 15.5, y: 20.0))
                
                let secondAction = SCNAction.moveAlong(path: secondPath, duration: 2.0)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                node?.runAction(secondAction)
                SCNTransaction.completionBlock = { [weak self] in
                    Queue.mainQueue().after(2.2, {
                        self?.setupMovementAnimation()
                    })
                }
                SCNTransaction.commit()
            })
        }
        SCNTransaction.commit()
    }
        
    func resetAnimation() {
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
}

extension UIBezierPath {
    var elements: [PathElement] {
        var pathElements = [PathElement]()
        withUnsafeMutablePointer(to: &pathElements) { elementsPointer in
            cgPath.apply(info: elementsPointer) { (userInfo, nextElementPointer) in
                let nextElement = PathElement(element: nextElementPointer.pointee)
                let elementsPointer = userInfo!.assumingMemoryBound(to: [PathElement].self)
                elementsPointer.pointee.append(nextElement)
            }
        }
        return pathElements
    }
}

enum PathElement {
    case moveToPoint(CGPoint)
    case addLineToPoint(CGPoint)
    case addQuadCurveToPoint(CGPoint, CGPoint)
    case addCurveToPoint(CGPoint, CGPoint, CGPoint)
    case closeSubpath

    init(element: CGPathElement) {
        switch element.type {
            case .moveToPoint:
                self = .moveToPoint(element.points[0])
            case .addLineToPoint:
                self = .addLineToPoint(element.points[0])
            case .addQuadCurveToPoint:
                self = .addQuadCurveToPoint(element.points[0], element.points[1])
            case .addCurveToPoint:
                self = .addCurveToPoint(element.points[0], element.points[1], element.points[2])
            case .closeSubpath:
                self = .closeSubpath
            @unknown default:
                self = .closeSubpath
        }
    }
}

public extension SCNAction {
    class func moveAlong(path: UIBezierPath, duration animationDuration: Double) -> SCNAction {
        let points = path.elements
        var actions = [SCNAction]()

        for point in points {
            switch point {
            case .moveToPoint(let a):
                let moveAction = SCNAction.move(to: SCNVector3(a.x, 0,  a.y), duration: animationDuration)
                actions.append(moveAction)
                break

            case .addCurveToPoint(let a, let b, let c):
                let moveAction1 = SCNAction.move(to: SCNVector3(a.x, 0, a.y), duration: animationDuration)
                let moveAction2 = SCNAction.move(to: SCNVector3(b.x, 0, b.y), duration: animationDuration)
                let moveAction3 = SCNAction.move(to: SCNVector3(c.x, 0, c.y), duration: animationDuration)
                actions.append(moveAction1)
                actions.append(moveAction2)
                actions.append(moveAction3)
                break

            case .addLineToPoint(let a):
                let moveAction = SCNAction.move(to: SCNVector3(a.x, 0, a.y), duration: animationDuration)
                actions.append(moveAction)
                break

            case .addQuadCurveToPoint(let a, let b):
                let moveAction1 = SCNAction.move(to: SCNVector3(a.x, 0, a.y), duration: animationDuration)
                let moveAction2 = SCNAction.move(to: SCNVector3(b.x, 0, b.y), duration: animationDuration)
                actions.append(moveAction1)
                actions.append(moveAction2)
                break

            default:
                let moveAction = SCNAction.move(to: SCNVector3(0, 0, 0), duration: animationDuration)
                actions.append(moveAction)
                break
            }
        }
        return SCNAction.sequence(actions)
    }
}
