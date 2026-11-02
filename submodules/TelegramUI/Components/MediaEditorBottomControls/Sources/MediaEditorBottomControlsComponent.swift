import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import PlainButtonComponent
import BundleIconComponent
import ContextReferenceButtonComponent

private let mediaEditorBottomControlsHighlightColor = UIColor(rgb: 0xffd300)
private let mediaEditorBottomControlsFadeDuration: Double = mediaEditorBottomControlsHandoffFadeDuration
private let mediaEditorBottomControlsBlurRadius: CGFloat = mediaEditorBottomControlsHandoffBlurRadius
private let mediaEditorBottomControlsDisabledAlpha: CGFloat = 0.2
private let mediaEditorBottomControlsCollapsedSide: CGFloat = 8.0
private let mediaEditorBottomControlsLabelFont = Font.with(size: 16.0, design: .round, weight: .semibold)

public final class MediaEditorBottomControlsComponent: Component {
    public let spec: MediaEditorBottomControlsLayoutSpec
    public let left: MediaEditorBottomControlsSideItem
    public let right: MediaEditorBottomControlsSideItem
    public let middle: [MediaEditorBottomControlsMiddleItem]
    public let selectedId: String?
    public let middleSpacing: CGFloat
    public let isHidden: Bool
    public let isMiddleEnabled: Bool
    public let areSideButtonsEnabled: Bool
    public let isRightEnabled: Bool
    public let areSideButtonsHidden: Bool
    public let contentAlpha: CGFloat
    public let infoString: String?
    public let leftPressed: () -> Void
    public let rightPressed: () -> Void
    public let rightLongPressed: ((UIView) -> Void)?
    public let customLayout: MediaEditorBottomControlsCustomLayout?
    public let middleFadesWhenEmpty: Bool

    public init(
        spec: MediaEditorBottomControlsLayoutSpec,
        left: MediaEditorBottomControlsSideItem,
        right: MediaEditorBottomControlsSideItem,
        middle: [MediaEditorBottomControlsMiddleItem],
        selectedId: String?,
        middleSpacing: CGFloat,
        isHidden: Bool,
        isMiddleEnabled: Bool,
        areSideButtonsEnabled: Bool,
        isRightEnabled: Bool,
        areSideButtonsHidden: Bool = false,
        contentAlpha: CGFloat = 1.0,
        infoString: String?,
        leftPressed: @escaping () -> Void,
        rightPressed: @escaping () -> Void,
        rightLongPressed: ((UIView) -> Void)?,
        customLayout: MediaEditorBottomControlsCustomLayout? = nil,
        middleFadesWhenEmpty: Bool = false
    ) {
        self.spec = spec
        self.left = left
        self.right = right
        self.middle = middle
        self.selectedId = selectedId
        self.middleSpacing = middleSpacing
        self.isHidden = isHidden
        self.isMiddleEnabled = isMiddleEnabled
        self.areSideButtonsEnabled = areSideButtonsEnabled
        self.isRightEnabled = isRightEnabled
        self.areSideButtonsHidden = areSideButtonsHidden
        self.contentAlpha = contentAlpha
        self.infoString = infoString
        self.leftPressed = leftPressed
        self.rightPressed = rightPressed
        self.rightLongPressed = rightLongPressed
        self.customLayout = customLayout
        self.middleFadesWhenEmpty = middleFadesWhenEmpty
    }

    public static func ==(lhs: MediaEditorBottomControlsComponent, rhs: MediaEditorBottomControlsComponent) -> Bool {
        if lhs.spec != rhs.spec || lhs.left != rhs.left || lhs.right != rhs.right || lhs.selectedId != rhs.selectedId || lhs.middleSpacing != rhs.middleSpacing {
            return false
        }
        if lhs.isHidden != rhs.isHidden || lhs.isMiddleEnabled != rhs.isMiddleEnabled || lhs.areSideButtonsEnabled != rhs.areSideButtonsEnabled || lhs.isRightEnabled != rhs.isRightEnabled || lhs.areSideButtonsHidden != rhs.areSideButtonsHidden {
            return false
        }
        if lhs.contentAlpha != rhs.contentAlpha || lhs.infoString != rhs.infoString || (lhs.rightLongPressed == nil) != (rhs.rightLongPressed == nil) {
            return false
        }
        if lhs.customLayout?.key != rhs.customLayout?.key || lhs.middleFadesWhenEmpty != rhs.middleFadesWhenEmpty {
            return false
        }
        if lhs.middle.count != rhs.middle.count {
            return false
        }
        for (l, r) in zip(lhs.middle, rhs.middle) {
            if l.id != r.id || l.isHighlighted != r.isHighlighted || l.isDisabled != r.isDisabled || l.tag !== r.tag || l.accessibilityLabel != r.accessibilityLabel || (l.longPress == nil) != (r.longPress == nil) {
                return false
            }
            if !mediaEditorBottomControlsSameContent(l.content, r.content) {
                return false
            }
        }
        return true
    }

