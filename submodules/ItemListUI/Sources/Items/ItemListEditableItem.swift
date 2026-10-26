import Foundation
import UIKit
import Display
import AsyncDisplayKit

public final class ItemListRevealOptionsGestureRecognizer: UIPanGestureRecognizer {
    public var validatedGesture = false
    public var firstLocation: CGPoint = CGPoint()
    
    public var allowAnyDirection = false
    public var lastVelocity: CGPoint = CGPoint()
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        if #available(iOS 13.4, *) {
            self.allowedScrollTypesMask = .continuous
        }
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
    }
    
    public func becomeCancelled() {
        self.state = .cancelled
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        if !self.validatedGesture {
            if !self.allowAnyDirection && translation.x > 0.0 {
                self.state = .failed
            } else if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                self.state = .failed
            } else if abs(translation.x) > 4.0 && abs(translation.y) * 2.5 < abs(translation.x) {
                self.validatedGesture = true
            }
        }
        
        if self.validatedGesture {
            self.lastVelocity = self.velocity(in: self.view)
            super.touchesMoved(touches, with: event)
        }
    }
}

open class ItemListRevealOptionsItemNode: ListViewItemNode, ASGestureRecognizerDelegate {
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private var leftRevealNode: ItemListRevealOptionsNode?
    private var rightRevealNode: ItemListRevealOptionsNode?
    private var revealOptions: (left: [ItemListRevealOption], right: [ItemListRevealOption]) = ([], [])
    private var enableAnimations: Bool = true
    
    private var motion = ItemListRevealMotion()
    private var revealDirection: CGFloat = -1.0
    private var animationLink: SharedDisplayLinkDriver.Link?
    private var previousAnimationTime: CFTimeInterval = 0
    private var animationCompletion: (() -> Void)?
    private var suppressGestureEvents = false
    private var deliveringAction = false
    private var lastSurfaceProgress: CGFloat = 0
    public private(set) var revealOffset: CGFloat = 0.0
    public private(set) var isRevealOptionsActive: Bool = false
    public private(set) var isNextRevealOptionsActive: Bool = false
    public private(set) var revealOptionsSeparatorAlpha: CGFloat = 1.0
    public private(set) var nextRevealOptionsSeparatorAlpha: CGFloat = 1.0
    private weak var revealOptionsActivePreviousItemNode: ItemListRevealOptionsItemNode?

    private weak var revealOptionsTopSeparatorNode: ASDisplayNode?
    private weak var revealOptionsBottomSeparatorNode: ASDisplayNode?
    private var revealOptionsTopSeparatorBaseIsHidden: Bool = false
    private var revealOptionsBottomSeparatorBaseIsHidden: Bool = false
    private var revealOptionsTopSeparatorHiddenByPreviousRevealOptions: Bool = false
    private var revealOptionsBottomSeparatorHiddenByNextRevealOptions: Bool = false

    private weak var revealOptionsHighlightedBackgroundNode: ASDisplayNode?
    private var revealOptionsHighlightedBackgroundBaseFrame: CGRect?
    private var revealOptionsHighlightedBackgroundTracksRevealOffset: Bool = false
    private var revealOptionsHighlightedBackgroundActiveCornerRadius: CGFloat = 0.0

    private var revealOptionsAllowsHighlight = true
    private var revealOptionsBaseHighlightAlpha: CGFloat = 0
    private var selectionHighlightEndTime: CFTimeInterval = 0
    private var highlightFadeGeneration = 0
    private weak var revealOptionsHighlightAnchor: ASDisplayNode?
    private var recognizer: ItemListRevealTouchGestureRecognizer?
    private var scrollRecognizer: UIPanGestureRecognizer?
    private var tapRecognizer: UITapGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private var allowAnyDirection = false

    public var isDisplayingRevealedOptions: Bool {
        return self.isRevealOptionsActive
    }

    private func updateRevealOptionsActive(_ isActive: Bool, transition: ContainedViewLayoutTransition) {
        if self.isRevealOptionsActive != isActive {
            self.isRevealOptionsActive = isActive
            self.updatePreviousRevealOptionsItemNode(isActive: isActive, transition: transition)
            self.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        }
    }

