import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import AnimatedStickerNode
import SwiftSignalKit
import ContextUI
import TelegramCore
import ReactionSelectionNode
import ChatControllerInteraction
import FeaturedStickersScreen
import ChatTextInputMediaRecordingButton
import ReplyAccessoryPanelNode
import ChatMessageStickerItemNode
import ChatMessageInstantVideoItemNode
import ChatMessageAnimatedStickerItemNode
import ChatMessageTransitionNode
import ChatMessageBubbleItemNode
import ChatEmptyNode
import ChatMediaInputStickerGridItem
import AccountContext
import ChatInputAccessoryPanel

/// The eased progress `animation` will be at when the frame this runloop turn is composing hits the
/// screen — 0.0 for one that has not started yet.
///
/// A brand-new animation has `beginTime == 0.0`: CoreAnimation stamps it at commit, so it renders its
/// start value. CoreList instead stamps every track in a pass with the time that pass BEGAN
/// (`ListAnimationController.now()`, via `CoreAnimationCompiler.animation(for:property:)`), which is
/// already some milliseconds in the past by the time a transaction completion runs — such a track is
/// partway through on its very first rendered frame, and reading its `fromValue` would over-correct by
/// that much.
///
/// Times are taken in the layer's own space, which is what CoreAnimation evaluates in, so a
/// speed/timeOffset anywhere up the tree (Slow Animations) does not skew the result. A curve this
/// cannot evaluate — a `CASpringAnimation`, whose value needs the spring solution rather than a
/// bezier — reports 0.0 and therefore contributes its start value: the same answer this file gave for
/// every animation before, and an under- rather than over-correction.
private func pendingAnimationProgress(_ animation: CAAnimation, on layer: CALayer) -> CGFloat {
    guard animation.beginTime > 0.0 else {
        return 0.0
    }
    guard let timingFunction = animation.timingFunction, !(animation is CASpringAnimation) else {
        return 0.0
    }
    let speed = animation.speed == 0.0 ? 1.0 : Double(animation.speed)
    let elapsed = (layer.convertTime(CACurrentMediaTime(), from: nil) - animation.beginTime) * speed + animation.timeOffset
    guard elapsed > 0.0, animation.duration > 0.0 else {
        return elapsed > 0.0 ? 1.0 : 0.0
    }
    return CGFloat(timingFunction.solveOutput(atInput: min(1.0, elapsed / animation.duration)))
}

private extension CAMediaTimingFunction {
    /// The cubic bezier's y for a given x, both on [0, 1] — the curve's output at a fraction of its
    /// duration. Newton-Raphson on x, which converges in a couple of steps for the shallow curves
    /// used here; the clamp keeps a degenerate control point (a zero derivative) from diverging.
    func solveOutput(atInput input: Double) -> Double {
        var rawPoint = [Float](repeating: 0.0, count: 2)
        self.getControlPoint(at: 1, values: &rawPoint)
        let control1 = (x: Double(rawPoint[0]), y: Double(rawPoint[1]))
        self.getControlPoint(at: 2, values: &rawPoint)
        let control2 = (x: Double(rawPoint[0]), y: Double(rawPoint[1]))

        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let inverseT = 1.0 - t
            return 3.0 * inverseT * inverseT * t * a + 3.0 * inverseT * t * t * b + t * t * t
        }

        var t = input
        for _ in 0 ..< 8 {
            let error = bezier(t, control1.x, control2.x) - input
            if abs(error) < 1.0e-5 {
                break
            }
            let inverseT = 1.0 - t
            let derivative = 3.0 * inverseT * inverseT * control1.x + 6.0 * inverseT * t * (control2.x - control1.x) + 3.0 * t * t * (1.0 - control2.x)
            if abs(derivative) < 1.0e-6 {
                break
            }
            t = min(1.0, max(0.0, t - error / derivative))
        }
        return bezier(t, control1.y, control2.y)
    }
}

/// The per-axis value an animation's endpoint describes, or nil on an axis the keyPath does not
/// drive. Only the geometry keyPaths the list backends actually emit are decoded; anything else
/// reports nothing and is skipped by the caller.
private func animatedGeometryValue(_ value: Any?, keyPath: String) -> (x: CGFloat?, y: CGFloat?) {
    guard let value = value else {
        return (nil, nil)
    }
    let nsValueType = (value as? NSValue).map { String(cString: $0.objCType) } ?? ""
    switch keyPath {
    case "sublayerTransform", "transform":
        guard nsValueType.contains("CATransform3D"), let value = value as? NSValue else {
            return (nil, nil)
        }
        let transform = value.caTransform3DValue
        return (transform.m41, transform.m42)
    case "bounds":
        guard nsValueType.contains("CGRect"), let value = value as? NSValue else {
            return (nil, nil)
        }
        return (value.cgRectValue.origin.x, value.cgRectValue.origin.y)
    case "bounds.origin", "position":
        guard nsValueType.contains("CGPoint"), let value = value as? NSValue else {
            return (nil, nil)
        }
        return (value.cgPointValue.x, value.cgPointValue.y)
    default:
        guard let value = value as? NSNumber else {
            return (nil, nil)
        }
        if keyPath.hasSuffix(".x") {
            return (CGFloat(value.doubleValue), nil)
        } else if keyPath.hasSuffix(".y") {
            return (nil, CGFloat(value.doubleValue))
        } else {
            return (nil, nil)
        }
    }
}

/// How far `layer`'s animations on one geometry property displace it from its MODEL value, as the
/// next frame will render it. Zero when nothing is animating that property — which is what keeps a
/// model value written in this same turn WITHOUT an animation (CoreList rebases its container that
/// way) from being counted: that write renders immediately, so the model already is the truth for it.
private func pendingGeometryDisplacement(_ layer: CALayer, keyPathPrefixes: [String], modelValue: CGPoint) -> CGPoint {
    guard let keys = layer.animationKeys() else {
        return .zero
    }
    var result = CGPoint.zero
    for key in keys {
        guard let animation = layer.animation(forKey: key) as? CABasicAnimation, let keyPath = animation.keyPath else {
            continue
        }
        guard keyPathPrefixes.contains(where: { keyPath == $0 || keyPath.hasPrefix("\($0).") }) else {
            continue
        }
        let progress = pendingAnimationProgress(animation, on: layer)
        let from = animatedGeometryValue(animation.fromValue, keyPath: keyPath)
        let to = animatedGeometryValue(animation.toValue, keyPath: keyPath)
        // An additive animation's endpoints are displacements from the model value, so its
        // contribution is the interpolated value itself; a plain one's are absolute, and the model
        // value stands in for an omitted endpoint as it does for CoreAnimation.
        let baseX = animation.isAdditive ? 0.0 : modelValue.x
        let baseY = animation.isAdditive ? 0.0 : modelValue.y
        let currentX = (from.x ?? baseX) + ((to.x ?? baseX) - (from.x ?? baseX)) * progress
        let currentY = (from.y ?? baseY) + ((to.y ?? baseY) - (from.y ?? baseY)) * progress
        result.x += currentX - baseX
        result.y += currentY - baseY
    }
    return result
}

