import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public let displayLinkDispatcher = DisplayLinkDispatcher()
private let dispatcher = displayLinkDispatcher

public enum ImageCorner: Equatable {
    case Corner(CGFloat)
    case Tail(CGFloat, UIImage)
    
    public var extendedInsets: CGSize {
        switch self {
            case .Tail:
                return CGSize(width: 4.0, height: 0.0)
            default:
                return CGSize()
        }
    }
    
    public var withoutTail: ImageCorner {
        switch self {
            case .Corner:
                return self
            case let .Tail(radius, _):
                return .Corner(radius)
        }
    }
    
    public var radius: CGFloat {
        switch self {
            case let .Corner(radius):
                return radius
            case let .Tail(radius, _):
                return radius
        }
    }
}

public func ==(lhs: ImageCorner, rhs: ImageCorner) -> Bool {
    switch lhs {
        case let .Corner(lhsRadius):
            switch rhs {
                case let .Corner(rhsRadius) where abs(lhsRadius - rhsRadius) < CGFloat.ulpOfOne:
                    return true
                default:
                    return false
            }
        case let .Tail(lhsRadius, lhsImage):
            if case let .Tail(rhsRadius, rhsImage) = rhs, lhsRadius.isEqual(to: rhsRadius), lhsImage === rhsImage {
                return true
            } else {
                return false
            }
    }
}

public func isRoundEqualCorners(_ corners: ImageCorners) -> Bool {
    if case .Corner = corners.topLeft, case .Corner = corners.topRight, case .Corner = corners.bottomLeft, case .Corner = corners.bottomRight {
        if corners.topLeft.radius == corners.topRight.radius && corners.topRight.radius == corners.bottomLeft.radius && corners.bottomLeft.radius == corners.bottomRight.radius {
            return true
        }
    }
    return false
}

public struct ImageCorners: Equatable {
    public let topLeft: ImageCorner
    public let topRight: ImageCorner
    public let bottomLeft: ImageCorner
    public let bottomRight: ImageCorner
    
    public var isEmpty: Bool {
        if self.topLeft != .Corner(0.0) {
            return false
        }
        if self.topRight != .Corner(0.0) {
            return false
        }
        if self.bottomLeft != .Corner(0.0) {
            return false
        }
        if self.bottomRight != .Corner(0.0) {
            return false
        }
        return true
    }
    
    public init(radius: CGFloat) {
        self.topLeft = .Corner(radius)
        self.topRight = .Corner(radius)
        self.bottomLeft = .Corner(radius)
        self.bottomRight = .Corner(radius)
    }
    
    public init(topLeft: ImageCorner, topRight: ImageCorner, bottomLeft: ImageCorner, bottomRight: ImageCorner) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
    
    public init() {
        self.init(topLeft: .Corner(0.0), topRight: .Corner(0.0), bottomLeft: .Corner(0.0), bottomRight: .Corner(0.0))
    }
    
    public var extendedEdges: UIEdgeInsets {
        let left = self.bottomLeft.extendedInsets.width
        let right = self.bottomRight.extendedInsets.width
        
        return UIEdgeInsets(top: 0.0, left: left, bottom: 0.0, right: right)
    }
    
    public func withRemovedTails() -> ImageCorners {
        return ImageCorners(topLeft: self.topLeft.withoutTail, topRight: self.topRight.withoutTail, bottomLeft: self.bottomLeft.withoutTail, bottomRight: self.bottomRight.withoutTail)
    }
}

public func ==(lhs: ImageCorners, rhs: ImageCorners) -> Bool {
    return lhs.topLeft == rhs.topLeft && lhs.topRight == rhs.topRight && lhs.bottomLeft == rhs.bottomLeft && lhs.bottomRight == rhs.bottomRight
}

public class ImageNode: ASDisplayNode {
    private var disposable = MetaDisposable()
    private let hasImage: ValuePromise<Bool>?
    private var first = true
    private let enableEmpty: Bool
    public var enableAnimatedTransition: Bool
    public var animateFirstTransition = true
    
    private let _contentReady = Promise<Bool>()
    private var didSetReady: Bool = false
    public var contentReady: Signal<Bool, NoError> {
        return self._contentReady.get()
    }
    
    public var ready: Signal<Bool, NoError> {
        if let hasImage = self.hasImage {
            return hasImage.get()
        } else {
            return .single(true)
        }
    }
    
    public init(enableHasImage: Bool = false, enableEmpty: Bool = false, enableAnimatedTransition: Bool = false) {
        if enableHasImage {
            self.hasImage = ValuePromise(false, ignoreRepeated: true)
        } else {
            self.hasImage = nil
        }
        self.enableEmpty = enableEmpty
        self.enableAnimatedTransition = enableAnimatedTransition
        super.init()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func setSignal(_ signal: Signal<UIImage?, NoError>) {
        var reportedHasImage = false
        self.disposable.set((signal |> deliverOnMainQueue).start(next: {[weak self] next in
            dispatcher.dispatch {
                if let strongSelf = self {
                    var animate = strongSelf.enableAnimatedTransition
                    if strongSelf.first && next != nil {
                        strongSelf.first = false
                        animate = false
                        if strongSelf.isNodeLoaded && strongSelf.animateFirstTransition {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                        }
                    }
                    if let image = next?.cgImage {
                        if animate, let previousContents = strongSelf.contents {
                            strongSelf.contents = image
                            let tempLayer = CALayer()
                            tempLayer.contents = previousContents
                            tempLayer.frame = strongSelf.layer.bounds
                            strongSelf.layer.addSublayer(tempLayer)
                            tempLayer.opacity = 0.0
                            tempLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: true, completion: { [weak tempLayer] _ in
                                tempLayer?.removeFromSuperlayer()
                            })

                            //strongSelf.layer.animate(from: previousContents as! CGImage, to: image, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        } else {
                            strongSelf.contents = image
                        }
                    } else if strongSelf.enableEmpty {
                        strongSelf.contents = nil
                    }
                    if !reportedHasImage {
                        if let hasImage = strongSelf.hasImage {
                            reportedHasImage = true
                            hasImage.set(true)
                        }
                    }
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._contentReady.set(.single(true))
                    }
                }
            }
        }))
    }
    
    public override func clearContents() {
        super.clearContents()
        
        self.contents = nil
        self.disposable.set(nil)
    }
    
    public var image: UIImage? {
        if let contents = self.contents {
            return UIImage(cgImage: contents as! CGImage)
        } else {
            return nil
        }
    }
}

