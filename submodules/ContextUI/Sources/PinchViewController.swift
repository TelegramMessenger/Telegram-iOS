import AsyncDisplayKit
import Foundation
import UIKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit

private func cancelContextGestures(sourceView: UIView) {
    if let view = sourceView as? ContextControllerSourceView {
        view.cancelGesture()
    }

    if let superview = sourceView.superview {
        cancelContextGestures(view: superview)
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

public final class PinchSourceContainerView: UIView, UIGestureRecognizerDelegate {
    public let contentView: UIView
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

    public var activate: ((PinchSourceContainerView) -> Void)?
    public var scaleUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    public var animatedOut: (() -> Void)?
    var deactivate: (() -> Void)?
    public var deactivated: (() -> Void)?
    var updated: ((CGFloat, CGPoint, CGPoint) -> Void)?

    public init() {
        self.gesture = PinchSourceGesture()
        self.contentView = UIView()

        super.init(frame: CGRect.zero)

        self.addSubview(self.contentView)

        self.gesture.began = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            cancelContextGestures(sourceView: strongSelf)
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

        self.addGestureRecognizer(self.gesture)
        self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.isActive
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            transition.updateFrame(view: self.contentView, frame: contentFrame)
        }
    }

    func restoreToNaturalSize() {
        guard let naturalContentFrame = self.naturalContentFrame else {
            return
        }
        self.contentView.frame = naturalContentFrame
    }
}

private final class PinchControllerView: ViewControllerTracingNodeView {
    private weak var controller: PinchViewController?

    private var initialSourceFrame: CGRect?

    private let clippingNode: UIView
    private let scrollingContainer: UIView

    private let sourceNode: PinchSourceContainerView
    private let getContentAreaInScreenSpace: () -> CGRect

    private let dimNode: UIView

    private var validLayout: ContainerViewLayout?
    private var isAnimatingOut: Bool = false

    private var hapticFeedback: HapticFeedback?

    init(controller: PinchViewController, sourceNode: PinchSourceContainerView, getContentAreaInScreenSpace: @escaping () -> CGRect) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace

        self.dimNode = UIView()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.dimNode.alpha = 0.0

        self.clippingNode = UIView()
        self.clippingNode.clipsToBounds = true

        self.scrollingContainer = UIView()

        super.init(frame: CGRect.zero)

        self.addSubview(self.dimNode)
        self.addSubview(self.clippingNode)
        self.clippingNode.addSubview(self.scrollingContainer)

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

            strongSelf.sourceNode.contentView.layer.transform = transform
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, previousActionsContainerNode: ContextActionsContainerNode?) {
        if self.isAnimatingOut {
            return
        }

        self.validLayout = layout

        transition.updateFrame(view: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(view: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
    }

    func animateIn() {
        let convertedFrame = convertFrame(self.sourceNode.bounds, from: self.sourceNode, to: self)
        self.sourceNode.contentView.frame = convertedFrame
        self.initialSourceFrame = convertedFrame
        self.scrollingContainer.addSubview(self.sourceNode.contentView)

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
            strongSelf.sourceNode.addSubview(strongSelf.sourceNode.contentView)

            strongSelf.sourceNode.animatedOut?()

            completion()
        }

        let convertedFrame = convertFrame(self.sourceNode.bounds, from: self.sourceNode, to: self)
        self.sourceNode.contentView.frame = convertedFrame
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

            self.sourceNode.contentView.layer.transform = CATransform3DIdentity
            self.sourceNode.contentView.center = CGPoint(x: initialSourceFrame.midX, y: initialSourceFrame.midY)
            self.sourceNode.contentView.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration * 1.2, damping: 110.0)
            self.sourceNode.contentView.layer.animatePosition(from: CGPoint(x: offset.x - pinchOffset.x * (scale - 1.0), y: offset.y - pinchOffset.y * (scale - 1.0)), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true, force: true, completion: { _ in
                performCompletion()
            })

            let dimNodeTransition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: transitionCurve)
            dimNodeTransition.updateAlpha(view: self.dimNode, alpha: 0.0)
        } else {
            performCompletion()
        }
    }

    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if self.isAnimatingOut {
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset.y)
            transition.animateOffsetAdditive(view: self.scrollingContainer, offset: -offset.y)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

public final class PinchViewController: ViewController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let sourceNode: PinchSourceContainerView
    private let getContentAreaInScreenSpace: () -> CGRect

    private var wasDismissed = false

    private var controllerView: PinchControllerView!

    public init(sourceNode: PinchSourceContainerView, getContentAreaInScreenSpace: @escaping () -> CGRect) {
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
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()

        self._ready.set(.single(true))
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        let controllerViewLocal = PinchControllerView(controller: self, sourceNode: sourceNode, getContentAreaInScreenSpace: getContentAreaInScreenSpace)
        controllerView = controllerViewLocal
        displayNode.view.addSubview(controllerViewLocal)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerView.updateLayout(layout: layout, transition: transition, previousActionsContainerNode: nil)
    }

    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)

        self.controllerView.animateIn()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controllerView.frame = self.displayNode.view.bounds
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.wasDismissed {
            self.wasDismissed = true
            self.controllerView.animateOut(completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
        }
    }

    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.controllerView.addRelativeContentOffset(offset, transition: transition)
    }
}