    private func updateNextRevealOptionsActive(_ isActive: Bool, separatorAlpha: CGFloat = 1.0, transition: ContainedViewLayoutTransition) {
        let alphaChanged = self.nextRevealOptionsSeparatorAlpha != separatorAlpha
        self.nextRevealOptionsSeparatorAlpha = separatorAlpha
        if self.isNextRevealOptionsActive != isActive {
            self.isNextRevealOptionsActive = isActive
            self.nextRevealOptionsActiveStateUpdated(isActive: isActive, transition: transition)
        } else if alphaChanged {
            self.revealOptionsSeparatorAlphaUpdated()
        }
    }

    private func previousRevealOptionsItemNode() -> ItemListRevealOptionsItemNode? {
        guard let subnodes = self.supernode?.subnodes else {
            return nil
        }

        if let index = self.index {
            var candidate: ItemListRevealOptionsItemNode?
            for subnode in subnodes {
                guard let itemNode = subnode as? ItemListRevealOptionsItemNode, itemNode !== self, let itemIndex = itemNode.index, itemIndex < index else {
                    continue
                }
                if let currentCandidate = candidate, let candidateIndex = currentCandidate.index {
                    if itemIndex > candidateIndex {
                        candidate = itemNode
                    }
                } else {
                    candidate = itemNode
                }
            }
            if let candidate = candidate {
                return candidate
            }
        }

        var candidate: ItemListRevealOptionsItemNode?
        for subnode in subnodes {
            guard let itemNode = subnode as? ItemListRevealOptionsItemNode, itemNode !== self else {
                continue
            }
            if itemNode.frame.maxY <= self.frame.minY + UIScreenPixel {
                if let currentCandidate = candidate {
                    if itemNode.frame.maxY > currentCandidate.frame.maxY {
                        candidate = itemNode
                    }
                } else {
                    candidate = itemNode
                }
            }
        }
        return candidate
    }

    private func updatePreviousRevealOptionsItemNode(isActive: Bool, transition: ContainedViewLayoutTransition) {
        let previousItemNode = isActive ? self.previousRevealOptionsItemNode() : nil
        if self.revealOptionsActivePreviousItemNode !== previousItemNode {
            self.revealOptionsActivePreviousItemNode?.updateNextRevealOptionsActive(false, transition: transition)
            self.revealOptionsActivePreviousItemNode = previousItemNode
        }
        previousItemNode?.updateNextRevealOptionsActive(isActive, separatorAlpha: self.revealOptionsSeparatorAlpha, transition: transition)
        if !isActive {
            self.revealOptionsActivePreviousItemNode = nil
        }
    }

    private func updateRevealOptionsSeparatorVisibility() {
        self.revealOptionsTopSeparatorNode?.isHidden = self.revealOptionsTopSeparatorBaseIsHidden || self.revealOptionsTopSeparatorHiddenByPreviousRevealOptions
        self.revealOptionsBottomSeparatorNode?.isHidden = self.revealOptionsBottomSeparatorBaseIsHidden || (!self.isNextRevealOptionsActive && self.revealOptionsBottomSeparatorHiddenByNextRevealOptions)
        self.revealOptionsTopSeparatorNode?.alpha = self.revealOptionsSeparatorAlpha
        self.revealOptionsBottomSeparatorNode?.alpha = min(self.revealOptionsSeparatorAlpha, self.nextRevealOptionsSeparatorAlpha)
    }

    private func updateRevealOptionsHighlightedBackgroundGeometry(transition: ContainedViewLayoutTransition) {
        guard let highlightedBackgroundNode = self.revealOptionsHighlightedBackgroundNode, let baseFrame = self.revealOptionsHighlightedBackgroundBaseFrame else {
            return
        }

        let frame: CGRect
        if self.revealOptionsHighlightedBackgroundTracksRevealOffset && self.isRevealOptionsActive {
            frame = baseFrame.offsetBy(dx: self.revealOffset, dy: 0.0)
        } else {
            frame = baseFrame
        }
        transition.updateFrame(node: highlightedBackgroundNode, frame: frame)
        highlightedBackgroundNode.layer.cornerCurve = .continuous
        highlightedBackgroundNode.cornerRadius = min(self.revealOptionsHighlightedBackgroundActiveCornerRadius, baseFrame.height / 2) * (self.revealOptionsAllowsHighlight ? self.revealOptionsHighlightProgress : 0)
    }