/// The translation, in `parent`'s bounds coordinate space, between where `child` and its contents
/// RENDER on the next frame and where the model geometry `CALayer.convert` reads puts them.
///
/// Every list movement in the chat leaves the model at the destination and carries the travel in an
/// animation, so this is what separates "where the content is" from "where it is going". The chat has
/// one backend per mechanism: `ListViewImpl` scrolls by animating its own `sublayerTransform`
/// additively (Display/Source/ListView.swift:3775), while CoreList parks its content host's model
/// `bounds.origin.y` at the settled offset and carries the travel in an additive `bounds.origin.y`
/// track, moving individual rows with additive `position` tracks
/// (CoreListDemo/CoreAnimationCompiler.swift `keyPath(for:)`). Reading the mechanism off the layers
/// rather than asking the list keeps this correct for either backend — and for a row that is moving
/// under its own track while the viewport moves too.
///
/// A `bounds.origin` displacement enters NEGATED: it is the origin of the coordinate space the
/// children are positioned in, so scrolling it down moves them up.
private func pendingRenderedTranslation(parent: CALayer, child: CALayer) -> CGPoint {
    let sublayerTransformModel = CGPoint(x: parent.sublayerTransform.m41, y: parent.sublayerTransform.m42)
    let sublayerTransform = pendingGeometryDisplacement(parent, keyPathPrefixes: ["sublayerTransform"], modelValue: sublayerTransformModel)
    let boundsOrigin = pendingGeometryDisplacement(parent, keyPathPrefixes: ["bounds"], modelValue: parent.bounds.origin)
    let position = pendingGeometryDisplacement(child, keyPathPrefixes: ["position"], modelValue: child.position)

    return CGPoint(
        x: sublayerTransform.x - boundsOrigin.x + position.x,
        y: sublayerTransform.y - boundsOrigin.y + position.y
    )
}

/// Convert a rect expressed in window coordinates to `toView`'s local coordinates,
/// accounting for the movement any ancestor of `toView` is in the middle of. Returns
/// the position in `toView.bounds` that `windowRect` renders at on the next frame.
///
/// Standard `toView.layer.convert(windowRect, from: nil)` reads model geometry only,
/// so it yields the position that will render at `windowRect` once every animation in
/// flight has FINISHED — a list schedules its scroll and leaves the model at the
/// destination. For source-side morph calibration, where the snapshot was captured at
/// pre-animation state, the position it renders at when the morph starts is what we
/// want; taking the settled one instead offsets the bubble by the list's whole travel.
///
/// Walks the layer chain top-down from the root to `toView`. At each parent→child step
/// it subtracts that step's pending rendered-minus-model translation *in the parent's
/// own bounds coord space*, then does the standard one-step `convert(_:to:)` into the
/// child. Applying the correction at the right level (rather than flat-summing the
/// translations in the destination space) lets `CALayer.convert` propagate each
/// correction through any remaining transforms — child `transform`, further ancestors'
/// own model `sublayerTransform`, etc. — so the result is correct even when the chain
/// contains non-translation transforms, and both chat list backends put a π rotation in
/// it twice over.
private func convertAnimatingSourceRectFromWindow(_ windowRect: CGRect, toView: UIView) -> CGRect {
    var chain: [CALayer] = []
    var layer: CALayer? = toView.layer
    while let cur = layer {
        chain.append(cur)
        layer = cur.superlayer
    }
    chain.reverse()

    var r = windowRect
    for i in 0..<(chain.count - 1) {
        let parent = chain[i]
        let child = chain[i + 1]

        let pending = pendingRenderedTranslation(parent: parent, child: child)
        let adjustedR = r.offsetBy(dx: -pending.x, dy: -pending.y)
        r = parent.convert(adjustedR, to: child)
    }
    return r
}

/// `rect` of `sourceView` as it renders now, converted into `toView` as it renders now. The source is read through its
/// presentation layers when it is in `toView`'s window, and through the windows' frames when it is in another one (the
/// keyboard's, see `convertAcrossWindows`); then `convertAnimatingSourceRectFromWindow` accounts for any movement
/// `toView`'s ancestors are in the middle of. An animation that runs inside a chat item needs this: the list leaves
/// the item's model at its destination while it scrolls a new message in, so a plain conversion starts the flight off
/// by the remaining scroll.
private func convertRenderedSourceRect(_ rect: CGRect, from sourceView: UIView, toAnimatingView toView: UIView) -> CGRect {
    guard let toWindow = toView.window else {
        return sourceView.convertAcrossWindows(rect, to: toView)
    }
    let windowRect: CGRect
    if sourceView.window === toWindow, let presentationLayer = sourceView.layer.presentation() {
        windowRect = presentationLayer.convert(rect, to: nil)
    } else {
        windowRect = sourceView.convertAcrossWindows(rect, to: toWindow)
    }
    return convertAnimatingSourceRectFromWindow(windowRect, toView: toView)
}

private final class OverlayTransitionContainerNode: ViewControllerTracingNode {
    override init() {
        super.init()
    }

    deinit {
    }

    override func didLoad() {
        super.didLoad()
    }

    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

private final class OverlayTransitionContainerController: ViewController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private var controllerNode: OverlayTransitionContainerNode {
        return self.displayNode as! OverlayTransitionContainerNode
    }

    private var wasDismissed: Bool = false

    init() {
        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .Ignore
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    override public func loadDisplayNode() {
        self.displayNode = OverlayTransitionContainerNode()

        self.displayNodeDidLoad()

        self._ready.set(.single(true))
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.updateLayout(layout: layout, transition: transition)
    }

    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.wasDismissed {
            self.wasDismissed = true
            self.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        }
    }
}

private func chatMessageTransitionAnimationDuration() -> Double {
    #if DEBUG && false
    return 3.0
    #else
    return 0.3
    #endif
}

public final class ChatMessageTransitionNodeImpl: ASDisplayNode, ChatMessageTransitionNode, ChatMessageTransitionProtocol {
    static let animationDuration: Double = chatMessageTransitionAnimationDuration()

    public static let verticalAnimationControlPoints: (Float, Float, Float, Float) = (0.19919472913616398, 0.010644531250000006, 0.27920937042459737, 0.91025390625)
    public static let verticalAnimationCurve: ContainedViewLayoutTransitionCurve = .custom(verticalAnimationControlPoints.0, verticalAnimationControlPoints.1, verticalAnimationControlPoints.2, verticalAnimationControlPoints.3)
    public static let horizontalAnimationCurve: ContainedViewLayoutTransitionCurve = .custom(0.23, 1.0, 0.32, 1.0)

    final class ReplyPanel {
        let titleView: UIView
        let textView: UIView
        let lineView: UIView
        let imageView: UIView?
        let relativeSourceRect: CGRect
        let relativeTargetRect: CGRect