    fileprivate struct ItemSpec {
        let id: String
        let button: AnyComponent<Empty>
        let height: CGFloat
        let alpha: CGFloat
        var accessibilityLabel: String? = nil
    }

    fileprivate final class Capsule {
        let containerView: UIView
        let glassView = GlassBackgroundView()
        let clipView = UIView()
        private(set) var itemViews: [String: ComponentView<Empty>] = [:]
        private(set) var itemOrder: [String] = []
        private var adoptedViews: [UIView] = []
        private var fadingViews: [UIView] = []
        private var holdsGlassHidden = false
        var anchorsContentToCentre = false
        private(set) var isGlassShown = true
        var isShown = false
        var firstShowScales = true
        var fadesWhenEmpty = false
        private var lastTintColor: GlassBackgroundView.TintColor = .init(kind: .panel)
        private var lastIsInteractive = false

        init(containerView: UIView) {
            self.containerView = containerView
            self.clipView.clipsToBounds = true
            containerView.addSubview(self.glassView)
            self.glassView.contentView.addSubview(self.clipView)
        }

        func itemView(id: String) -> UIView? {
            return self.itemViews[id]?.view
        }

        var orderedItemViews: [UIView] {
            return self.itemOrder.compactMap { self.itemViews[$0]?.view }
        }

        func update(
            items: [ItemSpec],
            layout: ([CGSize]) -> (capsuleFrame: CGRect?, itemFrames: [CGRect]),
            tintColor: GlassBackgroundView.TintColor,
            isInteractive: Bool,
            isVisible: Bool,
            alpha: CGFloat,
            transition: ComponentTransition,
            alphaTransition: ComponentTransition
        ) -> (capsuleFrame: CGRect?, itemFrames: [String: CGRect]) {
            let validIds = Set(items.map(\.id))
            var removedViews: [UIView] = self.adoptedViews
            self.adoptedViews = []
            for (id, itemView) in self.itemViews where !validIds.contains(id) {
                if let view = itemView.view {
                    removedViews.append(view)
                }
                self.itemViews.removeValue(forKey: id)
            }
            self.itemOrder = items.map(\.id)

            var newIds = Set<String>()
            var sizes: [CGSize] = []
            for item in items {
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemView = ComponentView<Empty>()
                    self.itemViews[item.id] = itemView
                    newIds.insert(item.id)
                }
                let size = itemView.update(
                    transition: newIds.contains(item.id) ? .immediate : transition,
                    component: item.button,
                    environment: {},
                    containerSize: CGSize(width: 1000.0, height: item.height)
                )
                sizes.append(size)
            }

            self.lastTintColor = tintColor
            self.lastIsInteractive = isInteractive
            let (capsuleFrame, frames) = layout(sizes)
            let oldOrigin = self.containerView.center.offsetBy(dx: -self.containerView.bounds.width * 0.5, dy: -self.containerView.bounds.height * 0.5)
            let oldSize = self.containerView.bounds.size
            let anchorsContentToCentre = self.anchorsContentToCentre
            self.anchorsContentToCentre = false

            guard let capsuleFrame else {
                self.hide(removedViews: removedViews, tintColor: tintColor, transition: transition, alphaTransition: alphaTransition)
                return (nil, [:])
            }

            let wasShown = self.isShown
            self.isShown = true
            let containerTransition: ComponentTransition = wasShown ? transition : .immediate
            containerTransition.setPosition(view: self.containerView, position: capsuleFrame.center)
            containerTransition.setBounds(view: self.containerView, bounds: CGRect(origin: .zero, size: capsuleFrame.size))
            containerTransition.setFrame(view: self.glassView, frame: CGRect(origin: .zero, size: capsuleFrame.size))
            let revealsGlass = !wasShown && self.fadesWhenEmpty && !transition.animation.isImmediate
            self.glassView.update(size: capsuleFrame.size, cornerRadius: mediaEditorBottomControlsCapsuleCornerRadius(capsuleFrame.size), isDark: true, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible && !self.holdsGlassHidden, transition: revealsGlass ? transition : containerTransition)
            self.isGlassShown = isVisible && !self.holdsGlassHidden
            containerTransition.setFrame(view: self.clipView, frame: CGRect(origin: .zero, size: capsuleFrame.size))
            containerTransition.setCornerRadius(layer: self.clipView.layer, cornerRadius: mediaEditorBottomControlsCapsuleCornerRadius(capsuleFrame.size))
            if !wasShown {
                if transition.animation.isImmediate || self.fadesWhenEmpty {
                    ComponentTransition.immediate.setScale(view: self.containerView, scale: 1.0)
                    self.containerView.alpha = alpha
                } else if !self.firstShowScales {
                    ComponentTransition.immediate.setScale(view: self.containerView, scale: 1.0)
                    self.containerView.alpha = 0.0
                    alphaTransition.setAlpha(view: self.containerView, alpha: alpha)
                    alphaTransition.animateBlur(layer: self.containerView.layer, fromRadius: mediaEditorBottomControlsBlurRadius, toRadius: 0.0)
                } else {
                    ComponentTransition.immediate.setScale(view: self.containerView, scale: 0.001)
                    transition.setScale(view: self.containerView, scale: 1.0)
                    self.containerView.alpha = 0.0
                    alphaTransition.setAlpha(view: self.containerView, alpha: alpha)
                }
            } else {
                transition.setScale(view: self.containerView, scale: 1.0)
                alphaTransition.setAlpha(view: self.containerView, alpha: alpha)
            }

            for view in removedViews {
                if wasShown {
                    if anchorsContentToCentre {
                        transition.setFrame(view: view, frame: mediaEditorBottomControlsCentreAnchoredFrame(view.frame, fromCapsuleSize: oldSize, toCapsuleSize: capsuleFrame.size))
                    } else {
                        transition.setFrame(view: view, frame: mediaEditorBottomControlsScreenStableFrame(view.frame, fromCapsuleOrigin: oldOrigin, toCapsuleOrigin: capsuleFrame.origin))
                    }
                }
                self.fadeOut(view: view, alphaTransition: alphaTransition)
            }

            var result: [String: CGRect] = [:]
            for (index, item) in items.enumerated() {
                guard index < frames.count, let view = self.itemViews[item.id]?.view else {
                    continue
                }
                let localFrame = frames[index].offsetBy(dx: -capsuleFrame.minX, dy: -capsuleFrame.minY)
                result[item.id] = localFrame
                if view.superview == nil {
                    self.clipView.addSubview(view)
                }
                if let accessibilityLabel = item.accessibilityLabel {
                    view.isAccessibilityElement = true
                    view.accessibilityLabel = accessibilityLabel
                    view.accessibilityTraits = .button
                }
                if newIds.contains(item.id) {
                    if wasShown {
                        if anchorsContentToCentre {
                            view.frame = mediaEditorBottomControlsCentreAnchoredFrame(localFrame, fromCapsuleSize: capsuleFrame.size, toCapsuleSize: oldSize)
                        } else {
                            view.frame = mediaEditorBottomControlsScreenStableFrame(localFrame, fromCapsuleOrigin: capsuleFrame.origin, toCapsuleOrigin: oldOrigin)
                        }
                        transition.setFrame(view: view, frame: localFrame)
                    } else {
                        view.frame = localFrame
                    }
                    if alphaTransition.animation.isImmediate {
                        view.alpha = item.alpha
                    } else {
                        view.alpha = 0.0
                        alphaTransition.setAlpha(view: view, alpha: item.alpha)
                        alphaTransition.animateBlur(layer: view.layer, fromRadius: mediaEditorBottomControlsBlurRadius, toRadius: 0.0)
                    }
                } else {
                    transition.setFrame(view: view, frame: localFrame)
                    alphaTransition.setAlpha(view: view, alpha: item.alpha)
                }
            }
            return (capsuleFrame, result)
        }