    public func updateRevealOptionsSeparatorNodes(top: ASDisplayNode?, bottom: ASDisplayNode?, topIsHidden: Bool, bottomIsHidden: Bool, topHiddenByPreviousRevealOptions: Bool = false, bottomHiddenByNextRevealOptions: Bool = false) {
        self.revealOptionsTopSeparatorNode = top
        self.revealOptionsBottomSeparatorNode = bottom
        self.revealOptionsTopSeparatorBaseIsHidden = topIsHidden
        self.revealOptionsBottomSeparatorBaseIsHidden = bottomIsHidden
        self.revealOptionsTopSeparatorHiddenByPreviousRevealOptions = topHiddenByPreviousRevealOptions
        self.revealOptionsBottomSeparatorHiddenByNextRevealOptions = bottomHiddenByNextRevealOptions
        self.updateRevealOptionsSeparatorVisibility()
    }

    public func updateRevealOptionsHighlightedBackgroundFrame(_ highlightedBackgroundNode: ASDisplayNode, frame: CGRect, tracksRevealOffset: Bool = true, activeCornerRadius: CGFloat = 26.0, transition: ContainedViewLayoutTransition = .immediate, aboveNodes: [ASDisplayNode?] = []) {
        self.revealOptionsHighlightedBackgroundNode = highlightedBackgroundNode
        if !aboveNodes.isEmpty {
            self.revealOptionsHighlightAnchor = aboveNodes.compactMap { $0 }.first(where: { $0.supernode != nil })
        }
        self.revealOptionsHighlightedBackgroundBaseFrame = frame
        self.revealOptionsHighlightedBackgroundTracksRevealOffset = tracksRevealOffset
        self.revealOptionsHighlightedBackgroundActiveCornerRadius = activeCornerRadius
        self.updateRevealOptionsHighlightedBackgroundGeometry(transition: transition)
    }

    public var revealOptionsHighlightProgress: CGFloat {
        return CGFloat(min(1, max(0, self.motion.surface.value)))
    }

    public func updateRevealOptionsHighlightedBackgroundNode(_ highlightedBackgroundNode: ASDisplayNode, isHighlighted: Bool, transition: ContainedViewLayoutTransition, aboveNodes: [ASDisplayNode?], highlightAlpha: CGFloat = 1.0, allowsRevealHighlight: Bool = true) {
        self.revealOptionsHighlightedBackgroundNode = highlightedBackgroundNode
        self.revealOptionsAllowsHighlight = allowsRevealHighlight
        self.revealOptionsBaseHighlightAlpha = isHighlighted ? highlightAlpha : 0.0
        self.revealOptionsHighlightAnchor = aboveNodes.compactMap { $0 }.first(where: { $0.supernode != nil })
        self.applyRevealOptionsHighlight(transition: transition)
    }

    private func applyRevealOptionsHighlight(transition: ContainedViewLayoutTransition) {
        guard let node = self.revealOptionsHighlightedBackgroundNode else { return }
        let alpha = self.revealOptionsBaseHighlightAlpha + (1.0 - self.revealOptionsBaseHighlightAlpha) * (self.revealOptionsAllowsHighlight ? CGFloat(min(1, max(0, self.motion.surfaceOpacity.value))) : 0)
        if alpha > 0 || self.isRevealOptionsActive {
            if self.isRevealOptionsActive || node.alpha == 0 {
                self.highlightFadeGeneration += 1
                node.layer.removeAnimation(forKey: "opacity")
            }
            if node.supernode == nil {
                if let anchor = self.revealOptionsHighlightAnchor, anchor.supernode === self {
                    self.insertSubnode(node, aboveSubnode: anchor)
                } else {
                    self.insertSubnode(node, at: 0)
                }
            }
            if self.isRevealOptionsActive {
                self.selectionHighlightEndTime = 0
                node.alpha = alpha
            } else {
                transition.updateAlpha(node: node, alpha: alpha)
            }
        } else if node.supernode != nil {
            // A second highlight/layout update must not remove the node while its
            // presentation is still fading (the model alpha is already zero).
            if node.alpha != 0 || node.layer.animation(forKey: "opacity") == nil {
                self.highlightFadeGeneration += 1
                let generation = self.highlightFadeGeneration
                let delay = max(0, self.selectionHighlightEndTime - CACurrentMediaTime())
                let transition = UIAccessibility.isReduceMotionEnabled ? ContainedViewLayoutTransition.immediate : transition
                transition.updateAlpha(node: node, alpha: 0, delay: delay, completion: { [weak self, weak node] completed in
                    if completed, let self, self.highlightFadeGeneration == generation, !self.isRevealOptionsActive, self.revealOptionsBaseHighlightAlpha == 0 {
                        node?.removeFromSupernode()
                    }
                })
            }
        }
        self.updateRevealOptionsHighlightedBackgroundGeometry(transition: transition)
    }