        init(
            titleView: UIView,
            textView: UIView,
            lineView: UIView,
            imageView: UIView?,
            relativeSourceRect: CGRect,
            relativeTargetRect: CGRect
        ) {
            self.titleView = titleView
            self.textView = textView
            self.lineView = lineView
            self.imageView = imageView
            self.relativeSourceRect = relativeSourceRect
            self.relativeTargetRect = relativeTargetRect
        }
    }

    final class Sticker {
        let imageNode: TransformImageNode?
        let animationNode: AnimatedStickerNode?
        let placeholderNode: ASDisplayNode?
        let imageLayer: CALayer?
        let relativeSourceRect: CGRect
        
        var sourceFrame: CGRect {
            if let imageNode = self.imageNode {
                return imageNode.frame
            } else if let imageLayer = self.imageLayer {
                return imageLayer.bounds
            } else {
                return CGRect(origin: CGPoint(), size: relativeSourceRect.size)
            }
        }
        
        var sourceLayer: CALayer? {
            if let imageNode = self.imageNode {
                return imageNode.layer
            } else if let imageLayer = self.imageLayer {
                return imageLayer
            } else {
                return nil
            }
        }

        init(imageNode: TransformImageNode?, animationNode: AnimatedStickerNode?, placeholderNode: ASDisplayNode?, imageLayer: CALayer?, relativeSourceRect: CGRect) {
            self.imageNode = imageNode
            self.animationNode = animationNode
            self.placeholderNode = placeholderNode
            self.imageLayer = imageLayer
            self.relativeSourceRect = relativeSourceRect
        }
        
        func snapshotContentTree() -> UIView? {
            if let animationNode = self.animationNode {
                return animationNode.view.snapshotContentTree()
            } else if let imageNode = self.imageNode {
                return imageNode.view.snapshotContentTree()
            } else if let sourceLayer = self.imageLayer {
                return sourceLayer.snapshotContentTreeAsView()
            } else {
                return nil
            }
        }
    }

    enum Source {
        final class TextInput {
            let backgroundView: UIView
            let contentView: UIView
            let sourceRect: CGRect
            let scrollOffset: CGFloat

            init(backgroundView: UIView, contentView: UIView, sourceRect: CGRect, scrollOffset: CGFloat) {
                self.backgroundView = backgroundView
                self.contentView = contentView
                self.sourceRect = sourceRect
                self.scrollOffset = scrollOffset
            }
        }

        enum StickerInput {
            case inputPanel(itemNode: ChatMediaInputStickerGridItemNode)
            case mediaPanel(itemNode: HorizontalStickerGridItemNode)
            case universal(sourceContainerView: UIView, sourceRect: CGRect, sourceLayer: CALayer)
            case emptyPanel(itemNode: ChatEmptyNodeStickerContentNode)
        }

        final class AudioMicInput {
            let micButton: ChatTextInputMediaRecordingButton

            init(micButton: ChatTextInputMediaRecordingButton) {
                self.micButton = micButton
            }
        }

        final class VideoMessage {
            let view: UIView

            init(view: UIView) {
                self.view = view
            }
        }

        final class MediaInput {
            let extractSnapshot: () -> UIView?

            init(extractSnapshot: @escaping () -> UIView?) {
                self.extractSnapshot = extractSnapshot
            }
        }
        
        final class GroupedMediaInput {
            let extractSnapshots: () -> [UIView]

            init(extractSnapshots: @escaping () -> [UIView]) {
                self.extractSnapshots = extractSnapshots
            }
        }

        case textInput(textInput: TextInput, replyPanel: ChatInputAccessoryPanelView?)
        case stickerMediaInput(input: StickerInput, replyPanel: ChatInputAccessoryPanelView?)
        case audioMicInput(AudioMicInput)
        case videoMessage(VideoMessage)
        case mediaInput(MediaInput)
        case groupedMediaInput(GroupedMediaInput)
    }
            
    final class DecorationItemNodeImpl: ASDisplayNode, ChatMessageTransitionNode.DecorationItemNode {
        let itemNode: ChatMessageItemNodeProtocol
        let contentView: UIView
        var globalPortalSourceView: PortalSourceView?
        let aboveEverything: Bool
        private let getContentAreaInScreenSpace: () -> CGRect
        
        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode
        private let clippingNode: ASDisplayNode
        
        fileprivate weak var overlayController: OverlayTransitionContainerController?
        
        init(itemNode: ChatMessageItemNodeProtocol, contentView: UIView, aboveEverything: Bool, getContentAreaInScreenSpace: @escaping () -> CGRect) {
            self.itemNode = itemNode
            self.contentView = contentView
            self.aboveEverything = aboveEverything
            self.getContentAreaInScreenSpace = getContentAreaInScreenSpace
            
            self.clippingNode = ASDisplayNode()
            self.clippingNode.clipsToBounds = true
            
            self.scrollingContainer = ASDisplayNode()
            self.containerNode = ASDisplayNode()
            
            super.init()
            
            self.addSubnode(self.clippingNode)
            self.clippingNode.addSubnode(self.scrollingContainer)
            self.scrollingContainer.addSubnode(self.containerNode)
            
            if aboveEverything {
                let globalPortalSourceView = PortalSourceView()
                globalPortalSourceView.needsGlobalPortal = true
                self.globalPortalSourceView = globalPortalSourceView
                globalPortalSourceView.addSubview(self.contentView)
                self.containerNode.view.addSubview(globalPortalSourceView)
            } else {
                self.containerNode.view.addSubview(self.contentView)
            }
        }
        