        var restingFrame: CGRect {
            let size = self.containerView.bounds.size
            return CGRect(origin: CGPoint(x: self.containerView.center.x - size.width * 0.5, y: self.containerView.center.y - size.height * 0.5), size: size)
        }

        func adopt(frame: CGRect, hasGlass: Bool, contentViews: [UIView]) {
            for view in self.adoptedViews {
                view.removeFromSuperview()
            }
            for (_, itemView) in self.itemViews {
                itemView.view?.removeFromSuperview()
            }
            self.itemViews.removeAll()
            self.itemOrder = []

            let bounds = CGRect(origin: .zero, size: frame.size)
            self.containerView.layer.removeAllAnimations()
            ComponentTransition.immediate.setScale(view: self.containerView, scale: 1.0)
            self.containerView.alpha = 1.0
            self.containerView.center = frame.center
            self.containerView.bounds = bounds
            self.glassView.frame = bounds
            self.glassView.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: false, isVisible: hasGlass, transition: .immediate)
            self.isGlassShown = hasGlass
            self.clipView.frame = bounds
            self.clipView.layer.cornerRadius = frame.height * 0.5
            for view in contentViews {
                self.clipView.addSubview(view)
            }
            self.adoptedViews = contentViews
            self.isShown = true
            self.anchorsContentToCentre = true
        }

        func cancelGlassHold() {
            self.holdsGlassHidden = false
        }

        func restoreGlassAfterAppearance(transition: ComponentTransition) {
            guard self.holdsGlassHidden else {
                return
            }
            self.holdsGlassHidden = false
            let size = self.containerView.bounds.size
            self.glassView.update(size: size, cornerRadius: mediaEditorBottomControlsCapsuleCornerRadius(size), isDark: true, tintColor: self.lastTintColor, isInteractive: self.lastIsInteractive, isVisible: true, transition: transition)
            self.isGlassShown = true
        }

        func hideGlassForAppearance() {
            self.holdsGlassHidden = true
            let size = self.containerView.bounds.size
            self.glassView.update(size: size, cornerRadius: mediaEditorBottomControlsCapsuleCornerRadius(size), isDark: true, tintColor: self.lastTintColor, isInteractive: false, isVisible: false, transition: .immediate)
            self.isGlassShown = false
        }

        func handBack(to frame: CGRect, hasGlass: Bool, transition: ComponentTransition, alphaTransition: ComponentTransition) {
            let oldSize = self.containerView.bounds.size
            let bounds = CGRect(origin: .zero, size: frame.size)
            transition.setPosition(view: self.containerView, position: frame.center)
            transition.setBounds(view: self.containerView, bounds: bounds)
            transition.setFrame(view: self.glassView, frame: bounds)
            self.glassView.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: false, isVisible: hasGlass, transition: transition)
            self.isGlassShown = hasGlass
            transition.setFrame(view: self.clipView, frame: bounds)
            transition.setCornerRadius(layer: self.clipView.layer, cornerRadius: frame.height * 0.5)
            let takenOver = self.fadingViews
            self.fadingViews = []
            for view in self.orderedItemViews + self.adoptedViews + takenOver {
                transition.setFrame(view: view, frame: mediaEditorBottomControlsCentreAnchoredFrame(view.frame, fromCapsuleSize: oldSize, toCapsuleSize: frame.size))
                mediaEditorFadeWithBlur(view: view, isIn: false, duration: alphaTransition.animation.isImmediate ? 0.0 : mediaEditorBottomControlsFadeDuration)
            }
            for view in takenOver {
                DispatchQueue.main.asyncAfter(deadline: .now() + mediaEditorBottomControlsFadeDuration * max(1.0, UIView.animationDurationFactor()), execute: { [weak view] in
                    view?.removeFromSuperview()
                })
            }
        }

        private func hide(removedViews: [UIView], tintColor: GlassBackgroundView.TintColor, transition: ComponentTransition, alphaTransition: ComponentTransition) {
            for view in removedViews {
                self.fadeOut(view: view, alphaTransition: alphaTransition)
            }
            guard self.isShown else {
                return
            }
            self.isShown = false
            if self.fadesWhenEmpty {
                self.firstShowScales = false
                let size = self.containerView.bounds.size
                self.glassView.update(size: size, cornerRadius: mediaEditorBottomControlsCapsuleCornerRadius(size), isDark: true, tintColor: tintColor, isInteractive: false, isVisible: false, transition: transition)
                self.isGlassShown = false
                return
            }
            let collapsedSize = CGSize(width: mediaEditorBottomControlsCollapsedSide, height: mediaEditorBottomControlsCollapsedSide)
            let collapsedBounds = CGRect(origin: .zero, size: collapsedSize)
            transition.setFrame(view: self.glassView, frame: collapsedBounds)
            self.glassView.update(size: collapsedSize, cornerRadius: collapsedSize.height * 0.5, isDark: true, tintColor: tintColor, isInteractive: false, isVisible: true, transition: transition)
            self.isGlassShown = true
            transition.setFrame(view: self.clipView, frame: collapsedBounds)
            transition.setCornerRadius(layer: self.clipView.layer, cornerRadius: collapsedSize.height * 0.5)
            transition.setBounds(view: self.containerView, bounds: collapsedBounds, completion: { [weak self] _ in
                guard let self, !self.isShown else {
                    return
                }
                self.containerView.alpha = 0.0
            })
        }

        private func fadeOut(view: UIView, alphaTransition: ComponentTransition) {
            if alphaTransition.animation.isImmediate {
                view.removeFromSuperview()
                return
            }
            self.fadingViews.append(view)
            alphaTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                guard let self, let view, self.fadingViews.contains(where: { $0 === view }) else {
                    return
                }
                view.removeFromSuperview()
                self.fadingViews.removeAll(where: { $0 === view })
            })
            alphaTransition.animateBlur(layer: view.layer, fromRadius: 0.0, toRadius: mediaEditorBottomControlsBlurRadius, removeOnCompletion: false)
        }
    }

    public final class View: UIView {
        private let glassContainerView = GlassBackgroundContainerView()
        private let leftCapsule: Capsule
        private let middleCapsule: Capsule
        private let rightSourceView = ContextControllerSourceView()
        private let rightCapsule: Capsule
        private let selectionView = UIView()
        private let infoLabel = UILabel()
        private var coloredImages: [String: UIImage] = [:]
        private var isSelectionShown = false

        private var component: MediaEditorBottomControlsComponent?
        private var lastAvailableSize: CGSize?
        private var pendingHandoffs: [(MediaEditorBottomControlsHandoff, Bool)] = []
        private var isHandedBack = false
        var testCoordinateRoot: UIView?

        private var coordinateRoot: UIView? {
            return self.window ?? self.testCoordinateRoot
        }

        override public init(frame: CGRect) {
            self.leftCapsule = Capsule(containerView: UIView())
            self.middleCapsule = Capsule(containerView: UIView())
            self.rightCapsule = Capsule(containerView: self.rightSourceView)

            super.init(frame: frame)

            self.addSubview(self.glassContainerView)
            self.glassContainerView.contentView.addSubview(self.leftCapsule.containerView)
            self.glassContainerView.contentView.addSubview(self.middleCapsule.containerView)
            self.glassContainerView.contentView.addSubview(self.rightCapsule.containerView)

            self.selectionView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.15)
            self.selectionView.isUserInteractionEnabled = false
            self.selectionView.alpha = 0.0
            self.middleCapsule.glassView.contentView.insertSubview(self.selectionView, at: 0)

            self.middleCapsule.containerView.alpha = 0.0
            self.middleCapsule.containerView.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)

            self.infoLabel.backgroundColor = .clear
            self.infoLabel.textAlignment = .center
            self.infoLabel.textColor = .white
            self.infoLabel.font = Font.regular(13.0)
            self.infoLabel.isUserInteractionEnabled = false
            self.addSubview(self.infoLabel)

            self.rightSourceView.beginDelay = 0.4
            self.rightSourceView.targetViewForActivationProgress = self.rightCapsule.glassView
            self.rightSourceView.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component, let rightLongPressed = component.rightLongPressed else {
                    gesture.cancel()
                    return
                }
                rightLongPressed(self.rightSourceView)
            }
            self.rightSourceView.shouldBegin = { [weak self] _ in
                guard let self, let component = self.component else {
                    return false
                }
                return component.rightLongPressed != nil && component.isRightEnabled && component.areSideButtonsEnabled && !component.isHidden
            }
        }

        required public init?(coder: NSCoder) {
            preconditionFailure()
        }

        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self {
                return nil
            }
            return result
        }

        public var middleCapsuleView: UIView {
            return self.middleCapsule.containerView
        }

        public var leftCapsuleView: UIView {
            return self.leftCapsule.containerView
        }

        public var rightCapsuleView: UIView {
            return self.rightCapsule.containerView
        }

        var rightCapsuleIsGlassVisible: Bool {
            return self.rightCapsule.isGlassShown
        }

        public var leftButtonView: UIView? {
            return self.leftCapsule.orderedItemViews.first
        }

        public var rightButtonView: UIView? {
            return self.rightCapsule.orderedItemViews.first
        }

        public var middleItemViews: [UIView] {
            return self.middleCapsule.orderedItemViews
        }

        public func adopt(_ handoff: MediaEditorBottomControlsHandoff, reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled) {
            self.pendingHandoffs.append((handoff, reduceMotion))
            self.setNeedsLayout()
            self.runPendingHandoffIfReady()
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            self.runPendingHandoffIfReady()
        }

        override public func didMoveToWindow() {
            super.didMoveToWindow()
            self.setNeedsLayout()
        }

        private func runPendingHandoffIfReady() {
            guard !self.pendingHandoffs.isEmpty, !self.isHandedBack, let coordinateRoot = self.coordinateRoot, let component = self.component, let availableSize = self.lastAvailableSize else {
                return
            }
            let handoffs = self.pendingHandoffs
            self.pendingHandoffs = []
            guard let (handoff, reduceMotion) = handoffs.last else {
                return
            }
            let slots: [(Capsule, MediaEditorBottomControlsHandoff.Slot?)] = [
                (self.leftCapsule, handoff.left),
                (self.middleCapsule, handoff.middle),
                (self.rightCapsule, handoff.right)
            ]
            var inPlace: [UIView] = []
            var inPlaceCapsules: [Capsule] = []
            let plans = slots.map { capsule, slot in
                mediaEditorBottomControlsHandoffSlotPlan(source: slot.map { self.convert($0.frame, from: coordinateRoot) }, target: capsule.restingFrame, reduceMotion: reduceMotion)
            }
            let appearsAsWhole = !plans.contains(where: { plan in
                if case .morph = plan {
                    return true
                }
                return false
            })
            for ((capsule, slot), plan) in zip(slots, plans) {
                capsule.firstShowScales = false
                switch plan {
                case let .morph(from):
                    capsule.adopt(frame: from, hasGlass: slot?.hasGlass ?? true, contentViews: slot?.contentViews ?? [])
                case .inPlace:
                    if capsule.isShown && !appearsAsWhole {
                        capsule.hideGlassForAppearance()
                        inPlace.append(capsule.containerView)
                        inPlaceCapsules.append(capsule)
                    }
                }
            }
            if appearsAsWhole {
                self.layer.animateAlpha(from: 0.0, to: self.alpha, duration: mediaEditorBottomControlsFadeDuration, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                ComponentTransition.animateTransientBlur(layer: self.layer, fromRadius: mediaEditorBottomControlsBlurRadius, toRadius: 0.0, duration: mediaEditorBottomControlsFadeDuration)
            }
            self.isSelectionShown = false
            self.selectionView.alpha = 0.0

            let _ = self.apply(component: component, availableSize: availableSize, transition: .spring(duration: mediaEditorBottomControlsHandoffMoveDuration))
            for view in inPlace {
                mediaEditorFadeWithBlur(view: view, isIn: true)
            }
            if !inPlaceCapsules.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + mediaEditorBottomControlsFadeDuration * 0.5, execute: {
                    for capsule in inPlaceCapsules {
                        capsule.restoreGlassAfterAppearance(transition: .easeInOut(duration: mediaEditorBottomControlsFadeDuration))
                    }
                })
            }
            DispatchQueue.main.async {
                for (handoff, _) in handoffs {
                    handoff.didAdopt()
                }
            }
        }

        public func handBack(_ handBack: MediaEditorBottomControlsHandBack, reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled) {
            self.isHandedBack = true
            for capsule in [self.leftCapsule, self.middleCapsule, self.rightCapsule] {
                capsule.cancelGlassHold()
            }
            self.pendingHandoffs = []
            self.isUserInteractionEnabled = false
            let transition: ComponentTransition = .spring(duration: mediaEditorBottomControlsHandoffMoveDuration)
            let alphaTransition: ComponentTransition = .easeInOut(duration: mediaEditorBottomControlsHandoffFadeDuration)
            let targets: [(Capsule, MediaEditorBottomControlsHandBack.Target?)] = [
                (self.leftCapsule, handBack.left),
                (self.middleCapsule, handBack.middle),
                (self.rightCapsule, handBack.right)
            ]
            for (capsule, target) in targets {
                let current = capsule.restingFrame
                let frame = target.map { self.convert($0.frame, from: self.coordinateRoot) }
                switch mediaEditorBottomControlsHandoffSlotPlan(source: frame, target: current, reduceMotion: reduceMotion) {
                case let .morph(from):
                    capsule.handBack(to: from, hasGlass: target?.hasGlass ?? true, transition: transition, alphaTransition: alphaTransition)
                    let glassView = capsule.glassView
                    let glassSize = from.size
                    DispatchQueue.main.asyncAfter(deadline: .now() + mediaEditorBottomControlsHandoffMoveDuration - mediaEditorBottomControlsHandBackGlassFadeDuration, execute: { [weak glassView] in
                        glassView?.update(size: glassSize, cornerRadius: glassSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), isInteractive: false, isVisible: false, transition: .easeInOut(duration: mediaEditorBottomControlsHandBackGlassFadeDuration))
                    })
                case .inPlace:
                    mediaEditorFadeWithBlur(view: capsule.containerView, isIn: false)
                }
            }
            alphaTransition.setAlpha(view: self.selectionView, alpha: 0.0)
            alphaTransition.setAlpha(view: self.infoLabel, alpha: 0.0)
        }

        public func animateOutAsWhole(duration: Double) {
            self.layer.animateAlpha(from: self.alpha, to: 0.0, duration: duration, removeOnCompletion: false)
            ComponentTransition.easeInOut(duration: duration).animateBlur(layer: self.layer, fromRadius: 0.0, toRadius: mediaEditorBottomControlsBlurRadius, removeOnCompletion: false)
        }

        public var selectionPillView: UIView {
            return self.selectionView
        }

        public var rightButtonSourceView: UIView {
            return self.rightSourceView
        }

        public func rightButtonFrame(in coordinateView: UIView?) -> CGRect? {
            guard self.rightSourceView.superview != nil else {
                return nil
            }
            return self.rightSourceView.convert(self.rightSourceView.bounds, to: coordinateView)
        }

        public func middleItemView(id: String) -> UIView? {
            return self.middleCapsule.itemView(id: id)
        }

        public func middleItemFrame(id: String, in coordinateView: UIView?) -> CGRect? {
            guard let view = self.middleCapsule.itemView(id: id), view.superview != nil else {
                return nil
            }
            return view.convert(view.bounds, to: coordinateView)
        }

        private func coloredImage(key: String, color: UIColor, generate: (UIColor) -> UIImage?) -> UIImage? {
            let cacheKey = "\(key)-\(color.argb)"
            if let image = self.coloredImages[cacheKey] {
                return image
            }
            let image = generate(color)
            self.coloredImages[cacheKey] = image
            return image
        }

        private func sideItemSpec(_ item: MediaEditorBottomControlsSideItem, side: CGFloat, isEnabled: Bool, action: @escaping () -> Void) -> ItemSpec {
            let content: AnyComponent<Empty>
            var insets = UIEdgeInsets()
            switch item.content {
            case let .icon(name, flipped):
                content = AnyComponent(BundleIconComponent(name: name, tintColor: .white, flipHorizontally: flipped))
            case let .label(text, icon):
                var stackItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: text, font: mediaEditorBottomControlsLabelFont, color: .white)))
                ]
                if let icon {
                    stackItems.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: icon, tintColor: .white))))
                }
                content = AnyComponent(HStack(stackItems, spacing: 5.0))
                insets = UIEdgeInsets(top: 0.0, left: mediaEditorBottomControlsLabelHorizontalPadding * 0.5, bottom: 0.0, right: mediaEditorBottomControlsLabelHorizontalPadding * 0.5)
            }
            return ItemSpec(
                id: item.id,
                button: AnyComponent(PlainButtonComponent(
                    content: content,
                    minSize: CGSize(width: item.width ?? side, height: side),
                    contentInsets: insets,
                    action: action,
                    isEnabled: isEnabled,
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                height: side,
                alpha: 1.0,
                accessibilityLabel: item.accessibilityLabel
            )
        }

        private func tintColor(_ tint: MediaEditorBottomControlsSideItem.Tint) -> GlassBackgroundView.TintColor {
            switch tint {
            case .panel:
                return .init(kind: .panel)
            case let .accent(color):
                return .init(kind: .custom(style: .default, color: color))
            }
        }

        public func update(component: MediaEditorBottomControlsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.isHandedBack {
                self.component = component
                return availableSize
            }
            let result = self.apply(component: component, availableSize: availableSize, transition: transition)
            if !self.pendingHandoffs.isEmpty {
                self.setNeedsLayout()
            }
            return result
        }

        private func apply(component: MediaEditorBottomControlsComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let isFirstUpdate = self.component == nil
            self.component = component
            self.lastAvailableSize = availableSize
            let transition: ComponentTransition = isFirstUpdate ? .immediate : transition
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: mediaEditorBottomControlsFadeDuration)

            transition.setFrame(view: self.glassContainerView, frame: CGRect(origin: .zero, size: availableSize))
            self.glassContainerView.update(size: availableSize, isDark: true, transition: transition)

            let width = availableSize.width
            let spec = component.spec
            let customLayout = component.customLayout
            let side = spec.buttonSide
            let contentAlpha = component.contentAlpha
            let sidesHidden = component.isHidden || component.areSideButtonsHidden
            let sideAlpha: CGFloat = (sidesHidden ? 0.0 : 1.0) * contentAlpha
            let sideEnabled = component.areSideButtonsEnabled && !sidesHidden

            var leftWidth = side
            let _ = self.leftCapsule.update(
                items: [self.sideItemSpec(component.left, side: side, isEnabled: sideEnabled, action: { [weak self] in
                    self?.component?.leftPressed()
                })],
                layout: { sizes in
                    leftWidth = sizes.first?.width ?? side
                    let layout = customLayout.map { $0.layout(availableSize, [], leftWidth, side) } ?? mediaEditorBottomControlsLocalLayout(width: width, spec: spec, middleItemWidths: [], middleSpacing: 0.0, leftWidth: leftWidth, rightWidth: side)
                    return (layout.leftFrame, [layout.leftFrame])
                },
                tintColor: self.tintColor(component.left.tint),
                isInteractive: sideEnabled,
                isVisible: !sidesHidden,
                alpha: sideAlpha,
                transition: transition,
                alphaTransition: alphaTransition
            )
            self.leftCapsule.containerView.isUserInteractionEnabled = sideEnabled

            let rightEnabled = sideEnabled && component.isRightEnabled
            var rightWidth = side
            let _ = self.rightCapsule.update(
                items: [self.sideItemSpec(component.right, side: side, isEnabled: rightEnabled, action: { [weak self] in
                    self?.component?.rightPressed()
                })],
                layout: { sizes in
                    rightWidth = sizes.first?.width ?? side
                    let layout = customLayout.map { $0.layout(availableSize, [], leftWidth, rightWidth) } ?? mediaEditorBottomControlsLocalLayout(width: width, spec: spec, middleItemWidths: [], middleSpacing: 0.0, leftWidth: leftWidth, rightWidth: rightWidth)
                    return (layout.rightFrame, [layout.rightFrame])
                },
                tintColor: self.tintColor(component.right.tint),
                isInteractive: rightEnabled,
                isVisible: !sidesHidden,
                alpha: sideAlpha * (component.isRightEnabled ? 1.0 : mediaEditorBottomControlsDisabledAlpha),
                transition: transition,
                alphaTransition: alphaTransition
            )
            self.rightSourceView.isUserInteractionEnabled = rightEnabled
            self.rightSourceView.isGestureEnabled = component.rightLongPressed != nil && rightEnabled

            let middleItems = component.middle.map { item -> ItemSpec in
                let isSelected = item.id == component.selectedId
                let color: UIColor
                if isSelected {
                    color = .white
                } else if item.isHighlighted && !item.isDisabled {
                    color = mediaEditorBottomControlsHighlightColor
                } else {
                    color = .white
                }
                let content: AnyComponent<Empty>
                var contentInsets = UIEdgeInsets()
                switch item.content {
                case let .icon(name):
                    content = AnyComponent(BundleIconComponent(name: name, tintColor: color, maxSize: CGSize(width: 28.0, height: 28.0)))
                case let .image(image, size):
                    content = AnyComponent(Image(image: image, size: size, contentMode: .center))
                case let .coloredImage(key, size, generate):
                    content = AnyComponent(Image(image: self.coloredImage(key: key, color: color, generate: generate), size: size, contentMode: .center))
                case let .text(text, font, horizontalInset):
                    content = AnyComponent(Text(text: text, font: font, color: color))
                    contentInsets = UIEdgeInsets(top: 0.0, left: horizontalInset, bottom: 0.0, right: horizontalInset)
                case let .custom(customContent):
                    content = customContent
                }
                let isEnabled = component.isMiddleEnabled && !item.isDisabled
                let button: AnyComponent<Empty>
                if let longPress = item.longPress {
                    let action = item.action
                    button = AnyComponent(ContextReferenceButtonComponent(
                        content: content,
                        tag: item.tag,
                        minSize: CGSize(width: side, height: side),
                        action: { view, gesture in
                            guard isEnabled else {
                                return
                            }
                            if let gesture {
                                longPress(view, gesture)
                            } else {
                                action()
                            }
                        }
                    ))
                } else {
                    button = AnyComponent(PlainButtonComponent(
                        content: content,
                        minSize: CGSize(width: side, height: side),
                        contentInsets: contentInsets,
                        action: item.action,
                        isEnabled: isEnabled,
                        animateAlpha: true,
                        animateScale: false,
                        animateContents: false,
                        tag: item.tag
                    ))
                }
                return ItemSpec(id: item.id, button: button, height: side, alpha: item.isDisabled ? mediaEditorBottomControlsDisabledAlpha : 1.0, accessibilityLabel: item.accessibilityLabel)
            }
            let middleVisible = !component.isHidden && !middleItems.isEmpty
            let middleSpacing = component.middleSpacing
            self.middleCapsule.fadesWhenEmpty = component.middleFadesWhenEmpty
            let middleResult = self.middleCapsule.update(
                items: middleItems,
                layout: { sizes in
                    let layout = customLayout.map { $0.layout(availableSize, sizes.map(\.width), leftWidth, rightWidth) } ?? mediaEditorBottomControlsLocalLayout(width: width, spec: spec, middleItemWidths: sizes.map(\.width), middleSpacing: middleSpacing, leftWidth: leftWidth, rightWidth: rightWidth)
                    return (layout.middleFrame, layout.itemFrames)
                },
                tintColor: .init(kind: .panel),
                isInteractive: middleVisible && component.isMiddleEnabled,
                isVisible: middleVisible,
                alpha: component.isHidden ? 0.0 : (component.isMiddleEnabled ? 1.0 : mediaEditorBottomControlsDisabledAlpha) * contentAlpha,
                transition: transition,
                alphaTransition: alphaTransition
            )
            self.middleCapsule.containerView.isUserInteractionEnabled = middleVisible && component.isMiddleEnabled

            self.updateSelection(selectedId: component.selectedId, capsuleFrame: middleResult.capsuleFrame, itemFrames: middleResult.itemFrames, isHidden: component.isHidden, transition: transition, alphaTransition: alphaTransition)

            if let infoString = component.infoString {
                self.infoLabel.text = infoString
            }
            alphaTransition.setAlpha(view: self.infoLabel, alpha: component.infoString == nil ? 0.0 : 1.0)
            let infoInset = side + 10.0
            transition.setFrame(view: self.infoLabel, frame: CGRect(x: infoInset, y: 0.0, width: max(0.0, availableSize.width - infoInset * 2.0), height: side))

            return availableSize
        }

        private func updateSelection(selectedId: String?, capsuleFrame: CGRect?, itemFrames: [String: CGRect], isHidden: Bool, transition: ComponentTransition, alphaTransition: ComponentTransition) {
            guard let selectedId, capsuleFrame != nil, let itemFrame = itemFrames[selectedId] else {
                self.isSelectionShown = false
                alphaTransition.setAlpha(view: self.selectionView, alpha: 0.0)
                return
            }
            let frame = mediaEditorBottomControlsSelectionFrame(itemFrame: itemFrame)
            let selectionTransition: ComponentTransition = self.isSelectionShown ? transition : .immediate
            self.isSelectionShown = true
            selectionTransition.setFrame(view: self.selectionView, frame: frame)
            selectionTransition.setCornerRadius(layer: self.selectionView.layer, cornerRadius: frame.height * 0.5)
            alphaTransition.setAlpha(view: self.selectionView, alpha: isHidden ? 0.0 : 1.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