    // For decorations whose colors depend on the animated surface (e.g. badges).
    open func revealOptionsSurfaceUpdated(progress: CGFloat) {
    }

    open func revealOptionsSeparatorAlphaUpdated() {
        self.updateRevealOptionsSeparatorVisibility()
    }

    override open func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        if highlighted || !animated {
            self.selectionHighlightEndTime = 0
            self.highlightFadeGeneration += 1
            self.revealOptionsHighlightedBackgroundNode?.layer.removeAnimation(forKey: "opacity")
        }
        self.revealOptionsBaseHighlightAlpha = highlighted ? 1 : 0
        self.applyRevealOptionsHighlight(transition: animated && !highlighted ? .animated(duration: 0.4, curve: .easeInOut) : .immediate)
    }

    override open func selected() {
        super.selected()
        // Hold only accepted taps, never touches cancelled by scrolling or a swipe.
        if !self.isRevealOptionsActive && !UIAccessibility.isReduceMotionEnabled {
            self.selectionHighlightEndTime = CACurrentMediaTime() + 0.5
        }
    }

    override open var canBeSelected: Bool {
        return !self.isDisplayingRevealedOptions
    }
    
    override public init(layerBacked: Bool, rotated: Bool, seeThrough: Bool) {
        super.init(layerBacked: layerBacked, rotated: rotated, seeThrough: seeThrough)
    }

    deinit {
        self.animationLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
        self.revealOptionsActivePreviousItemNode?.updateNextRevealOptionsActive(false, transition: .immediate)
    }
    
    open var controlsContainer: ASDisplayNode {
        return self
    }
    
    override open func didLoad() {
        super.didLoad()
        let recognizer = ItemListRevealTouchGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.delegate = self.wrappedGestureRecognizerDelegate
        recognizer.canBegin = { [weak self] point, direction in
            guard let self else { return false }
            return self.canBeginReveal(at: point, direction: direction)
        }
        recognizer.horizontalIntent = { [weak self] in
            guard let self else { return }
            self.cancelRevealContextGestures(in: self.view)
        }
        self.view.addGestureRecognizer(recognizer)

        // Touch input has its own measured hysteresis. Keep indirect scrolling
        // on UIPan so trackpads retain UIKit's continuous scroll event support.
        let scrollRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.revealScrollGesture(_:)))
        scrollRecognizer.allowedTouchTypes = []
        if #available(iOS 13.4, *) {
            scrollRecognizer.allowedScrollTypesMask = .continuous
        }
        scrollRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.scrollRecognizer = scrollRecognizer
        self.view.addGestureRecognizer(scrollRecognizer)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.revealTapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        tapRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.view.addGestureRecognizer(tapRecognizer)
        self.updateRecognizerAvailability()
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            return self?.isRevealOptionsActive ?? false
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    override open func reuse() {
        self.selectionHighlightEndTime = 0
        self.highlightFadeGeneration += 1
        self.revealOptionsHighlightedBackgroundNode?.layer.removeAnimation(forKey: "opacity")
        self.resetRevealInteraction(notify: true)
        self.revealOptionsBaseHighlightAlpha = 0
        self.applyRevealOptionsHighlight(transition: .immediate)
        super.reuse()
    }

    override open func didExitHierarchy() {
        super.didExitHierarchy()
        self.resetRevealInteraction(notify: true)
    }

    private var activeRevealNode: ItemListRevealOptionsNode? {
        return self.revealDirection > 0 ? self.leftRevealNode : self.rightRevealNode
    }

    private var activeOptions: [ItemListRevealOption] {
        return self.revealDirection > 0 ? self.revealOptions.left : self.revealOptions.right
    }

    private func updateRecognizerAvailability() {
        let enabled = !self.revealOptions.left.isEmpty || !self.revealOptions.right.isEmpty
        self.recognizer?.isEnabled = enabled
        self.scrollRecognizer?.isEnabled = enabled
        self.allowAnyDirection = !self.revealOptions.left.isEmpty || self.isRevealOptionsActive
        if self.isNodeLoaded {
            self.view.disablesInteractiveTransitionGestureRecognizer = self.allowAnyDirection
        }
    }

    open func setRevealOptions(_ options: (left: [ItemListRevealOption], right: [ItemListRevealOption]), enableAnimations: Bool = true) {
        guard self.revealOptions != options || self.enableAnimations != enableAnimations else { return }
        let previous = self.activeOptions
        let updated = self.revealDirection > 0 ? options.left : options.right
        let structuralChange = previous.map { self.revealOptionAnimationKey($0.key) } != updated.map { self.revealOptionAnimationKey($0.key) } || previous.map(\.isDestructive) != updated.map(\.isDestructive)
        if structuralChange && self.isRevealOptionsActive {
            self.resetRevealInteraction(notify: true)
        }
        self.revealOptions = options
        self.enableAnimations = enableAnimations
        if let node = self.activeRevealNode {
            node.setOptions(self.activeOptions, isLeft: self.revealDirection > 0, enableAnimations: enableAnimations)
            self.updateActiveRevealMetrics()
            // Appearance changes (mute/read toggles, themes, localization) keep
            // every channel's presentation and velocity.
            if self.motion.state == .open || self.motion.state == .settling(open: true) {
                self.motion.settle(to: self.motion.parameters.openDistance, velocity: self.motion.body.velocity, animated: true)
            }
            self.renderRevealMotion()
            self.startRevealAnimation()
        }
        self.updateRecognizerAvailability()
    }

    // Hosts can identify alternate presentations of the same control (e.g.
    // mute/unmute). Selection still delivers the option's original action key.
    open func revealOptionAnimationKey(_ key: Int32) -> Int32 {
        return key
    }

    private func containsAction(at point: CGPoint) -> Bool {
        guard let node = self.activeRevealNode else { return false }
        return node.containsActionPoint(node.view.convert(point, from: self.view))
    }

    private func canBeginReveal(at point: CGPoint, direction: CGFloat) -> Bool {
        guard self.validLayout != nil, self.motion.state != .filling, !self.deliveringAction, !self.containsAction(at: point) else { return false }
        if self.isRevealOptionsActive && (abs(self.motion.body.value) >= 0.1 || abs(self.motion.body.velocity) >= 5) { return true }
        return direction > 0 ? !self.revealOptions.left.isEmpty : !self.revealOptions.right.isEmpty
    }

    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.tapRecognizer {
            return self.isRevealOptionsActive && self.motion.state != .dragging && !self.containsAction(at: gestureRecognizer.location(in: self.view))
        } else if gestureRecognizer === self.scrollRecognizer, let recognizer = self.scrollRecognizer {
            let velocity = recognizer.velocity(in: self.view)
            return abs(velocity.x) > abs(velocity.y) && self.canBeginReveal(at: recognizer.location(in: self.view), direction: velocity.x)
        }
        return true
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer === self.recognizer || otherGestureRecognizer === self.scrollRecognizer
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Navigation containers already take priority over UIPan recognizers.
        // Keep that relationship for our touch recognizer too: folder paging
        // accepts center swipes and rejects edge swipes, leaving those to us.
        return gestureRecognizer === self.recognizer && otherGestureRecognizer is InteractiveTransitionGestureRecognizer
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // A scrolling pan must wait for the horizontal recognizer's vertical
        // rejection; otherwise it wins before the 25-point horizontal deadzone.
        return gestureRecognizer === self.recognizer && otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
    }

    @objc private func revealTapGesture(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.setRevealOptionsOpened(false, animated: true)
            self.revealOptionsInteractivelyClosed()
        }
    }

    @objc private func revealGesture(_ recognizer: ItemListRevealTouchGestureRecognizer) {
        self.handleRevealGesture(state: recognizer.state, direction: recognizer.initialDirection, translation: recognizer.translation, velocity: recognizer.horizontalVelocity, location: recognizer.location)
    }

    @objc private func revealScrollGesture(_ recognizer: UIPanGestureRecognizer) {
        let velocity = recognizer.velocity(in: self.view)
        self.handleRevealGesture(state: recognizer.state, direction: velocity.x, translation: recognizer.translation(in: self.view).x, velocity: velocity.x, location: recognizer.location(in: self.view))
    }

    func handleRevealGesture(state: UIGestureRecognizer.State, direction: CGFloat, translation: CGFloat, velocity: CGFloat, location: CGPoint) {
        guard !self.suppressGestureEvents, let (size, _, _) = self.validLayout else { return }
        switch state {
        case .began:
            self.cancelRevealContextGestures(in: self.view)
            self.advanceRevealAnimation()
            let atClosedPosition = abs(self.motion.body.value) < 0.1 && abs(self.motion.body.velocity) < 5
            if !self.isRevealOptionsActive || atClosedPosition {
                let newDirection: CGFloat = direction > 0 ? 1 : -1
                if self.revealDirection != newDirection {
                    self.leftRevealNode?.removeFromSupernode()
                    self.rightRevealNode?.removeFromSupernode()
                    self.leftRevealNode = nil
                    self.rightRevealNode = nil
                    self.motion.reset()
                }
                guard self.setupRevealNode(direction: newDirection) else { return }
            }
            self.animationCompletion = nil
            let highlightAlpha = self.revealOptionsHighlightedBackgroundNode.flatMap { node -> CGFloat? in
                guard node.supernode != nil, !node.isHidden else { return nil }
                return CGFloat(node.layer.presentation()?.opacity ?? node.layer.opacity)
            } ?? 0
            self.motion.begin(highlightAlpha: Double(highlightAlpha))
            self.hapticFeedback = self.hapticFeedback ?? HapticFeedback()
            self.hapticFeedback?.prepareTap()
            self.renderRevealMotion()
            self.revealOptionsInteractivelyOpened()
            fallthrough
        case .changed:
            let wasArmed = self.motion.isArmed
            let distance = self.revealDirection < 0 ? location.x : size.width - location.x
            self.motion.change(translation: Double(translation * self.revealDirection), velocity: Double(velocity * self.revealDirection), distanceFromCommitEdge: Double(distance), reduceMotion: UIAccessibility.isReduceMotionEnabled)
            if wasArmed != self.motion.isArmed { self.hapticFeedback?.tap() }
            self.renderRevealMotion()
            self.startRevealAnimation()
        case .ended, .cancelled:
            guard self.motion.state == .dragging else { return }
            let commit = self.motion.end(translation: Double(translation * self.revealDirection), velocity: Double(velocity * self.revealDirection), cancelled: state == .cancelled, animated: !UIAccessibility.isReduceMotionEnabled)
            self.renderRevealMotion()
            self.startRevealAnimation()
            if commit, let option = self.revealDirection > 0 ? self.activeOptions.first : self.activeOptions.last {
                self.deliverRevealOption(option, animated: true)
            } else if !self.motion.wantsOpen {
                self.revealOptionsInteractivelyClosed()
            }
        default:
            break
        }
    }

    private func cancelRevealContextGestures(in view: UIView) {
        for recognizer in view.gestureRecognizers ?? [] {
            if let contextGesture = recognizer as? ContextGesture {
                contextGesture.cancel()
            }
        }
        for subview in view.subviews {
            self.cancelRevealContextGestures(in: subview)
        }
    }

    private func deliverRevealOption(_ option: ItemListRevealOption, animated: Bool) {
        guard !self.deliveringAction, self.motion.state != .filling else { return }
        self.deliveringAction = true
        self.revealOptionSelected(option, animated: animated)
        self.deliveringAction = false
    }

    @discardableResult private func setupRevealNode(direction: CGFloat) -> Bool {
        guard self.validLayout != nil else { return false }
        let options = direction > 0 ? self.revealOptions.left : self.revealOptions.right
        guard !options.isEmpty else { return false }
        self.revealDirection = direction
        if self.activeRevealNode == nil {
            let node = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.deliverRevealOption(option, animated: false)
            }, tapticAction: {})
            node.setOptions(options, isLeft: direction > 0, enableAnimations: self.enableAnimations)
            if direction > 0 { self.leftRevealNode = node } else { self.rightRevealNode = node }
            self.controlsContainer.addSubnode(node)
        }
        self.updateActiveRevealMetrics()
        return true
    }

    private func updateActiveRevealMetrics() {
        guard let (size, leftInset, rightInset) = self.validLayout, let node = self.activeRevealNode else { return }
        let sideInset = self.revealDirection > 0 ? leftInset : rightInset
        var revealSize = node.measure(CGSize(width: .greatestFiniteMagnitude, height: size.height))
        revealSize.width += sideInset
        node.bounds = CGRect(origin: .zero, size: revealSize)
        self.motion.configure(node.motionParameters(width: size.width, sideInset: sideInset, displayScale: self.isNodeLoaded ? self.view.traitCollection.displayScale : UIScreen.main.scale))
    }

    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        if let previous = self.validLayout, previous.0 != size || previous.1 != leftInset || previous.2 != rightInset {
            self.resetRevealInteraction(notify: true)
        }
        self.validLayout = (size, leftInset, rightInset)
        if self.isRevealOptionsActive {
            self.updatePreviousRevealOptionsItemNode(isActive: true, transition: .immediate)
            self.updateActiveRevealMetrics()
            self.renderRevealMotion()
        }
    }

    open func updateRevealOffsetInternal(offset: CGFloat, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        if offset != 0 && self.activeRevealNode == nil {
            guard self.setupRevealNode(direction: offset > 0 ? 1 : -1) else { completion?(); return }
        }
        self.animationCompletion = completion
        self.motion.settle(to: Double(offset * self.revealDirection), velocity: self.motion.body.velocity, animated: transition.isAnimated && !UIAccessibility.isReduceMotionEnabled)
        self.renderRevealMotion()
        self.startRevealAnimation()
    }

    private func renderRevealMotion() {
        guard let (size, _, _) = self.validLayout else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.revealOffset = self.revealDirection * CGFloat(self.motion.body.value)
        // Separators return as the surface fades, while controls and interaction
        // state remain alive until all their animation channels have settled.
        let separatorAlpha = 1.0 - CGFloat(min(1, max(0, self.motion.surfaceOpacity.value)))
        let separatorAlphaChanged = self.revealOptionsSeparatorAlpha != separatorAlpha
        self.revealOptionsSeparatorAlpha = separatorAlpha
        self.updateRevealOptionsActive(self.motion.state != .closed, transition: .immediate)
        if separatorAlphaChanged {
            self.revealOptionsSeparatorAlphaUpdated()
            self.revealOptionsActivePreviousItemNode?.updateNextRevealOptionsActive(self.isRevealOptionsActive, separatorAlpha: separatorAlpha, transition: .immediate)
        }
        if let node = self.activeRevealNode {
            let distance = max(0, CGFloat(self.motion.body.value))
            let x = self.revealDirection > 0 ? min(distance - node.bounds.width, 0) : size.width - distance
            node.position = CGPoint(x: x + node.bounds.width / 2, y: node.bounds.height / 2)
            node.render(motion: self.motion)
        }
        self.updateRevealOffset(offset: self.revealOffset, transition: .immediate)
        self.applyRevealOptionsHighlight(transition: .immediate)
        let progress = self.revealOptionsHighlightProgress
        if progress != self.lastSurfaceProgress || self.motion.surfaceOpacity.value != self.motion.surfaceOpacity.target {
            self.lastSurfaceProgress = progress
            self.revealOptionsSurfaceUpdated(progress: progress)
        }
        if self.motion.state == .closed {
            self.leftRevealNode?.removeFromSupernode()
            self.rightRevealNode?.removeFromSupernode()
            self.leftRevealNode = nil
            self.rightRevealNode = nil
        }
        self.updateRecognizerAvailability()
    }

    private func startRevealAnimation() {
        if self.motion.isAtRest {
            self.animationLink?.invalidate()
            self.animationLink = nil
            self.previousAnimationTime = 0
            let completion = self.animationCompletion
            self.animationCompletion = nil
            completion?()
            return
        }
        guard self.animationLink == nil else { return }
        self.previousAnimationTime = CACurrentMediaTime()
        self.animationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
            self?.advanceRevealAnimation()
        })
    }

    private func advanceRevealAnimation() {
        guard self.previousAnimationTime > 0 else { return }
        let now = CACurrentMediaTime()
        let dt = max(0, now - self.previousAnimationTime)
        self.previousAnimationTime = now
        self.advanceRevealAnimations(by: dt)
    }

    // Same deterministic step for display updates and interaction regressions.
    func advanceRevealAnimations(by dt: Double) {
        self.motion.advance(by: dt)
        self.renderRevealMotion()
        self.startRevealAnimation()
    }

    private func cancelRevealRecognizers() {
        self.suppressGestureEvents = true
        self.recognizer?.isEnabled = false
        self.scrollRecognizer?.isEnabled = false
        self.updateRecognizerAvailability()
        self.suppressGestureEvents = false
    }

    private func resetRevealInteraction(notify: Bool) {
        let wasActive = self.isRevealOptionsActive
        self.cancelRevealRecognizers()
        self.animationLink?.invalidate()
        self.animationLink = nil
        self.previousAnimationTime = 0
        self.animationCompletion = nil
        self.layer.allowsGroupOpacity = false
        self.motion.reset()
        self.renderRevealMotion()
        if notify && wasActive { self.revealOptionsInteractivelyClosed() }
    }

    @objc private func reduceMotionChanged() {
        if UIAccessibility.isReduceMotionEnabled {
            self.selectionHighlightEndTime = 0
            self.highlightFadeGeneration += 1
            self.revealOptionsHighlightedBackgroundNode?.layer.removeAnimation(forKey: "opacity")
            self.motion.snapToTargets()
            self.motion.advance(by: 0)
            self.renderRevealMotion()
            self.startRevealAnimation()
        }
    }

    open func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    open func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        self.updateRevealOptionsSeparatorVisibility()
        self.updateRevealOptionsHighlightedBackgroundGeometry(transition: transition)
    }

    open func nextRevealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        self.updateRevealOptionsSeparatorVisibility()
    }

    open func revealOptionsInteractivelyOpened() {
    }

    open func revealOptionsInteractivelyClosed() {
    }

    open func setRevealOptionsOpened(_ value: Bool, animated: Bool) {
        guard self.motion.state != .filling, value != self.motion.wantsOpen else { return }
        if value {
            guard self.setupRevealNode(direction: -1) else { return }
        } else {
            self.cancelRevealRecognizers()
        }
        self.animationCompletion = nil
        self.motion.settle(to: value ? self.motion.parameters.openDistance : 0, velocity: self.motion.body.velocity, animated: animated && !UIAccessibility.isReduceMotionEnabled)
        self.renderRevealMotion()
        self.startRevealAnimation()
    }

    open func animateRevealOptionsFill(completion: (() -> Void)? = nil) {
        guard let (size, _, _) = self.validLayout, self.activeRevealNode != nil else { completion?(); return }
        self.cancelRevealRecognizers()
        self.layer.allowsGroupOpacity = true
        self.animationCompletion = { [weak self] in
            self?.layer.allowsGroupOpacity = false
            completion?()
        }
        self.motion.settle(to: Double(size.width + 74), velocity: self.motion.body.velocity, animated: !UIAccessibility.isReduceMotionEnabled, filling: true)
        self.renderRevealMotion()
        self.startRevealAnimation()
    }

    open func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
    }

    override open var preventsTouchesToOtherItems: Bool {
        return self.isDisplayingRevealedOptions
    }

    override open func touchesToOtherItemsPrevented() {
        if self.isDisplayingRevealedOptions {
            self.setRevealOptionsOpened(false, animated: true)
        }
    }
}