        func updateLayout(size: CGSize) {
            self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
            
            // The chat history node composes (rather than is) its ListViewImpl, so item nodes sit one
            // level deeper: itemNode -> listView (identity) -> ChatHistoryListNodeImpl wrapper (holds the
            // 180° rotation) -> un-rotated container. Convert up to that container (3 hops) so the wrapper's
            // rotation is applied as an intermediate transform, yielding the item's on-screen rect (matching
            // the pre-composition 2-hop behavior). Stopping at the wrapper's own space would skip its rotation.
            let absoluteRect = self.itemNode.view.convert(self.itemNode.view.bounds, to: self.itemNode.supernode?.supernode?.supernode?.view)
            self.containerNode.frame = absoluteRect
            if let globalPortalSourceView = self.globalPortalSourceView {
                globalPortalSourceView.frame = CGRect(origin: CGPoint(), size: size)
            }
        }
        
        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
            if transition.isAnimated {
                assert(true)
            }
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: -offset)
            transition.animateOffsetAdditive(node: self.scrollingContainer, offset: offset)
        }

        func addContentOffset(offset: CGFloat) {
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset)
        }
    }
    
    final class CustomOffsetHandlerImpl {
        weak var itemNode: ChatMessageItemNodeProtocol?
        let update: (CGFloat, ContainedViewLayoutTransition) -> Bool
        
        init(itemNode: ChatMessageItemNodeProtocol, update: @escaping (CGFloat, ContainedViewLayoutTransition) -> Bool) {
            self.itemNode = itemNode
            self.update = update
        }
    }

    private final class AnimatingItemNode: ASDisplayNode {
        let itemNode: ChatMessageItemNodeProtocol
        private let contextSourceNode: ContextExtractedContentContainingNode
        private let source: ChatMessageTransitionNodeImpl.Source
        private let getContentAreaInScreenSpace: () -> CGRect

        private let portalSourceView: PortalSourceView
        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode
        private let clippingNode: ASDisplayNode
        private var portalTargetView: PortalView?

        weak var overlayController: OverlayTransitionContainerController?

        var animationEnded: (() -> Void)?
        var updateAfterCompletion: Bool = false

        init(itemNode: ChatMessageItemNodeProtocol, contextSourceNode: ContextExtractedContentContainingNode, source: ChatMessageTransitionNodeImpl.Source, overlayContainerNode: ASDisplayNode, getContentAreaInScreenSpace: @escaping () -> CGRect) {
            self.portalSourceView = PortalSourceView()
            
            self.itemNode = itemNode
            self.getContentAreaInScreenSpace = getContentAreaInScreenSpace

            self.clippingNode = ASDisplayNode()
            self.clippingNode.clipsToBounds = false

            self.scrollingContainer = ASDisplayNode()
            self.containerNode = ASDisplayNode()
            self.contextSourceNode = contextSourceNode
            self.source = source

            super.init()
            
            self.view.addSubview(self.portalSourceView)

            self.portalSourceView.addSubview(self.clippingNode.view)
            self.clippingNode.addSubnode(self.scrollingContainer)
            self.scrollingContainer.addSubnode(self.containerNode)
            
            if let portalTargetView = PortalView(matchPosition: true) {
                self.portalTargetView = portalTargetView
                self.portalSourceView.addPortal(view: portalTargetView)
                overlayContainerNode.view.addSubview(portalTargetView.view)
            }
        }

        deinit {
            self.contextSourceNode.addSubnode(self.contextSourceNode.contentNode)
        }

        func updateLayout(size: CGSize) {
            self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
        }

        func beginAnimation() {
            if let portalTargetView = self.portalTargetView {
                portalTargetView.view.alpha = 0.0
                portalTargetView.view.layer.allowsGroupOpacity = true
                portalTargetView.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.14, delay: 0.14)
                
                self.portalSourceView.layer.allowsGroupOpacity = true
                self.portalSourceView.layer.animateAlpha(from: 0.01, to: 1.0, duration: 0.1, delay: 0.12)
            }
            
            let verticalDuration: Double = ChatMessageTransitionNodeImpl.animationDuration
            let horizontalDuration: Double = verticalDuration
            let delay: Double = 0.0

            var updatedContentAreaInScreenSpace = self.getContentAreaInScreenSpace()
            updatedContentAreaInScreenSpace.size.width = updatedContentAreaInScreenSpace.origin.x + self.clippingNode.bounds.width
            updatedContentAreaInScreenSpace.origin.x = 0.0

            let clippingOffset = updatedContentAreaInScreenSpace.minY - self.clippingNode.frame.minY
            self.clippingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: updatedContentAreaInScreenSpace.minY), size: CGSize(width: updatedContentAreaInScreenSpace.size.width, height: self.clippingNode.bounds.height))
            self.clippingNode.bounds = CGRect(origin: CGPoint(x: 0.0, y: clippingOffset), size: self.clippingNode.bounds.size)

            switch self.source {
            case let .textInput(initialTextInput, replyPanel):
                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                var currentContentRect = self.contextSourceNode.contentRect
                let contextSourceNode = self.contextSourceNode
                self.contextSourceNode.layoutUpdated = { [weak self, weak contextSourceNode] size, _ in
                    guard let strongSelf = self, let contextSourceNode = contextSourceNode, strongSelf.contextSourceNode === contextSourceNode else {
                        return
                    }
                    let updatedContentRect = contextSourceNode.contentRect
                    let deltaY = updatedContentRect.height - currentContentRect.height
                    if !deltaY.isZero {
                        currentContentRect = updatedContentRect
                        strongSelf.addContentOffset(offset: deltaY, itemNode: nil)
                    }
                }

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let targetAbsoluteRect = self.contextSourceNode.view.convertAcrossWindows(self.contextSourceNode.contentRect, to: self.view)

                let sourceRect = convertAnimatingSourceRectFromWindow(initialTextInput.sourceRect, toView: self.view)
                let sourceBackgroundAbsoluteRect = initialTextInput.backgroundView.frame.offsetBy(dx: sourceRect.minX, dy: sourceRect.minY)
                let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.minX, y: sourceBackgroundAbsoluteRect.maxY - self.contextSourceNode.contentRect.height), size: self.contextSourceNode.contentRect.size)

                let textInput = ChatMessageTransitionNodeImpl.Source.TextInput(backgroundView: initialTextInput.backgroundView, contentView: initialTextInput.contentView, sourceRect: sourceRect, scrollOffset: initialTextInput.scrollOffset)
                textInput.backgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height), size: textInput.backgroundView.bounds.size)
                textInput.contentView.frame = textInput.contentView.frame.offsetBy(dx: 0.0, dy: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel, let replyPanelTransitionData = replyPanel.transitionData, let replyPanelParentView = replyPanel.superview {
                    let replyPanelFrame = replyPanel.frame
                    var replySourceAbsoluteFrame: CGRect
                    
                    if let storedFrameBeforeDismissed = replyPanel.storedFrameBeforeDismissed {
                        replySourceAbsoluteFrame = convertAnimatingSourceRectFromWindow(storedFrameBeforeDismissed, toView: self.view)
                    } else {
                        replySourceAbsoluteFrame = replyPanelParentView.convertAcrossWindows(replyPanelFrame, to: self.view)
                    }

                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.minX - self.contextSourceNode.contentRect.minX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.minY - self.contextSourceNode.contentRect.minY

                    var globalTargetFrame = replySourceAbsoluteFrame.offsetBy(dx: 0.0, dy: replyPanelFrame.height)

                    globalTargetFrame.origin.x += sourceAbsoluteRect.minX - targetAbsoluteRect.minX
                    globalTargetFrame.origin.y += sourceAbsoluteRect.minY - targetAbsoluteRect.minY

                    sourceReplyPanel = ReplyPanel(
                        titleView: replyPanelTransitionData.titleView,
                        textView: replyPanelTransitionData.textView,
                        lineView: replyPanelTransitionData.lineView,
                        imageView: replyPanelTransitionData.imageView,
                        relativeSourceRect: replySourceAbsoluteFrame,
                        relativeTargetRect: globalTargetFrame
                    )
                }

                self.itemNode.cancelInsertionAnimations()

                let horizontalCurve = ChatMessageTransitionNodeImpl.horizontalAnimationCurve
                let horizontalTransition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: horizontalCurve)
                let verticalCurve = ChatMessageTransitionNodeImpl.verticalAnimationCurve
                let verticalTransition: ContainedViewLayoutTransition = .animated(duration: verticalDuration, curve: verticalCurve)

                let combinedTransition = CombinedTransition(horizontal: horizontalTransition, vertical: verticalTransition)

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: verticalCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: horizontalCurve.mediaTimingFunction, additive: true)
                

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.animateContentFromTextInputField(
                        textInput: ChatMessageBubbleItemNode.AnimationTransitionTextInput(
                            backgroundView: textInput.backgroundView,
                            contentView: textInput.contentView,
                            sourceRect: textInput.sourceRect,
                            scrollOffset: textInput.scrollOffset
                        ),
                        transition: combinedTransition
                    )
                    if let sourceReplyPanel {
                        itemNode.animateReplyPanel(
                            sourceReplyPanel: ChatMessageBubbleItemNode.AnimationTransitionReplyPanel(
                                titleView: sourceReplyPanel.titleView,
                                textView: sourceReplyPanel.textView,
                                lineView: sourceReplyPanel.lineView,
                                imageView: sourceReplyPanel.imageView,
                                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                                relativeTargetRect: sourceReplyPanel.relativeTargetRect
                            ),
                            transition: combinedTransition
                        )
                    }
                } else if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromTextInputField(
                        textInput: ChatMessageAnimatedStickerItemNode.AnimationTransitionTextInput(
                            backgroundView: textInput.backgroundView,
                            contentView: textInput.contentView,
                            sourceRect: textInput.sourceRect,
                            scrollOffset: textInput.scrollOffset
                        ),
                        transition: combinedTransition
                    )
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(
                            sourceReplyPanel: ChatMessageAnimatedStickerItemNode.AnimationTransitionReplyPanel(
                                titleView: sourceReplyPanel.titleView,
                                textView: sourceReplyPanel.textView,
                                lineView: sourceReplyPanel.lineView,
                                imageView: sourceReplyPanel.imageView,
                                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                                relativeTargetRect: sourceReplyPanel.relativeTargetRect
                            ),
                            transition: combinedTransition
                        )
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromTextInputField(
                        textInput: ChatMessageStickerItemNode.AnimationTransitionTextInput(
                            backgroundView: textInput.backgroundView,
                            contentView: textInput.contentView,
                            sourceRect: textInput.sourceRect,
                            scrollOffset: textInput.scrollOffset
                        ),
                        transition: combinedTransition
                    )
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(
                            sourceReplyPanel: ChatMessageStickerItemNode.AnimationTransitionReplyPanel(
                                titleView: sourceReplyPanel.titleView,
                                textView: sourceReplyPanel.textView,
                                lineView: sourceReplyPanel.lineView,
                                imageView: sourceReplyPanel.imageView,
                                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                                relativeTargetRect: sourceReplyPanel.relativeTargetRect
                            ),
                            transition: combinedTransition
                        )
                    }
                }
            case let .stickerMediaInput(stickerMediaInput, replyPanel):
                self.itemNode.cancelInsertionAnimations()

                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let stickerSource: Sticker
                let sourceAbsoluteRect: CGRect
                switch stickerMediaInput {
                case let .inputPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: sourceItemNode.placeholderNode, imageLayer: nil, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = convertRenderedSourceRect(sourceItemNode.imageNode.frame, from: sourceItemNode.view, toAnimatingView: self.view)
                case let .mediaPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: sourceItemNode.placeholderNode, imageLayer: nil, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = convertRenderedSourceRect(sourceItemNode.imageNode.frame, from: sourceItemNode.view, toAnimatingView: self.view)
                case let .universal(sourceContainerView, sourceRect, sourceLayer):
                    stickerSource = Sticker(imageNode: nil, animationNode: nil, placeholderNode: nil, imageLayer: sourceLayer, relativeSourceRect: sourceLayer.frame)
                    sourceAbsoluteRect = convertRenderedSourceRect(sourceRect, from: sourceContainerView, toAnimatingView: self.view)
                case let .emptyPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.stickerNode.imageNode, animationNode: sourceItemNode.stickerNode.animationNode, placeholderNode: nil, imageLayer: nil, relativeSourceRect: sourceItemNode.stickerNode.imageNode.frame)
                    sourceAbsoluteRect = convertRenderedSourceRect(sourceItemNode.stickerNode.imageNode.frame, from: sourceItemNode.stickerNode.view, toAnimatingView: self.view)
                }

                let targetAbsoluteRect = self.contextSourceNode.view.convertAcrossWindows(self.contextSourceNode.contentRect, to: self.view)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel, let replyPanelTransitionData = replyPanel.transitionData, let replyPanelParentView = replyPanel.superview {
                    let replyPanelFrame = replyPanel.frame
                    var replySourceAbsoluteFrame: CGRect
                    
                    if let storedFrameBeforeDismissed = replyPanel.storedFrameBeforeDismissed {
                        replySourceAbsoluteFrame = self.view.convert(storedFrameBeforeDismissed, from: nil)
                    } else {
                        replySourceAbsoluteFrame = replyPanelParentView.convertAcrossWindows(replyPanelFrame, to: self.view)
                    }
                    
                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.midX - self.contextSourceNode.contentRect.midX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.midY - self.contextSourceNode.contentRect.midY

                    sourceReplyPanel = ReplyPanel(
                        titleView: replyPanelTransitionData.titleView,
                        textView: replyPanelTransitionData.textView,
                        lineView: replyPanelTransitionData.lineView,
                        imageView: replyPanelTransitionData.imageView,
                        relativeSourceRect: replySourceAbsoluteFrame,
                        relativeTargetRect: replySourceAbsoluteFrame.offsetBy(dx: 0.0, dy: replySourceAbsoluteFrame.height)
                    )
                }

                let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))

                if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(
                        stickerSource: ChatMessageAnimatedStickerItemNode.AnimationTransitionSticker(
                            imageNode: stickerSource.imageNode,
                            animationNode: stickerSource.animationNode,
                            placeholderNode: stickerSource.placeholderNode,
                            imageLayer: stickerSource.imageLayer,
                            relativeSourceRect: stickerSource.relativeSourceRect
                        ),
                        transition: combinedTransition
                    )
                    if let sourceAnimationNode = stickerSource.animationNode {
                        itemNode.animationNode?.setFrameIndex(sourceAnimationNode.currentFrameIndex)
                    }
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(
                            sourceReplyPanel: ChatMessageAnimatedStickerItemNode.AnimationTransitionReplyPanel(
                                titleView: sourceReplyPanel.titleView,
                                textView: sourceReplyPanel.textView,
                                lineView: sourceReplyPanel.lineView,
                                imageView: sourceReplyPanel.imageView,
                                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                                relativeTargetRect: sourceReplyPanel.relativeTargetRect
                            ),
                            transition: combinedTransition
                        )
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(
                        stickerSource: ChatMessageStickerItemNode.AnimationTransitionSticker(
                            imageNode: stickerSource.imageNode,
                            animationNode: stickerSource.animationNode,
                            placeholderNode: stickerSource.placeholderNode,
                            imageLayer: stickerSource.imageLayer,
                            relativeSourceRect: stickerSource.relativeSourceRect
                        ),
                        transition: combinedTransition
                    )
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(
                            sourceReplyPanel: ChatMessageStickerItemNode.AnimationTransitionReplyPanel(
                                titleView: sourceReplyPanel.titleView,
                                textView: sourceReplyPanel.textView,
                                lineView: sourceReplyPanel.lineView,
                                imageView: sourceReplyPanel.imageView,
                                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                                relativeTargetRect: sourceReplyPanel.relativeTargetRect
                            ),
                            transition: combinedTransition
                        )
                    }
                }

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.horizontalAnimationCurve.mediaTimingFunction, additive: true)

                switch stickerMediaInput {
                case .inputPanel, .universal:
                    break
                case let .mediaPanel(sourceItemNode):
                    sourceItemNode.isHidden = true
                case let .emptyPanel(sourceItemNode):
                    sourceItemNode.isHidden = true
                }
            case let .audioMicInput(audioMicInput):
                if let (container, localRect) = audioMicInput.micButton.contentContainer {
                    // No snapshot of the blob: it flies itself, in its own container, along the same path as the
                    // play button here in the chat, crossfading into it at the start.
                    let sourceAbsoluteRect = convertRenderedSourceRect(localRect, from: container, toAnimatingView: self.view)

                    let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))

                    if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                        if let contextContainer = itemNode.animateFromMicInput(sourceSize: sourceAbsoluteRect.size, transition: combinedTransition) {
                            self.containerNode.addSubnode(contextContainer.contentNode)

                            let targetAbsoluteRect = contextContainer.view.convertAcrossWindows(contextContainer.contentRect, to: self.view)

                            self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -contextContainer.contentRect.minX, dy: -contextContainer.contentRect.minY)
                            contextContainer.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                            let _ = audioMicInput.micButton.animateDecorationToSentMessage(targetRect: targetAbsoluteRect, in: self.view, duration: verticalDuration, horizontalCurve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve, verticalCurve: ChatMessageTransitionNodeImpl.verticalAnimationCurve)

                            self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self, weak contextContainer] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let contextContainer = contextContainer {
                                    contextContainer.isExtractedToContextPreview = false
                                    contextContainer.isExtractedToContextPreviewUpdated?(false)
                                    contextContainer.addSubnode(contextContainer.contentNode)
                                }

                                strongSelf.endAnimation()
                            })

                            self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.horizontalAnimationCurve.mediaTimingFunction, additive: true)
                        }
                    }
                }
            case let .videoMessage(videoMessage):
                let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.cancelInsertionAnimations()

                    self.contextSourceNode.isExtractedToContextPreview = true
                    self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                    self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                    let sourceAbsoluteRect = videoMessage.view.frame
                    let targetAbsoluteRect = self.contextSourceNode.view.convertAcrossWindows(self.contextSourceNode.contentRect, to: self.view)

                    videoMessage.view.frame = videoMessage.view.frame.offsetBy(dx: targetAbsoluteRect.midX - sourceAbsoluteRect.midX, dy: targetAbsoluteRect.midY - sourceAbsoluteRect.midY)

                    self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                    self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)

                    self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.verticalAnimationCurve.mediaTimingFunction, additive: true, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }

                        strongSelf.endAnimation()
                    })

                    itemNode.animateInstantVideoFromSnapshot(snapshotView: videoMessage.view, transition: combinedTransition)
                }
            case let .mediaInput(mediaInput):
                if let snapshotView = mediaInput.extractSnapshot() {
                    Queue.mainQueue().justDispatch { [snapshotView, weak self] in
                        guard let self else {
                            return
                        }

                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            itemNode.cancelInsertionAnimations()

                            self.contextSourceNode.isExtractedToContextPreview = true
                            self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                            self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                            let targetAbsoluteRect = self.contextSourceNode.view.convertAcrossWindows(self.contextSourceNode.contentRect, to: self.view)
                            let sourceBackgroundAbsoluteRect = snapshotView.frame
                            let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.midX - self.contextSourceNode.contentRect.size.width / 2.0, y: sourceBackgroundAbsoluteRect.midY - self.contextSourceNode.contentRect.size.height / 2.0), size: self.contextSourceNode.contentRect.size)

                            let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))

                            if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                                itemNode.animateContentFromMediaInput(snapshotView: snapshotView, transition: combinedTransition)
                            }

                            self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)

                            snapshotView.center = targetAbsoluteRect.center.offsetBy(dx: -self.containerNode.frame.minX, dy: -self.containerNode.frame.minY)
                            self.containerNode.view.addSubview(snapshotView)

                            self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                            self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)
                            self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.endAnimation()
                            })

                            combinedTransition.horizontal.animateTransformScale(node: self.contextSourceNode.contentNode, from: CGPoint(x: sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width, y: sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height))

                            combinedTransition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: CGPoint(x: 1.0 / (sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width), y: 1.0 / (sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height)))

                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })

                        }
                    }
                } else {
                    self.endAnimation()
                }
            case let .groupedMediaInput(groupedMediaInput):
                let snapshotViews = groupedMediaInput.extractSnapshots()
                if snapshotViews.isEmpty {
                    self.endAnimation()
                    return
                }
                Queue.mainQueue().justDispatch { [weak self] in
                    guard let self else {
                        return
                    }

                    if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                        itemNode.cancelInsertionAnimations()

                        self.contextSourceNode.isExtractedToContextPreview = true
                        self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                        self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                        let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNodeImpl.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))

                        var targetContentRects: [CGRect] = []
                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            targetContentRects = itemNode.animateContentFromGroupedMediaInput(transition: combinedTransition)
                        }
                        
                        let targetAbsoluteRect = self.contextSourceNode.view.convertAcrossWindows(self.contextSourceNode.contentRect, to: self.view)

                        func boundingRect(for views: [UIView]) -> CGRect {
                            var minX: CGFloat = .greatestFiniteMagnitude
                            var minY: CGFloat = .greatestFiniteMagnitude
                            var maxX: CGFloat = .leastNonzeroMagnitude
                            var maxY: CGFloat = .leastNonzeroMagnitude

                            for view in views {
                                let rect = view.frame
                                if rect.minX < minX {
                                    minX = rect.minX
                                }
                                if rect.minY < minY {
                                    minY = rect.minY
                                }
                                if rect.maxX > maxX {
                                    maxX = rect.maxX
                                }
                                if rect.maxY > maxY {
                                    maxY = rect.maxY
                                }
                            }
                            return CGRect(origin: CGPoint(x: minX, y: minY), size: CGSize(width: maxX - minX, height: maxY - minY))
                        }

                        let sourceBackgroundAbsoluteRect = boundingRect(for: snapshotViews)
                        let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.midX - self.contextSourceNode.contentRect.size.width / 2.0, y: sourceBackgroundAbsoluteRect.midY - self.contextSourceNode.contentRect.size.height / 2.0), size: self.contextSourceNode.contentRect.size)

                        self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)

                        self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                        self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)
                        self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNodeImpl.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.endAnimation()
                        })

                        combinedTransition.horizontal.animateTransformScale(node: self.contextSourceNode.contentNode, from: CGPoint(x: sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width, y: sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height))

                        var index = 0
                        for snapshotView in snapshotViews {
                            let targetContentRect = targetContentRects[index]
                            let targetAbsoluteContentRect = targetContentRect.offsetBy(dx: targetAbsoluteRect.minX, dy: targetAbsoluteRect.minY)
                            
                            snapshotView.center = targetAbsoluteContentRect.center.offsetBy(dx: -self.containerNode.frame.minX, dy: -self.containerNode.frame.minY)
                            self.containerNode.view.addSubview(snapshotView)
                        
                            combinedTransition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: CGPoint(x: 1.0 / (snapshotView.frame.width / targetContentRect.width), y: 1.0 / (snapshotView.frame.height / targetContentRect.height)))
                            
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            
                            index += 1
                        }
                        
                    }
                }
            }
        }

        private func endAnimation() {
            self.contextSourceNode.isExtractedToContextPreview = false
            self.contextSourceNode.isExtractedToContextPreviewUpdated?(false)
            
            self.animationEnded?()
        }

        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?) {
            var applyOffset = false
            if let itemNode = itemNode {
                if itemNode === self.itemNode {
                    applyOffset = true
                }
            } else {
                applyOffset = true
            }
            if applyOffset {
                if transition.isAnimated {
                    assert(true)
                }
                self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: -offset)
                transition.animateOffsetAdditive(node: self.scrollingContainer, offset: offset)
            }
        }

        func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
            var applyOffset = false
            if let itemNode = itemNode {
                if itemNode === self.itemNode {
                    applyOffset = true
                }
            } else {
                applyOffset = true
            }
            if applyOffset {
                self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset)
            }
        }
    }
    
    private final class MessageReactionContext {
        private(set) weak var itemNode: ListViewItemNode?
        private(set) weak var contextController: ContextController?
        private(set) weak var standaloneReactionAnimation: StandaloneReactionAnimation?
        
        var isEmpty: Bool {
            return self.contextController == nil && self.standaloneReactionAnimation == nil
        }
        
        init(itemNode: ListViewItemNode, contextController: ContextController?, standaloneReactionAnimation: StandaloneReactionAnimation?) {
            self.itemNode = itemNode
            self.contextController = contextController
            self.standaloneReactionAnimation = standaloneReactionAnimation
        }
        
        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?, isRotated: Bool) {
            guard let currentItemNode = self.itemNode else {
                return
            }
            if itemNode == nil || itemNode === currentItemNode {
                if let contextController = self.contextController {
                    contextController.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                    standaloneReactionAnimation.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
            }
        }

        func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
        }
        
        func dismiss() {
            if let contextController = self.contextController {
                contextController.cancelReactionAnimation()
                contextController.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak contextController] _ in
                    contextController?.dismissNow()
                })
            }
            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                standaloneReactionAnimation.cancel()
                standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                    standaloneReactionAnimation?.removeFromSupernode()
                })
            }
        }
    }

    private let listNode: ChatHistoryListNodeImpl
    private let getContentAreaInScreenSpace: () -> CGRect
    private let onTransitionEvent: (ContainedViewLayoutTransition) -> Void

    private var currentPendingItems: [Int64: (Source, () -> Void)] = [:]

    private var animatingItemNodes: [AnimatingItemNode] = []
    private var decorationItemNodes: [DecorationItemNodeImpl] = []
    private var messageReactionContexts: [MessageReactionContext] = []
    private var customOffsetHandlers: [CustomOffsetHandlerImpl] = []
    
    public let overlayContainerNode: ASDisplayNode

    var hasScheduledTransitions: Bool {
        return !self.currentPendingItems.isEmpty
    }

    var hasOngoingTransitions: Bool {
        return !self.animatingItemNodes.isEmpty
    }

    init(listNode: ChatHistoryListNodeImpl, getContentAreaInScreenSpace: @escaping () -> CGRect, onTransitionEvent: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.listNode = listNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace
        self.onTransitionEvent = onTransitionEvent
        self.overlayContainerNode = ASDisplayNode()

        super.init()

        self.listNode.animationCorrelationMessagesFound = { [weak self] itemNodeAndCorrelationIds in
            guard let strongSelf = self else {
                return
            }
            
            for (correlationId, itemNode) in itemNodeAndCorrelationIds {
                if let (currentSource, initiated) = strongSelf.currentPendingItems[correlationId] {
                    strongSelf.beginAnimation(itemNode: itemNode, source: currentSource)
                    initiated()
                }
            }
            
            if itemNodeAndCorrelationIds.count == strongSelf.currentPendingItems.count {
                strongSelf.currentPendingItems = [:]
            }
        }
    }

    func add(correlationId: Int64, source: Source, initiated: @escaping () -> Void) {
        self.currentPendingItems = [correlationId: (source, initiated)]
        self.listNode.setCurrentSendAnimationCorrelationIds(Set([correlationId]))
    }
    
    func add(grouped: [(correlationId: Int64, source: Source, initiated: () -> Void)]) {
        var currentPendingItems: [Int64: (Source, () -> Void)] = [:]
        var correlationIds = Set<Int64>()
        for (correlationId, source, initiated) in grouped {
            currentPendingItems[correlationId] = (source, initiated)
            correlationIds.insert(correlationId)
        }
        
        self.currentPendingItems = currentPendingItems
        self.listNode.setCurrentSendAnimationCorrelationIds(correlationIds)
    }
    
    public func add(decorationView: UIView, itemNode: ChatMessageItemNodeProtocol, aboveEverything: Bool) -> DecorationItemNode {
        let decorationItemNode = DecorationItemNodeImpl(itemNode: itemNode, contentView: decorationView, aboveEverything: aboveEverything, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)
        decorationItemNode.updateLayout(size: self.bounds.size)
       
        self.decorationItemNodes.append(decorationItemNode)
        self.addSubnode(decorationItemNode)
        
        return decorationItemNode
    }
    
    public func remove(decorationNode: DecorationItemNode) {
        self.decorationItemNodes.removeAll(where: { $0 === decorationNode })
        decorationNode.removeFromSupernode()
        if let decorationNode = decorationNode as? DecorationItemNodeImpl {
            decorationNode.overlayController?.dismiss()
        }
    }
    
    public func addCustomOffsetHandler(itemNode: ChatMessageItemNodeProtocol, update: @escaping (CGFloat, ContainedViewLayoutTransition) -> Bool) -> Disposable {
        let handler = CustomOffsetHandlerImpl(itemNode: itemNode, update: update)
        self.customOffsetHandlers.append(handler)
        
        return ActionDisposable { [weak self, weak handler] in
            Queue.mainQueue().async {
                guard let self, let handler else {
                    return
                }
                self.customOffsetHandlers.removeAll(where: { $0 === handler })
            }
        }
    }

    private func beginAnimation(itemNode: ChatMessageItemNodeProtocol, source: Source) {
        var contextSourceNode: ContextExtractedContentContainingNode?
        if let itemNode = itemNode as? ChatMessageBubbleItemNode {
            contextSourceNode = itemNode.mainContextSourceNode
        } else if let itemNode = itemNode as? ChatMessageStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        } else if let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        } else if let itemNode = itemNode as? ChatMessageInstantVideoItemNode {
            contextSourceNode = itemNode.contextSourceNode
        }

        if let contextSourceNode = contextSourceNode {
            let animatingItemNode = AnimatingItemNode(itemNode: itemNode, contextSourceNode: contextSourceNode, source: source, overlayContainerNode: self.overlayContainerNode, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)
            animatingItemNode.updateLayout(size: self.bounds.size)
            
            self.animatingItemNodes.append(animatingItemNode)
            switch source {
            // Voice messages animate inside the chat, as text does: the blob flies itself, above it.
            case .videoMessage, .mediaInput, .groupedMediaInput:
                let overlayController = OverlayTransitionContainerController()
                overlayController.displayNode.addSubnode(animatingItemNode)
                animatingItemNode.overlayController = overlayController
                self.listNode.context.sharedContext.mainWindow?.presentInGlobalOverlay(overlayController)
                animatingItemNode.frame = self.bounds
            default:
                animatingItemNode.frame = CGRect()
                itemNode.addSubnode(animatingItemNode)
            }

            animatingItemNode.animationEnded = { [weak self, weak animatingItemNode] in
                guard let strongSelf = self, let animatingItemNode = animatingItemNode else {
                    return
                }
                animatingItemNode.removeFromSupernode()
                animatingItemNode.overlayController?.dismiss()
                if let index = strongSelf.animatingItemNodes.firstIndex(where: { $0 === animatingItemNode }) {
                    strongSelf.animatingItemNodes.remove(at: index)
                }

                if animatingItemNode.updateAfterCompletion {
                    for message in animatingItemNode.itemNode.messages() {
                        strongSelf.listNode.requestMessageUpdate(stableId: message.stableId)
                        break
                    }
                }
            }

            animatingItemNode.beginAnimation()

            self.onTransitionEvent(.animated(duration: ChatMessageTransitionNodeImpl.animationDuration, curve: ChatMessageTransitionNodeImpl.verticalAnimationCurve))
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    private func removeEmptyMessageReactionContexts() {
        for i in (0 ..< self.messageReactionContexts.count).reversed() {
            if self.messageReactionContexts[i].isEmpty {
                self.messageReactionContexts.remove(at: i)
            }
        }
    }
    
    func dismissMessageReactionContexts(itemNode: ListViewItemNode? = nil) {
        for i in (0 ..< self.messageReactionContexts.count).reversed() {
            let messageReactionContext = self.messageReactionContexts[i]
            if itemNode == nil || messageReactionContext.itemNode === itemNode {
                self.messageReactionContexts.remove(at: i)
                messageReactionContext.dismiss()
            }
        }
    }
    
    func addMessageContextController(messageId: EngineMessage.Id, contextController: ContextController) {
        self.addMessageReactionContextContext(messageId: messageId, contextController: contextController, standaloneReactionAnimation: nil)
    }
    
    func addMessageStandaloneReactionAnimation(messageId: EngineMessage.Id, standaloneReactionAnimation: StandaloneReactionAnimation) {
        self.addMessageReactionContextContext(messageId: messageId, contextController: nil, standaloneReactionAnimation: standaloneReactionAnimation)
    }
    
    private func addMessageReactionContextContext(messageId: EngineMessage.Id, contextController: ContextController?, standaloneReactionAnimation: StandaloneReactionAnimation?) {
        self.removeEmptyMessageReactionContexts()
        
        var messageItemNode: ListViewItemNode?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemNodeProtocol {
                if itemNode.matchesMessage(id: messageId) {
                    messageItemNode = itemNode
                }
            }
        }
        
        if let messageItemNode = messageItemNode {
            for i in 0 ..< self.messageReactionContexts.count {
                if self.messageReactionContexts[i].itemNode === messageItemNode {
                    self.messageReactionContexts[i].dismiss()
                    self.messageReactionContexts.remove(at: i)
                    break
                }
            }
            self.messageReactionContexts.append(MessageReactionContext(itemNode: messageItemNode, contextController: contextController, standaloneReactionAnimation: standaloneReactionAnimation))
        }
    }

    func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?, isRotated: Bool) {
        /*for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode)
        }*/
        if itemNode == nil {
            for decorationItemNode in self.decorationItemNodes {
                decorationItemNode.addExternalOffset(offset: offset, transition: transition)
            }
            var removeCustomOffsetHandlers: [CustomOffsetHandlerImpl] = []
            for customOffsetHandler in self.customOffsetHandlers {
                if !customOffsetHandler.update(offset, transition) {
                    removeCustomOffsetHandlers.append(customOffsetHandler)
                }
            }
            for customOffsetHandler in removeCustomOffsetHandlers {
                self.customOffsetHandlers.removeAll(where: { $0 ===  customOffsetHandler})
            }
        }
        for messageReactionContext in self.messageReactionContexts {
            messageReactionContext.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode, isRotated: isRotated)
        }
    }

    func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
        /*for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addContentOffset(offset: offset, itemNode: itemNode)
        }*/
        if itemNode == nil {
            for decorationItemNode in self.decorationItemNodes {
                decorationItemNode.addContentOffset(offset: offset)
            }
            var removeCustomOffsetHandlers: [CustomOffsetHandlerImpl] = []
            for customOffsetHandler in self.customOffsetHandlers {
                if !customOffsetHandler.update(offset, .immediate) {
                    removeCustomOffsetHandlers.append(customOffsetHandler)
                }
            }
            for customOffsetHandler in removeCustomOffsetHandlers {
                self.customOffsetHandlers.removeAll(where: { $0 ===  customOffsetHandler})
            }
        }
        for messageReactionContext in self.messageReactionContexts {
            messageReactionContext.addContentOffset(offset: offset, itemNode: itemNode)
        }
    }

    func isAnimatingMessage(stableId: UInt32) -> Bool {
        for itemNode in self.animatingItemNodes {
            for message in itemNode.itemNode.messages() {
                if message.stableId == stableId {
                    return true
                }
            }
        }
        return false
    }

    func scheduleUpdateMessageAfterAnimationCompleted(stableId: UInt32) {
        for itemNode in self.animatingItemNodes {
            for message in itemNode.itemNode.messages() {
                if message.stableId == stableId {
                    itemNode.updateAfterCompletion = true
                }
            }
        }
    }

    func hasScheduledUpdateMessageAfterAnimationCompleted(stableId: UInt32) -> Bool {
        for itemNode in self.animatingItemNodes {
            for message in itemNode.itemNode.messages() {
                if message.stableId == stableId {
                    return itemNode.updateAfterCompletion
                }
            }
        }
        return false
    }
}
