import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import UIKitRuntimeUtils
import ContextUI

private final class PinchControllerNode: ViewControllerTracingNode {
    private weak var controller: PinchController?

    private var initialSourceFrame: CGRect?

    private let clippingNode: ASDisplayNode
    private let scrollingContainer: ASDisplayNode

    private let sourceNode: PinchSourceContainerNode
    private let disableScreenshots: Bool
    private let getContentAreaInScreenSpace: () -> CGRect

    private let dimNode: ASDisplayNode

    private var validLayout: ContainerViewLayout?
    private var isAnimatingOut: Bool = false

    private var hapticFeedback: HapticFeedback?

    init(controller: PinchController, sourceNode: PinchSourceContainerNode, disableScreenshots: Bool, getContentAreaInScreenSpace: @escaping () -> CGRect) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.disableScreenshots = disableScreenshots
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
        
        if self.disableScreenshots {
            setLayerDisableScreenshots(self.layer, true)
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

public final class PinchControllerImpl: ViewController, PinchController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let sourceNode: PinchSourceContainerNode
    private let disableScreenshots: Bool
    private let getContentAreaInScreenSpace: () -> CGRect

    private var wasDismissed = false

    private var controllerNode: PinchControllerNode {
        return self.displayNode as! PinchControllerNode
    }

    public init(sourceNode: PinchSourceContainerNode, disableScreenshots: Bool = false, getContentAreaInScreenSpace: @escaping () -> CGRect) {
        self.sourceNode = sourceNode
        self.disableScreenshots = disableScreenshots
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
        self.displayNode = PinchControllerNode(controller: self, sourceNode: self.sourceNode, disableScreenshots: self.disableScreenshots, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)

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
