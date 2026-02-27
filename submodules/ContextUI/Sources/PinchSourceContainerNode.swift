import Foundation
import UIKit
import AsyncDisplayKit
import Display

private func cancelContextGestures(node: ASDisplayNode) {
    if let node = node as? ContextControllerSourceNode {
        node.cancelGesture()
    }

    if let supernode = node.supernode {
        cancelContextGestures(node: supernode)
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
            if let recognizer = recognizer as? InteractiveTransitionGestureRecognizer {
                recognizer.cancel()
            } else if let recognizer = recognizer as? WindowPanRecognizer {
                recognizer.cancel()
            }
        }
    }

    if let superview = view.superview {
        cancelContextGestures(view: superview)
    }
}

public final class PinchSourceGesture: UIPinchGestureRecognizer {
    private final class Target {
        var updated: (() -> Void)?

        @objc func onGesture(_ gesture: UIPinchGestureRecognizer) {
            self.updated?()
        }
    }

    private let target: Target

    public private(set) var currentTransform: (CGFloat, CGPoint, CGPoint)?

    public var began: (() -> Void)?
    public var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?
    public var ended: (() -> Void)?

    private var initialLocation: CGPoint?
    private var pinchLocation = CGPoint()
    private var currentOffset = CGPoint()

    private var currentNumberOfTouches = 0

    public init() {
        self.target = Target()

        super.init(target: self.target, action: #selector(self.target.onGesture(_:)))

        self.target.updated = { [weak self] in
            self?.gestureUpdated()
        }
    }

    override public func reset() {
        super.reset()

        self.currentNumberOfTouches = 0
        self.initialLocation = nil
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        //self.currentTouches.formUnion(touches)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
    }

    private func gestureUpdated() {
        switch self.state {
        case .began:
            self.currentOffset = CGPoint()

            let pinchLocation = self.location(in: self.view)
            self.pinchLocation = pinchLocation
            self.initialLocation = pinchLocation
            let scale = max(1.0, self.scale)
            self.currentTransform = (scale, self.pinchLocation, self.currentOffset)

            self.currentNumberOfTouches = self.numberOfTouches

            self.began?()
        case .changed:
            let locationSum = self.location(in: self.view)

            if self.numberOfTouches < 2 && self.currentNumberOfTouches >= 2 {
                self.initialLocation = CGPoint(x: locationSum.x - self.currentOffset.x, y: locationSum.y - self.currentOffset.y)
            }
            self.currentNumberOfTouches = self.numberOfTouches

            if let initialLocation = self.initialLocation {
                self.currentOffset = CGPoint(x: locationSum.x - initialLocation.x, y: locationSum.y - initialLocation.y)
            }
            if let (scale, pinchLocation, _) = self.currentTransform {
                self.currentTransform = (scale, pinchLocation, self.currentOffset)
                self.updated?(scale, pinchLocation, self.currentOffset)
            }

            let scale = max(1.0, self.scale)
            self.currentTransform = (scale, self.pinchLocation, self.currentOffset)
            self.updated?(scale, self.pinchLocation, self.currentOffset)
        case .ended, .cancelled:
            self.ended?()
        default:
            break
        }
    }
}


public final class PinchSourceContainerNode: ASDisplayNode, ASGestureRecognizerDelegate {
    public let contentNode: ASDisplayNode
    public var contentRect: CGRect = CGRect()
    private(set) var naturalContentFrame: CGRect?

    public let gesture: PinchSourceGesture

    public var isPinchGestureEnabled: Bool = true {
        didSet {
            if self.isPinchGestureEnabled != oldValue {
                self.gesture.isEnabled = self.isPinchGestureEnabled
            }
        }
    }

    public var maxPinchScale: CGFloat = 10.0

    private var isActive: Bool = false

    public var activate: ((PinchSourceContainerNode) -> Void)?
    public var scaleUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    public var animatedOut: (() -> Void)?
    public var deactivate: (() -> Void)?
    public var deactivated: (() -> Void)?
    public var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?

    override public init() {
        self.gesture = PinchSourceGesture()
        self.contentNode = ASDisplayNode()

        super.init()

        self.addSubnode(self.contentNode)

        self.gesture.began = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            cancelContextGestures(node: strongSelf)
            cancelContextGestures(view: strongSelf.view)
            strongSelf.isActive = true

            strongSelf.activate?(strongSelf)
        }

        self.gesture.ended = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.isActive = false
            strongSelf.deactivate?()
            strongSelf.deactivated?()
        }

        self.gesture.updated = { [weak self] scale, pinchLocation, offset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updated?(min(scale, strongSelf.maxPinchScale), pinchLocation, offset)
            strongSelf.scaleUpdated?(min(scale, strongSelf.maxPinchScale), .immediate)
        }
    }

    override public func didLoad() {
        super.didLoad()

        self.view.addGestureRecognizer(self.gesture)
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.isActive
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        self.naturalContentFrame = contentFrame
        if !self.isActive {
            transition.updateFrame(node: self.contentNode, frame: contentFrame)
        }
    }

    public func restoreToNaturalSize() {
        guard let naturalContentFrame = self.naturalContentFrame else {
            return
        }
        self.contentNode.frame = naturalContentFrame
    }
}