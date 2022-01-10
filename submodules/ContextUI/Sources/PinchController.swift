import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit

final class PinchSourceGesture: UIPinchGestureRecognizer {
    private final class Target {
        var updated: (() -> Void)?

        @objc func onGesture(_ gesture: UIPinchGestureRecognizer) {
            self.updated?()
        }
    }

    private let target: Target

    private(set) var currentTransform: (CGFloat, CGPoint, CGPoint)?

    var began: (() -> Void)?
    var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?
    var ended: (() -> Void)?

    private var initialLocation: CGPoint?
    private var pinchLocation = CGPoint()
    private var currentOffset = CGPoint()

    private var currentNumberOfTouches = 0

    init() {
        self.target = Target()

        super.init(target: self.target, action: #selector(self.target.onGesture(_:)))

        self.target.updated = { [weak self] in
            self?.gestureUpdated()
        }
    }

    override func reset() {
        super.reset()

        self.currentNumberOfTouches = 0
        self.initialLocation = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        //self.currentTouches.formUnion(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
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

public final class PinchSourceContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    public let contentNode: ASDisplayNode
    public var contentRect: CGRect = CGRect()
    private(set) var naturalContentFrame: CGRect?

    fileprivate let gesture: PinchSourceGesture
    fileprivate var panGesture: UIPanGestureRecognizer?

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
    var deactivate: (() -> Void)?
    public var deactivated: (() -> Void)?
    var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?

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

    @objc private func panGestureRecognized(_ recognizer: UIPanGestureRecognizer) {
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

    func restoreToNaturalSize() {
        guard let naturalContentFrame = self.naturalContentFrame else {
            return
        }
        self.contentNode.frame = naturalContentFrame
    }
}

private final class PinchControllerNode: ViewControllerTracingNode {
    private weak var controller: PinchController?

    private var initialSourceFrame: CGRect?

    private let clippingNode: ASDisplayNode
    private let scrollingContainer: ASDisplayNode

    private let sourceNode: PinchSourceContainerNode
    private let getContentAreaInScreenSpace: () -> CGRect

    private let dimNode: ASDisplayNode

    private var validLayout: ContainerViewLayout?
    private var isAnimatingOut: Bool = false

    private var hapticFeedback: HapticFeedback?

    init(controller: PinchController, sourceNode: PinchSourceContainerNode, getContentAreaInScreenSpace: @escaping () -> CGRect) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace

        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.dimNode.alpha = 0.0

        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true

        self.scrollingContainer = ASDisplayNode()

        super.init()

        self.addSubnode(self.dimNode)
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.scrollingContainer)

        self.sourceNode.deactivate = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controller?.dismiss()
        }

        self.sourceNode.updated = { [weak self] scale, pinchLocation, offset in
            guard let strongSelf = self, let initialSourceFrame = strongSelf.initialSourceFrame else {
                return
            }
            strongSelf.dimNode.alpha = max(0.0, min(1.0, scale - 1.0))

            let pinchOffset = CGPoint(
                x: pinchLocation.x - initialSourceFrame.width / 2.0,
                y: pinchLocation.y - initialSourceFrame.height / 2.0
            )

            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, offset.x - pinchOffset.x * (scale - 1.0), offset.y - pinchOffset.y * (scale - 1.0), 0.0)
            transform = CATransform3DScale(transform, scale, scale, 0.0)

            strongSelf.sourceNode.contentNode.transform = transform
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
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
    }

    func animateIn() {
        let convertedFrame = convertFrame(self.sourceNode.bounds, from: self.sourceNode.view, to: self.view)
        self.sourceNode.contentNode.frame = convertedFrame
        self.initialSourceFrame = convertedFrame
        self.scrollingContainer.addSubnode(self.sourceNode.contentNode)

        var updatedContentAreaInScreenSpace = self.getContentAreaInScreenSpace()
        updatedContentAreaInScreenSpace.origin.x = 0.0
        updatedContentAreaInScreenSpace.size.width = self.bounds.width

        self.clippingNode.layer.animateFrame(from: updatedContentAreaInScreenSpace, to: self.clippingNode.frame, duration: 0.18 * 1.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        self.clippingNode.layer.animateBoundsOriginYAdditive(from: updatedContentAreaInScreenSpace.minY, to: 0.0, duration: 0.18 * 1.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
    }

    func animateOut(completion: @escaping () -> Void) {
        self.isAnimatingOut = true

        let performCompletion: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.isAnimatingOut = false

            strongSelf.sourceNode.restoreToNaturalSize()
            strongSelf.sourceNode.addSubnode(strongSelf.sourceNode.contentNode)

            strongSelf.sourceNode.animatedOut?()

            completion()
        }

        let convertedFrame = convertFrame(self.sourceNode.bounds, from: self.sourceNode.view, to: self.view)
        self.sourceNode.contentNode.frame = convertedFrame
        self.initialSourceFrame = convertedFrame

        if let (scale, pinchLocation, offset) = self.sourceNode.gesture.currentTransform, let initialSourceFrame = self.initialSourceFrame {
            let duration = 0.3
            let transitionCurve: ContainedViewLayoutTransitionCurve = .easeInOut

            var updatedContentAreaInScreenSpace = self.getContentAreaInScreenSpace()
            updatedContentAreaInScreenSpace.origin.x = 0.0
            updatedContentAreaInScreenSpace.size.width = self.bounds.width

            self.clippingNode.layer.animateFrame(from: self.clippingNode.frame, to: updatedContentAreaInScreenSpace, duration: duration * 1.0, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: duration * 1.0, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)

            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: .spring)
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.prepareImpact(.light)
            self.hapticFeedback?.impact(.light)

            self.sourceNode.scaleUpdated?(1.0, transition)

            let pinchOffset = CGPoint(
                x: pinchLocation.x - initialSourceFrame.width / 2.0,
                y: pinchLocation.y - initialSourceFrame.height / 2.0
            )

            var transform = CATransform3DIdentity
            transform = CATransform3DScale(transform, scale, scale, 0.0)

            self.sourceNode.contentNode.transform = CATransform3DIdentity
            self.sourceNode.contentNode.position = CGPoint(x: initialSourceFrame.midX, y: initialSourceFrame.midY)
            self.sourceNode.contentNode.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration * 1.2, damping: 110.0)
            self.sourceNode.contentNode.layer.animatePosition(from: CGPoint(x: offset.x - pinchOffset.x * (scale - 1.0), y: offset.y - pinchOffset.y * (scale - 1.0)), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true, force: true, completion: { _ in
                performCompletion()
            })

            let dimNodeTransition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: transitionCurve)
            dimNodeTransition.updateAlpha(node: self.dimNode, alpha: 0.0)
        } else {
            performCompletion()
        }
    }

    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if self.isAnimatingOut {
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset.y)
            transition.animateOffsetAdditive(node: self.scrollingContainer, offset: -offset.y)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

public final class PinchController: ViewController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let sourceNode: PinchSourceContainerNode
    private let getContentAreaInScreenSpace: () -> CGRect

    private var wasDismissed = false

    private var controllerNode: PinchControllerNode {
        return self.displayNode as! PinchControllerNode
    }

    public init(sourceNode: PinchSourceContainerNode, getContentAreaInScreenSpace: @escaping () -> CGRect) {
        self.sourceNode = sourceNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace

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
        self.displayNode = PinchControllerNode(controller: self, sourceNode: self.sourceNode, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)

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

    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.controllerNode.addRelativeContentOffset(offset, transition: transition)
    }
}
