import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import ReactionSelectionNode
import TelegramCore
import SyncCore
import SwiftSignalKit

private func convertFrame(_ frame: CGRect, from fromView: UIView, to toView: UIView) -> CGRect {
    let sourceWindowFrame = fromView.convert(frame, to: nil)
    var targetWindowFrame = toView.convert(sourceWindowFrame, from: nil)

    if let fromWindow = fromView.window, let toWindow = toView.window {
        targetWindowFrame.origin.x += toWindow.bounds.width - fromWindow.bounds.width
    }
    return targetWindowFrame
}

final class PinchSourceGesture: UIPinchGestureRecognizer {
    private final class Target {
        var updated: (() -> Void)?

        @objc func onGesture(_ gesture: UIPinchGestureRecognizer) {
            self.updated?()
        }
    }

    private let target: Target

    private(set) var currentTransform: (CGFloat, CGPoint)?

    var began: (() -> Void)?
    var updated: ((CGFloat, CGPoint) -> Void)?
    var ended: (() -> Void)?

    private var lastLocation: CGPoint?
    private var currentOffset = CGPoint()

    init() {
        self.target = Target()

        super.init(target: self.target, action: #selector(self.target.onGesture(_:)))

        self.target.updated = { [weak self] in
            self?.gestureUpdated()
        }
    }

    override func reset() {
        super.reset()

        self.lastLocation = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        if touches.count >= 2 {
            var locationSum = CGPoint()
            for touch in touches {
                let point = touch.location(in: self.view)
                locationSum.x += point.x
                locationSum.y += point.y
            }
            locationSum.x /= CGFloat(touches.count)
            locationSum.y /= CGFloat(touches.count)
            if let lastLocation = self.lastLocation {
                self.currentOffset = CGPoint(x: locationSum.x - lastLocation.x, y: locationSum.y - lastLocation.y)
            } else {
                self.lastLocation = locationSum
                self.currentOffset = CGPoint()
            }
            if let (scale, _) = self.currentTransform {
                self.currentTransform = (scale, self.currentOffset)
                self.updated?(scale, self.currentOffset)
            }
        }
    }

    private func gestureUpdated() {
        switch self.state {
        case .began:
            self.lastLocation = nil
            self.currentOffset = CGPoint()
            self.currentTransform = nil
            self.began?()
        case .changed:
            let scale = max(1.0, self.scale)
            self.currentTransform = (scale, self.currentOffset)
            self.updated?(scale, self.currentOffset)
        case .ended, .cancelled:
            self.ended?()
        default:
            break
        }
    }
}

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

public final class PinchSourceContainerNode: ASDisplayNode {
    public let contentNode: ASDisplayNode
    public var contentRect: CGRect = CGRect()
    private(set) var naturalContentFrame: CGRect?

    fileprivate let gesture: PinchSourceGesture

    public var isPinchGestureEnabled: Bool = false {
        didSet {
            if self.isPinchGestureEnabled != oldValue {
                self.gesture.isEnabled = self.isPinchGestureEnabled
            }
        }
    }

    private var isActive: Bool = false

    public var activate: ((PinchSourceContainerNode) -> Void)?
    public var scaleUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    var deactivate: (() -> Void)?
    var updated: ((CGFloat, CGPoint) -> Void)?

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
        }

        self.gesture.updated = { [weak self] scale, offset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updated?(scale, offset)
            strongSelf.scaleUpdated?(scale, .immediate)
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

    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        self.naturalContentFrame = contentFrame
        if !self.isActive {
            transition.updateFrame(node: self.contentNode, frame: contentFrame)
        }
    }

    func restoreToNaturalSize() {
        guard let naturalContentFrame = self.naturalContentFrame else {
            return
        }
        self.contentNode.frame = naturalContentFrame
    }
}

private final class PinchControllerNode: ViewControllerTracingNode {
    private weak var controller: PinchController?
    private let sourceNode: PinchSourceContainerNode

    private let dimNode: ASDisplayNode

    private var validLayout: ContainerViewLayout?
    private var isAnimatingOut: Bool = false

    private var hapticFeedback: HapticFeedback?

    init(controller: PinchController, sourceNode: PinchSourceContainerNode) {
        self.controller = controller
        self.sourceNode = sourceNode

        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.dimNode.alpha = 0.0

        super.init()

        self.addSubnode(self.dimNode)

        self.sourceNode.deactivate = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controller?.dismiss()
        }

        self.sourceNode.updated = { [weak self] scale, offset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dimNode.alpha = max(0.0, min(1.0, scale - 1.0))
            strongSelf.sourceNode.contentNode.transform = CATransform3DTranslate(CATransform3DMakeScale(scale, scale, 1.0), offset.x / scale, offset.y / scale, 0.0)
        }
    }

    deinit {
    }

    override func didLoad() {
        super.didLoad()
    }

    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, previousActionsContainerNode: ContextActionsContainerNode?) {
        if self.isAnimatingOut {
            return
        }

        self.validLayout = layout

        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
    }

    func animateIn() {
        let convertedFrame = convertFrame(self.sourceNode.contentNode.frame, from: self.sourceNode.view, to: self.view)
        self.sourceNode.contentNode.frame = convertedFrame
        self.addSubnode(self.sourceNode.contentNode)
    }

    func animateOut(completion: @escaping () -> Void) {
        let performCompletion: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.sourceNode.restoreToNaturalSize()
            strongSelf.sourceNode.addSubnode(strongSelf.sourceNode.contentNode)

            completion()
        }

        if let (scale, offset) = self.sourceNode.gesture.currentTransform {
            let duration = 0.4
            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: .spring)
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.prepareImpact(.light)
            Queue.mainQueue().after(0.2, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.hapticFeedback?.impact(.light)
            })

            self.sourceNode.scaleUpdated?(1.0, transition)

            self.sourceNode.contentNode.transform = CATransform3DIdentity
            self.sourceNode.contentNode.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration * 1.2, damping: 110.0)
            self.sourceNode.contentNode.layer.animatePosition(from: CGPoint(x: offset.x, y: offset.y), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true, force: true, completion: { _ in
                performCompletion()
            })

            let dimNodeTransition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
            dimNodeTransition.updateAlpha(node: self.dimNode, alpha: 0.0)
        } else {
            performCompletion()
        }
    }
}

public final class PinchController: ViewController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let sourceNode: PinchSourceContainerNode

    private var wasDismissed = false

    private var controllerNode: PinchControllerNode {
        return self.displayNode as! PinchControllerNode
    }

    public init(sourceNode: PinchSourceContainerNode) {
        self.sourceNode = sourceNode

        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .Ignore

        self.lockOrientation = true
        self.blocksBackgroundWhenInOverlay = true
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    override public func loadDisplayNode() {
        self.displayNode = PinchControllerNode(controller: self, sourceNode: self.sourceNode)

        self.displayNodeDidLoad()

        self._ready.set(.single(true))
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.updateLayout(layout: layout, transition: transition, previousActionsContainerNode: nil)
    }

    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)

        self.controllerNode.animateIn()
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.wasDismissed {
            self.wasDismissed = true
            self.controllerNode.animateOut(completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
        }
    }
}
